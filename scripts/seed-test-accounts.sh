#!/usr/bin/env bash
# scripts/seed-test-accounts.sh
#
# Creates all test accounts needed by the integration test suite.
# Safe to run multiple times — accounts that already exist are skipped.
#
# Accounts created:
#   homeowner-a@fixo.test  / Test1234!  (Homeowner, verified)
#   tradie-verified@fixo.test / Test1234! (Tradie, verified, profile + credential approved)
#   unverified@fixo.test   / Test1234!  (Homeowner, email NOT verified — for P1-06)
#   staff@fixo.test        / Test1234!  (Staff — created via superadmin invite endpoint)
#
# Prerequisites:
#   docker compose up -d   (API must be running)
#
# Usage:
#   bash scripts/seed-test-accounts.sh
#   FIXO_API_URL=http://localhost:5000 bash scripts/seed-test-accounts.sh

set -euo pipefail

API="${FIXO_API_URL:-http://localhost:5000}/api"
PASS="Test1234!"
ADMIN_EMAIL="admin@fixo.nz"
ADMIN_PASS="Admin1!Fixo"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $1"; }
skip() { echo -e "${YELLOW}SKIP${NC}  $1"; }
fail() { echo -e "${RED}FAIL${NC}  $1"; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────────

post() {
  local path="$1"; shift
  local body="$1"; shift
  local token="${1:-}"
  local auth_header=""
  [ -n "$token" ] && auth_header="-H \"Authorization: Bearer $token\""
  curl -s -o /tmp/fixo_seed_resp.json -w "%{http_code}" \
    -X POST "$API$path" \
    -H "Content-Type: application/json" \
    ${token:+-H "Authorization: Bearer $token"} \
    -d "$body"
}

get_token() {
  local email="$1" pass="$2"
  local resp
  resp=$(curl -s -X POST "$API/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$pass\"}")
  echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null
}

psql_run() {
  docker compose exec -T db psql -U fixo -d fixo -tA -c "$1" 2>/dev/null
}

account_exists() {
  local email="$1"
  local count
  count=$(psql_run "SELECT count(*) FROM \"AspNetUsers\" WHERE \"Email\"='$email';")
  [ "${count:-0}" -gt "0" ]
}

verify_email_direct() {
  # Directly marks email as verified in the DB — used for test accounts
  # where we don't want to go through the OTP flow.
  local email="$1"
  psql_run "UPDATE \"AspNetUsers\" SET \"EmailVerified\"=true, \"EmailVerifiedAtUtc\"=now() WHERE \"Email\"='$email';"
}

echo ""
echo "=== Fixo Test Account Seed ==="
echo "API: $API"
echo ""

# ── 1. homeowner-a@fixo.test ─────────────────────────────────────────────────
EMAIL="homeowner-a@fixo.test"
if account_exists "$EMAIL"; then
  skip "$EMAIL already exists"
else
  STATUS=$(post "/auth/register" "{\"firstName\":\"Homeowner\",\"lastName\":\"Alpha\",\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"role\":0}")
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "201" ]; then
    verify_email_direct "$EMAIL"
    pass "Created $EMAIL (Homeowner, verified)"
  else
    fail "Failed to create $EMAIL (HTTP $STATUS): $(cat /tmp/fixo_seed_resp.json)"
  fi
fi

# ── 2. tradie-verified@fixo.test ─────────────────────────────────────────────
EMAIL="tradie-verified@fixo.test"
if ! account_exists "$EMAIL"; then
  STATUS=$(post "/auth/register" "{\"firstName\":\"Tradie\",\"lastName\":\"Verified\",\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"role\":1}")
  if [ "$STATUS" != "200" ] && [ "$STATUS" != "201" ]; then
    fail "Failed to create $EMAIL (HTTP $STATUS): $(cat /tmp/fixo_seed_resp.json)"
  fi
  pass "Created $EMAIL"
fi

verify_email_direct "$EMAIL"
TOKEN=$(get_token "$EMAIL" "$PASS")
if [ -n "$TOKEN" ]; then
  curl -s -o /dev/null -X PUT "$API/profile" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
      "firstName":"Tradie","lastName":"Verified",
      "phone":"+6421000001",
      "address":"1 Test St, Auckland",
      "latitude":-36.8485,"longitude":174.7633,
      "tradeCategory":"Plumbing",
      "serviceRadiusKm":25
    }' || true
fi

