// Shared tinted feedback surfaces — extracted per mobile/HARDCODED_AUDIT.md
// Phase 4. View-only: no ViewModel or repository dependencies.

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Semantic tone for tinted feedback surfaces (banners, pill chips).
enum FixoTone { brand, accent, danger, success, neutral }

extension on FixoTone {
  /// Hue used for background tints, borders and icons.
  Color fill(bool isDark) => switch (this) {
        FixoTone.brand =>
          isDark ? DesignTokens.brand300 : DesignTokens.brand500,
        FixoTone.accent => DesignTokens.amber,
        FixoTone.danger => DesignTokens.red,
        FixoTone.success => DesignTokens.green,
        FixoTone.neutral => DesignTokens.inkSoft(isDark),
      };

  /// Foreground for text/icons sitting on the tint.
  Color ink(bool isDark) => switch (this) {
        FixoTone.brand => DesignTokens.foregroundBrand(isDark),
        FixoTone.accent => DesignTokens.inkAccent(isDark),
        FixoTone.danger => DesignTokens.inkDanger(isDark),
        FixoTone.success => DesignTokens.inkSuccess(isDark),
        FixoTone.neutral => DesignTokens.inkSoft(isDark),
      };
}

/// Tinted notice card — icon + message (or title + body) on a soft tinted
/// surface with a matching border. Replaces the repeated
/// `Container( tint bg, tile radius, tint border, Row[icon, text] )` pattern
/// found across dashboards, payment, dispute and cancellation flows.
class FixoInfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final FixoTone tone;

  /// Explicit fill+ink colour — overrides [tone] for callers that already
  /// resolved a semantic colour (e.g. `inkSuccess`, `foregroundBrand`).
  final Color? color;

  /// Optional bold heading above [message].
  final String? title;

  /// Optional trailing widget rendered under the body — use for actions
  /// (e.g. a retry button or a link).
  final Widget? action;

  /// Caption-sized body for legal/disclaimer text.
  final bool compact;

  const FixoInfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = FixoTone.brand,
    this.title,
    this.action,
    this.compact = false,
    this.color,
  });

  /// Danger-tone shorthand for error surfaces.
  const FixoInfoBanner.error({
    super.key,
    required this.message,
    this.action,
    this.compact = false,
  })  : icon = Icons.error_outline_rounded,
        tone = FixoTone.danger,
        title = null,
        color = null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = color ?? tone.fill(isDark);
    final ink = color ?? tone.ink(isDark);

    final body = title != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title!,
                style: TextStyle(
                  fontFamily: DesignTokens.fontDisplay,
                  fontWeight: FW.bold,
                  fontSize: DesignTokens.fontSizeBody,
                  color: isDark ? DesignTokens.inkDark : DesignTokens.brand900,
                ),
              ),
              const SizedBox(height: Space.s1),
              Text(
                message,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSecondary,
                  color: DesignTokens.inkSoft(isDark),
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: Space.s2_5),
                action!,
              ],
            ],
          )
        : Text(
            message,
            style: TextStyle(
              fontSize: compact
                  ? DesignTokens.fontSizeCaption
                  : DesignTokens.fontSizeSecondary,
              height: compact ? 1.45 : null,
              color: compact ? DesignTokens.inkSoft(isDark) : ink,
              fontWeight: compact ? FW.regular : FW.medium,
            ),
          );

    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: Alpha.tint),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: fill.withValues(alpha: Alpha.borderMid)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ink),
          const SizedBox(width: Space.s2_5),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Pill-shaped status chip — icon or dot + label on a soft tinted surface.
/// Covers `_TrustChip`, `_StatusPill`, `_UrgentChip` and `_Chip` variants.
class FixoPillChip extends StatelessWidget {
  final String label;
  final Color color;

  /// Leading icon at 14px. Mutually exclusive with [showDot].
  final IconData? icon;

  /// Leading 6px status dot (urgency/live indicators).
  final bool showDot;

  /// Uppercase + wide tracking for emphasis chips.
  final bool uppercase;

  /// False removes the border (flat tint chip).
  final bool bordered;

  /// Text/icon colour override — defaults to [color]. Use for amber chips
  /// where readable text needs `accentText` rather than the raw amber fill.
  final Color? textColor;

  const FixoPillChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showDot = false,
    this.uppercase = false,
    this.bordered = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.s2_5, vertical: Space.s1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: Alpha.tintStandard),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: bordered
            ? Border.all(color: color.withValues(alpha: Alpha.borderMid))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            )
          else if (icon != null)
            Icon(icon, size: 14, color: fg),
          if (showDot || icon != null)
            const SizedBox(width: Space.s1_5),
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                fontWeight: uppercase ? FW.bold : FW.semibold,
                letterSpacing: uppercase ? Tracking.wider : null,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header — small muted label with optional amber count badge and
/// optional helper line. Covers `_sectionLabel`, `_SectionLabel` and
/// `_GroupLabel` variants.
class FixoSectionLabel extends StatelessWidget {
  final String label;
  final int? count;
  final String? helper;
  final bool uppercase;

  const FixoSectionLabel({
    super.key,
    required this.label,
    this.count,
    this.helper,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            uppercase ? label.toUpperCase() : label,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeCaption,
              fontWeight: FW.semibold,
              letterSpacing: Tracking.wide,
              color: th.textSoft,
            ),
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: Space.s1_5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: DesignTokens.amber.withValues(alpha: Alpha.tintAccent),
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: DesignTokens.amber.withValues(alpha: Alpha.borderMid),
              ),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeTiny,
                fontWeight: FW.bold,
                color: th.accentText,
              ),
            ),
          ),
        ],
      ],
    );

    if (helper == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: Space.s1),
        Text(
          helper!,
          style: TextStyle(
              fontSize: DesignTokens.fontSizeCaption, color: th.textSoft),
        ),
      ],
    );
  }
}
