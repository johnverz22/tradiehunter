// Shared labeled progress bar — extracted per mobile/HARDCODED_AUDIT.md
// Phase 4. View-only: no ViewModel or repository dependencies.

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// A thin progress bar with an optional trailing label — used for lead
/// countdowns and offer expiry. For the 4-segment job stage indicator use
/// `CompactProgressBar` instead.
class FixoProgressBar extends StatelessWidget {
  /// 0.0–1.0 fill fraction.
  final double progress;
  final String? label;
  final Color? barColor;
  final Color? trackColor;
  final Color? labelColor;
  final double height;

  const FixoProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.barColor,
    this.trackColor,
    this.labelColor,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.micro),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: height,
              backgroundColor:
                  trackColor ?? DesignTokens.paperLine(isDark),
              valueColor: AlwaysStoppedAnimation<Color>(
                  barColor ?? DesignTokens.brand500),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: Space.s2),
          Text(
            label!,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeSecondary,
              fontWeight: FW.semibold,
              color: labelColor ?? DesignTokens.inkSoft(isDark),
            ),
          ),
        ],
      ],
    );
  }
}
