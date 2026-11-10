// Screenshot driver — walks every route per persona and emits __SHOT__
// markers. A host-side watcher captures `xcrun simctl io screenshot`
// on each marker while this test parks on the settled screen.
//
// Run (homeowner):
//   flutter test integration_test/screenshots_test.dart \
//     --device-id <udid> --dart-define FIXO_PERSONA=homeowner \
//     --dart-define SHOT_MATCH_JOB=<requestedJobId>
//
// Run (tradie):
//   flutter test integration_test/screenshots_test.dart \
//     --device-id <udid> --dart-define FIXO_PERSONA=tradie \
//     --dart-define SHOT_OFFER_JOB=<jobWithPendingOfferId>
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_helper.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment(
  'FIXO_PERSONA',
  defaultValue: 'homeowner',
);

/// Forced app theme for the run: `light` or `dark`. Without it the app
/// follows the simulator's appearance, so a "light" folder can silently
/// contain dark captures.
const _theme = String.fromEnvironment('SHOT_THEME', defaultValue: 'light');

/// A `Requested` job owned by the homeowner — the matching screen
/// dispatches POST /jobs/:id/match itself on load.
const _matchJobId = String.fromEnvironment('SHOT_MATCH_JOB', defaultValue: '64');

/// A job whose pending JobOffer targets the tradie persona.
const _offerJobId = String.fromEnvironment('SHOT_OFFER_JOB', defaultValue: '64');

/// A job in `AwaitingPayment` matched to the tradie persona — feeds the
/// match-result, payment, payment-status and dispute shots.
const _paymentJobId =
    String.fromEnvironment('SHOT_PAYMENT_JOB', defaultValue: '64');

/// A job in `Booked` matched to the tradie persona.
const _bookedJobId =
    String.fromEnvironment('SHOT_BOOKED_JOB', defaultValue: '65');

/// A job in `InProgress` matched to the tradie persona (also feeds chat).
const _inProgressJobId =
    String.fromEnvironment('SHOT_INPROGRESS_JOB', defaultValue: '66');

const _tradieUserId = 'a552097b-16b4-427b-92dd-497b6c1c1e2e';
const _homeownerUserId = 'ee759288-3421-4c43-992c-f87ea3a0e916';

/// How long the host has to fire simctl after the marker prints.
const _shotHold = Duration(seconds: 4);

Future<void> _shot(WidgetTester tester, String name,
    {Duration settle = const Duration(seconds: 5)}) async {
  await pumpFor(tester, settle);
  print('__SHOT__ $name');
  await Future<void>.delayed(_shotHold);
}

/// Fails the run if the rendered theme is not the forced one, so a wrong-theme
/// folder can never be produced again.
void _expectForcedTheme(WidgetTester tester) {
  final scaffold = find.byType(Scaffold);
  if (scaffold.evaluate().isEmpty) return;
  final brightness = Theme.of(tester.element(scaffold.first)).brightness;
  expect(
    brightness,
    _theme == 'dark' ? Brightness.dark : Brightness.light,
    reason: 'SHOT_THEME=$_theme but the app rendered $brightness',
  );
}

