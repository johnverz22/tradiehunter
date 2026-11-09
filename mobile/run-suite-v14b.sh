#!/bin/bash
# v1.4 verification — rerun files that were compile-blocked + match_tradie
cd "$(dirname "$0")"
PRO="9AA76BF8-982A-4044-A032-FA49CBF3D9E3"
MAX="76384481-43CD-44B1-AA74-F90533D7358E"
LOG=../test-logs-v14
mkdir -p "$LOG"

run() {
  local name=$1 file=$2 dev=$3 persona=$4
  echo "=== $name start $(date +%H:%M:%S) ==="
  flutter test "integration_test/$file" --device-id "$dev" \
    --dart-define FIXO_DISABLE_PUSH=true \
    ${persona:+--dart-define FIXO_PERSONA=$persona} \
    > "$LOG/$name.log" 2>&1
  echo "=== $name exit=$? $(date +%H:%M:%S) ==="
}

run auth           auth_test.dart          $PRO
run job_request    job_request_test.dart   $PRO
run payment        payment_test.dart       $PRO
run dispute        dispute_test.dart       $PRO
run cancel_home    cancellation_test.dart  $PRO homeowner
run match_tradie   matching_test.dart      $MAX tradie
echo "=== ALL DONE ==="
