import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace.dart';
import '../repositories/job_hub_client.dart';
import '../ui/design/th_tokens.dart' show THDurations;
import 'auth_viewmodel.dart' show resolveBaseUrl;
import 'incoming_offer_queue.dart';
import 'jobs_viewmodel.dart';
import 'offer_responder.dart';

/// Result of answering an offer from the incoming-request alert.
class IncomingOfferResult {
  const IncomingOfferResult(this.outcome, {this.errorCode});

  final OfferResponseOutcome outcome;

  /// Machine-readable `ApiError.code` when [outcome] is rejected.
  final String? errorCode;
}

/// App-scoped owner of the tradie's live offers (QA plan §3).
///
/// Lives outside any screen so an offer is caught whichever page the tradie is
/// on. Sources, merged into one [IncomingOfferQueue]:
///  * SignalR `OfferLifecycleEvent` — created refetches; every closing kind
///    (expired, declined, accepted, withdrawn, superseded, closed) removes it;
///  * `GET /api/offers/pending/mine` on start, resume and reconnect, so offers
///    that arrived while the app was closed still surface;
///  * a 1 s ticker that drops offers past their server-corrected deadline.
///
/// It never changes job state itself: answering goes through
/// [OfferResponder] and booking arrives over the usual status events.
class IncomingOfferCoordinator extends StateNotifier<IncomingOfferQueue>
    with WidgetsBindingObserver {
  IncomingOfferCoordinator(this._ref) : super(const IncomingOfferQueue());

  final Ref _ref;
  StreamSubscription<OfferLifecycleEvent>? _offerSub;
  StreamSubscription<void>? _reconnectSub;
  Timer? _ticker;
  bool _started = false;

  bool get isStarted => _started;

  /// Begins listening. Safe to call repeatedly (e.g. from every tradie home
  /// mount): later calls just refetch.
  Future<void> start() async {
    if (_started) {
      await refresh();
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    final hub = _ref.read(jobHubClientProvider);
    _offerSub = hub.onOfferLifecycle.listen(_onOfferEvent);
    _reconnectSub = hub.onReconnected.listen((_) => unawaited(refresh()));
    _ticker = Timer.periodic(THDurations.countdownTick, (_) => _tick());

    try {
      await hub.connect(baseUrl: resolveBaseUrl());
    } catch (e) {
      // The hub retries on its own; the HTTP fetch below still works.
      debugPrint('IncomingOfferCoordinator: hub connect failed: $e');
    }
    await refresh();
  }

  /// Stops listening and clears the queue (sign-out, role change).
  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _offerSub?.cancel();
    _reconnectSub?.cancel();
    _ticker?.cancel();
    _offerSub = null;
    _reconnectSub = null;
    _ticker = null;
    if (mounted) state = const IncomingOfferQueue();
  }

  /// Replaces the queue with the server's current list. A failed fetch keeps
  /// the existing queue: an outage is not "no offers".
  Future<void> refresh() async {
    if (!_started) return;
    try {
      final fetched = await _ref
          .read(jobsRepositoryProvider)
          .getMyPendingOffers();
      if (!mounted || !_started) return;
      state = state.replaceAll(fetched);
    } catch (e) {
      debugPrint('IncomingOfferCoordinator: refresh failed: $e');
    }
  }

  /// Accepts or declines [offer]. On success the offer leaves the queue at
  /// once; on rejection the queue is reconciled against the server so a stale
  /// card disappears instead of lingering.
  Future<IncomingOfferResult> respond(
    JobOffer offer, {
    required bool accept,
  }) async {
    final responder = _ref.read(offerResponderProvider);
    final outcome = await responder.respond(
      jobId: offer.jobId,
      offer: offer,
      accept: accept,
    );
    switch (outcome) {
      case OfferResponseOutcome.success:
        if (mounted) state = state.removeOffer(offer.id);
        return IncomingOfferResult(outcome);
      case OfferResponseOutcome.rejected:
        final code = responder.lastErrorCode;
        unawaited(refresh());
        return IncomingOfferResult(outcome, errorCode: code);
      case OfferResponseOutcome.alreadyInFlight:
        return IncomingOfferResult(outcome);
    }
  }

  void _onOfferEvent(OfferLifecycleEvent event) {
    if (!mounted) return;
    switch (event.eventType) {
      case OfferEventType.created:
        unawaited(refresh());
      case OfferEventType.expired ||
          OfferEventType.declined ||
          OfferEventType.accepted ||
          OfferEventType.withdrawn ||
          OfferEventType.superseded ||
          OfferEventType.closed:
        state = event.offerId.isNotEmpty
            ? state.removeOffer(event.offerId)
            : state.removeJob(event.jobId);
      case OfferEventType.unknown:
        break;
    }
  }

  void _tick() {
    if (!mounted) return;
    final next = state.pruneExpired();
    if (!identical(next, state)) state = next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final incomingOfferCoordinatorProvider =
    StateNotifierProvider<IncomingOfferCoordinator, IncomingOfferQueue>(
      (ref) => IncomingOfferCoordinator(ref),
    );
