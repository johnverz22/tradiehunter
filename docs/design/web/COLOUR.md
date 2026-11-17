# Colour: TradieHunter Web Design System v1

> Master palette lives in `../mobile/tokens/tokens.json`. Web adds a few roles in `tokens/tokens.json`. Generated CSS: `tokens/tokens.css`. Tailwind v4 utilities: `tokens/theme.css`. **Never hardcode hex.**

## Inherited tokens (CSS name, mobile name)

| CSS / Tailwind | Mobile | Light | Dark | Use on web |
|---|---|---|---|---|
| `paper` | `paper` | #F4F6FB | #0A101E | Page background |
| `surface` | `surface` | #FFFFFF | #121A2D | Cards, tables, fields, dialogs |
| `surface-alt` | `surfaceAlt` | #EBEFF8 | #1A2540 | Table header, segmented track, disabled fill, skeleton |
| `ink` | `text` | #0F172A | #E8EDF8 | Primary text |
| `ink-soft` | `textSoft` | #4B5A71 | #9DAAC4 | Secondary text, table header text, help |
| `ink-brand` | `textBrand` | #1E3A8A | #8FA8F2 | Links, selected tab, ghost buttons |
| `brand` / `on-brand` | `brand` / `onBrand` | #1E3A8A / #FFF | #8FA8F2 / #0A101E | Primary buttons, current page, checked controls |
| `brand-tint` | `tintBrand` | #E3E9FA | #1C2B52 | Info badge and banner, icon tiles, ghost hover |
| `accent` / `on-accent` | same | #B45309 / #FFF | #E8A04C / #1A1005 | The one gold commit action |
| `accent-ink` | `accentText` | #8A3F06 | #F2B567 | Gold as text (warn badge, wordmark) |
| `accent-tint` | `accentTint` | #FDF0E0 | #2D2110 | Warn badge and banner |
| `success` / `success-tint` | same | #157A3A / #DDF5E5 | #4ADE80 / #10301E | Verified, done, switch on |
| `danger` / `danger-tint` | same | #B91C1C / #FDE8E8 | #F87171 / #3A1717 | Errors, dispute, destructive |
| `line`, `track` | same | #DCE2EF | #26345A | Decorative dividers, card borders, inactive progress |
| `avatar` / `on-avatar` | `avTradie` / `onAvTradie` | #3A56C4 / #FFF | #2A3F78 / #DCE5FF | Avatar fill and initials |
| `hero-start` → `hero-end`, `on-hero`, `hero-gold`, `hero-glow` | same | | | Sign-in aside, hero card |
| `glass` | same | white 86% | surface 82% | Sticky top bar (blurred) |

## Web-only tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `line-strong` | #7C89A3 | #62729C | Borders of interactive controls (inputs, selects, secondary buttons, checkboxes). 3:1 against paper, surface and surface-alt |
| `focus` | = `brand` | = `brand` | Focus ring |
| `on-danger` | #FFFFFF | #1A0505 | Text on filled danger buttons |
| `sidebar` | = `hero-start` | = `hero-start` | Sidebar background |
| `on-sidebar`, `on-sidebar-soft` | white, white 80% | same | Sidebar text, inactive items |
| `sidebar-hover`, `sidebar-active` | white 12%, 18% | white 10%, 16% | Sidebar item states (composited before the contrast check) |
| `scrim` | navy 55% | near-black 70% | Behind dialogs and the drawer |

## Pairing rules

- Gold: `on-accent` on `accent`, never a literal. Gold as text is `accent-ink`.
- Filled danger uses `on-danger` (it flips to near-black in dark).
- Use `line` for decoration (card edges, row dividers) and `line-strong` for anything the user must see to operate (control borders).
- Status colour never stands alone: badge text, icons in steppers and banners.
- Inactive and disabled states use `surface-alt` + `ink-soft`; disabled controls are exempt from contrast but stay readable.

## Contrast gate

`tools/build.mjs --check` fails if any of 36 text pairs drops under 4.5:1 or any of 9 non-text pairs under 3:1, in either theme. Semi-transparent colours are flattened over their real background first. Results: `tokens/contrast-report.txt` (90 pairs, all passing).
