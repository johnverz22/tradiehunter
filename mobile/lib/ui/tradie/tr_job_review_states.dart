// Review and terminal state views for tradie job detail (plan 5.3 PR C).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../network/external_launcher.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../../widgets/rating_sheet.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'tr_job_parts.dart';
import 'tr_job_state.dart';

/// AwaitingConfirmation: In-progress layout with a 48-hour approval notice.
class TrJobAwaitingConfirmationScreen extends ConsumerWidget {
  const TrJobAwaitingConfirmationScreen({
    super.key,
    required this.job,
    required this.contact,
    required this.adjustments,
  });

  final Job job;
  final JobContact? contact;
  final List<JobAdjustment> adjustments;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _body(ctx, ref)),
  );

  Widget _body(BuildContext context, WidgetRef ref) {
    final commissionPercent = Decimal.tryParse(
      '${ref.watch(localeConfigProvider).valueOrNull?['commissionPercent'] ?? ''}',
    );

    return THScaffold(
      key: ValueKey('tradie_job_${job.id}'),
      appBar: THAppBar(title: job.title, subtitle: job.category),
      dock: const THDock(role: THDockRole.tradie, active: THDockTab.jobs),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THCard(
            children: [
              const THProgress(steps: 5, done: 4, current: true),
              const SizedBox(height: Space.s3),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        THText(
                          'Awaiting confirmation',
                          style: THTextStyle.title,
                        ),
                        THText(
                          'Waiting for homeowner review.',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge('Awaiting confirmation', kind: THBadgeKind.accent),
                ],
              ),
              if (job.referenceCode?.isNotEmpty == true) ...[
                const SizedBox(height: Space.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TrJobCodeBadge(referenceCode: job.referenceCode!),
                ),
              ],
            ],
          ),

          // 48h auto-complete notice
          Container(
            padding: const EdgeInsets.all(Space.s3_5),
            decoration: BoxDecoration(
              color: context.th.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: context.th.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hourglass_top_outlined,
                  size: Sizes.iconLg,
                  color: context.th.brand,
                ),
                const SizedBox(width: Space.s2_5),
                const Expanded(
                  child: THText(
                    'Waiting for the homeowner to confirm the work is complete. '
                    'They have 48 hours — if they don\'t respond the job auto-completes.',
                    style: THTextStyle.body,
                  ),
                ),
              ],
            ),
          ),

          if (contact != null)
            TrContactCard(
              contact: contact!,
              address: trAddressLabel(job),
              onMessage: () => context.push('/chat/${job.id}'),
              onCall: (p) => ref.read(externalLauncherProvider).callPhone(p),
            ),

          TrJobDetailsCard(job: job, commissionPercent: commissionPercent),

          TrAdjustmentsCard(
            adjustments: adjustments,
            onRequestExtra: () {},
            onWithdraw: (_) {},
          ),
        ],
      ),
    );
  }
}

/// Completed: Job finished, option to rate homeowner.
class TrJobCompletedScreen extends ConsumerStatefulWidget {
  const TrJobCompletedScreen({
    super.key,
    required this.job,
    required this.contact,
    required this.adjustments,
  });

  final Job job;
  final JobContact? contact;
  final List<JobAdjustment> adjustments;

  @override
  ConsumerState<TrJobCompletedScreen> createState() =>
      _TrJobCompletedScreenState();
}

class _TrJobCompletedScreenState extends ConsumerState<TrJobCompletedScreen> {
  bool _hasReview = false;

