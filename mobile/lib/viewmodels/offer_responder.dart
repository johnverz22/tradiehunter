import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace.dart';
import '../repositories/jobs_repository.dart';
import 'jobs_viewmodel.dart';

/// Result of an offer accept/decline command (V15-14).
enum OfferResponseOutcome {
  /// Server accepted the command; SignalR carries the resulting state.
  success,

  /// Server rejected the command (stale/already-answered offer, 409) or the
  /// request failed. Callers reconcile by refetching the pending offer.
  rejected,

  /// A command for this job is already in flight — nothing was dispatched.
  alreadyInFlight,
}

/// Shared accept/decline command path for job offers (V15-14).
///
/// Both the tradie dashboard lead cards and the request-detail screen go
/// through this single object so one tap dispatches exactly one authorized
/// POST to `…/offers/{id}/respond`, and concurrent duplicates — including a
/// dashboard tap racing a detail-screen submit — can never double-dispatch.
///
/// The responder is provider-scoped, so the in-flight set is shared app-wide.
/// It never mutates job state itself; booking updates arrive only through the
/// server's SignalR status/lifecycle events after a successful command.
class OfferResponder {
  OfferResponder(this._repo);

  final JobsRepository _repo;
  final Set<String> _inFlight = {};

  /// Job ids with a response currently being dispatched.
  bool isResponding(String jobId) => _inFlight.contains(jobId);

  /// Dispatches one accept/decline command for [offer] on [jobId].
  ///
  /// Returns [OfferResponseOutcome.alreadyInFlight] without dispatching when
  /// a command for the same job is still running, so callers can safely wire
  /// this straight to a button tap.
  Future<OfferResponseOutcome> respond({
    required String jobId,
    required JobOffer offer,
    required bool accept,
  }) async {
    if (!_inFlight.add(jobId)) return OfferResponseOutcome.alreadyInFlight;
    try {
      final ok = await _repo.respondToOffer(
        jobId,
        offer.id,
        response: accept ? 'Accepted' : 'Declined',
      );
      return ok ? OfferResponseOutcome.success : OfferResponseOutcome.rejected;
    } finally {
      _inFlight.remove(jobId);
    }
  }
}

final offerResponderProvider = Provider<OfferResponder>(
  (ref) => OfferResponder(ref.watch(jobsRepositoryProvider)),
);
