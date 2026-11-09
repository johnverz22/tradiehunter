# Mobile App Hardcoded Values Audit

## Remediation status (updated 2026-11-03)

**Done:**
- **Phase 1** — all proposed tokens added to `design_tokens.dart`: `Space.s0_5/s1_5/s2_5`, `Space.navClearance`, `Space.stickyBarClearance`, `Radii.micro/small/medium`, `FW`, `FixoDurations` (renamed from `Durations` — collides with `material.dart`'s own `Durations`), `Tracking`, `Alpha` (28 values, exact-preserving), `fontSizeSm/fontSizeH2Small/fontSizeAmountLg/fontSizeTiny`, `FixoPadding`, `SocialColors.googleBlue`, `THColors.navBarShadow`/`cardElevatedShadow`.
- **Phase 2** — ~1,090 mechanical replacements via script: 344 SizedBox, 174 EdgeInsets (+6 `FixoPadding.page`), 155 fontSize, 209 FontWeight, 32 radii, 17 durations, 13 letterSpacing. Only scale-exact values swapped (pixel-identical); off-scale leftovers listed below.
- **Phase 3** — all 45 `Color(0x…)` literals outside `design_tokens.dart` mapped to tokens per the table below (one intentional keep: splash `_gradientBottom 0xFF2A5A8C`, a private named const). 125 `withValues(alpha:)` → `Alpha.*`. `isDark ? cardDark : Colors.white` → `surfaceCard(isDark)`; `Colors.whiteXX/blackXX` shorthands → `withValues(Alpha.*)`; `Colors.red` → `th.danger`; grey shades → `inkSoft*`; `Colors.white` on gradients/fills kept deliberately.
- **Phase 4** — new shared widgets in `lib/views/widgets/`: `fixo_feedback.dart` (`FixoInfoBanner`+`.error` ctor, `FixoPillChip`, `FixoSectionLabel`, `FixoTone`), `fixo_rows.dart` (`FixoStepRow`, `FixoSummaryRow`, `FixoDetailRow`, `FixoListDivider`, `FixoCopyButton`), `fixo_progress_bar.dart` (`FixoProgressBar`), `fixo_cta_stack.dart` (`FixoCtaStack`). Replaced ~14 private widget classes: `_ErrorBanner`×4, `_Banner`, `_InfoBanner`, `_TrustChip`, `_Chip`, `_StatusPill`(schedule), `_UrgentChip`, `_VerificationBanner`, `_sectionLabel`, `_SectionLabel`, `_GroupLabel`, `_buildBar`, `_ErrorNote`, `_Step`, `_StepDivider`, `_CopyButton`, `_SummaryRow`, `_Divider`, `_DetailRow`. `FixoAvatar` and `FixoHeroHeader` skipped (avatar exists; hero headers too divergent).
- **Phase 5** — durations/letterSpacing/radii/alpha covered by the Phase 2 pass; BoxShadow sites already use `shadowCard`/`Alpha` tokens.

**Deliberately left raw (need design sign-off or are intentional):**
- SizedBox 3/5/14/18/28 (~11 sites), EdgeInsets args 1/1.5/3/5/7/9/14/22/48/56 (~60 args — micro-adjustments, not scale values), fontSize 1/10/17/22/26/28/40 (~9 sites), Radius.circular 1/22/24/32, `Colors.white` on gradients/brand fills (~50 — correct "on-dark" usage), `Colors.transparent` (overlays), `fontFamily:` overrides (~85 — the v1.6 type ramp is applied via inline styles; converting to `textTheme` roles is a separate refactor), `0xFF2A5A8C` splash gradient stop.

**Verification:** `flutter analyze` — 7 pre-existing warnings only. `flutter test` — 618 pass; 49 failures all pre-existing baseline (shared-layout/status-strip overflow, chat composer a11y, auth surfaces, GoogleFonts asset issue) — unchanged by this work (pixel-identical pass; verified against the pre-change failure list).

## Summary

The app has a **comprehensive design token system** (`design_tokens.dart`) with `Space`, `Radii`, `Sizes`, `TypeTokens`, `THColors`, and a `FixoTheme`. A `DesignTokens` shim maps legacy names to canonical values. Despite this, **~1,250 hardcoded values** persist across 45+ files in `lib/`, bypassing the token system.

### Existing Token Coverage

| Token group | Classes | Status |
|---|---|---|
| Spacing | `Space` (s1=4, s2=8, s3=12, s4=16, s5=20, s6=24, s7=32, s8=40, gutter=20) | Good — exists but underused |
| Radii | `Radii` (card=20, control=14, tile=16, sheet=28, pill=999) | Good — exists but underused |
| Sizes | `Sizes` (tapMin=48, button=56, input=56, nav=68, appBar=56, avatarSm/Md/Lg/Xl) | Good — exists but underused |
| Typography | `TypeTokens` (fontDisplay, fontBody, fontMono) | Good — but fontFamily inlined 78x |
| Colors | `THColors` (light/dark/outdoor via ThemeExtension) | Good — but 122 hex literals bypass it |
| Font sizes | `DesignTokens.fontSizeH1/H2/H3/Body/Secondary/Caption/Status/Display/Control/Mono/Amount` | Good — but 164 raw fontSize values |
| Font weights | None defined | **Missing** |
| Durations | None defined | **Missing** |
| Letter spacing | None defined | **Missing** |
| Shadows | `THColors.cardShadow`, `THColors.ctaShadow` | Exists but 16 inline BoxShadows bypass it |
| Alpha tints | None defined | **Missing** — 124 inline `withValues(alpha:)` |

### Existing Reusable Widgets

Already extracted: `FixoAppBar`, `FixoBackButton`, `FixoPrimaryButton`, `FixoGhostButton`, `FixoTonalButton`, `FixoCard`, `StatusBadge`, `JobStepper`, `FixoLoading`, `FixoEmptyState`, `FixoErrorState`, `FixoWordmark`, `FixoResponsive`, `ResponsiveContainer`, `MasterDetailLayout`, `FixoHeaderBackground`, `FixoGradientTopArea`, `StickyActionBar`, `FixoAppBarAction`.

---

## Hardcoded Value Findings

### 1. Colors — 122 hardcoded `Color(0x...)` outside theme + 133 `Colors.*` usages

**Hardcoded hex colors (non-theme files):**

| Hex | Used in | Should be |
|---|---|---|
| `0xFF92600A` | tradie_dashboard_view (line 303) | `THColors.accentText` (light) or new `amberDark` token |
| `0xFFB96A18` | tradie_dashboard_view (line 430, 1538) | `THColors.accentText` or accentText variant |
| `0xFF22C55E` | tradie_dashboard_view (line 770) | `THColors.success` (light) |
| `0xFF64748B` | tradie_dashboard_view (line 771), job_timeline | New `THColors.neutral` token |
| `0xFF717D8A` | tradie_dashboard_view (line 1048) | `THColors.textSoft` |
| `0xFF90CAF9` | job_timeline (lines 144, 183, 310) | `THColors.brand` (dark) |
| `0xFFE57373` | job_timeline (line 324) | `THColors.danger` (dark) |
| `0xFF94A3B8` | job_timeline (line 325) | New `THColors.neutral` or `THColors.textSoft` |
| `0xFF3A7D5C` | payment_status_screen (lines 142, 148, 219, 227, 286) | `THColors.success` (light) / `DesignTokens.green` |
| `0xFF4285F4` | signup_screen (line 441), login_screen (line 246) | Google brand color — define as `SocialColors.googleBlue` |
| `0xFFFAF8F5` | tradie_onboarding_wizard (line 282) | `THColors.surface` (light) variant |
| `0xFFF1F3F5` | profile_screen (line 150) | `THColors.surface` or neutral tint |
| `0xFFF3F4F6` | chat_screen (line 329) | `THColors.surface` |
| `0xFFFDE8E8` | settings_screen (line 217) | `THColors.danger.withValues(alpha: 0.12)` |
| `0xFFEAE6DF` | 7 files (nav bar, buttons, cards, states) | `DesignTokens.paperLineLight` variant or new `THColors.lineWarm` |
| `0xFF48515A` | fixo_cards (line 90) | `THColors.textSoft` (light) |
| `0xFF9B2B21` | fixo_cards (line 97) | `THColors.danger` (light) / `DesignTokens.inkDanger(false)` |
| `0xFF241300` | rating_sheet (218), schedule_sheet (342) | `DesignTokens.onAmber` |
| `0xFFE5E0D8` | tradie_dashboard_view (line 1491) | `DesignTokens.paperLineLight` |
| `0xFFD8CEBE` | tradie_dashboard_view (line 1144) | New warm border token |
| `0xFFF5EFEB` / `0xFFECE3D6` | tradie_dashboard_view (line 1138) gradient | Define as gradient tokens |
| `0xFFF6F4EF` | match_result_screen (line 147) | `THColors.paper` variant |
| `0xFFF8FAFC` | job_info_grid (line 22) | `THColors.surface` |
| `0xFF1E293B` | job_info_grid (line 22) | `THColors.surface` (dark) variant |
| `0xFFEDEBE5` | auth_controls (line 115) | `THColors.surface` variant |
| `0xFFF5F2EE` | main_layout (line 160) | `THColors.paper` variant |

**`Colors.*` raw Material constants (133 instances in 31 files):**
- `Colors.white` — 70+ uses (should use `THColors.surface` or `DesignTokens.surfaceCard`)
- `Colors.transparent` — 15+ uses (acceptable for overlay backgrounds)
- `Colors.red` — 3 uses (should use `THColors.danger`)
- `Colors.black.withValues(alpha:)` — several uses for shadows
- `Colors.white.withValues(alpha: 0.xx)` — 40+ uses (should define opacity tokens)

### 2. EdgeInsets / Padding — 241 instances with raw numbers

**Hotspots:**

| File | Count | Common pattern |
|---|---|---|
| tradie_dashboard_view | 20 | `EdgeInsets.symmetric(horizontal: Space.s4, vertical: 10)` — mixing tokens and raw |
| tradie_onboarding_wizard | 18 | `EdgeInsets.fromLTRB(24, 16, 24, 24)` — page padding |
| public_profile_screen | 14 | `EdgeInsets.symmetric(horizontal: 16)` |
| settings_screen | 11 | `EdgeInsets.symmetric(horizontal: 16)` |
| post_job_screen | 11 | `EdgeInsets.fromLTRB(24, 16, 24, 24)` |
| match_result_screen | 11 | `EdgeInsets.fromLTRB(20, 0, 20, 20)` |
| chat_widgets | 9 | `EdgeInsets.symmetric(horizontal: 12, vertical: 8)` |
| homeowner_job_detail_screen | 8 | `EdgeInsets.fromLTRB(24, 16, 24, 24)` |
| payment_screen | 7 | `EdgeInsets.fromLTRB(24, 24, 24, 24)` |
| signup_screen | 7 | `EdgeInsets.fromLTRB(24, ..., 24, ...)` |

**Should use:**
- `EdgeInsets.all(Space.s4)` instead of `EdgeInsets.all(16)`
- `EdgeInsets.symmetric(horizontal: Space.gutter)` instead of `horizontal: 20`
- New `FixoPadding.page` constant for the standard `EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s6)` page pattern

### 3. fontSize — 164 raw numeric values

| Raw value | Count | Token equivalent |
|---|---|---|
| 12 | 40 | `DesignTokens.fontSizeCaption` / `fontSizeStatus` |
| 13 | 25 | `DesignTokens.fontSizeSecondary` |
| 14 | 18 | (between secondary and body — consider token `fontSizeSm` = 14) |
| 15 | 12 | `DesignTokens.fontSizeBody` |
| 16 | 14 | `DesignTokens.fontSizeH3` |
| 18 | 8 | (between H3 and H2 — consider token `fontSizeH2Small` = 18) |
| 20 | 6 | `DesignTokens.fontSizeH2` |
| 22 | 3 | (no token — add `fontSizeAmount` already = 24) |
| 24 | 6 | `DesignTokens.fontSizeH1` / `fontSizeAmount` |
| 28 | 3 | (between H1 and Display — consider token) |
| 32 | 4 | `DesignTokens.fontSizeDisplay` |
| 36 | 2 | (no token — consider `fontSizeAmountLarge`) |
| 38 | 1 | (no token) |
| 40 | 1 | (no token) |

### 4. SizedBox spacers — 357 instances with raw numbers

The single largest category. Raw `SizedBox(height: N)` or `SizedBox(width: N)` where N maps directly to Space tokens:

| Raw value | Approx count | Token |
|---|---|---|
| 2 | 8 | `Space.s0_5` (missing — add 2.0) |
| 3 | 4 | (no token — add `Space.s0_75` or skip) |
| 4 | 35 | `Space.s1` |
| 5 | 8 | (no token) |
| 6 | 12 | `Space.s1_5` (missing — add 6.0) |
| 8 | 35 | `Space.s2` |
| 10 | 12 | (no token — add `Space.s2_5` or use s2/s3) |
| 12 | 30 | `Space.s3` |
| 14 | 6 | (no token — use s3 or s4) |
| 16 | 45 | `Space.s4` |
| 18 | 3 | (no token) |
| 20 | 8 | `Space.s5` |
| 24 | 25 | `Space.s6` |
| 28 | 3 | (no token) |
| 32 | 15 | `Space.s7` |
| 40 | 5 | `Space.s8` |

### 5. BorderRadius.circular — 31 raw values

| Raw value | Count | Token |
|---|---|---|
| 2 | 4 | (no token — micro radius for progress bars) |
| 3 | 3 | (no token — micro radius) |
| 4 | 1 | `DesignTokens.radius` (legacy 4.0) |
| 10 | 3 | (no token — `Radii.small`?) |
| 12 | 3 | (no token — `Radii.medium`?) |
| 16 | 5 | `Radii.tile` |
| 22 | 1 | (no token) |
| 24 | 1 | (no token) |
| 28 | 1 | `Radii.sheet` |
| 100 | 8 | `Radii.pill` (should use 999 or `Radii.pill`) |
| 999 | 1 | `Radii.pill` |

### 6. FontWeight — 199 instances, no weight tokens

| Weight | Count | Semantic |
|---|---|---|
| w400 | 15 | Regular body text |
| w500 | 15 | Medium emphasis |
| w600 | 70 | Semi-bold — labels, button text, section headers |
| w700 | 70 | Bold — headings, amounts, active states |
| w800 | 2 | Extra bold — large amounts only (payment_screen) |

### 7. BoxShadow — 16 inline instances outside theme

| File | blurRadius | Issue |
|---|---|---|
| tradie_dashboard_view (3) | 4, 3, 8 | Inline shadow definitions |
| custom_bottom_nav_bar (3) | 16, 16, 8 | Should use elevation tokens |
| main_layout (1) | 6 | Inline |
| modern_job_card (1) | 8 | Inline |
| chat_widgets (1) | 6 | Inline |
| homeowner_dashboard_header (1) | 24 | Inline |
| sticky_action_bar (1) | 16 | Should use `THColors.cardShadow` variant |

### 8. Duration — 19 raw `Duration(milliseconds:)`

| Value | Count | Use |
|---|---|---|
| 150 | 4 | Button press/animation |
| 200 | 2 | Switch toggle |
| 220 | 1 | Page transition |
| 250 | 1 | Onboarding dot |
| 280 | 1 | Onboarding slide |
| 300 | 3 | Delay / debounce |
| 400 | 1 | Address debounce |
| 600 | 1 | Splash ring delay |
| 800 | 1 | Rating sheet delay |
| 1000 | 1 | Schedule sheet delay |
| 1200 | 1 | Splash ring delay |
| 2800 | 1 | Splash total duration |

### 9. letterSpacing — 13 raw values

| Value | Count | Context |
|---|---|---|
| -0.02 * fontSize | 4 | Display headings (should be token `letterSpacingTight`) |
| -0.01 * 11 | 1 | Nav bar label |
| -0.8 | 1 | Splash |
| 0.2 | 3 | Section labels / badges |
| 0.4 | 1 | Dashboard header |
| 0.5 | 2 | Urgent chip uppercase |
| 0.8 | 3 | Onboarding labels |

### 10. withValues(alpha:) — 124 inline opacity tints

The most pervasive pattern. Repeated alpha values that should be semantic tokens:

| Alpha | Count | Semantic |
|---|---|---|
| 0.05 | 3 | Very subtle overlay |
| 0.06 | 3 | Subtle card gradient stop |
| 0.07 | 2 | Info banner background |
| 0.08 | 6 | Tinted icon background |
| 0.10 | 2 | Light danger/success tint |
| 0.12 | 20 | Standard tint (brand/danger/success/neutral) — **most common** |
| 0.15 | 10 | Accent/amber tint |
| 0.16 | 2 | Green tint (profile) |
| 0.18 | 3 | Brand gradient stop |
| 0.20 | 2 | Dark mode brand tint |
| 0.25 | 8 | Border emphasis |
| 0.28 | 3 | Dark mode status tint |
| 0.30 | 3 | Border / divider emphasis |
| 0.35 | 5 | Border accent |
| 0.4 | 4 | Shadow / border |
| 0.45 | 3 | Dark mode outline |
| 0.5 | 2 | Divider fade |
| 0.55 | 2 | Dark mode progress bar |
| 0.65 | 2 | White text on gradient |
| 0.7 | 3 | White icon on gradient |
| 0.75 | 8 | White text on gradient (subtle) |
| 0.92 | 2 | Nav bar background |
| 0.55 | 2 | Progress bar fill (dark) |

---

## Repeated Widget Patterns to Extract

### Pattern 1: Tinted Info Banner / Notice Card
**Found in:** tradie_dashboard_view (paused banner, verification banner), payment_screen (materials disclaimer), dispute_screen, homeowner_job_detail_screen, cancel_job_sheet

**Current pattern (repeated 8+ times):**
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: someColor.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: someColor.withValues(alpha: 0.3)),
  ),
  child: Row(children: [Icon(...), SizedBox(width: 12), Expanded(child: Column(children: [Text(title), Text(body)]))]),
)
```

**Proposed widget:** `FixoInfoBanner`
- Parameters: `icon`, `title`, `body`, `tone` (brand/amber/danger/success/neutral), `actionLabel`, `onAction`
- Uses `THColors` + `Radii.tile` + `Space.s4`

### Pattern 2: Section Label with Count Badge
**Found in:** tradie_dashboard_view (`_sectionLabel`), jobs_list_screen

**Current:**
```dart
Row(children: [
  Text(title, style: TextStyle(fontSize: 12, fontWeight: w700, letterSpacing: 0.2, color: textSoft)),
  SizedBox(width: 6),
  Container(padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(color: amber.withAlpha(0.15), borderRadius: circular(999),
      border: Border.all(color: amber.withAlpha(0.3))),
    child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: w700, color: Color(0xFFB96A18))))
])
```

**Proposed widget:** `FixoSectionLabel`
- Parameters: `label`, `count` (optional), `tone`

### Pattern 3: Pill Chip / Status Chip
**Found in:** tradie_dashboard_view (`_UrgentChip`), payment_status_screen (verified chip), match_result_screen, schedule_sheet, job_timeline

**Current:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withAlpha(0.1), borderRadius: circular(100), border: Border.all(...)),
  child: Row(children: [Container(width: 6, height: 6, circle, color), SizedBox(width: 6), Text(uppercase, style: TextStyle(fontSize: 12, w700, letterSpacing: 0.5))])
)
```

