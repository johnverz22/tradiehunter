// TrJobCard: v2 tradie job card for dashboard and job lists.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'tr_home_mapper.dart';

class TrJobCard extends StatelessWidget {
  const TrJobCard({
    super.key,
    required this.job,
    this.onTap,
    this.isOverdueOverride,
  });

  final Job job;
  final VoidCallback? onTap;
  final bool? isOverdueOverride;

  bool get _isOverdue {
    if (isOverdueOverride != null) return isOverdueOverride!;
    if (job.status != 'Booked') return false;
    return thIsOverdue(job, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _isOverdue;
    final badge = thTradieStatusBadge(job.status, isOverdue: overdue);
    final progress = thTradieProgress(job);
    final subtitle = thTradieJobSubtitle(job);
    final amount = job.finalAmount ?? job.totalAmount ?? job.estimatedTotal;
    final actionRequired = thIsTradieActionRequired(job.status);

    final actionLabel = switch (job.status) {
      'Booked' => 'Check in',
      'InProgress' => 'Check out',
      'AwaitingConfirmation' => 'Review',
      _ => null,
    };

    return Semantics(
      button: true,
      label: '${job.title}, $subtitle, ${badge.label}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap ?? () => context.push('/tradie/jobs/${job.id}'),
        child: THCard(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: Space.s2,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 2.0,
                    children: [
                      THText(job.title, style: THTextStyle.title),
                      THText(
                        subtitle,
                        style: THTextStyle.meta,
                        tone: THTone.soft,
                      ),
                    ],
                  ),
                ),
                THBadge(
                  badge.label,
                  kind: badge.kind,
                  icon: overdue ? Icons.warning_amber_rounded : null,
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: Space.s3),
              THProgress(
                steps: progress.steps,
                done: progress.done,
                current: progress.current,
              ),
            ],
            const SizedBox(height: Space.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: amount == null
                      ? const SizedBox.shrink()
                      : THText(formatMoney(amount), style: THTextStyle.money),
                ),
                if (actionRequired && actionLabel != null)
                  THButton(
                    label: actionLabel,
                    kind: THButtonKind.accent,
                    size: THButtonSize.sm,
                    fullWidth: false,
                    onPressed: onTap ?? () => context.push('/tradie/jobs/${job.id}'),
                  )
                else
                  const THIcon(Icons.chevron_right_rounded, tone: THTone.soft),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
