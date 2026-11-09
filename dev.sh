#!/usr/bin/env bash
# dev.sh — Start the full Fixo dev stack
#
# Usage:
#   ./dev.sh                  # start Docker services + Flutter (Android emulator)
#   ./dev.sh ios              # start Docker services + Flutter (iOS simulator)
#   ./dev.sh web              # start Docker services + Flutter (Chrome)
#   ./dev.sh android2         # start Docker services + Flutter on TWO Android emulators (parallel)
#   ./dev.sh ios2             # start Docker services + Flutter on TWO iOS simulators (parallel)
#   ./dev.sh ios2-rebuild     # rebuild + reinstall + relaunch on both iOS sims, then attach
#   ./dev.sh android-attach   # attach flutter to the 2nd emulator using the last build (no Docker, no rebuild)
#   ./dev.sh docker           # Docker services only (no Flutter)
#   ./dev.sh stop             # stop all Docker services
#   ./dev.sh android --build  # force-rebuild Docker images then start Flutter
#
# Prerequisites: Docker (OrbStack), Flutter on host, mobile/.env.json filled in.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$REPO_ROOT/mobile"
ENV_JSON="$MOBILE_DIR/.env.json"
ENV_JSON_EXAMPLE="$MOBILE_DIR/.env.json.example"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}▶ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $*${NC}"; }
error() { echo -e "${RED}✖ $*${NC}" >&2; }

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_stop() {
  info "Stopping Docker services..."
  docker compose -f "$REPO_ROOT/docker-compose.yml" down
}

cmd_docker() {
  local build_flag="${1:-}"

  # Without --build: already-running containers are left untouched.
  # Pass --build explicitly (./dev.sh android --build) after Dockerfile changes.
  if [[ "$build_flag" == "--build" ]]; then
    info "Building and starting Docker services..."
    docker compose -f "$REPO_ROOT/docker-compose.yml" up -d --build
  else
    info "Starting Docker services (skipping rebuild — pass --build to force)..."
    docker compose -f "$REPO_ROOT/docker-compose.yml" up -d
  fi

  info "Services up. API → http://localhost:5000  Admin → http://localhost:3000"
}

# Ensure .env.json exists and warn about placeholders (shared by all runners).
ensure_env_json() {
  if [[ ! -f "$ENV_JSON" ]]; then
    if [[ -f "$ENV_JSON_EXAMPLE" ]]; then
      warn ".env.json not found — copying from .env.json.example"
      cp "$ENV_JSON_EXAMPLE" "$ENV_JSON"
      warn "Edit $ENV_JSON and replace GOOGLE_CLIENT_ID, then re-run."
      exit 1
    else
      error ".env.json missing and no example file found. Create $ENV_JSON."
      exit 1
    fi
  fi

  if grep -q "REPLACE_WITH" "$ENV_JSON"; then
    warn ".env.json still contains placeholder values."
    warn "Google Sign-In will not work until you fill them in."
  fi
}

cmd_flutter() {
  local target="${1:-android}"

  ensure_env_json

  local flutter_args=("--dart-define-from-file=$ENV_JSON")

  case "$target" in
    ios)     flutter_args+=("-d" "$(get_ios_device)") ;;
    web)     flutter_args+=("-d" "chrome") ;;
    android) flutter_args+=("-d" "$(get_android_device)") ;;
    *)       error "Unknown target: $target (use android|ios|web)"; exit 1 ;;
  esac

  info "Starting Flutter ($target) with dart-define from .env.json..."
  cd "$MOBILE_DIR"
  flutter run "${flutter_args[@]}"
}

