// v1.7 design tokens — mirrors docs/design/v1.6/html/kit.css.
//
// Use via Theme.of(context).extension<THColors>()! for colours.
// Use Space, Radii, Sizes for layout constants.
//
// Source of truth: docs/design/v1.6/html/kit.css and
//                  docs/design/v1.6/tokens/design_tokens.dart
library;

import 'package:flutter/material.dart';

// ── Spacing (4pt scale) ─────────────────────────────────────────────────────

abstract class Space {
  Space._();

  static const double s0_5 = 2.0;
  static const double s1 = 4.0;
  static const double s1_5 = 6.0;
  static const double s2 = 8.0;
  static const double s2_5 = 10.0;
  static const double s3 = 12.0;
  static const double s4 = 16.0;
  static const double s5 = 20.0;
  static const double s6 = 24.0;
  static const double s7 = 32.0;
  static const double s8 = 40.0;
  static const double s9 = 48.0;
  static const double gutter = 20.0;

  /// Bottom padding so list content clears the floating bottom nav bar.
  static const double navClearance = 120.0;

  /// Bottom spacer so content clears a [StickyActionBar].
  static const double stickyBarClearance = 80.0;
}

// ── Border radius ───────────────────────────────────────────────────────────

abstract class Radii {
  Radii._();

  static const double micro = 2.0;    // progress bars, tiny elements
  static const double small = 10.0;   // small chips, inner elements
  static const double medium = 12.0;  // intermediate radius
  static const double control = 14.0;
  static const double tile = 16.0;
  static const double card = 20.0;
  static const double sheet = 28.0;
  static const double pill = 999.0;
}

// ── Component sizes ─────────────────────────────────────────────────────────

abstract class Sizes {
  Sizes._();

  static const double tapMin = 48.0;
  static const double button = 56.0;
  static const double buttonSecondary = 52.0;
  static const double input = 56.0;
  static const double chipVisual = 40.0;
  static const double iconSm = 18.0;
  static const double iconMd = 22.0;
  static const double segmentMin = 80.0;
  static const double dot = 10.0;
  static const double dotActive = 32.0;
  static const double nav = 68.0;
  static const double appBar = 56.0;
  static const double fab = 56.0;
  static const double switchW = 52.0;
  static const double switchH = 32.0;

  /// Pill status button (Online/Offline) — min height 44dp, satisfies 48dp
  /// tap target via internal padding.
  static const double statusButton = 44.0;

  /// Animated presence dot in the status button — drawn at 8dp.
  static const double heroDot = 8.0;

  /// Status chip height (used in job cards and job detail).
  static const double statusChip = 26.0;

  // Avatar sizes
  static const double avatarSm = 36.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 72.0;
  static const double avatarXl = 88.0;
}

// ── Typography ──────────────────────────────────────────────────────────────

abstract class TypeTokens {
  TypeTokens._();

  static const String fontDisplay = 'Space Grotesk';
  static const String fontBody = 'IBM Plex Sans';
  static const String fontMono = 'IBM Plex Mono';
}

// ── Font weights ────────────────────────────────────────────────────────────

abstract class FW {
  FW._();

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;
}

// ── Durations ───────────────────────────────────────────────────────────────

abstract class FixoDurations {
  FixoDurations._();

  static const Duration fast = Duration(milliseconds: 150);            // button press
  static const Duration toggle = Duration(milliseconds: 200);         // switch toggle
  static const Duration pageTransition = Duration(milliseconds: 220);
  static const Duration onboardingDot = Duration(milliseconds: 250);
  static const Duration onboardingSlide = Duration(milliseconds: 280);
  static const Duration expand           = Duration(milliseconds: 300);  // expand/collapse sections
  static const Duration debounce = Duration(milliseconds: 300);
  static const Duration addressDebounce = Duration(milliseconds: 400);
  static const Duration splashRing = Duration(milliseconds: 600);
  static const Duration sheetDelay = Duration(milliseconds: 800);      // rating sheet
  /// Online dot pulse — one full pulsation cycle. Respect reduce-motion.
  static const Duration pulse = Duration(milliseconds: 900);
  static const Duration sheetDelayLong = Duration(milliseconds: 1000); // schedule sheet
  static const Duration splashRingLate = Duration(milliseconds: 1200);
  static const Duration splash = Duration(milliseconds: 2800);
}

// ── Letter spacing (tracking) ───────────────────────────────────────────────

abstract class Tracking {
  Tracking._();

