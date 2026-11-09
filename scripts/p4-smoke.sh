#!/usr/bin/env bash
# P4 end-to-end smoke test against the running stack.
#
# Covers P4-01 (payments table), P4-02 (provider seam), P4-03 (receipt upload,
# hashing, duplicate rejection), P4-04 (homeowner endpoints + ownership),
# P4-05 (admin queue, verify, reject, re-upload) and P4-06 (Hangfire expiry).
#
# Test-only. It temporarily lowers PaymentInstructions:WindowHours to 0 so the
# expiry path can be observed in seconds rather than hours, verifies the demo
# tradie so a candidate exists, and deletes the jobs it creates. Config, jobs
# and receipts are restored on exit.
set -uo pipefail

API=http://localhost:5000
PW='Demo1!Fixo'
DB="docker compose exec -T db psql -U fixo -d fixo -t -A"
CFG=backend/appsettings.Development.json

pretty() { python3 -c 'import sys;print(sys.stdin.read())'; }
q() { $DB -c "$1"; }
fail() { echo "SMOKE FAILED: $*" >&2; exit 1; }
assert_eq() { [ "$2" = "$3" ] || fail "$1: expected '$3', got '$2'"; }

IDS=()
RECEIPTS=()
# Demo tradie verification is flipped on so a candidate exists; restored on exit.
NEAR=""
NEAR_ORIG=""
OTHER_PLUMBERS=""
cleanup() {
  sed -i '' 's/"WindowHours": [0-9]*/"WindowHours": 2/' "$CFG"
  for id in "${IDS[@]:-}"; do
    [ -n "$id" ] && q "DELETE FROM \"Jobs\" WHERE \"Id\"=$id;" >/dev/null 2>&1
  done
  for key in "${RECEIPTS[@]:-}"; do
    [ -n "$key" ] && rm -f "/tmp/$key"
  done
  if [ -n "$NEAR" ]; then
    NVER=${NEAR_ORIG%%|*}; NAVAIL=${NEAR_ORIG##*|}
    q "UPDATE \"TradieProfiles\" SET \"IsVerified\"=$NVER, \"IsAvailable\"=$NAVAIL WHERE \"UserId\"='$NEAR';" >/dev/null 2>&1
  fi
  for other in ${OTHER_PLUMBERS:-}; do
    [ -n "$other" ] && q "UPDATE \"TradieProfiles\" SET \"IsAvailable\"=true WHERE \"UserId\"='$other';" >/dev/null 2>&1
  done
  # Always leave the API running the current source build.
  docker compose restart api >/dev/null 2>&1
  echo
  echo "cleanup done (config restored, jobs + receipts deleted, tradie restored, api restarted)"
}
trap cleanup EXIT

# Hangfire keeps its storage in Redis, not SQL: each job is a hash with Type,
# Method, Arguments and State fields. Count jobs of a given type currently
# sitting in the Scheduled state.
hangfire_scheduled() {
  docker compose exec -T redis sh -c "
    found=0
    for k in \$(redis-cli --scan --pattern 'fixo:hangfire:job:*' 2>/dev/null); do
      case \"\$k\" in *:state|*:history) continue;; esac
      [ \"\$(redis-cli HGET \"\$k\" State 2>/dev/null)\" = 'Scheduled' ] || continue
      redis-cli HGET \"\$k\" Type 2>/dev/null | grep -q '$1' && found=\$((found+1))
    done
    echo \$found" 2>/dev/null | tr -d '\r'
}

login() {
  curl -s -X POST "$API/api/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" |
    python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])'
}

# HTTP status of a request, without the body, into $CODE.
CODE=0
code() { CODE=$(curl -s -o /dev/null -w '%{http_code}' "$@"); }

# The API image is baked (no bind mount), so editing backend/ source requires a
# rebuild before a restart. Wait for the listener rather than sleeping a guessed
# interval and racing it.
wait_for_api() {
  for _ in $(seq 1 40); do
    curl -s -o /dev/null "$API/api/config/locale" && return 0
    sleep 1
  done
  fail "API did not come up at $API"
}

restart_api() {
  docker compose restart api >/dev/null 2>&1
  wait_for_api
}

echo "rebuilding + restarting api to pick up the current source…"
docker compose build api >/dev/null 2>&1
restart_api

