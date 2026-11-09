# v1.6 — High-Fidelity Visual Design

**Date:** 2026-10-29
**Status:** Draft — awaiting review
**Parent spec:** [specification.md](specification.md) · **Tasks:** [tasks.md](tasks.md) (V16-21–V16-26)

> [!IMPORTANT]
> Layout, UX structure, component sizing, state logic, and copy decisions are governed by [specification.md](specification.md). This document governs only: colour expression, backgrounds, abstract graphics, illustration, depth, shadow, motion, and deliverable format. The two documents are jointly authoritative; conflicts resolve in favour of specification.md on functional matters and this document on visual treatment.

---

## 1. Art direction

**One line:** *Trustworthy trade craft, made warm and modern.* Blueprint precision plus friendly local service — clean cream surfaces, confident navy structure, one energetic orange accent per screen.

**Tone split by screen type:**

| Screen type | Tone | Visuals |
|---|---|---|
| **Hero / celebration** (splash, onboarding, match result, earnings, empty states, success) | Warm, energetic, inviting | Gradient hero bands, blobs, rings, illustrations, full art direction |
| **Working / outdoor** (lists, forms, job detail, payment, chat) | Calm, flat, legible | Cream surface, single accent, no blobs or glass |

Every hero screen gets a companion **outdoor / high-contrast variant**: blobs, gradients, and glass removed; flat cream background; same layout and copy. This is the default in high ambient-light conditions and when Reduce Transparency is enabled.

---

## 2. Colour system

> [!NOTE]
> Hues are **locked** to the existing brand palette. No new accent hues, neons, purple, pink, or glossy gradients. All colour expression comes from tints, tonal steps, gradients, and proportional use of the six source colours below.

### 2.1 Colour roles

| Role | Source colour | Token | Primary uses |
|---|---|---|---|
| Structure | Deep navy | `DesignTokens.navy` | Headings, hero bands, nav active, "In progress" fills, dark-mode surface base |
| Action | Orange / amber | `DesignTokens.amber` (`#E38B29`) | Primary CTAs, urgent timers, the one accent per screen, "Needs action" pills |
| Information | Mid-blue | `DesignTokens.blue` | Avatars, info banners, map/location accents, tonal button fill, progress bar completed segment |
| Canvas | Warm cream | `DesignTokens.cream` | App background |
| Surface | White | `DesignTokens.surface` | Cards, sheets |
| Success | Existing green | `DesignTokens.green` | Verified, Paid, Done pills only |
| Error / Problem | Existing red | `DesignTokens.red` | Disputed, Receipt rejected pills only |

### 2.2 Allowed derivations

No new hue families. All derivations are opacity and gradient operations on the source colours above.

**Tints** (source colour composited over cream or white surface):

| Strength | Use |
|---|---|
| 6% | Subtle hover/pressed states; grid texture; noise |
| 12% | Status pill fills (waiting, cancelled, problem — dark-mode borders) |
| 20% | Tonal button fill; blob shapes on hero screens |
| 32% | Attention-card accent band; selected-state overlay |

**Tonal steps** (allowed only for navy and mid-blue):

- One lighter step: lighten by ~15% for gradient highlight ends and hero text backgrounds
- One darker step: darken by ~15% for gradient shadow ends and nav rail

**Gradients** (only between existing colours, defined directions):

| Name | From → To | Angle | Use |
|---|---|---|---|
| `heroGradient` | Navy → mid-blue | 135° | Hero bands, splash, earnings hero, match result header |
| `warmBg` | Cream → peach tint (cream + 6% orange) | Top → bottom | Warm screen backgrounds (onboarding, auth) |
| `coolBg` | Mid-blue tint (12%) → cream | Top → bottom | Cooler hero backgrounds (matching screen) |
| `ctaSheen` | Orange → lighter orange (6% difference) | Top → bottom | Primary button surface only |

**Proportional rule:** ~60% cream/white · ~30% navy and blue · ~10% orange. Orange is reserved for actions and urgency — never decorative. If any screen has orange in more than one place, review which one is not an action.

---

## 3. Backgrounds and abstract graphics

All abstract assets are vector, built from palette tints, and stored in the abstract asset kit (deliverable §9.3).

### 3.1 Asset library

