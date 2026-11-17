import 'api_helper.dart';
import 'auth_helper.dart' show pollUntil;
import 'test_config.dart';

/// Self-seeding fixtures — each factory drives a job through the real API
/// (create → match → offer accept → receipt → staff verify → lifecycle) and
/// returns the job ID in the requested state. Tests then navigate straight to
/// the route they want instead of hunting for a matching card in the job list,
/// which removes the dependency on p3-smoke.sh / p4-smoke.sh ordering.
///
/// Flow versions: jobs created today are stamped flowVersion 2
/// (Requested → Booked → InProgress → AwaitingConfirmation → approve →
/// AwaitingPayment → PaymentReview → Completed — payment at completion).
/// Legacy flowVersion-1 jobs keep pay-before-booking
/// (accept → AwaitingPayment → PaymentReview → Booked → … → Completed).
/// The factories branch on the job's own `flowVersion` so the same suite
/// works against either backend configuration.
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
    return ApiHelper.createJob(token, title: _title(tag), hours: 2);
  }

  /// Job in `Requested` with a live pending offer addressed to the test tradie.
  static Future<(int jobId, int offerId)> pendingOfferJob({
    String tag = 'offered',
  }) async {
    final homeowner = await ApiHelper.homeownerToken;
    final tradie = await ApiHelper.tradieToken;
    final jobId = await ApiHelper.createJob(
      homeowner,
      title: _title(tag),
      hours: 2,
    );
    await ApiHelper.dispatchMatch(jobId, homeowner);

    Map<String, dynamic>? offer;
    await pollUntil(
      () async {
        offer = await ApiHelper.getPendingOffer(jobId, tradie);
        return offer != null;
      },
      timeout: const Duration(seconds: 45),
      interval: const Duration(seconds: 2),
    );
    return (jobId, offer!['id'] as int);
  }

  /// Job in `AwaitingPayment` with payment not yet opened.
  ///
  /// v2: booked → checked in → checked out → homeowner approved the
  /// completion summary → AwaitingPayment.
  /// v1: offer accepted → AwaitingPayment (pay-before-booking).
  static Future<int> awaitingPaymentJob({
    String tag = 'awaiting-payment',
  }) async {
    final (jobId, offerId) = await pendingOfferJob(tag: tag);
    final homeowner = await ApiHelper.homeownerToken;
    final tradie = await ApiHelper.tradieToken;
    await ApiHelper.respondToOffer(jobId, offerId, 'Accepted', tradie);

    if (await _flowVersion(jobId, homeowner) >= 2) {
      await _waitForStatus(jobId, 'Booked');
      await ApiHelper.checkIn(jobId, tradie);
      await _waitForStatus(jobId, 'InProgress');
      await ApiHelper.checkOut(jobId, tradie);
      await _waitForStatus(jobId, 'AwaitingConfirmation');
      await ApiHelper.approveJob(jobId, homeowner);
      await _waitForStatus(jobId, 'AwaitingPayment');
    } else {
      await _waitForStatus(jobId, 'AwaitingPayment');
    }
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

  /// Job in `Booked` matched to the test tradie.
  ///
  /// v2: offer accepted → Booked directly (no payment gate).
  /// v1: accept → AwaitingPayment → receipt → staff verify → Booked.
  static Future<int> bookedJob({String tag = 'booked'}) async {
    final (jobId, offerId) = await pendingOfferJob(tag: tag);
    final homeowner = await ApiHelper.homeownerToken;
    final tradie = await ApiHelper.tradieToken;
    await ApiHelper.respondToOffer(jobId, offerId, 'Accepted', tradie);

    if (await _flowVersion(jobId, homeowner) >= 2) {
      await _waitForStatus(jobId, 'Booked');
      return jobId;
    }

    await _waitForStatus(jobId, 'AwaitingPayment');
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
  static Future<int> awaitingConfirmationJob({
    String tag = 'awaiting-confirmation',
  }) async {
    final jobId = await inProgressJob(tag: tag);
    await ApiHelper.checkOut(jobId, await ApiHelper.tradieToken);
    await _waitForStatus(jobId, 'AwaitingConfirmation');
    return jobId;
  }

  /// Job in `Completed`.
  ///
  /// v2: … → AwaitingPayment → receipt → staff verify → Completed.
  /// v1: AwaitingConfirmation → homeowner confirm → Completed.
  static Future<int> completedJob({String tag = 'completed'}) async {
    final homeowner = await ApiHelper.homeownerToken;
    if (await _latestFlowVersion() >= 2) {
      final jobId = await paymentReviewJob(tag: tag);
      final staff = await ApiHelper.staffToken;
      final payment = await ApiHelper.getPayment(jobId, homeowner);
      await ApiHelper.verifyPayment(payment['paymentId'] as int, staff);
      await _waitForStatus(jobId, 'Completed');
      return jobId;
    }
    final jobId = await awaitingConfirmationJob(tag: tag);
    await ApiHelper.confirmCompletion(jobId, homeowner);
    await _waitForStatus(jobId, 'Completed');
    return jobId;
  }

  /// Project job in `Requested` with a pending QuoteRequest offer for the
  /// test tradie and one submitted quote. Returns (jobId, quoteId, tradieId).
  static Future<(int jobId, int quoteId, String tradieId)> quotedJob({
    String tag = 'quoted',
    double amount = 2000,
  }) async {
    final homeowner = await ApiHelper.homeownerToken;
    final tradie = await ApiHelper.tradieToken;
    final jobId = await ApiHelper.createJob(
      homeowner,
      title: _title(tag),
      jobType: 'Project',
      budgetMin: amount * 0.8,
      budgetMax: amount * 1.2,
      scopeNotes: 'Integration-test project scope.',
    );
    await ApiHelper.dispatchMatch(jobId, homeowner);

    // Wait until the matching engine has issued the tradie a QuoteRequest.
    Map<String, dynamic>? offer;
    await pollUntil(
      () async {
        offer = await ApiHelper.getPendingOffer(jobId, tradie);
        return offer != null;
      },
      timeout: const Duration(seconds: 45),
      interval: const Duration(seconds: 2),
    );

    final profile = await ApiHelper.getMyProfile(tradie);
    final tradieId = profile['id'] as String;

    Map<String, dynamic> quote;
    try {
      quote = await ApiHelper.submitQuote(
        jobId,
        tradie,
        pricingModel: 'Fixed',
        amount: amount,
        gstIncluded: false,
      );
    } catch (e) {
      // Unregistered tradies must not charge GST; registered ones must.
      // Retry once with the opposite flag if the profile disagrees.
      if (!e.toString().contains('GST')) rethrow;
      quote = await ApiHelper.submitQuote(
        jobId,
        tradie,
        pricingModel: 'Fixed',
        amount: amount,
        gstIncluded: true,
      );
    }
    return (jobId, quote['id'] as int, tradieId);
  }

  /// Booked job (matched to the test tradie) with one Pending price
  /// adjustment proposed via the API. Returns (jobId, adjustmentId).
  static Future<(int jobId, int adjustmentId)> pendingAdjustmentJob({
    String tag = 'adjustment',
  }) async {
    final jobId = await bookedJob(tag: tag);
    final tradie = await ApiHelper.tradieToken;
    final adj = await ApiHelper.proposeAdjustment(
      jobId,
      tradie,
      kind: 'Materials',
      description: 'Fixture extra cost — treated pine shelving.',
      amount: 145.50,
    );
    return (jobId, adj['id'] as int);
  }

  /// Test tradie's own user id (for `/tradie/:id?jobId=` routes).
  static Future<String> tradieProfileId() async {
    final profile = await ApiHelper.getMyProfile(await ApiHelper.tradieToken);
    return profile['id'] as String;
  }

  /// The flow version new jobs are stamped with on this backend — used to
  /// pick the right terminal path in [completedJob].
  static Future<int> _latestFlowVersion() async {
    final homeowner = await ApiHelper.homeownerToken;
    final jobId = await requestedJob(tag: 'flowprobe');
    return _flowVersion(jobId, homeowner);
  }

  static Future<int> _flowVersion(int jobId, String token) async {
    final job = await ApiHelper.getJob(jobId, token);
    return (job['flowVersion'] as num?)?.toInt() ?? 1;
  }

  // ── Competing tradies ──────────────────────────────────────────────────────

  /// Marks the demo tradie unavailable so sequential matching targets the
  /// test tradie. Only needed by suites that dispatch real offers
  /// (matching + any fixture above Requested). No-op when the demo account
  /// doesn't exist on this backend.
  static Future<void> parkCompetingTradies() async {
    try {
      await ApiHelper.setAvailability(
        kDemoTradieEmail,
        kDemoTradiePassword,
        false,
      );
    } catch (_) {
      /* demo seed absent — nothing competing to park */
    }
  }

  static Future<void> restoreCompetingTradies() async {
    try {
      await ApiHelper.setAvailability(
        kDemoTradieEmail,
        kDemoTradiePassword,
        true,
      );
    } catch (_) {
      /* demo seed absent */
    }
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
