// Variant capture driver — covers the manifest rows the base pass can't
// reach: job-detail states (awaiting confirmation, completed, cancelled,
// disputed, expired), payment-status variants, the cancel sheet, an empty
// chat, the expired and unavailable tradie request, the tradie sheets and
// the onboarding wizard steps 2-4. Emits __SHOT__ markers for run-shots.sh.
//
// Capture names follow docs/todos/02_design_system_fix_plan.md section 7.3 and
// are checked by `scripts/check-capture-names.py`. A capture whose fixture id
// was not passed prints `__SHOT_SKIPPED__ <name> | <reason>` instead of
// pushing a job id of 0.
//
// Run with the same flags as the base pass (run-shots.sh passes SHOT_THEME
// and SHOT_TEXT_SCALE). Fixture jobs may be flow v1 or v2 depending on backend
// JobFlow:Version — status-strip keys are shared.
//
// Requires the variant fixtures from scripts/mk-variant-fixtures.sh plus the
// base set (SHOT_BOOKED_JOB). Pass ids via --dart-define. Optional:
//   SHOT_ADJUST_JOB  InProgress job with a pending extra-cost adjustment
//                    -> homeowner/13b_extra_cost (no script creates it yet)
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/exception_log.dart';
import 'helpers/shot_env.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment(
  'FIXO_PERSONA',
  defaultValue: 'homeowner',
);

const _awaitJobId = String.fromEnvironment('SHOT_AWAIT_JOB', defaultValue: '0');
const _doneJobId = String.fromEnvironment('SHOT_DONE_JOB', defaultValue: '0');
const _cancJobId = String.fromEnvironment('SHOT_CANC_JOB', defaultValue: '0');
const _dispJobId = String.fromEnvironment('SHOT_DISP_JOB', defaultValue: '0');
const _subJobId = String.fromEnvironment('SHOT_SUB_JOB', defaultValue: '0');
const _rejJobId = String.fromEnvironment('SHOT_REJ_JOB', defaultValue: '0');
const _expJobId = String.fromEnvironment('SHOT_EXP_JOB', defaultValue: '0');
const _adjustJobId = String.fromEnvironment(
  'SHOT_ADJUST_JOB',
  defaultValue: '0',
);
const _bookedJobId = String.fromEnvironment(
  'SHOT_BOOKED_JOB',
  defaultValue: '0',
);
const _expiredOfferJobId = String.fromEnvironment(
  'SHOT_EXPOFFER_JOB',
  defaultValue: '0',
);

const _brief = Duration(seconds: 2);
const _dismissPoint = Offset(200, 100);

Future<void> _shot(
  WidgetTester tester,
  String name, {
  Duration settle = const Duration(seconds: 5),
}) async {
  ExceptionLog.mark(name);
  await pumpFor(tester, settle);
  expectShotEnvironment(tester);
  print('__SHOT__ $name');
  await Future<void>.delayed(const Duration(seconds: 4));
}

/// go_router reuses the page element on same-pattern param changes — always
/// push param'd routes so each job id builds a fresh screen.
Future<void> _push(
  WidgetTester tester,
  String location,
  String name, {
  Duration settle = const Duration(seconds: 5),
}) async {
  ExceptionLog.mark(name);
  appRouter.push(location);
  await _shot(tester, name, settle: settle);
}

