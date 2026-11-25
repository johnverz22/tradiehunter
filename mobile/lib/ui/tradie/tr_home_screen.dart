// TradieHomeScreen: v2 tradie home (migration plan 5.1, id `tr_home`, route
// `/tradie`).
//
// Hand-owned port of views/tradie/tradie_dashboard_view.dart. Same data flow:
// jobsViewModelProvider.loadTradieJobs, pending offers per Requested job,
// accept/decline through the shared OfferResponder (one POST per tap),
// availability through profileViewModelProvider.updateAvailability, SignalR
// (new match, offer lifecycle, status, reconnect) and an app-resume refresh.
// Same Keys: `tradie_dashboard`, `availability_button`, `stat_tile_*`,
// `today_card_cta`. Hosted inside ThShell, which supplies the dock.
//
// Gaps (plan G-13/G-14): no response-rate tile (no data); weekly net maps the
// server contract 1:1 and is never summed from jobs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../viewmodels/auth_viewmodel.dart' show resolveBaseUrl;
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/offer_responder.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import '../feedback/th_state_view.dart';
import 'tr_home_mapper.dart';
import 'tr_home_parts.dart';

class TradieHomeScreen extends ConsumerStatefulWidget {
  const TradieHomeScreen({super.key});

  static const String route = '/tradie';

  @override
  ConsumerState<TradieHomeScreen> createState() => _TradieHomeScreenState();
}