**Proposed widget:** `FixoPillChip`
- Parameters: `label`, `dotColor` (optional), `tone`, `isUppercase`

### Pattern 4: Gradient Hero Header
**Found in:** tradie_dashboard_view (`_TradieHero`), homeowner_dashboard_header, payment_screen (amount hero)

**Current:** Dark brand gradient container with white text, sub-tiles, and optional toggle.

**Proposed widget:** `FixoHeroHeader`
- Parameters: `gradient`, `children` / `title` / `subtitle` / `amount` / `actions`

### Pattern 5: Numbered Step Row
**Found in:** payment_screen (`_StepRow`), tradie_onboarding_wizard

**Current:**
```dart
Row(children: [
  Container(circle, child: Text('$number', style: TextStyle(fontMono, 14, w700, brand))),
  SizedBox(width: 12),
  Expanded(child: Column(children: [Text(title, style: TextStyle(15, w600)), SizedBox(height: 6), child]))
])
```

**Proposed widget:** `FixoStepRow`
- Parameters: `number`, `title`, `child`

### Pattern 6: Summary Row + Divider
**Found in:** payment_screen (`_SummaryRow`, `_Divider`), settings_screen, payment_status_screen, homeowner_job_detail_screen

**Current:**
```dart
// Row
Row(mainAxisAlignment: spaceBetween, children: [
  Text(label, style: TextStyle(fontSize: 13, color: inkSoft)),
  Text(value, style: TextStyle(fontSize: 13, fontWeight: w600))
])
// Divider
Divider(height: 1, color: paperLine)
```