  static const double tight = -0.02;   // multiply by font size — display headings
  static const double tightSm = -0.01; // multiply by font size — small text
  static const double normal = 0.0;
  static const double wide = 0.2;      // section labels, badges
  static const double emphasis = 0.4;  // dashboard header
  static const double wider = 0.5;     // uppercase chips
  static const double widest = 0.8;    // onboarding emphasis
}

// ── Alpha / opacity tints ───────────────────────────────────────────────────

abstract class Alpha {
  Alpha._();

  static const double subtle = 0.04;
  static const double overlay = 0.05;
  static const double wash = 0.06;               // subtle card gradient stop
  static const double faint = 0.07;              // info banner background
  static const double tint = 0.08;               // tinted icon background
  static const double tintLight = 0.10;          // light danger/success tint
  static const double tintStandard = 0.12;       // standard tint — most common
  static const double tintMid = 0.13;
  static const double tintSoft = 0.14;
  static const double tintAccent = 0.15;         // accent/amber tint
  static const double tintStrong = 0.16;         // green tint (profile)
  static const double gradient = 0.18;           // brand gradient stop
  static const double tintDark = 0.20;           // dark mode brand tint
  static const double border = 0.25;             // border emphasis
  static const double borderDark = 0.28;         // dark mode status tint
  static const double borderMid = 0.30;          // border/divider emphasis
  static const double borderStrong = 0.35;       // border accent
  static const double ghost = 0.38;              // faint white on dark
  static const double shadow = 0.40;             // shadow/border
  static const double outlineDark = 0.45;        // dark mode outline
  static const double divider = 0.50;            // divider fade
  static const double fillDark = 0.55;           // dark mode progress bar
  static const double iconOnGradientSoft = 0.60;
  static const double iconOnGradient = 0.65;
  static const double iconOnGradientStrong = 0.70;
  static const double textOnGradient = 0.75;
  static const double textOnGradientStrong = 0.80;
  static const double scrim = 0.85;
  static const double navBarStrong = 0.90;
  static const double navBar = 0.92;
}

// ── Padding presets ─────────────────────────────────────────────────────────

abstract class FixoPadding {
  FixoPadding._();

  /// Standard page padding — 24px sides, 16 top, 24 bottom.
  static const EdgeInsets page =
      EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s6);

  /// Page padding with reduced bottom — content continues below.
  static const EdgeInsets pageTop =
      EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s4);

  /// Standard card interior padding.
  static const EdgeInsets card = EdgeInsets.all(Space.s5);

  /// Section horizontal padding aligned to the page gutter.
  static const EdgeInsets section =
      EdgeInsets.symmetric(horizontal: Space.gutter);
}

// ── Third-party brand colours ───────────────────────────────────────────────

abstract class SocialColors {
  SocialColors._();

  static const Color googleBlue = Color(0xFF4285F4);
}

// ── Colour theme extension ───────────────────────────────────────────────────
//
// Three named instances:
//   THColors.light   — default, cream background
//   THColors.dark    — navy-black background
//   THColors.outdoor — light values but flat: no blur/glass, outline elevation,
//                      textSoft #46505A for extra legibility in bright conditions

@immutable
class THColors extends ThemeExtension<THColors> {
  const THColors({
    required this.paper,
    required this.surface,
    required this.text,
    required this.textSoft,
    required this.textBrand,
    required this.brand,
    required this.onBrand,
    required this.accent,
    required this.accentText,
    required this.line,
    required this.tintBrand,
    required this.track,
    required this.danger,
    required this.success,
  });

  final Color paper;      // screen/page background
  final Color surface;    // card/sheet surface
  final Color text;       // primary text
  final Color textSoft;   // secondary/muted text
  final Color textBrand;  // brand-coloured headings and labels
  final Color brand;      // structural brand colour (navy light / blue300 dark)
  final Color onBrand;    // text/icons on brand fills
  final Color accent;     // amber — ONE primary CTA per screen only
  final Color accentText; // text on light backgrounds referring to accent (#8F4F08 light / amber dark)
  final Color line;       // dividers and borders
  final Color tintBrand;  // brand tint fill for pills, tonal buttons
  final Color track;      // progress bar track, inactive segment
  final Color danger;     // error / disputed
  final Color success;    // verified / done

  // ── Light theme ───────────────────────────────────────────────────────────

  static const light = THColors(
    paper:      Color(0xFFF6F4EE),
    surface:    Color(0xFFFFFFFF),
    text:       Color(0xFF14181B),
    textSoft:   Color(0xFF5B6570),
    textBrand:  Color(0xFF193957),
    brand:      Color(0xFF193957),
    onBrand:    Color(0xFFFFFFFF),
    accent:     Color(0xFFE38B29),
    accentText: Color(0xFF8F4F08),
    line:       Color(0xFFE4E0D4),
    tintBrand:  Color(0x1F3C75AA), // blue at 12%
    track:      Color(0x1F193957), // navy at 12%
    danger:     Color(0xFFB23A2E),
    success:    Color(0xFF3A7D5C),
  );

