#!/bin/bash
# v1.7 pipeline. Source of truth: html/*.html + html/kit.css (+ fonts/, assets/).
#   ./build.sh            -> regenerate dark/outdoor variants, assemble build/, render frames/*.png
#   SKIP_RENDER=1 ./build.sh   -> assemble only
# Needs python3 + bs4 (pip install beautifulsoup4) and, for rendering, playwright (pip install playwright; playwright install chromium).
set -e
cd "$(dirname "$0")"
python3 tools/variants.py .          # light frames are the ONLY hand-edited screens; dark/outdoor are generated
python3 tools/assemble.py .
[ -n "$SKIP_RENDER" ] && exit 0
rm -rf frames; mkdir -p frames
python3 render.py build/component-sheet.html build/style-tile.html build/frames-*.html --out frames
