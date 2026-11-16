#!/usr/bin/env bash
# P12 (v1.7) end-to-end smoke test against the running stack.
#
# Drives the full §4.2 pay-at-completion flow for a flow-v2 job:
#   post → pick (tradie list + direct request) → accept → check-in →
#   adjust (propose + approve) → check-out (final hours) → approve → pay
#   (receipt upload) → verify → payout.
#
# Prereqs:
#   - The stack is running (`docker compose up`) and the demo accounts exist
#     (scripts/seed-test-accounts.sh / DemoSeedService).
#   - JobFlow:Version = 2 in backend/appsettings.Development.json so the
#     posted job runs the v2 flow (this script does NOT flip the flag itself;
#     run it with the flag on, as QA would after sign-off).
#
# Test-only. Jobs/adjustments created here are cancelled/cleaned where the
# API allows; the DB restore logic mirrors p4-smoke.sh.
set -uo pipefail

API=http://localhost:5000
PW='Demo1!Fixo'

pretty() { python3 -c 'import sys;print(sys.stdin.read())'; }
fail() { echo "P12 SMOKE FAILED: $*" >&2; exit 1; }

login() {
  curl -s -X POST "$API/api/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" |
    python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])'
}

HO=$(login homeowner@fixo.nz "$PW")
TR=$(login tradie@fixo.nz "$PW")
AD=$(login admin@fixo.nz 'Admin1!Fixo')
[ -n "$HO" ] && [ -n "$TR" ] && [ -n "$AD" ] || fail "could not acquire demo tokens"
echo "tokens acquired (homeowner / tradie / admin)"

api() { # method path token [body]
  local method=$1 path=$2 token=$3 body=${4:-}
  if [ -n "$body" ]; then
    curl -s -X "$method" "$API$path" -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' -d "$body"
  else
    curl -s -X "$method" "$API$path" -H "Authorization: Bearer $token"
  fi
}

json() { python3 -c "import sys,json;d=json.load(sys.stdin);print(d$1)"; }

# ── 1. Post a v2 hourly job (no rate, no hours, flexible timing) ──────────────
SERVICE_ID=$(api GET /api/services "$HO" | json "[0]['id']")
[ -n "$SERVICE_ID" ] || fail "no services available"

NOW_DAY=$(python3 -c 'import datetime;print((datetime.datetime.utcnow()+datetime.timedelta(days=3)).strftime("%Y-%m-%dT09:00:00Z"))')
JOB=$(api POST /api/jobs "$HO" "{
  \"title\": \"P12 smoke — fix dripping tap\",
  \"description\": \"Kitchen mixer tap drips constantly. v1.7 smoke job.\",
  \"serviceId\": $SERVICE_ID,
  \"urgency\": \"Medium\",
  \"timingPreference\": \"Flexible\",
  \"latitude\": -36.8559,
  \"longitude\": 174.7665,
  \"address\": \"70 Symonds Street, Grafton, Auckland\"
}")
JOB_ID=$(echo "$JOB" | json "['id']" 2>/dev/null) || JOB_ID=""
[ -n "$JOB_ID" ] || fail "job create failed: $JOB"
STATUS=$(echo "$JOB" | json "['status']")
FLOW=$(echo "$JOB" | json "['flowVersion']")
assert_flow() { [ "$FLOW" = "2" ] || fail "job must be flow v2 (set JobFlow:Version=2), got $FLOW"; }
assert_flow
echo "job $JOB_ID created (status=$STATUS, flow=$FLOW)"

cleanup() {
  api POST "/api/jobs/$JOB_ID/cancel" "$HO" \
    '{"reasonCode":"homeowner_changed_mind","notes":"p12-smoke cleanup"}' >/dev/null
}
trap cleanup EXIT

[ "$STATUS" = "Requested" ] || fail "expected Requested, got $STATUS"

# ── 2. Choose-a-Tradie list (P12-05) ─────────────────────────────────────────
LIST=$(api GET "/api/jobs/$JOB_ID/tradies?sort=rating" "$HO")
TRADIE_ID=$(echo "$LIST" | json "[0]['tradieId']" 2>/dev/null) || TRADIE_ID=""
[ -n "$TRADIE_ID" ] || fail "tradie list empty: $LIST"
RATE=$(echo "$LIST" | json "[0]['hourlyRate']")
GST=$(echo "$LIST" | json "[0]['isGstRegistered']")
echo "tradie list ok — first: $TRADIE_ID at \$$RATE/hr (gst=$GST)"

# ── 3. Direct request with rate snapshot (P12-08) ────────────────────────────
REQ=$(api POST "/api/jobs/$JOB_ID/request" "$HO" "{\"tradieId\":\"$TRADIE_ID\",\"message\":\"Hi, are you free this week?\"}")
OFFER_ID=$(echo "$REQ" | json "['id']" 2>/dev/null) || OFFER_ID=""
[ -n "$OFFER_ID" ] || fail "direct request failed: $REQ"
SNAP=$(echo "$REQ" | json "['hourlyRateSnapshot']")
[ "$SNAP" = "$RATE" ] || fail "rate snapshot mismatch: sent $RATE, snapshot $SNAP"
echo "direct request sent (offer $OFFER_ID, snapshot \$$SNAP)"

