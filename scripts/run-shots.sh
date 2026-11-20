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
# `SHOT_TEXT_SCALE` (default 1.0, 2.0 = 200%) is applied by the driver (it fails
# the run if the app renders another scale) and recorded in run.json. A run
# with a scale other than 1.0 writes to `docs/runs/v2/screenshots-text<pct>/`
# (e.g. screenshots-text200) so it cannot overwrite the 100% captures; an
# explicit SHOTS_OUT_ROOT always wins. Compare such a run with
# `scripts/compare-shots.py --shots docs/runs/v2/screenshots-text200`.
# Framework exceptions raised during the run are attributed to the screen being
# captured (`__EXCEPTION__` lines from helpers/exception_log.dart) and collected
# in `<theme>/<persona>/exceptions.txt` for the P-03 triage. Captures a driver
# could not take (`__SHOT_SKIPPED__ <name> | <reason>`) are collected in
# `<theme>/<persona>/skipped.txt`. Runs of another driver (SHOT_FILE=
# integration_test/screenshots_variants_test.dart) write `exceptions-variants.txt`
# and `skipped-variants.txt` instead, so they do not overwrite the base run's.
# Non-fatal tester warnings ("Warning: A call to tap() ... would not hit test",
# e.g. partly off-screen targets at 200%) are not framework exceptions, so they
# never reach exceptions.txt. They are collected in
# `<theme>/<persona>/warnings.txt` (P4-14), one line per distinct warning,
# attributed to the last capture taken before it ("after <name>"). Variants
# runs write `warnings-variants.txt`.
# Reproducibility (P4-04): the run refuses to start when the working tree has
# uncommitted changes outside docs/runs/ (the captures themselves are not
# counted), because the images could not be reproduced from the recorded commit.
# Override with `ALLOW_DIRTY=1` (env var or extra argument); run.json then
# records `<commit>-dirty` as before.
# Every run writes a `run.json` next to the PNGs (flag, commit, device,
# theme, text scale) into `<theme>/<persona>/` and `<theme>/shared/`.
set -u
PERSONA=$1; THEME=$2; UDID=$3; shift 3

# Capture flags. An explicit `UI_V2=...` extra argument wins over the env var,
# which wins over the default `all`.
UI_V2_VALUE=${UI_V2-all}
ALLOW_DIRTY=${ALLOW_DIRTY:-0}
TEXT_SCALE=${SHOT_TEXT_SCALE:-1.0}
EXTRA=()
for kv in "$@"; do
  case "$kv" in
    UI_V2=*) UI_V2_VALUE=${kv#UI_V2=} ;;
    ALLOW_DIRTY=*) ALLOW_DIRTY=${kv#ALLOW_DIRTY=} ;;
    SHOT_TEXT_SCALE=*) TEXT_SCALE=${kv#SHOT_TEXT_SCALE=} ;;
    *) EXTRA+=("$kv") ;;
  esac
done

# Output root: 100% text scale keeps the historical folder; any other scale gets
# its own (the scale is only known once the arguments above are parsed).
REPO=$(cd "$(dirname "$0")/.." && pwd)
if awk -v s="$TEXT_SCALE" 'BEGIN { exit !(s + 0 > 0) }'; then :; else
  echo "SHOT_TEXT_SCALE must be a positive number, got '$TEXT_SCALE'" >&2; exit 2
fi
ROOT_DIR="$REPO/docs/runs/v2/screenshots"
if awk -v s="$TEXT_SCALE" 'BEGIN { exit !(s + 0 != 1) }'; then
  ROOT_DIR="$ROOT_DIR-text$(awk -v s="$TEXT_SCALE" 'BEGIN { printf "%d", s * 100 + 0.5 }')"
fi
OUT=${SHOTS_OUT_ROOT:-$ROOT_DIR}/$THEME

DEFINES=(--dart-define "FIXO_PERSONA=$PERSONA" --dart-define FIXO_DISABLE_PUSH=true --dart-define "SHOT_THEME=$THEME")
DEFINES+=(--dart-define "UI_V2=$UI_V2_VALUE" --dart-define "SHOT_TEXT_SCALE=$TEXT_SCALE")
for kv in "${EXTRA[@]+"${EXTRA[@]}"}"; do DEFINES+=(--dart-define "$kv"); done