**Proposed widget:** `FixoSummaryRow` + `FixoListDivider`

### Pattern 7: Labeled Progress Bar
**Found in:** tradie_dashboard_view (`_LeadCountdownBar`), compact_progress_bar, offer_countdown, post_job_screen

**Current:**
```dart
Row(children: [
  Expanded(child: ClipRRect(borderRadius: circular(3), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: track, valueColor: barColor))),
  SizedBox(width: 8),
  Text(label, style: TextStyle(fontSize: 13, fontWeight: w600, color: labelColor))
])
```

**Proposed widget:** `FixoProgressBar`
- Parameters: `progress`, `label`, `barColor`, `trackColor`, `height`

### Pattern 8: CTA Stack (Primary + Ghost)
**Found in:** payment_status_screen (`_cta`), match_result_screen, homeowner_job_detail_screen, tradie_job_detail_screen, matching_screen

**Current:**
```dart
Column(mainAxisSize: min, children: [
  FixoPrimaryButton(label: '...', onPressed: ...),
  SizedBox(height: 8),
  FixoGhostButton(label: '...', onPressed: ...)
])
```

**Proposed widget:** `FixoCtaStack`
- Parameters: `primaryLabel`, `onPrimary`, `secondaryLabel`, `onSecondary`, `primaryLoading`

