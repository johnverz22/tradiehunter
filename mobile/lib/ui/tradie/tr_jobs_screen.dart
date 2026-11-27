import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';
import '../shared/th_shell.dart' show kThBreakpointMasterDetail;
import 'tr_home_mapper.dart';
import 'tr_job_card.dart';
import 'tr_job_router.dart';

enum TrJobFilter { today, upcoming, awaitingPayment, done, all }

const Set<String> _workStatuses = {
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
};

const Set<String> _awaitingPaymentStatuses = {
  'AwaitingPayment',
  'PaymentReview',
};

class TrDayGroup {
  const TrDayGroup(this.label, this.jobs);
  final String label;
  final List<Job> jobs;
}

List<Job> filterTradieJobs(List<Job> jobs, TrJobFilter filter, DateTime now) {
  return switch (filter) {
    TrJobFilter.today =>
      jobs
          .where(
            (j) =>
                _workStatuses.contains(j.status) &&
                thIsScheduledOnOrBeforeToday(j, now),
          )
          .toList(),
    TrJobFilter.upcoming =>
      jobs
          .where(
            (j) =>
                _workStatuses.contains(j.status) &&
                !thIsScheduledOnOrBeforeToday(j, now),
          )
          .toList(),
    TrJobFilter.awaitingPayment =>
      jobs.where((j) => _awaitingPaymentStatuses.contains(j.status)).toList(),
    TrJobFilter.done => jobs.where((j) => j.status == 'Completed').toList(),
    TrJobFilter.all => jobs,
  };
}

List<TrDayGroup> groupTradieJobsByDay(
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
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE d MMM').format(day);
  }

  return [
    for (final day in days) TrDayGroup(labelFor(day), byDay[day]!),
    if (unscheduled.isNotEmpty) TrDayGroup('Unscheduled', unscheduled),
  ];
}

class TrJobsScreen extends ConsumerStatefulWidget {
  const TrJobsScreen({super.key, @visibleForTesting this.wideLayoutOverride});

  /// Test seam: forces the wide master-detail layout on/off. Null (production)
  /// enables it whenever the window is at least [kThBreakpointMasterDetail].
  final bool? wideLayoutOverride;

  @override
  ConsumerState<TrJobsScreen> createState() => _TrJobsScreenState();
}

class _TrJobsScreenState extends ConsumerState<TrJobsScreen> {
  TrJobFilter _filter = TrJobFilter.today;

