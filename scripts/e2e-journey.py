#!/usr/bin/env python3
"""scripts/e2e-journey.py — integrated homeowner + tradie journey, API only.

Drives one job through the whole marketplace lifecycle with both personas
acting on the same job, exactly as the mobile fixtures do
(mobile/integration_test/helpers/fixture_helper.dart), but in one run and
with a named step on every call:

  post job (homeowner) -> match -> offer arrives (tradie) -> accept
  -> [v2] Booked -> chat both ways -> check in -> check out
  -> homeowner approves -> AwaitingPayment -> receipt -> PaymentReview
  -> staff verifies -> Completed -> homeowner reviews tradie
  [v1: accept -> AwaitingPayment -> receipt -> verify -> Booked -> ... -> confirm]

Why it exists
  * It is the cheap gate in front of the device suites. The E1 baseline
    (docs/runs/v2/e2e-baseline-2026-11.md) found that payment, dispute,
    cancellation and job_lifecycle all died in fixture setup on a backend
    POST. Run this first and that drift shows up as one clear failing step
    instead of four unrelated red suites.
  * It needs no device, so it also runs in CI before the emulator boots.

Usage
  python3 scripts/e2e-journey.py                    # run the journey
  python3 scripts/e2e-journey.py --junit out.xml    # also write JUnit XML
  python3 scripts/e2e-journey.py --restore-tradies  # un-park demo tradie only
  python3 scripts/e2e-journey.py --manifest m.json  # use personas from e2e-personas.py
                                                    # (tradie is asked directly; see --match-mode)
                                                    # (first homeowner/tradie/staff) and
                                                    # append the job id to the manifest

Environment
  FIXO_API_URL   API base, default http://localhost:5000

Exit codes
  0 pass   1 a journey step failed   2 stack unreachable / accounts missing

Only ever point this at the local docker stack (a non-localhost FIXO_API_URL is
refused) with either the seeded *@fixo.test accounts or a persona manifest
(docs/todos/03_e2e_realignment_plan.md §3 rule 1; 08_e2e_persona_fabric_plan.md).
"""

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from decimal import Decimal
from xml.sax.saxutils import quoteattr

API_BASE = os.environ.get("FIXO_API_URL", "http://localhost:5000").rstrip("/")
API = API_BASE + "/api"

# Mirrors mobile/integration_test/helpers/test_config.dart.
HOMEOWNER = ("homeowner-a@fixo.test", "Test1234!")
TRADIE = ("tradie-verified@fixo.test", "Test1234!")
STAFF = ("staff@fixo.test", "Test1234!")
DEMO_TRADIE = ("tradie@fixo.nz", "Demo1!Fixo")  # competes for offers; parked
# Superadmin for the admin quote-settings scenario (same defaults as e2e-personas.py).
SUPERADMIN = (os.environ.get("FIXO_ADMIN_EMAIL", "admin@fixo.nz"),
              os.environ.get("FIXO_ADMIN_PASSWORD", "Admin1!Fixo"))

# Real-looking street address for fixture jobs (the API path bypasses the LINZ
# lookup, so any well-formed string works; keep it realistic for the demo).
DEMO_ADDRESS = "1 Queen Street, Auckland CBD, Auckland 1010"
HTTP_TIMEOUT = 15
POLL_TIMEOUT = 45
POLL_INTERVAL = 2

# Smallest valid PNG; a unique suffix defeats the server's receipt dedupe.
_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


class StepFailed(Exception):
    pass


class Unreachable(Exception):
    pass


# ── Persona manifest (scripts/e2e-personas.py) ───────────────────────────────

MANIFEST_PATH = None
TRADIES = []  # every tradie persona of the manifest (first one is TRADIE)
MATCH_MODE = "auto"  # auto | quick | direct (see --match-mode)


def require_local():
    host = (urllib.parse.urlparse(API_BASE).hostname or "").lower()
    if host not in ("localhost", "127.0.0.1", "::1"):
        raise Unreachable("refusing FIXO_API_URL %r: not localhost (local docker stack only)" % API_BASE)


def _read_manifest(path):
    with open(path) as f:
        return json.load(f)


def apply_manifest(path):
    """Rebind HOMEOWNER/TRADIE/STAFF to the first persona of each role."""
    global HOMEOWNER, TRADIE, STAFF, MANIFEST_PATH, TRADIES
    try:
        m = _read_manifest(path)
    except (OSError, ValueError) as e:
        raise Unreachable("cannot read manifest %s: %s" % (path, e))
    if m.get("schemaVersion") != 1:
        raise Unreachable("manifest %s has schemaVersion %r, expected 1" % (path, m.get("schemaVersion")))
    first = {}
    for p in m.get("personas", []):
        first.setdefault(p.get("role"), (p["email"], p["password"]))
    missing = [r for r in ("homeowner", "tradie", "staff") if r not in first]
    if missing:
        raise Unreachable("manifest %s has no %s persona (re-run e2e-personas.py with --staff 1)" % (path, "/".join(missing)))
    HOMEOWNER, TRADIE, STAFF = first["homeowner"], first["tradie"], first["staff"]
    TRADIES = [(p["email"], p["password"]) for p in m.get("personas", []) if p.get("role") == "tradie"]
    MANIFEST_PATH = path


def record_job(job_id, scenario):
    """Append the created job to the manifest so the mobile/web tiers can find it."""
    if not MANIFEST_PATH:
        return
    m = _read_manifest(MANIFEST_PATH)
    m.setdefault("jobs", []).append(
        {"id": job_id, "scenario": scenario, "homeownerEmail": HOMEOWNER[0], "tradieEmail": TRADIE[0]}
    )
    tmp = MANIFEST_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(m, f, indent=2)
        f.write("\n")
    os.replace(tmp, MANIFEST_PATH)  # atomic


# ── HTTP ─────────────────────────────────────────────────────────────────────


def _json_default(o):
    """Request bodies may carry Decimal amounts: integral values go out as ints
    (exact), others as floats (fine for the 2dp test amounts used here)."""
    if isinstance(o, Decimal):
        return int(o) if o == o.to_integral_value() else float(o)
    raise TypeError("cannot serialise %r" % (o,))


def _request(method, path, token=None, body=None, raw=None, content_type=None):
    headers = {}
    data = None
    if token:
        headers["Authorization"] = "Bearer " + token
    if raw is not None:
        data, headers["Content-Type"] = raw, content_type
    elif body is not None:
        data, headers["Content-Type"] = json.dumps(body, default=_json_default).encode(), "application/json"
    req = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as r:
            status, text = r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        status, text = e.code, e.read().decode("utf-8", "replace")
    except (urllib.error.URLError, OSError) as e:
        raise Unreachable("%s %s: %s" % (method, path, e))
    if status >= 400:
        raise StepFailed("%s %s -> HTTP %d: %s" % (method, path, status, text[:300]))
    if status == 204 or not text.strip():
        return None
    try:
        # Money is a JSON number server-side; parse it as Decimal so amounts
        # are compared exactly (never through binary floats).
        return json.loads(text, parse_float=Decimal)
    except ValueError:
        return {"_raw": text}


def get(path, token=None):
    return _request("GET", path, token)


def post(path, token=None, body=None):
    return _request("POST", path, token, body if body is not None else {})


def delete(path, token=None):
    return _request("DELETE", path, token)


def _upload_png(path, field_name, filename, token):
    boundary = "fixojourney%d" % int(time.time() * 1000)
    payload = _PNG + ("|fixo-journey-%d" % time.time_ns()).encode()
    head = (
        '--%s\r\nContent-Disposition: form-data; name="%s"; '
        'filename="%s"\r\nContent-Type: image/png\r\n\r\n' % (boundary, field_name, filename)
    ).encode()
    tail = ("\r\n--%s--\r\n" % boundary).encode()
    return _request(
        "POST",
        path,
        token,
        raw=head + payload + tail,
        content_type="multipart/form-data; boundary=" + boundary,
    )


def upload_receipt(job_id, token):
    return _upload_png("/jobs/%d/payment/upload-receipt" % job_id, "receipt", "receipt.png", token)


def upload_photo(job_id, token):
    return _upload_png("/jobs/%d/photos" % job_id, "files", "issue.png", token)


def login(creds):
    try:
        body = post("/auth/login", body={"email": creds[0], "password": creds[1]})
    except StepFailed as e:
        raise Unreachable(
            "cannot log in as %s (%s) — run: bash scripts/seed-test-accounts.sh"
            % (creds[0], str(e)[:160].replace("\n", " "))
        )
    token = (body or {}).get("token")
    if not token:
        raise Unreachable("login for %s returned no token: %r" % (creds[0], body))
    return token


def poll(desc, fn, timeout=POLL_TIMEOUT):
    end = time.time() + timeout
    last = None
    while time.time() < end:
        last = fn()
        if last:
            return last
        time.sleep(POLL_INTERVAL)
    raise StepFailed("timed out after %ds waiting for: %s" % (timeout, desc))


def status_of(job_id, token):
    return (get("/jobs/%d" % job_id, token) or {}).get("status")