| Asset | Description | Opacity | Screens |
|---|---|---|---|
| **Soft blobs** | Two large blurred organic shapes: mid-blue tint top-right, peach tint bottom-left | 10–14% | Splash, onboarding, role select, match result (hero), earnings hero, empty states |
| **Radar rings** | 3–4 concentric circles in navy or white | 6–10% | Splash, match hero band, earnings hero, matching screen ("Contacting tradie") |
| **Route lines** | Dotted curved path connecting a homeowner pin to a tradie pin | 12% | Match result hero, onboarding slide 2, empty states |
| **Blueprint grid** | 24px dot or line grid over navy surfaces | 4–5% | Hero bands, splash, earnings hero; fades toward content with a gradient mask |
| **Tool-geometry shapes** | Rounded hexagon (nut), wrench-jaw arc, spirit-level pill, pin silhouette, 120–220px | 6–8% | Cropped at screen edges on hero screens; not behind body text |
| **Contour lines** | Thin topographic strokes over map-related headers | 5% | Request detail map header, active-job address card |
| **Film grain / noise** | 2–3% grain texture | 2–3% | Over gradients only, to prevent banding |

### 3.2 Placement rules

- Abstracts live in the **top 30%** of the screen or behind hero cards only.
- **Never** place abstracts behind body text, form fields, CTAs, or list content.
- Text over any abstract must meet ≥4.5:1 contrast (≥3:1 for 18px+/700 text); measure after compositing.
- Outdoor variant: remove all blobs, grids, and glass; keep the gradient hero band if the text over it is still contrast-compliant; otherwise replace the band with a flat navy header.

---

## 4. Depth, surfaces, and materials

### 4.1 Cards

- White surface, 20px radius, 1px neutral border.
- Two-layer shadow: `0 1px 2px rgba(navy, 0.06)` + `0 8px 24px rgba(navy, 0.08)`.
- Dark mode: elevated surface colour from existing dark palette; 1px border at 12% white; no heavy shadow.

### 4.2 Hero bands

- `heroGradient` (navy → mid-blue, 135°), 28–32px bottom radius.
- Radar rings and blueprint grid inside the band.
- Text: white, 18px+/600. All text over the gradient must pass ≥4.5:1 on the darkest and lightest points of the gradient.

### 4.3 Elevated sheets (bottom sheets)

- 28px top radius, drag handle (40×4px, neutral tint, centred).
- Shadow: `0 -12px 32px rgba(navy, 0.12)`.

### 4.4 Glass (used sparingly)

Allowed **only** on bottom nav bar and floating headers:
- Light mode: white at 80% opacity, 20px blur backdrop.
- Dark mode: existing dark surface colour at 78%, 20px blur.
- **Never** under body text, form fields, or CTAs.

### 4.5 Primary button (orange CTA)

- Background: `ctaSheen` gradient (orange → lighter orange, 6% difference, top to bottom).
- 1px inner highlight at the top edge: white at 20%.
- Shadow: `0 6px 16px rgba(orange, 0.25)`.
- Pressed state: scale 0.98, shadow reduces to `0 2px 8px rgba(orange, 0.15)`.
- 120ms ease-out for press/release.

### 4.6 Avatars

- Circular, 3px white ring over hero bands.
- Verified tradies: small green check badge (16px, filled circle) at the bottom-right of the avatar ring.

---

## 5. Typography and iconography

### 5.1 Type

Two families (carried from v1.5 D2, expressed here for visual design):

| Role | Family | Size / Weight | Notes |
|---|---|---|---|
| Hero numbers (earnings, price hero, payment amount) | Space Grotesk | 32–40 / 700 | Tabular figures, tracking −1%, white on navy or navy on cream |
| Display headings (H1) | Space Grotesk | 28 / 700 | |
| Section headings (H2) | Space Grotesk | 20 / 600 | |
| Card titles | IBM Plex Sans | 18 / 600 | Two-line max |
| Price (in cards) | IBM Plex Sans | 24 / 700 | Tabular figures |
| Body | IBM Plex Sans | 16 / 400 | |
| Secondary / metadata | IBM Plex Sans | 14 / 400 | |
| Caption / label | IBM Plex Sans | 12 / 500 | Minimum; never below 12 |

Mono (IBM Plex Mono) only for reference/job codes. Never for captions, helpers, or UI labels.

### 5.2 Icons

- One **rounded duotone** icon set throughout, 24px visual size.
- Default: 2px navy stroke.
- Accent element on each icon: single orange or mid-blue fill on the key element (e.g. the arrow on Navigate is orange; the check on Verified is green).
- Status pills carry an icon per the pill system in §3.2 of the main spec.
- Active tab icon: filled navy icon inside a 12% mid-blue tint rounded square (24×24px indicator).
- No mixing of filled, outlined, and sharp icons — one set only.

