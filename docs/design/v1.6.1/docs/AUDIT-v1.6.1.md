# TradieHunter design v1.6 → v1.6.1 audit

Method: every `[data-frame]` in `html/*.html` rendered in Chromium and probed (`skills/mockup-html-qa/scripts/probe_mockups.py`), plus the repo's own `tools/audit.py`. Raw output: `docs/evidence/probe-before-source-html.json`, `probe-after-source-html.json`.
Scope limit: frames were viewed as contact sheets; dark/outdoor variants are generated from light and were probed, not eyeballed one by one.

| ID | Sev | Finding | Evidence | Fix in v1.6.1 |
|---|---|---|---|---|
| F-01 | Critical | Sources in `html/` carry a `%%SPRITE%%` placeholder that only `build/` replaces → icons blank when a mockup is opened from `html/` | Frames with unresolved icons (old source): homeowner 33/34, tradie 11/13, dark 50/57, outdoor 10/15, ipad 6/6, states 6/7, entry 3/8. After: 0 | `tools/inline_sprite.py` keeps the sprite inside every source between `<!--SPRITE-->` markers; `assemble.py` is now a copy; `build.sh` runs it |
| F-02 | Major | Back button geometry is not one pattern | 57 frames back at x=8; H11, T21 at x=20 via inline `padding:4px 20px`; chevron ink spans x 8–14.5 of its 24 box so ink lands ≈x=28, 8px off the 20px gutter; T21 back sits on bare map linework; icon buttons had no accessible name | `.appbar:has(> .back:first-child){padding-left:0}`, 24px glyph, `.heroband`/`.maphead` variants (white glyph / frosted scrim, flat+outline in outdoor), `aria-label` on 61 icon buttons |
| F-03 | Major | `.chip` (40dp interactive filter) used as a 26px label via inline `height:26px` | 16 uses in frames, 9 in component-sheet/prototype | New `.badge` (26px, 12/600, nowrap) |
| F-04 | Major | Trust row on H17 overflows the frame | `span.chip "Insured"` 88×26 beyond frame, H17 rated/expanded, light+dark; cause: 4 items in `.spread` | Rating on its own row, badges in wrapping `.badges` (5 tiles) |
| F-05 | Minor | Chip rows hard-cut at the frame edge | H13/T23 quick replies, H19 filters; 88% mask hid ~12% of the row | `.faderow` is a real scroller with snap, 32px fade. This is intentional scrolling; Flutter must match (see skill) |
| F-06 | Minor | 11px text contradicts the 12px floor (AC-VD-10) and the handoff claim of 0 | 10 inline `11px` in frames-homeowner (e.g. "Step 2 of 4", pill 22px/11px) | → 12px; 22px pill → 24px |

## Open (not fixed)
- `IPAD-messages-light/dark`: master pane text and detail pane clip past the 834px frame.
- Contrast hits (181 by `audit.py`, mostly component-sheet annotations and gradient false positives) and 7 frames with >2 orange elements: unchanged, not re-investigated.
- Hit area: chips draw 40dp and pad to 48 via `::after`; `audit.py` still counts them <48 (false positive by design).
- Committed `html/` was out of sync with the pipeline (hand-copied dark frames inside light files). `build.sh` regenerates them; commit the regenerated sources.
- Fixes were verified visually on 5 frames only (H11, T21, H17, H19, H13).

## What works (keep)
Token set and radii are consistent across frames; built `build/` output resolved every icon before this change; 4-slot/5-slot nav is consistent; contrast pairs listed in AUDIT-CONTEXT hold by construction.
