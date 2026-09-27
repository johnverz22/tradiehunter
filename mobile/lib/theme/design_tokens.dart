/// Design tokens for the Fixo design system.
///
/// Source of truth: `docs/design/design-system.html`.
/// Never hardcode raw hex values in view files — use these tokens.
library;

import 'package:flutter/material.dart';

/// Central definition of every design-system token.
///
/// Brand colors are derived from [hue] so the entire palette updates
/// when the white-label knob changes.
class DesignTokens {
  DesignTokens._();

  // ── Brand hue (white-label knob) ──────────────────
  static const double hue = 209.0;

  // ── Brand palette ─────────────────────────────────
  static Color get brand900 =>
      HSLColor.fromAHSL(1.0, hue, 0.55, 0.22).toColor();
  static Color get brand700 =>
      HSLColor.fromAHSL(1.0, hue, 0.50, 0.32).toColor();
  static Color get brand500 =>
      HSLColor.fromAHSL(1.0, hue, 0.48, 0.45).toColor();
  static Color get brand300 =>
      HSLColor.fromAHSL(1.0, hue, 0.45, 0.68).toColor();

  // Brand-100 varies by theme
  static Color get brand100Light =>
      HSLColor.fromAHSL(1.0, hue, 0.45, 0.92).toColor();
  static Color get brand100Dark =>
      HSLColor.fromAHSL(1.0, hue, 0.35, 0.16).toColor();

  // ── Semantic colors ───────────────────────────────
  static const Color amber = Color(0xFFE38B29);
  static const Color amberDark = Color(0xFFB96A18);
  static const Color green = Color(0xFF3A7D5C);
  static const Color red = Color(0xFFB23A2E);

  // ── Light theme neutrals ──────────────────────────
  static const Color paperLight = Color(0xFFF6F4EE);
  static const Color paperLineLight = Color(0xFFE4E0D4);
  static const Color inkLight = Color(0xFF1D2226);
  static const Color inkSoftLight = Color(0xFF5B6570);

  // ── Dark theme neutrals ───────────────────────────
  static const Color paperDark = Color(0xFF14181B);
  static const Color paperLineDark = Color(0xFF262C30);
  static const Color inkDark = Color(0xFFECEAE3);
  static const Color inkSoftDark = Color(0xFF9AA4AC);

  /// Elevated card surface in dark mode — slightly lighter than [paperDark]
  /// so cards read as raised. Replaces hardcoded `0xFF1E2328` in views.
  static const Color cardDark = Color(0xFF1E2328);

  /// Primary CTA foreground (dark ink on amber).
  static const Color onAmber = Color(0xFF241300);

  // ── Border radius ─────────────────────────────────
  static const double radius = 4.0;

  // ── Typography ────────────────────────────────────
  static const String fontDisplay = 'Space Grotesk';
  static const String fontBody = 'IBM Plex Sans';
  static const String fontMono = 'IBM Plex Mono';

  // ── Type scale (from design-system.html) ──────────
  static const double fontSizeDisplay = 44.0;
  static const double fontSizeH2 = 24.0;
  static const double fontSizeH3 = 16.0;
  static const double fontSizeBody = 15.0;
  static const double fontSizeMono = 13.0;

  // ── Spacing scale (4px base unit) ─────────────────
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;
  static const double space12 = 48.0;
}
