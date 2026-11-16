import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/fixo_cards.dart';
import 'compact_progress_bar.dart';
import 'job_status_presentation.dart';
import '../../feedback/fixo_notice.dart';

/// v1.6 status-strip — the navy gradient band that sits immediately below the
/// app bar on job detail screens (H12, T22).
///
/// Contains:
/// - CompactProgressBar with "Step X of N" caption
/// - Reference code (right-aligned, muted monospace)
/// - Tap the entire strip to expand/collapse the full step timeline inline
///
/// The entire band is brand-gradient, so all text/icons are white-alpha.
///
/// v1.7 (P12-15): the step order comes from [JobStepperFlow] — 6 steps
/// (Requested → Booked → In progress → Review & approve → Pay → Completed)
/// for v2 jobs, the legacy 4-step order for flowVersion-1 jobs.
class StatusStrip extends StatefulWidget {
  final String status;

  /// v1.7 JobDto stage (0..5) under the job's [flowVersion]; null falls
  /// back to the legacy status mapping.
  final int? stage;
  final int? flowVersion;
  final String? referenceCode;

  const StatusStrip({
    super.key,
    required this.status,
    this.stage,
    this.flowVersion,
    this.referenceCode,
  });

  @override
  State<StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<StatusStrip>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  JobStepperFlow get _flow => JobStepperFlow.resolve(
        widget.status,
        stage: widget.stage,
        flowVersion: widget.flowVersion,
      );

  bool get _isTerminal => _flow.isTerminal;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final presentation = JobStatusPresentation.forStatus(widget.status);
    final isDisputed = widget.status == 'Disputed';

    final flow = _flow;
    final totalSteps = flow.totalSteps;
    final stepIndex = flow.activeIndex;
    final completedSteps = stepIndex + 1;
    // The current step's own title is the clearest caption; it differs from
    // the status-chip label for most statuses, in which case the chip label
    // shows as the sub-caption.
    final stepLabel = flow.titles.isNotEmpty && stepIndex < flow.titles.length
        ? flow.titles[stepIndex]
        : flow.stepCaption;
    final shouldShowSublabel = stepLabel.trim().toLowerCase() !=
        presentation.label.trim().toLowerCase();

    // Progress bar shows for known, non-terminal statuses only — unknown
    // statuses and Cancelled/Expired/Disputed render the pill alone.
    final bool hasProgress =
        presentation.label != 'Status unavailable' && !flow.isTerminal;

