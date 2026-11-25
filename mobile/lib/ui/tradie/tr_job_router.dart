// TrJobRouter: v2 entry for `/tradie/jobs/:jobId` (plan 5.3, PR A).
//
// Loads the job once, picks the state with `trSelectJobView`, and renders it.
// PR A is behaviour-neutral: no v2 state widgets exist yet, so every selected
// view injects the v1 screen (`v1Fallback`). Later PRs enable one view at a
// time by adding a case to the switch below.
//
// SignalR (status / adjustment events for this job) refreshes the loader; the
// subscriptions are cancelled in `dispose`. While a refresh is in flight the
// previous data stays on screen so the injected screen is not rebuilt.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/job_hub_client.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../feedback/th_state_view.dart';
import 'tr_job_providers.dart';
import 'tr_job_state.dart';

class TrJobRouter extends ConsumerStatefulWidget {
  const TrJobRouter({super.key, required this.jobId, required this.v1Fallback});

  final String jobId;

  /// Builds the v1 screen for views that have no v2 widget yet.
  final Widget Function() v1Fallback;

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
            // PR A: every view is still the v1 screen.
            TrJobView.booked ||
            TrJobView.inProgress ||
            TrJobView.awaitingConfirmation ||
            TrJobView.completed ||
            TrJobView.cancelled ||
            TrJobView.disputed ||
            TrJobView.fallback => widget.v1Fallback(),
          };
        },
      ),
    );
  }
}