Future<void> _go(WidgetTester tester, String location, String name,
    {Object? extra, Duration settle = const Duration(seconds: 5)}) async {
  appRouter.go(location, extra: extra);
  await pumpFor(tester, settle);
  _expectForcedTheme(tester);
  print('__SHOT__ $name');
  await Future<void>.delayed(_shotHold);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture all $_persona screens',
    (tester) async {
      // ThemeMode index: 0 system, 1 light, 2 dark (read by ThemeModeNotifier).
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _theme == 'dark' ? 2 : 1);
      app.main();
      // Splash shows during the ~2s boot delay — catch it early.
      if (_persona == 'homeowner') {
        await _shot(tester, 'shared/01_splash',
            settle: const Duration(milliseconds: 1500));
      } else {
        await pumpFor(tester, const Duration(seconds: 2));
      }

      // Pre-auth screens — capture once, on the homeowner pass.
      if (_persona == 'homeowner') {
        await _go(tester, '/onboarding', 'shared/02_onboarding',
            settle: const Duration(seconds: 3));
        await _go(tester, '/auth', 'shared/03_login',
            settle: const Duration(seconds: 3));
        await _go(tester, '/signup', 'shared/04_signup',
            settle: const Duration(seconds: 3));
        await _go(tester, '/verify-email', 'shared/05_verify_email',
            extra: 'unverified@fixo.test',
            settle: const Duration(seconds: 3));
        await _go(tester, '/role-select', 'shared/06_role_select',
            extra: (userId: 'stub', registrationToken: 'stub'),
            settle: const Duration(seconds: 3));
      }

      // Land on the login form before loginAs — gotoLogin cannot converge
      // from arbitrary non-shell routes (role-select/verify-email).
      appRouter.go('/auth');
      final email = _persona == 'tradie' ? kTradieEmail : kHomeownerEmail;
      final password =
          _persona == 'tradie' ? kTradiePassword : kHomeownerPassword;
      await loginAs(tester, email, password);
      await _shot(tester, '$_persona/00_post_login',
          settle: const Duration(seconds: 2));

      final stops = _persona == 'tradie'
          ? <(String, String)>[
              ('/tradie', 'tradie/01_dashboard'),
              ('/jobs', 'tradie/02_jobs_list'),
              ('/tradie/requests/$_offerJobId', 'tradie/03_request_detail'),
              ('/tradie/jobs/$_inProgressJobId', 'tradie/04_active_job_inprogress'),
              ('/chat/$_inProgressJobId', 'tradie/06_chat'),
              ('/messages', 'tradie/07_messages'),
              ('/profile', 'tradie/08_profile'),
              ('/settings', 'tradie/09_settings'),
              ('/tradie/onboarding', 'tradie/10_onboarding_wizard'),
              ('/tradie/$_tradieUserId', 'tradie/11_public_profile'),
              ('/users/$_homeownerUserId', 'tradie/12_homeowner_profile'),
            ]
          : <(String, String)>[
              ('/home', 'homeowner/01_dashboard'),
              ('/jobs', 'homeowner/02_jobs_list'),
              ('/messages', 'homeowner/03_messages'),
              ('/profile', 'homeowner/04_profile'),
              ('/settings', 'homeowner/05_settings'),
              ('/jobs/new', 'homeowner/06_post_job'),
            ];

      for (final (route, name) in stops) {
        await _go(tester, route, name);
      }

      if (_persona == 'homeowner') {
        // Post-job is a long scrollable form — grab the bottom half too.
        final scrollable = find.byType(Scrollable).first;
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable, const Offset(0, -900));
          await _shot(tester, 'homeowner/06b_post_job_bottom',
              settle: const Duration(seconds: 2));
        }
        await _go(tester, '/jobs/$_matchJobId/matching',
            'homeowner/07_matching',
            settle: const Duration(seconds: 6));
        await _go(tester, '/jobs/$_paymentJobId/match',
            'homeowner/08_match_result');
        await _go(tester, '/jobs/$_inProgressJobId/detail',
            'homeowner/09_job_detail_inprogress');
        // push (not go) between same-pattern routes — go_router reuses the
        // page element on param-only changes, leaving initState-fetched data
        // stale (the prior job's screen renders again).
        appRouter.push('/jobs/$_bookedJobId/detail');
        await _shot(tester, 'homeowner/10_job_detail_booked');
        await _go(tester, '/chat/$_inProgressJobId', 'homeowner/11_chat');
        await _go(tester, '/jobs/$_paymentJobId/payment', 'homeowner/12_payment');
        await _go(tester, '/jobs/$_paymentJobId/payment/status',
            'homeowner/13_payment_status');
        await _go(tester, '/jobs/$_paymentJobId/dispute', 'homeowner/14_dispute');
        await _go(tester, '/tradie/$_tradieUserId',
            'homeowner/15_tradie_profile');
        await _go(tester, '/users/$_homeownerUserId',
            'homeowner/16_homeowner_profile');
      }

      if (_persona == 'tradie') {
        appRouter.push('/tradie/jobs/$_bookedJobId');
        await _shot(tester, 'tradie/05_active_job_booked');
      }

      print('__SHOTS_DONE__');
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
