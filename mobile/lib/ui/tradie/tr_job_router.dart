// TrJobRouter: v2 entry for `/tradie/jobs/:jobId` (plan 5.3, PR A).
//
// Loads the job once, picks the state with `trSelectJobView`, and renders it.
//
// SignalR (status / adjustment events for this job) refreshes the loader; the
// subscriptions are cancelled in `dispose`. While a refresh is in flight the
// previous data stays on screen so the view is not rebuilt.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/job_hub_client.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../feedback/th_state_view.dart';
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

class _TrJobRouterState extends ConsumerState<TrJobRouter> {
  StreamSubscription<JobStatusEvent>? _statusSubscription;
  StreamSubscription<JobAdjustmentEvent>? _adjustmentSubscription;

  @override
  void initState() {
    super.initState();
    final hub = ref.read(jobHubClientProvider);
    _statusSubscription = hub.onJobStatusChanged.listen((event) {
      if (event.jobId == widget.jobId) _refresh();
    });
    _adjustmentSubscription = hub.onAdjustmentChanged.listen((event) {
      if (event.jobId == widget.jobId) _refresh();
    });
  }

  void _refresh() {
    if (!mounted) return;
    ref.invalidate(trJobDetailProvider(widget.jobId));
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _adjustmentSubscription?.cancel();
    super.dispose();
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
