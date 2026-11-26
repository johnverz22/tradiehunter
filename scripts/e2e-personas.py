#!/usr/bin/env python3
"""scripts/e2e-personas.py — provision a run-scoped persona fabric for E2E.

Creates N homeowners, N tradies and 1-2 staff accounts through the REAL API
(register -> OTP -> verify-email; tradie profile/rates/credential -> staff
credential review; superadmin invite -> set-password) and writes a manifest
that every E2E tier consumes, so the API, mobile and web tiers all exercise
the SAME users and jobs.  Plan: docs/todos/08_e2e_persona_fabric_plan.md (P1).

  python3 scripts/e2e-personas.py                          # 2 homeowners, 3 tradies, 1 staff
  python3 scripts/e2e-personas.py --homeowners 2 --tradies 4 --staff 2
  python3 scripts/e2e-personas.py --run-id nightly1 --out /tmp/m.json
  python3 scripts/e2e-personas.py --cleanup test-logs/e2e-personas-<id>/manifest.json

Accounts are named  qa+<runid>-<role>-<n>@fixo.test  and are safe to leave in
the DB.  --cleanup deactivates (admin API) every account listed in a manifest;
the API has no delete route, so rows remain but can no longer log in.

How verification works (no DB writes, ever)
  * Email OTPs and the staff-invite token are emailed; the dev stack delivers
    them to MailHog, whose HTTP API (MAILHOG_URL, default :8025) is read here.
  * Tradie verification follows the MVP rule "verified while holding >= 1
    approved credential": upload a credential, a staff persona approves it via
    POST /admin/credentials/{id}/review, then GET /profile must say isVerified.

Manifest (JSON, schemaVersion 1)
  {schemaVersion, runId, createdAtUtc, apiUrl, serviceId, tradeType,
   personas: [{role, index, email, password, firstName, lastName, userId,
               verified, credentialId, hourlyRate, bankAccountLast4}],
   jobs: []}            <- later tiers append {id, scenario, homeownerEmail, ...}
It holds throw-away test passwords in clear text; the file is chmod 600 and
lives under test-logs/ (git-ignored) by default.

Environment
  FIXO_API_URL         API base, default http://localhost:5000  (a trailing /api is tolerated)
  MAILHOG_URL          default http://localhost:8025
  FIXO_ADMIN_EMAIL / FIXO_ADMIN_PASSWORD   superadmin used to invite staff
                       (default: the AdminSeed values admin@fixo.nz / Admin1!Fixo)

Safety: refuses any non-localhost FIXO_API_URL / MAILHOG_URL.  Only real API
routes are used.  Money is parsed as Decimal and rates are sent as whole-dollar
JSON integers, so no float ever touches an amount.  stdlib only.

Failure behaviour: provisioning stops at the first failing step (the
fail-fast equivalent) and exits 1; --retry N retries transient HTTP errors
(connection errors, 502/503/504); --timeout S bounds each request.

Exit codes: 0 ok   1 a step failed   2 stack unreachable / unsafe target
"""

from __future__ import annotations

import argparse
import base64
import email as emaillib
import email.header
import json
import os
import re
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = 1
SAFE_HOSTS = {"localhost", "127.0.0.1", "::1"}
EMAIL_DOMAIN = "fixo.test"

# Same location the seeded tradie uses, so matching radius checks line up.
DEMO_ADDRESS = "1 Queen Street, Auckland CBD, Auckland 1010"  # real-looking street address; the API fixtures bypass LINZ lookup
AKL = {"address": DEMO_ADDRESS, "latitude": -36.8485, "longitude": 174.7633}
NAMES = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel"]

# Smallest valid PNG; a unique suffix keeps each upload distinct.
_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

OPTS = {"timeout": 15.0, "retry": 0}


class StepFailed(Exception):
    pass


class Unreachable(Exception):
    pass


# ── Safety + config ──────────────────────────────────────────────────────────


