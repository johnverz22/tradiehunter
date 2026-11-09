#!/bin/bash
# V15-20 variant fixtures — drives jobs into the states the base fixture set
# doesn't produce: AwaitingConfirmation, Completed, Cancelled, Disputed,
# payment Submitted/Rejected/Expired. Prints SHOT_* ids for the variant
# capture driver. Expired is forced at the DB level (Hangfire schedule is
# immutable once armed); all other transitions go through the real API.
set -e
API=http://localhost:5000/api
DB="docker compose exec -T db psql -U fixo -d fixo -t -A"
HOMEOWNER=homeowner-a@fixo.test
TRADIE=tradie-verified@fixo.test
STAFF=staff@fixo.test
PW=Test1234!

jget() { python3 -c "import json,sys;print(json.load(sys.stdin)$1)"; }
token() {
  for i in 1 2 3 4 5; do
    local t=$(curl -sf -X POST $API/auth/login -H 'Content-Type: application/json' \
      -d "{\"email\":\"$1\",\"password\":\"$2\"}" | jget "['token']" 2>/dev/null)
    [ -n "$t" ] && { echo "$t"; return; }
    sleep 1
  done
  echo "token failed for $1" >&2; return 1
}

HT=$(token $HOMEOWNER $PW)
TT=$(token $TRADIE $PW)
ST=$(token $STAFF $PW)

# Park competing demo tradie.
curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"tradie@fixo.nz","password":"Demo1!Fixo"}' | jget "['token']" > /tmp/demo_tok 2>/dev/null || true
[ -s /tmp/demo_tok ] && curl -s -X POST $API/profile/availability \
  -H "Authorization: Bearer $(cat /tmp/demo_tok)" \
  -H 'Content-Type: application/json' -d '{"available":false}' >/dev/null

mkjob() {
  curl -sf -X POST $API/jobs -H "Authorization: Bearer $HT" \
    -H 'Content-Type: application/json' -d "{
      \"title\":\"$1\",\"description\":\"v1.5 variant fixture.\",\"urgency\":\"Medium\",
      \"latitude\":-36.8485,\"longitude\":174.7633,\"address\":\"3 Test St, Auckland\",
      \"serviceId\":1,
      \"scheduledStartUtc\":\"$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=3)).isoformat())')\",
      \"hours\":2,\"hourlyRate\":85.50}" | jget "['id']"; }

status() { curl -s $API/jobs/$1 -H "Authorization: Bearer $HT" | jget "['status']"; }
wait_status() {
  for i in $(seq 1 25); do [ "$(status $1)" = "$2" ] && return 0; sleep 2; done
  echo "TIMEOUT $1 -> $2 (now $(status $1))" >&2; return 1; }
pending_offer() {
  curl -s $API/jobs/$1/offers/pending -H "Authorization: Bearer $TT" | \
    python3 -c "import json,sys;d=sys.stdin.read().strip();print(json.loads(d)['id'] if d else '')" 2>/dev/null; }

to_awaiting_payment() {
  curl -sf -X POST $API/jobs/$1/match -H "Authorization: Bearer $HT" \
    -H 'Content-Type: application/json' -d '{}' >/dev/null
  local oid=""
  for i in $(seq 1 25); do oid=$(pending_offer $1); [ -n "$oid" ] && break; sleep 2; done
  [ -z "$oid" ] && { echo "no pending offer for $1" >&2; return 1; }
  curl -sf -X POST $API/jobs/$1/offers/$oid/respond \
    -H "Authorization: Bearer $TT" -H 'Content-Type: application/json' \
    -d '{"response":"Accepted"}' >/dev/null
  wait_status $1 AwaitingPayment
}
make_receipt() { python3 -c "import sys,base64;sys.stdout.buffer.write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')+b'|var-$1-$RANDOM')" > /tmp/rcpt_$1.png; }
upload() { make_receipt $1; curl -sf -X POST $API/jobs/$1/payment/upload-receipt \
  -H "Authorization: Bearer $HT" -F "receipt=@/tmp/rcpt_$1.png;type=image/png" >/dev/null; }
to_booked() {
  to_awaiting_payment $1
  local pid=$(curl -sf $API/jobs/$1/payment -H "Authorization: Bearer $HT" | jget "['paymentId']")
  upload $1; wait_status $1 PaymentReview
  curl -sf -X POST $API/admin/payments/$pid/verify \
    -H "Authorization: Bearer $ST" -H 'Content-Type: application/json' -d '{}' >/dev/null
  wait_status $1 Booked
}
TS=$(date +%s)

