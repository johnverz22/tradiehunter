import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/homeowner_dashboard_header.dart';
import '../widgets/homeowner_job_summary.dart';

/// Homeowner dashboard — visual modernization only.
/// Providers, SignalR wiring, and callbacks unchanged.
class HomeownerDashboardView extends ConsumerStatefulWidget {
  const HomeownerDashboardView({super.key});

  @override
  ConsumerState<HomeownerDashboardView> createState() =>
      _HomeownerDashboardViewState();
}

class _HomeownerDashboardViewState
    extends ConsumerState<HomeownerDashboardView> {
  StreamSubscription<JobStatusEvent>? _statusSubscription;
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs(),
    );
    _initSignalR();
  }

  Future<void> _initSignalR() async {
    final hub = ref.read(jobHubClientProvider);
    final baseUrl = resolveBaseUrl();

    await hub.connect(baseUrl: baseUrl);
    if (!mounted) return;

    _statusSubscription = hub.onJobStatusChanged.listen((e) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(e.jobId, e.status);
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Widget _eyebrow(String title) => Padding(
    padding: const EdgeInsets.only(top: Space.s5_5, bottom: Space.s3_5),
    child: Text(
      title,
      style: TextStyle(
        fontFamily: DesignTokens.fontBody,
        fontSize: DesignTokens.fontSizeCaption,
        fontWeight: FW.semibold,
        letterSpacing: Tracking.emphasis,
        color: DesignTokens.inkSoft(
          Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    ),
  );

  Widget _jobs(List<Job> jobs, {bool isAttention = false}) =>
      SliverList.separated(
        itemCount: jobs.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: DesignTokens.cardGap),
        itemBuilder: (context, index) =>
            homeownerJobSummary(context, jobs[index], isAttention: isAttention),
      );

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final firstName = (profileState.profile?['firstName'] as String? ?? '')
        .trim();
    final location = (profileState.profile?['address'] as String? ??
            profileState.profile?['suburb'] as String? ??
            profileState.profile?['location'] as String?)
        ?.trim();
    final attention = jobsState.jobs
        .where((j) => needsHomeownerAttention(j.status))
        .toList();

    int attentionPriority(String status) {
      switch (status) {
        case 'AwaitingPayment':
          return 0;
        case 'AwaitingConfirmation':
          return 1;
        case 'Disputed':
          return 2;
        case 'PaymentReview':
          return 3;
        default:
          return 4;
      }
    }

    attention.sort((a, b) {
      final pA = attentionPriority(a.status);
      final pB = attentionPriority(b.status);
      if (pA != pB) return pA.compareTo(pB);

      final dateA = a.scheduledStartUtc ?? a.createdAtUtc;
      final dateB = b.scheduledStartUtc ?? b.createdAtUtc;
      if (dateA != null && dateB != null) {
        return dateA.compareTo(dateB);
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      }
      return 0;
    });

    final booked = jobsState.jobs
        .where((j) => j.status == 'Booked' || j.status == 'InProgress')
        .toList();
    final active = jobsState.jobs
        .where(
          (j) =>
              !isPastHomeownerJob(j.status) &&
              !needsHomeownerAttention(j.status) &&
              j.status != 'Booked' &&
              j.status != 'InProgress',
        )
        .toList();
    final past = jobsState.jobs
        .where((j) => isPastHomeownerJob(j.status))
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white icons over brand header
      child: Scaffold(
        key: const Key('homeowner_dashboard'),
        body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Brand header — light-blue abstract bg shared with every
            // app bar ─────────────────────────────────────────────────
            HomeownerDashboardHeader(
              firstName: firstName,
              location: (location != null && location.isNotEmpty) ? location : null,
            ),
            Expanded(
              child: jobsState.isLoading && jobsState.jobs.isEmpty
                  ? const FixoLoading(label: 'Loading your jobs...')
                  : jobsState.error != null && jobsState.jobs.isEmpty
                  ? FixoErrorState(
                      message: 'Could not load your jobs. Please try again.',
                      onRetry: () => ref
                          .read(jobsViewModelProvider.notifier)
                          .loadHomeownerJobs(),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: RefreshIndicator(
                          onRefresh: () => ref
                              .read(jobsViewModelProvider.notifier)
                              .loadHomeownerJobs(),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s3, Space.gutter, Space.navClearance),
                                sliver: SliverMainAxisGroup(
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (jobsState.error != null)
                                            JobsRefreshNotice(
                                              onRetry: () => ref
                                                  .read(
                                                    jobsViewModelProvider
                                                        .notifier,
                                                  )
                                                  .loadHomeownerJobs(),
                                            ),
                                          if (jobsState.jobs.isEmpty)
                                            HomeownerDashboardEmpty(
                                              onPost: () =>
                                                  context.push('/jobs/new'),
                                            ),
                                          if (attention.isNotEmpty)
                                            _eyebrow('Needs your attention'),
                                        ],
                                      ),
                                    ),
                                    _jobs(attention, isAttention: true),
                                    if (booked.isNotEmpty) ...[
                                      SliverToBoxAdapter(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _eyebrow('Booked'),
                                            HomeownerBookedJobs(jobs: booked),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (active.isNotEmpty) ...[
                                      SliverToBoxAdapter(
                                        child: _eyebrow('Active jobs'),
                                      ),
                                      _jobs(active),
                                    ],
                                    if (past.isNotEmpty) ...[
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: Space.s5_5),
                                          child: Semantics(
                                            expanded: _showPast,
                                            child: TextButton.icon(
                                              onPressed: () => setState(
                                                () => _showPast = !_showPast,
                                              ),
                                              icon: Icon(
                                                _showPast
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                              ),
                                              label: Text(
                                                'Past jobs (${past.length})',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_showPast) _jobs(past),
                                    ],
                                    if (jobsState.jobs.isNotEmpty)
                                      SliverToBoxAdapter(
                                        child: TextButton(
                                          onPressed: () => context.go('/jobs'),
                                          child: const Text('See all jobs'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ), // Scaffold
    ); // AnnotatedRegion
  }
}