HO=$(login homeowner@fixo.nz 'Demo1!Fixo')
TR=$(login tradie@fixo.nz 'Demo1!Fixo')
AD=$(login admin@fixo.nz 'Admin1!Fixo')
[ -n "$HO" ] && [ -n "$TR" ] && [ -n "$AD" ] || fail "could not acquire demo tokens"
echo "tokens acquired (homeowner / tradie / admin)"

# ── Fixtures ──────────────────────────────────────────────────────────────────
NEAR=$(q "SELECT p.\"UserId\" FROM \"TradieProfiles\" p
       JOIN \"AspNetUsers\" u ON u.\"Id\"=p.\"UserId\"
       WHERE u.\"Email\"='tradie@fixo.nz';")
NEAR_ORIG=$(q "SELECT \"IsVerified\"::text || '|' || \"IsAvailable\"::text FROM \"TradieProfiles\" WHERE \"UserId\"='$NEAR';" )
q "UPDATE \"TradieProfiles\" SET \"IsVerified\"=true, \"IsAvailable\"=true WHERE \"UserId\"='$NEAR';" >/dev/null

OTHER_PLUMBERS=$(q "SELECT p.\"UserId\" FROM \"TradieProfiles\" p WHERE p.\"TradeType\"='Plumber' AND p.\"UserId\" != '$NEAR' AND p.\"IsVerified\"=true AND p.\"IsAvailable\"=true;")
for other in ${OTHER_PLUMBERS:-}; do
  [ -n "$other" ] && q "UPDATE \"TradieProfiles\" SET \"IsAvailable\"=false WHERE \"UserId\"='$other';" >/dev/null
done
echo "fixture: demo Plumber ($NEAR) verified and isolated"

post_job() {
  cat > /tmp/p4-job.json <<JSON
{
  "title": "$1",
  "description": "P4 smoke test job.",
  "urgency": "High",
  "serviceId": 1,
  "scheduledStartUtc": "$(date -u -v+2d '+%Y-%m-%dT%H:%M:%SZ')",
  "hours": 2,
  "hourlyRate": 85.50,
  "latitude": -36.8485,
  "longitude": 174.7633,
  "address": "12 Queen Street, Auckland, Auckland"
}
JSON
  curl -s -X POST "$API/api/jobs" \
    -H "Authorization: Bearer $HO" -H 'Content-Type: application/json' \
    -d @/tmp/p4-job.json
}

# Drive a fresh job all the way to AwaitingPayment: post → match → tradie accepts.
# Echoes the job id. Caller appends to IDS.
make_payable_job() {
  local label="$1" jid oid
  jid=$(post_job "$label" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
  curl -s -X POST "$API/api/jobs/$jid/match" -H "Authorization: Bearer $HO" >/dev/null
  sleep 4
  oid=$(q "SELECT \"Id\" FROM \"JobOffers\" WHERE \"JobId\"=$jid AND \"Response\"='Pending' ORDER BY \"Id\" LIMIT 1;")
  [ -n "$oid" ] || fail "no pending offer created for job $jid"
  curl -s -X POST "$API/api/jobs/$jid/offers/$oid/respond" \
    -H "Authorization: Bearer $TR" -H 'Content-Type: application/json' \
    -d '{"response":"Accepted"}' >/dev/null
  local st; st=$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$jid;")
  assert_eq "job $jid after accept" "$st" "AwaitingPayment"
  echo "$jid"
}

# Callers append to IDS themselves: make_payable_job runs in a subshell, so an
# IDS+= inside it would never reach the EXIT trap.
track() { IDS+=("$1"); }

# Minimal valid 1x1 PNG. Each scenario uses distinct bytes so the ReceiptHash
# duplicate check (P4-03) only fires where we want it to.
make_receipt() {
  local path="$1" tag="$2"
  RECEIPTS+=("$(basename "$path")")
  python3 - "$path" "$tag" <<'PY'
import struct, sys, zlib
path, tag = sys.argv[1], sys.argv[2]
raw = b''.join(b'\x00' + bytes((i * 37 + len(tag) * 11) % 256 for _ in range(3)) for i in range(1))
def chunk(kind, data):
    body = kind + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body))
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
       + chunk(b'tEXt', b'Comment\x00' + tag.encode())
       + chunk(b'IDAT', zlib.compress(raw))
       + chunk(b'IEND', b''))
open(path, 'wb').write(png)
PY
}

upload_receipt() {
  curl -s -X POST "$API/api/jobs/$1/payment/upload-receipt" \
    -H "Authorization: Bearer $HO" -F "receipt=@$2;type=image/png"
}

