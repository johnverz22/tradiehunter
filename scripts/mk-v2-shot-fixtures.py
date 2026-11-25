#!/usr/bin/env python3
"""V2-aware screenshot fixtures for the v2 capture drivers.

Drives jobs through the real API into every state the base
(integration_test/screenshots_test.dart) and variants
(integration_test/screenshots_variants_test.dart) drivers need, branching on
each job's own flowVersion like integration_test/helpers/fixture_helper.dart:

  v2 (pay at completion): accept -> Booked -> check-in -> InProgress ->
    check-out -> AwaitingConfirmation -> approve -> AwaitingPayment ->
    receipt -> PaymentReview -> staff verify -> Completed
  v1 (pay before booking): accept -> AwaitingPayment -> receipt ->
    PaymentReview -> staff verify -> Booked -> check-in -> ... -> Completed

Prints SHOT_* defines to feed `scripts/run-shots.sh` extra dart-defines.

Prereq: `docker compose up -d` with the API on :5000 and seeded accounts
(`bash scripts/seed-test-accounts.sh`). Run from the repo root:

    python3 scripts/mk-v2-shot-fixtures.py
"""
import base64
import json
import subprocess
import sys
import time
import urllib.request
import urllib.error

API = "http://localhost:5000/api"
HOMEOWNER = "homeowner-a@fixo.test"
TRADIE = "tradie-verified@fixo.test"
STAFF = "staff@fixo.test"
DEMO_TRADIE = "tradie@fixo.nz"
PW = "Test1234!"

PNG_B64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA"
    "hKmMIQAAAABJRU5ErkJggg=="
)


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def req(method, path, token=None, body=None, raw=None, ctype="application/json"):
    url = f"{API}{path}"
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    r = urllib.request.Request(url, data=data, method=method)
    if token:
        r.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        r.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            payload = resp.read()
            if resp.status == 204 or not payload:
                return None
            return json.loads(payload)
    except urllib.error.HTTPError as e:
        detail = e.read().decode()[:400]
        raise RuntimeError(f"{method} {path} -> {e.code}: {detail}")


def login(email):
    for _ in range(5):
        try:
            return req("POST", "/auth/login", body={"email": email, "password": PW})["token"]
        except Exception:
            time.sleep(1)
    raise RuntimeError(f"login failed for {email}")


HT = login(HOMEOWNER)
TT = login(TRADIE)
ST = login(STAFF)

# Park the demo tradie so sequential matching targets tradie-verified.
try:
    DT = login(DEMO_TRADIE)
    req("POST", "/profile/availability", DT, {"available": False})
    log("demo tradie parked")
except Exception as e:
    log(f"demo tradie park skipped: {e}")


def jget(job_id, token=HT):
    return req("GET", f"/jobs/{job_id}", token)


def status(job_id):
    return jget(job_id).get("status")


def flow_version(job_id):
    return int(jget(job_id).get("flowVersion") or 1)


def wait_status(job_id, expected, timeout=90):
    deadline = time.time() + timeout
    while time.time() < deadline:
        s = status(job_id)
        if s == expected:
            return
        time.sleep(2)
    raise RuntimeError(f"job {job_id} stuck (now {status(job_id)}, wanted {expected})")


def mkjob(title, job_type=None, budget_min=None, budget_max=None):
    body = {
        "title": title,
        "description": "v2 screenshot fixture.",
        "urgency": "Medium",
        "latitude": -36.8485,
        "longitude": 174.7633,
        "address": "1 Test St, Auckland",
        "serviceId": 1,
        "timingPreference": "Flexible",
        "estimatedHours": 2,
    }
    if job_type:
        body.update({
            "jobType": job_type,
            "budgetMin": budget_min,
            "budgetMax": budget_max,
            "scopeNotes": "v2 fixture project scope.",
        })
    return req("POST", "/jobs", HT, body)["id"]


def pending_offer(job_id):
    try:
        r = req("GET", f"/jobs/{job_id}/offers/pending", TT)
        return r
    except RuntimeError:
        return None


def dispatch_and_wait_offer(job_id, timeout=90):
    req("POST", f"/jobs/{job_id}/match", HT, {})
    deadline = time.time() + timeout
    while time.time() < deadline:
        offer = pending_offer(job_id)
        if offer:
            return offer
        time.sleep(2)
    raise RuntimeError(f"no pending offer for job {job_id}")


def accept_offer(job_id, offer_id):
    req("POST", f"/jobs/{job_id}/offers/{offer_id}/respond", TT,
        {"response": "Accepted"})


def upload_receipt(job_id):
    boundary = f"fixo{int(time.time() * 1000)}"
    marker = f"|v2fix-{job_id}-{int(time.time() * 1000)}".encode()
    payload = (
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="receipt"; filename="receipt.png"\r\n'
        "Content-Type: image/png\r\n\r\n"
    ).encode() + base64.b64decode(PNG_B64) + marker + (
        f"\r\n--{boundary}--\r\n"
    ).encode()
    req("POST", f"/jobs/{job_id}/payment/upload-receipt", HT,
        raw=payload, ctype=f"multipart/form-data; boundary={boundary}")


