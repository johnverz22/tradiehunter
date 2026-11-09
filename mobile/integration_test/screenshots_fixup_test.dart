// One-off retake of shots that went stale because go_router reuses the
// page element on same-pattern param changes (see screenshots_test.dart).
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/test_config.dart';

const _persona =
    String.fromEnvironment('FIXO_PERSONA', defaultValue: 'homeowner');

Future<void> _shot(WidgetTester tester, String name) async {
  await pumpFor(tester, const Duration(seconds: 5));
  print('__SHOT__ $name');
  await Future<void>.delayed(const Duration(seconds: 4));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fixup shots',
    (tester) async {
      app.main();
      if (_persona == 'homeowner') {
        // Catch the splash mid-boot (it holds ~2s while _checkAppState runs).
        await pumpFor(tester, const Duration(milliseconds: 1200));
        print('__SHOT__ shared/01_splash');
        await Future<void>.delayed(const Duration(seconds: 4));
      }
      await pumpFor(tester, const Duration(seconds: 2));
      appRouter.go('/auth');
      if (_persona == 'homeowner') {
        appRouter.go('/onboarding');
        await _shot(tester, 'shared/02_onboarding');
        appRouter.go('/auth');
        await _shot(tester, 'shared/03_login');
      }
      await loginAs(
        tester,
        _persona == 'tradie' ? kTradieEmail : kHomeownerEmail,
        _persona == 'tradie' ? kTradiePassword : kHomeownerPassword,
      );
      if (_persona == 'tradie') {
        appRouter.go('/tradie/jobs/65');
        await _shot(tester, 'tradie/05_active_job_booked');
      } else {
        appRouter.go('/jobs/65/detail');
        await _shot(tester, 'homeowner/10_job_detail_booked');
      }
      print('__SHOTS_DONE__');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