REPO_ROOT=$REPO
COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
# Uncommitted changes outside docs/runs/ (earlier captures live there and would
# make every second persona/theme run look dirty).
DIRTY_FILES=$(git -C "$REPO_ROOT" status --porcelain -- . ':(exclude)docs/runs' 2>/dev/null)
if [ -n "$DIRTY_FILES" ]; then
  if [ "$ALLOW_DIRTY" = "1" ]; then
    COMMIT="$COMMIT-dirty"
    echo "WARNING: dirty working tree; run.json will record $COMMIT (ALLOW_DIRTY=1)" >&2
  else
    {
      echo "Refusing to capture from a dirty working tree (images could not be"
      echo "reproduced from commit $COMMIT). Commit or stash these, or pass ALLOW_DIRTY=1:"
      echo "$DIRTY_FILES" | head -20 | sed 's/^/  /'
    } >&2
    exit 3
  fi
fi
mkdir -p "$OUT/shared" "$OUT/$PERSONA"
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
# Log files are per driver so a variants run never truncates the base run's.
DRIVER=$(basename "$SHOT_FILE" .dart); DRIVER=${DRIVER%_test}; DRIVER=${DRIVER#screenshots}
SUFFIX=${DRIVER//_/-}   # "" for the base driver, "-variants" for the variants one
EXC_FILE="$OUT/$PERSONA/exceptions$SUFFIX.txt"
SKIP_FILE="$OUT/$PERSONA/skipped$SUFFIX.txt"
WARN_FILE="$OUT/$PERSONA/warnings$SUFFIX.txt"
LAST_SHOT=startup
echo "=== persona=$PERSONA theme=$THEME udid=$UDID out=$OUT file=$SHOT_FILE ==="
echo "=== UI_V2=${UI_V2_VALUE:-<default flags>} text_scale=$TEXT_SCALE commit=$COMMIT device=$DEVICE_NAME ==="
: > "$EXC_FILE"
: > "$SKIP_FILE"
: > "$WARN_FILE"
"${FLUTTER_BIN:-flutter}" test \
  "$SHOT_FILE" \
  --device-id "$UDID" --reporter expanded "${DEFINES[@]}" 2>&1 | \
while IFS= read -r line; do
  echo "$line"
  if [[ "$line" == __EXCEPTION__* ]]; then
    echo "${line#__EXCEPTION__ }" >> "$EXC_FILE"
  fi
  if [[ "$line" =~ Warning:[[:space:]]+(A[[:space:]]+call[[:space:]]+to[[:space:]]+[A-Za-z]+\(\).*) ]]; then
    # P4-14: non-fatal tester warning (e.g. tap that would not hit test).
    # Keep the first line only (finder text can be long) and dedupe per capture.
    w="[after $LAST_SHOT] ${BASH_REMATCH[1]:0:300}"
    grep -qxF -- "$w" "$WARN_FILE" || echo "$w" >> "$WARN_FILE"
  fi
  if [[ "$line" == __SHOT_SKIPPED__* ]]; then
    echo "${line#__SHOT_SKIPPED__ }" >> "$SKIP_FILE"
  fi
  if [[ "$line" =~ __SHOT__[[:space:]]+([^[:space:]]+) ]]; then
    name="${BASH_REMATCH[1]}"
    LAST_SHOT="$name"
    mkdir -p "$OUT/$(dirname "$name")"
    xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1 \
      && echo "  [captured] $name.png" || echo "  [CAPTURE FAILED] $name"
  fi
done
echo "=== exceptions: $(grep -c . "$EXC_FILE") distinct (see $EXC_FILE) ==="
echo "=== skipped captures: $(grep -c . "$SKIP_FILE") (see $SKIP_FILE) ==="
echo "=== warnings: $(grep -c . "$WARN_FILE") distinct (see $WARN_FILE) ==="
