// P5 — Booked → Completed Lifecycle
//
// Self-seeding: fixtures drive a fresh job to the required state via the API
// (FixtureHelper), so no pre-seeded Booked job is needed and either persona
// can run on a single simulator.
//
//   flutter test integration_test/job_lifecycle_test.dart \
//     --device-id "iPhone 17 Pro" --dart-define FIXO_PERSONA=tradie
//   flutter test integration_test/job_lifecycle_test.dart \
//     --device-id "iPhone 17 Pro Max" --dart-define FIXO_PERSONA=homeowner

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/api_helper.dart';
import 'helpers/auth_helper.dart';
import 'helpers/fixture_helper.dart';
import 'helpers/test_config.dart';

const _persona =
    String.fromEnvironment('FIXO_PERSONA', defaultValue: 'tradie');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(FixtureHelper.parkCompetingTradies);
  tearDownAll(FixtureHelper.restoreCompetingTradies);

  if (_persona == 'tradie') {
    _tradieSuite();
  } else {
    _homeownerSuite();
  }
}

// ── Tradie side ───────────────────────────────────────────────────────────────

void _tradieSuite() {
  group('P5 — Lifecycle (tradie side)', () {
    testWidgets('P5-03 tradie can check in on a Booked job', (tester) async {
      final jobId = await FixtureHelper.bookedJob(tag: 'p5-03');

      app.main();
      await loginAsTradie(tester);

      appRouter.go('/tradie/jobs/$jobId');
      await pumpFor(tester, kNetworkSettle);

      // P5-10: Check In button only visible when Booked
      expect(find.text('Check In'), findsOneWidget);

      await tester.tap(find.text('Check In'));
      await pumpFor(tester, kNetworkSettle);

      await pollUntil(
        () async =>
            (await ApiHelper.getJobStatus(
                jobId, await ApiHelper.tradieToken)) ==
            'InProgress',
      );
    });

    testWidgets('P5-04 tradie can check out on an InProgress job',
        (tester) async {
      final jobId = await FixtureHelper.inProgressJob(tag: 'p5-04');

      app.main();
      await loginAsTradie(tester);

      appRouter.go('/tradie/jobs/$jobId');
      await pumpFor(tester, kNetworkSettle);

      expect(find.text('Check Out'), findsOneWidget);

      await tester.tap(find.text('Check Out'));
      await pumpFor(tester, kNetworkSettle);

      await pollUntil(
        () async =>
            (await ApiHelper.getJobStatus(
                jobId, await ApiHelper.tradieToken)) ==
            'AwaitingConfirmation',
      );
    });
  });
}

// ── Homeowner side ────────────────────────────────────────────────────────────

void _homeownerSuite() {
  group('P5 — Lifecycle (homeowner side)', () {
    testWidgets('P5-05 homeowner can confirm completion', (tester) async {
      final jobId =
          await FixtureHelper.awaitingConfirmationJob(tag: 'p5-05');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/detail');
      await pumpFor(tester, kNetworkSettle);

      // P5-11: Confirm Completion button
      expect(find.text('Confirm Completion'), findsOneWidget);

      await tester.tap(find.text('Confirm Completion'));
      await pumpFor(tester, kNetworkSettle);

      await pollUntil(
        () async =>
            (await ApiHelper.getJobStatus(
                jobId, await ApiHelper.homeownerToken)) ==
            'Completed',
      );
    });

    testWidgets('P5-09 homeowner can leave a review after Completed',
        (tester) async {
      final jobId = await FixtureHelper.completedJob(tag: 'p5-09');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/detail');
      await pumpFor(tester, kNetworkSettle);

      // P5-11: Leave a Review appears when Completed and no review yet
      expect(find.byKey(const Key('leave_review_button')), findsOneWidget);
    });
  });
}