def wait_status(job_id, token, expected):
    def check():
        s = status_of(job_id, token)
        return s == expected

    try:
        poll("job %d status == %s" % (job_id, expected), check)
    except StepFailed:
        raise StepFailed(
            "job %d never reached %s (now %s)" % (job_id, expected, status_of(job_id, token))
        )


# ── Competing tradie ─────────────────────────────────────────────────────────


def set_demo_tradie(available):
    """Park/unpark the demo tradie so the test tradie wins matching. No-op if
    the demo seed is absent (same behaviour as FixtureHelper)."""
    try:
        t = post("/auth/login", body={"email": DEMO_TRADIE[0], "password": DEMO_TRADIE[1]})
        post("/profile/availability", (t or {}).get("token"), {"available": available})
        return True
    except (StepFailed, Unreachable, AttributeError):
        return False


# ── Journey ──────────────────────────────────────────────────────────────────


class Recorder:
    def __init__(self):
        self.rows = []  # (name, seconds, error|None)

    def step(self, name, fn):
        t0 = time.time()
        print("  %-52s" % name, end="", flush=True)
        try:
            out = fn()
        except Unreachable:
            print("UNREACHABLE")
            raise
        except Exception as e:  # noqa: BLE001 — report any failure as a step failure
            dt = time.time() - t0
            self.rows.append((name, dt, str(e)))
            print("FAIL (%.1fs)\n    -> %s" % (dt, e))
            raise StepFailed("%s: %s" % (name, e))
        dt = time.time() - t0
        self.rows.append((name, dt, None))
        print("ok   (%.1fs)" % dt)
        return out


# ── Response assertions (plan 08 P2.2) ───────────────────────────────────────
# Field names come from backend/DTOs/JobDTOs.cs (JobDto) and AdminDTOs.cs
# (admin job detail: statusHistory, chatTranscript).

# Order the v2 and v1 happy paths must pass through (subsequence check, so
# extra intermediate states do not fail the run).
PATH_V2 = ["Booked", "InProgress", "AwaitingConfirmation", "AwaitingPayment", "PaymentReview", "Completed"]
PATH_V1 = ["AwaitingPayment", "PaymentReview", "Booked", "InProgress", "AwaitingConfirmation", "Completed"]


def dec(v):
    """JSON number -> Decimal. .NET writes 85m as `85` and 85.5m as `85.5`, so a
    money field may arrive as int or Decimal; None/other stays None."""
    if isinstance(v, bool) or not isinstance(v, (int, Decimal)):
        return None
    return Decimal(v)


def need(cond, msg):
    if not cond:
        raise StepFailed(msg)


def is_subsequence(wanted, actual):
    it = iter(actual)
    return all(w in it for w in wanted)


def assert_booked(job, ho, tradie_id, flow):
    j = get("/jobs/%d" % job, ho) or {}
    need(j.get("status") == "Booked", "status is %r, expected Booked" % j.get("status"))
    need(int(j.get("flowVersion") or 1) == flow, "flowVersion changed to %r" % j.get("flowVersion"))
    need(j.get("matchedTradieId") == tradie_id,
         "matchedTradieId %r is not the persona tradie %r" % (j.get("matchedTradieId"), tradie_id))
    need(j.get("matchedTradieName"), "matchedTradieName missing on a Booked job")
    rate = dec(j.get("hourlyRate"))
    need(rate is not None and rate > 0, "hourlyRate snapshot missing/zero: %r" % j.get("hourlyRate"))
    return rate


def assert_completion_money(job, ho, rate, hours):
    j = get("/jobs/%d" % job, ho) or {}
    need(dec(j.get("finalHours")) == Decimal(hours), "finalHours %r != %s" % (j.get("finalHours"), hours))
    labour, final = dec(j.get("labourAmount")), dec(j.get("finalAmount"))
    adj = dec(j.get("adjustmentsTotal")) or Decimal(0)
    need(labour is not None and labour > 0, "labourAmount missing/zero: %r" % j.get("labourAmount"))
    # JobDto: FinalAmount = LabourAmount + AdjustmentsTotal (exact decimal maths).
    need(final == labour + adj, "finalAmount %r != labour %r + adjustments %r" % (final, labour, adj))
    need(dec(j.get("totalAmount")) == final, "totalAmount alias %r != finalAmount %r" % (j.get("totalAmount"), final))
    # Labour should be the rate snapshot x hours; reported rather than assumed
    # because rounding rules are the backend's call (SPECS.md).
    if labour != rate * Decimal(hours):
        print("    note: labourAmount %s != hourlyRate %s x %sh (rounding/min-charge rule?)" % (labour, rate, hours))


def assert_payment_open(job, ho, flow):
    """GET /jobs/{id}/payment right after approval (fields: backend PaymentDTOs;
    shape captured live from job 401 in plan 08's results log)."""
    pay = get("/jobs/%d/payment" % job, ho) or {}
    need(pay.get("jobId") == job, "payment.jobId %r != %d" % (pay.get("jobId"), job))
    need(pay.get("paymentId") is not None, "payment has no paymentId")
    amount = dec(pay.get("amount"))
    need(amount is not None and amount > 0, "payment.amount missing/zero: %r" % pay.get("amount"))
    if flow >= 2:
        # v2 pay-at-completion: the homeowner pays exactly the approved FinalAmount.
        j = get("/jobs/%d" % job, ho) or {}
        final = dec(j.get("finalAmount"))
        need(amount == final, "payment.amount %s != job.finalAmount %s" % (amount, final))
    need(pay.get("status") == "Pending", "payment.status %r before upload, expected Pending (seen live, job 402)" % pay.get("status"))
    need(str(job) in str(pay.get("reference") or ""), "payment.reference %r does not carry job id %d" % (pay.get("reference"), job))
    print("    (payment %s %s, status %r, canUploadReceipt=%r)" % (amount, pay.get("currency"), pay.get("status"), pay.get("canUploadReceipt")))
    return pay


def assert_payment_verified(job, ho, opened):
    pay = get("/jobs/%d/payment" % job, ho) or {}
    need(pay.get("paymentId") == opened.get("paymentId"), "paymentId changed during verification")
    need(dec(pay.get("amount")) == dec(opened.get("amount")), "payment.amount changed: %r -> %r" % (opened.get("amount"), pay.get("amount")))
    need(pay.get("status") == "Verified", "payment.status %r, expected Verified" % pay.get("status"))
    need(pay.get("canUploadReceipt") is False, "canUploadReceipt should be false once verified, got %r" % pay.get("canUploadReceipt"))
    need(pay.get("submittedAtUtc"), "submittedAtUtc not set after receipt upload")
    need(pay.get("verifiedAtUtc"), "verifiedAtUtc not set after verification")
    need(pay.get("reference") == opened.get("reference"), "payment.reference changed")


def assert_audit_trail(job, st, flow, markers):
    a = get("/admin/jobs/%d" % job, st) or {}
    seen = [h.get("toStatus") for h in sorted(a.get("statusHistory") or [], key=lambda h: h.get("changedAtUtc") or "")]
    wanted = PATH_V2 if flow >= 2 else PATH_V1
    need(is_subsequence(wanted, seen), "statusHistory %r does not contain %r in order" % (seen, wanted))
    texts = [m.get("content") for m in (a.get("chatTranscript") or [])]
    for marker in markers:
        need(marker in texts, "chat message %r missing from the admin transcript (%d messages)" % (marker, len(texts)))