def require_local(url: str, what: str) -> str:
    host = (urllib.parse.urlparse(url).hostname or "").lower()
    if host not in SAFE_HOSTS:
        raise Unreachable(
            "refusing %s %r: host %r is not localhost (local docker stack only)" % (what, url, host)
        )
    return url.rstrip("/")


def api_base() -> str:
    base = require_local(os.environ.get("FIXO_API_URL", "http://localhost:5000"), "FIXO_API_URL")
    return (base[:-4] if base.endswith("/api") else base) + "/api"


def mailhog_base() -> str:
    return require_local(os.environ.get("MAILHOG_URL", "http://localhost:8025"), "MAILHOG_URL")


# ── HTTP ─────────────────────────────────────────────────────────────────────


def _send(req: urllib.request.Request):
    """One request with transient-error retry. Returns (status, text)."""
    attempts = OPTS["retry"] + 1
    last = None
    for i in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=OPTS["timeout"]) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            status, text = e.code, e.read().decode("utf-8", "replace")
            if status in (502, 503, 504) and i + 1 < attempts:
                last = "HTTP %d" % status
                time.sleep(1 + i)
                continue
            return status, text
        except (urllib.error.URLError, OSError) as e:
            last = str(e)
            if i + 1 < attempts:
                time.sleep(1 + i)
                continue
    raise Unreachable("%s %s: %s" % (req.get_method(), req.full_url, last))


def call(method, path, token=None, body=None, raw=None, content_type=None, ok=(200, 201, 204)):
    """API call. Raises StepFailed on an unexpected status; returns parsed JSON
    (floats parsed as Decimal) or None for empty bodies."""
    headers, data = {}, None
    if token:
        headers["Authorization"] = "Bearer " + token
    if raw is not None:
        data, headers["Content-Type"] = raw, content_type
    elif body is not None:
        data, headers["Content-Type"] = json.dumps(body).encode(), "application/json"
    status, text = _send(urllib.request.Request(api_base() + path, data=data, headers=headers, method=method))
    if status not in ok:
        raise StepFailed("%s %s -> HTTP %d: %s" % (method, path, status, text[:300].replace("\n", " ")))
    if not text.strip():
        return None
    try:
        return json.loads(text, parse_float=Decimal)
    except ValueError:
        return {"_raw": text}


def multipart(fields: dict, file_field: str, filename: str, content: bytes, ctype: str):
    boundary = "fixoqa%d" % time.time_ns()
    parts = []
    for k, v in fields.items():
        parts.append(
            ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (boundary, k, v)).encode()
        )
    parts.append(
        (
            '--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: %s\r\n\r\n'
            % (boundary, file_field, filename, ctype)
        ).encode()
        + content
        + b"\r\n"
    )
    parts.append(("--%s--\r\n" % boundary).encode())
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


# ── MailHog (the dev stack's real email channel) ─────────────────────────────


def _decode_header(value: str) -> str:
    try:
        return str(email.header.make_header(email.header.decode_header(value or "")))
    except Exception:  # noqa: BLE001
        return value or ""


def _message_parts(raw: str):
    """(subject, plain_text, html_text) — html_text is tag-stripped, "" when absent."""
    msg = emaillib.message_from_string(raw)
    plain, html = [], []
    for part in msg.walk():
        ctype = part.get_content_type()
        if ctype not in ("text/plain", "text/html"):
            continue
        payload = part.get_payload(decode=True)
        if payload is None:
            continue
        text = payload.decode(part.get_content_charset() or "utf-8", "replace")
        (plain if ctype == "text/plain" else html).append(text)
    plain_body = "\n".join(plain)
    html_body = ""
    if html:
        html_body = "\n".join(html)
        html_body = re.sub(r"(?is)<(style|script).*?</\1>", " ", html_body)
        html_body = re.sub(r"(?s)<[^>]+>", " ", html_body)
    return _decode_header(msg.get("Subject", "")), plain_body, html_body


