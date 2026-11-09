# v1.7 handoff
**Source of truth:** `html/kit.css` (tokens + components). Frames live in `html/frames-homeowner.html` and `html/frames-tradie.html` — edit directly, all frames are hand-authored (no build script required). Developer tokens: `tokens/tokens.json`, `tokens.css`, `design_tokens.dart`.

## Frame inventory

### frames-homeowner.html (23 frames)
| Frame | Notes |
|---|---|
| H07-light | Dashboard · hero band + attention cards + booked row |
| H07-dark | Dashboard dark variant |
| H07-empty-light | First-time empty state · trust stat row + Post a job CTA |
| H07-empty-dark | Empty state dark variant |
| H09-light | Post a job form |
| H10-light | Matching / finding tradie |
| H11-light | Match result |
| H12-inprogress-light | Job detail — in progress |
| H12-inprogress-dark | Job detail dark variant |
| H12-dispute-light | Job detail — dispute open |
| H13-light | Chat |
| H13-dark | Chat dark variant |
| H14-light | Payment instructions |
| H15-review-light | Payment status — under review |
| H15-success-light | Payment status — confirmed |
| H15-rejected-light | Payment status — receipt rejected |
| H15-expired-light | Payment status — window expired |
| H16-light | Raise a dispute |
| H17-rated-light | Public tradie profile — rated |
| H17-new-light | Public tradie profile — new |
| H18-messages-light | Messages list |
| H18-profile-light | Self profile |
| H18-settings-light | Settings |

### frames-tradie.html (13 frames)
| Frame | Notes |
|---|---|
| T19-light | Tradie dashboard · earnings hero + leads + today |
| T19-dark | Tradie dashboard dark variant |
| T20-light | Jobs list |
| T21-light | Lead detail |
| T22-booked-light | Job detail — booked |
| T22-inprogress-light | Job detail — in progress |
| T23-light | Chat |
| T24-light | Profile |
| T25-step1..4-light | Onboarding wizard steps 1–4 |
| T26-light | Homeowner public profile (tradie view) |

## Design decisions applied (v1.7 session)

### Icons — no sprite dependencies in frames
All `<use href="#i-*">` removed from every visible UI element. Inline SVG paths used throughout. Permitted sprite refs remain **only** inside `.navbar .tab .ind svg` (small 22px tab icons) — but even those were converted to inline SVG in this session. **All frames are now fully self-contained HTML — no external sprite sheet required.**

Specific replacements:
- Pill icons (excl/play/alert/clock/check) → 14×14 inline SVG
- Avatar verified badges (`.vbdg`) → `60%/60%` white check inline SVG
- Hero area large icons → inline paths with explicit width/height
- `btn-tonal` buttons → inline SVG icons: Navigate (compass), Message (bubble), Call (phone), Check in (pin), Check out (check), Message Sarah (bubble)
- FAB `+` → inline cross SVG
- Navbar tabs (Home, Jobs, Messages, Profile) → inline SVG

### CTA placement — sticky bar standard
All primary/secondary/ghost CTAs are in `<div class="sticky">` at the bottom of the frame. Content area uses `flex:1` to push sticky to the bottom. Screens fixed:
- H15-review: added "View job" sticky
- H15-rejected: moved "Upload again" to sticky, added `flex:1` to content
- H15-expired: moved "Start again" + "Contact support" to sticky `stack8`, added `flex:1` to content
- H15-success: added `flex:1` to content

### Iconed buttons
All `btn-tonal` action buttons carry inline SVG leading icons. `btn-tile` rows (Message / Call / Navigate) all iconed. Exception: in-card secondary actions (Upload receipt, Open chat on dashboard card) intentionally icon-free.

### Send button
Composer send button uses right-facing paper plane: `<path d="M22 12L2 4l4 8-4 8 20-8z"/>` — flat horizontal, no tilt.

### Homeowner dashboard (H07) redesign
- **Hero band** replaces plain `h1` header: navy gradient, `bpdots` texture, rings watermark, `GOOD MORNING` small-caps label, 28px Display name, frosted location pill, bell with amber unread dot.
- **Attention cards**: job title as headline (17px Display), tradie name secondary, price/time separated by hairline rule, progress shown as 4×6px dot indicators + "Step X of 4" label.
- **Booked section**: compact list row inside single card (avatar + job + dots + price), "Open chat" tonal button below hairline.
- **Empty states** (light + dark): hero band, illustration with `drop-shadow`, "Find a tradie you can trust" headline, 3-stat row (`<5 min · 100% · Fixed`), full-width "Post a job" CTA with `+` icon. Dark variant uses `il-01-dark.svg`.

### attcard gradient
`.attcard { background: linear-gradient(180deg, rgba(60,117,170,.18) 0%, rgba(60,117,170,.06) 40%, transparent 100%); border-top: none; border-left: none; }`
No left-border accent — tinted top wash only.

### Dark mode pills
`.dark .pill-waiting { background: rgba(137,175,210,.28); color: #ffffff; }` — pure white text for contrast.

## Rules to implement
- Spacing 4-pt scale; gutter 20. Radii card 20, control 14, tile 16, sheet 28.
- Tap targets 48dp minimum. Chips draw 40dp but pad hit area to 48.
- Buttons 56 (secondary 52, tonal/ghost 48). One amber primary per screen.
- Selection: 2dp brand border + tint + check. Amber never means selected.
- Green = verified/done. Red = problem/dispute. Orange = CTA and one urgency element.
- Nav: 68dp, equal slots, 56dp FAB inside centre slot (homeowner only), 4 tabs for tradie.
- Dark: swap tokens only. Outdoor: light + flat, no blur, outlines for elevation.
- Respect reduced motion for skeleton shimmer.

## Needs product sign-off
FAB navy not amber; only first lead Accept amber, later ones navy; awaiting-payment progress navy; HIGH tag solid navy; pill/CTA copy split.

## Assets
`assets/il-01..12-{light,dark}.svg` (240×240), `assets/brand/` app icons (iOS 1024, Android adaptive fg/bg/mono, notification 24), splash, favicon, map pins, wordmarks (outlined paths), PNG exports in `assets/brand/png`. Rings/dots/route-line/tool-* decorative SVGs in `assets/`.