---

## 6. Illustration

### 6.1 Style

Flat vector, consistent with existing onboarding illustrations:
- Tradies wear navy/blue clothing with orange accents (hi-vis stripe, tool belt, cap).
- Soft peach and blue backdrop shapes (match the blob language).
- Friendly, diverse characters; no stereotypes.
- No photos, stock imagery, or photographic elements — except user-uploaded job and profile photos.

### 6.2 Required spot illustrations (160–200px)

| ID | Screen | Content |
|---|---|---|
| IL-01 | First-time homeowner dashboard | Homeowner looking at phone, welcoming scene, orange doorbell/house accent |
| IL-02 | No messages | Two speech bubbles, navy + cream, one with an orange ellipsis |
| IL-03 | Request expired | Clock with an expired marker, tradie hat in background, soft orange tint |
| IL-04 | Job not found / unavailable | Broken pin or question-mark-on-map, neutral tones |
| IL-05 | Payment expired | Calendar with an x and a grey clock, peach tint |
| IL-06 | Review received | Star with a spark, warm orange and gold, celebratory |
| IL-07 | Success / booking confirmed | Handshake or checkmark scene, navy + orange, green accent |
| IL-08 | Empty tradie lead queue | Tradie looking hopeful, tool belt, soft blue background |

---

## 7. Screen-by-screen visual treatment

Apply these visual treatments on top of the layout and structure defined in [specification.md §4](specification.md). Numbers in parentheses are pixel dimensions for the reference sizes (402×874 homeowner, 440×956 tradie, 834×1194 iPad).

### S01 — Splash

- Background: `heroGradient` full screen.
- Radar rings behind wordmark at 8% white.
- Blueprint grid at 4%, fading toward bottom with gradient mask.
- Wordmark: white "Tradie" + orange "Hunter" (existing `FixoWordmark` style, inverted for gradient surface).
- Tagline 16/500 white, fades in on load (opacity 0→1, 300ms, delayed 200ms).
- Orange underline accent (2×32px) beneath the wordmark.
- Film grain over gradient at 2%.

### S02–S04 — Onboarding slides

- Background: `warmBg` gradient (cream → peach tint).
- Soft blobs: mid-blue tint at top-right, peach tint at bottom-left, 12% opacity.
- Illustration (160–200px) breaking out of a rounded blob (24px radius, white at 60%).
- Route-line motif (12% navy) on slide 2 connecting two location pins.
- Progress dots: pill shape, orange filled (active), navy tint (inactive).
- Next button: orange CTA with sheen; Skip: 48px ghost target, navy text.
- Slide 2 heading: "See credentials and reviews before you hire."

### S05 — Login

- Background: cream, small mid-blue blob at top-right (12%, blurred).
- Wordmark at top.
- Form: cards use unified container style.
- "Forgot password?" right-aligned under the Password field.
- "Sign in" button: orange CTA with sheen.
- Google button: white card, 56px, 1.5px navy-tint outline, Google icon.

### S06 — Sign-up

- Role selector: 2-up segmented control (72px tall).
- Selected role: orange tint (32%) fill + 2px orange border + soft orange glow ring (8px blur, 20% orange).
- Unselected: white card + 1px neutral border.
- Homeowner icon: house (unified with role-select screen).
- Tradie icon: wrench or hard-hat (consistent with role-select).
- Form scrolls; sticky "Create account" never covers a field.

### S07 — OTP verification

- Six 48×56 boxes, 1.5px neutral border, active box: 2px orange border.
- 22px/600 digits, tabular.
- Auto-advance on input; error state: red-tint border + shake animation (120ms, reduce-motion: skip shake).

### S08 — Role select

- Two cards, 20px radius, unified container style.
- Selected: orange tint (32%) fill + 2px orange border + glow.
- Icon tile: 56px, mid-blue tint (20%) background.

### H07 — Homeowner dashboard

- Background: flat cream (working screen; no blobs).
- Greeting: "Welcome back, [Name]" — Space Grotesk 28/700, navy.
- "Needs your attention" cards: 4px orange accent bar on left edge; tradie avatar in the card header has a gradient ring (navy → mid-blue, 2px).
- Compact progress bar: navy track, orange filled segment, 4px height, 4px radius.
- Raised Post job button: orange CTA with sheen + soft orange halo (12px blur, 20% opacity).

### H09 — Post a job

