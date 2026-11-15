#!/usr/bin/env bash
# refactor-check.sh — verify token discipline after a widget refactor.
# Usage: bash agent/skills/widget-refactor/scripts/refactor-check.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT/mobile"

echo "== raw color literals in views =="
rg -n "Color\(0x" lib/views lib/widgets || echo "  none"
echo "== inline fontSize (should be THType tokens) =="
rg -n "fontSize:\s*\d+" lib/views lib/widgets || echo "  none"
echo "== theme conditionals inside views (dark-mode hack detector) =="
rg -n "isDark|brightness ==|ThemeMode\." lib/views || echo "  none"
echo "== generated files hand-edited? (git diff check) =="
git diff --name-only | grep -E "output/.*\.dart$" && echo "  WARNING: generated output modified — fix the generator instead" || echo "  none"
echo
echo "Done. Any 'none'-less section above needs fixing before commit."
