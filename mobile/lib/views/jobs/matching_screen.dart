import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../widgets/offer_countdown.dart';
import '../widgets/sticky_action_bar.dart';
import '../../feedback/fixo_notice.dart';
import '../../ui/homeowner/ho_radar_screen.dart';
import '../../ui/homeowner/ho_request_sent_screen.dart';
import '../../ui/ui_flags.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';

/// Which waiting experience this screen runs.
enum MatchingScreenMode {
  /// Quick match: dispatch POST /api/jobs/:id/match and watch the server's
  /// sequential offers (P3-09/P3-10). Reached from "Quick match for me" and
  /// from a `Requested` job card.
  autoMatch,

  /// Request-sent (v1.7 P12-08/P12-09): the homeowner directly requested one
  /// tradie (POST /api/jobs/:id/request). No dispatch happens — the screen
  /// shows who was asked, at what rate, counts down to `expiresAtUtc` and
  /// navigates on the response.
  requestSent,
}

/// Homeowner waiting screen for both matching paths.
///
/// **autoMatch** (mockup 07): radar ripple + sequential offer progress. Calls
/// POST /api/jobs/:id/match, then watches SignalR for the server's offer
/// lifecycle events — the server owns the run (offer → timeout/decline →
/// next tradie → broaden → cancel), so this screen only renders progress and
/// never polls. See P3-09 / P3-10.
///
/// **requestSent** (v1.7): shows the asked tradie ([JobOffer.tradieName]),
/// their snapshot rate with the D8 GST label when supplied, and a live
/// countdown to the offer's `expiresAtUtc`. An accepted offer (SignalR
/// `OfferLifecycleEvent` or the `Booked` status event, or a poll fallback of
/// GET /api/jobs/:id/offers/pending) navigates to the booked job detail;
/// decline/timeout returns to the tradie list with a notice. The match
/// result screen with its auto-selected `matches[0]` is retired (P12-09).
class MatchingScreen extends ConsumerStatefulWidget {
  final String jobId;
  final MatchingScreenMode mode;

  /// D8 GST label for the requested tradie's snapshot rate
  /// ("Incl. GST" / "No GST charged"); null when unknown — the label is
  /// omitted rather than guessed.
  final String? gstLabel;

  /// How long the screen waits in `starting` before telling the homeowner the
  /// run may be stalled. Offer timeouts themselves stay server-owned — this
  /// only covers the case where no offer event ever arrives.
  static const stallDuration = Duration(seconds: 45);

  /// Poll cadence for the request-sent fallback (SignalR is primary).
  static const pollInterval = Duration(seconds: 15);

  const MatchingScreen({
    super.key,
    required this.jobId,
    this.mode = MatchingScreenMode.autoMatch,
    this.gstLabel,
  });

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  StreamSubscription? _offerSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _reconnectingSub;
  StreamSubscription? _reconnectedSub;
  Timer? _stallTimer;
  Timer? _pollTimer;
  bool _dispatchFailed = false;
  bool _stalled = false;
  bool _reconnecting = false;
  bool _animationsEnabled = false;
  bool _busy = false;

  /// The pending direct request (requestSent mode only).
  JobOffer? _request;

  /// The pending-offer fetch finished in requestSent mode.
  bool _requestChecked = false;