- Background: flat cream.
- Photo tiles: white cards with dashed 1.5px mid-blue-tint border; "+" icon in mid-blue.
- Estimate card: mid-blue tint (12%) background, large price in navy 28/700, IBM Plex Sans tabular.
- "Post Job" button: disabled state is greyed navy outline (not orange); enabled: orange CTA.

### H10 — Matching

- Background: `coolBg` gradient (mid-blue tint → cream).
- Radar rings at 8% navy.
- Animated rings pulse: 2s loop, scale 1.0→1.08→1.0, opacity 1.0→0.4→1.0. Reduce-motion: no pulse, static rings.
- Step captions: "Searching", "Contacting", "Replied" — 14px/600, navy.

### H11 — Match result

- **Hero band:** `heroGradient` (navy → mid-blue, 135°), 32px bottom radius.
  - Radar rings at 8% white.
  - Route line (dotted, 12% white) from a homeowner pin to a tradie pin.
  - Blueprint grid at 4%.
- **Tradie avatar:** 72px, white 3px ring, overlaps the bottom edge of the hero band by 36px; verified badge (green check, 18px).
- **Badges:** "Verified" and "Insured" as glass pills (white 80% + 12px blur, 1px white at 30% border, 12px/600 navy text) — outdoor variant uses solid white pills.
- **Price breakdown card:** unified container, mid-blue tint (6%) background, price row 24/700.
- **CTA:** orange with sheen + halo.

### H12 — Job detail (in progress)

- **Status strip** (compact, replaces the gradient header on detail screens): flat navy 64px strip containing the status pill and compact progress bar; text white.
- **People card:** unified container; three tonal buttons (Chat, Message, Call) in a 3-up row: mid-blue tint (20%) fill, navy 24px icon, 14px/600 navy label.
- **Details card:** unified container; price row 24/700 spans both columns.

### H13 — Chat

- Background: cream with blueprint-dot pattern at 3% (24px grid, navy dots).
- Status pill: one-line, floats below the header, mid-blue tint (12%) background, navy text, clock icon.
- Sent bubbles: navy fill, white text, 18px radius (square bottom-right corner).
- Received bubbles: white, `0 1px 4px rgba(navy, 0.08)` shadow, 18px radius (square bottom-left corner).
- Quick-reply chips: mid-blue tint (12%) fill, navy text, 40px height, horizontal scroll with fade edge.
- Composer: 56px, cream background, 1px neutral border; camera icon 48px mid-blue, send icon 48px orange.

### H14 — Payment

- Amount hero: `heroGradient` card (or mid-blue tint card), amount 40/700 Space Grotesk white.
- Numbered steps connected by a dotted vertical line (navy at 20%); each step has a 32px circle node in navy.
- Copy reference button: tonal, mid-blue tint fill, navy text.

### H15 — Payment status

- **Success state:** green radial burst (existing green, 8% opacity) behind the check icon; drawn-check animation 400ms.
- **Rejected state:** red tint (12%) card with alert icon; soft red-tint shape behind the icon.
- **Expired state:** grey tint card, `IL-05` spot illustration.
- Receipt summary: collapsed behind expandable "View receipt details" row.

### H16 — Dispute

- Background: flat cream.
- Evidence photo tile: neutral tint (12% navy) with a visible camera icon in navy (not dark navy fill).
- "What happens next" card: 3 numbered rows, mid-blue icon per row.

### H17 — Public tradie profile

- Hero photo: full-width or 88px circular depending on layout; verified badge overlay.
- Trust row: one instance only — rating or "New to TradieHunter" (Space Grotesk 18/600), jobs completed, verified badge.
- "Request for a job" sticky CTA: orange with sheen.
- "Message" tonal button: mid-blue tint.

### H18 — Messages list / self-profile / Settings

- **Messages:** 72px rows, avatar (40px circular), name 16/600, job title 14 secondary, last-message preview 14 truncated, time 12 right-aligned, unread dot 8px orange.
- **Settings:** grouped 20px cards, 56px rows, section labels 12/600 uppercase navy at 60% opacity. Log out: 56px row, red text, at very bottom, no card container.

### T19 — Tradie dashboard

- **Earnings hero band:** `heroGradient`, radar rings at 8% white, blueprint grid at 4%.
  - Earned amount: Space Grotesk 40/700 white, tabular figures.
  - Orange sparkline beneath the number (simple 4-point line chart, orange, 2px stroke). Reduce-motion: static data points instead of animated sparkline.
  - Supporting tiles (2-up): white cards on the hero band's lower section, 16px radius.
