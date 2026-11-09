// V15-16 live two-client verification.
//
// The tradie client parks on /chat/<job>. The host (scripts/run-live-chat.sh)
// then:
//   1. sends a homeowner message via REST → the SignalR hub must push it to
//      this client live (no refresh), asserted by the text appearing;
//   2. backgrounds the app (simctl launch Preferences), sends a second
//      message, and relaunches fixo → the client must reconnect and
//      reconcile, showing the missed message.
// __SHOT__ markers let the host capture each received state.
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/test_config.dart';

const _jobId = String.fromEnvironment('LIVE_CHAT_JOB', defaultValue: '159');
const _msgOne = 'LIVE-MARKER-ONE';
const _msgTwo = 'LIVE-MARKER-TWO';

Future<void> _shot(WidgetTester tester, String name) async {
  await pumpFor(tester, const Duration(seconds: 2));
  print('__SHOT__ $name');
  await Future<void>.delayed(const Duration(seconds: 4));
}

/// Pumps until [text] is on screen or [timeout] elapses.
Future<void> _expectWithin(
    WidgetTester tester, String text, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(text).evaluate().isNotEmpty) return;
  }
  fail('expected "$text" within ${timeout.inSeconds}s — '
      'hub push/reconnect did not deliver');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live two-client send + reconnect',
    (tester) async {
      app.main();
      await pumpFor(tester, const Duration(seconds: 2));
      await loginAs(tester, kTradieEmail, kTradiePassword);

      appRouter.go('/chat/$_jobId');
      await pumpFor(tester, const Duration(seconds: 6));
      print('__LIVE_READY__');

      // Phase 1 — live hub push while the app is foregrounded.
      await _expectWithin(tester, _msgOne, const Duration(seconds: 45));
      print('__LIVE_GOT_ONE__');
      await _shot(tester, 'tradie/19_chat_live_push');

      // Phase 2 — host backgrounds the app, sends, and relaunches it.
      print('__LIVE_BG__');
      await _expectWithin(tester, _msgTwo, const Duration(seconds: 90));
      print('__LIVE_GOT_TWO__');
      await _shot(tester, 'tradie/20_chat_reconnect');

      print('__SHOTS_DONE__');
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