def wait_for_mail(to_addr: str, subject_has: str, timeout: float = 45.0, include_html: bool = False):
    """Newest MailHog message to `to_addr` whose subject contains `subject_has`.

    include_html appends the tag-stripped HTML part to the returned body —
    needed for the staff invite, whose token only appears in the HTML
    token box when no activation URL is configured.
    """
    url = "%s/api/v2/search?kind=to&query=%s&limit=50" % (mailhog_base(), urllib.parse.quote(to_addr))
    end = time.time() + timeout
    while True:
        status, text = _send(urllib.request.Request(url))
        if status == 200:
            for item in (json.loads(text).get("items") or []):  # newest first
                raw = (item.get("Raw") or {}).get("Data")
                if not raw:
                    continue
                subject, plain, html = _message_parts(raw)
                if subject_has.lower() in subject.lower():
                    if include_html and html:
                        return (plain + "\n" + html).strip() if plain else html
                    return plain or html
        if time.time() >= end:
            raise StepFailed(
                "no MailHog message to %s with subject containing %r after %ds "
                "(is MailHog up at %s and the API sending to it?)"
                % (to_addr, subject_has, timeout, mailhog_base())
            )
        time.sleep(1.5)


def otp_from(body: str) -> str:
    m = re.search(r"(?<![\w#])(\d{6})(?![\w])", body)
    if not m:
        raise StepFailed("could not find a 6-digit code in the OTP email: %r" % body[:200])
    return m.group(1)


def invite_token_from(body: str) -> str:
    m = re.search(r"token=([^\s\"'&<>]+)", body)
    if m:
        return urllib.parse.unquote(m.group(1))
    # Bare-token fallback: the invite token is base64url (WebEncoders), so a
    # charset filter keeps out emails, URLs and markup fragments.
    candidates = [w for w in body.split() if re.fullmatch(r"[A-Za-z0-9_-]{20,}", w)]
    if candidates:
        return max(candidates, key=len)
    raise StepFailed("could not find an invite token in the staff-invite email")


# ── Provisioning steps ───────────────────────────────────────────────────────


def say(msg: str):
    print("  " + msg, flush=True)


def login(email_addr: str, password: str) -> str:
    body = call("POST", "/auth/login", body={"email": email_addr, "password": password})
    token = (body or {}).get("token")
    if not token:
        raise StepFailed("login for %s returned no token" % email_addr)
    return token


def register_verified(p: dict) -> str:
    """Register -> read OTP from MailHog -> verify-email. Returns a JWT."""
    role_code = {"homeowner": 0, "tradie": 1}[p["role"]]
    call(
        "POST",
        "/auth/register",
        body={
            "email": p["email"],
            "password": p["password"],
            "firstName": p["firstName"],
            "lastName": p["lastName"],
            "role": role_code,
        },
    )
    code = otp_from(wait_for_mail(p["email"], "verification code"))
    auth = call("POST", "/auth/verify-email", body={"email": p["email"], "code": code})
    token = (auth or {}).get("token")
    if not token:
        raise StepFailed("verify-email for %s returned no token" % p["email"])
    return token


def staff_token_for_review(admin_token: str, staff: list) -> str:
    """Prefer a staff persona (the realistic reviewer); fall back to superadmin."""
    if staff:
        return login(staff[0]["email"], staff[0]["password"])
    return admin_token


def admin_login() -> str:
    email_addr = os.environ.get("FIXO_ADMIN_EMAIL", "admin@fixo.nz")
    password = os.environ.get("FIXO_ADMIN_PASSWORD", "Admin1!Fixo")
    try:
        return login(email_addr, password)
    except StepFailed as e:
        raise Unreachable(
            "cannot log in as superadmin %s (%s) — set FIXO_ADMIN_EMAIL/FIXO_ADMIN_PASSWORD" % (email_addr, str(e)[:120])
        )


