import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../widgets/sticky_action_bar.dart';

/// Mockup 07-matching: radar ripple + sequential offer progress.
///
/// Calls POST /api/jobs/:id/match, then watches SignalR for the server's
/// offer lifecycle events — the server owns the run (offer → timeout/decline
/// → next tradie → broaden → cancel), so this screen only renders progress
/// and never polls. See P3-09 / P3-10.
class MatchingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const MatchingScreen({super.key, required this.jobId});

  /// How long the screen waits in `starting` before telling the homeowner the
  /// run may be stalled. Offer timeouts themselves stay server-owned — this
  /// only covers the case where no offer event ever arrives.
  static const stallDuration = Duration(seconds: 45);

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
  bool _dispatchFailed = false;
  bool _stalled = false;
  bool _reconnecting = false;
  bool _animationsEnabled = false;
  bool _busy = false;

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
      enabled ? _ctrl.repeat() : _ctrl.stop();
    }
  }

  /// Subscribes to hub events once, then dispatches the match run. Subscribing
  /// before dispatching keeps the first OfferCreated event from being lost.
  Future<void> _start() async {
    final hub = ref.read(jobHubClientProvider);
    final progress = ref.read(matchingProgressProvider(widget.jobId).notifier);

    _offerSub ??= hub.onOfferLifecycle.listen(progress.applyOfferEvent);
    _statusSub ??= hub.onJobStatusChanged.listen((event) {
      progress.applyStatusEvent(event);
      if (event.jobId == widget.jobId &&
          (event.status == 'AwaitingPayment' || event.status == 'Matched')) {
        _goToResult();
      }
    });
    _reconnectingSub ??= hub.onReconnecting.listen((_) {
      if (mounted) setState(() => _reconnecting = true);
    });
    _reconnectedSub ??= hub.onReconnected.listen((_) => _onReconnected());

    await _dispatch();
  }

  /// Connects (idempotent), joins the job group, triggers the run and re-reads
  /// state. Also used by the Try-again retry path.
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
      if (job.status == 'AwaitingPayment' || job.status == 'Matched') {
        _goToResult();
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

  /// Reconnected SignalR gets a new connection id — group membership is gone,
  /// so re-join and re-read in case events landed while disconnected.
  Future<void> _onReconnected() async {
    if (!mounted) return;
    setState(() => _reconnecting = false);
    final hub = ref.read(jobHubClientProvider);
    await hub.joinJobGroup(widget.jobId);
    if (!mounted) return;
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

  Future<void> _goToResult() async {
    _stallTimer?.cancel();
    await _leave();
    if (mounted) {
      context.pushReplacement('/jobs/${widget.jobId}/match');
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
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(matchingProgressProvider(widget.jobId));
    final done = progress.phase == MatchingPhase.noTradieFound;
    final matched = progress.phase == MatchingPhase.matched;
    final searching = !done && !matched;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                // Factual cancel: DELETE /api/jobs/:id, then pop.
                _stallTimer?.cancel();
                await _leave();
                await ref.read(jobsRepositoryProvider).cancelJob(widget.jobId);
                if (context.mounted) context.pop();
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
                    final cycleProgress =
                        (progress + i / Sizes.radarRingCount) % 1;
                    final scale = 0.5 + (cycleProgress * 0.5);
                    final fadeValue =
                        (Alpha.divider * (1 - cycleProgress)).clamp(0.0, 1.0);
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
