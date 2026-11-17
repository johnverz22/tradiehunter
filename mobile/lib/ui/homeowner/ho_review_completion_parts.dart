import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoPendingCompletionAdjustment extends StatelessWidget {
  const HoPendingCompletionAdjustment({
    super.key,
    required this.adjustment,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });
  final JobAdjustment adjustment;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => THCard(
    tone: THCardTone.accent,
    children: [
      const THBadge('Extra cost request', kind: THBadgeKind.accent),
      if (adjustment.expiresAtUtc != null) ...[
        const SizedBox(height: Space.s1),
        THText(
          'Expires ${MaterialLocalizations.of(context).formatShortDate(adjustment.expiresAtUtc!.toLocal())}',
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
      ],
      const SizedBox(height: Space.s2),
      THText(formatMoney(adjustment.amount), style: THTextStyle.money),
      THText(adjustment.kind, style: THTextStyle.meta, tone: THTone.soft),
      const SizedBox(height: Space.s2),
      THText(
        adjustment.description.isEmpty
            ? 'No description provided.'
            : adjustment.description,
        style: THTextStyle.body,
      ),
      if (adjustment.evidenceUrl?.isNotEmpty == true) ...[
        const SizedBox(height: Space.s2),
        const THText(
          'A receipt or photo is attached.',
          style: THTextStyle.meta,
        ),
      ],
      const SizedBox(height: Space.s3),
      Row(
        spacing: Space.s2,
        children: [
          Expanded(
            child: THButton(
              label: 'Decline',
              kind: THButtonKind.secondary,
              size: THButtonSize.sm,
              onPressed: busy ? null : onDecline,
            ),
          ),
          Expanded(
            child: THButton(
              label: 'Approve',
              size: THButtonSize.sm,
              onPressed: busy ? null : onApprove,
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.s2),
      const THText(
        'This decision updates the final total. You will review the amount before payment.',
        style: THTextStyle.meta,
        tone: THTone.soft,
      ),
    ],
  );
}

class HoCompletionBreakdown extends StatelessWidget {
  const HoCompletionBreakdown({
    super.key,
    required this.job,
    required this.adjustments,
  });
  final Job job;
  final List<JobAdjustment> adjustments;

  @override
  Widget build(BuildContext context) {
    final approved = adjustments.where((adjustment) => adjustment.isApproved);
    final hasLines = job.labourAmount != null || approved.isNotEmpty;
    return THCard(
      children: [
        const THText('How it adds up', style: THTextStyle.title),
        const SizedBox(height: Space.s2),
        if (job.finalAmount == null)
          const THText(
            'The final amount hasn’t been calculated yet. Check back shortly.',
            style: THTextStyle.body,
          )
        else ...[
          if (!hasLines)
            THKeyValue('Final amount', formatMoney(job.finalAmount!)),
          if (job.finalHours != null && job.labourAmount != null)
            THKeyValue(
              'Labour · ${job.finalHours} h × ${formatMoneyOrDash(job.hourlyRate)}',
              formatMoney(job.labourAmount!),
            )
          else if (job.labourAmount != null)
            THKeyValue('Labour', formatMoney(job.labourAmount!)),
          for (final adjustment in approved)
            THKeyValue(
              adjustment.description.isEmpty
                  ? 'Approved extra cost'
                  : adjustment.description,
              formatMoney(adjustment.amount),
            ),
          if (hasLines)
            THKeyValue(
              'Total to approve',
              formatMoney(job.finalAmount!),
              strong: true,
            ),
        ],
      ],
    );
  }
}