def provision_staff(p: dict, admin_token: str):
    call(
        "POST",
        "/admin/staff/invite",
        admin_token,
        {"email": p["email"], "firstName": p["firstName"], "lastName": p["lastName"]},
    )
    token = invite_token_from(wait_for_mail(p["email"], "invited", include_html=True))
    call("POST", "/admin/staff/set-password", body={"email": p["email"], "token": token, "newPassword": p["password"]})
    jwt = login(p["email"], p["password"])  # prove the credentials we are about to hand out work
    p["userId"] = str((call("GET", "/profile", jwt) or {}).get("id") or "")
    p["verified"] = True


def pick_service(token: str, forced):
    """Return (service_id, trade_type) for the tradies' rate + profile.

    Defaults to service 1 — the id scripts/e2e-journey.py posts jobs with.
    trade_type must be the service's category ("Plumber", "Electrician", ...):
    MatchingService compares TradeType.ToLower() to job.Category.ToString(),
    the TradeCategory enum name — "Plumbing" never matches a Plumber job.
    """
    services = call("GET", "/tradie/services", token)
    rows = services if isinstance(services, list) else []
    want = int(forced) if forced else 1
    for s in rows:
        if isinstance(s, dict) and int(s.get("id", -1)) == want:
            return want, s.get("category") or "Plumber"
    if rows and isinstance(rows[0], dict) and "id" in rows[0]:
        return int(rows[0]["id"]), rows[0].get("category") or "Plumber"
    return want, "Plumber"  # service list unavailable; 1 is the seeded/journey id


def upload_credential(jwt: str, filename: str, cred_type: str, tag: str) -> int:
    """POST /tradie/credentials (multipart) as the tradie; returns the credential id."""
    body, ctype = multipart(
        {"type": cred_type},
        "file",
        filename,
        _PNG + ("|qa-%s-%d" % (tag, time.time_ns())).encode(),
        "image/png",
    )
    cred = call("POST", "/tradie/credentials", jwt, raw=body, content_type=ctype)
    cred_id = (cred or {}).get("id")
    if cred_id is None:
        listing = call("GET", "/tradie/credentials", jwt)
        cred_id = (listing[-1] if isinstance(listing, list) and listing else {}).get("id")
    if cred_id is None:
        raise StepFailed("credential upload (%s) returned no id" % filename)
    return int(cred_id)


def ensure_payout_details(jwt: str, p: dict):
    """Give the tradie payout bank details through PUT /profile (real API, no DB
    writes) unless the profile already has them, so the admin payout queue can
    process this persona. NZ format XX-XXXX-XXXXXXX-XX; a throw-away test number.
    PUT /profile overwrites first/last name and phone, so those are echoed back."""
    profile = call("GET", "/profile", jwt) or {}
    existing = str(profile.get("bankAccountNumber") or "")
    if existing:
        p["bankAccountLast4"] = re.sub(r"\D", "", existing)[-4:]
        return False
    number = "12-3456-%07d-00" % (9000000 + p["index"])
    call(
        "PUT",
        "/profile",
        jwt,
        {
            "firstName": profile.get("firstName") or p["firstName"],
            "lastName": profile.get("lastName") or p["lastName"],
            "phoneNumber": profile.get("phoneNumber"),
            "bankAccountName": "%s %s" % (p["firstName"], p["lastName"]),
            "bankAccountNumber": number,
        },
    )
    check = call("GET", "/profile", jwt) or {}
    if str(check.get("bankAccountNumber") or "") != number:
        raise StepFailed("payout bank details for %s did not round-trip through /profile" % p["email"])
    p["bankAccountLast4"] = re.sub(r"\D", "", number)[-4:]
    return True


