import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import 'job_progress_dots.dart';

import '../../models/marketplace.dart';
import 'job_navigation.dart';
import 'job_status_presentation.dart';
import 'modern_job_card.dart';

bool isPastHomeownerJob(String status) =>
    const {'Completed', 'Cancelled', 'Expired'}.contains(status);

bool needsHomeownerAttention(String status) => const {
  'AwaitingPayment',
  'PaymentReview',
  'AwaitingConfirmation',
  'Disputed',
}.contains(status);

Widget homeownerJobSummary(
  BuildContext context,
  Job job, {
  bool isAttention = false,
}) {
  final presentation = JobStatusPresentation.forStatus(job.status);
  final bool isBooked =
      job.status == 'Booked' || job.status == 'InProgress';
  final String? actionLabel = switch (job.status) {
    'AwaitingPayment' => 'Pay now',
    'PaymentReview' => 'View payment status',
    'AwaitingConfirmation' => 'Review completion',
    'Booked' || 'InProgress' => 'Open chat',
    'Completed' => 'Leave a review',
    'Cancelled' || 'Expired' => null,
    _ => presentation.homeownerAction,
  };

  // Booked/InProgress cards: tap the card itself navigates to job detail,
  // while the tonal button specifically opens chat.
  void onCardTap() => openHomeownerJob(context, job);
  final VoidCallback? onActionTap = isBooked && job.matchedTradieId != null
      ? () => context.push('/chat/${job.id}')
      : (actionLabel != null ? onCardTap : null);

  return ModernJobCard(
    key: ValueKey(job.id),
    title: job.title,
    category: job.category,
    suburb: job.suburb,
    reference: job.referenceCode,
    priceLabel: job.totalAmount == null
        ? null
        : formatMoney(job.totalAmount!),
    scheduleLabel: job.scheduledStartUtc == null
        ? null
        : '${DateFormat.MMMd().add_jm().format(job.scheduledStartUtc!.toLocal())}${job.hours > 0 ? ' · ${job.hours}h' : ''}',
    identityLabel: job.matchedTradieName,
    status: presentation.label,
    statusKind: presentation.kind,
    actionLabel: actionLabel,
    actionIsTonal: isBooked,
    actionIsSecondary: job.status == 'AwaitingPayment',
    progressStatus: job.status,
    isAttention: isAttention,
    onTap: isBooked ? onActionTap : onCardTap,
  );
}

class HomeownerBookedJobs extends StatelessWidget {
  final List<Job> jobs;
  const HomeownerBookedJobs({super.key, required this.jobs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < jobs.length; i++) ...[
          if (i > 0) const SizedBox(height: DesignTokens.cardGap),
          _BookedJobCard(job: jobs[i]),
        ],
      ],
    );
  }
}

class _BookedJobCard extends StatelessWidget {
  final Job job;
  const _BookedJobCard({required this.job});

  String _initials(String? name) {
    final words = name?.trim().split(RegExp(r'\s+')) ?? [];
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scheduleLabel = job.scheduledStartUtc == null
        ? null
        : DateFormat('EEE h:mm a').format(job.scheduledStartUtc!.toLocal());

    return FixoCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('booked_${job.id}'),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        onTap: () => openHomeownerJob(context, job),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.s4, Space.s3, Space.s4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row: avatar | title+name+dots | price+date ─────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar 44×44
                  CircleAvatar(
                    radius: Sizes.avatarMd / 2,
                    backgroundColor: colors.tintBrand,
                    foregroundColor: colors.textBrand,
                    child: Text(
                      _initials(job.matchedTradieName),
                      style: const TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontSize: DesignTokens.fontSizeSm,
                        fontWeight: FW.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  // Middle: title + tradie name + progress dots
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: DesignTokens.fontDisplay,
                            fontSize: DesignTokens.fontSizeSm,
                            fontWeight: FW.bold,
                            height: 1.2,
                            color: DesignTokens.foreground(isDark),
                          ),
                        ),
                        if (job.matchedTradieName?.trim().isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.s0_5),
                            child: Text(
                              job.matchedTradieName!,
                              style: TextStyle(
                                fontFamily: DesignTokens.fontBody,
                                fontSize: DesignTokens.fontSizeSecondary,
                                fontWeight: FW.medium,
                                color: DesignTokens.inkSoft(isDark),
                              ),
                            ),
                          ),
                        const SizedBox(height: Space.s2),
                        JobProgressDots(status: job.status),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  // Right: price + date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (job.totalAmount != null)
                        Text(
                          formatMoney(job.totalAmount!),
                          style: TextStyle(
                            fontFamily: DesignTokens.fontBody,
                            fontSize: DesignTokens.fontSizeBody,
                            fontWeight: FW.bold,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                            color: DesignTokens.foreground(isDark),
                          ),
                        ),
                      if (scheduleLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.s0_5),
                          child: Text(
                            scheduleLabel,
                            style: TextStyle(
                              fontFamily: DesignTokens.fontBody,
                              fontSize: DesignTokens.fontSizeTiny,
                              color: DesignTokens.inkSoft(isDark),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // ── Divider + tonal Open chat button ───────────────────
              const SizedBox(height: Space.s3),
              Divider(height: 1, color: colors.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s3),
                child: FixoTonalButton(
                  label: 'Open chat',
                  icon: Icons.chat_bubble_outline,
                  fullWidth: true,
                  height: Sizes.buttonTonalSm,
                  onPressed: job.matchedTradieId == null
                      ? null
                      : () => context.push('/chat/${job.id}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JobsRefreshNotice extends StatelessWidget {
  final VoidCallback onRetry;

  const JobsRefreshNotice({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Could not refresh jobs. Showing previously loaded jobs.'),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