def run_journey(rec):
    ctx = {}

    ctx["homeowner"] = rec.step("login homeowner", lambda: login(HOMEOWNER))
    ctx["tradie"] = rec.step("login tradie", lambda: login(TRADIE))
    ctx["staff"] = rec.step("login staff", lambda: login(STAFF))
    ho, tr, st = ctx["homeowner"], ctx["tradie"], ctx["staff"]

    rec.step("park competing demo tradie", lambda: set_demo_tradie(False))

    def create():
        body = post(
            "/jobs",
            ho,
            {
                "title": "Journey — %d" % int(time.time() * 1000),
                "description": "Integrated journey job.",
                "urgency": "Medium",
                "latitude": -36.8485,
                "longitude": 174.7633,
                "address": DEMO_ADDRESS,
                "serviceId": 1,
                "timingPreference": "Flexible",
                "estimatedHours": 2,
            },
        )
        if not body or "id" not in body:
            raise StepFailed("no job id in response: %r" % body)
        return int(body["id"])

    job = rec.step("homeowner posts job", create)
    record_job(job, "happy-path")
    flow = rec.step(
        "read job flowVersion",
        lambda: int((get("/jobs/%d" % job, ho) or {}).get("flowVersion") or 1),
    )
    print("    (flow version %d)" % flow)

    # Quick-match offers the top-ranked candidate first. Against the seeded
    # stack that is the test tradie (the demo tradie is parked), but with
    # persona-manifest runs the seeded tradie-verified account (rating 5.0)
    # outranks the unrated QA tradies and holds the offer for its whole window.
    # Manifest runs therefore ask the persona tradie directly (v2 only:
    # POST /jobs/{id}/request, OfferService.CreateDirectRequestAsync).
    direct = MATCH_MODE == "direct" or (MATCH_MODE == "auto" and MANIFEST_PATH and flow >= 2)
    if direct and flow < 2:
        raise StepFailed("direct requests need a v2 job (this job is flow %d); use --match-mode quick" % flow)
    direct_offer = {}

    if direct:
        def request_tradie():
            tradie_id = (get("/profile", tr) or {}).get("id")
            if not tradie_id:
                raise StepFailed("tradie /profile has no id")
            direct_offer.update(post("/jobs/%d/request" % job, ho, {"tradieId": tradie_id}) or {})
            if "id" not in direct_offer:
                raise StepFailed("no offer id in direct-request response: %r" % direct_offer)

        rec.step("homeowner requests the tradie directly", request_tradie)
    else:
        rec.step("homeowner dispatches matching", lambda: post("/jobs/%d/match" % job, ho))

    def offer():
        def pending():
            return _request("GET", "/jobs/%d/offers/pending" % job, tr)

        body = poll("pending offer for the test tradie", pending, 45)
        if direct and body.get("id") != direct_offer.get("id"):
            raise StepFailed(
                "tradie's pending offer %r is not the direct request %r" % (body.get("id"), direct_offer.get("id"))
            )
        return body

    offer_body = rec.step("tradie receives offer", offer)
    rec.step(
        "tradie accepts offer",
        lambda: post(
            "/jobs/%d/offers/%s/respond" % (job, offer_body["id"]), tr, {"response": "Accepted"}
        ),
    )

    if flow >= 2:
        rec.step("job Booked (no payment gate)", lambda: wait_status(job, ho, "Booked"))
    else:
        rec.step("job AwaitingPayment (v1)", lambda: wait_status(job, ho, "AwaitingPayment"))

        def pay_v1():
            pay = get("/jobs/%d/payment" % job, ho)
            upload_receipt(job, ho)
            wait_status(job, ho, "PaymentReview")
            post("/admin/payments/%s/verify" % pay["paymentId"], st)
            wait_status(job, ho, "Booked")

        rec.step("v1 receipt -> staff verify -> Booked", pay_v1)

    tradie_id = (get("/profile", tr) or {}).get("id")
    rate = rec.step("assert Booked job: tradie, flow, rate", lambda: assert_booked(job, ho, tradie_id, flow))

    # Chat both ways once the job is Booked (chat opens at Booked/InProgress).
    rec.step(
        "homeowner -> tradie chat",
        lambda: post("/jobs/%d/messages" % job, ho, {"content": "journey: homeowner hello"}),
    )
    rec.step(
        "tradie -> homeowner chat",
        lambda: post("/jobs/%d/messages" % job, tr, {"content": "journey: tradie on my way"}),
    )

    rec.step("tradie checks in", lambda: post("/jobs/%d/check-in" % job, tr))
    rec.step("job InProgress (both personas agree)", lambda: (
        wait_status(job, tr, "InProgress"), wait_status(job, ho, "InProgress")))
    rec.step("tradie checks out (2h)", lambda: post("/jobs/%d/check-out" % job, tr, {"finalHours": 2}))
    rec.step("job AwaitingConfirmation", lambda: wait_status(job, ho, "AwaitingConfirmation"))
    rec.step("assert completion money (exact decimals)", lambda: assert_completion_money(job, ho, rate, "2"))

    if flow >= 2:
        rec.step("homeowner approves itemised amount", lambda: post("/jobs/%d/approve" % job, ho))
        rec.step("job AwaitingPayment", lambda: wait_status(job, ho, "AwaitingPayment"))

        opened = {}

        def pay_v2():
            opened.update(assert_payment_open(job, ho, flow))  # also opens the payment
            need(opened.get("canUploadReceipt") is not False, "canUploadReceipt is false before any upload")
            upload_receipt(job, ho)

        rec.step("payment open: amount == finalAmount, reference", pay_v2)
        rec.step("job PaymentReview", lambda: wait_status(job, ho, "PaymentReview"))
        rec.step(
            "staff verifies payment",
            lambda: post("/admin/payments/%s/verify" % opened["paymentId"], st),
        )
        rec.step("job Completed (payment verified)", lambda: wait_status(job, ho, "Completed"))
        rec.step("payment Verified, amount unchanged", lambda: assert_payment_verified(job, ho, opened))
    else:
        rec.step("homeowner confirms completion (v1)", lambda: post("/jobs/%d/confirm" % job, ho))

    rec.step("job Completed", lambda: wait_status(job, ho, "Completed"))
    rec.step("tradie sees Completed too", lambda: wait_status(job, tr, "Completed"))
    rec.step(
        "staff audit: status history + chat transcript",
        lambda: assert_audit_trail(job, st, flow, ["journey: homeowner hello", "journey: tradie on my way"]),
    )

    def review():
        tradie_id = (get("/profile", tr) or {}).get("id")
        if not tradie_id:
            raise StepFailed("tradie /profile has no id")
        post("/jobs/%d/reviews" % job, ho, {"revieweeId": tradie_id, "rating": 5, "comment": "journey"})

    rec.step("homeowner reviews tradie", review)
    return job



def expect_http_error(desc, fn):
    """The call must be rejected (HTTP >= 400). Unreachable still propagates."""
    try:
        fn()
    except StepFailed:
        return
    raise StepFailed("%s: expected an HTTP error but the call succeeded" % desc)


def http_status(method, path, token=None, body=None):
    """Like _request but returns the HTTP status instead of raising on >= 400."""
    headers, data = {}, None
    if token:
        headers["Authorization"] = "Bearer " + token
    if body is not None:
        data, headers["Content-Type"] = json.dumps(body, default=_json_default).encode(), "application/json"
    req = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except (urllib.error.URLError, OSError) as e:
        raise Unreachable("%s %s: %s" % (method, path, e))


def expect_http_status(desc, fn, code):
    """fn must return the exact HTTP status `code` (stricter than expect_http_error)."""
    got = fn()
    need(got == code, "%s: expected HTTP %d, got %r" % (desc, code, got))


def parse_utc(value):
    """ISO-8601 string from the API -> aware datetime, or None.

    Python 3.9's fromisoformat rejects fractional seconds that are not exactly
    3 or 6 digits, but .NET emits a variable count (7/6/5/4 digits), so normalise
    to exactly 6 before parsing.
    """
    if not value:
        return None
    m = re.match(
        r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})?$",
        str(value).strip(),
    )
    if not m:
        return None
    base, frac, tz = m.group(1), (m.group(2) or "")[:6].ljust(6, "0"), m.group(3) or "Z"
    try:
        return datetime.fromisoformat("%s.%s%s" % (base, frac, "+00:00" if tz == "Z" else tz))
    except ValueError:
        return None


def submit_quote(job, token, amount):
    """Fixed-price quote. GST must match the tradie's registration (D8), which
    the persona fabric does not set, so retry once with the opposite flag."""
    body = {"pricingModel": "Fixed", "amount": amount, "materialsIncluded": False, "gstIncluded": False}
    try:
        return post("/jobs/%d/quotes" % job, token, body)
    except StepFailed as e:
        if "GST" not in str(e):
            raise
        body["gstIncluded"] = True
        return post("/jobs/%d/quotes" % job, token, body)


def quote_counts(job, token):
    """(quotesRequested, quotesReceived) from GET /jobs/{id}; nulls stay None."""
    j = get("/jobs/%d" % job, token) or {}
    return j.get("quotesRequested"), j.get("quotesReceived")


def poll_counts(job, token, want):
    """Poll until the job's quote counts equal `want` (offers/quotes can lag)."""
    poll("quote counts %r on job %d" % (want, job), lambda: quote_counts(job, token) == want)


def job_list_row(job, token):
    """Find the job row in GET /jobs (JobListResponse.Items), or None."""
    res = get("/jobs?pageSize=50", token) or {}
    for row in res.get("items") or []:
        if row.get("id") == job:
            return row
    return None


def list_quote_counts(job, token, want):
    """Assert the jobs-list row carries the same counts as the detail DTO."""
    row = job_list_row(job, token)
    need(row is not None, "job %d not found in the homeowner jobs list" % job)
    got = (row.get("quotesRequested"), row.get("quotesReceived"))
    need(got == want, "jobs-list counts for job %d are %r, expected %r" % (job, got, want))


def _get_quote_settings(token):
    return get("/admin/settings/quotes", token) or {}


def _find_quote(job, token, quote_id):
    for q in get("/jobs/%d/quotes" % job, token) or []:
        if q.get("id") == quote_id:
            return q
    raise StepFailed("quote %r not found on job %d" % (quote_id, job))


def available_job_ids(token):
    """Tradie available-jobs board as {job_id: item}."""
    res = get("/tradie/available-jobs?pageSize=50", token) or {}
    return {j.get("id"): j for j in (res.get("items") or [])}





