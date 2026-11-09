// Device-sweep driver for V15-05/V15-20 — parks on screens while the host
// captures via simctl on __SHOT__ markers. Landscape is exercised by
// forcing orientation via SystemChrome (the device must support it).
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment(
  'FIXO_PERSONA',
  defaultValue: 'homeowner',
);
const _chatJobId =
    String.fromEnvironment('SHOT_INPROGRESS_JOB', defaultValue: '159');

Future<void> _shot(WidgetTester tester, String name,
    {Duration hold = const Duration(seconds: 6)}) async {
  print('__SHOT__ $name');
  await Future<void>.delayed(hold);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'device sweep $_persona',
    (tester) async {
      app.main();
      await pumpFor(tester, const Duration(seconds: 2));
      await loginAs(
        tester,
        _persona == 'tradie' ? kTradieEmail : kHomeownerEmail,
        _persona == 'tradie' ? kTradiePassword : kHomeownerPassword,
      );
      await pumpFor(tester, const Duration(seconds: 4));

      appRouter.go(_persona == 'tradie' ? '/tradie' : '/home');
      await pumpFor(tester, const Duration(seconds: 5));
      await _shot(tester, '$_persona/29_dashboard_portrait');

      // Force landscape — verifies the dashboard reflows and safe areas hold.
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft]);
      await pumpFor(tester, const Duration(seconds: 3));
      await _shot(tester, '$_persona/30_dashboard_landscape');
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
      await pumpFor(tester, const Duration(seconds: 3));

      // Keyboard + safe-area — focus the chat composer (soft keyboard must
      // be enabled: Simulator > I/O > Keyboard > hardware keyboard OFF).
      appRouter.go('/chat/$_chatJobId');
      await pumpFor(tester, const Duration(seconds: 6));
      final composer = find.byType(TextField).last;
      if (composer.evaluate().isNotEmpty) {
        await tester.tap(composer);
        await pumpFor(tester, const Duration(seconds: 2));
      }
      await _shot(tester, '$_persona/31_chat_keyboard');

      print('__SHOTS_DONE__');
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
