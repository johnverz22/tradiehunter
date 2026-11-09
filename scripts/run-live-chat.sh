#!/bin/bash
# V15-16 live two-client chat verification — drives
# integration_test/live_chat_test.dart on a simulator while the host acts as
# the second client (homeowner) via the REST API and backgrounds/foregrounds
# the app with simctl to exercise reconnect + reconcile.
#
# Usage:
#   ./scripts/run-live-chat.sh <udid> <jobId> [theme]
# The job must be in a chat-open state (Booked/InProgress) with
# tradie-verified matched and homeowner-a as owner.
set -u
UDID=$1; JOB=$2; THEME=${3:-light}
OUT=/Users/john/Develop/tradies/docs/runs/v1.5/screenshots/$THEME
mkdir -p "$OUT/tradie"

API=http://localhost:5000/api
HT=$(curl -sf -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"homeowner-a@fixo.test","password":"Test1234!"}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['token'])")

send() { curl -sf -X POST $API/jobs/$JOB/messages -H "Authorization: Bearer $HT" \
  -H 'Content-Type: application/json' -d "{\"content\":\"$1\"}" >/dev/null \
  && echo "  [sent] $1" || echo "  [SEND FAILED] $1"; }

cd "$(dirname "$0")/../mobile"
echo "=== live chat: udid=$UDID job=$JOB ==="
/Users/john/Develop/flutter/bin/flutter test \
  integration_test/live_chat_test.dart \
  --device-id "$UDID" --reporter expanded \
  --dart-define LIVE_CHAT_JOB=$JOB \
  --dart-define FIXO_DISABLE_PUSH=true 2>&1 | \
while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *__LIVE_READY__*)
      sleep 2; send "LIVE-MARKER-ONE" ;;
    *__LIVE_BG__*)
      sleep 1
      echo "  [simctl] backgrounding fixo (launch Preferences)"
      xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null 2>&1
      sleep 8
      send "LIVE-MARKER-TWO"
      sleep 2
      echo "  [simctl] relaunching fixo"
      xcrun simctl launch "$UDID" nz.co.fixo.fixo >/dev/null 2>&1 ;;
    *__SHOT__*)
      name=$(echo "$line" | sed -E 's/.*__SHOT__[[:space:]]*//; s/[[:space:]]*$//')
      mkdir -p "$OUT/$(dirname "$name")"
      xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1 \
        && echo "  [captured] $name.png" || echo "  [CAPTURE FAILED] $name" ;;
  esac
done