def onboard_tradie(p: dict, jwt: str, service_id: int, trade_type: str, reviewer: str, run_id: str):
    n = p["index"]
    call(
        "PUT",
        "/profile",
        jwt,
        {
            "firstName": p["firstName"],
            "lastName": p["lastName"],
            "phoneNumber": "+6421%06d" % (900000 + n),
            "tradeType": trade_type,
            "address": AKL["address"],
            "latitude": AKL["latitude"],
            "longitude": AKL["longitude"],
            "serviceRadiusKm": 25,
            "isAvailable": True,
        },
    )
    rate = 80 + 5 * n  # whole dollars -> JSON integer, never a float
    call("POST", "/tradie/rates", jwt, {"rates": [{"serviceId": service_id, "hourlyRate": rate}]})
    stored = call("GET", "/tradie/rates", jwt)
    rows = stored if isinstance(stored, list) else (stored or {}).get("rates", [])
    got = [Decimal(str(r.get("hourlyRate"))) for r in rows if int(r.get("serviceId", -1)) == service_id]
    if got != [Decimal(rate)]:
        raise StepFailed("rate round-trip mismatch for %s: sent %s, stored %s" % (p["email"], rate, got))
    p["hourlyRate"] = "%d.00" % rate

    p["credentialId"] = upload_credential(jwt, "license-%s-%d.png" % (run_id, n), "License", "%s-%d" % (run_id, n))

    call("POST", "/admin/credentials/%d/review" % p["credentialId"], reviewer, {"status": "Approved"})
    profile = call("GET", "/profile", jwt) or {}
    p["userId"] = str(profile.get("id") or "")
    p["verified"] = profile.get("isVerified") is True
    if not p["verified"]:
        raise StepFailed(
            "credential %s approved but /profile.isVerified is %r for %s — verification rule changed?"
            % (p["credentialId"], profile.get("isVerified"), p["email"])
        )
    ensure_payout_details(jwt, p)


def mk_persona(run_id: str, role: str, n: int) -> dict:
    return {
        "role": role,
        "index": n,
        "email": "qa+%s-%s-%d@%s" % (run_id, role, n, EMAIL_DOMAIN),
        "password": "Qa1!" + secrets.token_hex(6),
        "firstName": "Qa",
        "lastName": "%s%s" % (role.capitalize(), NAMES[(n - 1) % len(NAMES)]),
        "userId": "",
        "verified": False,
        "credentialId": None,
        "hourlyRate": None,
        "bankAccountLast4": None,
    }


# ── Manifest ─────────────────────────────────────────────────────────────────


def write_manifest(path: Path, manifest: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(manifest, indent=2) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)  # atomic


def provision(args) -> int:
    run_id = args.run_id
    out = Path(args.out) if args.out else Path(
        os.environ.get("E2E_LOG_DIR") or REPO_ROOT / "test-logs" / ("e2e-personas-" + run_id)
    ) / "manifest.json"
    if out.suffix != ".json":
        out = out / "manifest.json"

    print("e2e personas: run %s against %s" % (run_id, api_base()))
    admin = admin_login() if (args.staff or args.tradies) else None  # invites staff / reviews credentials
    personas: list = []
    manifest = {
        "schemaVersion": SCHEMA_VERSION,
        "runId": run_id,
        "createdAtUtc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "apiUrl": api_base()[:-4],
        "serviceId": None,
        "tradeType": None,
        "personas": personas,
        "jobs": [],
    }

    def save():  # write after every persona so a failed run still leaves a usable partial manifest
        write_manifest(out, manifest)

    try:
        staff = []
        for n in range(1, args.staff + 1):
            p = mk_persona(run_id, "staff", n)
            personas.append(p)
            staff.append(p)
            provision_staff(p, admin)
            say("staff     %s" % p["email"])
            save()

        for n in range(1, args.homeowners + 1):
            p = mk_persona(run_id, "homeowner", n)
            personas.append(p)
            jwt = register_verified(p)
            p["userId"] = str((call("GET", "/profile", jwt) or {}).get("id") or "")
            p["verified"] = True
            say("homeowner %s" % p["email"])
            save()

        reviewer = staff_token_for_review(admin, staff) if args.tradies else None
        for n in range(1, args.tradies + 1):
            p = mk_persona(run_id, "tradie", n)
            personas.append(p)
            jwt = register_verified(p)
            if manifest["serviceId"] is None:
                manifest["serviceId"], manifest["tradeType"] = pick_service(jwt, args.service_id)
            onboard_tradie(p, jwt, manifest["serviceId"], manifest["tradeType"], reviewer, run_id)
            say("tradie    %s  (credential %s approved, $%s/h, payout ••%s)" % (p["email"], p["credentialId"], p["hourlyRate"], p["bankAccountLast4"]))
            save()
    except Unreachable:
        raise
    except StepFailed as e:
        save()
        print("\nPROVISIONING FAILED: %s\n(partial manifest: %s)" % (e, out))
        return 1

    save()
    print("\nPERSONAS OK: %d accounts -> %s" % (len(personas), out))
    print("MANIFEST=%s" % out)  # greppable by run-e2e.sh
    return 0


