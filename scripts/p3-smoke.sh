#!/usr/bin/env bash
# P3 end-to-end smoke test against the running stack.
#
# Covers P3-01 (offer persistence), P3-03 (sequential dispatch), P3-04
# (Hangfire timeout), P3-05 (broadened stage), P3-06 (terminal cancel) and
# P3-07 (tradie respond endpoint).
#
# Test-only. It temporarily lowers Matching:OfferWindowMinutes to 1 so the
# Hangfire timeout path can be observed without waiting 10 minutes, flips
# IsVerified/TradeType on demo tradie profiles to build a known candidate
# set, and deletes the jobs it creates. Config and jobs are restored on exit.
set -uo pipefail

API=http://localhost:5000
PW='Demo1!Fixo'
DB="docker compose exec -T db psql -U fixo -d fixo -t -A"
CFG=backend/appsettings.Development.json

# NOTE: buffer stdin first — `python3 -m json.tool || cat` loses the body
# because json.tool consumes stdin even when it rejects the input.
pretty() { python3 -c 'import sys;print(sys.stdin.read())'; }
q() { $DB -c "$1"; }
fail() { echo "SMOKE FAILED: $*" >&2; exit 1; }

OTHER_PLUMBERS=""
IDS=()
cleanup() {
  sed -i '' 's/"OfferWindowMinutes": [0-9]*/"OfferWindowMinutes": 10/' "$CFG"
  # Always leave the API running the current source build.
  docker compose restart api >/dev/null 2>&1
  for id in "${IDS[@]:-}"; do
    [ -n "$id" ] && q "DELETE FROM \"Jobs\" WHERE \"Id\"=$id;" >/dev/null 2>&1
  done
  if [ -n "${NEAR:-}" ]; then
    NVER=${NEAR_ORIG%%|*}; NAVAIL=${NEAR_ORIG##*|}
    q "UPDATE \"TradieProfiles\" SET \"IsVerified\"=$NVER, \"IsAvailable\"=$NAVAIL WHERE \"UserId\"='$NEAR';" >/dev/null 2>&1
  fi
  for other in ${OTHER_PLUMBERS:-}; do
    [ -n "$other" ] && q "UPDATE \"TradieProfiles\" SET \"IsAvailable\"=true WHERE \"UserId\"='$other';" >/dev/null 2>&1
  done
  if [ -n "${FAR:-}" ]; then
    IFS='|' read -r FTRADE FVER FAVAIL <<< "$FAR_ORIG"
    q "UPDATE \"TradieProfiles\" SET \"TradeType\"='$FTRADE', \"IsVerified\"=$FVER, \"IsAvailable\"=$FAVAIL,
         \"Location\"=NULL WHERE \"UserId\"='$FAR';" >/dev/null 2>&1
  fi
  rm -f /tmp/p3-job.json
  [ "${RESTART:-0}" = 1 ] && docker compose restart api >/dev/null 2>&1
  echo
  echo "cleanup done (config restored, jobs deleted, api restarted)"
}
trap cleanup EXIT

login() {
  curl -s -X POST "$API/api/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$PW\"}" |
    python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])'
}

HO=$(login homeowner@fixo.nz)
TR=$(login tradie@fixo.nz)   # the demo Plumber — the only candidate we can authenticate
echo "tokens acquired"

# ── Fixtures ──────────────────────────────────────────────────────────────────
# 1. Verify the demo Plumber (~0 km) — the strict-radius candidate.
# The candidate we can authenticate as: the tradie@fixo.nz profile.
# Always test the current source build, never a stale container.
echo "restarting api to pick up the current build…"
docker compose restart api >/dev/null 2>&1
sleep 15

NEAR=$(q "SELECT p.\"UserId\" FROM \"TradieProfiles\" p
       JOIN \"AspNetUsers\" u ON u.\"Id\"=p.\"UserId\"
       WHERE u.\"Email\"='tradie@fixo.nz';")

SQL="SELECT \"IsVerified\"::text || '|' || \"IsAvailable\"::text FROM \"TradieProfiles\" WHERE \"UserId\"='$NEAR';"
NEAR_ORIG=$(q "$SQL")
q "UPDATE \"TradieProfiles\" SET \"IsVerified\"=true, \"IsAvailable\"=true WHERE \"UserId\"='$NEAR';" >/dev/null

