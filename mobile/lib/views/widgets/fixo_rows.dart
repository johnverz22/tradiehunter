// Shared row patterns — extracted per mobile/HARDCODED_AUDIT.md Phase 4.
// View-only: no ViewModel or repository dependencies.

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Numbered instruction row — a tinted circle with a mono step number beside
/// a bold title and arbitrary content (payment transfer steps, onboarding).
class FixoStepRow extends StatelessWidget {
  final int number;
  final String title;
  final Widget child;

  const FixoStepRow({
    super.key,
    required this.number,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignTokens.brand500.withValues(alpha: Alpha.tintStandard),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontFamily: DesignTokens.fontMono,
              fontSize: DesignTokens.fontSizeSm,
              fontWeight: FW.bold,
              color: DesignTokens.foregroundBrand(isDark),
            ),
          ),
        ),
        const SizedBox(width: Space.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: FW.semibold,
                ),
              ),
              const SizedBox(height: Space.s1_5),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// Label + value row for summary cards (payment totals, settings metadata).
/// [emphasize] bumps the value to body size + bold.
class FixoSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const FixoSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeSecondary,
              color: DesignTokens.inkSoft(isDark),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasize
                  ? DesignTokens.fontSizeBody
                  : DesignTokens.fontSizeSm,
              fontWeight: emphasize ? FW.bold : FW.semibold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stacked label-over-value row with an optional trailing [FixoCopyButton]
/// (bank account details, reference codes).
class FixoDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onCopy;

  const FixoDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeCaption,
                  color: DesignTokens.inkSoft(isDark),
                ),
              ),
              const SizedBox(height: Space.s0_5),
              Text(
                value,
                style: TextStyle(
                  fontFamily: mono ? DesignTokens.fontMono : null,
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: FW.semibold,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null) FixoCopyButton(label: label, onTap: onCopy!),
      ],
    );
  }
}

/// Theme-aware list divider (paperLine in both modes).
class FixoListDivider extends StatelessWidget {
  /// Total vertical space the divider occupies — matches [Divider.height].
  final double spacing;

  const FixoListDivider({super.key, this.spacing = 20});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(height: spacing, color: DesignTokens.paperLine(isDark));
  }
}

/// A labelled copy control — an explicit "Copy" action is more discoverable
/// than a bare icon and keeps the 48px touch target the spec asks for.
class FixoCopyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const FixoCopyButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Copy $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints:
              const BoxConstraints(minHeight: Sizes.tapMin, minWidth: Sizes.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: DesignTokens.foregroundBrand(isDark),
              ),
              const SizedBox(width: Space.s1_5),
              Text(
                'Copy',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  fontWeight: FW.semibold,
                  color: DesignTokens.foregroundBrand(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