def cleanup(manifest_path: str) -> int:
    path = Path(manifest_path)
    if not path.is_file():
        print("manifest not found: %s" % path, file=sys.stderr)
        return 2
    manifest = json.loads(path.read_text())
    admin = admin_login()
    failed = 0
    for p in manifest.get("personas", []):
        if not (p.get("email", "").startswith("qa+") and p["email"].endswith("@" + EMAIL_DOMAIN)):
            print("  skip     %s (not a qa+ persona)" % p.get("email"))
            continue
        if not p.get("userId"):
            print("  skip     %s (no userId recorded)" % p["email"])
            continue
        try:
            call("POST", "/admin/users/%s/deactivate" % urllib.parse.quote(p["userId"]), admin)
            print("  deactivated %s" % p["email"])
        except StepFailed as e:
            failed += 1
            print("  FAIL     %s: %s" % (p["email"], e))
    print("cleanup done (%d failures); rows remain in the DB, logins are disabled" % failed)
    return 1 if failed else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--run-id", help="slug for qa+<runid>-... emails (default: UTC timestamp)")
    ap.add_argument("--homeowners", type=int, default=2)
    ap.add_argument("--tradies", type=int, default=3)
    ap.add_argument("--staff", type=int, default=1, choices=[0, 1, 2],
                    help="staff accounts via superadmin invite (0 = superadmin reviews the tradie credentials)")
    ap.add_argument("--service-id", help="service every tradie bids on (default: 1, the id e2e-journey.py uses)")
    ap.add_argument("--out", help="manifest path (default: test-logs/e2e-personas-<runid>/manifest.json)")
    ap.add_argument("--cleanup", metavar="MANIFEST", help="deactivate every account in MANIFEST and exit")
    ap.add_argument("--retry", type=int, default=0, help="retry transient HTTP errors N times (default 0)")
    ap.add_argument("--timeout", type=float, default=15.0, help="per-request timeout seconds (default 15)")
    args = ap.parse_args()

    OPTS["retry"], OPTS["timeout"] = max(0, args.retry), args.timeout
    args.run_id = re.sub(r"[^a-z0-9]", "", (args.run_id or datetime.now(timezone.utc).strftime("%m%d%H%M%S")).lower())
    if not args.run_id:
        print("--run-id must contain letters or digits", file=sys.stderr)
        return 2
    if args.homeowners < 1 and not args.cleanup:
        print("need at least 1 homeowner", file=sys.stderr)
        return 2

    try:
        api_base(), mailhog_base()  # fail on unsafe targets before touching anything
        return cleanup(args.cleanup) if args.cleanup else provision(args)
    except Unreachable as e:
        print("\nUNREACHABLE: %s" % e)
        return 2


if __name__ == "__main__":
    sys.exit(main())