def run_competing_quotes(rec):
    """Plan 08 P2.4: a Project job, three tradies quote, the homeowner accepts
    one. Accepting must book the job at that quote's pricing and decline the
    rest atomically (QuoteService.AcceptQuoteAsync). Project jobs are the only
    place real competition exists (SPECS.md s3); hourly jobs take one pending
    request at a time."""
    if not MANIFEST_PATH or len(TRADIES) < 3:
        raise Unreachable(
            "competing-quotes needs --manifest with >= 3 tradies (e2e-personas.py --tradies 3); have %d"
            % len(TRADIES)
        )
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tokens = [rec.step("login tradie %d" % (i + 1), lambda c=c: login(c)) for i, c in enumerate(TRADIES[:3])]
    ids = [(get("/profile", t) or {}).get("id") for t in tokens]
    need(all(ids) and len(set(ids)) == 3, "could not read 3 distinct tradie ids: %r" % ids)
    amounts = [Decimal("1500"), Decimal("1700"), Decimal("1900")]  # below the s362F threshold used by v2_flows_test
    winner = 1  # the middle quote wins, so first/last both have to be declined

    def create():
        body = post("/jobs", ho, {
            "title": "Quotes — %d" % int(time.time() * 1000),
            "description": "Competing quotes journey job.",
            "urgency": "Medium", "latitude": -36.8485, "longitude": 174.7633,
            "address": DEMO_ADDRESS, "serviceId": 1, "timingPreference": "Flexible",
            "jobType": "Project", "budgetMin": 1200, "budgetMax": 2400,
            "scopeNotes": "Competing quotes journey scope.",
        })
        need(body and "id" in body, "no job id in response: %r" % body)
        return int(body["id"])

    job = rec.step("homeowner posts Project job", create)
    record_job(job, "competing-quotes")
    flow = int((get("/jobs/%d" % job, ho) or {}).get("flowVersion") or 1)
    need(flow >= 2, "quotes need a v2 job, got flow %d" % flow)

    for i, tid in enumerate(ids):
        rec.step("homeowner requests a quote from tradie %d" % (i + 1),
                 lambda tid=tid: post("/jobs/%d/request" % job, ho, {"tradieId": tid}))

    rec.step("job shows 3 requested, 0 received", lambda: poll_counts(job, ho, (3, 0)))

    def tradie_counts_hidden():
        j = get("/jobs/%d" % job, tokens[0]) or {}
        need(j.get("quotesRequested") is None and j.get("quotesReceived") is None,
             "tradie sees counts %r/%r, expected null (homeowner-only)"
             % (j.get("quotesRequested"), j.get("quotesReceived")))

    rec.step("tradie view has null quote counts", tradie_counts_hidden)

    quote_ids = []
    for i, (tok, amt) in enumerate(zip(tokens, amounts)):
        def q(tok=tok, amt=amt):
            quote_ids.append(int(submit_quote(job, tok, amt)["id"]))
        rec.step("tradie %d submits Fixed quote %s" % (i + 1, amt), q)
        n = i + 1
        rec.step("counts show 3 requested, %d received" % n, lambda n=n: poll_counts(job, ho, (3, n)))
        rec.step("homeowner list shows 3 requested, %d received" % n,
                 lambda n=n: list_quote_counts(job, ho, (3, n)))
    # Order of GET results is not guaranteed; key everything by quote id.

    def before_accept():
        quotes = get("/jobs/%d/quotes" % job, ho)
        need(isinstance(quotes, list) and len(quotes) == 3, "expected 3 quotes, got %r" % quotes)
        by_id = {q["id"]: q for q in quotes}
        for qid, tid, amt in zip(quote_ids, ids, amounts):
            q = by_id.get(qid)
            need(q is not None, "quote %d missing from the homeowner list" % qid)
            need(q.get("status") == "Submitted", "quote %d status %r, expected Submitted" % (qid, q.get("status")))
            need(q.get("tradieId") == tid, "quote %d belongs to %r, expected %r" % (qid, q.get("tradieId"), tid))
            need(q.get("pricingModel") == "Fixed" and dec(q.get("amount")) == amt,
                 "quote %d is %r %r, expected Fixed %s" % (qid, q.get("pricingModel"), q.get("amount"), amt))
        need(status_of(job, ho) == "Requested", "job should stay Requested until a quote is accepted")

    rec.step("homeowner sees 3 Submitted quotes at the right prices", before_accept)

    win_id, win_tradie, win_amt = quote_ids[winner], ids[winner], amounts[winner]
    rec.step("homeowner accepts the middle quote",
             lambda: post("/jobs/%d/quotes/%d/accept" % (job, win_id), ho, {"confirmWrittenContract": False}))
    rec.step("job Booked", lambda: wait_status(job, ho, "Booked"))
    rec.step("counts are null once booked", lambda: poll_counts(job, ho, (None, None)))

    def after_accept():
        j = get("/jobs/%d" % job, ho) or {}
        need(j.get("matchedTradieId") == win_tradie, "matchedTradieId %r is not the accepted tradie" % j.get("matchedTradieId"))
        need(j.get("agreedPricingModel") == "Fixed", "agreedPricingModel %r, expected Fixed" % j.get("agreedPricingModel"))
        need(dec(j.get("estimatedTotal")) == win_amt, "estimatedTotal %r != accepted quote %s" % (j.get("estimatedTotal"), win_amt))
        by_id = {q["id"]: q for q in get("/jobs/%d/quotes" % job, ho)}
        for qid in quote_ids:
            want = "Accepted" if qid == win_id else "Declined"
            need(by_id[qid].get("status") == want, "quote %d is %r, expected %s" % (qid, by_id[qid].get("status"), want))

    rec.step("accepted quote books the job; the others are Declined", after_accept)

    def no_pending_offers():
        for i, tok in enumerate(tokens):
            need(_request("GET", "/jobs/%d/offers/pending" % job, tok) is None,
                 "tradie %d still has a pending offer after the job booked" % (i + 1))

    rec.step("no tradie has a pending offer left", no_pending_offers)

    for i in (0, 2):
        rec.step("declined tradie %d cannot check in" % (i + 1),
                 lambda i=i: expect_http_error("check-in by a declined tradie",
                                               lambda: post("/jobs/%d/check-in" % job, tokens[i])))
    rec.step("accepted tradie checks in", lambda: post("/jobs/%d/check-in" % job, tokens[winner]))
    rec.step("job InProgress", lambda: wait_status(job, ho, "InProgress"))
    return job


def _create_hourly_job(ho, prefix="Hourly", lat=-36.8485, lng=174.7633, address=DEMO_ADDRESS):
    body = post("/jobs", ho, {
        "title": "%s — %d" % (prefix, int(time.time() * 1000)),
        "description": "%s journey job." % prefix,
        "urgency": "Medium", "latitude": lat, "longitude": lng,
        "address": address, "serviceId": 1, "timingPreference": "Flexible",
        "jobType": "Hourly", "estimatedHours": 2,
    })
    need(body and "id" in body, "no job id in response: %r" % body)
    return int(body["id"])


def _create_project_job(ho, prefix="Quotes", lat=-36.8485, lng=174.7633,
                        address=DEMO_ADDRESS, open_to_board=False, budget=(1200, 2400)):
    """Project job. open_to_board=False keeps the invite-only path (D4); true
    posts it to the tradie board (plan 10 Q7)."""
    body = post("/jobs", ho, {
        "title": "%s — %d" % (prefix, int(time.time() * 1000)),
        "description": "%s journey job." % prefix,
        "urgency": "Medium", "latitude": lat, "longitude": lng,
        "address": address, "serviceId": 1, "timingPreference": "Flexible",
        "jobType": "Project", "budgetMin": budget[0], "budgetMax": budget[1],
        "scopeNotes": "%s journey scope." % prefix,
        "openToBoard": bool(open_to_board),
    })
    need(body and "id" in body, "no job id in response: %r" % body)
    return int(body["id"])


def _book_direct(rec, job, ho, tr, tr_id, label="tradie"):
    rec.step("request %s directly" % label, lambda: post("/jobs/%d/request" % job, ho, {"tradieId": tr_id}))
    offer_id = rec.step(
        "%s receives offer" % label,
        lambda: poll("offer for %s on job %d" % (label, job),
                     lambda: (get("/jobs/%d/offers/pending" % job, tr) or {}).get("id")),
    )
    rec.step("%s accepts offer" % label,
             lambda: post("/jobs/%d/offers/%d/respond" % (job, offer_id), tr, {"response": "Accepted"}))
    rec.step("job Booked", lambda: wait_status(job, ho, "Booked"))
    return offer_id


def run_hourly_decline_reoffer(rec):
    """Plan 08 P2.4 (hourly sequential) & P2.5 (decline): tradie 1 declines
    the offer, job stays Requested, then tradie 2 receives and accepts."""
    if not MANIFEST_PATH or len(TRADIES) < 2:
        raise Unreachable("hourly-decline-reoffer needs --manifest with >= 2 tradies")
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tr1 = rec.step("login tradie 1", lambda: login(TRADIES[0]))
    tr2 = rec.step("login tradie 2", lambda: login(TRADIES[1]))
    id1 = (get("/profile", tr1) or {}).get("id")
    id2 = (get("/profile", tr2) or {}).get("id")
    need(id1 and id2 and id1 != id2, "need 2 distinct tradie ids: %r, %r" % (id1, id2))

    job = rec.step("homeowner posts hourly job", lambda: _create_hourly_job(ho, "Decline"))
    record_job(job, "hourly-decline-reoffer")

    rec.step("request tradie 1", lambda: post("/jobs/%d/request" % job, ho, {"tradieId": id1}))
    offer1 = rec.step(
        "tradie 1 receives offer",
        lambda: poll("offer 1 on job %d" % job,
                     lambda: (get("/jobs/%d/offers/pending" % job, tr1) or {}).get("id")),
    )
    rec.step("tradie 1 declines offer",
             lambda: post("/jobs/%d/offers/%d/respond" % (job, offer1), tr1, {"response": "Declined"}))

    def still_requested():
        j = get("/jobs/%d" % job, ho) or {}
        need(j.get("status") == "Requested", "expected Requested after decline, got %r" % j.get("status"))
        need(j.get("matchedTradieId") is None, "matchedTradieId should be None after decline")

    rec.step("job stays Requested with no matched tradie", still_requested)
    _book_direct(rec, job, ho, tr2, id2, "tradie 2")
    return job


