#!/bin/bash
# Screenshot fixtures for v1.4 — drives jobs through the real API into the
# exact states screenshots_test.dart needs. Prints the IDs to pass as
# --dart-define SHOT_*_JOB=<id>.
#
# Usage: ./scripts/mk-shot-fixtures.sh [--with-offer]
#   --with-offer  also create a pending-offer job for the tradie pass
#                 (offer window is ~10 min — create right before that run).
set -e
API=http://localhost:5000/api
HOMEOWNER=homeowner-a@fixo.test
TRADIE=tradie-verified@fixo.test
STAFF=staff@fixo.test
DEMO_TRADIE=tradie@fixo.nz
PW=Test1234!

jget() { python3 -c "import json,sys;print(json.load(sys.stdin)$1)"; }

token() { curl -sf -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\",\"password\":\"$2\"}" | jget "['token']"; }

HT=$(token $HOMEOWNER $PW)
TT=$(token $TRADIE $PW)
ST=$(token $STAFF $PW)

# Park the demo tradie so sequential matching targets tradie-verified.
curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$DEMO_TRADIE\",\"password\":\"Demo1!Fixo\"}" | \
  jget "['token']" > /tmp/demo_tok 2>/dev/null || true
if [ -s /tmp/demo_tok ]; then
  curl -s -X POST $API/profile/availability \
    -H "Authorization: Bearer $(cat /tmp/demo_tok)" \
    -H 'Content-Type: application/json' -d '{"available":false}' >/dev/null
  echo "demo tradie parked"
fi

mkjob() { # title -> job id
  curl -sf -X POST $API/jobs -H "Authorization: Bearer $HT" \
    -H 'Content-Type: application/json' -d "{
      \"title\":\"$1\",
      \"description\":\"v1.4 screenshot fixture.\",
      \"urgency\":\"Medium\",
      \"latitude\":-36.8485,\"longitude\":174.7633,
      \"address\":\"1 Test St, Auckland\",
      \"serviceId\":1,
      \"scheduledStartUtc\":\"$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=2)).isoformat())')\",
      \"hours\":2,\"hourlyRate\":85.50}" | jget "['id']"; }

status() { curl -s $API/jobs/$1 -H "Authorization: Bearer $HT" | jget "['status']"; }

wait_status() { # jobid expected
  for i in $(seq 1 25); do
    [ "$(status $1)" = "$2" ] && return 0
    sleep 2
  done
  echo "TIMEOUT waiting for job $1 -> $2 (now $(status $1))" >&2; return 1; }

pending_offer() { # jobid -> offer id (as seen by tradie)
  curl -s $API/jobs/$1/offers/pending -H "Authorization: Bearer $TT" | \
    python3 -c "import json,sys;d=sys.stdin.read().strip();print(json.loads(d)['id'] if d else '')" 2>/dev/null; }

to_awaiting_payment() { # jobid
  curl -sf -X POST $API/jobs/$1/match -H "Authorization: Bearer $HT" \
    -H 'Content-Type: application/json' -d '{}' >/dev/null
  local oid=""
  for i in $(seq 1 25); do oid=$(pending_offer $1); [ -n "$oid" ] && break; sleep 2; done
  [ -z "$oid" ] && { echo "no pending offer for job $1" >&2; return 1; }
  curl -sf -X POST $API/jobs/$1/offers/$oid/respond \
    -H "Authorization: Bearer $TT" -H 'Content-Type: application/json' \
    -d '{"response":"Accepted"}' >/dev/null
  wait_status $1 AwaitingPayment
}

to_booked() { # jobid  (assumes already AwaitingPayment)
  local pid=$(curl -sf $API/jobs/$1/payment -H "Authorization: Bearer $HT" | jget "['paymentId']")
  python3 - <<EOF >/tmp/receipt_$1.png
import sys,base64
sys.stdout.buffer.write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')+b'|shot-$1')
EOF
  curl -sf -X POST $API/jobs/$1/payment/upload-receipt \
    -H "Authorization: Bearer $HT" -F "receipt=@/tmp/receipt_$1.png;type=image/png" >/dev/null
  wait_status $1 PaymentReview
  curl -sf -X POST $API/admin/payments/$pid/verify \
    -H "Authorization: Bearer $ST" -H 'Content-Type: application/json' -d '{}' >/dev/null
  wait_status $1 Booked
}

TS=$(date +%s)

# 1. Requested (matching screen self-dispatches)
J_REQ=$(mkjob "Shot REQ $TS")
echo "SHOT_MATCH_JOB=$J_REQ ($(status $J_REQ))"

# 2. AwaitingPayment (match result / payment / status / dispute)
J_PAY=$(mkjob "Shot PAY $TS")
to_awaiting_payment $J_PAY
echo "SHOT_PAYMENT_JOB=$J_PAY ($(status $J_PAY))"

# 3. Booked
J_BOOK=$(mkjob "Shot BOOK $TS")
to_awaiting_payment $J_BOOK && to_booked $J_BOOK
echo "SHOT_BOOKED_JOB=$J_BOOK ($(status $J_BOOK))"

# 4. InProgress
J_PROG=$(mkjob "Shot PROG $TS")
to_awaiting_payment $J_PROG && to_booked $J_PROG
curl -sf -X POST $API/jobs/$J_PROG/check-in -H "Authorization: Bearer $TT" \
  -H 'Content-Type: application/json' -d '{}' >/dev/null
wait_status $J_PROG InProgress
echo "SHOT_INPROGRESS_JOB=$J_PROG ($(status $J_PROG))"

# 5. Optional pending-offer job (tradie pass — expires in ~10 min)
if [ "$1" = "--with-offer" ]; then
  J_OFF=$(mkjob "Shot OFFER $TS")
  curl -sf -X POST $API/jobs/$J_OFF/match -H "Authorization: Bearer $HT" \
    -H 'Content-Type: application/json' -d '{}' >/dev/null
  for i in $(seq 1 25); do
    oid=$(pending_offer $J_OFF); [ -n "$oid" ] && break; sleep 2
  done
  echo "SHOT_OFFER_JOB=$J_OFF (offer $oid pending)"
fi
echo "DONE"