def payment_id(job_id):
    return req("GET", f"/jobs/{job_id}/payment", HT)["paymentId"]


def to_booked(job_id):
    """Requested -> Booked via match + accept (v2) or pay-first (v1)."""
    fv = flow_version(job_id)
    offer = dispatch_and_wait_offer(job_id)
    accept_offer(job_id, offer["id"])
    if fv >= 2:
        wait_status(job_id, "Booked")
        return
    wait_status(job_id, "AwaitingPayment")
    pid = payment_id(job_id)
    upload_receipt(job_id)
    wait_status(job_id, "PaymentReview")
    req("POST", f"/admin/payments/{pid}/verify", ST, {})
    wait_status(job_id, "Booked")


def to_inprogress(job_id):
    if status(job_id) == "Requested":
        to_booked(job_id)
    req("POST", f"/jobs/{job_id}/check-in", TT, {})
    wait_status(job_id, "InProgress")


def to_awaiting_confirmation(job_id):
    to_inprogress(job_id)
    req("POST", f"/jobs/{job_id}/check-out", TT, {"finalHours": 2})
    wait_status(job_id, "AwaitingConfirmation")


def to_awaiting_payment(job_id):
    """Requested -> AwaitingPayment along whichever flow the job is stamped."""
    if status(job_id) == "Requested":
        if flow_version(job_id) >= 2:
            to_awaiting_confirmation(job_id)
            req("POST", f"/jobs/{job_id}/approve", HT, {})
            wait_status(job_id, "AwaitingPayment")
        else:
            offer = dispatch_and_wait_offer(job_id)
            accept_offer(job_id, offer["id"])
            wait_status(job_id, "AwaitingPayment")


def to_payment_review(job_id):
    to_awaiting_payment(job_id)
    payment_id(job_id)  # opens the payment
    upload_receipt(job_id)
    wait_status(job_id, "PaymentReview")


def to_completed(job_id):
    to_payment_review(job_id)
    pid = payment_id(job_id)
    req("POST", f"/admin/payments/{pid}/verify", ST, {})
    wait_status(job_id, "Completed")



def _tradie_id():
    return req("GET", "/profile", TT)["id"]


def request_quote(job_id):
    """Homeowner directly requests the test tradie on a project job.

    Sequential matching only ever creates Instant offers (MatchingService
    hardcodes OfferKind.Instant); QuoteRequest offers - the only kind a
    tradie can quote against - come from POST /jobs/:id/request.
    """
    req("POST", f"/jobs/{job_id}/request", HT, {"tradieId": _tradie_id()})
    deadline = time.time() + 30
    while time.time() < deadline:
        offer = pending_offer(job_id)
        if offer:
            return offer
        time.sleep(2)
    raise RuntimeError(f"no pending quote request for job {job_id}")


def psql(sql):
    subprocess.run(
        ["docker", "compose", "exec", "-T", "db", "psql", "-U", "fixo", "-d", "fixo", "-c", sql],
        check=True, capture_output=True, text=True,
    )


def cleanup_stale_shot_jobs():
    """Cancel previous Shot fixtures left in AwaitingPayment so they don't expire and flag accounts."""
    try:
        psql(
            "UPDATE \"Jobs\" SET \"Status\"='Cancelled', \"CancelReasonCode\"='homeowner_changed_mind', "
            "\"UpdatedAtUtc\"=NOW() "
            "WHERE \"Title\" LIKE 'Shot %' AND \"Status\"='AwaitingPayment';"
        )
        log("Prior Shot AwaitingPayment jobs cancelled (hygiene).")
    except Exception as e:
        log(f"Warning: could not cancel prior shot jobs: {e}")


