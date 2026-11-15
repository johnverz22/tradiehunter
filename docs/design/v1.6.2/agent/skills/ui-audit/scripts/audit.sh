#!/usr/bin/env bash
# audit.sh — run the design audit and print a gate-by-gate verdict.
# Usage: bash agent/skills/ui-audit/scripts/audit.sh [design_root]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DESIGN="${1:-$ROOT/docs/design/v1.6.2}"
OUT="${AUDIT_OUT:-/tmp/audit-$(basename "$DESIGN").json}"

python3 "$DESIGN/tools/audit_full.py" "$DESIGN" "$OUT"

python3 - "$OUT" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
frames = d['frames']
sheets = {'component-sheet.html', 'style-tile.html'}
screens = [f for f in frames if f['file'] not in sheets]

def n(fr, key): return sum(len(fr[key]) for fr in fr)
clip = sum(len(f['clip']) for f in screens)
tap = sum(len(f['tap']) for f in screens)
small = sum(len(f['small']) for f in frames)
contrast = sum(len(f['contrast']) for f in screens
                if not f['name'].startswith('S01'))   # documented false positive
a11y = sum(len(f['a11y']) for f in frames)
orange = sum(1 for f in screens if f['orange'] > 2)
static = len(d['static'])

gates = [
    ('clip (screens, faderow excluded upstream)', clip, 0),
    ('tap < 48dp', tap, 0),
    ('text < 12px', small, 0),
    ('contrast failures (non-S01 screens)', contrast, 0),
    ('a11y (aria/alt)', a11y, 0),
    ('orange budget > 2', orange, 0),
    ('static (classes/vars/assets)', static, 0),
]
fails = 0
print('\n=== GATES ===')
for name, val, want in gates:
    ok = val <= want
    fails += 0 if ok else 1
    print(f"{'PASS' if ok else 'FAIL'}  {name}: {val} (want <= {want})")
print(f"\n{len(frames)} frames audited ({len(screens)} screen frames).")
sys.exit(1 if fails else 0)
EOF
