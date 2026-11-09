// P4 — Manual Payment & Receipt Upload
//
// Self-seeding: fixtures drive a fresh job to AwaitingPayment / PaymentReview
// via the API, so no matching run or pre-seeded state is needed.
//
//   flutter test integration_test/payment_test.dart --device-id <id>

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/api_helper.dart';
import 'helpers/auth_helper.dart';
import 'helpers/fixture_helper.dart';
import 'helpers/test_config.dart';

/// Mirrors `BankDetails.isAvailable` (V15-08): instructions count as usable
/// only when both fields are non-placeholder and the account number isn't
/// all zeros — dev config ships '00-0000-0000000-00', which is a sentinel.
Future<bool> _instructionsUsable(int jobId) async {
  final payment =
      await ApiHelper.getPayment(jobId, await ApiHelper.homeownerToken);
  final bank = payment['bankDetails'] as Map<String, dynamic>?;
  final name = (bank?['accountName'] as String? ?? '').trim();
  final number = (bank?['accountNumber'] as String? ?? '').trim();
  if (name.isEmpty || number.isEmpty) return false;
  if (name.contains('<') || number.contains('<')) return false;
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isNotEmpty && !RegExp(r'^0+$').hasMatch(digits);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(FixtureHelper.parkCompetingTradies);
  tearDownAll(FixtureHelper.restoreCompetingTradies);

  group('P4 — Payment', () {
    // ── P4-13: payment screen shows bank details and upload button ─────────
    testWidgets('P4-13 payment screen renders bank details and upload button',
        (tester) async {
      final jobId = await FixtureHelper.awaitingPaymentJob(tag: 'p4-13');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/payment');
      await pumpFor(tester, kNetworkSettle);

      expect(find.byKey(const Key('payment_screen')), findsOneWidget);
      // V15-08: sentinel/placeholder instructions render as "unavailable"
      // instead of a guessed account — the dev config's all-zeros account
      // number trips this by design. When real instructions are configured
      // the reference and upload button show instead.
      final usable = await _instructionsUsable(jobId);
      if (usable) {
        expect(find.textContaining('FIXO-'), findsOneWidget);
        expect(
            find.byKey(const Key('upload_receipt_button')), findsOneWidget);
      } else {
        expect(
            find.textContaining('Bank transfer details are unavailable'),
            findsOneWidget);
      }
    });

    // ── P4-13: receipt under review shows status screen ───────────────────
    testWidgets('P4-13 payment under review shows status', (tester) async {
      final jobId = await FixtureHelper.paymentReviewJob(tag: 'p4-13r');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/payment/status');
      await pumpFor(tester, kNetworkSettle);

      // Status screen: 'Payment status' app bar + 'Under review' stage badge
      expect(find.text('Payment status'), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);
    });
  });
}
