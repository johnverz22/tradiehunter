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
#
# Flags (fix plan P-02): captures run with `UI_V2=all` by default so a v1
# screen cannot be mistaken for a v2 one. Override with the env var
# (`UI_V2=ho_home,ho_jobs ./scripts/run-shots.sh ...`), `UI_V2=` (empty,
# i.e. the shipped default flags) or an extra `UI_V2=...` argument.
# `SHOT_TEXT_SCALE` (default 1.0) is passed through and recorded.
# Every run writes a `run.json` next to the PNGs (flag, commit, device,
# theme, text scale) into `<theme>/<persona>/` and `<theme>/shared/`.
set -u
PERSONA=$1; THEME=$2; UDID=$3; shift 3
OUT=${SHOTS_OUT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)/docs/runs/v2/screenshots}/$THEME
mkdir -p "$OUT/shared" "$OUT/$PERSONA"

# Capture flags. An explicit `UI_V2=...` extra argument wins over the env var,
# which wins over the default `all`.
UI_V2_VALUE=${UI_V2-all}
TEXT_SCALE=${SHOT_TEXT_SCALE:-1.0}
EXTRA=()
for kv in "$@"; do
  case "$kv" in
    UI_V2=*) UI_V2_VALUE=${kv#UI_V2=} ;;
    SHOT_TEXT_SCALE=*) TEXT_SCALE=${kv#SHOT_TEXT_SCALE=} ;;
    *) EXTRA+=("$kv") ;;
  esac
done

DEFINES=(--dart-define "FIXO_PERSONA=$PERSONA" --dart-define FIXO_DISABLE_PUSH=true --dart-define "SHOT_THEME=$THEME")
DEFINES+=(--dart-define "UI_V2=$UI_V2_VALUE" --dart-define "SHOT_TEXT_SCALE=$TEXT_SCALE")
for kv in "${EXTRA[@]+"${EXTRA[@]}"}"; do DEFINES+=(--dart-define "$kv"); done

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]; then COMMIT="$COMMIT-dirty"; fi
DEVICE_NAME=$(xcrun simctl list devices 2>/dev/null | sed -n "s/^[[:space:]]*\(.*\) ($UDID) .*/\1/p" | head -1)
[ -n "$DEVICE_NAME" ] || DEVICE_NAME=unknown
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Minimal JSON string escaping (values here are short, plain tokens).
json_str() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
RUN_JSON=$(printf '{\n  "ui_v2": %s,\n  "commit": %s,\n  "device": %s,\n  "udid": %s,\n  "persona": %s,\n  "theme": %s,\n  "text_scale": %s,\n  "started_at": %s\n}\n' \
  "$(json_str "$UI_V2_VALUE")" "$(json_str "$COMMIT")" "$(json_str "$DEVICE_NAME")" \
  "$(json_str "$UDID")" "$(json_str "$PERSONA")" "$(json_str "$THEME")" \
  "$(json_str "$TEXT_SCALE")" "$(json_str "$STARTED_AT")")
printf '%s' "$RUN_JSON" > "$OUT/$PERSONA/run.json"
printf '%s' "$RUN_JSON" > "$OUT/shared/run.json"

cd "$(dirname "$0")/../mobile"
SHOT_FILE=${SHOT_FILE:-integration_test/screenshots_test.dart}
echo "=== persona=$PERSONA theme=$THEME udid=$UDID out=$OUT file=$SHOT_FILE ==="
echo "=== UI_V2=${UI_V2_VALUE:-<default flags>} text_scale=$TEXT_SCALE commit=$COMMIT device=$DEVICE_NAME ==="
"${FLUTTER_BIN:-flutter}" test \
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
