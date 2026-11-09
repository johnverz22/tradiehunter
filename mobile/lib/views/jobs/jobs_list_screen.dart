import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../tradie/tradie_dashboard_view.dart' show isScheduledOnOrBeforeToday;
import '../tradie/tradie_job_detail_screen.dart';
import '../tradie/request_detail_screen.dart';
import '../homeowner/homeowner_job_detail_screen.dart';
import '../widgets/job_status_presentation.dart';
import '../../widgets/fixo_states.dart';
import '../../widgets/fixo_buttons.dart';
import '../widgets/modern_job_card.dart';
import '../widgets/homeowner_job_summary.dart';

enum _JobFilter { active, completed, all }

/// T20 tradie filters — local-day buckets plus the two states a tradie needs
/// to find quickly; All keeps every exceptional state reachable.
enum _TradieJobFilter { today, upcoming, awaitingPayment, done, all }

const _tradieWorkStatuses = {'Booked', 'InProgress', 'AwaitingConfirmation'};

const _tradieAwaitingPaymentStatuses = {'AwaitingPayment', 'PaymentReview'};

/// One local-day bucket of tradie jobs for the grouped list.
class TradieDayGroup {
  final String label;
  final List<Job> jobs;
  const TradieDayGroup(this.label, this.jobs);
}

