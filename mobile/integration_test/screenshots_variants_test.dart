// Variant capture driver — covers the manifest rows the base pass can't
// reach: onboarding slides 2-3, H12 confirmation/terminal/disputed states,
// H15 payment-status variants, cancel sheets, wizard steps 2-4, empty chat,
// expired request and error states. Emits __SHOT__ markers for run-shots.sh.
//
// Requires the variant fixtures from scripts/mk-variant-fixtures.sh plus the
// base set (SHOT_BOOKED_JOB). Pass ids via --dart-define.
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment(
  'FIXO_PERSONA',
  defaultValue: 'homeowner',
);

const _awaitJobId =
    String.fromEnvironment('SHOT_AWAIT_JOB', defaultValue: '0');
const _doneJobId = String.fromEnvironment('SHOT_DONE_JOB', defaultValue: '0');
const _cancJobId = String.fromEnvironment('SHOT_CANC_JOB', defaultValue: '0');
const _dispJobId = String.fromEnvironment('SHOT_DISP_JOB', defaultValue: '0');
const _subJobId = String.fromEnvironment('SHOT_SUB_JOB', defaultValue: '0');
const _rejJobId = String.fromEnvironment('SHOT_REJ_JOB', defaultValue: '0');
const _expJobId = String.fromEnvironment('SHOT_EXP_JOB', defaultValue: '0');
const _bookedJobId =
    String.fromEnvironment('SHOT_BOOKED_JOB', defaultValue: '0');
const _expiredOfferJobId =
    String.fromEnvironment('SHOT_EXPOFFER_JOB', defaultValue: '0');

Future<void> _shot(WidgetTester tester, String name,
    {Duration settle = const Duration(seconds: 5)}) async {
  await pumpFor(tester, settle);
  print('__SHOT__ $name');
  await Future<void>.delayed(const Duration(seconds: 4));
}

/// go_router reuses the page element on same-pattern param changes — always
/// push param'd routes so each job id builds a fresh screen.
Future<void> _push(WidgetTester tester, String location, String name,
    {Duration settle = const Duration(seconds: 5)}) async {
  appRouter.push(location);
  await _shot(tester, name, settle: settle);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture $_persona variants',
    (tester) async {
      app.main();
      await pumpFor(tester, const Duration(seconds: 2));

      // ── Shared: onboarding slides 2-3 (slide 1 is in the base pass) ──
      if (_persona == 'homeowner') {
        appRouter.go('/onboarding');
        await pumpFor(tester, const Duration(seconds: 3));
        final next = find.text('Next');
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next);
          await _shot(tester, 'shared/02b_onboarding_slide2',
              settle: const Duration(seconds: 2));
        }
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next);
          await _shot(tester, 'shared/02c_onboarding_slide3',
              settle: const Duration(seconds: 2));
        }
      }

      appRouter.go('/auth');
      final email = _persona == 'tradie' ? kTradieEmail : kHomeownerEmail;
      final password =
          _persona == 'tradie' ? kTradiePassword : kHomeownerPassword;
      await loginAs(tester, email, password);

      if (_persona == 'homeowner') {
        // H12 variants — confirmation / terminal / disputed.
        await _push(tester, '/jobs/$_awaitJobId/detail',
            'homeowner/17_job_detail_awaiting_confirmation');
        await _push(tester, '/jobs/$_doneJobId/detail',
            'homeowner/18_job_detail_completed');
        await _push(tester, '/jobs/$_cancJobId/detail',
            'homeowner/19_job_detail_cancelled');
        await _push(tester, '/jobs/$_dispJobId/detail',
            'homeowner/20_job_detail_disputed');

        // H15 variants — review / verified / rejected / expired.
        await _push(tester, '/jobs/$_subJobId/payment/status',
            'homeowner/21_payment_status_review');
        await _push(tester, '/jobs/$_bookedJobId/payment/status',
            'homeowner/22_payment_status_verified');
        await _push(tester, '/jobs/$_rejJobId/payment/status',
            'homeowner/23_payment_status_rejected');
        await _push(tester, '/jobs/$_expJobId/payment/status',
            'homeowner/24_payment_status_expired');

        // H13 empty conversation (booked job with no messages).
        await _push(
            tester, '/chat/$_bookedJobId', 'homeowner/25_chat_empty');

        // Cancel sheet on a Booked job — open and capture only.
        await _push(tester, '/jobs/$_bookedJobId/detail',
            'homeowner/26_job_detail_booked_revisit');
        final cancelBtn = find.byTooltip('Cancel job');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn);
          await _shot(tester, 'homeowner/27_cancel_sheet',
              settle: const Duration(seconds: 2));
        }

        // Error variant — nonexistent job id.
        await _push(tester, '/jobs/99998/detail',
            'homeowner/28_job_detail_error');
      }

      if (_persona == 'tradie') {
        // T21 variants — expired offer, unavailable job.
        await _push(tester, '/tradie/requests/$_expiredOfferJobId',
            'tradie/13_request_expired');
        await _push(tester, '/tradie/requests/$_cancJobId',
            'tradie/14_request_unavailable');

        // T22 cancel sheet — overflow menu → Cancel Job (capture only).
        await _push(tester, '/tradie/jobs/$_bookedJobId',
            'tradie/15_active_job_booked_revisit');
        final overflow = find.byIcon(Icons.more_vert);
        if (overflow.evaluate().isNotEmpty) {
          await tester.tap(overflow.first);
          await pumpFor(tester, const Duration(seconds: 1));
          final cancelItem = find.text('Cancel Job');
          if (cancelItem.evaluate().isNotEmpty) {
            await tester.tap(cancelItem);
            await _shot(tester, 'tradie/16_cancel_sheet',
                settle: const Duration(seconds: 2));
            // Dismiss without confirming.
            await tester.tapAt(const Offset(200, 100));
            await pumpFor(tester, const Duration(seconds: 1));
          }
        }

        // Navigate options menu (map-app chooser) on a Booked job.
        await _push(tester, '/tradie/jobs/$_bookedJobId',
            'tradie/17_active_job_navigate_revisit');
        final navOptions = find.byKey(const Key('navigate_options_button'));
        if (navOptions.evaluate().isNotEmpty) {
          await tester.tap(navOptions);
          await _shot(tester, 'tradie/18_navigate_options',
              settle: const Duration(seconds: 2));
          await tester.tapAt(const Offset(200, 100));
          await pumpFor(tester, const Duration(seconds: 1));
        }

        // T25 wizard steps 2-4 (step 1 is in the base pass).
        appRouter.go('/tradie/onboarding');
        await pumpFor(tester, const Duration(seconds: 5));
        for (var step = 2; step <= 4; step++) {
          final cont = find.text('Continue');
          if (cont.evaluate().isEmpty) break;
          await tester.tap(cont.first);
          await pumpFor(tester, const Duration(seconds: 4));
          await _shot(tester, 'tradie/19_wizard_step$step',
              settle: const Duration(seconds: 2));
        }
      }

      print('__SHOTS_DONE__');
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
