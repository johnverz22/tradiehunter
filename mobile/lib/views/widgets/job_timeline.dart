import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/fixo_cards.dart';
import 'compact_progress_bar.dart';
import 'job_status_presentation.dart';

/// Full vertical job timeline for detail pages.
///
/// Features:
/// - Collapsed by default behind a ≥48px "View all steps" tap target
/// - Expands inline without navigating away
/// - Step nodes indicate completed (check), current (active node), or upcoming
///   without using any radio buttons
/// - Shows step timestamps when provided
/// - Gracefully handles terminal states (Cancelled, Expired, Disputed)
///
/// v1.7 (P12-15): step order is resolved by [JobStepperFlow] — the 6-step
/// Requested → Booked → In progress → Review & approve → Pay → Completed
/// order for v2 jobs, the legacy 4-step order for flowVersion-1 jobs.
class JobTimeline extends StatefulWidget {
  final String status;

  /// v1.7 JobDto stage (0..5) under the job's [flowVersion]; null falls
  /// back to the legacy status mapping.
  final int? stage;
  final int? flowVersion;
  final VoidCallback? onRefresh;
  final Map<int, DateTime>? stepDates;
  final bool initialExpanded;

  const JobTimeline({
    super.key,
    required this.status,
    this.stage,
    this.flowVersion,
    this.onRefresh,
    this.stepDates,
    this.initialExpanded = false,
  });

  @override
  State<JobTimeline> createState() => _JobTimelineState();
}