  // ── Dark theme ────────────────────────────────────────────────────────────

  static const dark = THColors(
    paper:      Color(0xFF14181B),
    surface:    Color(0xFF1E2328),
    text:       Color(0xFFECEAE3),
    textSoft:   Color(0xFF9AA4AC),
    textBrand:  Color(0xFF89AFD2),
    brand:      Color(0xFF89AFD2), // blue300 — lighter for dark surfaces
    onBrand:    Color(0xFF193957),
    accent:     Color(0xFFE38B29),
    accentText: Color(0xFFE38B29), // amber is its own contrast on dark
    line:       Color(0x1FFFFFFF), // white 12%
    tintBrand:  Color(0x333C75AA), // blue at 20%
    track:      Color(0x24FFFFFF), // white 14%
    danger:     Color(0xFFE8968E),
    success:    Color(0xFF8FC9A8),
  );

  // ── Outdoor / high-contrast variant ───────────────────────────────────────
  // Same hues as light; glass/gradients replaced with flat surfaces and 1px outlines.

  static const outdoor = THColors(
    paper:      Color(0xFFF6F4EE),
    surface:    Color(0xFFFFFFFF),
    text:       Color(0xFF14181B),
    textSoft:   Color(0xFF46505A), // darker than light for extra outdoor legibility
    textBrand:  Color(0xFF193957),
    brand:      Color(0xFF193957),
    onBrand:    Color(0xFFFFFFFF),
    accent:     Color(0xFFE38B29),
    accentText: Color(0xFF8F4F08),
    line:       Color(0x47193957), // navy 28% — visible outlines replace shadows
    tintBrand:  Color(0x1F3C75AA),
    track:      Color(0x1F193957),
    danger:     Color(0xFFB23A2E),
    success:    Color(0xFF3A7D5C),
  );

  // ── ThemeExtension boilerplate ────────────────────────────────────────────

  @override
  THColors copyWith({
    Color? paper, Color? surface, Color? text, Color? textSoft, Color? textBrand,
    Color? brand, Color? onBrand, Color? accent, Color? accentText, Color? line,
    Color? tintBrand, Color? track, Color? danger, Color? success,
  }) {
    return THColors(
      paper:      paper      ?? this.paper,
      surface:    surface    ?? this.surface,
      text:       text       ?? this.text,
      textSoft:   textSoft   ?? this.textSoft,
      textBrand:  textBrand  ?? this.textBrand,
      brand:      brand      ?? this.brand,
      onBrand:    onBrand    ?? this.onBrand,
      accent:     accent     ?? this.accent,
      accentText: accentText ?? this.accentText,
      line:       line       ?? this.line,
      tintBrand:  tintBrand  ?? this.tintBrand,
      track:      track      ?? this.track,
      danger:     danger     ?? this.danger,
      success:    success    ?? this.success,
    );
  }

