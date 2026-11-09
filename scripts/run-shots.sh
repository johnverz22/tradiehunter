#!/bin/bash
# V15-20 capture runner — drives integration_test/screenshots_test.dart on a
# simulator and captures `xcrun simctl io screenshot` on each __SHOT__ marker.
#
# Usage:
#   ./scripts/run-shots.sh <persona> <theme> <udid> [extra dart-defines...]
# Example:
#   ./scripts/run-shots.sh homeowner light 9AA7-... \
#     SHOT_MATCH_JOB=130 SHOT_PAYMENT_JOB=131 SHOT_BOOKED_JOB=132 \
#     SHOT_INPROGRESS_JOB=133 SHOT_OFFER_JOB=134
set -u
PERSONA=$1; THEME=$2; UDID=$3; shift 3
OUT=${SHOTS_OUT_ROOT:-/Users/john/Develop/tradies/docs/runs/v1.5/screenshots}/$THEME
mkdir -p "$OUT/shared" "$OUT/$PERSONA"

DEFINES=(--dart-define "FIXO_PERSONA=$PERSONA" --dart-define FIXO_DISABLE_PUSH=true)
for kv in "$@"; do DEFINES+=(--dart-define "$kv"); done

cd "$(dirname "$0")/../mobile"
SHOT_FILE=${SHOT_FILE:-integration_test/screenshots_test.dart}
echo "=== persona=$PERSONA theme=$THEME udid=$UDID out=$OUT file=$SHOT_FILE ==="
/Users/john/Develop/flutter/bin/flutter test \
  "$SHOT_FILE" \
  --device-id "$UDID" --reporter expanded "${DEFINES[@]}" 2>&1 | \
while IFS= read -r line; do
  echo "$line"
  if [[ "$line" =~ __SHOT__[[:space:]]+([^[:space:]]+) ]]; then
    name="${BASH_REMATCH[1]}"
    mkdir -p "$OUT/$(dirname "$name")"
    xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1 \
      && echo "  [captured] $name.png" || echo "  [CAPTURE FAILED] $name"
  fi
done
