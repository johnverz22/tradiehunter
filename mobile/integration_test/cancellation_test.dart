// P6 — Cancellations
//
// Run with: UI_V2=all exercises the v2 booked-screen cancel sheet
// (ho_booked_*); default flags exercise the v1 detail views. Tradie side is
// v1 until Phase 5.
//
// Self-seeding: each test gets a fresh Booked job from FixtureHelper.
// Either persona runs on a single simulator.
//
//   flutter test integration_test/cancellation_test.dart \
//     --device-id "iPhone 17 Pro" --dart-define FIXO_PERSONA=homeowner
//   flutter test integration_test/cancellation_test.dart \
//     --device-id "iPhone 17 Pro Max" --dart-define FIXO_PERSONA=tradie

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/fixture_helper.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment(
  'FIXO_PERSONA',
  defaultValue: 'homeowner',
);

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

// ── Homeowner side ────────────────────────────────────────────────────────────

void _homeownerSuite() {
  group('P6 — Cancellation (homeowner side)', () {
    // ── P6-06: cancel sheet renders correct widgets ────────────────────────
    testWidgets('P6-06 cancel sheet renders reason list and confirm button', (
      tester,
    ) async {
      final jobId = await FixtureHelper.bookedJob(tag: 'p6-06');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/detail');
      await pumpFor(tester, kNetworkSettle);

      await _openCancelSheet(tester);

      // Cancel sheet should be visible with a confirm button. The v1 sheet
      // also has a "Keep Job" button; the v2 sheet is dismissed by its barrier.
      expect(find.byKey(const Key('cancel_confirm_button')), findsOneWidget);

      // P6-06: fee warning is shown to homeowner
      expect(find.textContaining('fee'), findsWidgets);
    });

    // ── P6-06: dismissing the sheet keeps the job ──────────────────────────
    testWidgets('P6-06 dismissing cancel sheet keeps job', (tester) async {
      final jobId = await FixtureHelper.bookedJob(tag: 'p6-06d');

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/detail');
      await pumpFor(tester, kNetworkSettle);

      await _openCancelSheet(tester);

      await _dismissCancelSheet(tester);
      await pumpFor(tester);

      // Still on the job detail screen for a Booked job
      expect(find.textContaining('Booked'), findsWidgets);
    });
  });
}

// ── Tradie side ───────────────────────────────────────────────────────────────

void _tradieSuite() {
  group('P6 — Cancellation (tradie side)', () {
    // ── P6-04: tradie cancel returns job to Requested ─────────────────────
    testWidgets('P6-04 tradie cancel sheet shows account-flag warning', (
      tester,
    ) async {
      final jobId = await FixtureHelper.bookedJob(tag: 'p6-04');

      app.main();
      await loginAsTradie(tester);

      appRouter.go('/tradie/jobs/$jobId');
      await pumpFor(tester, kNetworkSettle);

      await _openCancelSheet(tester);

      // P6-06: tradie sees account-flag warning in the sheet
      expect(find.textContaining('flag'), findsOneWidget);
      expect(find.byKey(const Key('cancel_confirm_button')), findsOneWidget);
    });
  });
}

/// Dismisses the cancel sheet: "Keep Job" on v1, tap outside the sheet on v2
/// (which has no dismiss button).
Future<void> _dismissCancelSheet(WidgetTester tester) async {
  final keep = find.byKey(const Key('cancel_dismiss_button'));
  if (keep.evaluate().isNotEmpty) {
    await tester.tap(keep);
  } else {
    await tester.tapAt(const Offset(10, 10));
  }
}

/// Opens the cancel sheet from a job detail screen. All three detail
/// surfaces (v2 ho_booked, v1 homeowner, v1 tradie) expose the overflow
/// menu under the same `job_overflow_menu` key; the icon tap remains as a
/// fallback for surfaces that predate the key.
Future<void> _openCancelSheet(WidgetTester tester) async {
  final menu = find.byKey(const Key('job_overflow_menu'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu.first);
  } else {
    await tester.tap(find.byIcon(Icons.more_vert));
  }
  await pumpFor(tester);
  // Homeowner surfaces label the item 'Cancel job'; the tradie v1 sheet
  // uses title case 'Cancel Job'.
  final item = find.text('Cancel job').evaluate().isNotEmpty
      ? find.text('Cancel job')
      : find.text('Cancel Job');
  await tester.tap(item.first);
  await pumpFor(tester);
}
