#!/usr/bin/env bash
# dev.sh — Start the full Fixo dev stack
#
# Usage:
#   ./dev.sh                  # start Docker services + Flutter (Android emulator)
#   ./dev.sh ios              # start Docker services + Flutter (iOS simulator)
#   ./dev.sh web              # start Docker services + Flutter (Chrome)
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

cmd_flutter() {
  local target="${1:-android}"

  # Ensure .env.json exists
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

  # Warn if any placeholder values are still present
  if grep -q "REPLACE_WITH" "$ENV_JSON"; then
    warn ".env.json still contains placeholder values."
    warn "Google Sign-In will not work until you fill them in."
  fi

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
  dev=$(flutter devices 2>/dev/null | grep -i android | head -1 | awk -F '•' '{print $2}' | xargs)
  if [[ -z "$dev" ]]; then
    warn "No Android device found. Start an emulator first."
    echo "android"
  else
    echo "$dev"
  fi
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
  *)
    echo "Usage: $0 [android|ios|web|docker|stop] [--build]"
    exit 1
    ;;
esac
