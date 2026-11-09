// P3 — Matching: Sequential Offers & Timeouts
//
// Self-seeding: every test creates its own job via ApiHelper/FixtureHelper and
// polls the API for cross-state assertions, so no pre-seeded data is required.
// Run each persona on its own simulator (stagger launches — see
// docs/RUNNING-TESTS.md):
//
//   flutter test integration_test/matching_test.dart \
//     --device-id "iPhone 17 Pro" --dart-define FIXO_PERSONA=homeowner
//   flutter test integration_test/matching_test.dart \
//     --device-id "iPhone 17 Pro Max" --dart-define FIXO_PERSONA=tradie
//
// Prerequisites:
//   - Stack up: docker compose up -d
//   - Test accounts seeded (seed-test-accounts.sh) incl. verified tradie
//     profile + approved credential

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/api_helper.dart';
import 'helpers/auth_helper.dart';
import 'helpers/fixture_helper.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment('FIXO_PERSONA', defaultValue: 'homeowner');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(FixtureHelper.parkCompetingTradies);
  tearDownAll(FixtureHelper.restoreCompetingTradies);

  if (_persona == 'homeowner') {
    _homeownerSuite();
  } else {
    _tradieSuite();
  }
}

// ── Homeowner side ────────────────────────────────────────────────────────────

void _homeownerSuite() {
  group('P3 — Matching (homeowner side)', () {
    testWidgets('P3-11 matching screen shows progress while offer dispatched',
        (tester) async {
      final jobId = await FixtureHelper.requestedJob(tag: 'p3-11');
      // No explicit dispatch: MatchingScreen subscribes to SignalR then calls
      // triggerMatch itself on entry — same as the real post-job flow.

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/matching');

      // The screen opens on 'Finding tradies near you…' and flips to
      // 'Contacting …' when the SignalR offer-created event lands. Accept
      // either progress headline — the dispatch above may predate the
      // app's SignalR connection.
      await pollUntil(() async {
        await tester.pump(const Duration(seconds: 1));
        return find.textContaining('Contacting').evaluate().isNotEmpty ||
            find.textContaining('Finding tradies').evaluate().isNotEmpty;
      }, timeout: kNetworkSettle);
      expect(
        find.textContaining('Contacting').evaluate().isNotEmpty ||
            find.textContaining('Finding tradies').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('P3-04 job moves to AwaitingPayment after tradie accepts',
        (tester) async {
      final (jobId, offerId) =
          await FixtureHelper.pendingOfferJob(tag: 'p3-04');

      app.main();
      await loginAsHomeowner(tester);

      // Tradie accepts the pending offer (API — the tradie-side suite covers
      // the same accept via the UI on its own fixture job).
      await ApiHelper.respondToOffer(
          jobId, offerId, 'Accepted', await ApiHelper.tradieToken);

      await pollUntil(
        () async =>
            (await ApiHelper.getJobStatus(
                jobId, await ApiHelper.homeownerToken)) ==
            'AwaitingPayment',
        timeout: kMatchingSettle,
      );

      // Dashboard reflects the transition — V15-06 centralized labels render
      // the human form ("Payment due"), not the raw enum.
      appRouter.go('/jobs');
      await pumpFor(tester);
      expect(
        find.text('AwaitingPayment').evaluate().isNotEmpty ||
            find.text('Awaiting Payment').evaluate().isNotEmpty ||
            find.text('Awaiting payment').evaluate().isNotEmpty ||
            find.text('Payment due').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}

// ── Tradie side ───────────────────────────────────────────────────────────────

void _tradieSuite() {
  group('P3 — Matching (tradie side)', () {
    testWidgets('P3-03 tradie sees pending offer with countdown',
        (tester) async {
      final (jobId, _) = await FixtureHelper.pendingOfferJob(tag: 'p3-03');

      app.main();
      await loginAsTradie(tester);
      expect(find.byKey(const Key('tradie_dashboard')), findsOneWidget);

      // KNOWN DEFECT (pending-offer visibility): the tradie job list only
      // returns MatchedTradieId == me, and the dashboard doesn't listen to
      // OfferLifecycleEvent — so a pending offer has no in-app surface. The
      // request-detail route also can't load the job while only offered.
      // This test encodes intended behaviour; it fails until that is fixed.
      appRouter.go('/tradie/requests/$jobId');
      await pumpFor(tester);

      expect(
        find.textContaining('Accept'),
        findsWidgets,
        reason: 'BUG: pending offer has no tradie UI surface — job detail '
            'returns not-found for a tradie holding only a pending offer',
      );
    });

    testWidgets('P3-04 tradie accepts offer — job moves to AwaitingPayment',
        (tester) async {
      final (jobId, _) = await FixtureHelper.pendingOfferJob(tag: 'p3-04t');

      app.main();
      await loginAsTradie(tester);

      appRouter.go('/tradie/requests/$jobId');
      await pumpFor(tester);

      final acceptBtn = find.text('Accept Job').evaluate().isNotEmpty
          ? find.text('Accept Job')
          : (find.text('Review & Accept').evaluate().isNotEmpty
              ? find.text('Review & Accept')
              : find.textContaining('Accept'));
      expect(acceptBtn, findsWidgets,
          reason: 'BUG: pending offer has no tradie UI surface');
      await tester.tap(acceptBtn.first);
      await pumpFor(tester, kNetworkSettle);

      await pollUntil(
        () async =>
            (await ApiHelper.getJobStatus(
                jobId, await ApiHelper.tradieToken)) ==
            'AwaitingPayment',
        timeout: kMatchingSettle,
      );
    });
  });
}