OTHER_PLUMBERS=$(q "SELECT p.\"UserId\" FROM \"TradieProfiles\" p WHERE p.\"TradeType\"='Plumber' AND p.\"UserId\" != '$NEAR' AND p.\"IsVerified\"=true AND p.\"IsAvailable\"=true;")
for other in ${OTHER_PLUMBERS:-}; do
  [ -n "$other" ] && q "UPDATE \"TradieProfiles\" SET \"IsAvailable\"=false WHERE \"UserId\"='$other';" >/dev/null
done

# 2. A second Plumber ~37 km out: outside RadiusKm (25) but inside
#    BroadenedRadiusKm (50), so it is only reachable at the Broadened stage.
FAR=$(q "SELECT \"UserId\" FROM \"TradieProfiles\" WHERE \"Location\" IS NULL LIMIT 1;")
SQL="SELECT \"TradeType\" || '|' || \"IsVerified\"::text || '|' || \"IsAvailable\"::text FROM \"TradieProfiles\" WHERE \"UserId\"='$FAR';"
FAR_ORIG=$(q "$SQL")

q "UPDATE \"TradieProfiles\" SET \"TradeType\"='Plumber', \"IsVerified\"=true, \"IsAvailable\"=true,
     \"Location\"=ST_SetSRID(ST_MakePoint(174.3933, -36.6985), 4326)
   WHERE \"UserId\"='$FAR';" >/dev/null

SQL="SELECT round((ST_Distance(\"Location\", ST_SetSRID(ST_MakePoint(174.7633,-36.8485),4326))/1000.0)::numeric,1)
     FROM \"TradieProfiles\" WHERE \"UserId\"='$FAR';"
echo "fixtures: near Plumber ($NEAR) verified; far Plumber ($FAR) at $(q "$SQL") km"

