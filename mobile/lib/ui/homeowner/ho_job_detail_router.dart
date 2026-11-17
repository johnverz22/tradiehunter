import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/job_hub_client.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../feedback/th_state_view.dart';
import 'ho_extra_cost_screen.dart';
import 'ho_job_detail_providers.dart';
import 'ho_job_detail_state.dart';

/// Routes supported v2 states to their dedicated view and injects the v1
/// screen for states that have no v2 design yet. PR A deliberately sends every
/// state through the fallback; later 4.2 increments enable one state at a time.
class ThJobDetailRouter extends ConsumerStatefulWidget {
  const ThJobDetailRouter({
    super.key,
    required this.jobId,
    required this.v1Fallback,
  });

  final String jobId;
  final Widget Function() v1Fallback;

  @override
  ConsumerState<ThJobDetailRouter> createState() => _ThJobDetailRouterState();
}

class _ThJobDetailRouterState extends ConsumerState<ThJobDetailRouter> {
  StreamSubscription<JobStatusEvent>? _statusSubscription;
  StreamSubscription<JobAdjustmentEvent>? _adjustmentSubscription;

  @override
  void initState() {
    super.initState();
    final hub = ref.read(jobHubClientProvider);
    _statusSubscription = hub.onJobStatusChanged.listen((event) {
      if (event.jobId == widget.jobId) {
        ref.invalidate(hoJobDetailProvider(widget.jobId));
      }
    });
    _adjustmentSubscription = hub.onAdjustmentChanged.listen((event) {
      if (event.jobId == widget.jobId) {
        ref.invalidate(hoJobDetailProvider(widget.jobId));
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _adjustmentSubscription?.cancel();
    super.dispose();
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
            HoJobDetailView.booked ||
            HoJobDetailView.reviewCompletion ||
            HoJobDetailView.review ||
            HoJobDetailView.fallback => widget.v1Fallback(),
          };
        },
      ),
    );
  }
}
