import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsService;
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
import '../widgets/job_status_presentation.dart';
import '../widgets/offer_countdown.dart';
import '../widgets/fixo_feedback.dart';
import '../widgets/fixo_progress_bar.dart';
import '../widgets/sliding_availability_switch.dart';
import '../widgets/tradie_job_card.dart';
import '../../feedback/fixo_notice.dart';


/// Statuses that count as booked work for the tradie — the job is theirs to
/// turn up to (or is already underway / awaiting confirmation).
const _bookedWorkStatuses = {'Booked', 'InProgress', 'AwaitingConfirmation'};

/// Matched but not yet confirmed — the homeowner's payment is still in flight.
const _awaitingPaymentStatuses = {'AwaitingPayment', 'PaymentReview'};

/// True when [job]'s scheduled start is strictly today (local date == today).
/// Overdue jobs (past scheduled date) are separated into their own group.
bool _isScheduledToday(Job job, DateTime now) {
  final scheduled = job.scheduledStartUtc;
  if (scheduled == null) return true; // no schedule → show in today
  final local = scheduled.toLocal();
  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

/// True when [job] is overdue: Booked/InProgress/AwaitingConfirmation with a
/// scheduled start strictly before the start of today.
bool _isOverdue(Job job, DateTime now) {
  final scheduled = job.scheduledStartUtc;
  if (scheduled == null) return false;
  final startOfToday = DateTime(now.year, now.month, now.day);
  return scheduled.toLocal().isBefore(startOfToday);
}

/// Public backwards-compat helper used by [jobs_list_screen.dart].
/// Returns true when the job is scheduled on or before the end of today
/// (i.e. today + overdue). Overdue jobs are intentionally included for the
/// Jobs-screen "Today" filter, which shows everything due today or earlier.
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

  /// Availability toggle state: loading and error.
  bool _availabilityLoading = false;
  bool _availabilityError = false;

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

    // Going offline with active work or leads → confirm sheet.
    if (currentlyOnline) {
      final allJobs = ref.read(jobsViewModelProvider).jobs;
      final hasActiveOrLeads = allJobs.any(
        (j) =>
            j.status == 'Requested' || _bookedWorkStatuses.contains(j.status),
      );
      if (hasActiveOrLeads) {
        final confirmed = await _showGoOfflineConfirm();
        if (!confirmed || !mounted) return;
      }
    }

    setState(() {
      _availabilityLoading = true;
      _availabilityError = false;
    });
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
      setState(() => _availabilityError = true);
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
    final jobsState    = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final earningsState = ref.watch(tradieEarningsProvider);
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now    = DateTime.now();

    final leads = jobsState.jobs.where((j) => j.status == 'Requested').toList();

    // Overdue: booked jobs whose schedule is strictly before today.
    final overdueJobs = jobsState.jobs
        .where(
          (j) =>
              _bookedWorkStatuses.contains(j.status) && _isOverdue(j, now),
        )
        .toList()
      ..sort((a, b) {
        // Sort oldest first so the most-urgent overdue job is at the top.
        final aT = a.scheduledStartUtc;
        final bT = b.scheduledStartUtc;
        if (aT == null && bT == null) return 0;
        if (aT == null) return 1;
        if (bT == null) return -1;
        return aT.compareTo(bT);
      });

    // Today: booked jobs scheduled exactly for today (not overdue).
    final todayJobs = jobsState.jobs
        .where(
          (j) =>
              _bookedWorkStatuses.contains(j.status) &&
              _isScheduledToday(j, now) &&
              !_isOverdue(j, now),
        )
        .toList();

    // Sort today: action-required statuses first, then by schedule time.
    final sortedToday = [...todayJobs]..sort((a, b) {
        final aReq =
            JobStatusPresentation.forStatus(a.status).tradieActionRequired;
        final bReq =
            JobStatusPresentation.forStatus(b.status).tradieActionRequired;
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
              !_isScheduledToday(j, now) &&
              !_isOverdue(j, now),
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
                availabilityError: _availabilityError,
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
                      Icon(
                        Icons.pause_circle_outline,
                        size: Sizes.iconSm,
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
                            // ── New leads section ─────────────────────────
                            // Hidden entirely when empty and loaded with no
                            // error. Skeleton shown on first load. Animated
                            // in/out as leads arrive or are resolved.
                            _LeadsSection(
                              leads: leads,
                              pendingOffers: _pendingOffers,
                              offersLoaded: _offersLoaded,
                              hasError: jobsState.error != null,
                              isFirstLoad:
                                  jobsState.isLoading && jobsState.jobs.isEmpty,
                              responding: _responding,
                              onAccept: (job) =>
                                  _respondToLead(job, accept: true),
                              onDecline: (job) =>
                                  _respondToLead(job, accept: false),
                              onOpen: (job) =>
                                  context.push('/tradie/requests/${job.id}'),
                              onRetry: _refreshAll,
                            ),
                            // ── Overdue group ─────────────────────────────
                            if (overdueJobs.isNotEmpty) ...[
                              const SizedBox(height: Space.s4),
                              _OverdueSectionLabel(count: overdueJobs.length),
                              const SizedBox(height: Space.s2_5),
                              for (final job in overdueJobs) ...[
                                TradieJobCard(
                                  job: job,
                                  onTap: () =>
                                      context.push('/tradie/jobs/${job.id}'),
                                  isOverdueOverride: true,
                                ),
                                const SizedBox(height: Space.s2_5),
                              ],
                            ],
                            // ── Today section ─────────────────────────────
                            const SizedBox(height: Space.s4),
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

// ── Section labels ────────────────────────────────────────────────────────────

class _TodaySectionLabel extends StatelessWidget {
  final int count;
  const _TodaySectionLabel({required this.count});

  @override
  Widget build(BuildContext context) {
    final th     = Theme.of(context).extension<THColors>()!;
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

/// "Overdue" group header — warning tone, count badge.
class _OverdueSectionLabel extends StatelessWidget {
  final int count;
  const _OverdueSectionLabel({required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: Sizes.iconXs,
          color: DesignTokens.inkAccent(isDark),
        ),
        const SizedBox(width: Space.s1),
        Text(
          'Overdue',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeCaption,
            fontWeight: FW.semibold,
            letterSpacing: Tracking.wide,
            color: DesignTokens.inkAccent(isDark),
          ),
        ),
        const SizedBox(width: Space.s1_5),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s1_5,
            vertical: Space.s0_5,
          ),
          decoration: BoxDecoration(
            color: DesignTokens.amber.withValues(alpha: Alpha.tintAccent),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeTiny,
              fontWeight: FW.semibold,
              color: DesignTokens.inkAccent(isDark),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tradie earnings hero header ───────────────────────────────────────────────

/// Always-dark brand gradient header.
///
/// Layout (v1.7 corrected):
/// 1. Net row: Expanded figure column (caption + FittedBox amount) | switch.
///    The glass strip and status text ("Available for jobs / Offline") are
///    removed. The switch track shows "Online"/"Offline" itself.
///    Compact switch fallback when the figure column would be < heroMinFigureWidth.
/// 2. 1px hairline above stats columns.
/// 3. Two equal-width stat columns (Pending | Rating) directly on the gradient
///    — no fill, no border, 1px vertical hairline between columns.
///
/// The _SparklinePainter has been removed: it drew six hardcoded points
/// unrelated to real earnings data.
class _TradieHero extends StatelessWidget {
  final TradieEarningsState earningsState;
  final ProfileState profileState;
  final int todayCount;
  final bool isOnline;
  final bool availabilityLoading;
  final bool availabilityError;
  final VoidCallback onToggleOnline;
  final VoidCallback onEarningsRetry;

  const _TradieHero({
    required this.earningsState,
    required this.profileState,
    required this.todayCount,
    required this.isOnline,
    required this.availabilityLoading,
    this.availabilityError = false,
    required this.onToggleOnline,
    required this.onEarningsRetry,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final summary = earningsState.summary;

    final String earnedValue;
    final bool isNotAvailable =
        summary != null && summary.earnedNet == null;
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
    final int? reviewCount =
        profileState.profile?['reviewCount'] as int?;
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
          // Decorative concentric rings — top right, behind everything.
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
              Space.s5, // tightened from s4
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Net row: figure left, switch right ─────────────────
                // LayoutBuilder detects if the figure column is too narrow
                // and switches to compact mode.
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Available width minus the full-width switch and minimum gap.
                    final switchW = Sizes.availabilityTrackW;
                    final gap = Space.s4;
                    final figureAvail =
                        constraints.maxWidth - switchW - gap;
                    final useCompact =
                        figureAvail < Sizes.heroMinFigureWidth;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Figure column: caption + amount.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Net this week',
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeCaption,
                                  color: Colors.white.withValues(
                                      alpha: Alpha.iconOnGradient),
                                  letterSpacing: Tracking.wide,
                                ),
                              ),
                              const SizedBox(height: Space.s1),
                              GestureDetector(
                                onTap: hasError ? onEarningsRetry : null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          earnedValue,
                                          style: TextStyle(
                                            fontFamily:
                                                TypeTokens.fontDisplay,
                                            fontSize: (hasError ||
                                                    isNotAvailable)
                                                ? DesignTokens.fontSizeH2
                                                : DesignTokens
                                                    .fontSizeAmountLg,
                                            fontWeight: FW.bold,
                                            color: Colors.white,
                                            letterSpacing:
                                                Tracking.tight *
                                                    ((hasError ||
                                                            isNotAvailable)
                                                        ? DesignTokens
                                                            .fontSizeH2
                                                        : DesignTokens
                                                            .fontSizeAmountLg),
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
                                          alpha: Alpha.iconOnGradientStrong,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: useCompact
                              ? Space.s2
                              : Space.s4,
                        ),
                        // Availability switch — vertically centred on the
                        // figure (not the caption), never overlapping it.
                        SlidingAvailabilitySwitch(
                          key: const Key('availability_button'),
                          isOnline: isOnline,
                          isLoading: availabilityLoading,
                          hasError: availabilityError,
                          onToggle: onToggleOnline,
                          compact: useCompact,
                        ),
                      ],
                    );
                  },
                ),
                // ── Optional hairline above stats ───────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s3),
                  child: Container(
                    height: Sizes.borderWidthThin,
                    color: Colors.white.withValues(alpha: Alpha.tintStandard),
                  ),
                ),
                // ── Two equal-width stat columns (no glass) ─────────────
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HeroStatColumn(
                          key: const Key('stat_tile_pending'),
                          label: 'Pending',
                          valueText: pendingValue ?? '—',
                          captionText: null,
                          reserveCaptionSpace: true,
                        ),
                      ),
                      // Vertical hairline divider between columns.
                      Container(
                        width: Sizes.borderWidthThin,
                        color: Colors.white.withValues(alpha: Alpha.tintStandard),
                      ),
                      Expanded(
                        child: _HeroStatColumn(
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

// ── Hero stat column (plain — no glass) ───────────────────────────────────────

/// A single stats column rendered directly on the gradient — no fill, no border,
/// no radius. Left-padded for the first column, right-padded for the second
/// (handled by the outer Row's equal Expanded slots).
class _HeroStatColumn extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData? valueIcon;
  final String? captionText;
  final bool reserveCaptionSpace;

  const _HeroStatColumn({
    super.key,
    required this.label,
    required this.valueText,
    this.valueIcon,
    this.captionText,
    this.reserveCaptionSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label — 70% opacity on gradient
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
          // Value row (optional icon + text, tabular numerals, same size)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (valueIcon != null) ...[
                Icon(valueIcon, size: Sizes.iconRating, color: DesignTokens.amber),
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
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Caption or reserved-height placeholder so both columns match.
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

/// Decorative concentric rings for the hero background (top-right corner).
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = Sizes.borderWidthThin;
    final center = Offset(size.width, 0);
    for (final r in [50.0, 90.0, 130.0, 170.0]) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}

// ── New leads ─────────────────────────────────────────────────────────────────

/// New-leads section with smart visibility:
/// - [isFirstLoad]: shows one compact skeleton card while offers load.
/// - [leads] empty + [offersLoaded] + no [hasError]: renders nothing (no label,
///   no empty copy, no gap — first visible section below hero is "Today").
/// - [hasError]: shows inline error row with Retry (never hidden on error).
/// - Non-empty leads: animated in/out (AnimatedSize + fade), screen-reader
///   announcement on new lead, light haptic.
class _LeadsSection extends StatefulWidget {
  final List<Job> leads;
  final Map<String, JobOffer?> pendingOffers;
  final bool offersLoaded;
  final bool hasError;
  final bool isFirstLoad;
  final Set<String> responding;
  final ValueChanged<Job> onAccept;
  final ValueChanged<Job> onDecline;
  final ValueChanged<Job> onOpen;
  final VoidCallback onRetry;

  const _LeadsSection({
    required this.leads,
    required this.pendingOffers,
    required this.offersLoaded,
    required this.hasError,
    required this.isFirstLoad,
    required this.responding,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
    required this.onRetry,
  });

  @override
  State<_LeadsSection> createState() => _LeadsSectionState();
}

class _LeadsSectionState extends State<_LeadsSection> {
  List<String> _prevLeadIds = [];

  @override
  void didUpdateWidget(_LeadsSection old) {
    super.didUpdateWidget(old);
    final newIds = widget.leads.map((j) => j.id).toList();
    // Detect genuinely new leads (not just reorder) and announce.
    final added = newIds.where((id) => !_prevLeadIds.contains(id)).toList();
    if (added.isNotEmpty) {
      // Light haptic for new lead.
      HapticFeedback.lightImpact();
      // Accessibility live-region announcement for screen readers.
      // ignore: deprecated_member_use
      SemanticsService.announce(
        added.length == 1 ? 'New lead' : '${added.length} new leads',
        ui.TextDirection.ltr,
      );
    }
    _prevLeadIds = newIds;
  }

  @override
  Widget build(BuildContext context) {
    // Error row — always visible, never hidden.
    if (widget.hasError && !widget.isFirstLoad) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FixoSectionLabel(label: 'New leads'),
          const SizedBox(height: Space.s2_5),
          _LeadsErrorRow(onRetry: widget.onRetry),
          const SizedBox(height: Space.s4),
        ],
      );
    }

    // First-load skeleton — one compact placeholder card.
    if (widget.isFirstLoad) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FixoSectionLabel(label: 'New leads'),
          const SizedBox(height: Space.s2_5),
          const _LeadSkeletonCard(),
          const SizedBox(height: Space.s4),
        ],
      );
    }

    // Empty and loaded — render nothing.
    if (widget.leads.isEmpty) {
      return const SizedBox.shrink();
    }

    // Non-empty leads — animated section.
    return AnimatedSize(
      duration: FixoDurations.expand,
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FixoSectionLabel(
            label: 'New leads',
            count: widget.leads.length,
          ),
          const SizedBox(height: Space.s2_5),
          for (final job in widget.leads) ...[
            _AnimatedLeadCard(
              key: ValueKey(job.id),
              child: _LeadCard(
                job: job,
                offer: widget.pendingOffers[job.id],
                offerChecked: widget.offersLoaded ||
                    widget.pendingOffers.containsKey(job.id),
                busy: widget.responding.contains(job.id),
                onAccept: () => widget.onAccept(job),
                onDecline: () => widget.onDecline(job),
                onOpen: () => widget.onOpen(job),
              ),
            ),
            const SizedBox(height: Space.s2_5),
          ],
          const SizedBox(height: Space.s2),
        ],
      ),
    );
  }
}

