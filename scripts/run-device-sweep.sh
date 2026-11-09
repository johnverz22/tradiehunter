#!/bin/bash
# V15-20 device sweep — drives screenshots_device_test.dart; on the landscape
# marker it rotates the Simulator window via AppleScript (Cmd+Right) before
# capturing, then rotates back.
#
# Usage: ./scripts/run-device-sweep.sh <persona> <theme> <udid> <sim-name-fragment>
#   e.g. ./scripts/run-device-sweep.sh homeowner light <udid> "iPhone 17 Pro"
set -u
PERSONA=$1; THEME=$2; UDID=$3; SIMNAME=$4; shift 4
OUT=/Users/john/Develop/tradies/docs/runs/v1.5/screenshots/$THEME
mkdir -p "$OUT/$PERSONA"

DEFINES=(--dart-define "FIXO_PERSONA=$PERSONA" --dart-define FIXO_DISABLE_PUSH=true)
for kv in "$@"; do DEFINES+=(--dart-define "$kv"); done

cd "$(dirname "$0")/../mobile"
echo "=== device sweep persona=$PERSONA udid=$UDID sim=$SIMNAME ==="
/Users/john/Develop/flutter/bin/flutter test \
  integration_test/screenshots_device_test.dart \
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