  bool get _isRequestSent => widget.mode == MatchingScreenMode.requestSent;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    Future.microtask(_start);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (enabled != _animationsEnabled) {
      _animationsEnabled = enabled;
      if (!_isRequestSent) {
        enabled ? _ctrl.repeat() : _ctrl.stop();
      }
    }
  }

  /// Subscribes to hub events once, then dispatches (autoMatch) or seeds the
  /// request (requestSent). Subscribing before dispatching keeps the first
  /// OfferCreated event from being lost.
  Future<void> _start() async {
    final hub = ref.read(jobHubClientProvider);

    _offerSub ??= hub.onOfferLifecycle.listen(_onOfferEvent);
    _statusSub ??= hub.onJobStatusChanged.listen(_onStatusEvent);
    _reconnectingSub ??= hub.onReconnecting.listen((_) {
      if (mounted) setState(() => _reconnecting = true);
    });
    _reconnectedSub ??= hub.onReconnected.listen((_) => _onReconnected());

    if (_isRequestSent) {
      await _loadRequest();
      if (!mounted) return;
      _pollTimer = Timer.periodic(MatchingScreen.pollInterval, (_) {
        if (mounted) _loadRequest();
      });
      return;
    }

    await _dispatch();
  }

  void _onOfferEvent(OfferLifecycleEvent event) {
    if (event.jobId != widget.jobId) return;
    if (_isRequestSent) {
      switch (event.eventType) {
        case OfferEventType.accepted:
          _goToBookedDetail();
        case OfferEventType.declined:
        case OfferEventType.expired:
          _returnToList('Your request wasn\'t taken up — pick another tradie.');
        case OfferEventType.created:
        case OfferEventType.unknown:
          break;
      }
      return;
    }
    final progress = ref.read(matchingProgressProvider(widget.jobId).notifier);
    progress.applyOfferEvent(event);
  }

  void _onStatusEvent(JobStatusEvent event) {
    if (event.jobId != widget.jobId) return;
    if (_isRequestSent) {
      if (event.status == 'Booked') {
        _goToBookedDetail();
      } else if (event.status == 'Cancelled') {
        _returnToList('This job was cancelled.');
      }
      return;
    }
    final progress = ref.read(matchingProgressProvider(widget.jobId).notifier);
    progress.applyStatusEvent(event);
    if (event.status == 'Booked') {
      // v1.7: a tradie accepting books the job (contract #5) — go straight
      // to the booked job detail instead of the retired match-result screen.
      _goToBookedDetail();
    } else if (event.status == 'AwaitingPayment' || event.status == 'Matched') {
      _goToBookedDetail();
    }
  }

  /// Connects (idempotent), joins the job group, triggers the run and re-reads
  /// state. Also used by the Try-again retry path (autoMatch only).
  Future<void> _dispatch() async {
    if (_busy) return;
    _busy = true;
    if (mounted) {
      setState(() {
        _dispatchFailed = false;
        _stalled = false;
      });
    }
    final hub = ref.read(jobHubClientProvider);
    final repo = ref.read(jobsRepositoryProvider);

    // API_BASE_URL via --dart-define-from-file; auto-rewritten for Android emulator.
    await hub.connect(baseUrl: resolveBaseUrl());
    if (!mounted) {
      _busy = false;
      return;
    }
    await hub.joinJobGroup(widget.jobId);

    final started = await repo.triggerMatch(widget.jobId);
    if (!mounted) {
      _busy = false;
      return;
    }

    // Re-read current offer/job state in case matching ran before screen entry
    // (issue #20) or a retry landed on an already-running match.
    await _refreshState();
    if (!mounted) {
      _busy = false;
      return;
    }

    if (!started &&
        ref.read(matchingProgressProvider(widget.jobId)).phase ==
            MatchingPhase.starting) {
      // Server rejected the dispatch AND nothing is in flight — a real failure.
      setState(() => _dispatchFailed = true);
    } else {
      setState(() {
        _dispatchFailed = false;
        _stalled = false;
      });
      _armStallTimer();
    }
    _busy = false;
  }

  /// Re-reads job status + pending offer after entry, retry, or reconnect.
  Future<void> _refreshState() async {
    final repo = ref.read(jobsRepositoryProvider);
    final progress = ref.read(matchingProgressProvider(widget.jobId).notifier);

    final job = await repo.getJobById(widget.jobId);
    if (!mounted) return;
    if (job != null) {
      if (job.status == 'AwaitingPayment' ||
          job.status == 'Matched' ||
          job.status == 'Booked') {
        _goToBookedDetail();
        return;
      }
      if (job.status == 'Cancelled') {
        progress.applyStatusEvent(
          JobStatusEvent(
            jobId: widget.jobId,
            status: 'Cancelled',
            reasonCode: 'no_tradie_found',
          ),
        );
        return;
      }
    }

    final pendingOffer = await repo.getPendingOffer(widget.jobId);
    if (!mounted) return;
    if (pendingOffer != null) {
      progress.seedFromOffer(pendingOffer);
    }
  }

  // ── Request-sent data (v1.7) ────────────────────────────────────────────────

  Future<void> _loadRequest() async {
    final repo = ref.read(jobsRepositoryProvider);
    final job = await repo.getJobById(widget.jobId);
    if (!mounted) return;
    if (job != null && job.status == 'Booked') {
      _goToBookedDetail();
      return;
    }
    if (job != null && job.status != 'Requested' && job.status != 'Matching') {
      // The direct request resolved some other way (declined, cancelled).
      _returnToList('Your request wasn\'t taken up — pick another tradie.');
      return;
    }

    try {
      final offer = await repo.getPendingOffer(widget.jobId);
      if (!mounted) return;
      setState(() {
        _request = offer;
        _requestChecked = true;
        _reconnecting = false;
      });
      if (offer == null && job != null) {
        // No pending request and the job is still Requested — the request
        // expired or was declined; the homeowner picks someone else.
        _returnToList(
          'Your request expired without a response — pick another tradie.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _requestChecked = true);
    }
  }

  Future<void> _onReconnected() async {
    if (!mounted) return;
    setState(() => _reconnecting = false);
    final hub = ref.read(jobHubClientProvider);
    await hub.joinJobGroup(widget.jobId);
    if (!mounted) return;
    if (_isRequestSent) {
      await _loadRequest();
      return;
    }
    await _refreshState();
    if (mounted &&
        ref.read(matchingProgressProvider(widget.jobId)).phase ==
            MatchingPhase.starting) {
      _armStallTimer();
    }
  }

  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(MatchingScreen.stallDuration, () {
      if (!mounted) return;
      final phase = ref.read(matchingProgressProvider(widget.jobId)).phase;
      if (phase == MatchingPhase.starting && !_dispatchFailed) {
        setState(() => _stalled = true);
      }
    });
  }

  /// Accept → booked job detail (v1.7: no match-result screen).
  Future<void> _goToBookedDetail() async {
    _stallTimer?.cancel();
    _pollTimer?.cancel();
    await _leave();
    if (mounted) {
      context.pushReplacement('/jobs/${widget.jobId}/detail');
    }
  }

  /// Decline / timeout / manual cancel → back to the tradie list with a
  /// truthful notice (P12-09).
  Future<void> _returnToList(String notice) async {
    _stallTimer?.cancel();
    _pollTimer?.cancel();
    await _leave();
    if (mounted) {
      context.pushReplacement('/jobs/${widget.jobId}/tradies');
      FixoNotice.info(context, notice);
    }
  }

  Future<void> _leave() async {
    await ref.read(jobHubClientProvider).leaveJobGroup(widget.jobId);
  }

  @override
  void dispose() {
    _offerSub?.cancel();
    _statusSub?.cancel();
    _reconnectingSub?.cancel();
    _reconnectedSub?.cancel();
    _stallTimer?.cancel();
    _pollTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isRequestSent) return _buildRequestSent(context, theme, isDark);

    final progress = ref.watch(matchingProgressProvider(widget.jobId));
    if (isV2Screen('ho_radar')) {
      // N-03: presentation only. The SignalR run, dispatch, stall watchdog
      // and cancel all stay in this state object.
      return ThRadarScreen(
        progress: progress,
        radar: _animationsEnabled ? _ctrl : null,
        reconnecting: _reconnecting,
        stalled: _stalled,
        dispatchFailed: _dispatchFailed,
        busy: _busy,
        themeMode: ref.watch(themeModeProvider),
        onTryAgain: _dispatch,
        onCancel: _cancelMatching,
      );
    }
    final done = progress.phase == MatchingPhase.noTradieFound;
    final matched = progress.phase == MatchingPhase.matched;
    final searching = !done && !matched;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              if (searching) ...[
                if (_animationsEnabled)
                  AnimatedBuilder(
                    key: const ValueKey('matching-radar'),
                    animation: _ctrl,
                    builder: (context, child) =>
                        _RadarRipple(progress: _ctrl.value),
                  )
                else
                  const _StaticSearchBadge(),
                const SizedBox(height: Space.s8),
                // Sequential offer progress — "Contacting Tradie 2…" (P3-09).
                Semantics(
                  liveRegion: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: Sizes.matchingTextBlock,
                    ),
                    child: AnimatedSwitcher(
                      duration: FixoDurations.toggle,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: KeyedSubtree(
                        key: ValueKey(progress.headline),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              progress.headline,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FW.bold,
                              ),
                            ),
                            const SizedBox(height: Space.s2),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.s6,
                              ),
                              child: Text(
                                progress.subhead,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_reconnecting) ...[
                  const SizedBox(height: Space.s4),
                  Text(
                    'Connection lost — reconnecting…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_stalled) ...[
                  const SizedBox(height: Space.s4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s6),
                    child: Text(
                      'This is taking longer than usual.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (progress.phase == MatchingPhase.contactingTradie &&
                    progress.offerIndex > 0) ...[
                  const SizedBox(height: Space.s6),
                  Semantics(
                    label: 'Contacting tradie ${progress.offerIndex}',
                    child: _OfferProgressDots(index: progress.offerIndex),
                  ),
                ],
              ] else if (matched) ...[
                const Icon(
                  Icons.check_circle,
                  size: Sizes.iconHero,
                  color: DesignTokens.green,
                ),
                const SizedBox(height: Space.s6),
                Text(
                  progress.headline,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FW.bold,
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.search_off,
                  size: Sizes.iconHero,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: Space.s6),
                Text(
                  progress.headline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FW.bold,
                  ),
                ),
                const SizedBox(height: Space.s2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s6),
                  child: Text(
                    progress.subhead,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
        bottomNavigationBar: StickyActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_dispatchFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s2),
                  child: Text(
                    'Could not start matching for this job.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (_dispatchFailed || _stalled)
                TextButton(
                  onPressed: _busy ? null : _dispatch,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(Sizes.tapMin),
                  ),
                  child: const Text('Try again'),
                ),
              TextButton(
                onPressed: () async {
                  // Factual cancel: DELETE /api/jobs/:id, then back to the
                  // tradie list — the run itself is server-owned.
                  _stallTimer?.cancel();
                  await _leave();
                  await ref
                      .read(jobsRepositoryProvider)
                      .cancelJob(widget.jobId);
                  if (context.mounted) {
                    context.pushReplacement('/jobs/${widget.jobId}/tradies');
                  }
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(Sizes.tapMin),
                ),
                child: Text(done ? 'Go Back' : 'Cancel'),
              ),
            ],
          ),
        ),
      ), // Scaffold
    ); // AnnotatedRegion
  }

  // ── Request-sent UI (v1.7 P12-09) ───────────────────────────────────────────

  Widget _buildRequestSent(BuildContext context, ThemeData theme, bool isDark) {
    if (isV2Screen('ho_request_sent')) {
      return ThRequestSentScreen(
        requestChecked: _requestChecked,
        reconnecting: _reconnecting,
        request: _request,
        gstLabel: widget.gstLabel,
        onPickSomeoneElse: () =>
            _returnToList('Pick another tradie — the job is still open.'),
        onCancelRequest: _cancelRequest,
        onExpired: () {
          if (mounted) setState(() {});
        },
      );
    }
    final request = _request;
    final expired = request != null && request.remaining() <= Duration.zero;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        appBar: FixoAppBar(title: 'Request sent'),
        body: !_requestChecked
            ? const Center(child: CircularProgressIndicator())
            : request == null
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Space.gutter),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_off_outlined,
                        size: Sizes.iconHero,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: Space.s6),
                      Text(
                        'This request is no longer open',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FW.bold,
                        ),
                      ),
                      const SizedBox(height: Space.s2),
                      Text(
                        'It may have expired or been answered. '
                        'Pick another tradie to keep going.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                child: ListView(
                  padding: FixoPadding.page,
                  children: [
                    const SizedBox(height: Space.s5),
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: Sizes.iconHero,
                      color: isDark
                          ? DesignTokens.brand300
                          : DesignTokens.brand700,
                    ),
                    const SizedBox(height: Space.s5),
                    Text(
                      'You asked ${_displayName(request)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FW.bold,
                      ),
                    ),
                    const SizedBox(height: Space.s2),
                    Text(
                      'We\'ll let you know the moment they reply — '
                      'usually well before the timer runs out.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.s6),
                    // Rate + GST label (D8): snapshot rate shown only
                    // when the server supplied one.
                    if (request.hourlyRateSnapshot != null)
                      _RateCard(
                        rate: request.hourlyRateSnapshot!,
                        gstLabel: widget.gstLabel,
                        name: _displayName(request),
                        isDark: isDark,
                      ),
                    const SizedBox(height: Space.s4),
                    if (_reconnecting)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.s3),
                        child: Text(
                          'Connection lost — reconnecting…',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    OfferCountdown(
                      offer: request,
                      onExpired: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    if (request.message?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: Space.s4),
                      _MessageCard(message: request.message!.trim()),
                    ],
                    const SizedBox(height: Space.s6),
                    Text(
                      expired
                          ? 'The request has run out of time. '
                                'Pick another tradie — the job stays open.'
                          : 'If they can\'t take it, the job stays open '
                                'and nothing is charged.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.stickyBarClearance),
                  ],
                ),
              ),
        bottomNavigationBar: StickyActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FixoPrimaryButton(
                key: const Key('pick_someone_else_button'),
                label: 'Pick someone else',
                onPressed: request == null || expired
                    ? () => _returnToList(
                        'Pick another tradie — the job is still open.',
                      )
                    : null,
              ),
              const SizedBox(height: Space.s2),
              TextButton(
                key: const Key('cancel_request_button'),
                onPressed: request == null || expired
                    ? null
                    : () async {
                        // Factual cancel: the only server-side cancel for a
                        // request-stage job is DELETE /api/jobs/:id (P6-03
                        // contract) — the request dies with the job.
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancel this request?'),
                            content: const Text(
                              'Cancelling closes the whole job request — '
                              'the tradie will be told and nothing is '
                              'charged. You can always post it again.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Keep waiting'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Cancel request'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        _pollTimer?.cancel();
                        await _leave();
                        await ref
                            .read(jobsRepositoryProvider)
                            .cancelJob(widget.jobId);
                        if (mounted) {
                          this.context.pushReplacement(
                            '/jobs/${widget.jobId}/tradies',
                          );
                          FixoNotice.info(
                            this.context,
                            'Request cancelled — the job is closed.',
                          );
                        }
                      },
                child: const Text('Cancel request'),
              ),
            ],
          ),
        ),
      ), // Scaffold
    ); // AnnotatedRegion
  }

  /// v2 radar Cancel / Go Back. Same factual cancel as the v1 button:
  /// DELETE /api/jobs/:id, then back to the tradie list — the run itself is
  /// server-owned.
  Future<void> _cancelMatching() async {
    _stallTimer?.cancel();
    await _leave();
    await ref.read(jobsRepositoryProvider).cancelJob(widget.jobId);
    if (mounted) {
      context.pushReplacement('/jobs/${widget.jobId}/tradies');
    }
  }

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
          'Cancelling closes the whole job request — the tradie will be told and nothing is charged. You can always post it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _pollTimer?.cancel();
    await _leave();
    await ref.read(jobsRepositoryProvider).cancelJob(widget.jobId);
    if (mounted) {
      context.pushReplacement('/jobs/${widget.jobId}/tradies');
      FixoNotice.info(context, 'Request cancelled — the job is closed.');
    }
  }

  String _displayName(JobOffer offer) {
    final name = offer.tradieName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'the tradie';
  }
}

