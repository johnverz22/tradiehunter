"""Money, status-order and audit-trail assertions (moved unchanged from scripts/e2e-journey.py, plan 12 U1.2).

Field names come from backend/DTOs/JobDTOs.cs (JobDto) and AdminDTOs.cs
(admin job detail: statusHistory, chatTranscript). Money is always Decimal, never float.
"""
from __future__ import annotations

from decimal import Decimal

from .api import StepFailed, get

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