### Pattern 9: Avatar with Status Indicator
**Found in:** chat_widgets, homeowner_dashboard_header, public_profile_screen

**Current:** CircleAvatar or circular Container with status dot overlay.

**Proposed widget:** `FixoAvatar`
- Parameters: `image_url` / `initials`, `size` (sm/md/lg/xl), `statusDot` (optional)

### Pattern 10: Copy Button
**Found in:** payment_screen (`_CopyButton`), settings_screen

**Proposed widget:** `FixoCopyButton`
- Parameters: `label`, `value`, `iconSize`

---

## Proposed Token Additions

### New spacing tokens
```dart
abstract class Space {
  static const double s0_5 = 2.0;
  static const double s1_5 = 6.0;
  // ... existing tokens
}
```

### New radii tokens
```dart
abstract class Radii {
  static const double micro = 2.0;    // progress bars, tiny elements
  static const double small = 10.0;   // small chips, inner elements
  static const double medium = 12.0;  // intermediate radius
  // ... existing tokens
}
```

### Font weight tokens
```dart
abstract class FW {
  FW._();
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;
}
```

### Duration tokens
```dart
abstract class Durations {
  Durations._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration splash = Duration(milliseconds: 2800);
}
```

### Letter spacing tokens
```dart
abstract class Tracking {
  Tracking._();
  static const double tight = -0.02;   // multiply by fontSize
  static const double tightSm = -0.01; // small text
  static const double normal = 0.0;
  static const double wide = 0.2;     // labels, badges
  static const double wider = 0.5;    // uppercase chips
  static const double widest = 0.8;   // onboarding emphasis
}
```

