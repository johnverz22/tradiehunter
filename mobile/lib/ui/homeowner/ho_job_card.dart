// HoJobCard: v2 homeowner job card shared by `ho_home` (4.1 #1) and `ho_jobs`
// (4.1 #2). Moved verbatim out of ho_home_screen.dart; mapping lives in
// ho_home_mapper.dart, navigation in ho_job_navigation.dart.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_home_mapper.dart';
import 'ho_job_navigation.dart';

class HoJobCard extends StatelessWidget {
  const HoJobCard({
    super.key,
    required this.job,
    this.chatKeyPrefix = 'home_chat_',
  });
  final Job job;

  /// Prefix of the "Open chat" button Key (`<prefix><jobId>`), so each host
  /// screen keeps its own stable test Keys.
  final String chatKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final badge = thHomeStatusBadgeForJob(job);
    final progress = thHomeProgress(job);
    final subtitle = thHomeJobSubtitle(job);
    final amount = job.finalAmount ?? job.totalAmount ?? job.estimatedTotal;
    final canChat = thIsBookedJob(job.status) && job.matchedTradieId != null;

    return Semantics(
      button: true,
      label: '${job.title}, $subtitle, ${badge.label}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => thOpenHomeownerJob(context, job),
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
                THBadge(badge.label, kind: badge.kind),
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
            if (amount != null || canChat) ...[
              const SizedBox(height: Space.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: amount == null
                        ? const SizedBox.shrink()
                        : THText(formatMoney(amount), style: THTextStyle.money),
                  ),
                  if (canChat)
                    THButton(
                      key: Key('$chatKeyPrefix${job.id}'),
                      label: 'Open chat',
                      kind: THButtonKind.secondary,
                      size: THButtonSize.sm,
                      fullWidth: false,
                      onPressed: () => context.push('/chat/${job.id}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
