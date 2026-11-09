import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'compact_progress_bar.dart';
import 'job_status_presentation.dart';

/// v1.6 status-strip — the navy gradient band that sits immediately below the
/// app bar on job detail screens (H12, T22).
///
/// Contains:
/// - CompactProgressBar (4-segment) with "Step X of 4" caption
/// - Reference code (right-aligned, muted monospace)
/// - Tap the entire strip to expand/collapse the full 4-step timeline inline
///
/// The entire band is brand-gradient, so all text/icons are white-alpha.
class StatusStrip extends StatefulWidget {
  final String status;
  final String? referenceCode;

  const StatusStrip({
    super.key,
    required this.status,
    this.referenceCode,
  });

  @override
  State<StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<StatusStrip>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  static const _stepTitles = ['Requested', 'Booked', 'In progress', 'Done'];
  static const _stepSubtitles = [
    'Job request submitted',
    'Tradie matched & booked',
    'Work underway on site',
    'Work complete & verified',
  ];

  int get _activeStepIndex => switch (widget.status) {
        'Requested' || 'AwaitingPayment' || 'PaymentReview' => 0,
        'Booked' => 1,
        'InProgress' || 'AwaitingConfirmation' => 2,
        'Completed' => 3,
        'Cancelled' => 1,
        'Expired' => 0,
        'Disputed' => 2,
        _ => 0,
      };

  bool get _isTerminal => switch (widget.status) {
        'Cancelled' || 'Expired' || 'Disputed' => true,
        _ => false,
      };

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final presentation = JobStatusPresentation.forStatus(widget.status);
    final isDisputed = widget.status == 'Disputed';
    final stepIndex = presentation.progressStage ?? 0;
    final completedSteps = stepIndex + 1;

    // Step label for cpb caption
    final stepLabel = switch (widget.status) {
      'Booked' => 'Booked',
      'InProgress' => 'In progress',
      'AwaitingConfirmation' => 'Awaiting confirmation',
      'Completed' => 'Done',
      'Disputed' => 'Awaiting confirmation',
      _ => presentation.label,
    };

    final muted = isDisputed || widget.status == 'Cancelled';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Space.gutter, 14, Space.gutter, Space.s4),
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
          // Row: compact progress bar (with chevron in caption) + reference code
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: CompactProgressBar(
                  completedSteps: completedSteps,
                  totalSteps: 4,
                  label: 'Step $completedSteps of 4',
                  sublabel: stepLabel,
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
                        size: 24,
                        color: Colors.white
                            .withValues(alpha: Alpha.iconOnGradient),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.referenceCode != null &&
                  widget.referenceCode!.isNotEmpty) ...[
                const SizedBox(width: Space.s3),
                Text(
                  widget.referenceCode!,
                  style: TextStyle(
                    fontFamily: DesignTokens.fontMono,
                    fontSize: DesignTokens.fontSizeCaption,
                    fontWeight: FW.medium,
                    color:
                        Colors.white.withValues(alpha: Alpha.textOnGradient),
                  ),
                ),
              ],
            ],
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
      ),
    );
  }

  Widget _buildStepList() {
    final activeIndex = _activeStepIndex;
    final lineColor = Colors.white.withValues(alpha: Alpha.tintAccent);
    final activeLineColor = Colors.white.withValues(alpha: Alpha.gradient);

    return Column(
      children: List.generate(4, (index) {
        final isCompleted = index < activeIndex;
        final isCurrent = index == activeIndex;
        final isUpcoming = index > activeIndex;
        final isLast = index == 3;

        // Terminal subtitle override
        String subtitleText;
        if (_isTerminal && isCurrent) {
          subtitleText = switch (widget.status) {
            'Cancelled' => 'Job was cancelled',
            'Expired' => 'Job request expired',
            'Disputed' => 'Dispute raised; awaiting resolution',
            _ => _stepSubtitles[index],
          };
        } else {
          subtitleText = _stepSubtitles[index];
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step node + connecting line
              SizedBox(
                width: 28,
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
                          width: 2,
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
                      EdgeInsets.only(top: Space.s0_5, bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stepTitles[index],
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
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 14,
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
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: Alpha.tintAccent),
            shape: BoxShape.circle,
          ),
          child: Icon(terminalIcon, size: 14, color: Colors.white),
        );
      }
      return Container(
        width: 24,
        height: 24,
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
      width: 24,
      height: 24,
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