get_android_device() {
  local dev
  # Extract the device-ID field (column 2 after •) from the first Android line.
  dev=$(flutter devices 2>/dev/null \
    | grep -i android \
    | head -1 \
    | awk -F '•' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
  if [[ -z "$dev" ]]; then
    warn "No Android device found. Start an emulator first."
    echo "android"
  else
    echo "$dev"
  fi
}

# Launch Flutter on two Android emulators in parallel.
# Each instance streams prefixed output; Ctrl-C kills both.
cmd_flutter_duo() {
  ensure_env_json

  # Collect Android device IDs into an array (macOS bash 3.2 compatible)
  local raw
  raw=$(flutter devices 2>/dev/null | grep -i android | awk -F '•' '{print $2}')
  local DEVICES=()
  while IFS= read -r line; do
    local trimmed
    trimmed=$(echo "$line" | xargs)   # trim whitespace
    [[ -n "$trimmed" ]] && DEVICES+=("$trimmed")
  done <<< "$raw"

  if [[ ${#DEVICES[@]} -lt 2 ]]; then
    error "Need at least 2 running Android emulators, found ${#DEVICES[@]}."
    error "Start a second emulator with: flutter emulators --launch <emulator_id>"
    error "Available emulators:"
    flutter emulators 2>/dev/null | grep -v '^$' | head -10 >&2
    exit 1
  fi

  local dev1="${DEVICES[0]}"
  local dev2="${DEVICES[1]}"

  info "Device 1: $dev1"
  info "Device 2: $dev2"

  cd "$MOBILE_DIR"

  # Build the APK once before launching in parallel.
  # Two concurrent `flutter run` calls share the same build/ directory and
  # both trigger a Gradle build, which causes a Gradle file-lock conflict —
  # one instance hangs waiting for the lock and gets stuck on the splash screen.
  # Building once up-front lets both `flutter run --no-build` calls skip the
  # Gradle step entirely and go straight to install + run.
  info "Building APK (once)..."
  flutter build apk --debug --dart-define-from-file="$ENV_JSON"

  info "Launching on both emulators (Ctrl-C stops both)..."

  # --no-build skips the Gradle step; both instances just install + start the
  # pre-built APK on their respective device.
  flutter run --no-build --dart-define-from-file="$ENV_JSON" -d "$dev1" 2>&1 \
    | sed "s/^/[emu-1] /" &
  PID1=$!

  flutter run --no-build --dart-define-from-file="$ENV_JSON" -d "$dev2" 2>&1 \
    | sed "s/^/[emu-2] /" &
  PID2=$!

  # Trap Ctrl-C so both processes are cleaned up together
  trap "info 'Stopping both Flutter instances...'; kill $PID1 $PID2 2>/dev/null; exit 0" INT TERM

  wait $PID1 $PID2
}

get_ios_device() {
  local dev
  dev=$(flutter devices 2>/dev/null | grep -i iphone | head -1 | awk -F '•' '{print $2}' | xargs)
  if [[ -z "$dev" ]]; then
    warn "No iOS simulator found. Start one from Xcode first."
    echo "ios"
  else
    echo "$dev"
  fi
}

IOS_BUNDLE_ID="nz.co.fixo.fixo"
IOS_APP_PATH="$MOBILE_DIR/build/ios/iphonesimulator/Runner.app"
IOS_UDIDS=(); IOS_NAMES=()

# Populate IOS_UDIDS/IOS_NAMES with the first two available iPhone sims.
collect_ios_devices() {
  local raw
  raw=$(xcrun simctl list devices available 2>/dev/null \
    | grep -i iphone \
    | sed -E 's/^[[:space:]]*(.+) \(([0-9A-F-]+)\).*/\2|\1/')
  IOS_UDIDS=(); IOS_NAMES=()
  while IFS='|' read -r udid name; do
    if [[ -n "$udid" ]]; then
      IOS_UDIDS+=("$udid")
      IOS_NAMES+=("$(echo "$name" | xargs)")
    fi
  done <<< "$raw"

  if [[ ${#IOS_UDIDS[@]} -lt 2 ]]; then
    error "Need at least 2 iPhone simulators, found ${#IOS_UDIDS[@]}."
    error "Create one in Xcode → Settings → Platforms → +, or via simctl."
    exit 1
  fi
}

# Attach flutter tooling to both sims (hot reload keys, logs). Blocks until Ctrl-C.
attach_ios_duo() {
  local dev1="$1" dev2="$2"
  info "Attaching Flutter tooling (Ctrl-C stops both)..."
  flutter attach -d "$dev1" 2>&1 | sed "s/^/[sim-1] /" &
  local pid1=$!
  flutter attach -d "$dev2" 2>&1 | sed "s/^/[sim-2] /" &
  local pid2=$!

  trap "info 'Detaching both Flutter instances...'; kill $pid1 $pid2 2>/dev/null; exit 0" INT TERM
  wait $pid1 $pid2
}

# Terminate, install and launch the prebuilt .app on both sims.
install_ios_duo() {
  local dev
  for dev in "$1" "$2"; do
    xcrun simctl terminate "$dev" "$IOS_BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$dev" "$IOS_APP_PATH"
    xcrun simctl launch "$dev" "$IOS_BUNDLE_ID"
  done
}

# Launch Flutter on two iOS simulators in parallel.
# Boots the first two available iPhone sims if needed, builds the .app once,
# installs/launches on both, then attaches for logs + hot reload.
cmd_flutter_ios_duo() {
  ensure_env_json
  collect_ios_devices

  local dev dev1 dev2 name1 name2
  dev1="${IOS_UDIDS[0]}"; name1="${IOS_NAMES[0]}"
  dev2="${IOS_UDIDS[1]}"; name2="${IOS_NAMES[1]}"

  info "Simulator 1: $name1 ($dev1)"
  info "Simulator 2: $name2 ($dev2)"

  # Boot both (already-booted sims print an error — safe to ignore) and
  # bring the Simulator app to the foreground.
  open -a Simulator
  for dev in "$dev1" "$dev2"; do
    xcrun simctl boot "$dev" 2>/dev/null || true
    xcrun simctl bootstatus "$dev" -b 2>/dev/null || true
  done

  # Build the simulator .app once. Two concurrent `flutter run` calls share
  # the same build/ dir and trigger competing xcodebuilds — the same class of
  # file-lock problem as parallel Gradle builds on Android. Fix is identical:
  # build once up-front, then run the same binary on both devices.
  info "Building iOS simulator app (once)..."
  cd "$MOBILE_DIR"
  # No --no-codesign: it produces a linker-signed (0x20002) binary that the
  # iOS simulator denies Keychain access to (flutter_secure_storage →
  # PlatformException -34018 on every token read). A normal sim build gets
  # a proper adhoc signature (0x2) and Keychain works — no team needed.
  flutter build ios --debug --simulator \
    --dart-define-from-file="$ENV_JSON"

  if [[ ! -d "$IOS_APP_PATH" ]]; then
    error "Build completed but $IOS_APP_PATH was not produced."
    exit 1
  fi

  info "Installing and launching on both simulators..."
  install_ios_duo "$dev1" "$dev2"

  # flutter attach gives each instance its own VM-service session (hot reload
  # commands, logs) without invoking xcodebuild again.
  attach_ios_duo "$dev1" "$dev2"
}

# Rebuild + reinstall + relaunch on the same two sims, then re-attach.
# Use for changes a hot restart can't pick up: .env.json / --dart-define,
# native iOS code, plugins, or pubspec assets. For ordinary Dart edits,
# press R (hot restart) in the running ios2 terminal instead — much faster.
#
# Run from a SECOND terminal while ./dev.sh ios2 stays running: terminating
# the app drops that terminal's attach sessions, then this re-attaches.
cmd_flutter_ios_rebuild() {
  ensure_env_json
  collect_ios_devices

  local dev1 dev2
  dev1="${IOS_UDIDS[0]}"
  dev2="${IOS_UDIDS[1]}"

  info "Rebuilding iOS simulator app..."
  cd "$MOBILE_DIR"
  # See cmd_flutter_ios_duo: --no-codesign breaks Keychain on the simulator.
  flutter build ios --debug --simulator \
    --dart-define-from-file="$ENV_JSON"

  info "Reinstalling and relaunching on both simulators..."
  install_ios_duo "$dev1" "$dev2"

  attach_ios_duo "$dev1" "$dev2"
}

# Run flutter on the 2nd Android emulator using the last build — no Docker
# check, no Gradle rebuild. Use this in a second terminal tab while the first
# is already running `./dev.sh android`.
cmd_flutter_attach() {
  if [[ ! -f "$ENV_JSON" ]]; then
    error ".env.json missing. Run ./dev.sh android first."
    exit 1
  fi

  # Collect all Android device IDs
  local raw
  raw=$(flutter devices 2>/dev/null | grep -i android | awk -F '•' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
  local DEVICES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && DEVICES+=("$line")
  done <<< "$raw"

  local target_dev
  if [[ ${#DEVICES[@]} -ge 2 ]]; then
    # Default to the 2nd emulator so it doesn't clash with the 1st terminal's instance
    target_dev="${DEVICES[1]}"
    info "Attaching to 2nd emulator: $target_dev"
  elif [[ ${#DEVICES[@]} -eq 1 ]]; then
    target_dev="${DEVICES[0]}"
    warn "Only one Android device found, attaching to: $target_dev"
  else
    error "No Android devices found. Start an emulator first."
    exit 1
  fi

  cd "$MOBILE_DIR"
  info "Running flutter on $target_dev (no rebuild)..."
  flutter run --no-build --dart-define-from-file="$ENV_JSON" -d "$target_dev"
}

# ── Entry point ───────────────────────────────────────────────────────────────

COMMAND="${1:-android}"
BUILD_FLAG="${2:-}"   # optional --build passed as second arg

case "$COMMAND" in
  stop)
    cmd_stop
    ;;
  docker)
    cmd_docker "$BUILD_FLAG"
    ;;
  android|ios|web)
    cmd_docker "$BUILD_FLAG"
    cmd_flutter "$COMMAND"
    ;;
  android2)
    cmd_docker "$BUILD_FLAG"
    cmd_flutter_duo
    ;;
  ios2)
    cmd_docker "$BUILD_FLAG"
    cmd_flutter_ios_duo
    ;;
  ios2-rebuild)
    cmd_flutter_ios_rebuild
    ;;
  android-attach)
    cmd_flutter_attach
    ;;
  *)
    echo "Usage: $0 [android|android2|android-attach|ios|ios2|ios2-rebuild|web|docker|stop] [--build]"
    exit 1
    ;;
esac
