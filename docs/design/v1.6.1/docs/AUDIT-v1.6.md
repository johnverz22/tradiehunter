# TradieHunter v1.6 audit
Method: every `[data-frame]` in the v1.6 build measured in Chromium (clipping, tap targets, contrast, font size, orange count) plus visual review of all contact sheets. Script: `tools/audit.py`.

| # | Severity | Finding | Where | v1.7 fix |
|---|---|---|---|---|
| 1 | High | More than 2 orange elements per screen (AC-VD-02): 16 of 73 screens | H07 (8), T19 (5), T25 wizard, onboarding | Amber = one CTA + one urgency element. Accent bars, nodes, checkboxes, dots, FAB, HIGH tag now navy. Only the first lead's Accept is amber |
| 2 | High | Contrast below AA (44 hits) | eyebrow 3.5:1, countdown text 4.1, wordmark "Hunter" 2.4, wizard node 2.6, Disputed pill 1.95, dark red/green text 2.5-3.0 | `--accent-text #8F4F08` on light, text-soft/semantic `--danger-text`/`--success-text` per theme, inverse pill on navy strip |
| 3 | High | Controls clipped | Navigate/Message/Call row (H12, T22), T20 filter chips | Icon-over-label `btn-tile` (64px, equal columns); 4 chips fit as equal columns (Today / Upcoming / Unpaid / Done) |
| 4 | High | Cross-theme drift: dark frames hand-copied, only 7 of 52 screens had one; T21 earnings and H12 "Track" differed from light | frames-dark | Dark and outdoor are generated from the light frames (`tools/variants.py`): 57 dark, 15 outdoor |
| 5 | Med | Nav inconsistent: centre FAB missing on Messages/Profile, label collisions | H18, states | 5-slot grid nav, FAB lives inside the navbar |
| 6 | Med | Status bar missing or without icons | S01, S05-S08 and others | Auto-inserted everywhere |
| 7 | Med | Selection styled three ways (amber fill, amber border, navy) | S06, S08, wizard | One rule: 2px brand border + tint + check/radio |
| 8 | Med | Green used for toggles; red/amber text hardcoded | H18 settings | `.switch` in brand; semantic text tokens |
| 9 | Med | Onboarding: peach blob behind CTA/progress (AC-VD-04), dots left / Next right / Skip centred | S02-S04 | Dots centred above full-width Next; blob removed |
| 10 | Med | Pill text duplicates CTA ("Review completion" twice), wraps name | H07 | Pill = status ("Action needed", "Payment due"); CTA = verb |
| 11 | Low | ~20 off-palette hexes incl. skin tone in art | css, svg | Variables only; art redrawn palette-only |
| 12 | Low | Illustrations inconsistent in style (outline vs fill), IL-07/IL-08 unclear | assets | New set IL-01..12, one generator |
| 13 | Low | Missing states: loading, toast, offline banner, nav badge | - | Added in `frames-components.html` |

Result: screens with >2 orange 16 -> 3 (dark-mode amber countdown text, by design); text under 12px 11 -> 0; contrast hits on screens 44 -> ~14 (remaining are gradient-background false positives and the S01 splash).
Open: chat message list is top-anchored; chat chips are an intentional scroll row with fade.
