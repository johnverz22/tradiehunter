import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../viewmodels/auth_viewmodel.dart' show resolveBaseUrl;
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../feedback/th_notice.dart';
import 'ho_radar_screen.dart';
import 'ho_request_sent_screen.dart';

/// Which waiting experience this screen runs.
enum ThMatchingMode {
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

/// Homeowner waiting screen for both matching paths (v2).
///
/// This is the stateful controller that used to live in
/// `views/jobs/matching_screen.dart`; the presentation is [ThRadarScreen]
/// (autoMatch) and [ThRequestSentScreen] (requestSent). The server owns the
/// matching run (offer → timeout/decline → next tradie → broaden → cancel), so
/// this screen only renders progress from SignalR and never polls in autoMatch.
class ThMatchingScreen extends ConsumerStatefulWidget {
  const ThMatchingScreen({
    super.key,
    required this.jobId,
    this.mode = ThMatchingMode.autoMatch,
    this.gstLabel,
  });

  final String jobId;
  final ThMatchingMode mode;

  /// D8 GST label for the requested tradie's snapshot rate
  /// ("Incl. GST" / "No GST charged"); null when unknown — the label is
  /// omitted rather than guessed.
  final String? gstLabel;

  /// How long the screen waits in `starting` before telling the homeowner the
  /// run may be stalled. Offer timeouts themselves stay server-owned.
  static const stallDuration = Duration(seconds: 45);

  /// Poll cadence for the request-sent fallback (SignalR is primary).
  static const pollInterval = Duration(seconds: 15);

  @override
  ConsumerState<ThMatchingScreen> createState() => _ThMatchingScreenState();
}

class _ThMatchingScreenState extends ConsumerState<ThMatchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  StreamSubscription<OfferLifecycleEvent>? _offerSub;
  StreamSubscription<JobStatusEvent>? _statusSub;
  StreamSubscription<void>? _reconnectingSub;
  StreamSubscription<void>? _reconnectedSub;
  Timer? _stallTimer;
  Timer? _pollTimer;
  bool _dispatchFailed = false;
  bool _stalled = false;
  bool _reconnecting = false;
  bool _animationsEnabled = false;
  bool _busy = false;

  /// This screen holds one ref-counted watch on the job's hub group.
  bool _watching = false;
  late final JobHubClient _hub = ref.read(jobHubClientProvider);

  /// The pending direct request (requestSent mode only).
  JobOffer? _request;

  /// The pending-offer fetch finished in requestSent mode.
  bool _requestChecked = false;

  bool get _isRequestSent => widget.mode == ThMatchingMode.requestSent;

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
      // Status events (booked / cancelled) for this job only arrive through
      // its hub group; the poll below stays as the fallback.
      unawaited(_watch());
      await _loadRequest();
      if (!mounted) return;
      _pollTimer = Timer.periodic(ThMatchingScreen.pollInterval, (_) {
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
          _returnToList(
            'Your request wasn\u2019t taken up — pick another tradie.',
          );
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
    if (event.status == 'Booked' ||
        event.status == 'AwaitingPayment' ||
        event.status == 'Matched') {
      // v1.7: a tradie accepting books the job (contract #5) — go straight
      // to the booked job detail instead of the retired match-result screen.
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
    await _watch();

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
      _returnToList('Your request wasn\u2019t taken up — pick another tradie.');
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
    // The hub client re-joins watched job groups itself before emitting
    // onReconnected, so only the state re-read is left to do here.
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
    _stallTimer = Timer(ThMatchingScreen.stallDuration, () {
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
      THNotice.info(context, notice);
    }
  }

  /// Ref-counted join of this job's hub group (once per screen).
  Future<void> _watch() async {
    if (_watching) return;
    _watching = true;
    await _hub.watchJob(widget.jobId);
  }

  Future<void> _leave() async {
    if (!_watching) return;
    _watching = false;
    await _hub.unwatchJob(widget.jobId);
  }

  @override
  void dispose() {
    _offerSub?.cancel();
    _statusSub?.cancel();
    _reconnectingSub?.cancel();
    _reconnectedSub?.cancel();
    _stallTimer?.cancel();
    _pollTimer?.cancel();
    // Backing out (not just the accept/decline paths) must release the group.
    unawaited(_leave());
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRequestSent) {
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
    final progress = ref.watch(matchingProgressProvider(widget.jobId));
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

  /// Radar Cancel / Go Back. Factual cancel: DELETE /api/jobs/:id, then back
  /// to the tradie list — the run itself is server-owned.
  Future<void> _cancelMatching() async {
    _stallTimer?.cancel();
    await _leave();
    await ref.read(jobsRepositoryProvider).cancelJob(widget.jobId);
    if (mounted) {
      context.pushReplacement('/jobs/${widget.jobId}/tradies');
    }
  }

  /// The only server-side cancel for a request-stage job is DELETE
  /// /api/jobs/:id (P6-03 contract) — the request dies with the job.
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
      THNotice.info(context, 'Request cancelled — the job is closed.');
    }
  }
}
