import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'job_status_presentation.dart';

/// Compact "step X of N" dots + caption.
///
/// v1.7 (P12-15): renders the 6-step flow when the job's [stage]/
/// [flowVersion] say so, and the legacy 4-step flow otherwise — both
/// resolved through [JobStepperFlow] so the order never drifts.
class JobProgressDots extends StatelessWidget {
  final String status;

  /// v1.7 JobDto stage (0..5) under the job's [flowVersion].
  final int? stage;
  final int? flowVersion;

  const JobProgressDots({
    super.key,
    required this.status,
    this.stage,
    this.flowVersion,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<THColors>()!;
    final flow = JobStepperFlow.resolve(
      status,
      stage: stage,
      flowVersion: flowVersion,
    );
    final total = flow.totalSteps;
    final step = flow.activeIndex + 1;
    final terminal = flow.isTerminal;
    final stepLabel = terminal
        ? switch (status) {
            'Disputed' => 'Disputed',
            'Cancelled' => 'Cancelled',
            'Expired' => 'Expired',
            _ => 'Step $step of $total',
          }
        : 'Step $step of $total';
    return Semantics(
      label: '$status, step $step of $total',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: Space.s2,
          runSpacing: Space.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                total,
                (index) => Container(
                  width: Sizes.progressDot,
                  height: Sizes.progressDot,
                  margin: EdgeInsets.only(
                    right: index == total - 1 ? 0 : Sizes.progressDotGap,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < step
                        ? (terminal ? colors.textSoft : colors.brand)
                        : colors.track,
                  ),
                ),
              ),
            ),
            Text(
              stepLabel,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: colors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