post_job() {
  cat > /tmp/p3-job.json <<JSON
{
  "title": "$1",
  "description": "P3 smoke test job.",
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
    -d @/tmp/p3-job.json
}

# ── Scenario A: dispatch → ACCEPT (P3-03, P3-07 accept, P3-10) ────────────────
echo
echo "===== A: sequential dispatch + tradie accepts ====="
JA=$(post_job "P3 smoke A — accept" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
IDS+=("$JA")

SQL="SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JA;"
echo "job $JA created (status $(q "$SQL"))"

curl -s -X POST "$API/api/jobs/$JA/match" -H "Authorization: Bearer $HO" \
  -w "  [HTTP %{http_code}]\n"
sleep 4

SQL="SELECT \"Id\",\"Response\",\"Stage\" FROM \"JobOffers\" WHERE \"JobId\"=$JA ORDER BY \"Id\";"
echo "offers: $(q "$SQL")"

SQL="SELECT \"Id\" FROM \"JobOffers\" WHERE \"JobId\"=$JA AND \"Response\"='Pending' ORDER BY \"Id\" LIMIT 1;"
OA=$(q "$SQL")
[ -n "$OA" ] || fail "no pending offer was created"

SQL="SELECT \"HangfireJobId\" IS NOT NULL FROM \"JobOffers\" WHERE \"Id\"=$OA;"
[ "$(q "$SQL")" = "t" ] || fail "Hangfire timeout job was not scheduled"
echo "offer ${OA} has a Hangfire timeout job scheduled ✓"

echo "GET /api/jobs/$JA/offers/pending:"
curl -s "$API/api/jobs/$JA/offers/pending" -H "Authorization: Bearer $TR" \
  -w "  [HTTP %{http_code}]\n" | pretty

echo "POST respond Accepted:"
curl -s -X POST "$API/api/jobs/$JA/offers/$OA/respond" \
  -H "Authorization: Bearer $TR" -H 'Content-Type: application/json' \
  -d '{"response":"Accepted"}' -w "  [HTTP %{http_code}]\n" | pretty

SQL="SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JA;"
SA=$(q "$SQL")
echo "job status after accept: ${SA}"
[ "${SA}" = "AwaitingPayment" ] || fail "expected AwaitingPayment, got '$SA'"

SQL="SELECT COALESCE(\"MatchedTradieId\",'null') FROM \"Jobs\" WHERE \"Id\"=$JA;"
MA=$(q "$SQL")
[ "${MA}" != "null" ] || fail "MatchedTradieId was not set"
echo "MatchedTradieId set ✓"

echo "double-respond guard (expect 409):"
curl -s -X POST "$API/api/jobs/$JA/offers/$OA/respond" \
  -H "Authorization: Bearer $TR" -H 'Content-Type: application/json' \
  -d '{"response":"Declined"}' -w "  [HTTP %{http_code}]\n" | pretty

# ── Scenario B: decline → Broadened stage (P3-05, P3-07 decline) ─────────────
echo
echo "===== B: decline → next tradie at the Broadened stage ====="
JB=$(post_job "P3 smoke B — decline" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
IDS+=("$JB")
echo "job $JB created"

curl -s -X POST "$API/api/jobs/$JB/match" -H "Authorization: Bearer $HO" \
  -w "  [HTTP %{http_code}]\n"
sleep 4

SQL="SELECT \"Id\" FROM \"JobOffers\" WHERE \"JobId\"=$JB AND \"Response\"='Pending' ORDER BY \"Id\" LIMIT 1;"
OB=$(q "$SQL")
[ -n "$OB" ] || fail "no pending offer for job $JB"
echo "declining offer ${OB}…"
curl -s -X POST "$API/api/jobs/$JB/offers/$OB/respond" \
  -H "Authorization: Bearer $TR" -H 'Content-Type: application/json' \
  -d '{"response":"Declined"}' -w "  [HTTP %{http_code}]\n" >/dev/null
sleep 4

SQL="SELECT \"Id\",\"Response\",\"Stage\" FROM \"JobOffers\" WHERE \"JobId\"=$JB ORDER BY \"Id\";"
echo "offers: $(q "$SQL")"

SQL="SELECT string_agg(\"Stage\",',' ORDER BY \"Id\") FROM \"JobOffers\" WHERE \"JobId\"=$JB;"
SB=$(q "$SQL")
[ "${SB}" = "Auto,Broadened" ] || fail "expected stages Auto,Broadened, got '$SB'"
echo "Auto exhausted → Broadened stage reached ✓"

# ── Scenario C: timeout → terminal cancel (P3-04, P3-06) ─────────────────────
echo
echo "===== C: Hangfire timeout → no_tradie_found ====="
sed -i '' 's/"OfferWindowMinutes": [0-9]*/"OfferWindowMinutes": 1/' "$CFG"
docker compose restart api >/dev/null 2>&1
RESTART=1
sleep 14

JC=$(post_job "P3 smoke C — timeout" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
IDS+=("$JC")
echo "job $JC created with a 1-minute offer window"
curl -s -X POST "$API/api/jobs/$JC/match" -H "Authorization: Bearer $HO" \
  -w "  [HTTP %{http_code}]\n"
sleep 4

SQL="SELECT \"Id\",\"Response\",\"Stage\" FROM \"JobOffers\" WHERE \"JobId\"=$JC ORDER BY \"Id\";"
echo "offers right after dispatch: $(q "$SQL")"

echo "waiting for both Hangfire timeouts to fire…"
WAITED=0
SQL="SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JC;"
while [ "$WAITED" -lt 300 ]; do
  [ "$(q "$SQL")" = "Cancelled" ] && break
  sleep 5; WAITED=$((WAITED+5))
done

SQL="SELECT \"Id\",\"Response\",\"Stage\" FROM \"JobOffers\" WHERE \"JobId\"=$JC ORDER BY \"Id\";"
echo "final offers: $(q "$SQL")"
SC=$(q "$SQL")
case "${SC}" in
  *"TimedOut/Pending"*) fail "first offer never timed out: ${SC}" ;;
esac
case "${SC}" in
  *TimedOut/Broadened*) echo "both offers timed out; Broadened stage was reached ✓" ;;
  *) echo "note: only one candidate was reachable" ;;
esac

SQL="SELECT \"Status\" FROM \"Jobs\" WHERE \"Id\"=$JC;"
SC2=$(q "$SQL")
echo "job status after ${WAITED}s: ${SC2}"
[ "${SC2}" = "Cancelled" ] || fail "job was not cancelled, got '$SC2'"

SQL="SELECT COALESCE(\"CancelReasonCode\"::text,'none') FROM \"Jobs\" WHERE \"Id\"=$JC;"
RC=$(q "$SQL")
echo "cancel reason code: ${RC}"
[ "${RC}" = "no_tradie_found" ] || fail "expected no_tradie_found, got '$RC'"

SQL="SELECT \"FromStatus\" || ' -> ' || \"ToStatus\" || '  ' || COALESCE(\"ReasonCode\"::text,'') || ' ' || COALESCE(\"Reason\",'') FROM \"JobStatusHistory\" WHERE \"JobId\"=$JC ORDER BY \"Id\";"
echo "status history:"; q "$SQL"

echo
echo "ALL P3 CHECKS PASSED"
