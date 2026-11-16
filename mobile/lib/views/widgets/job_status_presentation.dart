import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/fixo_cards.dart';

// ── Chip tone ─────────────────────────────────────────────────────────────────

/// The tinted visual tone for a [StatusChip].
///
/// Maps to soft-tint bg + readable foreground in both themes.
/// Distinct from [FixoBadgeKind] which governs the legacy solid [StatusBadge].
enum ChipTone {
  neutral,    // Requested, Cancelled, Expired
  info,       // Booked
  brand,      // In progress (amber/brand)
  warning,    // Awaiting confirmation, Payment due
  success,    // Completed
  danger,     // Disputed, Under review
}

extension _ChipToneColors on ChipTone {
  /// Tint hue colour used for background at [Alpha.tintStandard] and border at
  /// [Alpha.borderMid].
  Color fill(bool isDark) => switch (this) {
        ChipTone.neutral  => DesignTokens.inkSoft(isDark),
        ChipTone.info     => isDark ? DesignTokens.brand300 : DesignTokens.brand500,
        ChipTone.brand    => DesignTokens.amber,
        ChipTone.warning  => DesignTokens.amber,
        ChipTone.success  => DesignTokens.green,
        ChipTone.danger   => DesignTokens.red,
      };

  /// Foreground colour for label + icon — must meet 4.5:1 on the tinted bg.
  Color ink(bool isDark) => switch (this) {
        ChipTone.neutral  => DesignTokens.inkSoft(isDark),
        ChipTone.info     => DesignTokens.foregroundBrand(isDark),
        ChipTone.brand    => DesignTokens.inkAccent(isDark),
        ChipTone.warning  => DesignTokens.inkAccent(isDark),
        ChipTone.success  => DesignTokens.inkSuccess(isDark),
        ChipTone.danger   => DesignTokens.inkDanger(isDark),
      };
}

// ── Tinted status chip ────────────────────────────────────────────────────────

/// Compact tinted status chip — icon + label on a soft tinted surface.
///
/// This is the canonical status widget for:
/// - Tradie dashboard Today cards
/// - Jobs list
/// - Job detail (homeowner and tradie)
/// - Homeowner views
///
/// Do NOT use the legacy solid [StatusBadge] for new code. The amber CTA must
/// remain the loudest element; chips use only tinted fills.
class StatusChip extends StatelessWidget {
  final String label;
  final ChipTone tone;
  final IconData icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    required this.icon,
  });

  /// Convenience constructor — resolves tone and icon from a raw status string
  /// via [JobStatusPresentation.forStatus].
  factory StatusChip.forStatus(String status) {
    final p = JobStatusPresentation.forStatus(status);
    return StatusChip(label: p.label, tone: p.chipTone, icon: p.chipIcon);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = tone.fill(isDark);
    final fg   = tone.ink(isDark);

    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: Sizes.statusChip,
          maxHeight: Sizes.statusChip,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s2_5,
          vertical:   Space.s1,
        ),
        decoration: BoxDecoration(
          color:        fill.withValues(alpha: Alpha.tintStandard),
          borderRadius: BorderRadius.circular(Radii.pill),
          border:       Border.all(color: fill.withValues(alpha: Alpha.borderMid)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: Space.s1),
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
      ),
    );
  }
}

// ── Presentation data ─────────────────────────────────────────────────────────

class JobStatusPresentation {
  final String label;

  /// Tinted chip tone — used by [StatusChip].
  final ChipTone chipTone;

  /// Icon for [StatusChip].
  final IconData chipIcon;

  /// Legacy badge kind — still used by the old [StatusBadge] for backward
  /// compatibility in homeowner cards. New code should use [StatusChip].
  final FixoBadgeKind kind;

  final String homeownerAction;
  final String tradieAction;

  /// Whether the tradie must act now for this status.
  final bool tradieActionRequired;

  final int? progressStage;

  /// Legacy (v1 flowVersion) 4-step labels.
  static const progressLabels = ['Requested', 'Booked', 'In progress', 'Done'];