# ── Scenario A: instructions → upload → verify (P4-01/03/04/05) ───────────────
echo
echo "===== A: instructions → receipt upload → admin verify → Booked ====="
JA=$(make_payable_job "P4 smoke A — verify")
track $JA
echo "job $JA is AwaitingPayment"

echo "GET /api/jobs/$JA/payment (instructions):"
curl -s "$API/api/jobs/$JA/payment" -H "Authorization: Bearer $HO" | pretty

# P4-06: entering AwaitingPayment armed the expiry job and stamped a deadline.
SQL="SELECT \"PaymentDueAtUtc\" IS NOT NULL FROM \"Jobs\" WHERE \"Id\"=$JA;"
[ "$(q "$SQL")" = "t" ] || fail "PaymentDueAtUtc was not stamped on entry to AwaitingPayment"
echo "payment deadline stamped on entry to AwaitingPayment ✓"

[ "$(hangfire_scheduled PaymentExpiryJob)" -ge 1 ] || fail "PaymentExpiryJob was not scheduled"
echo "Hangfire PaymentExpiryJob scheduled ✓"

# Calling twice must not create a second payment row.
curl -s "$API/api/jobs/$JA/payment" -H "Authorization: Bearer $HO" >/dev/null
curl -s "$API/api/jobs/$JA/payment" -H "Authorization: Bearer $HO" >/dev/null
assert_eq "payments rows for job $JA after 3 GETs" \
  "$(q "SELECT count(*) FROM \"Payments\" WHERE \"JobId\"=$JA;")" "1"

make_receipt /tmp/p4-a.png receiptA
echo "POST upload-receipt (receiptA):"
upload_receipt "$JA" /tmp/p4-a.png | pretty
assert_eq "job $JA after upload" "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JA;")" "PaymentReview"
assert_eq "payment status after upload" \
  "$(q "SELECT \"Status\" FROM \"Payments\" WHERE \"JobId\"=$JA;")" "Submitted"

SQL="SELECT \"ReceiptHash\" IS NOT NULL FROM \"Payments\" WHERE \"JobId\"=$JA;"
[ "$(q "$SQL")" = "t" ] || fail "ReceiptHash was not recorded"

# Ownership (P4-04): a tradie must not be able to read or pay another user's job.
code "$API/api/jobs/$JA/payment" -H "Authorization: Bearer $TR"
assert_eq "tradie GET payment for homeowner job" "$CODE" "404"
echo "non-owner GET is 404 (no job leak) ✓"

# Admin queue (P4-05).
echo "GET /api/admin/payments/pending (as admin):"
curl -s "$API/api/admin/payments/pending?page=1&pageSize=20" -H "Authorization: Bearer $AD" | pretty

# A homeowner must not be able to work the queue.
code "$API/api/admin/payments/pending" -H "Authorization: Bearer $HO"
assert_eq "homeowner hitting the admin queue" "$CODE" "403"
echo "homeowner is 403 on the admin queue ✓"

PA=$(q "SELECT \"Id\" FROM \"Payments\" WHERE \"JobId\"=$JA;")
[ -n "$PA" ] || fail "no payment row for job $JA"

echo "POST /api/admin/payments/$PA/verify:"
curl -s -X POST "$API/api/admin/payments/$PA/verify" -H "Authorization: Bearer $AD" | pretty
assert_eq "job $JA after verify" "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JA;")" "Booked"
assert_eq "payment after verify" "$(q "SELECT \"Status\" FROM \"Payments\" WHERE \"Id\"=$PA;")" "Verified"
SQL="SELECT \"VerifiedBy\" IS NOT NULL FROM \"Payments\" WHERE \"Id\"=$PA;"
[ "$(q "$SQL")" = "t" ] || fail "VerifiedBy was not stamped"
echo "payment Verified, job Booked, VerifiedBy stamped ✓"

# The queue must drain.
assert_eq "queue still lists payment $PA" \
  "$(q "SELECT count(*) FROM \"Payments\" WHERE \"Id\"=$PA AND \"Status\"='Submitted';")" "0"
echo "verified payment left the queue ✓"

# A verified job is closed for further payment.
code -X POST "$API/api/jobs/$JA/payment/upload-receipt" \
  -H "Authorization: Bearer $HO" -F "receipt=@/tmp/p4-a.png;type=image/png"
assert_eq "upload against a Booked job" "$CODE" "409"
echo "upload against a Booked job is 409 ✓"