PROFILE_ID=$(psql_run "SELECT \"Id\" FROM \"TradieProfiles\" WHERE \"UserId\"=(SELECT \"Id\" FROM \"AspNetUsers\" WHERE \"Email\"='$EMAIL');")
if [ -n "$PROFILE_ID" ]; then
  psql_run "UPDATE \"TradieProfiles\" SET \"IsVerified\"=true, \"IsAvailable\"=true WHERE \"Id\"=$PROFILE_ID;" || true
  psql_run "INSERT INTO \"TradieCredentials\" (\"TradieProfileId\",\"Type\",\"FileKey\",\"OriginalFileName\",\"Status\")
            SELECT $PROFILE_ID,'License','seed/tradie-verified-license.pdf','license.pdf','Approved'
            WHERE NOT EXISTS (SELECT 1 FROM \"TradieCredentials\" WHERE \"TradieProfileId\"=$PROFILE_ID AND \"Type\"='License' AND \"Status\"='Approved');" || true
  psql_run "INSERT INTO \"TradieRates\" (\"TradieProfileId\",\"ServiceId\",\"HourlyRate\")
            SELECT $PROFILE_ID, 1, 85.50
            WHERE NOT EXISTS (SELECT 1 FROM \"TradieRates\" WHERE \"TradieProfileId\"=$PROFILE_ID AND \"ServiceId\"=1);
            UPDATE \"TradieRates\" SET \"HourlyRate\"=85.50 WHERE \"TradieProfileId\"=$PROFILE_ID AND \"ServiceId\"=1;" || true
fi
pass "$EMAIL verified with approved License credential and Service 1 rate (\$85.50)"

# ── 3. unverified@fixo.test ──────────────────────────────────────────────────
EMAIL="unverified@fixo.test"
if account_exists "$EMAIL"; then
  skip "$EMAIL already exists"
else
  STATUS=$(post "/auth/register" "{\"firstName\":\"Unverified\",\"lastName\":\"User\",\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"role\":0}")
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "201" ]; then
    # Deliberately do NOT verify — this account tests the OTP gate (P1-06)
    pass "Created $EMAIL (Homeowner, NOT verified — intentional)"
  else
    fail "Failed to create $EMAIL (HTTP $STATUS): $(cat /tmp/fixo_seed_resp.json)"
  fi
fi

# ── 4. staff@fixo.test ───────────────────────────────────────────────────────
EMAIL="staff@fixo.test"
STAFF_TOKEN=$(get_token "$EMAIL" "$PASS")
if [ -n "$STAFF_TOKEN" ]; then
  pass "$EMAIL already exists and active (login succeeded)"
else
  # Staff accounts are created via the superadmin invite endpoint.
  ADMIN_TOKEN=$(get_token "$ADMIN_EMAIL" "$ADMIN_PASS")
  if [ -z "$ADMIN_TOKEN" ]; then
    fail "Could not get superadmin token — is the stack running? (admin@fixo.nz / Admin1!Fixo)"
  fi

  STATUS=$(post "/admin/staff/invite" "{\"email\":\"$EMAIL\",\"firstName\":\"Staff\",\"lastName\":\"User\"}" "$ADMIN_TOKEN")
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "201" ] || [ "$STATUS" = "409" ]; then
    # Retrieve the set-password token from MailHog
    MAILHOG_URL="${MAILHOG_URL:-http://localhost:8025}"
    SET_TOKEN=$(curl -s "$MAILHOG_URL/api/v2/search?kind=to&query=$EMAIL" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get("items", [])
    if items:
        body = items[0]["Content"]["Body"]
        parts = [p.strip() for p in body.strip().split() if len(p.strip()) > 20]
        if parts:
            print(parts[-1])
except Exception:
    pass
' 2>/dev/null || true)

    if [ -z "$SET_TOKEN" ]; then
      # Fallback to DB RegistrationToken if present
      SET_TOKEN=$(psql_run "SELECT \"RegistrationToken\" FROM \"AspNetUsers\" WHERE \"Email\"='$EMAIL';" 2>/dev/null || true)
    fi

    if [ -n "$SET_TOKEN" ]; then
      SET_STATUS=$(post "/admin/staff/set-password" "{\"email\":\"$EMAIL\",\"token\":\"$SET_TOKEN\",\"newPassword\":\"$PASS\"}")
      if [ "$SET_STATUS" = "200" ]; then
        pass "Created/activated $EMAIL (Staff, password set)"
      else
        skip "$EMAIL invited but set-password failed (HTTP $SET_STATUS) — inspect MailHog"
      fi
    else
      skip "$EMAIL invited — retrieve token from MailHog/DB to set password manually"
    fi
  else
    fail "Failed to invite $EMAIL (HTTP $STATUS): $(cat /tmp/fixo_seed_resp.json)"
  fi
fi

echo ""
echo "=== Seed complete ==="
echo ""
echo "Test accounts:"
echo "  homeowner-a@fixo.test     / $PASS  (Homeowner)"
echo "  tradie-verified@fixo.test / $PASS  (Tradie, verified)"
echo "  unverified@fixo.test      / $PASS  (Homeowner, OTP not done)"
echo "  staff@fixo.test           / $PASS  (Staff / admin web)"
echo ""