class _JobTimelineState extends State<JobTimeline> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  void didUpdateWidget(JobTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.stage != widget.stage ||
        oldWidget.initialExpanded != widget.initialExpanded) {
      _expanded = widget.initialExpanded;
    }
  }

  JobStepperFlow get _flow => JobStepperFlow.resolve(
    widget.status,
    stage: widget.stage,
    flowVersion: widget.flowVersion,
  );

  bool get _isTerminal => _flow.isTerminal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final presentation = JobStatusPresentation.forStatus(widget.status);

    final isUnavailable = presentation.label == 'Status unavailable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status badge row
        StatusBadge(label: presentation.label, kind: presentation.kind),
        const SizedBox(height: Space.s3),

        if (isUnavailable) ...[
          Text(
            'Job progress is unavailable. Refresh to check the latest status.',
            style: theme.textTheme.bodyMedium,
          ),
          if (widget.onRefresh != null) ...[
            const SizedBox(height: Space.s2),
            TextButton(
              onPressed: widget.onRefresh,
              child: const Text('Refresh status'),
            ),
          ],
        ] else ...[
          // Compact progress bar
          CompactProgressBar(
            status: widget.status,
            stage: widget.stage,
            flowVersion: widget.flowVersion,
          ),
          const SizedBox(height: Space.s2),

          // Inline expanded timeline or toggle button
          if (_expanded) ...[
            const SizedBox(height: Space.s2),
            _buildExpandedTimeline(context, isDark),
            const SizedBox(height: Space.s2),
            _buildToggleButton(
              label: 'Hide steps',
              icon: Icons.keyboard_arrow_up_rounded,
              onTap: () => setState(() => _expanded = false),
              isDark: isDark,
            ),
          ] else ...[
            _buildToggleButton(
              label: 'View all steps',
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: () => setState(() => _expanded = true),
              isDark: isDark,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final color = isDark ? DesignTokens.brand300 : DesignTokens.brand700;
    return SizedBox(
      height: Sizes.tapMin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    fontWeight: FW.semibold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Space.s1),
              Icon(icon, size: Sizes.iconAction, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedTimeline(BuildContext context, bool isDark) {
    final flow = _flow;
    final activeIndex = flow.activeIndex;
    final total = flow.totalSteps;
    final theme = Theme.of(context);

    final lineColor = isDark
        ? Colors.white.withValues(alpha: Alpha.tintAccent)
        : DesignTokens.paperLineLight;
    final activeLineColor = isDark
        ? DesignTokens.brand300
        : DesignTokens.brand700;

    return Semantics(
      label: List.generate(total, (index) {
        final state = index < activeIndex
            ? 'complete'
            : (index == activeIndex
                  ? (_isTerminal ? 'terminal' : 'current')
                  : 'upcoming');
        return '${flow.titles[index]}: $state';
      }).join(', '),
      child: ExcludeSemantics(
        child: Column(
          children: List.generate(total, (index) {
            final isCompleted = index < activeIndex;
            final isCurrent = index == activeIndex;
            final isUpcoming = index > activeIndex;
            final isLast = index == total - 1;

            // Date / subtitle logic
            final stepDate = widget.stepDates?[index];
            final subtitleText = stepDate != null
                ? DateFormat('MMM d, h:mm a').format(stepDate)
                : (_isTerminal && isCurrent
                      ? switch (widget.status) {
                          'Cancelled' => 'Job was cancelled',
                          'Expired' => 'Job request expired',
                          'Disputed' => 'Dispute raised; awaiting resolution',
                          _ => flow.subtitles[index],
                        }
                      : flow.subtitles[index]);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step indicator column with connecting line
                  SizedBox(
                    width: Sizes.stepNodeCol,
                    child: Column(
                      children: [
                        _buildStepNode(
                          index: index,
                          isCompleted: isCompleted,
                          isCurrent: isCurrent,
                          isUpcoming: isUpcoming,
                          isDark: isDark,
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: Sizes.borderWidthThick,
                              margin: const EdgeInsets.symmetric(
                                vertical: Space.s0_5,
                              ),
                              color: isCompleted ? activeLineColor : lineColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s3),

                  // Step title and subtitle
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: Space.s0_5,
                        bottom: isLast ? 0 : Space.s5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            flow.titles[index],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isCurrent
                                  ? FW.bold
                                  : (isCompleted ? FW.semibold : FW.regular),
                              color: isUpcoming
                                  ? (isDark
                                        ? Colors.white.withValues(
                                            alpha: Alpha.ghost,
                                          )
                                        : DesignTokens.inkSoft(isDark))
                                  : (isDark
                                        ? Colors.white
                                        : DesignTokens.brand900),
                            ),
                          ),
                          const SizedBox(height: Space.s0_5),
                          Text(
                            subtitleText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isUpcoming
                                  ? (isDark
                                        ? Colors.white.withValues(
                                            alpha: Alpha.border,
                                          )
                                        : DesignTokens.inkSoftLight.withValues(
                                            alpha: Alpha.divider,
                                          ))
                                  : (isDark
                                        ? Colors.white.withValues(
                                            alpha: Alpha.iconOnGradientSoft,
                                          )
                                        : DesignTokens.inkSoftLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStepNode({
    required int index,
    required bool isCompleted,
    required bool isCurrent,
    required bool isUpcoming,
    required bool isDark,
  }) {
    if (isCompleted) {
      return Container(
        width: Sizes.stepNode,
        height: Sizes.stepNode,
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.brand300 : DesignTokens.brand700,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: Sizes.iconChip,
          color: isDark ? DesignTokens.brand900 : Colors.white,
        ),
      );
    }

    if (isCurrent) {
      if (_isTerminal) {
        final terminalColor = switch (widget.status) {
          'Disputed' => DesignTokens.inkDanger(isDark),
          _ => isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
        };
        final terminalIcon = switch (widget.status) {
          'Disputed' => Icons.warning_amber_rounded,
          _ => Icons.close_rounded,
        };
        return Container(
          width: Sizes.stepNode,
          height: Sizes.stepNode,
          decoration: BoxDecoration(
            color: terminalColor,
            shape: BoxShape.circle,
          ),
          child: Icon(terminalIcon, size: Sizes.iconChip, color: Colors.white),
        );
      }

      final currentColor = isDark
          ? DesignTokens.brand300
          : DesignTokens.brand700;
      return Container(
        width: Sizes.stepNode,
        height: Sizes.stepNode,
        decoration: BoxDecoration(color: currentColor, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeCaption,
              fontWeight: FW.bold,
              color: isDark ? DesignTokens.brand900 : Colors.white,
            ),
          ),
        ),
      );
    }

    // Upcoming step
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: Alpha.tintDark)
        : DesignTokens.paperLineLight;
    return Container(
      width: Sizes.stepNode,
      height: Sizes.stepNode,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: outlineColor,
          width: DesignTokens.borderWidthFor(isDark),
        ),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeCaption,
            fontWeight: FW.medium,
            color: isDark
                ? Colors.white.withValues(alpha: Alpha.ghost)
                : DesignTokens.inkSoft(isDark),
          ),
        ),
      ),
    );
  }
}