# ── Scenario B: reject → re-upload → reject again (P4-05) ────────────────────
echo
echo "===== B: reject → re-upload → reject reason required ====="
JB=$(make_payable_job "P4 smoke B — reject")
track $JB
make_receipt /tmp/p4-b1.png receiptB1
upload_receipt "$JB" /tmp/p4-b1.png >/dev/null
PB=$(q "SELECT \"Id\" FROM \"Payments\" WHERE \"JobId\"=$JB;")
assert_eq "job $JB after upload" "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JB;")" "PaymentReview"

echo "reject with no reason (expect 400):"
code -X POST "$API/api/admin/payments/$PB/reject" \
  -H "Authorization: Bearer $AD" -H 'Content-Type: application/json' -d '{"reason":""}'
assert_eq "reject without a reason" "$CODE" "400"
echo "reject without a reason is 400 ✓"

echo "POST /api/admin/payments/$PB/reject:"
curl -s -X POST "$API/api/admin/payments/$PB/reject" \
  -H "Authorization: Bearer $AD" -H 'Content-Type: application/json' \
  -d '{"reason":"Receipt shows the wrong amount — please resend the full transfer slip."}' | pretty
assert_eq "job $JB after reject" "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JB;")" "AwaitingPayment"
assert_eq "payment status after reject" "$(q "SELECT \"Status\" FROM \"Payments\" WHERE \"Id\"=$PB;")" "Rejected"
assert_eq "ReUploadCount after reject" "$(q "SELECT \"ReUploadCount\" FROM \"Payments\" WHERE \"Id\"=$PB;")" "1"
SQL="SELECT \"RejectReason\" IS NOT NULL FROM \"Payments\" WHERE \"Id\"=$PB;"
[ "$(q "$SQL")" = "t" ] || fail "RejectReason was not recorded"
echo "payment Rejected, job back to AwaitingPayment, ReUploadCount=1 ✓"

# Rejecting twice from a non-submitted payment must conflict, not double-count.
code -X POST "$API/api/admin/payments/$PB/reject" \
  -H "Authorization: Bearer $AD" -H 'Content-Type: application/json' -d '{"reason":"again"}'
assert_eq "rejecting an already-rejected payment" "$CODE" "409"
echo "second reject is 409 ✓"

# The homeowner sees the reason and can re-upload.
echo "homeowner payment state while rejected:"
curl -s "$API/api/jobs/$JB/payment" -H "Authorization: Bearer $HO" | pretty
CAN=$(curl -s "$API/api/jobs/$JB/payment" -H "Authorization: Bearer $HO" |
      python3 -c 'import sys,json;print(json.load(sys.stdin)["canUploadReceipt"])')
assert_eq "canUploadReceipt after rejection" "$CAN" "True"

make_receipt /tmp/p4-b2.png receiptB2
echo "re-upload with a corrected receipt:"
upload_receipt "$JB" /tmp/p4-b2.png >/dev/null
assert_eq "job $JB after re-upload" "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JB;")" "PaymentReview"
assert_eq "payment after re-upload" "$(q "SELECT \"Status\" FROM \"Payments\" WHERE \"Id\"=$PB;")" "Submitted"
SQL="SELECT \"RejectReason\" IS NULL FROM \"Payments\" WHERE \"Id\"=$PB;"
[ "$(q "$SQL")" = "t" ] || fail "RejectReason was not cleared on re-upload"
SQL="SELECT count(*) FROM \"Payments\" WHERE \"JobId\"=$JB;"
assert_eq "re-upload reused the same payment row" "$(q "$SQL")" "1"
echo "re-upload resubmits the same payment, reason cleared ✓"

# ── Scenario C: receipt reuse is refused (P4-03) ─────────────────────────────
echo
echo "===== C: one bank receipt image can only back one payment ====="
JC=$(make_payable_job "P4 smoke C — receipt reuse")
track $JC

# C1 — scenario A's receipt offered against a different job.
RESP=$(upload_receipt "$JC" /tmp/p4-a.png)
echo "$RESP" | pretty
echo "$RESP" | grep -q "already been uploaded for another payment" \
  || fail "cross-job receipt reuse was not rejected: $RESP"
echo "one receipt cannot back two different jobs ✓"
assert_eq "job $JC stays AwaitingPayment" \
  "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JC;")" "AwaitingPayment"

# C2 — a distinct image is accepted.
make_receipt /tmp/p4-c.png receiptC
upload_receipt "$JC" /tmp/p4-c.png >/dev/null
assert_eq "a distinct receipt is accepted" \
  "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JC;")" "PaymentReview"