# ── 4. Tradie accepts → Booked (P12-10: accept books, no payment step) ───────
RESP=$(api POST "/api/jobs/$JOB_ID/offers/$OFFER_ID/respond" "$TR" '{"response":"Accepted"}')
[ "$(echo "$RESP" | json "['response']" 2>/dev/null)" = "Accepted" ] || fail "accept failed: $RESP"
JOB2=$(api GET "/api/jobs/$JOB_ID" "$HO")
[ "$(echo "$JOB2" | json "['status']")" = "Booked" ] || fail "job did not book on accept"
BOOKED_RATE=$(echo "$JOB2" | json "['hourlyRate']")
[ "$BOOKED_RATE" = "$SNAP" ] || fail "job rate != snapshot ($BOOKED_RATE vs $SNAP)"
echo "accept → Booked at \$$BOOKED_RATE/hr (rate snapshot copied)"

# ── 5. Check-in → In progress ────────────────────────────────────────────────
api POST "/api/jobs/$JOB_ID/check-in" "$TR" >/dev/null
[ "$(api GET "/api/jobs/$JOB_ID" "$TR" | json "['status']")" = "InProgress" ] || fail "check-in failed"
echo "check-in ok"

# ── 6. Price adjustment (P12-17): propose + approve ─────────────────────────
ADJ=$(api POST "/api/jobs/$JOB_ID/adjustments" "$TR" \
  '{"kind":"Materials","description":"Replacement mixer cartridge","amount":42.50}')
ADJ_ID=$(echo "$ADJ" | json "['id']" 2>/dev/null) || ADJ_ID=""
[ -n "$ADJ_ID" ] || fail "adjustment propose failed: $ADJ"
[ "$(echo "$ADJ" | json "['status']")" = "Pending" ] || fail "adjustment not pending"

# Approval is blocked while pending? No — the adjustment is decided here:
RESP_ADJ=$(api POST "/api/jobs/$JOB_ID/adjustments/$ADJ_ID/respond" "$HO" \
  '{"approve":true,"note":"Receipt looks fine"}')
[ "$(echo "$RESP_ADJ" | json "['status']")" = "Approved" ] || fail "adjustment approve failed: $RESP_ADJ"
TOTAL=$(api GET "/api/jobs/$JOB_ID" "$HO" | json "['adjustmentsTotal']")
[ "$TOTAL" = "42.50" ] || fail "adjustmentsTotal expected 42.50, got $TOTAL"
echo "adjustment approved (running total \$$TOTAL)"

# ── 7. Check-out with final hours (P12-11) ───────────────────────────────────
CO=$(api POST "/api/jobs/$JOB_ID/check-out" "$TR" '{"finalHours":3.5,"notes":"All done"}')
LABOUR=$(echo "$CO" | json "['labourAmount']")
FINAL=$(echo "$CO" | json "['finalAmount']")
EXPECTED_LABOUR=$(python3 -c "print(round(3.5 * $BOOKED_RATE, 2))")
EXPECTED_FINAL=$(python3 -c "print(round(3.5 * $BOOKED_RATE + 42.50, 2))")
[ "$LABOUR" = "$EXPECTED_LABOUR" ] || fail "labour mismatch: $LABOUR vs $EXPECTED_LABOUR"
[ "$FINAL" = "$EXPECTED_FINAL" ] || fail "final mismatch: $FINAL vs $EXPECTED_FINAL"
echo "check-out ok — labour \$$LABOUR + adjustments \$42.50 = \$$FINAL"

# ── 8. Approve → AwaitingPayment (P12-11) ────────────────────────────────────
api POST "/api/jobs/$JOB_ID/approve" "$HO" '{"note":"Looks right"}' >/dev/null
[ "$(api GET "/api/jobs/$JOB_ID" "$HO" | json "['status']")" = "AwaitingPayment" ] || fail "approve failed"
echo "approve → AwaitingPayment"

# ── 9. Pay: receipt upload → PaymentReview (manual bank transfer, unchanged) ─
RECEIPT=$(mktemp /tmp/p12-receipt-XXXX.png)
python3 -c "import base64,os;open('$RECEIPT','wb').write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='))"
UP=$(curl -s -X POST "$API/api/jobs/$JOB_ID/payment/upload-receipt" -H "Authorization: Bearer $HO" \
  -F "receipt=@$RECEIPT;type=image/png")
rm -f "$RECEIPT"
[ "$(echo "$UP" | json "['payment']['status']" 2>/dev/null || echo "$UP" | json "['status']" 2>/dev/null)" != "" ] || fail "receipt upload failed: $UP"
[ "$(api GET "/api/jobs/$JOB_ID" "$HO" | json "['status']")" = "PaymentReview" ] || fail "receipt upload did not reach PaymentReview"
echo "receipt uploaded → PaymentReview"

# ── 10. Staff verify → Completed + payout pending (P12-13/16) ────────────────
PAY_ID=$(api GET "/api/jobs/$JOB_ID/payment" "$HO" | json "['paymentId']")
[ -n "$PAY_ID" ] || fail "no payment id"
VERIFY=$(api POST "/api/admin/payments/$PAY_ID/verify" "$AD")
[ "$(api GET "/api/jobs/$JOB_ID" "$AD" | json "['status']")" = "Completed" ] || fail "verify did not complete the job: $VERIFY"
echo "verify → Completed"

PAYOUTS=$(api GET /api/admin/payouts/pending "$AD")
echo "$PAYOUTS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('items', d if isinstance(d, list) else [])
match = [p for p in items if p.get('jobId') == $JOB_ID]
assert match, 'no pending payout for job $JOB_ID'
p = match[0]
assert abs(float(p['grossAmount']) - float('$FINAL')) < 0.01, f\"gross {p['grossAmount']} != final $FINAL\"
print('payout pending ok — gross', p['grossAmount'])
" || fail "payout check failed"

echo ""
echo "P12 SMOKE PASSED — full §4.2 flow verified end-to-end."