/// Wraps a lead card with a fade-in animation on first build.
class _AnimatedLeadCard extends StatefulWidget {
  final Widget child;
  const _AnimatedLeadCard({super.key, required this.child});

  @override
  State<_AnimatedLeadCard> createState() => _AnimatedLeadCardState();
}

class _AnimatedLeadCardState extends State<_AnimatedLeadCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    _ctrl = AnimationController(
      vsync: this,
      duration: reduceMotion ? Duration.zero : FixoDurations.expand,
    )..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Skeleton placeholder for the first-load state.
class _LeadSkeletonCard extends StatelessWidget {
  const _LeadSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = DesignTokens.inkSoft(isDark)
        .withValues(alpha: Alpha.tintStandard);
    return Container(
      height: Sizes.expiryBarHeight + Space.s7, // ~88dp reserved height
      decoration: BoxDecoration(
        color: DesignTokens.surfaceCard(isDark),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: DesignTokens.paperLine(isDark)),
      ),
      padding: const EdgeInsets.all(Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: Space.s5,
            width: 100,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(Radii.small),
            ),
          ),
          const SizedBox(height: Space.s2),
          Container(
            height: Space.s4,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(Radii.small),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline error row shown when leads fetch fails.
class _LeadsErrorRow extends StatelessWidget {
  final VoidCallback onRetry;
  const _LeadsErrorRow({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s4,
        vertical: Space.s3,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.red.withValues(alpha: Alpha.tintStandard),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(
          color: DesignTokens.red.withValues(alpha: Alpha.borderMid),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: Sizes.iconSm,
            color: DesignTokens.inkDanger(isDark),
          ),
          const SizedBox(width: Space.s2),
          Expanded(
            child: Text(
              'Could not load leads.',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSecondary,
                color: DesignTokens.inkDanger(isDark),
              ),
            ),
          ),
          const SizedBox(width: Space.s2),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s2,
                vertical: Space.s1,
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSecondary,
                  fontWeight: FW.semibold,
                  color: DesignTokens.inkDanger(isDark),
                ),
              ),
            ),
          ),
        ],
      ),
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
                    colors: [
                      DesignTokens.paperLight,
                      DesignTokens.paperLineLight,
                    ],
                  ),
            color: isDark ? DesignTokens.cardDark : null,
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(
              color: DesignTokens.paperLine(isDark),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark ? Alpha.tintAccent : Alpha.subtle,
                ),
                blurRadius: Space.s2,
                offset: const Offset(0, 2),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Price + urgency chip
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
              // Row 2: Countdown bar
              _LeadCountdownBar(
                offer: widget.offer,
                offerChecked: widget.offerChecked,
                onExpired: _onExpired,
              ),
              const SizedBox(height: Space.s2),
              // Row 3: Metadata
              if (metaSegments.isNotEmpty)
                Text(
                  metaSegments.join(' · '),
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: soft,
                  ),
                ),
              if (metaSegments.isNotEmpty) const SizedBox(height: Space.s2),
              // Row 4: Title + photo
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
                        width: Sizes.iconHero * 0.7,
                        height: Sizes.iconHero * 0.7,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Space.s3),
              // Row 5: Decline | Accept
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
                            ? SizedBox(
                                width: Sizes.iconSm,
                                height: Sizes.iconSm,
                                child: CircularProgressIndicator(
                                  strokeWidth: Sizes.borderWidthThick,
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
    final isToday = local.year == now.year &&
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

/// Compact countdown progress bar for lead cards.
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

    if (!widget.offerChecked) {
      return FixoProgressBar(
        progress: 0.0,
        barColor: grey,
        label: 'Checking…',
        labelColor: grey,
      );
    }

    final offer = widget.offer;

    if (offer == null) {
      return FixoProgressBar(
        progress: 1.0,
        barColor: grey,
        label: 'Expired',
        labelColor: grey,
      );
    }

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
          TradieJobCard(job: job, onTap: () => onJobTap(job.id)),
          const SizedBox(height: Space.s2_5),
        ],
      ],
    );
  }
}

// ── Today empty state ─────────────────────────────────────────────────────────

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
    final th     = Theme.of(context).extension<THColors>()!;

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
            width:  Space.s9,
            height: Space.s9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isOnline
                      ? DesignTokens.green
                      : DesignTokens.inkSoft(isDark))
                  .withValues(alpha: Alpha.tintStandard),
            ),
            child: Icon(
              isOnline
                  ? Icons.check_circle_outline_rounded
                  : Icons.wifi_off_rounded,
              size:  Sizes.iconMd,
              color: isOnline
                  ? DesignTokens.inkSuccess(isDark)
                  : DesignTokens.inkSoft(isDark),
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "You're online" : 'Nothing scheduled today',
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
                              size:  Sizes.iconXs,
                              color: DesignTokens.inkSuccess(isDark),
                            ),
                            const SizedBox(width: Space.s1_5),
                            Text(
                              'Go online',
                              style: TextStyle(
                                fontSize:   DesignTokens.fontSizeSecondary,
                                fontWeight: FW.semibold,
                                color:      DesignTokens.inkSuccess(isDark),
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
            Space.s4, 0, Space.s4, Space.s3,
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
                child: TradieJobCard(
                  job: job,
                  onTap: () => onJobTap(job.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