  void _rateHomeowner() {
    final homeownerId = widget.job.homeownerId ?? '';
    if (homeownerId.isEmpty) return;

    RatingSheet.show(
      context,
      jobId: widget.job.id,
      jobTitle: widget.job.title,
      onSubmit: (rating, comment) async {
        final reviewRepo = ref.read(reviewsRepositoryProvider);
        await reviewRepo.submitReview(
          widget.job.id,
          rating,
          comment,
          revieweeId: homeownerId,
        );
        if (mounted) {
          setState(() => _hasReview = true);
          THNotice.success(context, 'Review submitted. Thank you!');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _page(ctx)),
  );

  Widget _page(BuildContext context) {
    final job = widget.job;
    final homeownerId = job.homeownerId ?? '';
    final commissionPercent = Decimal.tryParse(
      '${ref.watch(localeConfigProvider).valueOrNull?['commissionPercent'] ?? ''}',
    );

    return THScaffold(
      key: ValueKey('tradie_job_${job.id}'),
      appBar: THAppBar(title: job.title, subtitle: job.category),
      dock: const THDock(role: THDockRole.tradie, active: THDockTab.jobs),
      scrollable: true,
      stickyBar: homeownerId.isNotEmpty && !_hasReview
          ? THStickyBar(
              children: [
                THButton(
                  key: const Key('rate_homeowner_button'),
                  label: 'Rate Homeowner',
                  kind: THButtonKind.accent,
                  onPressed: _rateHomeowner,
                ),
              ],
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THCard(
            children: [
              const THProgress(steps: 5, done: 5, current: true),
              const SizedBox(height: Space.s3),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        THText('Completed', style: THTextStyle.title),
                        THText(
                          'Job completed. Thank you!',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge('Completed', kind: THBadgeKind.ok),
                ],
              ),
              if (job.referenceCode?.isNotEmpty == true) ...[
                const SizedBox(height: Space.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TrJobCodeBadge(referenceCode: job.referenceCode!),
                ),
              ],
            ],
          ),

          if (_hasReview)
            Container(
              padding: const EdgeInsets.all(Space.s3_5),
              decoration: BoxDecoration(
                color: context.th.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: context.th.line),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_top_outlined,
                    size: Sizes.iconLg,
                    color: context.th.brand,
                  ),
                  const SizedBox(width: Space.s2_5),
                  const Expanded(
                    child: THText(
                      'Review submitted — waiting for the other party.',
                      style: THTextStyle.body,
                    ),
                  ),
                ],
              ),
            ),

          TrJobDetailsCard(job: job, commissionPercent: commissionPercent),

          if (widget.adjustments.isNotEmpty)
            TrAdjustmentsCard(
              adjustments: widget.adjustments,
              onRequestExtra: () {},
              onWithdraw: (_) {},
            ),
        ],
      ),
    );
  }
}

/// Cancelled: Job was cancelled.
class TrJobCancelledScreen extends ConsumerWidget {
  const TrJobCancelledScreen({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _body(ctx)),
  );

  Widget _body(BuildContext context) {
    return THScaffold(
      key: ValueKey('tradie_job_${job.id}'),
      appBar: THAppBar(title: job.title, subtitle: job.category),
      dock: const THDock(role: THDockRole.tradie, active: THDockTab.jobs),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.s3_5),
            decoration: BoxDecoration(
              color: context.th.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: context.th.danger),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cancel_outlined,
                  size: Sizes.iconLg,
                  color: context.th.danger,
                ),
                const SizedBox(width: Space.s2_5),
                const Expanded(
                  child: THText(
                    'This job was cancelled.',
                    style: THTextStyle.body,
                  ),
                ),
              ],
            ),
          ),
          TrJobDetailsCard(job: job, commissionPercent: null),
        ],
      ),
    );
  }
}

/// Disputed: Active dispute under review.
class TrJobDisputedScreen extends ConsumerWidget {
  const TrJobDisputedScreen({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _body(ctx)),
  );

  Widget _body(BuildContext context) {
    return THScaffold(
      key: ValueKey('tradie_job_${job.id}'),
      appBar: THAppBar(title: job.title, subtitle: job.category),
      dock: const THDock(role: THDockRole.tradie, active: THDockTab.jobs),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.s3_5),
            decoration: BoxDecoration(
              color: context.th.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: context.th.danger),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gavel_rounded,
                  size: Sizes.iconLg,
                  color: context.th.danger,
                ),
                const SizedBox(width: Space.s2_5),
                const Expanded(
                  child: THText(
                    'This job has an active dispute under review.',
                    style: THTextStyle.body,
                  ),
                ),
              ],
            ),
          ),
          THButton(
            label: 'View dispute details',
            kind: THButtonKind.secondary,
            icon: Icons.info_outline_rounded,
            onPressed: () => context.push('/jobs/${job.id}/dispute'),
          ),
          TrJobDetailsCard(job: job, commissionPercent: null),
        ],
      ),
    );
  }
}

/// Fallback view for unrecognized statuses.
class TrJobFallbackScreen extends ConsumerWidget {
  const TrJobFallbackScreen({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _body(ctx)),
  );

  Widget _body(BuildContext context) {
    return THScaffold(
      key: ValueKey('tradie_job_${job.id}'),
      appBar: THAppBar(title: job.title, subtitle: job.category),
      dock: const THDock(role: THDockRole.tradie, active: THDockTab.jobs),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THCard(
            padding: Space.s4,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  THText(job.title, style: THTextStyle.title),
                  THBadge(job.status, kind: THBadgeKind.glass),
                ],
              ),
            ],
          ),
          TrJobDetailsCard(job: job, commissionPercent: null),
        ],
      ),
    );
  }
}
