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
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from decimal import Decimal
from xml.sax.saxutils import quoteattr

API_BASE = os.environ.get("FIXO_API_URL", "http://localhost:5000").rstrip("/")
API = API_BASE + "/api"

# Mirrors mobile/integration_test/helpers/test_config.dart.
HOMEOWNER = ("homeowner-a@fixo.test", "Test1234!")
TRADIE = ("tradie-verified@fixo.test", "Test1234!")
STAFF = ("staff@fixo.test", "Test1234!")
DEMO_TRADIE = ("tradie@fixo.nz", "Demo1!Fixo")  # competes for offers; parked

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
    global HOMEOWNER, TRADIE, STAFF, MANIFEST_PATH
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


def _request(method, path, token=None, body=None, raw=None, content_type=None):
    headers = {}
    data = None
    if token:
        headers["Authorization"] = "Bearer " + token
    if raw is not None:
        data, headers["Content-Type"] = raw, content_type
    elif body is not None:
        data, headers["Content-Type"] = json.dumps(body).encode(), "application/json"
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


def upload_receipt(job_id, token):
    boundary = "fixojourney%d" % int(time.time() * 1000)
    payload = _PNG + ("|fixo-journey-%d" % time.time_ns()).encode()
    head = (
        '--%s\r\nContent-Disposition: form-data; name="receipt"; '
        'filename="receipt.png"\r\nContent-Type: image/png\r\n\r\n' % boundary
    ).encode()
    tail = ("\r\n--%s--\r\n" % boundary).encode()
    return _request(
        "POST",
        "/jobs/%d/payment/upload-receipt" % job_id,
        token,
        raw=head + payload + tail,
        content_type="multipart/form-data; boundary=" + boundary,
    )


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
                "address": "1 Test St, Auckland",
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
    ap.add_argument("--manifest", help="persona manifest from scripts/e2e-personas.py (default: seeded *@fixo.test accounts)")
    args = ap.parse_args()
    global MATCH_MODE
    MATCH_MODE = args.match_mode

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
    try:
        job = run_journey(rec)
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
        print("\nJOURNEY PASS: job %s completed and reviewed in %.0fs" % (job, total))
    return code


if __name__ == "__main__":
    sys.exit(main())
