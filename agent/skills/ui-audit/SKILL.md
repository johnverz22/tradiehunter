---
name: ui-audit
description: Run the automated TradieHunter mockup/design audit (overflow, truncation, tap targets, sub-12px text, WCAG contrast, orange budget, aria/alt coverage, undefined classes, inline hardcoded colors) and interpret the results against the fix-spec gates. Use before committing mockup changes, after regenerating frames, or when a run screenshot diverges from the mockup.
---
# UI audit

## Procedure
1. Run the probe (needs python3 + playwright + chromium):
   `python3 docs/design/mobile/tools/audit_full.py docs/design /tmp/audit.json`
2. Read the JSON. Every finding names the frame and selector; the probe finds
   candidates, it cannot judge intent.
3. Apply the gates (docs/DESIGN.md §8). All must hold:
   - screen-frame contrast ≥ 4.5:1 (3:1 for ≥24px or ≥18.66px bold)
   - no text under 12px anywhere
   - no clipping past frame edges (`.faderow` cuts + decorative blobs excluded)
   - no tap target under 48dp (chips 40dp visual + 48dp hit are compliant)
   - orange elements ≤ 2 per screen (a countdown widget = 1; style-tile palette
     documentation is exempt)
   - every icon-only control has `aria-label`; every `<img>` has `alt`
   - zero undefined classes/custom props; zero unresolved `%%…%%` placeholders
   - IPAD master-detail: `.md` overflows the frame by 0px
4. **Known false positives** (do not "fix" these):
   - S01 splash status bar/wordmark contrast — the hero band is a sibling with
     `z-index` paint order the probe cannot composite.
   - Wordmark `span.o` flagged as a tap target — not interactive.
   - Hero-glass inline rgba constants (theme-invariant by spec).
5. For each REAL finding, classify it against the design-system categories
   (layout / dark contrast / accessibility / tokens) and fix in
   the mockup source (`docs/design/html/`), never in `build/`.
6. Re-run until clean; report: gate, count before → after, files touched.

## Companion checks
- `node tools/design2flutter/src/index.js --check tools/design2flutter/output`
  after regenerating Dart scaffolds.
- `node tools/design2flutter/test/smoke.js` for the end-to-end pipeline proof.
