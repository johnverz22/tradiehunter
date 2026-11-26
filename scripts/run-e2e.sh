#!/usr/bin/env bash
# scripts/run-e2e.sh — run the Flutter integration_test suites against the
# local stack (docs/todos/03_e2e_realignment_plan.md §5). The app is v2-only;
# a config only chooses which persona(s) run.
#
#   scripts/run-e2e.sh <config> [suite ...] [--seed] [--no-journey]
#                                           [--fail-fast] [--retry N]
#   scripts/run-e2e.sh --list-devices
#
# Configs
#   C0            homeowner + tradie personas
#   C1            homeowner persona (the §4.4 gate)
#   C2            tradie persona
#   J             integrated homeowner+tradie API journey only (no device)
#
# Before any device suite the integrated journey (scripts/e2e-journey.py)
# runs once: post -> match -> accept -> check-in/out -> approve -> pay ->
# verify -> review. If it fails the run stops, because every fixture-based
# suite would fail in setUp for the same reason. --no-journey skips it.
#
# Flags
#   --seed          run scripts/seed-test-accounts.sh first (or E2E_SEED=1)
#   --no-journey    skip the API journey pre-gate
#   --fail-fast     stop after the first failing suite
#   --retry N       re-run a failing suite up to N more times (default 0;
#                   a pass-after-retry is reported as FLAKY, not PASS)
#
# Environment (all optional except E2E_DEVICE)
#   E2E_DEVICE          device id for the homeowner persona (flutter devices)
#   E2E_TRADIE_DEVICE   device id for the tradie persona (default: E2E_DEVICE)
#   FIXO_API_URL        API base, default http://localhost:5000
#                       (Android emulators: localhost is rewritten to 10.0.2.2)
#   E2E_LOG_DIR         where logs go, default ./test-logs/e2e-<config>-<timestamp>
#   FLUTTER_BIN         flutter executable, default `flutter`
#   E2E_SEED=1          run scripts/seed-test-accounts.sh first (same as --seed)
#   E2E_SUITE_TIMEOUT   seconds before a suite is killed (default 1500; needs
#                       `timeout`/`gtimeout`, otherwise no limit)
#
# Suites run one after another: two iOS builds share mobile/build and collide
# if run in parallel (docs/TESTING.md).
# (no `set -u`: empty arrays break it on macOS bash 3.2)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
FLUTTER="${FLUTTER_BIN:-flutter}"
API_URL="${FIXO_API_URL:-http://localhost:5000}"

# Suites that read FIXO_PERSONA (two-persona files). Others are homeowner-only.
PERSONA_SUITES="matching job_lifecycle cancellation"
HOMEOWNER_DEFAULT="auth job_request payment dispute cancellation job_lifecycle matching"
TRADIE_DEFAULT="cancellation job_lifecycle matching"

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit "${1:-0}"; }

if [ "${1:-}" = "--list-devices" ]; then
  (cd "$MOBILE" && "$FLUTTER" devices); exit $?
fi
[ $# -ge 1 ] || usage 1
case "$1" in -h|--help) usage 0;; esac

CONFIG="$1"; shift
SEED="${E2E_SEED:-0}"
SUITES=()
JOURNEY=1; FAIL_FAST=0; RETRIES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seed) SEED=1 ;;
    --no-journey) JOURNEY=0 ;;
    --fail-fast) FAIL_FAST=1 ;;
    --retry) shift; RETRIES="${1:-}"
             case "$RETRIES" in ''|*[!0-9]*) echo "--retry needs a number"; exit 1;; esac ;;
    -*) echo "Unknown flag '$1'"; usage 1 ;;
    *) SUITES+=("${1%_test.dart}") ;;
  esac
  shift
done

case "$CONFIG" in
  C0) PERSONAS="homeowner tradie" ;;
  C1) PERSONAS="homeowner" ;;
  C2) PERSONAS="tradie" ;;
  J)  PERSONAS="" ;;
  *) echo "Unknown config '$CONFIG'"; usage 1 ;;
esac
if [ "$CONFIG" != "J" ]; then
  [ -n "${E2E_DEVICE:-}" ] || { echo "Set E2E_DEVICE (see: $0 --list-devices)"; exit 2; }
fi
TRADIE_DEVICE="${E2E_TRADIE_DEVICE:-${E2E_DEVICE:-}}"

# ── preflight ────────────────────────────────────────────────────────────────
if ! curl -s -o /dev/null --max-time 5 "$API_URL"; then
  echo "API not reachable at $API_URL — run: docker compose up -d"; exit 2
fi
if [ "$SEED" = "1" ]; then
  echo "Seeding test accounts…"
  FIXO_API_URL="$API_URL" bash "$ROOT/scripts/seed-test-accounts.sh" || {
    echo "Seeding failed"; exit 2; }
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE_CFG="$(echo "$CONFIG" | tr ':,' '__')"
LOG_DIR="${E2E_LOG_DIR:-$ROOT/test-logs/e2e-$SAFE_CFG-$STAMP}"
mkdir -p "$LOG_DIR"