def run_withdraw_no_match_repost(rec):
    """Plan 08 P2.5: job with no matches -> homeowner withdraws -> re-posts
    in Auckland -> cancels via POST /cancel."""
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    # Invercargill coordinates: outside Auckland tradies' 25 km service radius.
    no_match_job = rec.step(
        "post remote job (no matches)",
        lambda: _create_hourly_job(ho, "NoMatch", lat=-46.4132, lng=168.3538, address="1 Tay St, Invercargill"),
    )
    record_job(no_match_job, "withdraw-no-match")

    def check_no_matches():
        res = get("/jobs/%d/matches" % no_match_job, ho) or {}
        matches = res.get("matches", res) if isinstance(res, dict) else res
        need(isinstance(matches, list) and len(matches) == 0, "expected 0 matches, got %r" % res)

    rec.step("confirm 0 matches in remote area", check_no_matches)
    rec.step("homeowner withdraws remote job (DELETE)", lambda: delete("/jobs/%d" % no_match_job, ho))
    rec.step("remote job Cancelled", lambda: wait_status(no_match_job, ho, "Cancelled"))

    repost_job = rec.step("homeowner re-posts job in Auckland", lambda: _create_hourly_job(ho, "Repost"))
    record_job(repost_job, "repost")
    rec.step(
        "homeowner cancels re-posted job (POST /cancel)",
        lambda: post("/jobs/%d/cancel" % repost_job, ho,
                     {"reasonCode": "homeowner_changed_mind", "notes": "repost withdraw"}),
    )
    rec.step("re-posted job Cancelled", lambda: wait_status(repost_job, ho, "Cancelled"))
    return repost_job


def run_cancellations(rec):
    """Plan 08 P2.6: tradie cancels Booked -> reverts to Requested; homeowner
    cancels Booked -> Cancelled; homeowner cancels InProgress -> Cancelled."""
    if not MANIFEST_PATH or len(TRADIES) < 2:
        raise Unreachable("cancellations needs --manifest with >= 2 tradies")
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tr1 = rec.step("login tradie 1", lambda: login(TRADIES[0]))
    tr2 = rec.step("login tradie 2", lambda: login(TRADIES[1]))
    id1 = (get("/profile", tr1) or {}).get("id")
    id2 = (get("/profile", tr2) or {}).get("id")

    job1 = rec.step("post job for tradie+ho Booked cancel", lambda: _create_hourly_job(ho, "CancelBooked"))
    record_job(job1, "cancellations-booked")
    _book_direct(rec, job1, ho, tr1, id1, "tradie 1")

    rec.step(
        "tradie 1 cancels Booked job",
        lambda: post("/jobs/%d/cancel" % job1, tr1,
                     {"reasonCode": "tradie_unavailable", "notes": "cannot make it"}),
    )

    def reverted_to_requested():
        j = get("/jobs/%d" % job1, ho) or {}
        need(j.get("status") == "Requested", "expected Requested after tradie cancel, got %r" % j.get("status"))
        need(j.get("matchedTradieId") is None, "matchedTradieId not cleared on tradie cancel")

    rec.step("job reverts to Requested with no matched tradie", reverted_to_requested)

    job1b = rec.step("post job for homeowner Booked cancel", lambda: _create_hourly_job(ho, "CancelHoBooked"))
    record_job(job1b, "cancellations-ho-booked")
    _book_direct(rec, job1b, ho, tr2, id2, "tradie 2")
    rec.step(
        "homeowner cancels Booked job",
        lambda: post("/jobs/%d/cancel" % job1b, ho,
                     {"reasonCode": "homeowner_changed_mind", "notes": "no longer needed"}),
    )
    rec.step("job 1b Cancelled", lambda: wait_status(job1b, ho, "Cancelled"))
    rec.step(
        "cannot review Cancelled job",
        lambda: expect_http_error(
            "review on Cancelled job",
            lambda: post("/jobs/%d/reviews" % job1b, ho, {"revieweeId": id2, "rating": 5, "comment": "nope"}),
        ),
    )

    job2 = rec.step("post job for InProgress cancel", lambda: _create_hourly_job(ho, "CancelInProg"))
    record_job(job2, "cancellations-inprogress")
    _book_direct(rec, job2, ho, tr1, id1, "tradie 1")
    rec.step("tradie 1 checks in", lambda: post("/jobs/%d/check-in" % job2, tr1))
    rec.step("job 2 InProgress", lambda: wait_status(job2, ho, "InProgress"))
    rec.step(
        "homeowner cancels InProgress job",
        lambda: post("/jobs/%d/cancel" % job2, ho,
                     {"reasonCode": "homeowner_issue", "notes": "work stopped"}),
    )
    rec.step("job 2 Cancelled", lambda: wait_status(job2, ho, "Cancelled"))
    return job2


def run_receipt_reject_resubmit(rec):
    """Plan 08 P2.7: staff rejects receipt -> AwaitingPayment -> homeowner
    resubmits -> staff verifies -> Completed."""
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tr = rec.step("login tradie", lambda: login(TRADIE))
    st = rec.step("login staff", lambda: login(STAFF))
    tid = (get("/profile", tr) or {}).get("id")

    job = rec.step("post job for receipt reject", lambda: _create_hourly_job(ho, "ReceiptReject"))
    record_job(job, "receipt-reject-resubmit")
    _book_direct(rec, job, ho, tr, tid, "tradie")
    rec.step("tradie checks in", lambda: post("/jobs/%d/check-in" % job, tr))
    rec.step("job InProgress", lambda: wait_status(job, ho, "InProgress"))
    rec.step("tradie checks out", lambda: post("/jobs/%d/check-out" % job, tr, {"finalHours": 2}))
    rec.step("job AwaitingConfirmation", lambda: wait_status(job, ho, "AwaitingConfirmation"))
    rec.step("homeowner approves", lambda: post("/jobs/%d/approve" % job, ho))
    rec.step("job AwaitingPayment", lambda: wait_status(job, ho, "AwaitingPayment"))

    pay_id = rec.step("read payment id", lambda: (get("/jobs/%d/payment" % job, ho) or {}).get("paymentId"))
    need(pay_id, "missing paymentId")

    rec.step("homeowner uploads first receipt", lambda: upload_receipt(job, ho))
    rec.step("job PaymentReview", lambda: wait_status(job, ho, "PaymentReview"))

    def check_receipt_notif():
        res = get("/admin/notifications?limit=20", st) or {}
        items = res.get("items") or []
        # Staff alerts key on the entity (payment:{id}); the job id only
        # appears in the title/body, so match the payment entity.
        need(
            any(
                i.get("type") == "receipt_awaiting_verification"
                and i.get("entityType") == "payment"
                and str(i.get("entityId")) == str(pay_id)
                for i in items
            ),
            "expected admin notification for receipt upload on job %d (payment %s), got %r" % (job, pay_id, items[:5]),
        )

    rec.step("admin notification created for receipt upload", check_receipt_notif)
    rec.step(
        "staff rejects receipt",
        lambda: post("/admin/payments/%d/reject" % pay_id, st, {"reason": "Blurry image, please re-upload"}),
    )
    rec.step("job returns to AwaitingPayment", lambda: wait_status(job, ho, "AwaitingPayment"))

    def check_rejected():
        p = get("/jobs/%d/payment" % job, ho) or {}
        need(p.get("canUploadReceipt") is True, "canUploadReceipt should be True after reject: %r" % p)
        need(int(p.get("reUploadCount") or 0) >= 1, "reUploadCount not incremented: %r" % p)

    rec.step("payment allows re-upload with reUploadCount >= 1", check_rejected)
    rec.step("homeowner resubmits receipt", lambda: upload_receipt(job, ho))
    rec.step("job PaymentReview again", lambda: wait_status(job, ho, "PaymentReview"))
    rec.step("staff verifies resubmitted receipt", lambda: post("/admin/payments/%d/verify" % pay_id, st))
    rec.step("job Completed", lambda: wait_status(job, ho, "Completed"))
    return job


