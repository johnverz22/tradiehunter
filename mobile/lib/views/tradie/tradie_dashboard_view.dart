import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/offer_responder.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/modern_job_card.dart';
import '../widgets/job_status_presentation.dart';
import '../widgets/compact_progress_bar.dart';
import '../widgets/offer_countdown.dart';
import '../widgets/fixo_feedback.dart';
import '../widgets/fixo_progress_bar.dart';
import '../../feedback/fixo_notice.dart';


/// Statuses that count as booked work for the tradie — the job is theirs to
/// turn up to (or is already underway / awaiting confirmation).
const _bookedWorkStatuses = {'Booked', 'InProgress', 'AwaitingConfirmation'};

/// Matched but not yet confirmed — the homeowner's payment is still in flight.
const _awaitingPaymentStatuses = {'AwaitingPayment', 'PaymentReview'};

/// True when [job]'s scheduled start falls on or before the end of the local
/// day containing [now]. Jobs with no schedule are treated as due now so a
/// booked job never falls between the Today/Upcoming buckets.
bool isScheduledOnOrBeforeToday(Job job, DateTime now) {
  final scheduled = job.scheduledStartUtc;
  if (scheduled == null) return true;
  final endOfToday = DateTime(now.year, now.month, now.day + 1);
  return scheduled.toLocal().isBefore(endOfToday);
}

/// Tradie dashboard (T19): availability → truthful weekly stats → new leads →
/// today → collapsed upcoming/awaiting-payment. Financial figures come only
/// from the server's weekly earnings contract — never summed from jobs.
class TradieDashboardView extends ConsumerStatefulWidget {
  const TradieDashboardView({super.key});

  @override
  ConsumerState<TradieDashboardView> createState() =>
      _TradieDashboardViewState();
}