/// Groups [jobs] by the local calendar day of `scheduledStartUtc`
/// (unscheduled jobs land in a trailing "Unscheduled" group). Labels are
/// Today/Tomorrow or a localized date. [newestFirst] orders days descending
/// for Done/All, ascending for Today/Upcoming.
List<TradieDayGroup> tradieDayGroups(
  List<Job> jobs,
  DateTime now, {
  required bool newestFirst,
}) {
  DateTime dayKey(Job job) {
    final local = job.scheduledStartUtc!.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  final scheduled = jobs.where((j) => j.scheduledStartUtc != null).toList()
    ..sort((a, b) => a.scheduledStartUtc!.compareTo(b.scheduledStartUtc!));
  final unscheduled = jobs.where((j) => j.scheduledStartUtc == null).toList();

  final byDay = <DateTime, List<Job>>{};
  for (final job in scheduled) {
    byDay.putIfAbsent(dayKey(job), () => []).add(job);
  }
  final days = byDay.keys.toList()
    ..sort((a, b) => newestFirst ? b.compareTo(a) : a.compareTo(b));

  final today = DateTime(now.year, now.month, now.day);
  String labelFor(DateTime day) {
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEEE d MMM').format(day);
  }

  return [
    for (final day in days) TradieDayGroup(labelFor(day), byDay[day]!),
    if (unscheduled.isNotEmpty) TradieDayGroup('Unscheduled', unscheduled),
  ];
}

/// Jobs tab — role-aware:
/// - Homeowner: their posted jobs. FAB is in the nav bar, not here.
/// - Tradie: their assigned/active jobs.
class JobsListScreen extends ConsumerStatefulWidget {
  const JobsListScreen({super.key});

  @override
  ConsumerState<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends ConsumerState<JobsListScreen> {
  _JobFilter _filter = _JobFilter.active;
  _TradieJobFilter _tradieFilter = _TradieJobFilter.today;

  ProviderSubscription<ProfileState>? _profileSub;
  bool _jobsLoadStarted = false;

  /// Selected job for master-detail at ≥744pt.
  String? _selectedJobId;
  String? _selectedJobStatus;

  @override
  void initState() {
    super.initState();
    // The role isn't knowable until the profile arrives — a tradie whose
    // profile is still loading must not be sent down the homeowner path
    // (that previously left them on a spinner or the wrong empty state).
    _profileSub = ref.listenManual(profileViewModelProvider, (_, _) {
      _loadJobsForRole();
    });
    Future.microtask(_loadJobsForRole);
  }

  void _loadJobsForRole() {
    if (_jobsLoadStarted) return;
    final role = ref.read(profileViewModelProvider).profile?['role'];
    if (role == null) return; // wait for the profile listener
    _jobsLoadStarted = true;
    if (role == 1) {
      ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
    } else {
      ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();
    }
  }

  @override
  void dispose() {
    _profileSub?.close();
    super.dispose();
  }

  /// Routes a tradie to the correct screen based on job status.
  /// In wide mode (≥744pt) opens in the master-detail right panel.
  /// In narrow mode pushes the GoRouter route as before.
  void _openTradieJob(BuildContext context, Job job, {required bool isWide}) {
    if (isWide) {
      setState(() {
        _selectedJobId = job.id;
        _selectedJobStatus = job.status;
      });
    } else {
      if (job.status == 'Requested') {
        context.push('/tradie/requests/${job.id}');
      } else {
        context.push('/tradie/jobs/${job.id}');
      }
    }
  }

  /// Opens a homeowner job detail in wide or narrow mode.
  void _openHomeownerJob(BuildContext context, Job job, {required bool isWide}) {
    if (isWide) {
      setState(() {
        _selectedJobId = job.id;
        _selectedJobStatus = job.status;
      });
    } else {
      context.push('/jobs/${job.id}/detail');
    }
  }

  List<Job> _filterTradieJobs(List<Job> jobs, DateTime now) =>
      switch (_tradieFilter) {
        _TradieJobFilter.today =>
          jobs
              .where(
                (j) =>
                    _tradieWorkStatuses.contains(j.status) &&
                    isScheduledOnOrBeforeToday(j, now),
              )
              .toList(),
        _TradieJobFilter.upcoming =>
          jobs
              .where(
                (j) =>
                    _tradieWorkStatuses.contains(j.status) &&
                    !isScheduledOnOrBeforeToday(j, now),
              )
              .toList(),
        _TradieJobFilter.awaitingPayment =>
          jobs
              .where((j) => _tradieAwaitingPaymentStatuses.contains(j.status))
              .toList(),
        _TradieJobFilter.done =>
          jobs.where((j) => j.status == 'Completed').toList(),
        _TradieJobFilter.all => jobs,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);

    final isTradie = profileState.profile?['role'] == 1;
    final now = DateTime.now();

    Future<void> retry() => isTradie
        ? ref.read(jobsViewModelProvider.notifier).loadTradieJobs()
        : ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();

    final jobs = isTradie
        ? _filterTradieJobs(state.jobs, now)
        : state.jobs
              .where(
                (job) => switch (_filter) {
                  _JobFilter.active => !isPastHomeownerJob(job.status),
                  _JobFilter.completed => job.status == 'Completed',
                  _JobFilter.all => true,
                },
              )
              .toList();

    final dayGroups = isTradie
        ? tradieDayGroups(
            jobs,
            now,
            newestFirst:
                _tradieFilter == _TradieJobFilter.done ||
                _tradieFilter == _TradieJobFilter.all,
          )
        : const <TradieDayGroup>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kBreakpointMasterDetail;

        // Build the detail panel widget for the selected job.
        Widget? detailPanel;
        if (_selectedJobId != null) {
          if (isTradie) {
            if (_selectedJobStatus == 'Requested') {
              detailPanel = RequestDetailScreen(
                key: ValueKey('req_detail_$_selectedJobId'),
                requestId: _selectedJobId!,
                embedded: true,
              );
            } else {
              detailPanel = TradieJobDetailScreen(
                key: ValueKey('tradie_job_$_selectedJobId'),
                jobId: _selectedJobId!,
                embedded: true,
              );
            }
          } else {
            detailPanel = HomeownerJobDetailScreen(
              key: ValueKey('job_detail_$_selectedJobId'),
              jobId: _selectedJobId!,
              embedded: true,
            );
          }
        }

        final masterList = _buildMasterList(
          context: context,
          state: state,
          jobs: jobs,
          dayGroups: dayGroups,
          isTradie: isTradie,
          isWide: isWide,
          retry: retry,
        );

        final scaffold = Scaffold(
          appBar: FixoGradientAppBar(title: 'My Jobs', showBack: false),
          body: MasterDetailLayout(
            master: masterList,
            detail: detailPanel ?? const SizedBox.shrink(),
            detailVisible: _selectedJobId != null,
            emptyDetail: const _JobsEmptyDetail(),
          ),
        );

        return scaffold;
      },
    );
  }

  Widget _buildMasterList({
    required BuildContext context,
    required JobsState state,
    required List<Job> jobs,
    required List<TradieDayGroup> dayGroups,
    required bool isTradie,
    required bool isWide,
    required Future<void> Function() retry,
  }) {
    if (state.isLoading && state.jobs.isEmpty) {
      return const FixoLoading(label: 'Loading jobs...');
    }
    if (state.error != null && state.jobs.isEmpty) {
      return FixoErrorState(
        message: 'Could not load your jobs. Please try again.',
        onRetry: retry,
      );
    }
    if (state.jobs.isEmpty) {
      return isTradie
          ? const FixoEmptyState(
              icon: Icons.work_off_outlined,
              title: 'No jobs assigned yet',
              subtitle: 'Accept an incoming request to get started.',
            )
          : FixoEmptyState(
              icon: Icons.work_off_outlined,
              title: 'No jobs yet',
              subtitle: 'Post your first job to get matched.',
              actionLabel: 'Post a Job',
              onAction: () => context.push('/jobs/new'),
            );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            if (!isTradie)
              Padding(
                padding: const EdgeInsets.all(Space.s4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in _JobFilter.values)
                      ChoiceChip(
                        label: Text(switch (filter) {
                          _JobFilter.active => 'Active',
                          _JobFilter.completed => 'Completed',
                          _JobFilter.all => 'All',
                        }),
                        selected: _filter == filter,
                        onSelected: (_) =>
                            setState(() => _filter = filter),
                        materialTapTargetSize:
                            MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s3),
                      ),
                  ],
                ),
              ),
            if (isTradie)
              Padding(
                padding: const EdgeInsets.all(Space.s4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in _TradieJobFilter.values)
                      ChoiceChip(
                        label: Text(switch (filter) {
                          _TradieJobFilter.today => 'Today',
                          _TradieJobFilter.upcoming => 'Upcoming',
                          _TradieJobFilter.awaitingPayment =>
                            'Awaiting payment',
                          _TradieJobFilter.done => 'Done',
                          _TradieJobFilter.all => 'All',
                        }),
                        selected: _tradieFilter == filter,
                        onSelected: (_) =>
                            setState(() => _tradieFilter = filter),
                        materialTapTargetSize:
                            MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s3),
                      ),
                  ],
                ),
              ),
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.error != null) JobsRefreshNotice(onRetry: retry),
            Expanded(
              child: RefreshIndicator(
                onRefresh: retry,
                child: jobs.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          FixoEmptyState(
                            icon: Icons.work_off_outlined,
                            title: isTradie
                                ? switch (_tradieFilter) {
                                    _TradieJobFilter.today =>
                                      'Nothing scheduled today',
                                    _TradieJobFilter.upcoming =>
                                      'No upcoming jobs',
                                    _TradieJobFilter.awaitingPayment =>
                                      'No jobs waiting on payment',
                                    _TradieJobFilter.done =>
                                      'No completed jobs yet',
                                    _TradieJobFilter.all =>
                                      'No jobs assigned yet',
                                  }
                                : _filter == _JobFilter.completed
                                ? 'No completed jobs yet'
                                : 'No active jobs',
                            subtitle:
                                'Choose All to see your other jobs.',
                            actionLabel: 'View all jobs',
                            onAction: () => setState(
                              () => isTradie
                                  ? _tradieFilter = _TradieJobFilter.all
                                  : _filter = _JobFilter.all,
                            ),
                          ),
                        ],
                      )
                    : isTradie
                    ? _tradieList(dayGroups, isWide: isWide)
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s4, Space.gutter, Space.navClearance),
                        itemCount: jobs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Space.s3),
                        itemBuilder: (_, i) => isWide
                            ? GestureDetector(
                                onTap: () => _openHomeownerJob(
                                  context,
                                  jobs[i],
                                  isWide: true,
                                ),
                                child: homeownerJobSummary(
                                  context,
                                  jobs[i],
                                ),
                              )
                            : homeownerJobSummary(context, jobs[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grouped tradie list — local-day headers over `ModernJobCard` rows.
  Widget _tradieList(List<TradieDayGroup> groups, {required bool isWide}) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s1, Space.gutter, Space.navClearance),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: Space.s2, bottom: Space.s2),
            child: Text(
              group.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FW.bold,
              ),
            ),
          ),
          for (final job in group.jobs)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s3),
              child: _tradieJobCard(job, isWide: isWide),
            ),
        ],
      ],
    );
  }

  Widget _tradieJobCard(Job job, {required bool isWide}) {
    final presentation = JobStatusPresentation.forStatus(job.status);
    final scheduled = job.scheduledStartUtc?.toLocal();
    return ModernJobCard(
      title: job.title,
      category: job.category,
      suburb: job.suburb,
      reference: '${job.id} · ${job.category}',
      status: presentation.label,
      statusKind: presentation.kind,
      priceLabel: job.totalAmount != null
          ? '\$${job.totalAmount!.toStringAsFixed(2)}'
          : null,
      scheduleLabel: scheduled != null
          ? DateFormat.jm().format(scheduled)
          : null,
      actionLabel: presentation.tradieAction,
      progressStatus: job.status,
      onTap: () => _openTradieJob(context, job, isWide: isWide),
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────────────────────

class _JobsEmptyDetail extends StatelessWidget {
  const _JobsEmptyDetail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.work_outline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Space.s3),
          Text(
            'Select a job to view details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