  /// Wide master-detail: the job currently shown in the right pane.
  /// Non-null only when [kThBreakpointMasterDetail] width is reached.
  String? _selectedJobId;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(jobsViewModelProvider.notifier).loadTradieJobs(),
    );
  }

  void _openJob(BuildContext context, Job job, {required bool isWide}) {
    final id = job.id.toString();
    if (isWide && job.status != 'Requested') {
      // Wide layout: show detail in the right pane, no push.
      setState(() => _selectedJobId = id);
    } else if (job.status == 'Requested') {
      context.push('/tradie/requests/$id');
    } else {
      context.push('/tradie/jobs/$id');
    }
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _page(ctx)),
  );

  Widget _page(BuildContext context) {
    final state = ref.watch(jobsViewModelProvider);
    final notifier = ref.read(jobsViewModelProvider.notifier);
    final now = DateTime.now();

    final filtered = filterTradieJobs(state.jobs, _filter, now);
    final groups = groupTradieJobsByDay(
      filtered,
      now,
      newestFirst: _filter == TrJobFilter.done || _filter == TrJobFilter.all,
    );

    final c = context.th;

    return THScaffold(
      appBar: const THAppBar(title: 'My jobs'),
      scrollable: false,
      body: Builder(
        builder: (context) {
          // Window width, not the pane's constraints: THScaffold's gutter
          // would otherwise make an exactly-744 window fall short.
          final isWide =
              (widget.wideLayoutOverride ?? true) &&
              MediaQuery.sizeOf(context).width >= kThBreakpointMasterDetail;

          // On resize from wide→narrow, clear selection so it isn't stale.
          if (!isWide && _selectedJobId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedJobId = null);
            });
          }

          final masterPanel = Column(
            key: const Key('tr_jobs_master_panel'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s3),
                child: THCard(
                  padding: Space.s3,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              THText(
                                'Available projects',
                                style: THTextStyle.title,
                              ),
                              THText(
                                'Browse open projects nearby and send a quote',
                                style: THTextStyle.meta,
                                tone: THTone.soft,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.s2),
                        THButton(
                          key: const Key('open_available_jobs_button'),
                          label: 'Browse',
                          kind: THButtonKind.accent,
                          size: THButtonSize.sm,
                          fullWidth: false,
                          onPressed: () =>
                              context.push('/tradie/available-jobs'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                key: const Key('tradie_filter_row'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: Space.s3),
                child: Row(
                  spacing: Space.s2,
                  children: [
                    for (final f in TrJobFilter.values)
                      ChoiceChip(
                        label: Text(_filterLabel(f)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() {
                          _filter = f;
                          _selectedJobId = null;
                        }),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _body(context, state, notifier, groups, isWide: isWide),
              ),
            ],
          );

          if (!isWide) return masterPanel;

          // ── Wide: master list + detail pane ───────────────────────────────
          final detailPane = _selectedJobId != null
              ? ThEmbeddedPane(
                  child: TrJobRouter(
                    key: ValueKey('tr_job_detail_$_selectedJobId'),
                    jobId: _selectedJobId!,
                  ),
                )
              : const _TrJobsEmptyDetail();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: masterPanel),
              VerticalDivider(width: 1, color: c.line),
              Expanded(child: detailPane),
            ],
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    JobsState state,
    JobsNotifier notifier,
    List<TrDayGroup> groups, {
    required bool isWide,
  }) {
    if (state.isLoading && state.jobs.isEmpty) {
      return ThStateView.loading();
    }
    if (state.error != null && state.jobs.isEmpty) {
      return ThStateView.error(
        message: state.error!,
        onRetry: () => notifier.loadTradieJobs(),
      );
    }
    if (groups.isEmpty) {
      return ThStateView.empty(
        icon: Icons.work_outline_rounded,
        title: _emptyTitle(_filter),
        body: _emptyMessage(_filter),
        actionLabel: _filter != TrJobFilter.all ? 'Show all jobs' : null,
        onAction: _filter != TrJobFilter.all
            ? () => setState(() => _filter = TrJobFilter.all)
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () => notifier.loadTradieJobs(),
      child: ListView(
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: Space.s2, bottom: Space.s2),
              child: THText(
                group.label.toUpperCase(),
                style: THTextStyle.label,
                tone: THTone.soft,
              ),
            ),
            for (final job in group.jobs) ...[
              TrJobCard(
                job: job,
                onTap: () => _openJob(context, job, isWide: isWide),
              ),
              const SizedBox(height: Space.s2_5),
            ],
          ],
        ],
      ),
    );
  }

  static String _filterLabel(TrJobFilter f) => switch (f) {
    TrJobFilter.today => 'Today',
    TrJobFilter.upcoming => 'Upcoming',
    TrJobFilter.awaitingPayment => 'Awaiting payment',
    TrJobFilter.done => 'Done',
    TrJobFilter.all => 'All',
  };

  static String _emptyTitle(TrJobFilter f) => switch (f) {
    TrJobFilter.today => 'Nothing scheduled today',
    TrJobFilter.upcoming => 'No upcoming jobs',
    TrJobFilter.awaitingPayment => 'No jobs awaiting payment',
    TrJobFilter.done => 'No completed jobs yet',
    TrJobFilter.all => 'No jobs yet',
  };

  static String _emptyMessage(TrJobFilter f) => switch (f) {
    TrJobFilter.today => 'Check Upcoming or All to see other jobs.',
    TrJobFilter.upcoming => 'Accepted jobs for future days will appear here.',
    TrJobFilter.awaitingPayment =>
      'Completed jobs waiting on payment will appear here.',
    TrJobFilter.done => 'Finished jobs will be listed here.',
    TrJobFilter.all => 'Jobs you accept or are requested for will appear here.',
  };
}

/// Right-pane placeholder shown in wide layout before a job is selected.
class _TrJobsEmptyDetail extends StatelessWidget {
  const _TrJobsEmptyDetail();

  @override
  Widget build(BuildContext context) => ThStateView.empty(
    icon: Icons.work_outline_rounded,
    title: 'Select a job',
    body: 'Tap a job on the left to view its details here.',
  );
}
