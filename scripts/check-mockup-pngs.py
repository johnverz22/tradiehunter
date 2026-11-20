#!/usr/bin/env python3
"""Check that the mockup PNGs are up to date with the mockup HTML (P4-09).

The PNGs in docs/design/mobile/mockups/png/ are rendered from
docs/design/mobile/mockups/index.html by
`node docs/design/mobile/tools/mockup-shots.mjs`, which also writes
png/source.json (sha256 of the index.html it rendered). This script fails when

  * png/source.json is missing (the PNGs have no recorded source);
  * its sha256 differs from the current index.html (the mockup changed after
    the PNGs were exported: re-run `node docs/design/mobile/tools/build.mjs`
    and then mockup-shots.mjs);
  * the export ran without the web fonts (fonts_loaded is false);
  * a screen id in index.html has no <id>-light.png / <id>-dark.png, or a PNG
    belongs to no screen.

Usage: scripts/check-mockup-pngs.py [--warn]
  --warn  print GitHub ::warning:: annotations and exit 0 (use until the first
          re-export has been committed, then drop the flag).
Stdlib only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOCKUPS = ROOT / "docs/design/mobile/mockups"
HTML = MOCKUPS / "index.html"
PNG_DIR = MOCKUPS / "png"
THEMES = ("light", "dark")
FIX = (
    "node docs/design/mobile/tools/build.mjs && "
    "node docs/design/mobile/tools/mockup-shots.mjs  (needs network for the fonts)"
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--warn", action="store_true", help="warn instead of failing")
    args = ap.parse_args()

    html = HTML.read_text(encoding="utf-8").replace("\r\n", "\n")
    ids = list(dict.fromkeys(re.findall(r'data-screen="([^"]+)"', html)))
    errors: list[str] = []

    manifest_path = PNG_DIR / "source.json"
    if not manifest_path.exists():
        errors.append("mockups/png/source.json is missing: the PNGs have no recorded source")
    else:
        m = json.loads(manifest_path.read_text())
        digest = hashlib.sha256(html.encode("utf-8")).hexdigest()
        if m.get("sha256") != digest:
            errors.append("mockups/index.html changed after the PNGs were exported (sha256 differs)")
        if not m.get("fonts_loaded", False):
            errors.append("the PNGs were exported without Lexend / Source Sans 3 (fallback fonts)")

    expected = {f"{i}-{t}.png" for i in ids for t in THEMES}
    present = {p.name for p in PNG_DIR.glob("*.png")}
    for name in sorted(expected - present):
        errors.append(f"missing PNG: {name}")
    for name in sorted(present - expected):
        errors.append(f"PNG for no screen in index.html: {name}")

    print(f"{len(ids)} screens, {len(present)} PNGs")
    if not errors:
        print("OK: mockup PNGs match mockups/index.html")
        return 0
    for e in errors:
        print(f"::warning::{e}" if args.warn else f"  - {e}", file=sys.stdout if args.warn else sys.stderr)
    print(f"{'WARN' if args.warn else 'FAIL'}: {len(errors)} problem(s). Fix: {FIX}",
          file=sys.stdout if args.warn else sys.stderr)
    return 0 if args.warn else 1


if __name__ == "__main__":
    sys.exit(main())
