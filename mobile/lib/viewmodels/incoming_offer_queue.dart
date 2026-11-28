import 'package:flutter/foundation.dart';

import '../models/marketplace.dart';

/// Immutable queue of live job offers waiting on the tradie (QA plan §3).
///
/// Pure value logic, no I/O or timers, so ordering, de-duplication, expiry and
/// clock-drift handling are unit-testable. The coordinator owns one of these
/// and replaces it as events arrive.
@immutable
class IncomingOfferQueue {
  const IncomingOfferQueue({
    this.offers = const [],
    this.clockOffset = Duration.zero,
  });

  /// Live offers, earliest expiry first.
  final List<JobOffer> offers;

  /// `serverNow − deviceNow`. Add to the device clock to get server time, so a
  /// phone with a wrong clock still counts down against the real deadline.
  final Duration clockOffset;

  bool get isEmpty => offers.isEmpty;
  bool get isNotEmpty => offers.isNotEmpty;
  int get length => offers.length;

  /// Offer currently in front of the tradie (earliest expiry), or null.
  JobOffer? get head => offers.isEmpty ? null : offers.first;

  /// Server-corrected "now" for countdown maths.
  DateTime nowUtc([DateTime? deviceNow]) =>
      (deviceNow ?? DateTime.now()).toUtc().add(clockOffset);

  /// Time left on [offer] against the corrected clock; zero once expired.
  Duration remaining(JobOffer offer, [DateTime? deviceNow]) {
    final left = offer.expiresAtUtc.difference(nowUtc(deviceNow));
    return left.isNegative ? Duration.zero : left;
  }

  bool isExpired(JobOffer offer, [DateTime? deviceNow]) =>
      !offer.expiresAtUtc.isAfter(nowUtc(deviceNow));

  /// Replaces the queue with an authoritative server list. Non-pending and
  /// expired entries are dropped. The clock offset is taken from the first
  /// offer that carries `serverNowUtc`, else the previous offset is kept.
  IncomingOfferQueue replaceAll(
    Iterable<JobOffer> fetched, {
    DateTime? deviceNow,
  }) {
    final device = (deviceNow ?? DateTime.now()).toUtc();
    var offset = clockOffset;
    for (final o in fetched) {
      final serverNow = o.serverNowUtc;
      if (serverNow != null) {
        offset = serverNow.difference(device);
        break;
      }
    }
    final next = IncomingOfferQueue(offers: const [], clockOffset: offset);
    return next._withOffers(fetched, device);
  }

  /// Adds or refreshes one offer (keyed by id).
  IncomingOfferQueue upsert(JobOffer offer, {DateTime? deviceNow}) {
    final device = (deviceNow ?? DateTime.now()).toUtc();
    final byId = {for (final o in offers) o.id: o, offer.id: offer};
    return _withOffers(byId.values, device);
  }

  /// Removes by offer id (no-op when absent).
  IncomingOfferQueue removeOffer(String offerId) {
    if (!offers.any((o) => o.id == offerId)) return this;
    return IncomingOfferQueue(
      offers: offers.where((o) => o.id != offerId).toList(),
      clockOffset: clockOffset,
    );
  }

  /// Removes every offer for [jobId] (job closed, booked elsewhere, ...).
  IncomingOfferQueue removeJob(String jobId) {
    if (!offers.any((o) => o.jobId == jobId)) return this;
    return IncomingOfferQueue(
      offers: offers.where((o) => o.jobId != jobId).toList(),
      clockOffset: clockOffset,
    );
  }

  /// Drops offers past their (server-corrected) deadline.
  IncomingOfferQueue pruneExpired([DateTime? deviceNow]) {
    final kept = offers.where((o) => !isExpired(o, deviceNow)).toList();
    if (kept.length == offers.length) return this;
    return IncomingOfferQueue(offers: kept, clockOffset: clockOffset);
  }

  IncomingOfferQueue _withOffers(Iterable<JobOffer> source, DateTime device) {
    final live =
        source
            .where((o) => o.isPending && !isExpired(o, device))
            .toList()
          ..sort((a, b) => a.expiresAtUtc.compareTo(b.expiresAtUtc));
    return IncomingOfferQueue(offers: live, clockOffset: clockOffset);
  }
}