- **New leads section** (below hero, cream background):
  - Lead cards: white, unified container, **4px orange accent bar on left edge**.
  - Price: IBM Plex Sans 28/700 navy, top-left.
  - Urgency tag: orange pill, top-right of price row.
  - Countdown bar: orange filled over a navy-tint track, 6px height, 4px radius; bold time remaining 14/700 orange.
  - Metadata row: 14px, secondary colour.
  - Buttons: Decline (outlined navy-tint, 1/3 width) | Accept (orange CTA with sheen, 2/3 width), both 56px.
- **Today list:** flat cream; cards with pill top-right, price left.

### T21 — Request detail

- **Map header** (top 40% of screen when map available): full-width static map with contour lines at 5%, colour-matched to cream/navy palette.
  - Price in a white glass pill (white 85%, 16px blur, 14px radius) floating over the map.
  - Pin ripple animation: 3 rings expanding, navy at 6–8%, 1.5s loop. Reduce-motion: static pin.
- **Countdown bar:** full-width below the map (or below the address card if no map), 8px height, orange fill over navy-tint track, bold time 16/700 orange to the right.
- Sticky bottom: Decline (navy-tint outline) | Accept (orange CTA), 1:2 split.

### T22 — Active job

- Address card: unified container, mid-blue tint (12%) background, small static map thumbnail (80×64px) at right edge with contour lines; address text left.
- Three tonal action buttons (Navigate, Message, Call): 48px, mid-blue tint (20%) fill, navy icon, 14/600 label, 2-up then 1 or 3-up depending on screen width.
- Check In: orange CTA with sheen (56px).
- Check Out: navy solid CTA (56px), so the state change is visually distinct.

### T25 — Tradie onboarding wizard

- 4-step labelled progress bar: completed segments orange fill; current segment has a numbered circle node (24px, orange, white number); upcoming segments navy-tint track.
- Step cards: unified container.
- Service checkboxes: 56px rows inside soft cards; hourly-rate field slides in inline when ticked (height animation 200ms ease-out).
- Gradient fade above the sticky CTA: cream → transparent (40px), so content underneath is not abruptly cut.

### Dark mode variants (required for screens H07, H11, T19, T21)

- Surfaces: navy-black base from existing dark palette.
- Cards: existing dark elevated surface, 1px border at 12% white.
- Hero bands: slightly deeper navy → dark blue gradient; radar rings at 10% white (brighter to compensate for darker base).
- Orange CTAs: unchanged; shadow replaced with a glow `0 6px 20px rgba(orange, 0.30)` (no shadow on dark, use glow).
- Illustrations: re-tinted with brighter blues; orange accents unchanged; cream shapes → dark surface equivalent.
- Tonal buttons: mid-blue tint (20%) on dark surface; navy icon lightened to white or light-blue.
- Status pills: tints composited over dark surface; verify ≥4.5:1 for all text pairs.

### iPad layout

- **Content max-width:** 640px for forms and lists, centred.
- **Master-detail (≥744pt):** navy hero strip spans the left list pane; detail pane uses flat cream.
- **Left rail (≥1024pt):** 64px wide; icons + 12px labels; glass (white 80% + 20px blur); active item: 12% orange tint rounded rectangle behind icon + label.
- Chat: full-width with a 640px message column centred; quick replies within the same column.

---

## 8. Motion specification

| Interaction | Duration | Easing | Reduce-motion |
|---|---|---|---|
| Press (button) | 120ms | ease-out | No change (functional) |
| Sheet open / close | 280ms | spring (damping 0.7) | Fade only |
| Page / route transition | Shared-element for avatar and price | 300ms ease | Cross-fade only |
| Radar ring pulse | 2s loop, scale 1.0→1.08, opacity 1.0→0.4 | ease-in-out | Static rings |
| Countdown bar pulse (< 60 s) | 800ms loop, opacity 0.7→1.0 | ease-in-out | No pulse |
| Sparkline draw | 600ms, left to right | ease-out | Static points |
| Success check draw | 400ms path animation + green radial burst | ease-out | Opacity fade to final state |
| Card entry stagger | 40ms per card, opacity 0→1 | ease-out | Single fade |
| Skeleton shimmer | Cream → white, 1.2s loop | ease-in-out | Static cream |
| Service row expand | 200ms height animation | ease-out | Instant |

---

## 9. Deliverables

These are the expected outputs from the design phase. They are inputs to the Flutter implementation tasks V16-21–V16-26.

### 9.1 High-fidelity frames