/// Pushes [location] and captures [name], or records a skip when the fixture
/// id behind [define] was not provided.
Future<void> _pushFixture(
  WidgetTester tester, {
  required String fixtureId,
  required String define,
  required String location,
  required String name,
}) async {
  if (!hasFixture(fixtureId)) {
    shotSkipped(name, '$define not provided');
    return;
  }
  await _push(tester, location, name);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture $_persona variants', (tester) async {
    ExceptionLog.install();
    applyShotTextScale(tester);
    await seedShotPrefs();
    app.main();
    await pumpFor(tester, const Duration(seconds: 2));

    // Onboarding slides 2-3 are in the base pass (shared/02_onboarding_2/3).
    appRouter.go('/auth');
    final email = _persona == 'tradie' ? kTradieEmail : kHomeownerEmail;
    final password = _persona == 'tradie'
        ? kTradiePassword
        : kHomeownerPassword;
    await loginAs(tester, email, password);

    if (_persona == 'homeowner') {
      await _captureHomeownerJobStates(tester);
      await _captureHomeownerPaymentStates(tester);
      await _captureHomeownerSheetsAndErrors(tester);
    } else {
      await _captureTradieVariants(tester);
    }

    ExceptionLog.finish();
    print('__SHOTS_DONE__');
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// Job-detail states: confirmation, review, cancelled, disputed, expired and
/// the pending extra-cost adjustment.
Future<void> _captureHomeownerJobStates(WidgetTester tester) async {
  await _pushFixture(
    tester,
    fixtureId: _awaitJobId,
    define: 'SHOT_AWAIT_JOB',
    location: '/jobs/$_awaitJobId/detail',
    name: 'homeowner/14_review_completion',
  );
  await _pushFixture(
    tester,
    fixtureId: _doneJobId,
    define: 'SHOT_DONE_JOB',
    location: '/jobs/$_doneJobId/detail',
    name: 'homeowner/17_review',
  );
  await _pushFixture(
    tester,
    fixtureId: _cancJobId,
    define: 'SHOT_CANC_JOB',
    location: '/jobs/$_cancJobId/detail',
    name: 'homeowner/19_job_cancelled',
  );
  await _pushFixture(
    tester,
    fixtureId: _dispJobId,
    define: 'SHOT_DISP_JOB',
    location: '/jobs/$_dispJobId/detail',
    name: 'homeowner/19_job_disputed',
  );
  // mk-variant-fixtures.sh forces this job (and its payment) to Expired, so it
  // serves both the job-detail and the payment-status expired captures.
  await _pushFixture(
    tester,
    fixtureId: _expJobId,
    define: 'SHOT_EXP_JOB',
    location: '/jobs/$_expJobId/detail',
    name: 'homeowner/19_job_expired',
  );
  await _pushFixture(
    tester,
    fixtureId: _adjustJobId,
    define: 'SHOT_ADJUST_JOB',
    location: '/jobs/$_adjustJobId/detail',
    name: 'homeowner/13b_extra_cost',
  );
}

/// H15 variants — review / verified / rejected / expired.
Future<void> _captureHomeownerPaymentStates(WidgetTester tester) async {
  await _pushFixture(
    tester,
    fixtureId: _subJobId,
    define: 'SHOT_SUB_JOB',
    location: '/jobs/$_subJobId/payment/status',
    name: 'homeowner/16_payment_status_review',
  );
  await _pushFixture(
    tester,
    fixtureId: _bookedJobId,
    define: 'SHOT_BOOKED_JOB',
    location: '/jobs/$_bookedJobId/payment/status',
    name: 'homeowner/16_payment_status_verified',
  );
  await _pushFixture(
    tester,
    fixtureId: _rejJobId,
    define: 'SHOT_REJ_JOB',
    location: '/jobs/$_rejJobId/payment/status',
    name: 'homeowner/16_payment_status_rejected',
  );
  await _pushFixture(
    tester,
    fixtureId: _expJobId,
    define: 'SHOT_EXP_JOB',
    location: '/jobs/$_expJobId/payment/status',
    name: 'homeowner/16_payment_status_expired',
  );
}

/// Empty chat, the cancel sheet and the job-detail error state.
Future<void> _captureHomeownerSheetsAndErrors(WidgetTester tester) async {
  // H13 empty conversation (booked job with no messages).
  await _pushFixture(
    tester,
    fixtureId: _bookedJobId,
    define: 'SHOT_BOOKED_JOB',
    location: '/chat/$_bookedJobId',
    name: 'homeowner/21b_chat_empty',
  );

  // Cancel sheet on a Booked job — open and capture only.
  const cancelSheet = 'homeowner/20_cancel_sheet';
  if (hasFixture(_bookedJobId)) {
    ExceptionLog.mark(cancelSheet);
    appRouter.push('/jobs/$_bookedJobId/detail');
    await pumpFor(tester, const Duration(seconds: 5));
    // The v2 booked screen keeps Cancel in the overflow menu
    // (job_overflow_menu -> 'Cancel job'); the v1 screen used a
    // 'Cancel job' tooltip. Try the tooltip first, then the menu.
    var opened = false;
    final cancelBtn = find.byTooltip('Cancel job');
    if (cancelBtn.evaluate().isNotEmpty) {
      await tester.tap(cancelBtn);
      opened = true;
    } else {
      final overflow = find.byKey(const Key('job_overflow_menu'));
      if (overflow.evaluate().isNotEmpty) {
        await tester.tap(overflow.first);
        await pumpFor(tester, const Duration(seconds: 1));
        final cancelItem = find.text('Cancel job');
        if (cancelItem.evaluate().isNotEmpty) {
          await tester.tap(cancelItem.first);
          opened = true;
        }
      }
    }
    if (!opened) {
      shotSkipped(
        cancelSheet,
        'no "Cancel job" tooltip or job_overflow_menu "Cancel job" item '
        'on the booked job',
      );
    } else {
      await _shot(tester, cancelSheet, settle: _brief);
      // Dismiss without confirming.
      await tester.tapAt(_dismissPoint);
      await pumpFor(tester, const Duration(seconds: 1));
    }
  } else {
    shotSkipped(cancelSheet, 'SHOT_BOOKED_JOB not provided');
  }

  // Error variant — nonexistent job id.
  await _push(tester, '/jobs/99998/detail', 'homeowner/26_job_detail_error');
}

Future<void> _captureTradieVariants(WidgetTester tester) async {
  // T21 variants — expired offer, unavailable job.
  await _pushFixture(
    tester,
    fixtureId: _expiredOfferJobId,
    define: 'SHOT_EXPOFFER_JOB',
    location: '/tradie/requests/$_expiredOfferJobId',
    name: 'tradie/02b_lead_expired',
  );
  await _pushFixture(
    tester,
    fixtureId: _cancJobId,
    define: 'SHOT_CANC_JOB',
    location: '/tradie/requests/$_cancJobId',
    name: 'tradie/14_request_unavailable',
  );

  await _captureTradieJobSheets(tester);
  await _captureOnboardingSteps(tester);
}

/// T22 cancel sheet (overflow menu -> Cancel Job) and the map-app chooser on a
/// Booked job. Both are capture-only; nothing is confirmed.
Future<void> _captureTradieJobSheets(WidgetTester tester) async {
  const cancelSheet = 'tradie/15_cancel_sheet';
  const navigate = 'tradie/16_navigate_options';
  if (!hasFixture(_bookedJobId)) {
    shotSkipped(cancelSheet, 'SHOT_BOOKED_JOB not provided');
    shotSkipped(navigate, 'SHOT_BOOKED_JOB not provided');
    return;
  }

  appRouter.push('/tradie/jobs/$_bookedJobId');
  await pumpFor(tester, const Duration(seconds: 5));
  final overflow = find.byIcon(Icons.more_vert);
  if (overflow.evaluate().isEmpty) {
    shotSkipped(cancelSheet, 'no overflow (more_vert) menu on the booked job');
  } else {
    await tester.tap(overflow.first);
    await pumpFor(tester, const Duration(seconds: 1));
    final cancelItem = find.text('Cancel Job');
    if (cancelItem.evaluate().isEmpty) {
      shotSkipped(cancelSheet, 'no "Cancel Job" item in the overflow menu');
    } else {
      await tester.tap(cancelItem);
      await _shot(tester, cancelSheet, settle: _brief);
      // Dismiss without confirming.
      await tester.tapAt(_dismissPoint);
      await pumpFor(tester, const Duration(seconds: 1));
    }
  }

  // The tradie detail screen exposes the map-app chooser under
  // 'navigate_button' (there is no separate options-button key).
  appRouter.push('/tradie/jobs/$_bookedJobId');
  await pumpFor(tester, const Duration(seconds: 5));
  final navOptions = find.byKey(const Key('navigate_button'));
  if (navOptions.evaluate().isEmpty) {
    shotSkipped(navigate, 'no navigate_button on the booked job');
    return;
  }
  await tester.tap(navOptions);
  await _shot(tester, navigate, settle: _brief);
  await tester.tapAt(_dismissPoint);
  await pumpFor(tester, const Duration(seconds: 1));
}

/// T25 wizard steps 2-4 (step 1 is `tradie/12_onboarding_1` in the base pass).
/// Continue is tapped as-is, without filling anything in. When the button is
/// missing the walk stops and the remaining steps are reported as skips.
Future<void> _captureOnboardingSteps(WidgetTester tester) async {
  const steps = [
    'tradie/12_onboarding_2',
    'tradie/12_onboarding_3',
    'tradie/12_onboarding_4',
  ];
  appRouter.go('/tradie/onboarding');
  await pumpFor(tester, const Duration(seconds: 5));
  var blocked = false;
  for (final name in steps) {
    final cont = find.text('Continue');
    if (blocked || cont.evaluate().isEmpty) {
      blocked = true;
      shotSkipped(name, 'no "Continue" button on the previous wizard step');
      continue;
    }
    await tester.tap(cont.first);
    await pumpFor(tester, const Duration(seconds: 4));
    await _shot(tester, name, settle: _brief);
  }
}