class _TradieHomeScreenState extends ConsumerState<TradieHomeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<NewJobMatchEvent>? _matchSub;
  StreamSubscription<JobStatusEvent>? _statusSub;
  StreamSubscription<OfferLifecycleEvent>? _offerSub;
  StreamSubscription<void>? _reconnectSub;

  /// Pending offers by job id. A fetched `null` means the offer lapsed; a job
  /// missing from the map is still loading.
  final Map<String, JobOffer?> _pendingOffers = {};
  bool _offersLoaded = false;

  /// Job ids with a busy accept/decline control (the OfferResponder owns the
  /// real one-command-per-job guard).
  final Set<String> _responding = {};

  bool _availabilityLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      unawaited(_refreshAll());
      unawaited(_initSignalR());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshJobsAndOffers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchSub?.cancel();
    _offerSub?.cancel();
    _statusSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
    if (!mounted) return;
    unawaited(ref.read(tradieEarningsProvider.notifier).load());
    await _loadPendingOffers();
  }

  Future<void> _loadPendingOffers() async {
    if (!mounted) return;
    setState(() => _offersLoaded = false);
    final repo = ref.read(jobsRepositoryProvider);
    final leads = ref
        .read(jobsViewModelProvider)
        .jobs
        .where((j) => j.status == 'Requested')
        .toList();
    final entries = await Future.wait(
      leads.map((j) async => MapEntry(j.id, await repo.getPendingOffer(j.id))),
    );
    if (!mounted) return;
    setState(() {
      _pendingOffers
        ..clear()
        ..addEntries(entries);
      _offersLoaded = true;
    });
  }

  void _refreshJobsAndOffers() {
    unawaited(
      ref
          .read(jobsViewModelProvider.notifier)
          .loadTradieJobs()
          .then((_) => _loadPendingOffers())
          .catchError((Object e, StackTrace s) {
            // The view model reports its own errors into state.
            debugPrint('tr_home refresh failed: $e');
          }),
    );
  }

  Future<void> _initSignalR() async {
    final hub = ref.read(jobHubClientProvider);
    await hub.connect(baseUrl: resolveBaseUrl());
    if (!mounted) return;

    _matchSub = hub.onNewJobMatch.listen((event) {
      if (!mounted) return;
      _refreshJobsAndOffers();
      THNotice.push(
        context,
        title: NoticeCopy.newJobRequest(event.title),
        body: event.title,
      );
    });

    _offerSub = hub.onOfferLifecycle.listen((event) {
      if (!mounted) return;
      switch (event.eventType) {
        case OfferEventType.created:
          _refreshJobsAndOffers();
          THNotice.info(
            context,
            'New Job Offer: ${event.jobTitle ?? "New Request"}',
          );
        case OfferEventType.expired ||
            OfferEventType.declined ||
            OfferEventType.accepted:
          _pendingOffers.remove(event.jobId);
          _refreshJobsAndOffers();
        case OfferEventType.unknown:
          break;
      }
    });

    _statusSub = hub.onJobStatusChanged.listen((e) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(e.jobId, e.status);
      // A completion creates a payout row: refresh the weekly summary.
      if (e.status == 'Completed' || e.status == 'AwaitingConfirmation') {
        unawaited(ref.read(tradieEarningsProvider.notifier).load());
      }
    });

    _reconnectSub = hub.onReconnected.listen((_) {
      if (!mounted) return;
      _refreshJobsAndOffers();
      unawaited(ref.read(tradieEarningsProvider.notifier).load());
    });
  }

  Future<void> _respondToLead(Job job, {required bool accept}) async {
    final offer = _pendingOffers[job.id];
    if (offer == null || _responding.contains(job.id)) return;
    setState(() => _responding.add(job.id));
    final outcome = await ref
        .read(offerResponderProvider)
        .respond(jobId: job.id, offer: offer, accept: accept);
    if (!mounted) return;
    setState(() => _responding.remove(job.id));
    switch (outcome) {
      case OfferResponseOutcome.success:
        _refreshJobsAndOffers();
      case OfferResponseOutcome.rejected:
        THNotice.error(
          context,
          accept
              ? 'Could not accept this offer — it may have expired.'
              : 'Could not decline this offer.',
        );
        _refreshJobsAndOffers();
      case OfferResponseOutcome.alreadyInFlight:
        break;
    }
  }

  /// Optimistic availability toggle with an in-flight guard. Going offline
  /// with leads or booked work asks first.
  Future<void> _toggleAvailability(bool currentlyOnline) async {
    if (_availabilityLoading) return;
    if (currentlyOnline &&
        trNeedsOfflineConfirm(ref.read(jobsViewModelProvider).jobs)) {
      final confirmed = await showTrGoOfflineSheet(
        context,
        themeMode: ref.read(themeModeProvider),
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _availabilityLoading = true);
    var failed = false;
    try {
      final notifier = ref.read(profileViewModelProvider.notifier);
      final errorBefore = ref.read(profileViewModelProvider).error;
      await notifier.updateAvailability(!currentlyOnline);
      if (!mounted) return;
      // The view model swallows exceptions into state.error: compare.
      final errorAfter = ref.read(profileViewModelProvider).error;
      failed = errorAfter != null && errorAfter != errorBefore;
    } catch (e) {
      debugPrint('tr_home availability failed: $e');
      failed = true;
    }
    if (!mounted) return;
    setState(() => _availabilityLoading = false);
    if (failed) {
      THNotice.error(
        context,
        NoticeCopy.statusUpdateFailed,
        onRetry: () => unawaited(_toggleAvailability(currentlyOnline)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final earningsState = ref.watch(tradieEarningsProvider);
    final profile = profileState.profile;
    final online = profile?['isAvailable'] as bool? ?? true;
    final groups = TrHomeGroups.from(jobsState.jobs, DateTime.now());

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final body = (jobsState.isLoading && jobsState.jobs.isEmpty)
              ? const ThStateView.loading(label: 'Loading your jobs...')
              : (jobsState.error != null && jobsState.jobs.isEmpty)
              ? ThStateView.error(
                  message: 'Could not load your jobs. Please try again.',
                  onRetry: () => unawaited(_refreshAll()),
                )
              : RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      Sizes.gutter,
                      Space.s1_5,
                      Sizes.gutter,
                      thDockClearance(context),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _content(
                          jobsState: jobsState,
                          profile: profile,
                          profileLoading: profileState.isLoading,
                          earningsState: earningsState,
                          groups: groups,
                          online: online,
                        ),
                      ),
                    ),
                  ),
                );
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            ),
            child: Scaffold(
              key: const Key('tradie_dashboard'),
              backgroundColor: context.th.paper,
              body: SafeArea(bottom: false, child: body),
            ),
          );
        },
      ),
    );
  }

  Widget _content({
    required JobsState jobsState,
    required Map<String, dynamic>? profile,
    required bool profileLoading,
    required TradieEarningsState earningsState,
    required TrHomeGroups groups,
    required bool online,
  }) {
    void openJob(Job j) => context.push('/tradie/jobs/${j.id}');
    final firstName = (profile?['firstName'] as String?)?.trim();
    final rating = trRating(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        TrHomeHero(
          greeting: thTradieGreeting(firstName),
          online: online,
          switchEnabled: !_availabilityLoading,
          onToggle: () => unawaited(_toggleAvailability(online)),
          net: trHeroNet(earningsState),
          rating: rating,
          onRetryEarnings: () =>
              unawaited(ref.read(tradieEarningsProvider.notifier).load()),
        ),
        if (!online) const TrPausedBanner(),
        TrStatTiles(
          weekJobs: trWeekJobCount(jobsState.jobs, DateTime.now()),
          pending: trPendingNet(earningsState),
          rating: rating,
        ),
        if (trShowVerificationBanner(
          profileLoading: profileLoading,
          isVerified: profile?['isVerified'] as bool?,
        ))
          TrVerificationBanner(
            onReview: () => context.push('/tradie/onboarding'),
          ),
        TrLeadsSection(
          leads: groups.leads,
          pendingOffers: _pendingOffers,
          offersLoaded: _offersLoaded,
          hasError: jobsState.error != null,
          isFirstLoad: jobsState.isLoading && jobsState.jobs.isEmpty,
          responding: _responding,
          onAccept: (j) => unawaited(_respondToLead(j, accept: true)),
          onDecline: (j) => unawaited(_respondToLead(j, accept: false)),
          onOpen: (j) => context.push('/tradie/requests/${j.id}'),
          onExpired: _refreshJobsAndOffers,
          onRetry: () => unawaited(_refreshAll()),
        ),
        if (groups.overdue.isNotEmpty) ...[
          TrSectionLabel('Overdue', count: groups.overdue.length, accent: true),
          TrJobCards(jobs: groups.overdue, overdue: true, onTap: openJob),
        ],
        TrSectionLabel('Today', count: groups.today.length),
        TrTodaySection(
          jobs: groups.today,
          online: online,
          onTap: openJob,
          onGoOnline: () => unawaited(_toggleAvailability(online)),
        ),
        if (groups.upcoming.isNotEmpty)
          TrCollapsedSection(
            title: 'Upcoming',
            jobs: groups.upcoming,
            onTap: openJob,
          ),
        if (groups.awaitingPayment.isNotEmpty)
          TrCollapsedSection(
            title: 'Awaiting homeowner payment',
            jobs: groups.awaitingPayment,
            onTap: openJob,
          ),
        if (groups.disputed.isNotEmpty)
          TrCollapsedSection(
            title: 'Needs attention',
            jobs: groups.disputed,
            initiallyExpanded: true,
            onTap: openJob,
          ),
      ],
    );
  }
}
