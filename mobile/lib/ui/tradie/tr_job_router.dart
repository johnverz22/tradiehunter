// TrJobRouter: v2 entry for `/tradie/jobs/:jobId` (plan 5.3, PR A).
//
// Loads the job once, picks the state with `trSelectJobView`, and renders it.
//
// SignalR (status / adjustment events for this job) refreshes the loader. The
// `JobLiveUpdates` mixin joins the job's hub group (without which no status
// events arrive) and tears it down in `dispose`. While a refresh is in flight the
// previous data stays on screen so the view is not rebuilt.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../feedback/th_state_view.dart';
import '../shared/job_live_updates.dart';
import 'tr_job_booked_screen.dart';
import 'tr_job_inprogress_screen.dart';
import 'tr_job_providers.dart';
import 'tr_job_review_states.dart';
import 'tr_job_state.dart';

class TrJobRouter extends ConsumerStatefulWidget {
  const TrJobRouter({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<TrJobRouter> createState() => _TrJobRouterState();
}

class _TrJobRouterState extends ConsumerState<TrJobRouter>
    with JobLiveUpdates<TrJobRouter> {
  @override
  String get liveJobId => widget.jobId;

  @override
  void initState() {
    super.initState();
    startJobLiveUpdates();
  }

  @override
  void onJobLiveUpdate() {
    ref.invalidate(trJobDetailProvider(widget.jobId));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(trJobDetailProvider(widget.jobId));
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: data.when(
        skipLoadingOnReload: true,
        loading: () => const Scaffold(
          body: ThStateView.loading(label: 'Loading job details...'),
        ),
        error: (_, _) => Scaffold(
          body: ThStateView.error(
            message: 'Could not load this job. Please try again.',
            onRetry: () => ref.invalidate(trJobDetailProvider(widget.jobId)),
          ),
        ),
        data: (detail) {
          final job = detail.job;
          if (job == null) {
            return Scaffold(
              body: ThStateView.preset(
                ThStatePreset.jobUnavailable,
                onAction: () => context.go('/tradie'),
              ),
            );
          }
          return switch (trSelectJobView(job)) {
            TrJobView.booked => TrJobBookedScreen(
              job: job,
              contact: detail.contact,
              adjustments: detail.adjustments,
            ),
            TrJobView.inProgress => TrJobInProgressScreen(
              job: job,
              contact: detail.contact,
              adjustments: detail.adjustments,
            ),
            TrJobView.awaitingConfirmation => TrJobAwaitingConfirmationScreen(
              job: job,
              contact: detail.contact,
              adjustments: detail.adjustments,
            ),
            TrJobView.completed => TrJobCompletedScreen(
              job: job,
              contact: detail.contact,
              adjustments: detail.adjustments,
            ),
            TrJobView.cancelled => TrJobCancelledScreen(job: job),
            TrJobView.disputed => TrJobDisputedScreen(job: job),
            TrJobView.fallback => TrJobFallbackScreen(job: job),
          };
        },
      ),
    );
  }
}