# 1. AwaitingConfirmation (checked out, awaiting homeowner confirm)
J_AWAIT=$(mkjob "Shot AWAIT $TS"); to_booked $J_AWAIT
curl -sf -X POST $API/jobs/$J_AWAIT/check-in -H "Authorization: Bearer $TT" -H 'Content-Type: application/json' -d '{}' >/dev/null
wait_status $J_AWAIT InProgress
curl -sf -X POST $API/jobs/$J_AWAIT/check-out -H "Authorization: Bearer $TT" -H 'Content-Type: application/json' -d '{}' >/dev/null
wait_status $J_AWAIT AwaitingConfirmation
echo "SHOT_AWAIT_JOB=$J_AWAIT ($(status $J_AWAIT))"

# 2. Completed
J_DONE=$(mkjob "Shot DONE $TS"); to_booked $J_DONE
curl -sf -X POST $API/jobs/$J_DONE/check-in -H "Authorization: Bearer $TT" -H 'Content-Type: application/json' -d '{}' >/dev/null
wait_status $J_DONE InProgress
curl -sf -X POST $API/jobs/$J_DONE/check-out -H "Authorization: Bearer $TT" -H 'Content-Type: application/json' -d '{}' >/dev/null
wait_status $J_DONE AwaitingConfirmation
curl -sf -X POST $API/jobs/$J_DONE/confirm -H "Authorization: Bearer $HT" -H 'Content-Type: application/json' -d '{}' >/dev/null
wait_status $J_DONE Completed
echo "SHOT_DONE_JOB=$J_DONE ($(status $J_DONE))"

# 3. Cancelled (homeowner, pre-Booked free cancel)
J_CANC=$(mkjob "Shot CANC $TS")
curl -sf -X POST $API/jobs/$J_CANC/cancel -H "Authorization: Bearer $HT" \
  -H 'Content-Type: application/json' -d '{"reasonCode":"homeowner_changed_mind","reason":"Variant capture fixture."}' >/dev/null
wait_status $J_CANC Cancelled
echo "SHOT_CANC_JOB=$J_CANC ($(status $J_CANC))"

# 4. Disputed (open dispute on a Booked job)
J_DISP=$(mkjob "Shot DISP $TS"); to_booked $J_DISP
curl -sf -X POST $API/disputes -H "Authorization: Bearer $HT" \
  -H 'Content-Type: application/json' \
  -d "{\"jobId\":$J_DISP,\"reason\":\"quality_of_work\",\"details\":\"Variant capture fixture dispute.\"}" >/dev/null
echo "SHOT_DISP_JOB=$J_DISP ($(status $J_DISP), dispute open)"

# 5. Payment submitted (PaymentReview)
J_SUB=$(mkjob "Shot SUB $TS"); to_awaiting_payment $J_SUB
upload $J_SUB; wait_status $J_SUB PaymentReview
echo "SHOT_SUB_JOB=$J_SUB ($(status $J_SUB))"

# 6. Payment rejected (staff sends it back with a reason)
J_REJ=$(mkjob "Shot REJ $TS"); to_awaiting_payment $J_REJ
pid=$(curl -sf $API/jobs/$J_REJ/payment -H "Authorization: Bearer $HT" | jget "['paymentId']")
upload $J_REJ; wait_status $J_REJ PaymentReview
curl -sf -X POST $API/admin/payments/$pid/reject -H "Authorization: Bearer $ST" \
  -H 'Content-Type: application/json' \
  -d '{"reason":"Receipt is blurry — please re-upload a clearer photo."}' >/dev/null
echo "SHOT_REJ_JOB=$J_REJ ($(status $J_REJ))"

# 7. Expired payment window — forced at DB level (Hangfire schedule is armed
# at creation and cannot be re-dated; the row state is what the screen reads).
J_EXP=$(mkjob "Shot EXP $TS"); to_awaiting_payment $J_EXP
curl -sf $API/jobs/$J_EXP/payment -H "Authorization: Bearer $HT" >/dev/null
$DB -c "UPDATE \"Jobs\" SET \"Status\"='Expired' WHERE \"Id\"=$J_EXP;
        UPDATE \"Payments\" SET \"Status\"='Expired' WHERE \"JobId\"=$J_EXP;
        INSERT INTO \"JobStatusHistory\" (\"JobId\",\"FromStatus\",\"ToStatus\",\"ChangedByUserId\",\"ReasonCode\",\"Reason\",\"ChangedAtUtc\")
          VALUES ($J_EXP,'AwaitingPayment','Expired',(SELECT \"Id\" FROM \"AspNetUsers\" WHERE \"Email\"='$HOMEOWNER'),'no_payment','variant fixture',NOW());"
echo "SHOT_EXP_JOB=$J_EXP (forced Expired)"
echo "DONE"