def run_dispute_attachments_reviews(rec):
    """Plan 08 P2.8: attachment upload, negative review eligibility, chat both
    ways, dispute open + text evidence + staff resolve, then blind + positive
    reviews after completion."""
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tr = rec.step("login tradie", lambda: login(TRADIE))
    st = rec.step("login staff", lambda: login(STAFF))
    ho_id = (get("/profile", ho) or {}).get("id")
    tr_id = (get("/profile", tr) or {}).get("id")

    job = rec.step("post job for dispute+attachments+reviews", lambda: _create_hourly_job(ho, "DisputeReview"))
    record_job(job, "dispute-attachments-reviews")

    def upload_and_check():
        res = upload_photo(job, ho)
        need(isinstance(res, list) and len(res) == 1, "expected 1 uploaded photo, got %r" % res)

    rec.step("homeowner uploads photo attachment", upload_and_check)
    _book_direct(rec, job, ho, tr, tr_id, "tradie")

    rec.step(
        "cannot review before Completed",
        lambda: expect_http_error(
            "review while Booked",
            lambda: post("/jobs/%d/reviews" % job, ho, {"revieweeId": tr_id, "rating": 5, "comment": "too early"}),
        ),
    )

    rec.step("chat homeowner -> tradie", lambda: post("/jobs/%d/messages" % job, ho, {"content": "Hi tradie"}))
    rec.step("chat tradie -> homeowner", lambda: post("/jobs/%d/messages" % job, tr, {"content": "On my way"}))

    def check_chat():
        res = get("/jobs/%d/messages" % job, ho) or []
        msgs = (res.get("items") if "items" in res else res.get("messages", [])) if isinstance(res, dict) else res
        bodies = [m.get("content") for m in msgs]
        need("Hi tradie" in bodies and "On my way" in bodies, "missing chat messages: %r" % res)

    rec.step("GET messages has both directions", check_chat)

    rec.step("tradie checks in", lambda: post("/jobs/%d/check-in" % job, tr))
    rec.step("job InProgress", lambda: wait_status(job, ho, "InProgress"))

    dispute_id = rec.step(
        "homeowner opens dispute",
        lambda: (post("/disputes", ho, {"jobId": job, "reason": "Scope disagreement"}) or {}).get("id"),
    )
    need(dispute_id, "missing dispute id")
    rec.step(
        "homeowner adds dispute text evidence",
        lambda: post("/disputes/%d/evidence/text" % dispute_id, ho, {"textContent": "Photo attached earlier"}),
    )

    def staff_sees_dispute():
        d = get("/admin/disputes/%d" % job, st) or {}
        need(d.get("disputeStatus") == "Open" or d.get("isFlagged") is True, "dispute not visible to admin: %r" % d)

    rec.step("staff sees open dispute", staff_sees_dispute)
    rec.step(
        "staff resolves dispute",
        lambda: post("/admin/disputes/%d/resolve" % job, st, {"action": "Resolved", "note": "Agreed to continue"}),
    )

    rec.step("tradie checks out", lambda: post("/jobs/%d/check-out" % job, tr, {"finalHours": 2}))
    rec.step("job AwaitingConfirmation", lambda: wait_status(job, ho, "AwaitingConfirmation"))
    rec.step("homeowner approves", lambda: post("/jobs/%d/approve" % job, ho))
    rec.step("job AwaitingPayment", lambda: wait_status(job, ho, "AwaitingPayment"))
    pay_id = (get("/jobs/%d/payment" % job, ho) or {}).get("paymentId")
    rec.step("homeowner uploads receipt", lambda: upload_receipt(job, ho))
    rec.step("job PaymentReview", lambda: wait_status(job, ho, "PaymentReview"))
    rec.step("staff verifies payment", lambda: post("/admin/payments/%d/verify" % pay_id, st))
    rec.step("job Completed", lambda: wait_status(job, ho, "Completed"))

    rec.step(
        "homeowner submits review",
        lambda: post("/jobs/%d/reviews" % job, ho, {"revieweeId": tr_id, "rating": 5, "comment": "Great work"}),
    )
    rec.step(
        "tradie submits review",
        lambda: post("/jobs/%d/reviews" % job, tr, {"revieweeId": ho_id, "rating": 5, "comment": "Great homeowner"}),
    )

    def check_reviews():
        res = get("/jobs/%d/reviews" % job, ho) or {}
        items = res.get("items", res) if isinstance(res, dict) else res
        need(isinstance(items, list) and len(items) == 2, "expected 2 revealed reviews, got %r" % res)

    rec.step("both reviews revealed after both submit", check_reviews)

    def check_mailhog_for_dispute():
        mailhog = os.environ.get("MAILHOG_URL", "http://localhost:8025").rstrip("/")
        url = "%s/api/v2/search?kind=to&query=%s" % (mailhog, urllib.parse.quote(HOMEOWNER[0]))
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        items = data.get("items") or []
        need(len(items) > 0, "expected MailHog messages for %s, got 0" % HOMEOWNER[0])

    rec.step("MailHog received notification emails for homeowner", check_mailhog_for_dispute)
    return job


def run_homeowner_quotes_visibility(rec):
    """Plan 10 Q6.5: the data contract behind the Quotes badge/subtitle, the D4
    entry-point precondition, hourly jobs unchanged, and the s362F written-
    contract gate on accept.

    Push payload (E2E plan 1b step 5) is skipped on purpose: QuoteService
    notifies via SendPushToUserAsync, which pushes only and does not fall back
    to email, so MailHog has nothing to query. The `quote_submitted` route is
    covered by mobile/test/quote_discoverability_test.dart instead.
    """
    if not MANIFEST_PATH or len(TRADIES) < 2:
        raise Unreachable(
            "homeowner-quotes-visibility needs --manifest with >= 2 tradies; have %d" % len(TRADIES)
        )
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tr1 = rec.step("login tradie 1", lambda: login(TRADIES[0]))
    tr2 = rec.step("login tradie 2", lambda: login(TRADIES[1]))
    id1 = (get("/profile", tr1) or {}).get("id")
    id2 = (get("/profile", tr2) or {}).get("id")
    need(id1 and id2 and id1 != id2, "need 2 distinct tradie ids: %r, %r" % (id1, id2))

    # 1. Detail and list contract for a Project job with 2 requests, 1 quote.
    job = rec.step("homeowner posts Project job", lambda: _create_project_job(ho, "Visibility"))
    record_job(job, "homeowner-quotes-visibility")
    for tid in (id1, id2):
        rec.step("homeowner requests a quote from a tradie",
                 lambda tid=tid: post("/jobs/%d/request" % job, ho, {"tradieId": tid}))
    quote = rec.step("tradie 1 submits a Fixed quote",
                     lambda: submit_quote(job, tr1, Decimal("1500")))

    def detail_contract():
        need(quote.get("status") == "Submitted", "quote status %r, expected Submitted" % quote.get("status"))
        need(quote.get("pricingModel") == "Fixed", "quote pricingModel %r, expected Fixed" % quote.get("pricingModel"))
        need(quote.get("tradieId") == id1, "quote tradieId %r != tradie 1 %r" % (quote.get("tradieId"), id1))
        need(dec(quote.get("amount")) == Decimal("1500"), "quote amount %r != 1500" % quote.get("amount"))
        need(quote.get("validUntilUtc"), "quote validUntilUtc missing")
        quotes = get("/jobs/%d/quotes" % job, ho) or []
        need(isinstance(quotes, list) and len(quotes) == 1, "expected 1 quote, got %r" % quotes)
        q = quotes[0]
        need(q.get("id") == quote.get("id"), "list quote id %r != created %r" % (q.get("id"), quote.get("id")))
        need(q.get("status") == "Submitted", "list quote status %r, expected Submitted" % q.get("status"))
        need(parse_utc(q.get("validUntilUtc")) is not None,
             "validUntilUtc not parseable: %r" % q.get("validUntilUtc"))

    rec.step("GET /jobs/{id}/quotes returns the submitted quote", detail_contract)
    rec.step("counts show 2 requested, 1 received", lambda: poll_counts(job, ho, (2, 1)))
    rec.step("jobs list shows 2 requested, 1 received", lambda: list_quote_counts(job, ho, (2, 1)))

    # 2. D4 entry-point precondition: a Project job with no requests shows (0, 0).
    zero_job = rec.step("homeowner posts a Project job with no requests",
                        lambda: _create_project_job(ho, "NoRequests"))
    record_job(zero_job, "homeowner-quotes-zero-requests")
    rec.step("no-request job counts are 0, 0 (not null)", lambda: poll_counts(zero_job, ho, (0, 0)))

    # 3. Hourly jobs are unchanged (counts null).
    hourly = rec.step("homeowner posts an Hourly job", lambda: _create_hourly_job(ho, "VisibilityHourly"))
    record_job(hourly, "homeowner-quotes-hourly")
    rec.step("hourly job has null quote counts", lambda: poll_counts(hourly, ho, (None, None)))

    # 4. s362F written-contract gate. Each case needs its own job because
    # accepting books the job; all cases use tradie 1.
    def s362f_case(label, amount, expect_gate):
        case_job = _create_project_job(ho, "Contract" + label, budget=(1000, int(amount) + 1000))
        record_job(case_job, "homeowner-quotes-contract-" + label.lower())
        post("/jobs/%d/request" % case_job, ho, {"tradieId": id1})
        qid = int(submit_quote(case_job, tr1, amount)["id"])
        if expect_gate:
            expect_http_error(
                "%s: accept without contract confirmation is rejected" % label,
                lambda: post("/jobs/%d/quotes/%d/accept" % (case_job, qid), ho,
                             {"confirmWrittenContract": False}),
            )
            need(status_of(case_job, ho) == "Requested",
                 "%s: job left Requested after the gate" % label)
            quotes = get("/jobs/%d/quotes" % case_job, ho) or []
            need(any(x.get("id") == qid and x.get("status") == "Submitted" for x in quotes),
                 "%s: quote no longer Submitted after the gate" % label)
            post("/jobs/%d/quotes/%d/accept" % (case_job, qid), ho, {"confirmWrittenContract": True})
        else:
            post("/jobs/%d/quotes/%d/accept" % (case_job, qid), ho, {"confirmWrittenContract": False})
        wait_status(case_job, ho, "Booked")
        need(dec((get("/jobs/%d" % case_job, ho) or {}).get("estimatedTotal")) == amount,
             "%s: estimatedTotal != %s" % (label, amount))

    rec.step("s362F: 29999.99 books without confirmation",
             lambda: s362f_case("JustUnder", Decimal("29999.99"), expect_gate=False))
    rec.step("s362F: 30000.00 gates, then books when confirmed",
             lambda: s362f_case("At", Decimal("30000.00"), expect_gate=True))
    rec.step("s362F: 45000.00 gates, then books when confirmed",
             lambda: s362f_case("Over", Decimal("45000"), expect_gate=True))
    return job