# Suites park the demo tradie in setUpAll and restore it in tearDownAll; an
# aborted run (Ctrl-C, kill, timeout) skips tearDownAll and leaves it parked,
# which silently breaks the next run's matching. Always restore on exit.
cleanup() { FIXO_API_URL="$API_URL" python3 "$ROOT/scripts/e2e-journey.py" --restore-tradies >/dev/null 2>&1; }
trap cleanup EXIT
trap 'echo; echo "interrupted"; exit 130' INT TERM

# Per-suite timeout wrapper, if the platform has one.
TIMEOUT_CMD=""
for c in timeout gtimeout; do command -v "$c" >/dev/null 2>&1 && { TIMEOUT_CMD="$c"; break; }; done
SUITE_TIMEOUT="${E2E_SUITE_TIMEOUT:-1500}"

is_persona_suite() { case " $PERSONA_SUITES " in *" $1 "*) return 0;; esac; return 1; }

RESULTS=()
FAILED=0
STOP=0
JUNIT_CASES=()

if [ "$JOURNEY" = "1" ] || [ "$CONFIG" = "J" ]; then
  echo "=== integrated journey (homeowner + tradie, API) ==="
  FIXO_API_URL="$API_URL" python3 "$ROOT/scripts/e2e-journey.py" \
    --junit "$LOG_DIR/journey.xml" 2>&1 | tee "$LOG_DIR/journey.log"
  jrc=${PIPESTATUS[0]}
  if [ "$jrc" -eq 0 ]; then RESULTS+=("PASS     journey")
  else
    RESULTS+=("FAIL     journey  (log: $LOG_DIR/journey.log)")
    echo
    echo "Journey failed — stopping before the device suites (fixtures would fail the same way)."
    echo "Re-run with --no-journey to force the device suites anyway."
    printf '%s\n' "${RESULTS[@]}" | tee "$LOG_DIR/summary.txt"
    exit $([ "$jrc" -eq 2 ] && echo 2 || echo 1)
  fi
fi

run_one() { # suite persona device
  local suite="$1" persona="$2" device="$3"
  local file="integration_test/${suite}_test.dart"
  local name="$suite-$persona"
  if [ ! -f "$MOBILE/$file" ]; then
    echo "!! $file not found"; RESULTS+=("MISSING  $name"); FAILED=1; return
  fi
  local defs=(--dart-define FIXO_DISABLE_PUSH=true --dart-define "FIXO_API_URL=$API_URL")
  is_persona_suite "$suite" && defs+=(--dart-define "FIXO_PERSONA=$persona")

  local attempt=0 rc=1 t0
  while [ $attempt -le "$RETRIES" ]; do
    local log="$LOG_DIR/$name.log"
    [ $attempt -gt 0 ] && log="$LOG_DIR/$name.retry$attempt.log"
    echo "=== $name [$CONFIG] device=$device attempt=$((attempt+1)) $(date +%H:%M:%S) ==="
    t0=$(date +%s)
    local pre=()
    [ -n "$TIMEOUT_CMD" ] && pre=("$TIMEOUT_CMD" "$SUITE_TIMEOUT")
    (cd "$MOBILE" && "${pre[@]}" "$FLUTTER" test "$file" --device-id "$device" "${defs[@]}") \
      > "$log" 2>&1
    rc=$?
    echo "=== $name exit=$rc ($(( $(date +%s) - t0 ))s) ==="
    [ $rc -eq 0 ] && break
    [ $rc -eq 124 ] && echo "!! $name timed out after ${SUITE_TIMEOUT}s"
    attempt=$((attempt+1))
    # A failed run can leave the demo tradie parked; unpark before retrying.
    [ $attempt -le "$RETRIES" ] && cleanup
  done

  local secs=$(( $(date +%s) - t0 ))
  if [ $rc -eq 0 ] && [ $attempt -eq 0 ]; then RESULTS+=("PASS     $name")
  elif [ $rc -eq 0 ]; then RESULTS+=("FLAKY    $name  (passed on attempt $((attempt+1)))")
  else
    RESULTS+=("FAIL     $name  (log: $LOG_DIR/$name.log)"); FAILED=1
    [ "$FAIL_FAST" = "1" ] && STOP=1
  fi
}

for persona in $PERSONAS; do
  if [ "$persona" = "tradie" ]; then
    device="$TRADIE_DEVICE"; list="${SUITES[*]:-$TRADIE_DEFAULT}"
  else
    device="$E2E_DEVICE";    list="${SUITES[*]:-$HOMEOWNER_DEFAULT}"
  fi
  for suite in $list; do
    [ "$STOP" = "1" ] && break
    # Tradie persona only matters for two-persona suites.
    if [ "$persona" = "tradie" ] && ! is_persona_suite "$suite"; then continue; fi
    run_one "$suite" "$persona" "$device"
  done
  [ "$STOP" = "1" ] && { echo "--fail-fast: stopping"; break; }
done

echo; echo "──── summary [$CONFIG] ────"
printf '%s\n' "${RESULTS[@]}" | tee "$LOG_DIR/summary.txt"
echo "logs: $LOG_DIR"
exit $FAILED