### Alpha / opacity tokens
```dart
abstract class Alpha {
  Alpha._();
  static const double overlay = 0.05;
  static const double tint = 0.08;
  static const double tintStandard = 0.12;
  static const double tintAccent = 0.15;
  static const double border = 0.25;
  static const double borderStrong = 0.35;
  static const double textOnGradient = 0.75;
  static const double iconOnGradient = 0.65;
  static const double navBar = 0.92;
}
```

### Missing font size tokens
```dart
// Add to DesignTokens or new TypeScale class:
static const double fontSizeSm = 14.0;     // between secondary and body
static const double fontSizeH2Small = 18.0; // between H3 and H2
static const double fontSizeAmountLg = 36.0; // large hero amounts
```

### Shadow tokens
```dart
// Add to THColors or new ShadowTokens class:
List<BoxShadow> get navBarShadow => [
  BoxShadow(color: DesignTokens.shadowCard, blurRadius: 16, offset: Offset(0, -4)),
];
List<BoxShadow> get cardElevatedShadow => [
  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2), spreadRadius: -2),
];
```

### Page padding preset
```dart
abstract class FixoPadding {
  FixoPadding._();
  static const EdgeInsets page = EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s6);
  static const EdgeInsets pageTop = EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s4);
  static const EdgeInsets card = EdgeInsets.all(Space.s5);
  static const EdgeInsets section = EdgeInsets.symmetric(horizontal: Space.gutter);
}
```