def run_open_board_quotes(rec):
    """Plan 10 Q7.4-Q7.8 (open project board): an open Project job appears on the
    tradie board (suburb-masked, full details), a tradie quotes without an invite
    (one per tradie), invite-only / out-of-range / blocked jobs stay hidden, the
    close window is stamped at posting, and accepting a quote books the job.

    Board expiry (ExpirationWorker.ExpireBoardJobsAsync) is not asserted: the
    worker is not deterministically triggerable from this harness, so that rule
    stays with OpenBoardTests.cs / manual QA (noted in the plan).
    """
    if not MANIFEST_PATH or len(TRADIES) < 3:
        raise Unreachable("open-board-quotes needs --manifest with >= 3 tradies; have %d" % len(TRADIES))
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tr1 = rec.step("login tradie 1", lambda: login(TRADIES[0]))
    tr2 = rec.step("login tradie 2", lambda: login(TRADIES[1]))
    tr3 = rec.step("login tradie 3", lambda: login(TRADIES[2]))
    staff = rec.step("login staff", lambda: login(STAFF))
    id1 = (get("/profile", tr1) or {}).get("id")
    id2 = (get("/profile", tr2) or {}).get("id")
    id3 = (get("/profile", tr3) or {}).get("id")
    need(id1 and id2 and id3 and len({id1, id2, id3}) == 3, "need 3 distinct tradie ids")

    settings = rec.step("read quote settings", lambda: _get_quote_settings(staff))
    board_hours = settings.get("boardWindowHours")
    need(isinstance(board_hours, int) and 1 <= board_hours <= 720, "boardWindowHours %r" % board_hours)

    job = rec.step("homeowner posts an open Project job",
                   lambda: _create_project_job(ho, "OpenBoard", open_to_board=True))
    record_job(job, "open-board-quotes")

    def stamped():
        j = get("/jobs/%d" % job, ho) or {}
        need(j.get("openToBoard") is True, "openToBoard %r, expected true" % j.get("openToBoard"))
        close, created = parse_utc(j.get("quotesCloseAtUtc")), parse_utc(j.get("createdAtUtc"))
        need(close is not None, "quotesCloseAtUtc missing on an open job")
        need(created is not None, "createdAtUtc missing")
        hours = (close - created).total_seconds() / 3600.0
        need(abs(hours - board_hours) <= (5 / 60.0),
             "close window is %.2f h, expected ~%d h" % (hours, board_hours))

    rec.step("open job has openToBoard and a stamped close window", stamped)

    def listed():
        item = available_job_ids(tr1).get(job)
        need(item is not None, "job %d is not on tradie 1's available board" % job)
        suburb = DEMO_ADDRESS.split(",")[0].strip()
        need(item.get("suburb") == suburb,
             "board suburb %r, expected masked first segment %r" % (item.get("suburb"), suburb))
        need(not item.get("address"), "board item leaks a full address: %r" % item.get("address"))
        need(item.get("scopeNotes"), "board item missing scopeNotes")
        need(dec(item.get("budgetMin")) is not None and dec(item.get("budgetMax")) is not None,
             "board item missing budget range: %r" % item)
        need(item.get("description"), "board item missing description")
        need(parse_utc(item.get("quotesCloseAtUtc")) is not None, "board item missing quotesCloseAtUtc")
        need(item.get("quotesReceived") == 0, "board quotesReceived %r, expected 0" % item.get("quotesReceived"))

    rec.step("job is on the board with suburb masking + details", listed)

    quote = rec.step("tradie 1 quotes without an invite", lambda: submit_quote(job, tr1, Decimal("1500")))
    need(quote.get("status") == "Submitted", "board quote status %r, expected Submitted" % quote.get("status"))

    def owner_sees():
        quotes = get("/jobs/%d/quotes" % job, ho) or []
        need(any(q.get("id") == quote.get("id") for q in quotes), "homeowner does not see the board quote")
        poll_counts(job, ho, (None, 1))  # open-board: Requested null, Received 1

    rec.step("homeowner sees the board quote; counts are (null, 1)", owner_sees)

    rec.step("second quote from tradie 1 is rejected",
             lambda: expect_http_error("duplicate board quote",
                                       lambda: submit_quote(job, tr1, Decimal("1600"))))

    def gone_but_visible_to_tradie2():
        need(job not in available_job_ids(tr1), "tradie 1 still sees a job they already quoted")
        need(job in available_job_ids(tr2), "tradie 2 no longer sees the open job")

    rec.step("tradie 1 drops off the board, tradie 2 stays", gone_but_visible_to_tradie2)

    invite_only = rec.step("post an invite-only Project job", lambda: _create_project_job(ho, "InviteOnly"))
    record_job(invite_only, "open-board-invite-only")
    rec.step("invite-only job is not on the board",
             lambda: need(invite_only not in available_job_ids(tr2), "invite-only job listed on the board"))

    remote = rec.step("post an open job outside the radius",
                      lambda: _create_project_job(ho, "Remote", lat=-46.4132, lng=168.3538,
                                                  address="1 Tay St, Invercargill", open_to_board=True))
    record_job(remote, "open-board-remote")
    rec.step("out-of-range open job is not on the board",
             lambda: need(remote not in available_job_ids(tr2), "remote open job listed on the board"))

    rec.step("homeowner blocks tradie 3", lambda: post("/profile/block", ho, {"blockedUserId": id3}))
    try:
        rec.step("blocked tradie does not see the job",
                 lambda: need(job not in available_job_ids(tr3), "blocked tradie sees the open job"))
        rec.step("blocked tradie cannot quote",
                 lambda: expect_http_error("blocked board quote",
                                           lambda: submit_quote(job, tr3, Decimal("1400"))))
    finally:
        try:
            _request("DELETE", "/profile/block/%s" % id3, ho)
        except Exception as e:  # noqa: BLE001 — cleanup must not mask the assertion
            print("    warning: could not unblock tradie 3: %s" % e)

    # Window stamped at posting: a later settings change must not move it, and a
    # new job must pick up the new window. Restore the original in finally.
    try:
        superadmin = login(SUPERADMIN)
    except Unreachable as e:
        raise Unreachable(
            "open-board-quotes needs a superadmin login for the window check: %s — set "
            "FIXO_ADMIN_EMAIL / FIXO_ADMIN_PASSWORD" % e
        )

    def put_windows(board, validity):
        return _request("PUT", "/admin/settings/quotes", superadmin,
                        {"boardWindowHours": board, "validityHours": validity}) or {}

    before = (get("/jobs/%d" % job, ho) or {}).get("quotesCloseAtUtc")
    new_board = 1 if board_hours != 1 else 2
    try:
        rec.step("superadmin raises the board window",
                 lambda: put_windows(new_board, settings.get("validityHours")))

        def unchanged():
            after = (get("/jobs/%d" % job, ho) or {}).get("quotesCloseAtUtc")
            need(after == before, "existing job close moved from %r to %r after a settings change" % (before, after))

        rec.step("existing job keeps its stamped close window", unchanged)

        def new_job_uses_new_window():
            nj = _create_project_job(ho, "NewWindow", open_to_board=True)
            record_job(nj, "open-board-new-window")
            j = get("/jobs/%d" % nj, ho) or {}
            close, created = parse_utc(j.get("quotesCloseAtUtc")), parse_utc(j.get("createdAtUtc"))
            need(close is not None and created is not None, "new job timestamps missing: %r" % j)
            hours = (close - created).total_seconds() / 3600.0
            need(abs(hours - new_board) <= (5 / 60.0),
                 "new job window is %.2f h, expected ~%d h" % (hours, new_board))

        rec.step("a new job uses the new board window", new_job_uses_new_window)
    finally:
        try:
            put_windows(settings.get("boardWindowHours"), settings.get("validityHours"))
        except Exception as e:  # noqa: BLE001
            print("    warning: could not restore quote settings: %s" % e)

    rec.step("homeowner accepts the board quote",
             lambda: post("/jobs/%d/quotes/%d/accept" % (job, quote["id"]), ho,
                          {"confirmWrittenContract": False}))
    rec.step("job Booked", lambda: wait_status(job, ho, "Booked"))
    rec.step("tradie 2 can no longer quote a booked job",
             lambda: expect_http_error("quote after booking",
                                       lambda: submit_quote(job, tr2, Decimal("1700"))))
    return job


