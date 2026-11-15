---
name: mockup-html-qa
description: Check HTML/CSS mockup frames (e.g. docs/design/v*/html/frames-*.html) for defects BEFORE they are translated to Flutter - unresolved icon sprite refs, appbar back-button geometry, pills/chips overflowing their frame or parent, labels misusing the interactive chip class, text under 12px. Use whenever someone says mockups have missing icons, a broken back button, overflowing pills, or before handing mockups to an implementer.
---
# Mockup HTML QA

Mockups that are wrong get faithfully built wrong. Run this first.

## Steps
1. Open the **source** `html/` files, not only `build/`. A placeholder like `%%SPRITE%%` that only the build replaces makes every icon blank when someone opens the source (this happened in TradieHunter v1.6: 33/34 homeowner frames).
2. `python3 scripts/probe_mockups.py <label> html/frames-*.html` (needs playwright + chromium). Frames are elements with `data-frame`. Output: `probe-<label>.json` plus a one-line summary per file. Run it on `html/` and `build/` and diff.
3. Read the JSON; each item names the frame and selector.
4. Look at the pixels of every flagged frame. The probe finds candidates; it can't judge intent.

## What the probe flags
- `missingIcon`: `<use href="#x">` whose target id is absent, or an empty `<svg>`.
- `backBtn`: size, left offset, whether its icon resolves. Expect one size/offset everywhere; flag outliers (inline `padding:4px 20px` was the cause in TradieHunter).
- `pillOverflow`: `.pill/.chip/.badge/.tag` wider than frame or parent, or wrapping. Chips inside `.faderow` are skipped on purpose (intentional scroller): check those by eye that a chip is visibly cut with a fade.
- `clip`: any non-absolute element past the frame edge.

## Rules of thumb
- Non-interactive label = `.badge` (26px). `.chip` = interactive, 40dp visual, 48dp hit. Never size a chip with inline `height:26px`.
- Rows of 3+ badges use flex-wrap, not `space-between`.
- Scrolling chip row = scroller + fade on last ~32px, last chip visibly cut.
- Back: 48dp target, 24px glyph, glyph ink on the 20dp gutter, scrim over maps/imagery.
- Min text 12px.

Report each finding as: frame, selector, measurement, fix. Say what you did not check.