/// Snapshot rate card: "their hourly rate for this job" + GST label (D8).
class _RateCard extends StatelessWidget {
  final Decimal rate;
  final String? gstLabel;
  final String name;
  final bool isDark;

  const _RateCard({
    required this.rate,
    required this.gstLabel,
    required this.name,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FixoCard(
      child: Row(
        children: [
          Icon(
            Icons.payments_outlined,
            size: Sizes.iconAction,
            color: isDark ? DesignTokens.brand300 : DesignTokens.brand700,
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatRate(rate)}${gstLabel == null ? '' : ' · $gstLabel'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FW.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: Space.s0_5),
                Text(
                  '$name\'s rate for this job — agreed before they book in.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

/// The homeowner's optional pre-acceptance message (D3: the only contact
/// channel before Booked — no chat thread exists yet).
class _MessageCard extends StatelessWidget {
  final String message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<THColors>()!;
    return FixoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: Sizes.iconAction,
            color: colors.textBrand,
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your message',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FW.semibold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Space.s0_5),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three expanding rings around a static centre — one full cycle every two
/// seconds. Only used when platform animations are enabled; the reduced-motion
/// alternative is [_StaticSearchBadge].
class _RadarRipple extends StatelessWidget {
  const _RadarRipple({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: Sizes.radarMaxDiameter,
      height: Sizes.radarMaxDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < Sizes.radarRingCount; i++)
            Builder(
              builder: (context) {
                final cycleProgress = (progress + i / Sizes.radarRingCount) % 1;
                final scale = 0.5 + (cycleProgress * 0.5);
                final fadeValue = (Alpha.divider * (1 - cycleProgress)).clamp(
                  0.0,
                  1.0,
                );
                return Opacity(
                  opacity: fadeValue,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: Sizes.radarMaxDiameter,
                      height: Sizes.radarMaxDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DesignTokens.brand500,
                          width: Sizes.borderWidthThick,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const _StaticSearchBadge(),
        ],
      ),
    ),
  );
}

/// Reduced-motion alternative to [_RadarRipple]: same centre badge without
/// the expanding rings.
class _StaticSearchBadge extends StatelessWidget {
  const _StaticSearchBadge();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: Sizes.radarMaxDiameter,
    height: Sizes.radarMaxDiameter,
    child: Center(
      child: Container(
        width: Sizes.radarCenter,
        height: Sizes.radarCenter,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: DesignTokens.brand500,
        ),
        child: const Icon(
          Icons.search,
          size: Sizes.radarIcon,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// Three dots that fill as more tradies are contacted — one dot per offer the
/// server has dispatched in the current run.
class _OfferProgressDots extends StatelessWidget {
  const _OfferProgressDots({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const maxDots = 5;
    final shown = index.clamp(1, maxDots);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < shown; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s1),
            child: Container(
              width: Sizes.heroDot,
              height: Sizes.heroDot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == shown - 1
                    ? DesignTokens.amber
                    : DesignTokens.brand500.withValues(alpha: Alpha.shadow),
              ),
            ),
          ),
      ],
    );
  }
}
