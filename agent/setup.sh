#!/usr/bin/env bash
# setup.sh: verifies the TradieHunter design-system gate (nothing to install).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Design gate: tokens, screens, WCAG contrast"
node docs/design/mobile/tools/build.mjs --check

echo "== Optional Flutter side (needs the Flutter SDK): make -C agent flutter"
echo "Setup complete. Guide: docs/ai/AI-TOOLING.md"
