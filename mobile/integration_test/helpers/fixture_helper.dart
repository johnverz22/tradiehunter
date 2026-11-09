import 'api_helper.dart';
import 'auth_helper.dart' show pollUntil;
import 'test_config.dart';

/// Self-seeding fixtures — each factory drives a job through the real API
/// (create → match → offer accept → receipt → staff verify → lifecycle) and
/// returns the job ID in the requested state. Tests then navigate straight to
/// the route they want instead of hunting for a matching card in the job list,
/// which removes the dependency on p3-smoke.sh / p4-smoke.sh ordering.
///
/// Note: offer dispatch is sequential and goes to the top-ranked available
/// tradie. To make the test tradie (kTradieEmail) the deterministic target,
/// call [parkCompetingTradies] in setUpAll and [restoreCompetingTradies] in
/// tearDownAll.
class FixtureHelper {
  FixtureHelper._();

  static String _title(String tag) =>
      'Fixture — $tag ${DateTime.now().millisecondsSinceEpoch}';

  /// Job in `Requested`, matching not yet dispatched.
  static Future<int> requestedJob({String tag = 'requested'}) async {
    final token = await ApiHelper.homeownerToken;
    return ApiHelper.createJob(token, title: _title(tag));
  }

  /// Job in `Requested` with a live pending offer addressed to the test tradie.
  static Future<(int jobId, int offerId)> pendingOfferJob(
      {String tag = 'offered'}) async {
    final homeowner = await ApiHelper.homeownerToken;
    final tradie = await ApiHelper.tradieToken;
    final jobId =
        await ApiHelper.createJob(homeowner, title: _title(tag));
    await ApiHelper.dispatchMatch(jobId, homeowner);

    Map<String, dynamic>? offer;
    await pollUntil(() async {
      offer = await ApiHelper.getPendingOffer(jobId, tradie);
      return offer != null;
    }, timeout: const Duration(seconds: 45), interval: const Duration(seconds: 2));
    return (jobId, offer!['id'] as int);
  }

  /// Job in `AwaitingPayment`, matched to the test tradie.
  static Future<int> awaitingPaymentJob({String tag = 'awaiting-payment'}) async {
    final (jobId, offerId) = await pendingOfferJob(tag: tag);
    final tradie = await ApiHelper.tradieToken;
    await ApiHelper.respondToOffer(jobId, offerId, 'Accepted', tradie);
    await _waitForStatus(jobId, 'AwaitingPayment');
    return jobId;
  }

  /// Job in `PaymentReview` (receipt uploaded, not yet verified).
  static Future<int> paymentReviewJob({String tag = 'payment-review'}) async {
    final jobId = await awaitingPaymentJob(tag: tag);
    final homeowner = await ApiHelper.homeownerToken;
    await ApiHelper.getPayment(jobId, homeowner); // opens the payment
    await ApiHelper.uploadReceipt(jobId, homeowner);
    await _waitForStatus(jobId, 'PaymentReview');
    return jobId;
  }

  /// Job in `Booked` (receipt verified by staff), matched to the test tradie.
  static Future<int> bookedJob({String tag = 'booked'}) async {
    final jobId = await awaitingPaymentJob(tag: tag);
    final homeowner = await ApiHelper.homeownerToken;
    final staff = await ApiHelper.staffToken;
    final payment = await ApiHelper.getPayment(jobId, homeowner);
    await ApiHelper.uploadReceipt(jobId, homeowner);
    await _waitForStatus(jobId, 'PaymentReview');
    await ApiHelper.verifyPayment(payment['paymentId'] as int, staff);
    await _waitForStatus(jobId, 'Booked');
    return jobId;
  }

  /// Job in `InProgress` (tradie checked in via API).
  static Future<int> inProgressJob({String tag = 'in-progress'}) async {
    final jobId = await bookedJob(tag: tag);
    await ApiHelper.checkIn(jobId, await ApiHelper.tradieToken);
    await _waitForStatus(jobId, 'InProgress');
    return jobId;
  }

  /// Job in `AwaitingConfirmation` (tradie checked out via API).
  static Future<int> awaitingConfirmationJob(
      {String tag = 'awaiting-confirmation'}) async {
    final jobId = await inProgressJob(tag: tag);
    await ApiHelper.checkOut(jobId, await ApiHelper.tradieToken);
    await _waitForStatus(jobId, 'AwaitingConfirmation');
    return jobId;
  }

  /// Job in `Completed` (homeowner confirmed via API).
  static Future<int> completedJob({String tag = 'completed'}) async {
    final jobId = await awaitingConfirmationJob(tag: tag);
    await ApiHelper.confirmCompletion(jobId, await ApiHelper.homeownerToken);
    await _waitForStatus(jobId, 'Completed');
    return jobId;
  }

  // ── Competing tradies ──────────────────────────────────────────────────────

  /// Marks the demo tradie unavailable so sequential matching targets the
  /// test tradie. Only needed by suites that dispatch real offers
  /// (matching + any fixture above Requested). No-op when the demo account
  /// doesn't exist on this backend.
  static Future<void> parkCompetingTradies() async {
    try {
      await ApiHelper.setAvailability(
          kDemoTradieEmail, kDemoTradiePassword, false);
    } catch (_) {/* demo seed absent — nothing competing to park */}
  }

  static Future<void> restoreCompetingTradies() async {
    try {
      await ApiHelper.setAvailability(
          kDemoTradieEmail, kDemoTradiePassword, true);
    } catch (_) {/* demo seed absent */}
  }

  static Future<void> _waitForStatus(int jobId, String expected) async {
    final token = await ApiHelper.homeownerToken;
    await pollUntil(
      () async => (await ApiHelper.getJobStatus(jobId, token)) == expected,
      timeout: const Duration(seconds: 45),
      interval: const Duration(seconds: 2),
    );
  }
}