class _TradieDashboardViewState extends ConsumerState<TradieDashboardView>
    with WidgetsBindingObserver {
  StreamSubscription? _matchSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _offerSub;
  StreamSubscription? _reconnectSub;

  /// Pending offers keyed by job id — carries the real `expiresAtUtc` for the
  /// lead countdown. A lead job with a fetched `null` offer has already
  /// lapsed; one missing from the map is still loading.
  final Map<String, JobOffer?> _pendingOffers = {};
  bool _offersLoaded = false;

  /// Job ids showing a busy accept/decline control. The shared
  /// [OfferResponder] owns the actual one-command-per-job dispatch guard.
  final Set<String> _responding = {};

  /// Availability toggle state: null = idle, true = loading, false = error.
  bool _availabilityLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      _refreshAll();
      _initSignalR();
    });
  }

  /// Reconcile offers after a resume — the countdown may have lapsed or the
  /// offer timed out server-side while the app was backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshJobsAndOffers();
  }

  Future<void> _refreshAll() async {
    await ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
    unawaited(ref.read(tradieEarningsProvider.notifier).load());
    await _loadPendingOffers();
  }

  /// Fetches the pending offer for each Requested job so lead cards get the
  /// server `expiresAtUtc`. A job that yields no offer has already lapsed.
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
      leads.map(
        (job) async => MapEntry(job.id, await repo.getPendingOffer(job.id)),
      ),
    );
    if (!mounted) return;
    setState(() {
      _pendingOffers
        ..clear()
        ..addEntries(entries);
      _offersLoaded = true;
    });
  }

  Future<void> _initSignalR() async {
    final hub = ref.read(jobHubClientProvider);
    final baseUrl = resolveBaseUrl();
    await hub.connect(baseUrl: baseUrl);

    _matchSub = hub.onNewJobMatch.listen((event) {
      if (mounted) {
        _refreshJobsAndOffers();
        FixoNotice.push(
          context,
          title: NoticeCopy.newJobRequest(event.title),
          body: event.title,
        );
      }
    });

    _offerSub = hub.onOfferLifecycle.listen((event) {
      if (!mounted) return;
      switch (event.eventType) {
        case OfferEventType.created:
          _refreshJobsAndOffers();
          FixoNotice.info(
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
      // A completion creates a payout row — refresh the weekly summary.
      if (e.status == 'Completed' || e.status == 'AwaitingConfirmation') {
        unawaited(ref.read(tradieEarningsProvider.notifier).load());
      }
    });

    _reconnectSub = hub.onReconnected.listen((_) {
      _refreshJobsAndOffers();
      unawaited(ref.read(tradieEarningsProvider.notifier).load());
    });
  }

  void _refreshJobsAndOffers() {
    ref.read(jobsViewModelProvider.notifier).loadTradieJobs().then((_) {
      _loadPendingOffers();
    });
  }

  /// Direct accept/decline through the shared [OfferResponder] command path
  /// (V15-14) — exactly one authorized request per job, and a stale or
  /// rejected response reconciles against the server rather than guessing.
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
        FixoNotice.error(
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

  /// Toggle tradie availability — optimistic update, confirm with the API.
  ///
  /// Going Offline while active work exists shows a confirm sheet first.
  /// Going Online needs no confirm.
  Future<void> _handleAvailabilityToggle(
    bool currentlyOnline,
    List<Job> todayJobs,
  ) async {
    if (_availabilityLoading) return;

    // Going offline with active work → confirm sheet.
    if (currentlyOnline) {
      final hasActive = todayJobs.any(
        (j) => _bookedWorkStatuses.contains(j.status),
      );
      if (hasActive) {
        final confirmed = await _showGoOfflineConfirm();
        if (!confirmed || !mounted) return;
      }
    }

    setState(() => _availabilityLoading = true);
    try {
      final notifier = ref.read(profileViewModelProvider.notifier);
      // Clear any previous error before attempting the toggle.
      final errorBefore = ref.read(profileViewModelProvider).error;
      await notifier.updateAvailability(!currentlyOnline);
      if (!mounted) return;
      // The ViewModel swallows exceptions into state.error — surface them here.
      final errorAfter = ref.read(profileViewModelProvider).error;
      if (errorAfter != null && errorAfter != errorBefore) {
        throw Exception(errorAfter);
      }
    } catch (_) {
      if (!mounted) return;
      FixoNotice.error(
        context,
        NoticeCopy.statusUpdateFailed,
        onRetry: () => _handleAvailabilityToggle(currentlyOnline, todayJobs),
      );
    } finally {
      if (mounted) setState(() => _availabilityLoading = false);
    }
  }

  Future<bool> _showGoOfflineConfirm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      builder: (_) => const _GoOfflineSheet(),
    );
    return result ?? false;
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

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final earningsState = ref.watch(tradieEarningsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    final leads = jobsState.jobs.where((j) => j.status == 'Requested').toList();
    final todayJobs = jobsState.jobs
        .where(
          (j) =>
              _bookedWorkStatuses.contains(j.status) &&
              isScheduledOnOrBeforeToday(j, now),
        )
        .toList();

    // Sort today: action-required statuses first, then by schedule time.
    final sortedToday = [...todayJobs]..sort((a, b) {
        final aReq = JobStatusPresentation.forStatus(a.status).tradieActionRequired;
        final bReq = JobStatusPresentation.forStatus(b.status).tradieActionRequired;
        if (aReq != bReq) return aReq ? -1 : 1;
        final aTime = a.scheduledStartUtc;
        final bTime = b.scheduledStartUtc;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

    final upcomingJobs = jobsState.jobs
        .where(
          (j) =>
              _bookedWorkStatuses.contains(j.status) &&
              !isScheduledOnOrBeforeToday(j, now),
        )
        .toList();
    final awaitingPayment = jobsState.jobs
        .where((j) => _awaitingPaymentStatuses.contains(j.status))
        .toList();
    // The job list DTO carries no disputeStatus field for tradies — the
    // Disputed job status is the only truthful signal available here.
    final disputed = jobsState.jobs
        .where((j) => j.status == 'Disputed')
        .toList();

    // P1-09: only tradies an admin has approved a credential for can be
    // matched, so an unverified tradie needs to see why jobs aren't coming.
    // Gated on !isLoading so the banner doesn't flash before the profile
    // arrives.
    final isVerified = profileState.profile?['isVerified'] as bool?;
    final showVerificationBanner =
        !profileState.isLoading && isVerified != true;

    // P10-18: Read availability from profile, default true
    final isAvailable = profileState.profile?['isAvailable'] as bool? ?? true;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Header is always a dark brand gradient → always white status bar icons.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        key: const Key('tradie_dashboard'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _TradieHero(
                earningsState: earningsState,
                profileState: profileState,
                todayCount: sortedToday.length,
                isOnline: isAvailable,
                availabilityLoading: _availabilityLoading,
                onToggleOnline: () =>
                    _handleAvailabilityToggle(isAvailable, todayJobs),
                onEarningsRetry: () =>
                    ref.read(tradieEarningsProvider.notifier).load(),
              ),
              if (!isAvailable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s4,
                    vertical: Space.s2_5,
                  ),
                  color: DesignTokens.amber.withValues(alpha: Alpha.tintAccent),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pause_circle_outline,
                        size: 18,
                        color: DesignTokens.amber,
                      ),
                      const SizedBox(width: Space.s2),
                      Expanded(
                        child: Text(
                          "You're currently paused. Toggle back on to receive new job offers.",
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeSecondary,
                            color: DesignTokens.inkAccent(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: jobsState.isLoading && jobsState.jobs.isEmpty
                    ? const FixoLoading(label: 'Loading your jobs...')
                    : jobsState.error != null && jobsState.jobs.isEmpty
                    ? FixoErrorState(
                        message: jobsState.error!,
                        onRetry: _refreshAll,
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshAll,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            Space.s5,
                            Space.s4,
                            Space.s5,
                            Space.navClearance,
                          ),
                          children: [
                            if (showVerificationBanner) ...[
                              FixoInfoBanner(
                                icon: Icons.pending_actions_rounded,
                                tone: FixoTone.accent,
                                title: 'Not verified yet',
                                message:
                                    'Upload a licence or insurance so an admin can approve you. '
                                    'Unverified tradies are never matched to jobs.',
                                action: InkWell(
                                  onTap: () =>
                                      context.push('/tradie/onboarding'),
                                  child: Text(
                                    'Review my setup',
                                    style: TextStyle(
                                      fontFamily: DesignTokens.fontMono,
                                      fontSize: DesignTokens.fontSizeMono,
                                      fontWeight: FW.semibold,
                                      color: DesignTokens.inkAccent(isDark),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: Space.s5),
                            ],
                            FixoSectionLabel(
                              label: 'New leads',
                              count: leads.length,
                            ),
                            const SizedBox(height: Space.s2_5),
                            _LeadsSection(
                              leads: leads,
                              pendingOffers: _pendingOffers,
                              offersLoaded: _offersLoaded,
                              responding: _responding,
                              onAccept: (job) =>
                                  _respondToLead(job, accept: true),
                              onDecline: (job) =>
                                  _respondToLead(job, accept: false),
                              onOpen: (job) =>
                                  context.push('/tradie/requests/${job.id}'),
                            ),
                            const SizedBox(height: Space.s6),
                            // Today section label — neutral count badge per spec.
                            _TodaySectionLabel(count: sortedToday.length),
                            const SizedBox(height: Space.s2_5),
                            _TodaySection(
                              jobs: sortedToday,
                              isOnline: isAvailable,
                              onJobTap: (id) =>
                                  context.push('/tradie/jobs/$id'),
                              onGoOnline: () =>
                                  _handleAvailabilityToggle(
                                    isAvailable,
                                    todayJobs,
                                  ),
                            ),
                            if (upcomingJobs.isNotEmpty) ...[
                              const SizedBox(height: Space.s4),
                              _CollapsedJobSection(
                                title: 'Upcoming',
                                jobs: upcomingJobs,
                                onJobTap: (id) =>
                                    context.push('/tradie/jobs/$id'),
                              ),
                            ],
                            if (awaitingPayment.isNotEmpty) ...[
                              const SizedBox(height: Space.s4),
                              _CollapsedJobSection(
                                title: 'Awaiting homeowner payment',
                                jobs: awaitingPayment,
                                onJobTap: (id) =>
                                    context.push('/tradie/jobs/$id'),
                              ),
                            ],
                            if (disputed.isNotEmpty) ...[
                              const SizedBox(height: Space.s4),
                              _CollapsedJobSection(
                                title: 'Needs attention',
                                jobs: disputed,
                                initiallyExpanded: true,
                                onJobTap: (id) =>
                                    context.push('/tradie/jobs/$id'),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Go offline confirm sheet ──────────────────────────────────────────────────

/// Shown when the tradie tries to go offline while active jobs are in flight.
class _GoOfflineSheet extends StatelessWidget {
  const _GoOfflineSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.s5,
          Space.s5,
          Space.s5,
          Space.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Go offline?',
              style: TextStyle(
                fontFamily: DesignTokens.fontDisplay,
                fontSize: DesignTokens.fontSizeH2,
                fontWeight: FW.bold,
                color: DesignTokens.foreground(isDark),
              ),
            ),
            const SizedBox(height: Space.s2),
            Text(
              'You have active or booked jobs. Going offline means no new leads, '
              'but your current jobs are unaffected.',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBody,
                color: DesignTokens.inkSoft(isDark),
              ),
            ),
            const SizedBox(height: Space.s5),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: Sizes.buttonSecondary,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: DesignTokens.borderControl(isDark),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.control),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: SizedBox(
                    height: Sizes.buttonSecondary,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.brand900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.control),
                        ),
                      ),
                      child: const Text('Go offline'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today section label ───────────────────────────────────────────────────────

/// "Today" group header with a neutral count badge — smaller than the amber
/// leads badge to reduce visual weight. Baseline-aligned.
class _TodaySectionLabel extends StatelessWidget {
  final int count;

  const _TodaySectionLabel({required this.count});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'Today',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeCaption,
            fontWeight: FW.semibold,
            letterSpacing: Tracking.wide,
            color: th.textSoft,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: Space.s1_5),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s1_5,
              vertical: Space.s0_5,
            ),
            decoration: BoxDecoration(
              color: DesignTokens.inkSoft(isDark)
                  .withValues(alpha: Alpha.tintStandard),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeTiny,
                fontWeight: FW.semibold,
                color: th.textSoft,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Tradie earnings hero header ────────────────────────────────────────────────

/// Always-dark brand gradient header.
///
/// Layout changes from the previous version:
/// - Status pill button moved to the TOP ROW, right-aligned alongside the
///   "Net this week" label. The sparkline sits behind the net figure at
///   reduced opacity so it does not collide with the button.
/// - Sub-tiles row: exactly TWO tiles (Pending + Rating), equal width via
///   [Expanded] flex. Heights match via [IntrinsicHeight]. The Online tile
///   has been removed.
class _TradieHero extends StatelessWidget {
  final TradieEarningsState earningsState;
  final ProfileState profileState;
  final int todayCount;
  final bool isOnline;
  final bool availabilityLoading;
  final VoidCallback onToggleOnline;
  final VoidCallback onEarningsRetry;

  const _TradieHero({
    required this.earningsState,
    required this.profileState,
    required this.todayCount,
    required this.isOnline,
    required this.availabilityLoading,
    required this.onToggleOnline,
    required this.onEarningsRetry,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final summary = earningsState.summary;

    final String earnedValue;
    final bool isNotAvailable = summary != null && summary.earnedNet == null;
    if (earningsState.error != null && summary == null) {
      earnedValue = 'Unavailable — tap to retry';
    } else if (earningsState.isLoading && summary == null) {
      earnedValue = '…';
    } else if (isNotAvailable) {
      earnedValue = 'Not available';
    } else {
      earnedValue = summary?.earnedNet != null
          ? formatMoney(summary!.earnedNet!)
          : '—';
    }

    final String? pendingValue = summary?.pendingNet != null
        ? formatMoney(summary!.pendingNet!)
        : null;

    final bool hasError = earningsState.error != null && summary == null;

    final num? averageRatingNum =
        profileState.profile?['averageRating'] as num?;
    final int? reviewCount = profileState.profile?['reviewCount'] as int?;
    final bool hasRating =
        reviewCount != null &&
        reviewCount > 0 &&
        averageRatingNum != null &&
        averageRatingNum > 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DesignTokens.brand900, DesignTokens.brand700],
        ),
      ),
      child: Stack(
        children: [
          // Decorative concentric rings — top right, behind status button.
          Positioned(
            right: -48,
            top: -32,
            child: IgnorePointer(
              child: Opacity(
                opacity: Alpha.tintLight,
                child: CustomPaint(
                  size: const Size(220, 220),
                  painter: _RingsPainter(),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.s5,
              topPad + Space.s4,
              Space.s5,
              Space.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: "Net this week" label + status pill ──────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Net this week',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeCaption,
                          color: Colors.white
                              .withValues(alpha: Alpha.iconOnGradient),
                          letterSpacing: Tracking.wide,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.s2),
                    _AvailabilityPillButton(
                      key: const Key('availability_button'),
                      isOnline: isOnline,
                      isLoading: availabilityLoading,
                      onPressed: onToggleOnline,
                    ),
                  ],
                ),
                const SizedBox(height: Space.s1),
                // ── Net figure with sparkline behind it ────────────────
                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Sparkline — decorative, behind the net figure.
                    Positioned(
                      right: 0,
                      child: Opacity(
                        opacity: Alpha.iconOnGradientSoft,
                        child: SizedBox(
                          width: 80,
                          height: 44,
                          child: CustomPaint(
                            painter: _SparklinePainter(DesignTokens.amber),
                          ),
                        ),
                      ),
                    ),
                    // Net earnings figure.
                    GestureDetector(
                      onTap: hasError ? onEarningsRetry : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                earnedValue,
                                style: TextStyle(
                                  fontFamily: TypeTokens.fontDisplay,
                                  fontSize: (hasError || isNotAvailable)
                                      ? DesignTokens.fontSizeH2
                                      : DesignTokens.fontSizeAmountLg,
                                  fontWeight: FW.bold,
                                  color: Colors.white,
                                  letterSpacing: Tracking.tight *
                                      ((hasError || isNotAvailable)
                                          ? DesignTokens.fontSizeH2
                                          : DesignTokens.fontSizeAmountLg),
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                          if (hasError) ...[
                            const SizedBox(width: Space.s2),
                            Icon(
                              Icons.refresh_rounded,
                              size: Sizes.iconSm,
                              color: Colors.white.withValues(
                                  alpha: Alpha.iconOnGradientStrong),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s4),
                // ── Two equal-width stat tiles ─────────────────────────
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _HeroStatTile(
                          key: const Key('stat_tile_pending'),
                          label: 'Pending',
                          valueText: pendingValue != null
                              ? 'Pending $pendingValue'
                              : 'Pending —',
                          // Reserve caption height even when absent so tiles
                          // stay the same height as the rating tile.
                          captionText: null,
                          reserveCaptionSpace: true,
                        ),
                      ),
                      const SizedBox(width: Space.s2),
                      Expanded(
                        child: _HeroStatTile(
                          key: const Key('stat_tile_rating'),
                          label: 'Rating',
                          valueText: hasRating
                              ? averageRatingNum.toStringAsFixed(1)
                              : 'No reviews yet',
                          valueIcon: hasRating ? Icons.star_rounded : null,
                          captionText: hasRating
                              ? '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}'
                              : null,
                          reserveCaptionSpace: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero stat tile ────────────────────────────────────────────────────────────

/// A single semi-transparent tile inside the hero gradient.
///
/// [reserveCaptionSpace] ensures both tiles are the same height whether or
/// not one has a [captionText] — achieved by rendering an invisible Text
/// placeholder at the same size.
class _HeroStatTile extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData? valueIcon;
  final String? captionText;
  final bool reserveCaptionSpace;

  const _HeroStatTile({
    super.key,
    required this.label,
    required this.valueText,
    this.valueIcon,
    this.captionText,
    this.reserveCaptionSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s3,
        vertical: Space.s3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: Alpha.tintStandard),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(
          color: Colors.white.withValues(alpha: Alpha.tintAccent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            label,
            style: TextStyle(
              fontFamily: DesignTokens.fontBody,
              fontSize: DesignTokens.fontSizeTiny,
              fontWeight: FW.medium,
              color: Colors.white.withValues(alpha: Alpha.textOnGradient),
              letterSpacing: Tracking.wide,
            ),
          ),
          const SizedBox(height: Space.s1),
          // Value row (icon + text)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (valueIcon != null) ...[
                Icon(valueIcon, size: 14, color: DesignTokens.amber),
                const SizedBox(width: Space.s1),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valueText,
                    style: TextStyle(
                      fontFamily: TypeTokens.fontDisplay,
                      fontSize: DesignTokens.fontSizeSm,
                      fontWeight: FW.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Caption or reserved-space placeholder.
          if (captionText != null || reserveCaptionSpace) ...[
            const SizedBox(height: Space.s0_5),
            Opacity(
              opacity: captionText != null ? 1.0 : 0.0,
              child: Text(
                captionText ?? '–',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeTiny,
                  color: Colors.white.withValues(alpha: Alpha.textOnGradient),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Availability pill button ──────────────────────────────────────────────────

/// Pill status button for the hero top row.
///
/// States:
/// - Online: green-tinted filled dot + "Online" label, dot pulses (respects
///   reduce-motion).
/// - Offline: neutral outlined dot + "Offline" label, no pulse.
/// - Loading: spinner replaces the dot, button disabled, label unchanged.
///
/// Meets WCAG 4.5:1 contrast for label text on the dark gradient in both
/// themes. Min tap area 48×48dp via [ConstrainedBox] padding.
class _AvailabilityPillButton extends StatefulWidget {
  final bool isOnline;
  final bool isLoading;
  final VoidCallback onPressed;

  const _AvailabilityPillButton({
    super.key,
    required this.isOnline,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_AvailabilityPillButton> createState() =>
      _AvailabilityPillButtonState();
}

class _AvailabilityPillButtonState extends State<_AvailabilityPillButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: FixoDurations.pulse,
    );
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // _updatePulse reads MediaQuery — must not be called here.
    // Called in didChangeDependencies instead.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePulse();
  }

  @override
  void didUpdateWidget(_AvailabilityPillButton old) {
    super.didUpdateWidget(old);
    if (old.isOnline != widget.isOnline ||
        old.isLoading != widget.isLoading) {
      _updatePulse();
    }
  }

  void _updatePulse() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.isOnline && !widget.isLoading && !reduceMotion) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always-white text on the dark gradient — confirmed ≥ 4.5:1 on brand900.
    const labelColor = Colors.white;
    final dotColor =
        widget.isOnline ? DesignTokens.green : Colors.white;
    final borderColor = widget.isOnline
        ? DesignTokens.green.withValues(alpha: Alpha.outlineDark)
        : Colors.white.withValues(alpha: Alpha.border);
    final bgColor = widget.isOnline
        ? DesignTokens.green.withValues(alpha: Alpha.tintStandard)
        : Colors.white.withValues(alpha: Alpha.subtle);

    final label = widget.isOnline ? 'Online' : 'Offline';

    return Semantics(
      button: true,
      toggled: widget.isOnline,
      label: 'Availability',
      value: label,
      hint: widget.isOnline ? 'Double tap to go offline' : 'Double tap to go online',
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Pad hit area to Sizes.tapMin without expanding layout width.
          padding: const EdgeInsets.symmetric(vertical: Space.s1),
          child: Container(
            height: Sizes.statusButton,
            constraints: const BoxConstraints(minWidth: Sizes.tapMin),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s3,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  // Dot / spinner
                  SizedBox(
                    width: Sizes.heroDot,
                    height: Sizes.heroDot,
                    child: widget.isLoading
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white
                                .withValues(alpha: Alpha.iconOnGradientStrong),
                          )
                        : AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, _) => Opacity(
                              opacity: _pulseAnim.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dotColor,
                                  boxShadow: widget.isOnline
                                      ? [
                                          BoxShadow(
                                            color: DesignTokens.green
                                                .withValues(alpha: Alpha.divider),
                                            blurRadius: Space.s1,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: Space.s2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: TypeTokens.fontBody,
                      fontSize: DesignTokens.fontSizeSecondary,
                      fontWeight: FW.semibold,
                      color: labelColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

/// Decorative concentric rings for the hero background (top-right corner).
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width, 0);
    for (final r in [50.0, 90.0, 130.0, 170.0]) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}

/// Decorative sparkline — a simple curved amber line suggesting upward trend.
class _SparklinePainter extends CustomPainter {
  final Color color;
  const _SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Six relative y-points (0=top, 1=bottom) for a gentle upward-trending line.
    const ys = [0.80, 0.55, 0.70, 0.45, 0.60, 0.25];
    final pts = List.generate(ys.length, (i) {
      final x = size.width * i / (ys.length - 1);
      final y = size.height * ys[i];
      return Offset(x, y);
    });

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot at the last point
    canvas.drawCircle(
      pts.last,
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.color != color;
}


// ── New leads ─────────────────────────────────────────────────────────────────

class _LeadsSection extends StatelessWidget {
  final List<Job> leads;
  final Map<String, JobOffer?> pendingOffers;
  final bool offersLoaded;
  final Set<String> responding;
  final ValueChanged<Job> onAccept;
  final ValueChanged<Job> onDecline;
  final ValueChanged<Job> onOpen;

  const _LeadsSection({
    required this.leads,
    required this.pendingOffers,
    required this.offersLoaded,
    required this.responding,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leads.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s2),
            child: Text(
              'No new leads right now. Online tradies get offers first.',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.inkSoft(isDark),
              ),
            ),
          ),
        for (final job in leads) ...[
          _LeadCard(
            job: job,
            offer: pendingOffers[job.id],
            offerChecked: offersLoaded || pendingOffers.containsKey(job.id),
            busy: responding.contains(job.id),
            onAccept: () => onAccept(job),
            onDecline: () => onDecline(job),
            onOpen: () => onOpen(job),
          ),
          const SizedBox(height: Space.s2_5),
        ],
      ],
    );
  }
}

/// A field-ready lead card: everything needed to evaluate the offer without
/// forced navigation — job total, suburb, schedule, summary, photo and the
/// server offer expiry. Distance is deliberately absent: job coordinates are
/// masked for tradies until Booked (P5-01), so there is nothing truthful to
/// show.
class _LeadCard extends StatefulWidget {
  final Job job;
  final JobOffer? offer;

  /// True once the pending-offer fetch for this job has completed (so `null`
  /// offer means lapsed, not still loading).
  final bool offerChecked;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  const _LeadCard({
    required this.job,
    required this.offer,
    required this.offerChecked,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  @override
  State<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<_LeadCard> {
  bool get _offerLive =>
      widget.offer != null &&
      !widget.offer!.remaining().isNegative &&
      !widget.busy;

  /// The shared countdown hit zero — flip the actions to their disabled
  /// state. The server's timeout job owns the authoritative timeout.
  void _onExpired() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = DesignTokens.inkSoft(isDark);
    final photoUrl = widget.job.photoUrls.isNotEmpty
        ? widget.job.photoUrls.first
        : null;

    // Metadata line: suburb · schedule · duration — skip empty segments.
    final metaSegments = [
      if (widget.job.suburb.isNotEmpty) widget.job.suburb,
      if (widget.job.scheduledStartUtc != null)
        _scheduleLabel(widget.job.scheduledStartUtc!),
      if (widget.job.hours > 0) '${widget.job.hours}h',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [DesignTokens.paperLight, DesignTokens.paperLineLight],
                  ),
            color: isDark ? DesignTokens.cardDark : null,
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(
              color: DesignTokens.paperLine(isDark),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: isDark ? Alpha.tintAccent : Alpha.subtle),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Price (left) + urgency chip (right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.job.totalAmount != null
                              ? formatMoney(widget.job.totalAmount!)
                              : '—',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeH1,
                            fontWeight: FW.bold,
                            color: DesignTokens.foreground(isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.job.urgency == 'Urgent' ||
                      widget.job.urgency == 'Emergency') ...[
                    const SizedBox(width: Space.s2),
                    FixoPillChip(
                      label: widget.job.urgency!,
                      color: DesignTokens.amber,
                      textColor: DesignTokens.inkAccent(isDark),
                      showDot: true,
                      uppercase: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Space.s2),
              // Row 2: Countdown progress bar
              _LeadCountdownBar(
                offer: widget.offer,
                offerChecked: widget.offerChecked,
                onExpired: _onExpired,
              ),
              const SizedBox(height: Space.s2),
              // Row 3: Metadata line — suburb · schedule · duration
              if (metaSegments.isNotEmpty)
                Text(
                  metaSegments.join(' · '),
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: soft,
                  ),
                ),
              if (metaSegments.isNotEmpty) const SizedBox(height: Space.s2),
              // Row 4: Job title + photo thumbnail
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontWeight: FW.bold,
                        fontSize: DesignTokens.fontSizeBody,
                        height: 1.3,
                        color: DesignTokens.foreground(isDark),
                      ),
                    ),
                  ),
                  if (photoUrl != null) ...[
                    const SizedBox(width: Space.s3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.small),
                      child: Image.network(
                        _resolvePhotoUrl(photoUrl),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Space.s3),
              // Row 5: Decline (1/3) | Accept (2/3), 56px height
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: Sizes.button,
                      child: OutlinedButton(
                        onPressed: _offerLive ? widget.onDecline : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s1,
                          ),
                          foregroundColor:
                              DesignTokens.foregroundBrand(isDark),
                          side: BorderSide(
                            color: DesignTokens.borderControl(isDark),
                            width: DesignTokens.borderWidthFor(isDark),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Radii.control),
                          ),
                          textStyle: const TextStyle(
                            fontSize: DesignTokens.fontSizeSecondary,
                            fontWeight: FW.semibold,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Decline'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s2_5),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: Sizes.button,
                      child: FilledButton(
                        onPressed: _offerLive ? widget.onAccept : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s2,
                          ),
                          backgroundColor: DesignTokens.amber,
                          foregroundColor: DesignTokens.onAmber,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Radii.control),
                          ),
                          textStyle: const TextStyle(
                            fontSize: DesignTokens.fontSizeSecondary,
                            fontWeight: FW.bold,
                          ),
                        ),
                        child: widget.busy
                            ? const SizedBox(
                                width: Sizes.iconSm,
                                height: Sizes.iconSm,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Accept'),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _resolvePhotoUrl(String url) =>
      url.startsWith('http') ? url : '${resolveBaseUrl()}$url';

  static String _scheduleLabel(DateTime scheduledUtc) {
    final local = scheduledUtc.toLocal();
    final now = DateTime.now();
    final time = DateFormat.jm().format(local);
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) return 'Today $time';
    final tomorrow = now.add(const Duration(days: 1));
    if (local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day) {
      return 'Tomorrow $time';
    }
    return '${DateFormat('EEE d MMM').format(local)} $time';
  }
}

/// A compact progress-bar countdown for lead cards. Ticks its own 1-second
/// timer independently of [OfferCountdown] so the card keeps full layout
/// control. Uses [OfferCountdown.clampedRemaining] and
/// [OfferCountdown.formatClock] for consistent maths and formatting.
class _LeadCountdownBar extends StatefulWidget {
  final JobOffer? offer;
  final bool offerChecked;
  final VoidCallback onExpired;

  const _LeadCountdownBar({
    required this.offer,
    required this.offerChecked,
    required this.onExpired,
  });

  @override
  State<_LeadCountdownBar> createState() => _LeadCountdownBarState();
}

class _LeadCountdownBarState extends State<_LeadCountdownBar> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _expiredNotified = false;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    if (_remaining > Duration.zero) {
      _startTimer();
    } else if (widget.offer != null) {
      _notifyExpiredPostFrame();
    }
  }

  @override
  void didUpdateWidget(_LeadCountdownBar old) {
    super.didUpdateWidget(old);
    final oldExpiry = old.offer?.expiresAtUtc;
    final newExpiry = widget.offer?.expiresAtUtc;
    if (oldExpiry != newExpiry) {
      _timer?.cancel();
      _expiredNotified = false;
      _remaining = _compute();
      if (_remaining > Duration.zero) {
        _startTimer();
      } else if (widget.offer != null) {
        _notifyExpiredPostFrame();
      }
    }
  }

  Duration _compute() {
    final offer = widget.offer;
    if (offer == null) return Duration.zero;
    return OfferCountdown.clampedRemaining(offer, null);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _compute();
      setState(() => _remaining = next);
      if (next <= Duration.zero) {
        _timer?.cancel();
        _notifyExpired();
      }
    });
  }

  void _notifyExpiredPostFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyExpired());
  }

  void _notifyExpired() {
    if (_expiredNotified) return;
    _expiredNotified = true;
    widget.onExpired();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grey = DesignTokens.inkSoft(isDark);

    // Not yet checked — shimmer-like grey bar at 0 + 'Checking…' label
    if (!widget.offerChecked) {
      return FixoProgressBar(
        progress: 0.0,
        barColor: grey,
        label: 'Checking…',
        labelColor: grey,
      );
    }

    final offer = widget.offer;

    // Offer fetch returned null — expired/gone bar
    if (offer == null) {
      return FixoProgressBar(
        progress: 1.0,
        barColor: grey,
        label: 'Expired',
        labelColor: grey,
      );
    }

    // Live offer — compute progress fraction using offeredAtUtc as the start.
    final expiresAt = offer.expiresAtUtc;
    final totalSeconds =
        expiresAt.difference(offer.offeredAtUtc).inSeconds;
    final progress = totalSeconds > 0
        ? (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    final live = _remaining > Duration.zero;
    final labelColor =
        live ? DesignTokens.inkAccent(isDark) : grey;

    return FixoProgressBar(
      progress: progress,
      barColor: live ? DesignTokens.amber : grey,
      label: live ? OfferCountdown.formatClock(_remaining) : 'Expired',
      labelColor: labelColor,
    );
  }
}


// ── Today section ─────────────────────────────────────────────────────────────

class _TodaySection extends StatelessWidget {
  final List<Job> jobs;
  final bool isOnline;
  final ValueChanged<String> onJobTap;
  final VoidCallback onGoOnline;

  const _TodaySection({
    required this.jobs,
    required this.isOnline,
    required this.onJobTap,
    required this.onGoOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return _TodayEmptyState(isOnline: isOnline, onGoOnline: onGoOnline);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final job in jobs) ...[
          _TodayJobCard(job: job, onTap: () => onJobTap(job.id)),
          const SizedBox(height: Space.s2_5),
        ],
      ],
    );
  }
}

// ── Today empty state ─────────────────────────────────────────────────────────

/// Compact card that adapts to online/offline state.
///
/// Online: "You're online. New leads will appear here."
/// Offline: "No new leads right now. Online tradies get offers first."
///          + a "Go online" prompt button.
class _TodayEmptyState extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onGoOnline;

  const _TodayEmptyState({
    required this.isOnline,
    required this.onGoOnline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final th = Theme.of(context).extension<THColors>()!;

    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceCard(isDark),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: DesignTokens.paperLine(isDark)),
        boxShadow: DesignTokens.cardShadow(isDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Space.s9,
            height: Space.s9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isOnline ? DesignTokens.green : DesignTokens.inkSoft(isDark))
                  .withValues(alpha: Alpha.tintStandard),
            ),
            child: Icon(
              isOnline ? Icons.check_circle_outline_rounded : Icons.wifi_off_rounded,
              size: Sizes.iconMd,
              color: isOnline ? DesignTokens.inkSuccess(isDark) : DesignTokens.inkSoft(isDark),
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline
                      ? "You're online"
                      : 'Nothing scheduled today',
                  style: TextStyle(
                    fontFamily: DesignTokens.fontDisplay,
                    fontSize: DesignTokens.fontSizeBody,
                    fontWeight: FW.semibold,
                    color: th.text,
                  ),
                ),
                const SizedBox(height: Space.s1),
                Text(
                  isOnline
                      ? 'New leads will appear here as they come in.'
                      : 'No new leads right now. Online tradies get offers first.',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSecondary,
                    color: th.textSoft,
                  ),
                ),
                if (!isOnline) ...[
                  const SizedBox(height: Space.s3),
                  Semantics(
                    button: true,
                    label: 'Go online to receive new leads',
                    child: InkWell(
                      onTap: onGoOnline,
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s3,
                          vertical: Space.s2,
                        ),
                        decoration: BoxDecoration(
                          color: DesignTokens.green
                              .withValues(alpha: Alpha.tintStandard),
                          borderRadius: BorderRadius.circular(Radii.control),
                          border: Border.all(
                            color: DesignTokens.green
                                .withValues(alpha: Alpha.borderMid),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_rounded,
                              size: 14,
                              color: DesignTokens.inkSuccess(isDark),
                            ),
                            const SizedBox(width: Space.s1_5),
                            Text(
                              'Go online',
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeSecondary,
                                fontWeight: FW.semibold,
                                color: DesignTokens.inkSuccess(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today job card ────────────────────────────────────────────────────────────

/// Redesigned tradie Today card per v1.7 spec.
///
/// Layout:
/// 1. Row 1: job title (left, max 2 lines, bold) + StatusChip (trailing,
///    aligned to first line baseline via [CrossAxisAlignment.start]).
/// 2. Row 2: trade · suburb muted line.
/// 3. Row 3: price (left, strong, tabular) | schedule (right, 2 lines if
///    needed: day above, time below).
/// 4. Row 4: segmented progress bar — "Step X of 4" caption only.
/// 5. Action row: amber primary CTA only when [tradieActionRequired],
///    otherwise a trailing chevron on the card's right edge.
///
/// The whole card is tappable ([InkWell] wrapping). When a CTA is shown it
/// navigates identically to tapping the card.
class _TodayJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const _TodayJobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final th = Theme.of(context).extension<THColors>()!;
    final presentation = JobStatusPresentation.forStatus(job.status);
    final scheduled = job.scheduledStartUtc?.toLocal();

    // Price string — tabular numerals.
    final priceText = job.totalAmount != null
        ? formatMoney(job.totalAmount!)
        : null;

    // Schedule — split into date and time when available.
    final dateLabel = scheduled != null
        ? DateFormat('EEE d MMM').format(scheduled)
        : null;
    final timeLabel = scheduled != null
        ? DateFormat.jm().format(scheduled)
        : null;

    // Meta line: trade · suburb (never repeat trade twice).
    final metaParts = <String>[];
    if (job.category.isNotEmpty) metaParts.add(job.category);
    if (job.suburb.isNotEmpty) metaParts.add(job.suburb);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceCard(isDark),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: DesignTokens.paperLine(isDark)),
            boxShadow: DesignTokens.cardShadow(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: title + status chip ────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontSize: DesignTokens.fontSizeH3,
                        fontWeight: FW.bold,
                        height: 1.3,
                        color: th.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s2),
                  // Chip aligned to first line — CrossAxisAlignment.start
                  // handles this since the chip is fixed-height (Sizes.statusChip).
                  StatusChip(
                    label: presentation.label,
                    tone: presentation.chipTone,
                    icon: presentation.chipIcon,
                  ),
                ],
              ),

              // ── Row 2: trade · suburb ─────────────────────────────────
              if (metaParts.isNotEmpty) ...[
                const SizedBox(height: Space.s1),
                Text(
                  metaParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSecondary,
                    color: th.textSoft,
                  ),
                ),
              ],

              // ── Row 3: price | schedule ───────────────────────────────
              if (priceText != null || dateLabel != null) ...[
                const SizedBox(height: Space.s3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (priceText != null)
                      Expanded(
                        child: Text(
                          priceText,
                          style: TextStyle(
                            fontFamily: DesignTokens.fontDisplay,
                            fontSize: DesignTokens.fontSizeAmount,
                            fontWeight: FW.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: th.text,
                          ),
                        ),
                      ),
                    if (priceText != null && dateLabel != null)
                      const SizedBox(width: Space.s2),
                    if (dateLabel != null)
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              dateLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeSecondary,
                                fontWeight: FW.medium,
                                color: th.textSoft,
                              ),
                            ),
                            if (timeLabel != null)
                              Text(
                                timeLabel,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeSecondary,
                                  fontWeight: FW.semibold,
                                  color: th.text,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              // ── Row 4: progress bar ───────────────────────────────────
              if (presentation.progressStage != null) ...[
                const SizedBox(height: Space.s3),
                CompactProgressBar(
                  completedSteps: presentation.progressStage! + 1,
                  totalSteps: 4,
                  label: presentation.progressLabel,
                  // No sublabel — status is communicated by the chip above.
                ),
              ],

              // ── Row 5: CTA or chevron ─────────────────────────────────
              const SizedBox(height: Space.s3),
              if (presentation.tradieActionRequired)
                SizedBox(
                  width: double.infinity,
                  height: Sizes.tapMin,
                  child: Semantics(
                    button: true,
                    label: presentation.tradieAction,
                    child: FilledButton(
                      key: const Key('today_card_cta'),
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.amber,
                        foregroundColor: DesignTokens.onAmber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.control),
                        ),
                        textStyle: TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeBody,
                          fontWeight: FW.semibold,
                        ),
                      ),
                      child: Text(presentation.tradieAction),
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: Sizes.iconMd,
                    color: th.textSoft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Collapsed sections ────────────────────────────────────────────────────────

class _CollapsedJobSection extends StatelessWidget {
  final String title;
  final List<Job> jobs;
  final bool initiallyExpanded;
  final ValueChanged<String> onJobTap;

  const _CollapsedJobSection({
    required this.title,
    required this.jobs,
    required this.onJobTap,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: DesignTokens.surfaceCard(isDark),
      borderRadius: BorderRadius.circular(Radii.tile),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: Space.s4),
          childrenPadding: const EdgeInsets.fromLTRB(
            Space.s4,
            0,
            Space.s4,
            Space.s3,
          ),
          title: Text(
            '$title (${jobs.length})',
            style: TextStyle(
              fontFamily: DesignTokens.fontDisplay,
              fontWeight: FW.bold,
              fontSize: DesignTokens.fontSizeBody,
              color: isDark ? DesignTokens.inkDark : DesignTokens.brand900,
            ),
          ),
          children: [
            for (final job in jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s2_5),
                child: _scheduledJobCard(job, onJobTap),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _scheduledJobCard(Job job, ValueChanged<String> onJobTap) {
  final presentation = JobStatusPresentation.forStatus(job.status);
  final scheduled = job.scheduledStartUtc?.toLocal();
  final timeLabel = scheduled != null
      ? DateFormat('EEE d MMM · ').add_jm().format(scheduled)
      : null;
  return ModernJobCard(
    title: job.title,
    category: job.category,
    suburb: job.suburb,
    status: presentation.label,
    statusKind: presentation.kind,
    priceLabel: job.totalAmount != null
        ? formatMoney(job.totalAmount!)
        : null,
    scheduleLabel: timeLabel,
    actionLabel: presentation.tradieAction,
    progressStatus: job.status,
    onTap: () => onJobTap(job.id),
  );
}
