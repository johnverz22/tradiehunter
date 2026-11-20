# Colour — TradieHunter Design System v2

> Extracted from `DESIGN_GUIDE.md §2`. Single source of truth for colour is `tokens/tokens.json`.
> Use through `context.th.<name>` (Flutter) or `var(--<name>)` (CSS). **Never hardcode hex.**

## Colour token table

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | #F4F6FB | #0A101E | Screen background |
| `surface` | #FFFFFF | #121A2D | Cards, fields, sheets |
| `surfaceAlt` | #EBEFF8 | #1A2540 | Segmented track, map and photo fill |
| `text` | #0F172A | #E8EDF8 | Primary text |
| `textSoft` | #4B5A71 | #9DAAC4 | Secondary text, labels |
| `textBrand` | #1E3A8A | #8FA8F2 | Links, brand-coloured text, selected nav |
| `brand` / `onBrand` | #1E3A8A / #FFF | #8FA8F2 / #0A101E | Primary buttons, selected pills, own chat bubbles |
| `tintBrand` | #E3E9FA | #1C2B52 | Icon tiles, neutral badges, upload zones |
| `accent` / `onAccent` | #B45309 / #FFF | #E8A04C / #1A1005 | The one gold CTA, FAB, countdown arc |
| `accentText` | #8A3F06 | #F2B567 | Gold used as text on light or tint background |
| `accentTint` | #FDF0E0 | #2D2110 | Warning and pending badges |
| `success` / `successTint` | #157A3A / #DDF5E5 | #4ADE80 / #10301E | Verified, done, paid |
| `danger` / `dangerTint` | #B91C1C / #FDE8E8 | #F87171 / #3A1717 | Dispute, errors |
| `avTradie` / `onAvTradie` | #3A56C4 / #FFF | #2A3F78 / #DCE5FF | Avatar fill and initials |
| `heroStart` → `heroEnd` | #1E3A8A → #2849B5 | #17255C → #2A44A0 | Hero card gradient |
| `onHero`, `heroGold` | #FFF, #FFD495 | #FFF, #FFD495 | Text on hero cards |
| `line`, `track` | #DCE2EF | #26345A | Borders, dividers, inactive progress |
| `glass` | white 86% | surface 82% | Dock (composited over `paper`, opaque) and sticky bar (blurred) |

## Contrast gate

Contrast is **enforced by the build** — 19 text/background pairs per theme must reach 4.5:1 (WCAG AA) or `node tools/build.mjs --check` fails. See `tokens/contrast-report.txt` for the full results (38 pairs, all passing). Two earlier values were corrected during development (`success` light, `heroGold`).

## Pairing rules

- **Gold on light:** white text on `accent` works in light mode only. In dark mode gold takes `onAccent` (near-black). Always pair `accent` with `onAccent`, never with a literal white or black.
- **Gold as text:** use `accentText`, not `accent`, when gold is used as the colour of text on a surface.
- **Status is never colour-only.** Badges carry text; timelines carry icons.
- **One gold action per screen.** `accent` is the single primary CTA. `brand` (navy) is for secondary-importance filled actions.
