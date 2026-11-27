import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../feedback/th_state_view.dart';
import '../shared/job_live_updates.dart';
import 'ho_booked_screen.dart';
import 'ho_extra_cost_screen.dart';
import 'ho_job_detail_fallback_screen.dart';
import 'ho_job_detail_providers.dart';
import 'ho_job_detail_state.dart';
import 'ho_matching_screen.dart';
import 'ho_quotes_screen.dart';
import 'ho_review_completion_screen.dart';
import 'ho_review_screen.dart';

/// Routes each job status to its dedicated v2 view. Statuses without a design
/// frame (cancelled, dispute, requested, matching, payment, draft, expired)
/// render the composed [HoJobDetailFallbackScreen].
class ThJobDetailRouter extends ConsumerStatefulWidget {
  const ThJobDetailRouter({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<ThJobDetailRouter> createState() => _ThJobDetailRouterState();
}

class _ThJobDetailRouterState extends ConsumerState<ThJobDetailRouter>
    with JobLiveUpdates<ThJobDetailRouter> {
  @override
  String get liveJobId => widget.jobId;

  @override
  void initState() {
    super.initState();
    startJobLiveUpdates();
  }

  @override
  void onJobLiveUpdate() {
    ref.invalidate(hoJobDetailProvider(widget.jobId));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(hoJobDetailProvider(widget.jobId));
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: data.when(
        loading: () => const Scaffold(
          body: ThStateView.loading(label: 'Loading job details...'),
        ),
        error: (_, _) => Scaffold(
          body: ThStateView.error(
            message: 'Could not load this job. Please try again.',
            onRetry: () => ref.invalidate(hoJobDetailProvider(widget.jobId)),
          ),
        ),
        data: (detail) {
          final job = detail.job;
          if (job == null) {
            return Scaffold(
              body: ThStateView.preset(
                ThStatePreset.jobNotFound,
                onAction: () => context.go('/jobs'),
                onSecondary: () => context.go('/settings'),
              ),
            );
          }
          final selection = thSelectJobDetailView(
            job,
            adjustments: detail.adjustments,
            hasReview: detail.hasReview,
            hasTradie: detail.tradie != null,
          );
          return switch (selection.view) {
            HoJobDetailView.inProgress ||
            HoJobDetailView.extraCost => HoExtraCostScreen(
              job: job,
              tradie: detail.tradie,
              adjustment: detail.adjustments
                  .where((item) => item.isPending)
                  .firstOrNull,
            ),
            HoJobDetailView.booked => HoBookedScreen(
              job: job,
              tradie: detail.tradie,
              contact: detail.contact,
            ),
            HoJobDetailView.reviewCompletion => HoReviewCompletionScreen(
              job: job,
              adjustments: detail.adjustments,
            ),
            HoJobDetailView.review => HoReviewScreen(
              job: job,
              tradie: detail.tradie,
              hasReview: detail.hasReview,
            ),
            HoJobDetailView.fallback =>
              (job.status == 'Requested' || job.status == 'Matching')
              ? (job.isProject
                    ? HoQuotesScreen(jobId: job.id)
                    : ThMatchingScreen(jobId: job.id))
              : HoJobDetailFallbackScreen(
                  job: job,
                  reason: selection.fallback!,
                ),
          };
        },
      ),
    );
  }
}
