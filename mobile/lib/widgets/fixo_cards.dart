import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Semantic status badge kinds for the v1.6 status system.
///
/// Each variant defines distinct fill, text, and icon semantics:
/// - [actionNeeded]: Solid orange fill, dark text, `!` circle icon.
/// - [active]: Solid navy fill, white text, play/arrow icon.
/// - [waiting]: Navy tint 15%, navy text, clock icon.
/// - [done]: Green tint 15%, green text, checkmark icon.
/// - [cancelled]: Grey tint 15%, grey text, x icon.
/// - [problem]: Red tint 15%, red text, alert triangle icon.
enum FixoBadgeKind {
  actionNeeded,
  active,
  waiting,
  done,
  cancelled,
  problem,

  // Legacy aliases
  @Deprecated('Use done')
  verified,
  @Deprecated('Use active')
  live,
  @Deprecated('Use waiting or actionNeeded')
  hold,
  @Deprecated('Use problem or actionNeeded')
  urgent,
  @Deprecated('Use cancelled')
  neutral,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final FixoBadgeKind kind;
  final IconData? icon;
  final AlignmentGeometry? alignment;

  const StatusBadge({
    super.key,
    required this.label,
    required this.kind,
    this.icon,
    this.alignment,
  });

  static (Color bg, Color fg, IconData defaultIcon) resolveVisuals(
    FixoBadgeKind kind,
    bool isDark,
  ) {
    switch (kind) {
      case FixoBadgeKind.actionNeeded:
      case FixoBadgeKind.hold:
        return (
          DesignTokens.amber,
          DesignTokens.onAmber,
          Icons.error_outline,
        );
      case FixoBadgeKind.active:
      case FixoBadgeKind.live:
        return (
          isDark ? DesignTokens.brand700 : DesignTokens.brand900,
          Colors.white,
          Icons.play_arrow_rounded,
        );
      case FixoBadgeKind.waiting:
        // Dark mode: 28% tint + white text for legibility on dark surfaces
        // (confirmed HANDOFF.md design decision — not the 12% light-mode value).
        // Light mode: 12% brand tint + brand-900 text.
        return (
          isDark
              ? DesignTokens.brand300.withValues(alpha: Alpha.borderDark)
              : DesignTokens.brand900.withValues(alpha: Alpha.tintStandard),
          isDark ? Colors.white : DesignTokens.brand900,
          Icons.schedule_rounded,
        );
      case FixoBadgeKind.done:
      case FixoBadgeKind.verified:
        return (
          DesignTokens.green.withValues(alpha: Alpha.tintStandard),
          DesignTokens.inkSuccess(isDark),
          Icons.check_rounded,
        );
      case FixoBadgeKind.cancelled:
      case FixoBadgeKind.neutral:
        return (
          DesignTokens.inkSoft(isDark).withValues(alpha: Alpha.tintStandard),
          DesignTokens.inkSoft(isDark),
          Icons.close_rounded,
        );
      case FixoBadgeKind.problem:
      case FixoBadgeKind.urgent:
        return (
          DesignTokens.red.withValues(alpha: Alpha.tintStandard),
          DesignTokens.inkDanger(isDark),
          Icons.warning_amber_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, defaultIcon) = resolveVisuals(kind, isDark);
    final badgeIcon = icon ?? defaultIcon;

    final badge = Container(
      constraints: const BoxConstraints(minHeight: 28, maxHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: Space.s2_5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(badgeIcon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: DesignTokens.fontBody,
                fontSize: DesignTokens.fontSizeStatus,
                fontWeight: FW.semibold,
                color: fg,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: alignment ?? Alignment.centerLeft,
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: badge,
    );
  }
}

/// 6-segment job stepper.
/// Stages (0..5): Requested → Payment → Booked → In Progress → Confirm → Completed.
class JobStepper extends StatelessWidget {
  /// 0-based index of the active stage (0..5).
  final int activeStage;

  const JobStepper({super.key, required this.activeStage});

  static const _labels = [
    'Requested',
    'Payment',
    'Booked',
    'In Progress',
    'Confirm',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = isDark
        ? DesignTokens.paperLineDark
        : DesignTokens.paperLineLight;
    // Spec: done = brand-700, active = amber, upcoming = track.
    return Row(
      children: List.generate(6, (i) {
        final done = i < activeStage;
        final active = i == activeStage;
        final dotColor = done
            ? DesignTokens.brand700
            : active
            ? DesignTokens.amber
            : track;
        // Left connector is filled when this dot is active or done.
        // For i==0 there is nothing to the left visually, but we still
        // fill it so the bar starts coloured rather than dead-grey.
        final leftFilled = i <= activeStage;
        final rightDone = i < activeStage;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: leftFilled ? DesignTokens.brand700 : track,
                    ),
                  ),
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
                      color: rightDone ? DesignTokens.brand700 : track,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s1),
              Text(
                _labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeCaption,
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
    this.padding = const EdgeInsets.all(DesignTokens.cardPadding),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(DesignTokens.radiusCard);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: DesignTokens.borderCard(isDark)),
        boxShadow: DesignTokens.cardShadow(isDark),
      ),
      child: Material(
        color: DesignTokens.surfaceCard(isDark),
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
