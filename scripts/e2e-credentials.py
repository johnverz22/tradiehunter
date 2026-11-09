#!/usr/bin/env python3
"""Live end-to-end check of the admin tradie-credential review flow.

Covers the P1-07 backend contract that the P1-10 web queue consumes:

    GET  /admin/credentials/pending?page&pageSize  -> PagedResult<PendingCredentialDto>
    POST /admin/credentials/{id}/review            -> Approve, or Reject + RejectReason

It seeds three Pending credentials for one tradie profile, drives the endpoints,
asserts each response (200 / 400 / 404) and asserts the MVP verification rule
("verified while holding >= 1 approved credential") straight against the database.
Rows it created are deleted again unless --keep is passed.

Usage (from the repo root, dev stack up — `make docker`):

    python3 scripts/e2e-credentials.py                     # seed -> assert -> clean up
    python3 scripts/e2e-credentials.py --keep              # leave 3 Pending rows to poke the UI with
    python3 scripts/e2e-credentials.py --inspect           # print queue + verification state, change nothing
    python3 scripts/e2e-credentials.py --tradie-profile-id 5

Requires python3 (stdlib only) and the Docker Compose stack from
docker-compose.yml. Admin credentials default to the AdminSeed values in
backend/appsettings.Development.json; override with FIXO_API_URL,
FIXO_ADMIN_EMAIL and FIXO_ADMIN_PASSWORD.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_API = os.environ.get("FIXO_API_URL", "http://localhost:5000/api").rstrip("/")
DEFAULT_EMAIL = os.environ.get("FIXO_ADMIN_EMAIL", "admin@fixo.nz")
DEFAULT_PASSWORD = os.environ.get("FIXO_ADMIN_PASSWORD", "Admin1!Fixo")
PG_USER = os.environ.get("POSTGRES_USER", "fixo")
PG_DB = os.environ.get("POSTGRES_DB", "fixo")

SEEDED_TYPES = ["License", "Insurance", "Certification"]

RESULTS: list[tuple[str, bool, str]] = []


def check(label: str, ok: bool, detail: object = "") -> bool:
    """Record and print one assertion. Returns `ok` so callers can chain."""
    RESULTS.append((label, bool(ok), str(detail)))
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"\n        {detail}" if detail else ""))
    return bool(ok)


def die(message: str) -> None:
    print(f"\nERROR: {message}", file=sys.stderr)
    sys.exit(2)


# ── HTTP ───────────────────────────────────────────────────────────────────────


def request(method: str, path: str, token: str | None = None, body: object = None, timeout: float = 20.0):
    """Returns (status, parsed_body). HTTP errors are data, not exceptions."""
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{DEFAULT_API}{path}", data=payload, method=method)
    if payload is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status, raw = resp.status, resp.read().decode()
    except urllib.error.HTTPError as err:
        status, raw = err.code, err.read().decode()
    except urllib.error.URLError as err:
        die(f"cannot reach {DEFAULT_API} ({err.reason}) — is the dev stack up? `make docker`")
    try:
        return status, (json.loads(raw) if raw else None)
    except json.JSONDecodeError:
        return status, raw


def login(email: str, password: str) -> str:
    status, body = request("POST", "/auth/login", body={"email": email, "password": password})
    if status != 200 or not isinstance(body, dict) or not body.get("token"):
        die(f"admin login failed (status {status}, body {body!r}) — check AdminSeed credentials")
    return str(body["token"])


# ── Database ───────────────────────────────────────────────────────────────────


def psql(sql: str) -> str:
    """Runs psql inside the db container; returns the unaligned, tuple-only output."""
    cmd = [
        "docker", "compose", "exec", "-T", "db",
        "psql", "-U", PG_USER, "-d", PG_DB, "-tA", "-v", "ON_ERROR_STOP=1", "-c", sql,
    ]
    proc = subprocess.run(cmd, cwd=REPO_ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        die(f"psql failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return proc.stdout.strip()


def profiles_pending(profile_id: int | None = None) -> str:
    where = f'where "TradieProfileId" = {profile_id}' if profile_id else ""
    return psql(
        f'select "Id", "TradieProfileId", "Type", "Status", coalesce("RejectReason", \'-\') '
        f'from "TradieCredentials" {where} order by "Id";'
    )


def approved_count(profile_id: int) -> int:
    out = psql(
        f'select count(*) from "TradieCredentials" where "TradieProfileId" = {profile_id} '
        f"and \"Status\" = 'Approved';"
    )
    return int(out or 0)


def is_verified(profile_id: int) -> str:
    return psql(f'select "IsVerified" from "TradieProfiles" where "Id" = {profile_id};')


def recompute_verified(profile_id: int) -> None:
    """Mirrors the backend rule: verified while holding >= 1 approved credential."""
    psql(
        f'update "TradieProfiles" set "IsVerified" = exists ('
        f'select 1 from "TradieCredentials" c where c."TradieProfileId" = {profile_id} '
        f"and c.\"Status\" = 'Approved');"
    )

def seed_pending(profile_id: int) -> list[int]:
    rows = ", ".join(
        f"({profile_id}, '{ctype}', 'credentials/e2e-{ctype.lower()}.pdf', 'e2e-{ctype.lower()}.pdf', 'Pending')"
        for ctype in SEEDED_TYPES
    )
    out = psql(
        'insert into "TradieCredentials" '
        '("TradieProfileId", "Type", "FileKey", "OriginalFileName", "Status") '
        f'values {rows} returning "Id";'
    )
    return [int(line) for line in out.splitlines() if line.strip().isdigit()]


def queue(token: str, page: int = 1, page_size: int = 100) -> dict:
    status, body = request("GET", f"/admin/credentials/pending?page={page}&pageSize={page_size}", token=token)
    if status != 200 or not isinstance(body, dict):
        die(f"GET /admin/credentials/pending returned {status}: {body!r}")
    return body


# ── Flow ───────────────────────────────────────────────────────────────────────


def inspect(token: str, profile_id: int) -> None:
    body = queue(token)
    print(f"\nqueue: {body.get('totalCount')} pending (page {body.get('page')} of {body.get('totalPages')})")
    for item in body.get("items", []):
        print(f"  #{item.get('id')} {str(item.get('type')):<14} {item.get('tradieName')} "
              f"<{item.get('tradieEmail')}>  doc={item.get('originalFileName')}")
    print(f"\ntradie profile {profile_id}: IsVerified={is_verified(profile_id)}"
          f" (approved credentials: {approved_count(profile_id)})")
    print(f"\nall credential rows:\n{profiles_pending()}")


def main() -> int:
    global DEFAULT_API

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--token", help="reuse an existing admin JWT instead of logging in")
    parser.add_argument("--tradie-profile-id", type=int, help="TradieProfiles.Id to seed against (default: lowest id)")
    parser.add_argument("--keep", action="store_true",
                        help="leave the seeded rows behind (an approved row changes TradieProfile.IsVerified)")
    parser.add_argument("--inspect", action="store_true", help="print current state and exit without changing anything")
    parser.add_argument("--api-url", help=f"override the API base URL (default {DEFAULT_API})")
    args = parser.parse_args()

    if args.api_url:
        DEFAULT_API = args.api_url.rstrip("/")

    token = args.token or login(DEFAULT_EMAIL, DEFAULT_PASSWORD)
    check("admin login returns a JWT", bool(token), f"{len(token)} chars")

    profile_id = args.tradie_profile_id
    if profile_id is None:
        raw = psql('select "Id" from "TradieProfiles" order by "Id" limit 1;')
        if not raw.strip().isdigit():
            die("no TradieProfile rows exist — complete a tradie onboarding in the mobile app first")
        profile_id = int(raw)
    check("target tradie profile resolved", profile_id > 0, f"TradieProfiles.Id={profile_id}")

    if args.inspect:
        inspect(token, profile_id)
        return 0

    seeded = seed_pending(profile_id)
    if not check("seeded 3 Pending credentials", len(seeded) == 3, f"ids={seeded}"):
        return 2
    id_approve, id_reject, id_keep = seeded

    # ── GET queue ──────────────────────────────────────────────────────────────
    body = queue(token)
    items = body.get("items", [])
    ids = [item.get("id") for item in items]
    check("queue returns items + paging fields",
          all(key in body for key in ("items", "totalCount", "page", "pageSize", "totalPages")),
          f"totalCount={body.get('totalCount')} pageSize={body.get('pageSize')} totalPages={body.get('totalPages')}")
    check("all seeded rows are returned, oldest first",
          all(sid in ids for sid in seeded) and ids == sorted(ids), f"ids={ids}")
    sample = next((item for item in items if item.get("id") == id_approve), {})
    check("row carries the fields the web queue renders",
          all(sample.get(key) is not None for key in
              ("id", "type", "tradieUserId", "tradieName", "tradieEmail", "originalFileName", "downloadUrl")),
          f"keys={sorted(sample)}")
    check("downloadUrl is a private-bucket SAS link", "sig=" in str(sample.get("downloadUrl")),
          str(sample.get("downloadUrl"))[:110])


    # ── POST review: approve ───────────────────────────────────────────────────
    status, approved = request("POST", f"/admin/credentials/{id_approve}/review",
                               token=token, body={"status": "Approved"})
    check(f"approve #{id_approve} -> 200", status == 200, json.dumps(approved)[:200])
    check("approve response reports the credential as Approved",
          isinstance(approved, dict) and approved.get("status") == "Approved", (approved or {}).get("status"))
    check("approve clears RejectReason", isinstance(approved, dict) and not approved.get("rejectReason"),
          repr((approved or {}).get("rejectReason")))
    check("approve flips tradieIsVerified to true",
          isinstance(approved, dict) and approved.get("tradieIsVerified") is True,
          repr((approved or {}).get("tradieIsVerified")))

    # ── POST review: reject with reason ────────────────────────────────────────
    reason = "E2E check: policy lapsed, please upload the current certificate."
    status, rejected = request("POST", f"/admin/credentials/{id_reject}/review", token=token,
                               body={"status": "Rejected", "rejectReason": reason})
    check(f"reject #{id_reject} with reason -> 200", status == 200, json.dumps(rejected)[:200])
    check("reject response echoes status + reason",
          isinstance(rejected, dict) and rejected.get("status") == "Rejected"
          and rejected.get("rejectReason") == reason,
          f"status={(rejected or {}).get('status')} reason={(rejected or {}).get('rejectReason')!r}")
    check("tradie stays verified because an approved credential remains",
          isinstance(rejected, dict) and rejected.get("tradieIsVerified") is True,
          repr((rejected or {}).get("tradieIsVerified")))

    # ── POST review: validation + not-found ────────────────────────────────────
    status, bad = request("POST", f"/admin/credentials/{id_keep}/review", token=token, body={"status": "Rejected"})
    first_error = ""
    if isinstance(bad, list) and bad and isinstance(bad[0], dict):
        first_error = str(bad[0].get("errorMessage", ""))
    check("reject without a reason -> 400 with a validation error", status == 400, f"{status}: {bad!r}")
    check("validation error names the RejectReason field",
          "RejectReason" in first_error or "reject reason" in first_error.lower(), first_error)

    status, missing = request("POST", "/admin/credentials/999999999/review", token=token, body={"status": "Approved"})
    check("review of a missing credential -> 404 with a message", status == 404, f"{status}: {missing!r}")

    # ── Database state ─────────────────────────────────────────────────────────
    reviewed_row = next((row for row in profiles_pending(profile_id).splitlines()
                         if row.startswith(f"{id_approve}|")), "")
    check("reviewed row persists Status=Approved in the database", "|Approved|" in reviewed_row, reviewed_row)
    check("ReviewedById / ReviewedAtUtc were stamped",
          psql(f'select count(*) from "TradieCredentials" where "Id" = {id_approve} '
               f'and "ReviewedAtUtc" is not null and "ReviewedById" is not null;') == "1")
    approved_n = approved_count(profile_id)
    check("IsVerified matches the MVP rule (>= 1 approved credential)",
          is_verified(profile_id) == ("t" if approved_n > 0 else "f"),
          f"IsVerified={is_verified(profile_id)} approved={approved_n}")

    # ── Reviewed rows leave the queue ──────────────────────────────────────────
    remaining = [item.get("id") for item in queue(token).get("items", [])]
    check("reviewed credentials are no longer pending",
          id_approve not in remaining and id_reject not in remaining, f"pending ids={remaining}")
    check("the unreviewed credential is still pending", id_keep in remaining, f"#{id_keep}")

    # ── Clean up ───────────────────────────────────────────────────────────────
    if args.keep:
        print(f"\n--keep: left {seeded} in place "
              f"(tradie profile {profile_id} is now IsVerified={is_verified(profile_id)}).")
    else:
        psql(f'delete from "TradieCredentials" where "Id" in ({", ".join(str(i) for i in seeded)});')
        recompute_verified(profile_id)
        leftover = psql(f'select count(*) from "TradieCredentials" '
                        f'where "Id" in ({", ".join(str(i) for i in seeded)});')
        check("seeded rows removed and verification state restored",
              leftover == "0" and is_verified(profile_id) == ("t" if approved_count(profile_id) > 0 else "f"),
              f"IsVerified={is_verified(profile_id)} approved={approved_count(profile_id)}")

    failed = [label for label, ok, _ in RESULTS if not ok]
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    if failed:
        print("failed checks:\n  - " + "\n  - ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