Frames for every screen listed in §7 (light and dark where specified), plus outdoor/high-contrast variants for all hero screens, named by group and variant:
- `[ID]-light.png` / `[ID]-dark.png` / `[ID]-outdoor.png`
- Sizes: 402×874 (homeowner), 440×956 (tradie), 834×1194 (iPad)

### 9.2 Style tile

A single reference sheet containing:
- Palette: all six source colours with their 6/12/20/32% tints over cream and dark surfaces.
- Gradients: named swatches for `heroGradient`, `warmBg`, `coolBg`, `ctaSheen`.
- Typography: specimens for all 8 type roles (§5.1) in both light and dark.
- Radii: reference shapes at 4/12/14/16/20/28px.
- Shadows: rendered examples for cards, sheets, CTAs.
- Icon set: sample of 20 rounded-duotone icons at 24px.
- Illustration samples: 2 spot illustrations at final size.

### 9.3 Abstract asset kit (SVG)

- Soft blobs × 2 (top-right mid-blue, bottom-left peach)
- Radar rings × 1 (scalable, 3 and 4 ring variants)
- Route line × 1 (with homeowner pin and tradie pin endpoints)
- Blueprint grid tile × 1 (24px, dot and line variants)
- Tool-geometry shapes × 4 (hexagon nut, wrench arc, spirit-level pill, map pin silhouette)
- Contour lines × 1 (tileable strip)
- Noise overlay × 1 (2% and 3% variants)
- All 8 spot illustrations (IL-01–IL-08) at 200px

### 9.4 Component sheet

One Figma (or equivalent) frame per component at all states:

| Component | States |
|---|---|
| Lead card | Default, HIGH urgency, LOW urgency, expired, accepted, declined |
| Tradie hero | New, rated (4.8 ★), verified+insured, unverified |
| Trust tiles | New tradie, rated tradie, verified, insured |
| Status pills | 6 semantic variants × light + dark |
| Compact progress bar | Steps 1–4 + terminal (cancelled, disputed) × light + dark |
| Buttons | Primary, secondary, tonal, ghost, disabled × light + dark × default + pressed |
| Inputs | Default, focused, error, filled, disabled × light + dark |
| Bottom sheets | Cancel, dispute, map picker, schedule |
| Nav bars | Bottom nav (homeowner + tradie), left rail (iPad) |

### 9.5 Clickable prototype

Four core flows with shared-element transitions where specified:

1. **Homeowner:** Post job → Matching → Match result → Payment
2. **Tradie:** Lead card → Accept → Active job (Check In / Check Out)
3. **Chat:** Open conversation → Send message → Quick reply
4. **Onboarding:** Splash → Slides → Sign-up → OTP → Role select → First dashboard

---

## 10. Acceptance criteria (visual design)

- **AC-VD-01 Colour compliance:** no hue outside the six source colours; all derivations are tints, tonal steps, or named gradients from §2.2; verified by colour-picker spot-check on all frames.
- **AC-VD-02 Orange proportion:** orange appears in ≤2 places per working screen (always CTA + at most one urgency/countdown element); not used decoratively.
- **AC-VD-03 Contrast:** every text/background pair ≥4.5:1 (≥3:1 for 18px+/700); measured after compositing abstract assets; outdoor variants pass without relying on abstracts.
- **AC-VD-04 Abstract placement:** no abstract asset behind body text, form fields, or CTAs; all assets are in top 30% or hero-band regions.
- **AC-VD-05 Outdoor variant:** every hero screen has a flat, high-contrast companion with no blobs, glass, or gradients over text; all text pairs still pass contrast.
- **AC-VD-06 Illustration consistency:** all spot illustrations (IL-01–IL-08) match the existing onboarding style (flat vector, palette colours, friendly tradies with orange accents, no photos or stock).
- **AC-VD-07 Motion/reduce-motion:** every animated element has a defined reduce-motion fallback; no animation loop is attention-grabbing at rest (radar pulse stays gentle).
- **AC-VD-08 Component completeness:** component sheet covers all states listed in §9.4; no state is missing or marked "TBD".
- **AC-VD-09 Realistic data:** no lorem ipsum, no "Shot PROG 17…" fixture names, no placeholder bank account names; all frames use realistic NZ trade data (e.g. "Leaking kitchen tap, Grey Lynn", "$171.00", "Mike T., Plumber, 4.8 ★ (126)").
- **AC-VD-10 Spec fidelity:** every layout dimension, status pill, progress bar, and touch target from specification.md §3–4 is represented faithfully in the frames; no deviations without a recorded justification.
