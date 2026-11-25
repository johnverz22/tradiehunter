// Phase 5.0: v2 offer countdown (`TrOfferCountdown`) and its pure helpers,
// with the v1 `OfferCountdown` results pinned as literals.
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/tradie/tr_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase3_test_setup.dart';

JobOffer _offer(DateTime expiresUtc) => JobOffer(
  id: 'o1',
  jobId: 'j1',
  tradieId: 't1',
  offeredAtUtc: expiresUtc.subtract(const Duration(minutes: 15)),
  expiresAtUtc: expiresUtc,
  response: 'Pending',
  stage: 'Auto',
);

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? THTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUpAll(loadPhase3Fixtures);

  group('helpers', () {
    final cases = <Duration, (String, String)>{
      Duration.zero: ('0:00', 'Offer expired'),
      const Duration(seconds: 5): ('0:05', 'Expires in 0:05'),
      const Duration(minutes: 2, seconds: 9): ('2:09', 'Expires in 2:09'),
      const Duration(minutes: 59, seconds: 59): ('59:59', 'Expires in 59:59'),
      const Duration(hours: 1): ('1:00:00', 'Expires in 1h 0m'),
      const Duration(hours: 2, minutes: 3, seconds: 4): (
        '2:03:04',
        'Expires in 2h 3m',
      ),
    };
    cases.forEach((d, e) {
      test('$d', () {
        expect(trFormatCountdown(d), e.$1);
        expect(trCompactCountdownLabel(d), e.$2);
      });
    });
    test('remaining is clamped at zero', () {
      final now = DateTime.utc(2026, 11, 25, 10);
      final offer = _offer(now.subtract(const Duration(minutes: 3)));
      expect(trOfferRemaining(offer, () => now), Duration.zero);
    });
  });

  test('tone bands: calm > 2 min, soon <= 2 min, urgent <= 30 s', () {
    expect(trCountdownTone(const Duration(minutes: 5)), TrCountdownTone.calm);
    expect(trCountdownTone(const Duration(minutes: 2)), TrCountdownTone.soon);
    expect(
      trCountdownTone(const Duration(seconds: 30)),
      TrCountdownTone.urgent,
    );
    expect(trCountdownTone(Duration.zero), TrCountdownTone.urgent);
  });

  for (final dark in [false, true]) {
    final label = dark ? 'dark' : 'light';
    testWidgets('ticks down and fires onExpired once ($label)', (tester) async {
      var now = DateTime.utc(2026, 11, 25, 10);
      var expired = 0;
      await tester.pumpWidget(
        _host(
          TrOfferCountdown(
            offer: _offer(now.add(const Duration(seconds: 3))),
            clock: () => now,
            onExpired: () => expired++,
          ),
          theme: dark ? THTheme.dark : THTheme.light,
        ),
      );
      expect(find.text('Respond within 0:03'), findsOneWidget);
      expect(expired, 0);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(THDurations.countdownTick);
      expect(find.text('Respond within 0:02'), findsOneWidget);

      now = now.add(const Duration(seconds: 5));
      await tester.pump(THDurations.countdownTick);
      expect(find.text('Offer expired'), findsOneWidget);
      expect(expired, 1);

      // The timer is cancelled: further ticks neither rebuild nor re-notify.
      await tester.pump(const Duration(seconds: 5));
      expect(expired, 1);
    });
  }

  testWidgets('already expired offer notifies once after the first frame', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 25, 10);
    var expired = 0;
    await tester.pumpWidget(
      _host(
        TrOfferCountdown(
          compact: true,
          offer: _offer(now.subtract(const Duration(minutes: 1))),
          clock: () => now,
          onExpired: () => expired++,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Offer expired'), findsOneWidget);
    expect(expired, 1);
  });

  testWidgets('disposing cancels the ticker (no pending timers)', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 25, 10);
    await tester.pumpWidget(
      _host(
        TrOfferCountdown(
          offer: _offer(now.add(const Duration(minutes: 10))),
          clock: () => now,
        ),
      ),
    );
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    // flutter_test fails the test if a periodic Timer is still pending.
  });

  testWidgets('compact label survives 200% text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.utc(2026, 11, 25, 10);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: _host(
          SizedBox(
            width: 200,
            child: TrOfferCountdown(
              compact: true,
              offer: _offer(now.add(const Duration(minutes: 9, seconds: 5))),
              clock: () => now,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Expires in 9:05'), findsOneWidget);
  });
}