PC=$(q "SELECT \"Id\" FROM \"Payments\" WHERE \"JobId\"=$JC;")
echo "a distinct receipt is accepted ✓"

# C3 — staff reject it, which re-opens the job for a re-upload.
curl -s -X POST "$API/api/admin/payments/$PC/reject" \
  -H "Authorization: Bearer $AD" -H 'Content-Type: application/json' \
  -d '{"reason":"Wrong amount on the slip."}' >/dev/null
assert_eq "job $JC after rejection" \
  "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JC;")" "AwaitingPayment"

# C4 — re-sending the very same file is re-submitting evidence staff already
# refused, so it is refused too, with a message that says so.
RESP=$(upload_receipt "$JC" /tmp/p4-c.png)
echo "$RESP" | pretty
echo "$RESP" | grep -q "already submitted for this job" \
  || fail "re-sending the same receipt to the same job was not refused: $RESP"
echo "re-sending the same rejected receipt is refused ✓"

# C5 — a corrected image goes through.
make_receipt /tmp/p4-c2.png receiptC2
upload_receipt "$JC" /tmp/p4-c2.png >/dev/null
assert_eq "a corrected receipt is accepted" \
  "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JC;")" "PaymentReview"
assert_eq "ReUploadCount is still 1 (counted on reject)" \
  "$(q "SELECT \"ReUploadCount\" FROM \"Payments\" WHERE \"Id\"=$PC;")" "1"
echo "a corrected receipt is accepted, one send-back counted ✓"

# ── Scenario D: Hangfire expiry releases the job (P4-06) ────────────────────
echo
echo "===== D: payment window elapses → job Expired ====="
sed -i '' 's/"WindowHours": [0-9]*/"WindowHours": 0/' "$CFG"
restart_api

JD=$(make_payable_job "P4 smoke D — expiry, no payment row")
track $JD
echo "job $JD is AwaitingPayment with a 0-hour window; waiting for Hangfire…"

for _ in $(seq 1 20); do
  [ "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JD;")" = "Expired" ] && break
  sleep 2
done
assert_eq "job $JD after the payment window" \
  "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JD;")" "Expired"
# The homeowner never opened the payment screen, so there is no payment row and
# the job must still lapse rather than sit in AwaitingPayment forever.
assert_eq "expiry does not invent a payment row" \
  "$(q "SELECT count(*) FROM \"Payments\" WHERE \"JobId\"=$JD;")" "0"
SQL="SELECT \"ReasonCode\" FROM \"JobStatusHistory\" WHERE \"JobId\"=$JD ORDER BY \"Id\" DESC LIMIT 1;"
assert_eq "expiry reason code" "$(q "$SQL")" "no_payment"
echo "job with no payment row still expires, history records no_payment ✓"

# Expiry must not fire twice.
sleep 5
assert_eq "expiry is idempotent (history rows)" \
  "$(q "SELECT count(*) FROM \"JobStatusHistory\" WHERE \"JobId\"=$JD AND \"ToStatus\"='Expired';")" "1"
echo "expiry fired exactly once ✓"

# Now the same window, but the homeowner did open the payment screen.
JE=$(make_payable_job "P4 smoke D — expiry, with payment row")
track $JE
curl -s "$API/api/jobs/$JE/payment" -H "Authorization: Bearer $HO" >/dev/null
assert_eq "payment opened for job $JE" \
  "$(q "SELECT \"Status\" FROM \"Payments\" WHERE \"JobId\"=$JE;")" "Pending"
echo "job $JE is AwaitingPayment with a Pending payment; waiting for Hangfire…"

for _ in $(seq 1 20); do
  [ "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JE;")" = "Expired" ] && break
  sleep 2
done
assert_eq "job $JE after the payment window" \
  "$(q "SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JE;")" "Expired"
assert_eq "payment for job $JE after expiry" \
  "$(q "SELECT \"Status\" FROM \"Payments\" WHERE \"JobId\"=$JE;")" "Expired"
echo "an unpaid payment is marked Expired with the job ✓"

# An expired job is closed for payment.
code -X POST "$API/api/jobs/$JE/payment/upload-receipt" \
  -H "Authorization: Bearer $HO" -F "receipt=@/tmp/p4-a.png;type=image/png"
assert_eq "upload against an Expired job" "$CODE" "409"
echo "upload against an Expired job is 409 ✓"

echo
echo "=============================================="
echo " P4 SMOKE PASSED — all scenarios green"
echo "=============================================="
