#!/usr/bin/env bash
# setup.sh — one-shot setup for the TradieHunter design-system toolchain.
# Installs Node (parse5) + Python (beautifulsoup4, playwright) dependencies,
# then verifies the whole pipeline end-to-end: audit -> transpile -> lint -> smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

say "1/5 Node dependencies (design2flutter: parse5)"
(cd tools/design2flutter && [ -d node_modules/parse5 ] && echo "  already installed" || npm install --no-audit --no-fund)

say "2/5 Python dependencies (bs4 + playwright)"
python3 -c "import bs4" 2>/dev/null && echo "  bs4 ok" || pip install beautifulsoup4
python3 -c "import playwright" 2>/dev/null && echo "  playwright ok" || pip install playwright
python3 -c "
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(); b.close()
" 2>/dev/null && echo "  chromium ok" || { echo "  installing chromium…"; python3 -m playwright install chromium; }

say "3/5 Design audit (design gates)"
bash agent/skills/ui-audit/scripts/audit.sh docs/design

say "4/5 Transpile mockups -> Flutter scaffolds"
(cd tools/design2flutter && rm -rf output && node src/index.js --design ../../docs/design --out output)

say "5/5 Structural lint + end-to-end smoke test"
(cd tools/design2flutter && node src/index.js --check output && node test/smoke.js)

say "Optional: Flutter side (needs the Flutter SDK)"
cat <<'EOF'
  make -C agent flutter     # dart format + flutter analyze + flutter test
EOF

printf '\n\033[1;32mSetup complete. Guide: docs/ai/AI-TOOLING.md\033[0m\n'
