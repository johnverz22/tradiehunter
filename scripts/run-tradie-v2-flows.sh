#!/bin/bash
# Phase 5 (sub-plan 5.5 / 5.9): per-id `UI_V2=<id>` headless runs for the tradie
# screens, then once with `UI_V2=all`. One command instead of hand-typing each
# `flutter test --dart-define=UI_V2=<id> ...` line.
#
# Usage (from repo root):
#   ./scripts/run-tradie-v2-flows.sh            # every id, then `all`
#   ./scripts/run-tradie-v2-flows.sh tr_jobs    # one id (+ `all` unless NO_ALL=1)
#
# Runs the static guards first, keeps going after a failure and prints a
# summary table; exit code is non-zero if anything failed. Does NOT add any id
# to `v2Screens` and does not replace owner visual QA (5.5).
set -u
cd "$(dirname "$0")/.." || exit 1

declare -A TESTS=(
  [tr_job]="test/tradie_job_detail_test.dart test/tradie_job_card_test.dart test/ui/phase5_tr_job_test.dart test/ui/phase5_tr_job_state_test.dart"
  [tr_extra_cost]="test/tradie_job_detail_test.dart test/ui/phase5_tr_extra_cost_test.dart"
  [tr_complete]="test/tradie_job_detail_test.dart test/ui/phase5_tr_complete_test.dart"
  [tr_earnings]="test/ui/phase5_tr_earnings_test.dart test/profile_truthfulness_test.dart"
  [tr_onboarding]="test/tradie_onboarding_test.dart test/tradie_onboarding_wizard_test.dart test/ui/phase5_tr_onboarding_test.dart"
  [tr_jobs]="test/homeowner_jobs_ui_test.dart test/ui/phase5_tr_jobs_test.dart"
  [tr_profile]="test/profile_truthfulness_test.dart test/ui/phase5_tr_profile_summary_test.dart test/ui/phase5_tr_viewer_profile_test.dart"
  [wide_layout]="test/ui/phase5_tr_jobs_test.dart"
)
ORDER=(tr_job tr_extra_cost tr_complete tr_earnings tr_onboarding tr_jobs tr_profile wide_layout)
ALL_TESTS="test/offer_response_test.dart test/tradie_dashboard_test.dart test/tradie_dashboard_redesign_test.dart test/tradie_job_detail_test.dart test/tradie_onboarding_test.dart test/homeowner_jobs_ui_test.dart test/profile_truthfulness_test.dart test/ui/"

IDS=("${ORDER[@]}"); [ $# -gt 0 ] && IDS=("$@")
for id in "${IDS[@]}"; do
  [ -n "${TESTS[$id]:-}" ] || { echo "unknown id: $id (known: ${ORDER[*]})"; exit 2; }
done

declare -a ROWS; FAIL=0
run() { # label, define, tests...
  local label=$1 define=$2; shift 2
  echo "=== $label (UI_V2=$define) ==="
  if (cd mobile && flutter test --no-pub --dart-define=UI_V2="$define" "$@"); then
    ROWS+=("PASS  $label"); else ROWS+=("FAIL  $label"); FAIL=1; fi
}

python3 scripts/check_ui_boundary.py || FAIL=1
(cd mobile && flutter analyze --no-pub --fatal-infos) || FAIL=1

for id in "${IDS[@]}"; do run "$id" "$id" ${TESTS[$id]}; done
[ "${NO_ALL:-0}" = 1 ] || run "all" all $ALL_TESTS

echo; echo "--- summary ---"; printf '%s\n' "${ROWS[@]}"
exit $FAIL
