import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/offer_responder.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/modern_job_card.dart';
import '../widgets/job_status_presentation.dart';
import '../widgets/offer_countdown.dart';
import '../widgets/fixo_feedback.dart';
import '../widgets/fixo_progress_bar.dart';


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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New Job Request: ${event.title}')),
        );
      }
    });

    _offerSub = hub.onOfferLifecycle.listen((event) {
      if (!mounted) return;
      switch (event.eventType) {
        case OfferEventType.created:
          _refreshJobsAndOffers();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'New Job Offer: ${event.jobTitle ?? "New Request"}',
              ),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Could not accept this offer — it may have expired.'
                  : 'Could not decline this offer.',
            ),
          ),
        );
        _refreshJobsAndOffers();
      case OfferResponseOutcome.alreadyInFlight:
        break;
    }
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
                todayCount: todayJobs.length,
                isOnline: isAvailable,
                onToggleOnline: (v) => ref
                    .read(profileViewModelProvider.notifier)
                    .updateAvailability(v),
                onEarningsRetry: () =>
                    ref.read(tradieEarningsProvider.notifier).load(),
              ),
              if (!isAvailable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2_5),
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
                          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.navClearance),
                          children: [
                            if (showVerificationBanner) ...[
                              FixoInfoBanner(
                                icon: Icons.pending_actions_rounded,
                                tone: FixoTone.accent,
                                title: 'Not verified yet',
                                message: 'Upload a licence or insurance so an admin can approve you. '
                                    'Unverified tradies are never matched to jobs.',
                                action: InkWell(
                                  onTap: () => context.push('/tradie/onboarding'),
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
                            FixoSectionLabel(label: 'New leads', count: leads.length),
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
                            FixoSectionLabel(label: 'Today', count: todayJobs.length),
                            const SizedBox(height: Space.s2_5),
                            _TodaySection(
                              jobs: todayJobs,
                              onJobTap: (id) =>
                                  context.push('/tradie/jobs/$id'),
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

// ── Section label ─────────────────────────────────────────────────────────────

/// Uppercase muted section header matching the homeowner dashboard pattern.

// ── Tradie earnings hero header ────────────────────────────────────────────────

/// Always-dark brand gradient header with earnings hero, decorative sparkline,
/// two sub-tiles (pending + rating / jobs) and an embedded online/offline
/// toggle. The gradient is always dark so status bar icons are always white —
/// the caller wraps this in AnnotatedRegion.light.
class _TradieHero extends StatelessWidget {
  final TradieEarningsState earningsState;
  final ProfileState profileState;
  final int todayCount;
  final bool isOnline;
  final ValueChanged<bool> onToggleOnline;
  final VoidCallback onEarningsRetry;

  const _TradieHero({
    required this.earningsState,
    required this.profileState,
    required this.todayCount,
    required this.isOnline,
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
          ? '\$${summary!.earnedNet!.toStringAsFixed(2)}'
          : '—';
    }

    final String? pendingValue = summary?.pendingNet != null
        ? '\$${summary!.pendingNet!.toStringAsFixed(2)}'
        : null;

    final bool hasError = earningsState.error != null && summary == null;

    final num? averageRatingNum =
        profileState.profile?['averageRating'] as num?;
    final int? reviewCount = profileState.profile?['reviewCount'] as int?;

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
          // Decorative concentric rings — top right
          Positioned(
            right: -48,
            top: -32,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.10,
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
              topPad + 14,
              Space.s5,
              Space.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: earnings label + notification bell
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net this week',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeCaption,
                              color: Colors.white.withValues(alpha: Alpha.iconOnGradient),
                              letterSpacing: Tracking.wide,
                            ),
                          ),
                          const SizedBox(height: Space.s1),
                          GestureDetector(
                            onTap: hasError ? onEarningsRetry : null,
                            child: Row(
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
                                            ? 18
                                            : 38,
                                        fontWeight: FW.bold,
                                        color: Colors.white,
                                        letterSpacing: Tracking.tight *
                                            ((hasError || isNotAvailable)
                                                ? 18
                                                : 38),
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasError) ...[
                                  const SizedBox(width: Space.s2),
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: Alpha.iconOnGradientStrong),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sparkline — decorative amber line chart
                    const SizedBox(width: Space.s3),
                    SizedBox(
                      width: 72,
                      height: 44,
                      child: CustomPaint(
                        painter: _SparklinePainter(DesignTokens.amber),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s4),
                // Sub-tiles row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s2,
                          vertical: Space.s3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: Alpha.tintStandard),
                          borderRadius: BorderRadius.circular(Radii.tile),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: Alpha.tintAccent),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            pendingValue != null
                                ? 'Pending $pendingValue'
                                : 'Pending —',
                            style: const TextStyle(
                              fontFamily: TypeTokens.fontDisplay,
                              fontSize: DesignTokens.fontSizeSecondary,
                              fontWeight: FW.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.s2),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s2,
                          vertical: Space.s3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: Alpha.tintStandard),
                          borderRadius: BorderRadius.circular(Radii.tile),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: Alpha.tintAccent),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reviewCount != null &&
                                  reviewCount > 0 &&
                                  averageRatingNum != null &&
                                  averageRatingNum > 0) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: DesignTokens.amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      averageRatingNum.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontFamily: TypeTokens.fontDisplay,
                                        fontSize: DesignTokens.fontSizeSm,
                                        fontWeight: FW.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Space.s0_5),
                                Text(
                                  '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: Alpha.textOnGradient),
                                  ),
                                ),
                              ] else ...[
                                const Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeTiny,
                                    fontWeight: FW.semibold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.s2),
                    // Online/offline toggle — embedded as third tile
                    _OnlineSwitch(
                      online: isOnline,
                      onToggle: onToggleOnline,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Online/offline toggle styled as a hero tile — matches the sub-tile height,
/// shows a coloured dot + label + compact switch track.
/// Min tap target is 48×48 (Sizes.tapMin) per the accessibility contract.
class _OnlineSwitch extends StatelessWidget {
  final bool online;
  final ValueChanged<bool> onToggle;

  const _OnlineSwitch({required this.online, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const onColor = DesignTokens.green;
    const offColor = DesignTokens.inkSoftLight;

    final dotColor = online ? onColor : offColor;
    final label = online ? 'Online' : 'Offline';

    return Semantics(
      button: true,
      toggled: online,
      label: online ? 'Go offline' : 'Go online',
      child: GestureDetector(
        onTap: () => onToggle(!online),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minWidth: Sizes.tapMin, minHeight: Sizes.tapMin),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s3,
            vertical: Space.s3,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: Alpha.tintStandard),
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(
              color: online
                  ? onColor.withValues(alpha: Alpha.outlineDark)
                  : Colors.white.withValues(alpha: Alpha.tintAccent),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: FixoDurations.toggle,
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: online
                          ? [
                              BoxShadow(
                                color: onColor.withValues(alpha: Alpha.divider),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeTiny,
                      color: Colors.white,
                      fontWeight: FW.semibold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s1_5),
              // Compact switch track
              AnimatedContainer(
                duration: FixoDurations.toggle,
                width: Sizes.switchW * 0.75,   // 39px — compact for the tile
                height: Sizes.switchH * 0.75,  // 24px
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  color: online
                      ? onColor.withValues(alpha: Alpha.scrim)
                      : Colors.white.withValues(alpha: Alpha.border),
                ),
                alignment:
                    online ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: Alpha.border),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
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
                              ? '\$${widget.job.totalAmount!.toStringAsFixed(2)}'
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
                    FixoPillChip(label: widget.job.urgency!, color: DesignTokens.amber, textColor: DesignTokens.inkAccent(isDark), showDot: true, uppercase: true),
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
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _offerLive ? widget.onDecline : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: Space.s1),
                          foregroundColor:
                              DesignTokens.foregroundBrand(isDark),
                          side: BorderSide(
                            color: DesignTokens.borderControl(isDark),
                            width: DesignTokens.borderWidthFor(isDark),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusControl,
                            ),
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
                      height: 56,
                      child: FilledButton(
                        onPressed: _offerLive ? widget.onAccept : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                          backgroundColor: DesignTokens.amber,
                          foregroundColor: DesignTokens.onAmber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusControl,
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontSize: DesignTokens.fontSizeSecondary,
                            fontWeight: FW.bold,
                          ),
                        ),
                        child: widget.busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
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
      return FixoProgressBar(progress: 0.0, barColor: grey, label: 'Checking…', labelColor: grey);
    }

    final offer = widget.offer;

    // Offer fetch returned null — expired/gone bar
    if (offer == null) {
      return FixoProgressBar(progress: 1.0, barColor: grey, label: 'Expired', labelColor: grey);
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

    return FixoProgressBar(progress: progress, barColor: live ? DesignTokens.amber : grey, label: live ? OfferCountdown.formatClock(_remaining) : 'Expired', labelColor: labelColor);
  }

}


// ── Today / collapsed sections ────────────────────────────────────────────────

class _TodaySection extends StatelessWidget {
  final List<Job> jobs;
  final ValueChanged<String> onJobTap;

  const _TodaySection({required this.jobs, required this.onJobTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s2),
            child: Text(
              'Nothing scheduled today.',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.inkSoft(isDark),
              ),
            ),
          ),
        for (final job in jobs) ...[
          _scheduledJobCard(job, onJobTap),
          const SizedBox(height: Space.s2_5),
        ],
      ],
    );
  }
}

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
          childrenPadding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s3),
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
        ? '\$${job.totalAmount!.toStringAsFixed(2)}'
        : null,
    scheduleLabel: timeLabel,
    actionLabel: presentation.tradieAction,
    progressStatus: job.status,
    onTap: () => onJobTap(job.id),
  );
}