def main():
    cleanup_stale_shot_jobs()
    ts = int(time.time())
    out = {}

    # ── Base driver fixtures ──────────────────────────────────────────────
    j_req = mkjob(f"Shot REQ {ts}")
    out["SHOT_MATCH_JOB"] = j_req
    log(f"SHOT_MATCH_JOB={j_req} ({status(j_req)})")

    j_book = mkjob(f"Shot BOOK {ts}")
    to_booked(j_book)
    out["SHOT_BOOKED_JOB"] = j_book
    log(f"SHOT_BOOKED_JOB={j_book} ({status(j_book)})")

    j_prog = mkjob(f"Shot PROG {ts}")
    to_inprogress(j_prog)
    out["SHOT_INPROGRESS_JOB"] = j_prog
    log(f"SHOT_INPROGRESS_JOB={j_prog} ({status(j_prog)})")

    j_pay = mkjob(f"Shot PAY {ts}")
    to_awaiting_payment(j_pay)
    out["SHOT_PAYMENT_JOB"] = j_pay
    log(f"SHOT_PAYMENT_JOB={j_pay} ({status(j_pay)})")

    # Project job with one submitted quote (homeowner/11_quotes).
    j_quote = mkjob(f"Shot QUOTE {ts}", job_type="Project",
                    budget_min=1500, budget_max=3500)
    request_quote(j_quote)
    try:
        req("POST", f"/jobs/{j_quote}/quotes", TT, {
            "pricingModel": "Fixed", "amount": 2400, "gstIncluded": True,
            "inclusions": "Labour and standard materials.",
            "exclusions": "Council fees.",
        })
    except RuntimeError as e:
        if "GST" not in str(e):
            raise
        req("POST", f"/jobs/{j_quote}/quotes", TT, {
            "pricingModel": "Fixed", "amount": 2400, "gstIncluded": False,
        })
    out["SHOT_QUOTES_JOB"] = j_quote
    log(f"SHOT_QUOTES_JOB={j_quote} (Requested, quote submitted)")

    # Project job left open with a pending QuoteRequest for the tradie
    # (tradie/03_quote_form).
    j_qreq = mkjob(f"Shot QREQ {ts}", job_type="Project",
                   budget_min=800, budget_max=2000)
    request_quote(j_qreq)
    out["SHOT_QUOTE_REQUEST_JOB"] = j_qreq
    log(f"SHOT_QUOTE_REQUEST_JOB={j_qreq} (pending quote request)")

    # ── Variants driver fixtures ──────────────────────────────────────────
    j_await = mkjob(f"Shot AWAIT {ts}")
    to_awaiting_confirmation(j_await)
    out["SHOT_AWAIT_JOB"] = j_await
    log(f"SHOT_AWAIT_JOB={j_await} ({status(j_await)})")

    j_done = mkjob(f"Shot DONE {ts}")
    to_completed(j_done)
    out["SHOT_DONE_JOB"] = j_done
    log(f"SHOT_DONE_JOB={j_done} ({status(j_done)})")

    j_canc = mkjob(f"Shot CANC {ts}")
    req("POST", f"/jobs/{j_canc}/cancel", HT,
        {"reasonCode": "homeowner_changed_mind",
         "reason": "v2 capture fixture."})
    wait_status(j_canc, "Cancelled")
    out["SHOT_CANC_JOB"] = j_canc
    log(f"SHOT_CANC_JOB={j_canc} ({status(j_canc)})")

    j_disp = mkjob(f"Shot DISP {ts}")
    to_booked(j_disp)
    req("POST", "/disputes", HT,
        {"jobId": j_disp, "reason": "quality_of_work",
         "details": "v2 capture fixture dispute."})
    out["SHOT_DISP_JOB"] = j_disp
    log(f"SHOT_DISP_JOB={j_disp} ({status(j_disp)}, dispute open)")

    j_sub = mkjob(f"Shot SUB {ts}")
    to_payment_review(j_sub)
    out["SHOT_SUB_JOB"] = j_sub
    log(f"SHOT_SUB_JOB={j_sub} ({status(j_sub)})")

    j_rej = mkjob(f"Shot REJ {ts}")
    to_payment_review(j_rej)
    pid = payment_id(j_rej)
    req("POST", f"/admin/payments/{pid}/reject", ST,
        {"reason": "Receipt is blurry — please re-upload a clearer photo."})
    out["SHOT_REJ_JOB"] = j_rej
    log(f"SHOT_REJ_JOB={j_rej} ({status(j_rej)})")

    j_exp = mkjob(f"Shot EXP {ts}")
    to_awaiting_payment(j_exp)
    req("GET", f"/jobs/{j_exp}/payment", HT)  # opens the payment
    psql(
        f'UPDATE "Jobs" SET "Status"=\'Expired\' WHERE "Id"={j_exp};'
        f'UPDATE "Payments" SET "Status"=\'Expired\' WHERE "JobId"={j_exp};'
        'INSERT INTO "JobStatusHistory" ("JobId","FromStatus","ToStatus",'
        '"ChangedByUserId","ReasonCode","Reason","ChangedAtUtc") VALUES ('
        f'{j_exp},\'AwaitingPayment\',\'Expired\','
        '(SELECT "Id" FROM "AspNetUsers" WHERE "Email"=\'homeowner-a@fixo.test\'),'
        "'no_payment','v2 fixture',NOW());"
    )
    out["SHOT_EXP_JOB"] = j_exp
    log(f"SHOT_EXP_JOB={j_exp} (forced Expired)")

    j_adj = mkjob(f"Shot ADJ {ts}")
    to_inprogress(j_adj)
    req("POST", f"/jobs/{j_adj}/adjustments", TT, {
        "kind": "Materials",
        "description": "v2 fixture extra cost — treated pine shelving.",
        "amount": 145.50,
    })
    out["SHOT_ADJUST_JOB"] = j_adj
    log(f"SHOT_ADJUST_JOB={j_adj} ({status(j_adj)}, adjustment pending)")

    print("\n# ── defines for run-shots.sh ──")
    for k, v in out.items():
        print(f"{k}={v}")


if __name__ == "__main__":
    main()
