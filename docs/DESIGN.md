# TradieHunter — Design System

Visual and interaction source of truth for the Flutter app and admin web. Layout and behaviour contracts are in [SPECS §10](SPECS.md#10-mobile-ux-contract-v15--v16); this file covers look, tokens, frames and tooling. Current system version: **v1.7** (kit.css rewritten on semantic tokens).

## 1. Source of truth

| Path | What |
|---|---|
| `docs/design/html/kit.css` | Tokens + component vocabulary; `.dark` and `.outdoor` re-map custom properties |
| `docs/design/html/frames-*.html`, `prototype.html`, `component-sheet.html`, `style-tile.html` | 141 `[data-frame]` screens: 63 light (hand-edited) + 63 dark + 15 outdoor (both generated) |
| `docs/design/tokens/` | `tokens.json`, `tokens.css`, `design_tokens.dart`, kept in parity |
| `docs/design/assets/` | Brand marks (wordmarks, app icon set, map pins, notification icon), 12 illustrations in light/dark, textures, tool icons |
| `docs/design/fonts/` | Space Grotesk 500–700, IBM Plex Sans 400–700, IBM Plex Mono 500 (woff2) |
| `docs/design/design-system.html` | Original palette/token baseline (`--hue` 209), superseded by `tokens/` but still cited by older specs |
| `mobile/lib/theme/design_tokens.dart` | Dart tokens consumed by the app |

Existing mockups were deliberately **not** used as acceptance criteria for the v1.5/v1.6 UI sprints; the design specs and tokens were. From v1.7 the frames are again the visual reference for new screens (for example H19 Browse Tradies).

## 2. Art direction

*Trustworthy trade craft, made warm and modern.* Blueprint precision plus friendly local service: warm cream canvas, confident navy structure, **one** energetic amber accent per screen.

| Screen type | Tone | Treatment |
|---|---|---|
| Hero / celebration (splash, onboarding, match result, earnings, empty states, success) | Warm, energetic | Gradient hero bands, rings, blobs, illustrations |
| Working / outdoor (lists, forms, job detail, payment, chat) | Calm, flat, legible | Cream surface, single accent, no blobs or glass |

Every hero screen has an **outdoor/high-contrast variant** (no blobs, gradients or glass) used in bright light and when Reduce Transparency is on.

## 3. Colour

Hues are locked: `hue = 209` blue. No new accent hues, neon or glossy gradients; all expression is tints, tonal steps and proportion.

| Role | Token | Use |
|---|---|---|
| Structure | navy | Headings, hero bands, active nav, dark-mode base |
| Action | amber `#E38B29` | Primary CTA, urgent timer, "needs action" |
| Information | mid-blue | Avatars, info banners, tonal buttons, progress |
| Canvas / surface | cream / white | Background / cards, sheets |
| Success / problem | green / red | Verified, paid, done / disputed, rejected only |

Tints at 6 / 12 / 20 / 32% of a source colour; navy and blue may shift one tonal step (~15%) for gradient ends. Contrast: text ≥ 4.5:1 (3:1 large), meaningful non-text ≥ 3:1, measured after compositing over the theme surface. Never rely on hue alone.

**Brand budget:** at most 2 amber elements per screen (primary CTA + one urgency; a countdown counts as one). Green = verified/done, red = problem/dispute. **Selection = 2 dp brand border + tint + check, never amber.**

## 4. Type, geometry, interaction

| Token | Value |
|---|---|
| Display / hero | Space Grotesk 700, 28 / 40 |
| Section | Space Grotesk 600, 20 |
| Card title | IBM Plex Sans 600, 18 (two lines) |
| Price | IBM Plex Sans 700, 24 (payment hero 32) |
| Body / secondary | IBM Plex Sans 400, 16 / 14 |
| Caption | IBM Plex Sans 500, **12 px floor** |
| Mono | IBM Plex Mono 500, reference codes only |
| Spacing | 4-pt scale, 20 px gutter; section gaps 24–32, card gap 12 |
| Radii | card 20, control 14, tile 16, sheet 28, pill 999 |
| Sizes | tap target ≥ 48, button 56 (secondary 52, tonal/ghost 48), input 56, nav 64–68, app bar 56, FAB 56 |

Cards: 1 px neutral border, soft navy shadow (`0 2px 8px` at 8%). Dark mode uses elevated surfaces and visible borders, never white cards. Primary CTA label 17/600. Decline is a live outlined action, never a faded disabled label. Bottom action bars respect safe area and keyboard (subtle top shadow). Nav: Homeowner Home / Jobs / raised Post / Messages / Profile; Tradie Dashboard / Jobs / Messages / Profile. Icons: rounded outline set, 24 px (26 in nav), filled only for the active tab; every tappable icon ≥ 48 dp with a label. Support 320 px width, 393×852 and 430×932 phones, text scale 1.0–2.0, iPad master-detail ≥ 744 pt and left rail ≥ 1024 pt (content max-width 640). Respect reduced motion; no per-second timer announcements.

## 5. Component vocabulary

| Mockup class | Flutter |
|---|---|
| `.appbar`, `.back`, `.ico-btn` | `FixoAppBar`, `FixoBackButton`, `FixoAppBarAction` |
| `.btn-primary` / `.tonal` / `.ghost` | `FixoPrimaryButton` / `FixoTonalButton` / `FixoGhostButton` |
| `.card`, `.tile` | `FixoCard`, `FixoCard(radius: Radii.tile)` |
| `.av` (`.vbdg`) | `FixoAvatar` (verified badge) |
| `.wordmark` | `FixoWordmark` ("Hunter" in amber) |
| `.pill.*` (action, active, waiting, done, muted, problem) | `StatusBadge` / `THStatusPill` |
| `.chip` (40 dp draw, 48 dp hit) | `FixoFilterPill` / `THFilterChip` |
| `.faderow` | Horizontal scrolling chips with 32 px fade |
| `.badges` | `Wrap` |
| `.spread` | `Row(spaceBetween)` with `Expanded` text |
| `.heroband`, `.status-strip`, `.cpb` | Hero band, status strip, compact progress bar (4 segments) |
| `.countdown` | Countdown driven by server expiry |
| `.navbar` / `.rail` + `.fab` | `CustomBottomNavBar` + FAB |

Mockup semantics are binding. Generated files carry a `// GENERATED` header and are regenerated, not patched. Reuse the `Fixo*` family before creating a widget; new design-system components follow the `TH*` contract in `tools/design2flutter/th_components.dart`.

### Flutter token map
Use `Space.*` (gutter = `Space.gutter`), `Radii.*`, `Sizes.*`, `FW`, `Alpha`, `Tracking`, `FixoDurations` (renamed from `Durations`, which collides with Material), `THColors` via `Theme.of(context).extension<THColors>()` and `DesignTokens`. Never write `Color(0x…)`, magic numbers or `if (isDark)` in a view; dark/outdoor is a token swap. A missing token is added to `design_tokens.dart`, `tokens.json` and `kit.css` together. About 1,090 hard-coded values were replaced in v1.6; the few intentionally left raw (off-scale micro-adjustments, `Colors.white` on brand fills, the private splash gradient end) need design sign-off to change.

## 6. Frame inventory (141 frames)

- **Entry (8):** S01 splash, S02–S04 onboarding slides, S05 login, S06 sign-up, S07 OTP, S08 role select. **States (7):** expired/not-found/unavailable request, payment expired, no messages, empty leads, first run. **Components (5):** skeleton card, toast, banner, badge, controls. **iPad (6):** dashboard, messages, post job (light, plus dark variants).
- **Homeowner (25, `frames-homeowner.html`):** H07 dashboard (+ empty), H08 categories, H09 post job, H10 matching (+ no match), H11 match result, H12 job detail (in progress / dispute), H13 chat, H14 payment instructions (+ copy toast), H15 payment status (review / success / rejected / expired), H16 dispute, H17 tradie profile (rated / new / rated expanded), H18 messages / self-profile / settings, **H19 Browse Tradies** (the v1.7 Choose-a-Tradie reference), H20 notifications.
- **Tradie (12, `frames-tradie.html`):** T19 dashboard, T20 jobs, T21 lead detail, T22 booked / in progress, T23 chat, T24 profile, T25 onboarding steps 1–4, T26 homeowner profile.
- Dark and outdoor variants are generated into `frames-dark` / `frames-outdoor`.

Frame rules: icons are inline SVG, no sprite refs (`<use href="#i-*">`) in visible UI; every primary action sits in `<div class="sticky">` at the bottom with `flex:1` content above it; composer send icon is a right-facing paper plane; every `btn-tonal` carries a leading inline SVG (Navigate compass, Message bubble, Call handset, Check in pin, Check out check); H07 uses a navy hero band with a bell + amber unread dot and no "Post a job" strip (the FAB is the single entry point); `.attcard` is a top tint wash with no left border; dark `pill-waiting` is `rgba(137,175,210,.28)` with white text.

## 7. Feedback notices

All transient feedback uses `FixoNotice` (no `ScaffoldMessenger.showSnackBar`). Notices sit in an overlay at the top, one at a time (a new call cross-fades), never block taps, ≥ 48 dp row with close.

| Tone | Method | Use | Auto-dismiss |
|---|---|---|---|
| info | `FixoNotice.info` | Neutral confirmations, copy actions | 3 s |
| success | `.success` | Completed actions ("Job cancelled") | 3 s |
| warning | `.warning` | Non-blocking caution (no connection, expiry near) | 4 s |
| error | `.error` | Failed operation to retry | 5 s |
| push | `.push(title, body, onTap)` | Foreground FCM banner, `FixoApp._handleForegroundMessage` only | 5 s |

Copy rules: sentence case, active voice, ≤ 80 characters, no notice plus inline error for the same failure, dynamic values via `NoticeCopy` getters, never literals at call sites. Strings live in `mobile/lib/feedback/notice_copy.dart` (`copied`, `jobCancelled`, `checkInFailed`, `offerAcceptFailed`, `profileUpdated`, `reviewsLocked`, `codeSent(email)`, `onlineStatusChanged(online)`, …). Architecture: `FixoNoticeHost` (wraps the router content, owns the overlay) → `FixoNoticeController` (Riverpod `StateNotifier`) → `FixoNotice` static façade. Debug gallery at `/debug/notice-gallery` in debug builds only.

## 8. Regression gates (design changes must pass)

1. `python3 docs/design/tools/audit_full.py docs/design out.json`: `clip=0`, `tap=0`, `small=0`, `contrast=0` (< 4.5:1; 3:1 large), `static=0` undefined classes.
2. No `style="background:var(--surface)"` on `.seg.on`; no `rgba(255,57,87` in `kit.css`.
3. Orange budget: no screen frame with more than 2 amber elements.
4. Every `.ico-btn` / `.ibtn` / `.back` has `aria-label`; every `<img>` has `alt`.
5. iPad frames: `.md` right edge equals frame right edge (0 px overflow).

The v1.6.1 audit behind these gates (findings F-101…F-118: iPad master-detail overflow, illegible dark pills, raw palette colours, sub-48 dp targets, unnamed icon buttons, orange violations) is closed; the gates keep it closed.

## 9. Build pipeline

```bash
cd docs/design
./build.sh                  # variants.py (dark + outdoor from light) → inline_sprite.py → assemble.py → render frames/*.png
SKIP_RENDER=1 ./build.sh    # assemble only
```

Needs Python 3 + `beautifulsoup4`, and for rendering `playwright` + Chromium. Only the **light** frames are hand-edited. Other scripts: `audit_full.py` (gates), `audit.py`, `make_brand.py` (brand exports), `make_illustrations.py`, `sheet.py`. `render.py` / `render.mjs` screenshot frames. The HTML → Flutter transpiler and agent tooling live outside docs; see [ai/AI-TOOLING.md](ai/AI-TOOLING.md).

Brand note: the wordmark reads TradieHunter with "Hunter" in amber `#E38B29`. App icon set, splash logo, notification icon and map pins are under `assets/brand/`. The email header uses `wordmark-on-light@2x.png` hosted on the CDN.
