// ThHomeScreen: v2 homeowner home (migration plan 4.1 #1, id `ho_home`,
// route `/home`).
//
// Hand-owned port of views/homeowner/homeowner_dashboard_view.dart. Same data
// flow: jobsViewModelProvider.loadHomeownerJobs on entry and pull-to-refresh,
// SignalR job-status events applied through applyStatusUpdate, first name from
// profileViewModelProvider. Same grouping (attention / booked / active / past),
// same card navigation (see ho_job_navigation.dart) and the same Key
// `homeowner_dashboard`. Hosted inside ThShell, which supplies the dock.
//
// API gaps (plan §4.1, G-3 / G-5): the "Needs your attention" hero is derived
// client-side from job statuses; the mockup's "Top rated near you" list and
// per-tradie rating/distance have no source on this screen's endpoints, so
// that section is omitted rather than invented.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../viewmodels/auth_viewmodel.dart' show resolveBaseUrl;
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';
import 'ho_home_mapper.dart';
import 'ho_job_card.dart';
import 'ho_job_navigation.dart';

/// Quick categories shown as tiles. Labels double as the `/find-tradie` seed
/// (the browse screen matches categories case-insensitively).
const List<(IconData, String)> kThHomeCategories = [
  (Icons.water_drop_rounded, 'Plumbing'),
  (Icons.bolt_rounded, 'Electrical'),
  (Icons.hardware_rounded, 'Carpentry'),
  (Icons.format_paint_rounded, 'Painting'),
  (Icons.eco_rounded, 'Gardening'),
  (Icons.auto_awesome_rounded, 'Cleaning'),
  (Icons.home_rounded, 'Roofing'),
];

class ThHomeScreen extends ConsumerStatefulWidget {
  const ThHomeScreen({super.key});

  @override
  ConsumerState<ThHomeScreen> createState() => _ThHomeScreenState();
}

class _ThHomeScreenState extends ConsumerState<ThHomeScreen> {
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
    await hub.connect(baseUrl: resolveBaseUrl());
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

  Future<void> _reload() =>
      ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsViewModelProvider);
    final profile = ref.watch(profileViewModelProvider).profile;
    final firstName = (profile?['firstName'] as String? ?? '').trim();
    final groups = HoHomeGroups.from(jobsState.jobs);
    final hero = thAttentionHero(groups.attention);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;

          Widget body;
          if (jobsState.isLoading && jobsState.jobs.isEmpty) {
            body = const ThStateView.loading(label: 'Loading your jobs...');
          } else if (jobsState.error != null && jobsState.jobs.isEmpty) {
            body = ThStateView.error(
              message: 'Could not load your jobs. Please try again.',
              onRetry: _reload,
            );
          } else {
            body = RefreshIndicator(
              onRefresh: _reload,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Sizes.gutter,
                  Space.s1_5,
                  Sizes.gutter,
                  Sizes.dockClearance,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _Content(
                      firstName: firstName,
                      hasRefreshError: jobsState.error != null,
                      onRetry: _reload,
                      hero: hero,
                      groups: groups,
                      isEmpty: jobsState.jobs.isEmpty,
                      showPast: _showPast,
                      onTogglePast: () =>
                          setState(() => _showPast = !_showPast),
                    ),
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            key: const Key('homeowner_dashboard'),
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
    required this.firstName,
    required this.hasRefreshError,
    required this.onRetry,
    required this.hero,
    required this.groups,
    required this.isEmpty,
    required this.showPast,
    required this.onTogglePast,
  });

  final String firstName;
  final bool hasRefreshError;
  final Future<void> Function() onRetry;
  final HoAttentionHero? hero;
  final HoHomeGroups groups;
  final bool isEmpty;
  final bool showPast;
  final VoidCallback onTogglePast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        _Greeting(firstName: firstName),
        if (hasRefreshError) _RefreshNotice(onRetry: onRetry),
        if (hero != null) _AttentionHero(hero: hero!),
        Semantics(
          identifier: 'home_search',
          child: InkWell(
            key: const Key('home_search'),
            borderRadius: BorderRadius.circular(Radii.control),
            onTap: () => context.push('/find-tradie'),
            child: Semantics(
              button: true,
              label: 'Search for a tradie',
              excludeSemantics: true,
              child: const THField(
                value: 'What needs doing?',
                icon: Icons.search_rounded,
                placeholder: true,
              ),
            ),
          ),
        ),
        const _CategoryGrid(),
        if (isEmpty) ...[
          const _EmptyPost(),
        ] else ...[
          if (groups.attention.length > 1)
            _Section(
              title: 'Needs your attention',
              jobs: groups.attention.skip(1).toList(),
            ),
          if (groups.booked.isNotEmpty)
            _Section(title: 'Booked', jobs: groups.booked),
          if (groups.active.isNotEmpty)
            _Section(title: 'Active jobs', jobs: groups.active),
          if (groups.past.isNotEmpty) ...[
            Semantics(
              button: true,
              expanded: showPast,
              child: THButton(
                key: const Key('home_toggle_past'),
                label: 'Past jobs (${groups.past.length})',
                kind: THButtonKind.ghost,
                size: THButtonSize.sm,
                onPressed: onTogglePast,
              ),
            ),
            if (showPast) ..._jobCards(groups.past),
          ],
          THButton(
            key: const Key('home_see_all'),
            label: 'See all jobs',
            kind: THButtonKind.ghost,
            size: THButtonSize.sm,
            onPressed: () => context.go('/jobs'),
          ),
        ],
      ],
    );
  }
}

