// Phase 5.5: v2 tradie check-out / complete job (`tr_complete`).
import 'package:decimal/decimal.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/tradie/tr_complete_page.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase3_test_setup.dart';

Job _job({int hours = 2}) => Job(
  id: 'j42',
  title: 'Leaking kitchen tap',
  category: 'Plumbing',
  suburb: 'Grey Lynn',
  status: 'InProgress',
  stage: 3,
  hours: hours,
  hourlyRate: Decimal.parse('85.00'),
);

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildPage({
    bool dark = false,
    Job? job,
    Decimal? approvedExtras,
    Map<String, dynamic> localeConfig = const {'commissionPercent': '10'},
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        platformBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: ProviderScope(
        overrides: [
          localeConfigProvider.overrideWith((ref) async => localeConfig),
        ],
        child: MaterialApp(
          home: TrCompletePage(
            job: job ?? _job(),
            approvedAdjustmentsTotal: approvedExtras ?? Decimal.zero,
          ),
        ),
      ),
    );
  }

  group('TrCompletePage', () {
    testWidgets('renders totals and commission rows in light and dark', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          buildPage(dark: dark, approvedExtras: Decimal.parse('48.50')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Complete job'), findsOneWidget);
        expect(find.text('Leaking kitchen tap'), findsOneWidget);
        expect(find.byKey(const Key('final_hours_field')), findsOneWidget);
        expect(find.text('Approved extras'), findsOneWidget);
        expect(find.text('Homeowner pays'), findsOneWidget);
        expect(find.text('You receive'), findsOneWidget);
        // G-20: on-site times card omitted
        expect(find.textContaining('On site'), findsNothing);
      }
    });

    testWidgets('hides commission rows when commissionPercent is missing', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage(localeConfig: const {}));
      await tester.pumpAndSettle();

      expect(find.text('Homeowner pays'), findsOneWidget);
      expect(find.text('You receive'), findsNothing);
    });

    testWidgets('stepper increments and decrements within bounds', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage(job: _job(hours: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('plus'));
      await tester.pump();
      expect(find.text('1.5'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('minus'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('minus'));
      await tester.pump();
      expect(find.text('0.5'), findsOneWidget);

      // Cannot go below 0.5
      await tester.tap(find.bySemanticsLabel('minus'));
      await tester.pump();
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('pushTrComplete pops with confirmed hours', (tester) async {
      double? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeConfigProvider.overrideWith(
              (ref) async => {'commissionPercent': '10'},
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await pushTrComplete(
                      ctx,
                      job: _job(hours: 2),
                      approvedAdjustmentsTotal: Decimal.zero,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('plus'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('check_out_submit_button')));
      await tester.pumpAndSettle();

      expect(result, 2.5);
    });
  });
}