    final muted = isDisputed || widget.status == 'Cancelled';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s3_5, Space.gutter, Space.s4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DesignTokens.brand900, DesignTokens.brand700],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: status pill + reference code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                    label: presentation.label,
                    kind: presentation.kind,
                    icon: presentation.chipIcon,
                    onDark: true,
                  ),
                ),
              ),
              if (widget.referenceCode != null &&
                  widget.referenceCode!.isNotEmpty) ...[
                const SizedBox(width: Space.s2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label:
                          'Job code: ${widget.referenceCode}, long-press to copy',
                      child: Tooltip(
                        message: 'Long-press to copy job code',
                        child: GestureDetector(
                          key: const Key('status_strip_job_code'),
                          onLongPress: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.referenceCode!),
                            );
                            FixoNotice.info(context, 'Job code copied: ${widget.referenceCode}');
                          },
                          child: Text(
                            widget.referenceCode!,
                            style: TextStyle(
                              fontFamily: DesignTokens.fontMono,
                              fontSize: DesignTokens.fontSizeMono,
                              fontWeight: FW.medium,
                              color: Colors.white
                                  .withValues(alpha: Alpha.textOnGradient),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hasProgress) ...[
            const SizedBox(height: Space.s2_5),
            CompactProgressBar(
              completedSteps: completedSteps,
              totalSteps: totalSteps,
              label: 'Step $completedSteps of $totalSteps',
              sublabel: shouldShowSublabel ? stepLabel : null,
              muted: muted,
              onDark: true,
              onCaptionTap: _toggle,
              trailing: Padding(
                padding: const EdgeInsets.only(left: Space.s1),
                child: AnimatedRotation(
                  duration: FixoDurations.expand,
                  curve: Curves.easeInOut,
                  turns: _expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: Sizes.iconLg,
                    color: Colors.white
                        .withValues(alpha: Alpha.iconOnGradient),
                  ),
                ),
              ),
            ),
            // Expandable step list — animated
            AnimatedSize(
              duration: FixoDurations.expand,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: Space.s3),
                      child: _buildStepList(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepList() {
    final flow = _flow;
    final activeIndex = flow.activeIndex;
    final total = flow.totalSteps;
    final lineColor = Colors.white.withValues(alpha: Alpha.tintAccent);
    final activeLineColor = Colors.white.withValues(alpha: Alpha.gradient);

    return Column(
      children: List.generate(total, (index) {
        final isCompleted = index < activeIndex;
        final isCurrent = index == activeIndex;
        final isUpcoming = index > activeIndex;
        final isLast = index == total - 1;

        // Terminal subtitle override
        String subtitleText;
        if (_isTerminal && isCurrent) {
          subtitleText = switch (widget.status) {
            'Cancelled' => 'Job was cancelled',
            'Expired' => 'Job request expired',
            'Disputed' => 'Dispute raised; awaiting resolution',
            _ => flow.subtitles[index],
          };
        } else {
          subtitleText = flow.subtitles[index];
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step node + connecting line
              SizedBox(
                width: Sizes.stepNodeCol,
                child: Column(
                  children: [
                    _buildStepNode(
                      index: index,
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      isUpcoming: isUpcoming,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: Sizes.borderWidthThick,
                          margin:
                              const EdgeInsets.symmetric(vertical: Space.s0_5),
                          color: isCompleted ? activeLineColor : lineColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s3),
              // Step title + subtitle
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(top: Space.s0_5, bottom: isLast ? 0 : Space.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flow.titles[index],
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeBody,
                          fontWeight: isCurrent
                              ? FW.bold
                              : (isCompleted ? FW.semibold : FW.regular),
                          color: isUpcoming
                              ? Colors.white.withValues(alpha: Alpha.ghost)
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: Space.s0_5),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeCaption,
                          color: isUpcoming
                              ? Colors.white.withValues(alpha: Alpha.border)
                              : Colors.white
                                  .withValues(alpha: Alpha.iconOnGradientSoft),
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
    );
  }

  Widget _buildStepNode({
    required int index,
    required bool isCompleted,
    required bool isCurrent,
    required bool isUpcoming,
  }) {
    if (isCompleted) {
      return Container(
        width: Sizes.stepNode,
        height: Sizes.stepNode,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: Sizes.iconXs,
          color: DesignTokens.brand900,
        ),
      );
    }

    if (isCurrent) {
      if (_isTerminal) {
        final terminalIcon = switch (widget.status) {
          'Disputed' => Icons.warning_amber_rounded,
          _ => Icons.close_rounded,
        };
        return Container(
          width: Sizes.stepNode,
          height: Sizes.stepNode,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: Alpha.tintAccent),
            shape: BoxShape.circle,
          ),
          child: Icon(terminalIcon, size: Sizes.iconXs, color: Colors.white),
        );
      }
      return Container(
        width: Sizes.stepNode,
        height: Sizes.stepNode,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: Alpha.gradient),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeCaption,
              fontWeight: FW.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Upcoming
    return Container(
      width: Sizes.stepNode,
      height: Sizes.stepNode,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: Alpha.tintDark),
          width: DesignTokens.borderWidthFor(true),
        ),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeCaption,
            fontWeight: FW.medium,
            color: Colors.white.withValues(alpha: Alpha.ghost),
          ),
        ),
      ),
    );
  }
}
