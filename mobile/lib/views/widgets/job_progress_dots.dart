import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class JobProgressDots extends StatelessWidget {
  final String status;
  const JobProgressDots({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<THColors>()!;
    final step = switch (status) {
      'Booked' => 2,
      'InProgress' || 'AwaitingConfirmation' || 'Disputed' => 3,
      'Completed' => 4,
      _ => 1,
    };
    final stepLabel = switch (status) {
      'Requested' || 'AwaitingPayment' || 'PaymentReview' => 'Requested',
      'Booked' => 'Booked',
      'InProgress' => 'In progress',
      'AwaitingConfirmation' => 'Awaiting confirmation',
      'Disputed' => 'Disputed',
      'Completed' => 'Completed',
      'Cancelled' => 'Cancelled',
      'Expired' => 'Expired',
      _ => 'Step $step of 4',
    };
    final terminal = const {
      'Disputed',
      'Cancelled',
      'Expired',
    }.contains(status);
    return Semantics(
      label: '$status, step $step of 4',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                4,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
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