---

## Recommended Implementation Order

### Phase 1: Token gaps (low risk, high impact)
1. Add missing `Space.s0_5` and `Space.s1_5`
2. Add `Radii.micro`, `Radii.small`, `Radii.medium`
3. Add `FW` weight tokens
4. Add `Durations` tokens
5. Add `Tracking` letter spacing tokens
6. Add `Alpha` opacity tokens
7. Add missing font size tokens (`fontSizeSm`, `fontSizeH2Small`, `fontSizeAmountLg`)
8. Add `FixoPadding` presets
9. Add shadow variants to `THColors`

### Phase 2: High-frequency replacements (mechanical, large count reductions)
1. Replace 357 `SizedBox(height/width: N)` with `SizedBox(height/width: Space.sX)`
2. Replace 241 raw `EdgeInsets` with `Space.*` or `FixoPadding.*`
3. Replace 164 raw `fontSize: N` with `DesignTokens.fontSize*`
4. Replace 199 `FontWeight.wXXX` with `FW.*`

### Phase 3: Color cleanup
1. Replace 122 hardcoded `Color(0x...)` with `THColors` / `DesignTokens` references
2. Replace 133 `Colors.*` with theme-aware tokens
3. Replace 124 `withValues(alpha: 0.xx)` with `Alpha.*` tokens

### Phase 4: Extract reusable widgets
1. `FixoInfoBanner` — tinted notice card (8+ instances)
2. `FixoPillChip` — status/urgency pill (6+ instances)
3. `FixoSectionLabel` — label with count badge (3+ instances)
4. `FixoStepRow` — numbered instruction row (5+ instances)
5. `FixoSummaryRow` — label + value row (8+ instances)
6. `FixoProgressBar` — labeled progress bar (5+ instances)
7. `FixoCtaStack` — primary + ghost button column (6+ instances)
8. `FixoAvatar` — avatar with status dot (4+ instances)
9. `FixoCopyButton` — labeled copy control (3+ instances)
10. `FixoHeroHeader` — gradient hero section (3+ instances)

### Phase 5: Remaining cleanup
1. Replace 31 raw `BorderRadius.circular(N)` with `Radii.*`
2. Replace 19 raw `Duration(milliseconds:)` with `Durations.*`
3. Replace 13 raw `letterSpacing` with `Tracking.*`
4. Replace 16 inline `BoxShadow` with shadow tokens
5. Replace 78 inline `fontFamily: DesignTokens.*` with `Theme.of(context).textTheme` styles