List<Widget> _jobCards(List<Job> jobs) => [
  for (final j in jobs) HoJobCard(key: ValueKey(j.id), job: j),
];

class _Greeting extends StatelessWidget {
  const _Greeting({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final hasName = firstName.isNotEmpty;
    return Row(
      key: const Key('homeowner_hero'),
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: Space.s3,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasName) ...[
                THText('Kia ora,', style: THTextStyle.meta, tone: THTone.soft),
                THText(firstName, style: THTextStyle.h1),
              ] else
                THText('Kia ora', style: THTextStyle.h1),
            ],
          ),
        ),
        THIconButton(
          icon: Icons.notifications_rounded,
          kind: THButtonKind.secondary,
          dot: true,
          semanticLabel: 'Notifications',
          onPressed: () => context.push('/notifications'),
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
              key: const Key('home_retry'),
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

class _AttentionHero extends StatelessWidget {
  const _AttentionHero({required this.hero});
  final HoAttentionHero hero;

  @override
  Widget build(BuildContext context) {
    return THHero(
      children: [
        const THText(
          'NEEDS YOUR ATTENTION',
          style: THTextStyle.label,
          tone: THTone.gold,
        ),
        const SizedBox(height: Space.s2),
        THText(hero.headline, style: THTextStyle.h2, tone: THTone.onHero),
        THText(hero.subtitle, style: THTextStyle.meta, tone: THTone.onHeroSoft),
        const SizedBox(height: Space.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: hero.amountLabel == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        THText(
                          hero.amountLabel!,
                          style: THTextStyle.moneyLg,
                          tone: THTone.onHero,
                        ),
                        const THText(
                          'Incl. GST',
                          style: THTextStyle.meta,
                          tone: THTone.onHeroSoft,
                          size: 11.5,
                        ),
                      ],
                    ),
            ),
            THButton(
              key: const Key('home_hero_action'),
              label: hero.actionLabel,
              kind: THButtonKind.inverse,
              size: THButtonSize.sm,
              fullWidth: false,
              onPressed: () => thOpenHomeownerJob(context, hero.job),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, VoidCallback onTap) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: Key('home_category_$label'),
        borderRadius: BorderRadius.circular(Radii.tile),
        onTap: onTap,
        child: THTile(icon, label: label),
      ),
    );

    return THGrid(
      columns: 4,
      spacing: Space.s2_5,
      children: [
        for (final (icon, label) in kThHomeCategories)
          tile(icon, label, () => context.push('/find-tradie', extra: label)),
        tile(
          Icons.more_horiz_rounded,
          'More',
          () => context.push('/categories'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.jobs});
  final String title;
  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        const SizedBox(height: Space.s1),
        Semantics(header: true, child: THText(title, style: THTextStyle.title)),
        ..._jobCards(jobs),
      ],
    );
  }
}

class _EmptyPost extends StatelessWidget {
  const _EmptyPost();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        const SizedBox(height: Space.s2),
        const THText(
          'Find a tradie you can trust',
          style: THTextStyle.h2,
          align: TextAlign.center,
        ),
        const THText(
          'Describe your job and get matched with a verified local in minutes.',
          style: THTextStyle.body,
          tone: THTone.soft,
          align: TextAlign.center,
        ),
        THButton(
          key: const Key('home_post_job'),
          label: 'Post a job',
          kind: THButtonKind.accent,
          onPressed: () => context.push('/jobs/new'),
        ),
      ],
    );
  }
}
