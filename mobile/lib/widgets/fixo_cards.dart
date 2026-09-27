import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Pill badge from mockups 05/08/09/10/12.
/// Green = matched/verified/online, amber = requested/awaiting,
/// red = urgent/cancelled, brand = neutral/info.
enum FixoBadgeKind { verified, live, hold, urgent, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final FixoBadgeKind kind;

  const StatusBadge({super.key, required this.label, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late Color bg;
    late Color fg;
    switch (kind) {
      case FixoBadgeKind.verified:
      case FixoBadgeKind.live:
        bg = DesignTokens.green.withValues(alpha: 0.16);
        fg = DesignTokens.green;
        break;
      case FixoBadgeKind.hold:
        bg = DesignTokens.amber.withValues(alpha: 0.20);
        fg = DesignTokens.amberDark;
        break;
      case FixoBadgeKind.urgent:
        bg = DesignTokens.red.withValues(alpha: 0.12);
        fg = DesignTokens.red;
        break;
      case FixoBadgeKind.neutral:
        bg = isDark ? DesignTokens.brand100Dark : DesignTokens.brand100Light;
        fg = isDark ? DesignTokens.inkDark : DesignTokens.brand900;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: DesignTokens.fontMono,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

/// 4-segment job stepper from mockups 05/11.
/// Stages: Requested → Matched → Confirmed → Complete.
class JobStepper extends StatelessWidget {
  /// 0-based index of the active stage (0..3).
  final int activeStage;

  const JobStepper({super.key, required this.activeStage});

  static const _labels = ['Requested', 'Matched', 'Confirmed', 'Complete'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = isDark ? DesignTokens.paperLineDark : DesignTokens.paperLineLight;
    // Spec: done = brand-700, active = amber, upcoming = track.
    return Row(
      children: List.generate(4, (i) {
        final done = i < activeStage;
        final active = i == activeStage;
        final dotColor = done
            ? DesignTokens.brand700
            : active
                ? DesignTokens.amber
                : track;
        final leftDone = i > 0 && i <= activeStage;
        final rightDone = i < activeStage;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: Container(
                          height: 2,
                          color: leftDone ? DesignTokens.brand700 : track)),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      border: Border.all(color: dotColor, width: 2),
                    ),
                  ),
                  Expanded(
                      child: Container(
                          height: 2,
                          color: rightDone ? DesignTokens.brand700 : track)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  fontFamily: DesignTokens.fontMono,
                  fontSize: 10,
                  color: isDark
                      ? DesignTokens.inkSoftDark
                      : DesignTokens.inkSoftLight,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// White card wrapper used across mockups 05/08/09/12.
class FixoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FixoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(
          color:
              isDark ? DesignTokens.paperLineDark : DesignTokens.paperLineLight,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }
}