def run_quote_settings(rec):
    """Plan 10 Q7.2/Q7.3: admin quote-window settings — staff read-only, superadmin
    writes, 1-720 validation, new quotes honour ValidityHours, and changes are not
    retroactive. The original values are restored in `finally`.
    """
    staff = rec.step("login staff", lambda: login(STAFF))
    try:
        superadmin = login(SUPERADMIN)
    except Unreachable as e:
        raise Unreachable(
            "quote-settings needs a superadmin login: %s — set FIXO_ADMIN_EMAIL / "
            "FIXO_ADMIN_PASSWORD (demo seed defaults: admin@fixo.nz / Admin1!Fixo)" % e
        )
    ho = rec.step("login homeowner", lambda: login(HOMEOWNER))
    tr = rec.step("login tradie", lambda: login(TRADIE))

    def put(board, validity):
        return _request("PUT", "/admin/settings/quotes", superadmin,
                        {"boardWindowHours": board, "validityHours": validity}) or {}

    def assert_settings(board, validity):
        got = _get_quote_settings(staff)
        need(got.get("boardWindowHours") == board and got.get("validityHours") == validity,
             "settings are %r, expected %d/%d" % (got, board, validity))

    original = rec.step("staff can read quote settings", lambda: _get_quote_settings(staff))
    for field in ("boardWindowHours", "validityHours"):
        v = original.get(field)
        need(isinstance(v, int) and 1 <= v <= 720, "%s is %r, expected int 1..720" % (field, v))

    rec.step("staff cannot change quote settings (403)",
             lambda: expect_http_status(
                 "staff PUT /admin/settings/quotes",
                 lambda: http_status("PUT", "/admin/settings/quotes", staff,
                                     {"boardWindowHours": 48, "validityHours": 96}),
                 403))

    try:
        def set_and_check(board, validity):
            body = put(board, validity)
            need(body.get("boardWindowHours") == board and body.get("validityHours") == validity,
                 "PUT echoed %r, expected %d/%d" % (body, board, validity))
            assert_settings(board, validity)

        rec.step("superadmin sets 48/96 and staff reads it back", lambda: set_and_check(48, 96))

        for bad in ({"boardWindowHours": 0}, {"boardWindowHours": 721},
                    {"validityHours": 0}, {"validityHours": 721}, {"validityHours": -1}):
            body = {"boardWindowHours": 48, "validityHours": 96}
            body.update(bad)
            rec.step("reject invalid settings %r" % bad,
                     lambda body=body: expect_http_status(
                         "invalid quote settings %r" % body,
                         lambda: http_status("PUT", "/admin/settings/quotes", superadmin, body),
                         400))
        rec.step("settings unchanged after rejected writes", lambda: assert_settings(48, 96))

        job = rec.step("post Project job for validity", lambda: _create_project_job(ho, "Validity"))
        record_job(job, "quote-settings-validity")
        tr_id = (get("/profile", tr) or {}).get("id")
        rec.step("request the tradie", lambda: post("/jobs/%d/request" % job, ho, {"tradieId": tr_id}))
        quote = rec.step("tradie submits a quote", lambda: submit_quote(job, tr, Decimal("1500")))
        qid = quote.get("id")

        def check_validity():
            q = _find_quote(job, ho, qid)
            created, valid = parse_utc(q.get("createdAtUtc")), parse_utc(q.get("validUntilUtc"))
            need(created and valid, "quote timestamps missing: %r" % q)
            hours = (valid - created).total_seconds() / 3600.0
            need(abs(hours - 96) <= (1 / 60.0), "validity is %.3f h, expected ~96 h" % hours)

        rec.step("new quote is valid for ~96 h", check_validity)

        before = rec.step("read the quote's validUntil",
                          lambda: _find_quote(job, ho, qid).get("validUntilUtc"))
        rec.step("superadmin lowers validity to 24", lambda: set_and_check(48, 24))

        def unchanged():
            after = _find_quote(job, ho, qid).get("validUntilUtc")
            need(after == before,
                 "validUntil changed from %r to %r after a settings update" % (before, after))

        rec.step("existing quote is not retroactively changed", unchanged)
    finally:
        try:
            put(original.get("boardWindowHours"), original.get("validityHours"))
        except Exception as e:  # noqa: BLE001 — restore must not mask the real failure
            print("    warning: could not restore quote settings: %s" % e)
        else:
            print("    (restored quote settings to %s/%s)"
                  % (original.get("boardWindowHours"), original.get("validityHours")))
    return job


SCENARIOS = {
    "happy-path": run_journey,
    "competing-quotes": run_competing_quotes,
    "homeowner-quotes-visibility": run_homeowner_quotes_visibility,
    "quote-settings": run_quote_settings,
    "open-board-quotes": run_open_board_quotes,
    "hourly-decline-reoffer": run_hourly_decline_reoffer,
    "withdraw-no-match-repost": run_withdraw_no_match_repost,
    "cancellations": run_cancellations,
    "receipt-reject-resubmit": run_receipt_reject_resubmit,
    "dispute-attachments-reviews": run_dispute_attachments_reviews,
}


def write_junit(path, rows, total):
    fails = sum(1 for _, _, e in rows if e)
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<testsuite name="e2e-journey" tests="%d" failures="%d" time="%.2f">' % (len(rows), fails, total),
    ]
    for name, dt, err in rows:
        lines.append('  <testcase classname="journey" name=%s time="%.2f"%s' % (
            quoteattr(name), dt, ">" if err else "/>"))
        if err:
            lines.append("    <failure message=%s/>" % quoteattr(err))
            lines.append("  </testcase>")
    lines.append("</testsuite>")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    global MATCH_MODE, POLL_TIMEOUT
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--junit", help="write JUnit XML to this path")
    ap.add_argument("--restore-tradies", action="store_true", help="un-park the demo tradie and exit")
    ap.add_argument(
        "--match-mode",
        choices=("auto", "quick", "direct"),
        default="auto",
        help="how the tradie gets the offer: quick-match, or a direct request to the persona tradie "
        "(auto = direct for --manifest runs on v2, quick-match otherwise)",
    )
    ap.add_argument(
        "--scenario",
        choices=tuple(SCENARIOS) + ("all",),
        default="happy-path",
        help="happy-path (default; the run-e2e.sh gate) | competing-quotes (needs --manifest, >= 3 tradies) "
        "| homeowner-quotes-visibility (>= 2 tradies) | quote-settings | all",
    )
    ap.add_argument("--manifest", help="persona manifest from scripts/e2e-personas.py (default: seeded *@fixo.test accounts)")
    ap.add_argument("--fail-fast", action="store_true", help="stop on first failed scenario (default)")
    ap.add_argument("--retry", type=int, default=0, help="retry a failed scenario up to N times")
    ap.add_argument("--timeout", type=int, help="poll timeout in seconds (default: %d)" % POLL_TIMEOUT)
    args = ap.parse_args()
    MATCH_MODE = args.match_mode
    if args.timeout:
        POLL_TIMEOUT = args.timeout

    try:
        require_local()
        if args.manifest:
            apply_manifest(args.manifest)
    except Unreachable as e:
        print("UNREACHABLE: %s" % e)
        return 2

    if args.restore_tradies:
        set_demo_tradie(True)
        print("demo tradie restored (or not present)")
        return 0

    print("e2e journey against %s" % API_BASE)
    rec = Recorder()
    t0 = time.time()
    code = 0
    job = None
    names = list(SCENARIOS) if args.scenario == "all" else [args.scenario]
    try:
        jobs = []
        for name in names:
            for attempt in range(args.retry + 1):
                try:
                    print("-- scenario: %s --" % name)
                    jobs.append(SCENARIOS[name](rec))
                    break
                except StepFailed:
                    if attempt < args.retry:
                        print("retrying %s (%d/%d)..." % (name, attempt + 1, args.retry))
                        continue
                    raise
        job = ", ".join(str(j) for j in jobs)
    except Unreachable as e:
        print("\nUNREACHABLE: %s" % e)
        code = 2
    except StepFailed as e:
        print("\nJOURNEY FAILED at: %s" % e)
        code = 1
    finally:
        set_demo_tradie(True)  # always un-park, even on failure

    total = time.time() - t0
    if args.junit:
        write_junit(args.junit, rec.rows, total)
    if code == 0:
        print("\nJOURNEY PASS: %s (job %s) in %.0fs" % (", ".join(names), job, total))
    return code


if __name__ == "__main__":
    sys.exit(main())
