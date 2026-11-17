#!/usr/bin/env bash
# scripts/run-e2e.sh — run the Flutter integration_test suites against the
# local stack in one of the v1/v2 configurations (docs/e2e_realignment_plan.md §5).
#
#   scripts/run-e2e.sh <config> [suite ...]
#   scripts/run-e2e.sh --list-devices
#
# Configs
#   C0            default flags (what ships today); homeowner + tradie suites
#   C1            UI_V2=all, homeowner persona (the real §4.4 gate)
#   C2            UI_V2=all, tradie persona (tradie screens still v1; must not regress)
#   C3:<id,id>    UI_V2=<ids>, homeowner persona (isolate one screen)
#
# Environment (all optional except E2E_DEVICE)
#   E2E_DEVICE          device id for the homeowner persona (flutter devices)
#   E2E_TRADIE_DEVICE   device id for the tradie persona (default: E2E_DEVICE)
#   FIXO_API_URL        API base, default http://localhost:5000
#                       (Android emulators: localhost is rewritten to 10.0.2.2)
#   E2E_LOG_DIR         where logs go, default ./test-logs/e2e-<config>-<timestamp>
#   FLUTTER_BIN         flutter executable, default `flutter`
#   E2E_SEED=1          run scripts/seed-test-accounts.sh first (same as --seed)
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

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

if [ "${1:-}" = "--list-devices" ]; then
  (cd "$MOBILE" && "$FLUTTER" devices); exit $?
fi
[ $# -ge 1 ] || usage 1
case "$1" in -h|--help) usage 0;; esac

CONFIG="$1"; shift
SEED="${E2E_SEED:-0}"
SUITES=()
for a in "$@"; do
  if [ "$a" = "--seed" ]; then SEED=1; else SUITES+=("${a%_test.dart}"); fi
done

case "$CONFIG" in
  C0) V2="";            PERSONAS="homeowner tradie" ;;
  C1) V2="all";         PERSONAS="homeowner" ;;
  C2) V2="all";         PERSONAS="tradie" ;;
  C3:*) V2="${CONFIG#C3:}"; PERSONAS="homeowner" ;;
  *) echo "Unknown config '$CONFIG'"; usage 1 ;;
esac
[ -n "${E2E_DEVICE:-}" ] || { echo "Set E2E_DEVICE (see: $0 --list-devices)"; exit 2; }
TRADIE_DEVICE="${E2E_TRADIE_DEVICE:-$E2E_DEVICE}"

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

is_persona_suite() { case " $PERSONA_SUITES " in *" $1 "*) return 0;; esac; return 1; }

RESULTS=()
FAILED=0

run_one() { # suite persona device
  local suite="$1" persona="$2" device="$3"
  local file="integration_test/${suite}_test.dart"
  local name="$suite-$persona"
  if [ ! -f "$MOBILE/$file" ]; then
    echo "!! $file not found"; RESULTS+=("MISSING  $name"); FAILED=1; return
  fi
  local defs=(--dart-define FIXO_DISABLE_PUSH=true --dart-define "FIXO_API_URL=$API_URL")
  [ -n "$V2" ] && defs+=(--dart-define "UI_V2=$V2")
  is_persona_suite "$suite" && defs+=(--dart-define "FIXO_PERSONA=$persona")

  echo "=== $name [$CONFIG] device=$device $(date +%H:%M:%S) ==="
  (cd "$MOBILE" && "$FLUTTER" test "$file" --device-id "$device" "${defs[@]}") \
    > "$LOG_DIR/$name.log" 2>&1
  local rc=$?
  if [ $rc -eq 0 ]; then RESULTS+=("PASS     $name")
  else RESULTS+=("FAIL     $name  (log: $LOG_DIR/$name.log)"); FAILED=1; fi
  echo "=== $name exit=$rc ==="
}

for persona in $PERSONAS; do
  if [ "$persona" = "tradie" ]; then
    device="$TRADIE_DEVICE"; list="${SUITES[*]:-$TRADIE_DEFAULT}"
  else
    device="$E2E_DEVICE";    list="${SUITES[*]:-$HOMEOWNER_DEFAULT}"
  fi
  for suite in $list; do
    # Tradie persona only matters for two-persona suites.
    if [ "$persona" = "tradie" ] && ! is_persona_suite "$suite"; then continue; fi
    run_one "$suite" "$persona" "$device"
  done
done

echo; echo "──── summary [$CONFIG] ────"
printf '%s\n' "${RESULTS[@]}" | tee "$LOG_DIR/summary.txt"
echo "logs: $LOG_DIR"
exit $FAILED
