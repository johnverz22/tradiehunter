// ThJobsScreen: v2 homeowner jobs list (migration plan 4.1 #2, id `ho_jobs`,
// route `/jobs`).
//
// Hand-owned port of the homeowner branch of views/jobs/jobs_list_screen.dart.
// Same data flow: jobsViewModelProvider.loadHomeownerJobs on entry and
// pull-to-refresh; Active / Completed / All filter; loading, error, empty and
// refresh-error states; card tap navigation via ho_job_navigation.dart (routes
// unchanged, plan 4.4). Hosted inside ThShell, which supplies the dock.
//
// The route is shared with tradies, so app_router.dart only builds this screen
// for non-tradie roles (the tradie list keeps the v1 screen until Phase 5).
//
// Known deviation: v1 showed a master-detail panel at >= 744pt (embedded v1
// job detail). That panel needs the v2 job detail (plan 4.2) and the wide
// layout (D-4); until then wide screens use the narrow push navigation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';
import 'ho_job_card.dart';
import 'ho_jobs_mapper.dart';

/// Role gate for the shared `/jobs` route. Homeowners get [ThJobsScreen];
/// tradies get [tradieFallback] (the v1 list, ported in Phase 5). While the
/// profile is still loading the role is unknown, so a placeholder is shown:
/// a tradie must never trigger the homeowner jobs request (same rule as v1).
class ThJobsRoute extends ConsumerWidget {
  const ThJobsRoute({super.key, required this.tradieFallback});

  final Widget tradieFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileViewModelProvider);
    final role = profile.profile?['role'];
    if (role == 1) return tradieFallback;
    if (role == null) {
      final failed = profile.error != null && !profile.isLoading;
      return ThScope(
        themeMode: ref.watch(themeModeProvider),
        child: Builder(
          builder: (context) => Scaffold(
            key: const Key('homeowner_jobs_pending'),
            backgroundColor: context.th.paper,
            body: SafeArea(
              bottom: false,
              child: failed
                  ? ThStateView.error(
                      message: 'Could not load your jobs. Please try again.',
                      onRetry: () => ref
                          .read(profileViewModelProvider.notifier)
                          .loadProfile(),
                    )
                  : const ThStateView.loading(label: 'Loading jobs...'),
            ),
          ),
        ),
      );
    }
    return const ThJobsScreen();
  }
}

class ThJobsScreen extends ConsumerStatefulWidget {
  const ThJobsScreen({super.key});

  @override
  ConsumerState<ThJobsScreen> createState() => _ThJobsScreenState();
}

class _ThJobsScreenState extends ConsumerState<ThJobsScreen> {
  HoJobsFilter _filter = HoJobsFilter.active;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs(),
    );
  }

  Future<void> _reload() =>
      ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobsViewModelProvider);
    final jobs = thFilterHomeownerJobs(state.jobs, _filter);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;

          Widget body;
          if (state.isLoading && state.jobs.isEmpty) {
            body = const ThStateView.loading(label: 'Loading jobs...');
          } else if (state.error != null && state.jobs.isEmpty) {
            body = ThStateView.error(
              message: 'Could not load your jobs. Please try again.',
              onRetry: _reload,
            );
          } else if (state.jobs.isEmpty) {
            body = ThStateView.empty(
              key: const Key('jobs_empty'),
              icon: Icons.work_off_rounded,
              title: 'No jobs yet',
              body: 'Post your first job to get matched.',
              actionLabel: 'Post a job',
              onAction: () => context.push('/jobs/new'),
            );
          } else {
            body = RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Sizes.gutter,
                  Space.s1_5,
                  Sizes.gutter,
                  Sizes.dockClearance,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _Content(
                        filter: _filter,
                        onFilter: (f) => setState(() => _filter = f),
                        jobs: jobs,
                        isRefreshing: state.isLoading,
                        hasRefreshError: state.error != null,
                        onRetry: _reload,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            key: const Key('homeowner_jobs'),
            backgroundColor: c.paper,
            body: SafeArea(bottom: false, child: body),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.filter,
    required this.onFilter,
    required this.jobs,
    required this.isRefreshing,
    required this.hasRefreshError,
    required this.onRetry,
  });

  final HoJobsFilter filter;
  final ValueChanged<HoJobsFilter> onFilter;
  final List<Job> jobs;
  final bool isRefreshing;
  final bool hasRefreshError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        Semantics(
          header: true,
          child: const THText('My jobs', style: THTextStyle.h1),
        ),
        Semantics(
          label: 'Filter jobs',
          container: true,
          child: THSegmented(
            key: const Key('jobs_filter'),
            items: [for (final f in HoJobsFilter.values) f.label],
            selected: filter.index,
            onSelected: (i) => onFilter(HoJobsFilter.values[i]),
          ),
        ),
        if (isRefreshing)
          LinearProgressIndicator(
            minHeight: 2.0,
            color: context.th.accent,
            backgroundColor: context.th.surfaceAlt,
          ),
        if (hasRefreshError) _RefreshNotice(onRetry: onRetry),
        if (jobs.isEmpty)
          _FilterEmpty(
            filter: filter,
            onViewAll: () => onFilter(HoJobsFilter.all),
          )
        else
          for (final j in jobs)
            HoJobCard(key: ValueKey(j.id), job: j, chatKeyPrefix: 'jobs_chat_'),
      ],
    );
  }
}

class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty({required this.filter, required this.onViewAll});
  final HoJobsFilter filter;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('jobs_filter_empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        const SizedBox(height: Space.s4),
        THText(
          thJobsFilterEmptyTitle(filter),
          style: THTextStyle.h2,
          align: TextAlign.center,
        ),
        const THText(
          'Choose All to see your other jobs.',
          style: THTextStyle.body,
          tone: THTone.soft,
          align: TextAlign.center,
        ),
        THButton(
          key: const Key('jobs_view_all'),
          label: 'View all jobs',
          kind: THButtonKind.secondary,
          onPressed: onViewAll,
        ),
      ],
    );
  }
}

class _RefreshNotice extends StatelessWidget {
  const _RefreshNotice({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return THCard(
      tone: THCardTone.danger,
      padding: Space.s3_5,
      children: [
        Row(
          spacing: Space.s2_5,
          children: [
            const THIcon(
              Icons.wifi_off_rounded,
              size: 18.0,
              tone: THTone.danger,
            ),
            const Expanded(
              child: THText(
                "Couldn't refresh your jobs.",
                style: THTextStyle.meta,
              ),
            ),
            THButton(
              key: const Key('jobs_retry'),
              label: 'Retry',
              kind: THButtonKind.ghost,
              size: THButtonSize.sm,
              fullWidth: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ],
    );
  }
}