  @override
  THColors lerp(ThemeExtension<THColors>? other, double t) {
    if (other is! THColors) return this;
    return THColors(
      paper:      Color.lerp(paper,      other.paper,      t)!,
      surface:    Color.lerp(surface,    other.surface,    t)!,
      text:       Color.lerp(text,       other.text,       t)!,
      textSoft:   Color.lerp(textSoft,   other.textSoft,   t)!,
      textBrand:  Color.lerp(textBrand,  other.textBrand,  t)!,
      brand:      Color.lerp(brand,      other.brand,      t)!,
      onBrand:    Color.lerp(onBrand,    other.onBrand,    t)!,
      accent:     Color.lerp(accent,     other.accent,     t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      line:       Color.lerp(line,       other.line,       t)!,
      tintBrand:  Color.lerp(tintBrand,  other.tintBrand,  t)!,
      track:      Color.lerp(track,      other.track,      t)!,
      danger:     Color.lerp(danger,     other.danger,     t)!,
      success:    Color.lerp(success,    other.success,    t)!,
    );
  }

  // ── Convenience helpers ───────────────────────────────────────────────────

  /// Card elevation — box shadow for light; none for dark (use border instead).
  List<BoxShadow> get cardShadow => surface == const Color(0xFF1E2328)
      ? const []
      : const [
          BoxShadow(color: Color(0x0F193957), blurRadius: 2,  offset: Offset(0, 1)),
          BoxShadow(color: Color(0x14193957), blurRadius: 24, offset: Offset(0, 8)),
        ];

  /// CTA button shadow — amber glow.
  List<BoxShadow> get ctaShadow => const [
    BoxShadow(color: Color(0x40E38B29), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Bottom navigation bar shadow — lifts the bar off scrolled content.
  /// Dark theme uses a top border instead of elevation.
  List<BoxShadow> get navBarShadow => surface == const Color(0xFF1E2328)
      ? const []
      : const [
          BoxShadow(
            color: DesignTokens.shadowCard,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ];

  /// Elevated card shadow for floating elements above content.
  List<BoxShadow> get cardElevatedShadow => surface == const Color(0xFF1E2328)
      ? const []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: Alpha.subtle),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ];
}

// ── DesignTokens compatibility shim ─────────────────────────────────────────
//
// The codebase uses the legacy `DesignTokens.*` static API.
// This shim maps every old member to the canonical v1.6 token values so
// existing code compiles without change during the v1.6 migration.
//
// Do NOT add new code using DesignTokens.*; use THColors/Space/Radii/Sizes
// directly in any new or substantially-rewritten widgets.

abstract class DesignTokens {
  DesignTokens._();

  // ── Brand palette ────────────────────────────────────────────────────────
  static const double hue = 209.0;

  static const Color brand100Light = Color(0xFFD9E8F5);
  static const Color brand100Dark  = Color(0xFF1A2A38);
  static const Color brand300      = Color(0xFF89AFD2);
  static const Color brand500      = Color(0xFF3C75AA);
  static const Color brand700      = Color(0xFF1F4E7E);
  static const Color brand900      = Color(0xFF193957);

  static const Color amber     = Color(0xFFE38B29);
  static const Color amberDark = Color(0xFFE38B29); // same amber, referenced by dark-mode callers
  static const Color onAmber   = Color(0xFF3D1F00);

  static const Color green = Color(0xFF3A7D5C);
  static const Color red   = Color(0xFFB23A2E);

  // ── Backgrounds ─────────────────────────────────────────────────────────
  static const Color paperLight = Color(0xFFF6F4EE);
  static const Color paperDark  = Color(0xFF14181B);
  static const Color cardDark   = Color(0xFF1E2328);

  static const Color paperLineLight = Color(0xFFE4E0D4);
  static const Color paperLineDark  = Color(0x1FFFFFFF); // white 12%

  static const Color shadowCard = Color(0x14193957);

  static Color paperLine(bool isDark) => isDark ? paperLineDark : paperLineLight;

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static Color surfaceCard(bool isDark)     => isDark ? cardDark : Colors.white;
  static Color surfaceDisabled(bool isDark) =>
      // Light: warm cream-grey. Dark: pre-composited white@10% over #14181B=(20,24,27) → (44,47,50)
      isDark ? const Color(0xFF2C2F32) : const Color(0xFFE8E4DC);
  static Color surfaceTonal(bool isDark)    =>
      isDark ? brand300.withValues(alpha: Alpha.tintDark) : brand500.withValues(alpha: Alpha.tintLight);
  static Color surfaceStatus(bool isDark)   =>
      // Light: brand100Light. Dark: pre-composited brand300@28% over #14181B=(20,24,27) → (53,66,78)
      isDark ? const Color(0xFF35424E) : brand100Light;

  // ── Ink (text/icon) ───────────────────────────────────────────────────────
  static const Color inkLight    = Color(0xFF14181B);
  static const Color inkDark     = Color(0xFFECEAE3);
  static const Color inkSoftLight = Color(0xFF5B6570);
  static const Color inkSoftDark  = Color(0xFF9AA4AC);

  static Color inkSoft(bool isDark)    => isDark ? inkSoftDark : inkSoftLight;
  static Color inkAccent(bool isDark)  => isDark ? amber : const Color(0xFF8F4F08);
  static Color inkDanger(bool isDark)  =>
      isDark ? const Color(0xFFE8968E) : const Color(0xFF9B2B21);
  static Color inkSuccess(bool isDark) =>
      isDark ? const Color(0xFF8FC9A8) : const Color(0xFF1A4D33);

  // ── Foreground helpers ────────────────────────────────────────────────────
  static Color foreground(bool isDark)         => isDark ? inkDark : inkLight;
  static Color foregroundBrand(bool isDark)    => isDark ? brand300 : brand900;
  static Color foregroundTonal(bool isDark)    => isDark ? brand300 : brand700;
  static Color foregroundDisabled(bool isDark) =>
      // Light: warm mid-grey #6B6560 (6.0:1 on #E8E4DC disabled surface).
      // Dark: pre-composited white@55% over #14181B=(20,24,27) → (149,151,152).
      isDark ? const Color(0xFF959798) : const Color(0xFF6B6560);
  // foregroundStatus: white on dark tinted surface (28% tint); brand900 on light tint.
  static Color foregroundStatus(bool isDark)   => isDark ? Colors.white : brand900;

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color focus = Color(0xFF3C75AA);

  static Color borderCard(bool isDark)    => isDark ? paperLineDark : paperLineLight;
  // borderControl: visible control outline for inputs, checkboxes, chips.
  // Must meet WCAG 1.4.11 non-text contrast (>=3:1) against adjacent surfaces.
  // Light: #8A8882 warm-grey (4.2:1 on paper, 4.7:1 on white card).
  // Dark: white@45% composited (3.5:1 on card, 3.7:1 on paper).
  static Color borderControl(bool isDark) => isDark
      ? Colors.white.withValues(alpha: Alpha.outlineDark)
      : const Color(0xFF8A8882);
  static double borderWidthFor(bool isDark) => isDark ? 1.0 : 1.0;

  // ── Card shadow ───────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow(bool isDark) => isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x0F193957), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x14193957), blurRadius: 24, offset: Offset(0, 8)),
        ];

  // ── Typography ────────────────────────────────────────────────────────────
  static const String fontDisplay = TypeTokens.fontDisplay;
  static const String fontBody    = TypeTokens.fontBody;
  static const String fontMono    = TypeTokens.fontMono;

  static const double fontSizeDisplay   = 32.0;
  static const double fontSizeH1        = 24.0;
  static const double fontSizeH2        = 20.0;
  static const double fontSizeH2Small   = 18.0;
  static const double fontSizeH3        = 17.0; // was 16; one clear step above new body (16)
  // ── Specialised sizes (not part of the main scale) ──────────────────────
  /// Hero display name in the dashboard header (larger than H1).
  static const double fontSizeNameDisplay    = 28.0;
  /// Avatar initials at medium size (match-result hero).
  static const double fontSizeAvatarInitials = 26.0;
  /// Avatar initials at large size (public profile hero).
  static const double fontSizeAvatarInitialsLg = 28.0;
  /// Sub-amount price display — reference code, compact price hero.
  static const double fontSizeAmountSm       = 22.0;
  /// Splash / wordmark display — one-off, not in the content scale.
  static const double fontSizeSplash         = 40.0;
  // ── Type scale (v1.7) ───────────────────────────────────────────────────────
  // Bumped from v1.6 to improve readability at 1.0×; floor is 12 sp (fontSizeTiny).
  // Line heights: ~1.4 for body, ~1.25 for headings (set in fixo_theme.dart).
  static const double fontSizeBody      = 16.0; // was 15
  static const double fontSizeSm        = 15.0; // was 14
  static const double fontSizeSecondary = 14.0; // was 13
  static const double fontSizeCaption   = 13.0; // was 12
  static const double fontSizeTiny      = 12.0; // was 11 — hard floor, nothing below 12
  static const double fontSizeControl   = 16.0; // was 15; matches new body
  static const double fontSizeStatus    = 13.0; // was 12; chip legibility
  static const double fontSizeAmount    = 24.0; // unchanged
  static const double fontSizeAmountLg  = 36.0; // unchanged
  static const double fontSizeMono      = 13.0; // unchanged — opt-in for reference codes
  static const double fontSizeStep      = 15.0; // status strip "Step X of 4" — unchanged

  // ── Radii ─────────────────────────────────────────────────────────────────
  static const double radius        = 4.0;   // legacy base radius (v1.5 contract)
  static const double radiusCard    = Radii.card;
  static const double radiusControl = Radii.control;
  static const double radiusTile    = Radii.tile;
  static const double radiusSheet   = Radii.sheet;
  static const double radiusPill    = Radii.pill;
  static const double radiusInput   = Radii.control;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double space1 = Space.s1;
  static const double space2 = Space.s2;
  static const double space3 = Space.s3;
  static const double space4 = Space.s4;
  static const double space5 = Space.s5;
  static const double space6 = Space.s6;
  static const double space8 = Space.s8;

  static const double cardPadding = Space.s5; // 20
  static const double cardGap     = Space.s4; // 16
  static const double pageMargin  = Space.gutter; // 20

  // ── Sizes ─────────────────────────────────────────────────────────────────
  static const double targetMinimum   = Sizes.tapMin;
  static const double heightPrimary   = Sizes.button;
  static const double heightSecondary = Sizes.buttonSecondary;
  static const double heightInput     = Sizes.input;
}
