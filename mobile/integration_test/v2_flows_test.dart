// V2 — Homeowner Phase-4 flows (quotes, extra cost, tradie profile request)
//
// Run with: UI_V2=all (or UI_V2=ho_quotes,ho_extra_cost,ho_tradie_profile for
// the matching subset). These screens are gated — under default flags the v1
// views render instead, so each test skips itself unless its screen id is
// enabled. Covered by scripts/run-e2e.sh config C1.
//
// Self-seeding: FixtureHelper drives real API state (project job → quote
// request → submitted quote; booked job → pending adjustment; requested job
// → direct tradie request).
//
//   scripts/run-e2e.sh C1 v2_flows

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/api_helper.dart';
import 'helpers/auth_helper.dart';
import 'helpers/fixture_helper.dart';
import 'helpers/test_config.dart';

/// The `UI_V2` dart-define the runner passes (`all`, a comma-separated id
/// list, or empty for the compiled default allowlist).
const _uiV2 = String.fromEnvironment('UI_V2', defaultValue: '');

/// Mirrors `resolveV2Screen` in lib/ui/ui_flags.dart: `all` enables
/// everything, the compiled allowlist always applies, and a non-empty
/// define enables the listed ids on top of the allowlist.
bool _v2Enabled(String id) {
  const shipped = {
    'shell',
    'splash',
    'onboarding',
    'sign_in',
    'verify_otp',
    'role_select',
    'signup',
    'chat',
    'notifications',
    'profile',
    'messages_list',
    'settings',
  };
  if (_uiV2.trim() == 'all' || shipped.contains(id)) return true;
  if (_uiV2.trim().isEmpty) return false;
  return _uiV2.split(',').map((s) => s.trim()).contains(id);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(FixtureHelper.parkCompetingTradies);
  tearDownAll(FixtureHelper.restoreCompetingTradies);

  group('V2 — homeowner Phase-4 flows', () {
    // ── ho_quotes: accept a fixed quote below the s362F threshold ─────────
    testWidgets('ho_quotes accepts a quote and books the job', (tester) async {
      if (!_v2Enabled('ho_quotes')) {
        markTestSkipped('ho_quotes not enabled (needs UI_V2=all or ho_quotes)');
        return;
      }
      final (jobId, quoteId, _) = await FixtureHelper.quotedJob(
        tag: 'v2q-low',
        amount: 2000,
      );

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/quotes');
      await pumpFor(tester, kNetworkSettle);

      final accept = find.byKey(Key('accept_quote_$quoteId'));
      expect(accept, findsOneWidget);
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await pumpFor(tester, kNetworkSettle);

      // Below the written-contract threshold → direct accept, no gate.
      expect(find.text('Written contract required'), findsNothing);
      await pollUntil(
        () async =>
            (await ApiHelper.getJobStatus(
              jobId,
              await ApiHelper.homeownerToken,
            )) ==
            'Booked',
        timeout: kMatchingSettle,
      );
    });

    // ── ho_quotes: s362F written-contract gate over the threshold ─────────
    testWidgets('ho_quotes gates high-value accept behind written contract', (
      tester,
    ) async {
      if (!_v2Enabled('ho_quotes')) {
        markTestSkipped('ho_quotes not enabled (needs UI_V2=all or ho_quotes)');
        return;
      }
      final (jobId, quoteId, _) = await FixtureHelper.quotedJob(
        tag: 'v2q-high',
        amount: 45000,
      );

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/jobs/$jobId/quotes');
      await pumpFor(tester, kNetworkSettle);

      final accept = find.byKey(Key('accept_quote_$quoteId'));
      expect(accept, findsOneWidget);
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await pumpFor(tester, kNetworkSettle);

      // Building Act s362F: over-threshold quotes require the contract
      // checkbox before the accept is sent.
      expect(find.text('Written contract required'), findsOneWidget);
      await tester.tap(find.byKey(const Key('written_contract_checkbox')));
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('contract_confirm_button')));
      await pumpFor(tester, kNetworkSettle);

      await pollUntil(
        () async =>
            (await ApiHelper.getJobStatus(
              jobId,
              await ApiHelper.homeownerToken,
            )) ==
            'Booked',
        timeout: kMatchingSettle,
      );
    });

    // ── ho_extra_cost: homeowner approves a pending adjustment ────────────
    testWidgets('ho_extra_cost approves a pending extra-cost request', (
      tester,
    ) async {
      if (!_v2Enabled('ho_job_detail')) {
        markTestSkipped(
          'ho_job_detail not enabled (needs UI_V2=all or ho_job_detail)',
        );
        return;
      }
      final (jobId, adjustmentId) = await FixtureHelper.pendingAdjustmentJob(
        tag: 'v2adj',
      );

      app.main();
      await loginAsHomeowner(tester);

      // Booked + pending adjustment → the v2 extra-cost detail view.
      appRouter.go('/jobs/$jobId/detail');
      await pumpFor(tester, kNetworkSettle);

      expect(find.text('Extra cost request'), findsWidgets);
      final approve = find.byKey(const Key('adjustment_approve_button'));
      expect(approve, findsOneWidget);
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await pumpFor(tester);

      // Decision sheet → confirm approve.
      final confirm = find.byKey(const Key('adjustment_decision_confirm'));
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await pumpFor(tester, kNetworkSettle);

      final homeowner = await ApiHelper.homeownerToken;
      await pollUntil(() async {
        final adjustments = await ApiHelper.getAdjustments(jobId, homeowner);
        return adjustments.any(
          (a) => a['id'] == adjustmentId && a['status'] == 'Approved',
        );
      });
      // Approving an extra must not move the job itself.
      expect(await ApiHelper.getJobStatus(jobId, homeowner), 'Booked');
    });

    // ── ho_tradie_profile: request a specific tradie for a job ────────────
    testWidgets('ho_tradie_profile sends a direct tradie request', (
      tester,
    ) async {
      if (!_v2Enabled('ho_tradie_profile')) {
        markTestSkipped(
          'ho_tradie_profile not enabled (needs UI_V2=all or ho_tradie_profile)',
        );
        return;
      }
      final jobId = await FixtureHelper.requestedJob(tag: 'v2prof');
      final tradieId = await FixtureHelper.tradieProfileId();

      app.main();
      await loginAsHomeowner(tester);

      appRouter.go('/tradie/$tradieId?jobId=$jobId');
      await pumpFor(tester, kNetworkSettle);

      final requestBtn = find.byKey(const Key('request_this_tradie_button'));
      expect(requestBtn, findsOneWidget);
      await tester.ensureVisible(requestBtn);
      await tester.tap(requestBtn);
      await pumpFor(tester);

      // Optional-message sheet → send.
      final send = find.byKey(const Key('send_request_button'));
      expect(send, findsOneWidget);
      await tester.tap(send);
      await pumpFor(tester, kNetworkSettle);

      // Lands on the v2 request-sent screen and the API has the offer.
      expect(find.byKey(const Key('pick_someone_else_button')), findsOneWidget);
      await pollUntil(() async {
        final offer = await ApiHelper.getPendingOffer(
          jobId,
          await ApiHelper.tradieToken,
        );
        return offer != null;
      });
    });
  });
}
