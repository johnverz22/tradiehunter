// P7 — Disputes
//
// Self-seeding: each test gets a fresh Booked job from FixtureHelper and
// navigates straight to /jobs/:id/dispute.
//
//   flutter test integration_test/dispute_test.dart --device-id <id>

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/fixture_helper.dart';
import 'helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(FixtureHelper.parkCompetingTradies);
  tearDownAll(FixtureHelper.restoreCompetingTradies);

  group('P7 — Disputes', () {
    // ── P7-04: dispute screen renders all required fields ─────────────────
    testWidgets('P7-04 dispute screen renders reason, details and submit',
        (tester) async {
      final jobId = await FixtureHelper.bookedJob(tag: 'p7-04a');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.push('/jobs/$jobId/dispute');
      await pumpFor(tester, kNetworkSettle);

      expect(find.byKey(const Key('dispute_screen')), findsOneWidget);
      // V15-18: reasons are a fixed radio set, not a dropdown.
      expect(
          find.byKey(const Key('dispute_reason_Poor Quality')), findsOneWidget);
      expect(find.byKey(const Key('dispute_details_field')), findsOneWidget);
      expect(find.byKey(const Key('open_dispute_button')), findsOneWidget);
    });

    // ── P7-04: submit without selecting reason is blocked ────────────────
    testWidgets('P7-04 submitting dispute without details stays on screen',
        (tester) async {
      final jobId = await FixtureHelper.bookedJob(tag: 'p7-04b');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.push('/jobs/$jobId/dispute');
      await pumpFor(tester, kNetworkSettle);

      // Tap submit without filling reason or details
      await tester.tap(find.byKey(const Key('open_dispute_button')));
      await pumpFor(tester, kNetworkSettle);

      // Should remain on dispute screen (validation blocks or API rejects)
      expect(find.byKey(const Key('dispute_screen')), findsOneWidget);
    });

    // ── P7-04: filled dispute form can be submitted ────────────────────────
    testWidgets('P7-04 filled dispute form submits and leaves screen',
        (tester) async {
      final jobId = await FixtureHelper.bookedJob(tag: 'p7-04c');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.push('/jobs/$jobId/dispute');
      await pumpFor(tester, kNetworkSettle);

      // Select a reason (radio — scroll it into view first)
      final reason = find.byKey(const Key('dispute_reason_Poor Quality'));
      await tester.ensureVisible(reason);
      await pumpFor(tester);
      await tester.tap(reason);
      await pumpFor(tester);

      // Enter details
      await tester.enterText(
        find.byKey(const Key('dispute_details_field')),
        'Integration test dispute — work was not completed to standard.',
      );
      await pumpFor(tester);

      // Submit — the button is below the fold once the keyboard is up
      final submitBtn = find.byKey(const Key('open_dispute_button'));
      await tester.ensureVisible(submitBtn);
      await pumpFor(tester);
      await tester.tap(submitBtn);
      await pumpFor(tester, kNetworkSettle);

      // Should navigate away from dispute screen on success
      expect(find.byKey(const Key('dispute_screen')), findsNothing);
    });
  });
}