  /// "Step X of 4" — no status text (status shown by the chip).
  String? get progressLabel =>
      progressStage == null ? null : 'Step ${progressStage! + 1} of 4';

  const JobStatusPresentation(
    this.label, {
    this.chipTone = ChipTone.neutral,
    this.chipIcon = Icons.help_outline_rounded,
    this.kind = FixoBadgeKind.cancelled,
    this.homeownerAction = 'Open chat',
    this.tradieAction = 'View request',
    this.tradieActionRequired = false,
    this.progressStage,
  });

  String get tradieDashboardAction =>
      tradieAction == 'View job details' ? tradieAction : 'Open chat';

  static JobStatusPresentation forStatus(String status) =>
      _statuses[status] ?? const JobStatusPresentation('Status unavailable');

  /// ── Status → tone table ────────────────────────────────────────────────
  ///
  /// | Status                 | Tone    | Icon                      |
  /// |------------------------|---------|---------------------------|
  /// | Requested              | neutral | schedule_rounded          |
  /// | AwaitingPayment        | warning | payments_rounded          |
  /// | PaymentReview          | neutral | pending_rounded           |
  /// | Booked                 | info    | event_available_rounded   |
  /// | InProgress             | brand   | build_rounded             |
  /// | AwaitingConfirmation   | warning | pending_actions_rounded   |
  /// | Completed              | success | check_circle_rounded      |
  /// | Cancelled              | neutral | cancel_rounded            |
  /// | Expired                | neutral | timer_off_rounded         |
  /// | Disputed               | danger  | report_rounded            |
  static const _statuses = {
    'Requested': JobStatusPresentation(
      'Requested',
      chipTone: ChipTone.neutral,
      chipIcon: Icons.schedule_rounded,
      progressStage: 0,
      kind: FixoBadgeKind.waiting,
      homeownerAction: 'View matching',
    ),
    'AwaitingPayment': JobStatusPresentation(
      'Payment due',
      chipTone: ChipTone.warning,
      chipIcon: Icons.payments_rounded,
      progressStage: 0,
      kind: FixoBadgeKind.actionNeeded,
      homeownerAction: 'Payment details',
      tradieActionRequired: false, // homeowner must act, not tradie
    ),
    'PaymentReview': JobStatusPresentation(
      'Under review',
      chipTone: ChipTone.neutral,
      chipIcon: Icons.pending_rounded,
      progressStage: 0,
      kind: FixoBadgeKind.waiting,
      homeownerAction: 'View payment status',
    ),
    'Booked': JobStatusPresentation(
      'Booked',
      chipTone: ChipTone.info,
      chipIcon: Icons.event_available_rounded,
      progressStage: 1,
      kind: FixoBadgeKind.active,
      homeownerAction: 'View job details',
      tradieAction: 'Check in',
      tradieActionRequired: true,
    ),
    'InProgress': JobStatusPresentation(
      'In progress',
      chipTone: ChipTone.brand,
      chipIcon: Icons.build_rounded,
      progressStage: 2,
      kind: FixoBadgeKind.active,
      homeownerAction: 'View job details',
      tradieAction: 'Check out',
      tradieActionRequired: true,
    ),
    'AwaitingConfirmation': JobStatusPresentation(
      'Action needed',
      chipTone: ChipTone.warning,
      chipIcon: Icons.pending_actions_rounded,
      progressStage: 2,
      kind: FixoBadgeKind.actionNeeded,
      homeownerAction: 'Review completion',
      tradieAction: 'Mark complete',
      tradieActionRequired: true,
    ),
    'Completed': JobStatusPresentation(
      'Completed',
      chipTone: ChipTone.success,
      chipIcon: Icons.check_circle_rounded,
      progressStage: 3,
      kind: FixoBadgeKind.done,
      homeownerAction: 'View job details',
      tradieAction: 'View job details',
    ),
    'Cancelled': JobStatusPresentation(
      'Cancelled',
      chipTone: ChipTone.neutral,
      chipIcon: Icons.cancel_rounded,
      kind: FixoBadgeKind.cancelled,
      tradieAction: 'View job details',
    ),
    'Expired': JobStatusPresentation(
      'Expired',
      chipTone: ChipTone.neutral,
      chipIcon: Icons.timer_off_rounded,
      kind: FixoBadgeKind.cancelled,
    ),
    'Disputed': JobStatusPresentation(
      'Disputed',
      chipTone: ChipTone.danger,
      chipIcon: Icons.report_rounded,
      kind: FixoBadgeKind.problem,
    ),
  };
}

