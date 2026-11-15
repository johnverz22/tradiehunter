#!/usr/bin/env bash
# new-screen.sh <frame-prefix> [feature-name] — scaffold a Flutter screen from a mockup.
# Usage: bash agent/skills/new-screen-from-mockup/scripts/new-screen.sh H13 chat
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
FRAME="${1:?usage: new-screen.sh <frame-prefix> [feature-name]}"
FEATURE="${2:-screen}"

echo ">> locating frames matching '$FRAME'"
node "$ROOT/tools/design2flutter/src/index.js" --design "$ROOT/docs/design/v1.6.2" --list | grep -i "^$FRAME" || true

OUT="$(mktemp -d)"
echo ">> generating scaffold"
node "$ROOT/tools/design2flutter/src/index.js" --design "$ROOT/docs/design/v1.6.2" --out "$OUT" --frames "$FRAME"

DEST="$ROOT/mobile/lib/views/$FEATURE"
mkdir -p "$DEST"
for f in "$OUT"/*.dart; do
  base="$(basename "$f")"
  dest="$DEST/${base%.dart}_screen.dart"
  cp "$f" "$dest"
  echo "   created $dest"
done
echo ">> next: rename classes, wire view models, swap TH* contracts for Fixo* widgets,"
echo "   stress-test long text / 1.3x scale / 360dp / all three themes."