// ── v1.7 stepper flow (P12-11 / P12-15) ──────────────────────────────────────

/// Resolves the job stepper for a status under the job's flow version.
///
/// v1.7 (contract #6) 6-step order: Requested → Booked → In progress →
/// Review & approve → Pay → Completed. FlowVersion-1 jobs keep the legacy
/// 4-step order (Requested → Booked → In progress → Done) so in-flight v1
/// jobs never show the new steps mid-flight (P12-27 back-compat).
///
/// Every stepper widget (status strip, timeline, dots, compact bar) resolves
/// through this class so the order can never drift between them.
class JobStepperFlow {
  /// Legacy v1 step titles (flowVersion 1).
  static const v1Titles = ['Requested', 'Booked', 'In progress', 'Done'];

  static const v1Subtitles = [
    'Job request submitted',
    'Tradie matched & booked',
    'Work underway on site',
    'Work complete & verified',
  ];

  /// v1.7 v2 step titles (flowVersion 2) — pay last, per spec §7.
  static const v2Titles = [
    'Requested',
    'Booked',
    'In progress',
    'Review & approve',
    'Pay',
    'Completed',
  ];

  static const v2Subtitles = [
    'Job request submitted',
    'Tradie booked your job',
    'Work underway on site',
    'Check the summary & approve',
    'Payment is due',
    'All done — thanks!',
  ];

  final List<String> titles;
  final List<String> subtitles;
  final int totalSteps;

  /// 0-based index of the step matching the current status.
  final int activeIndex;

  /// Cancelled / Expired / Disputed — renders muted, never "complete".
  final bool isTerminal;

  const JobStepperFlow({
    required this.titles,
    required this.subtitles,
    required this.totalSteps,
    required this.activeIndex,
    required this.isTerminal,
  });

  /// Resolves from a raw status string. When [flowVersion] is 1 (or unknown
  /// with no stage) the legacy mapping applies; when the job carries a v2
  /// [stage] (0..5, contract #6) it drives the index directly.
  factory JobStepperFlow.resolve(
    String status, {
    int? stage,
    int? flowVersion,
  }) {
    final terminal = switch (status) {
      'Cancelled' || 'Expired' || 'Disputed' => true,
      _ => false,
    };
    final isV1 = flowVersion != null && flowVersion < 2 && stage == null;
    if (isV1) {
      return JobStepperFlow(
        titles: v1Titles,
        subtitles: v1Subtitles,
        totalSteps: 4,
        activeIndex: switch (status) {
          'Requested' || 'AwaitingPayment' || 'PaymentReview' => 0,
          'Booked' => 1,
          'InProgress' || 'AwaitingConfirmation' => 2,
          'Completed' => 3,
          'Cancelled' => 1,
          'Expired' => 0,
          'Disputed' => 2,
          _ => 0,
        },
        isTerminal: terminal,
      );
    }
    // v2 flow: stage drives the index when present, status otherwise.
    final active = (stage != null && stage >= 0 && stage <= 5)
        ? stage
        : switch (status) {
            'Requested' => 0,
            'Booked' => 1,
            'InProgress' => 2,
            'AwaitingConfirmation' => 3,
            'AwaitingPayment' || 'PaymentReview' => 4,
            'Completed' => 5,
            'Cancelled' => 1,
            'Expired' => 0,
            'Disputed' => 2,
            _ => 0,
          };
    return JobStepperFlow(
      titles: v2Titles,
      subtitles: v2Subtitles,
      totalSteps: 6,
      activeIndex: active.clamp(0, 5),
      isTerminal: terminal,
    );
  }

  /// "Step X of N" caption used by the compact progress bar.
  String get stepCaption =>
      'Step ${activeIndex + 1} of $totalSteps';
}
