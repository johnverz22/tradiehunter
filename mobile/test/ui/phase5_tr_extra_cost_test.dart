// Phase 5.4: v2 tradie request extra cost (`tr_extra_cost`).
import 'package:decimal/decimal.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/ui/tradie/tr_extra_cost_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase3_test_setup.dart';

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildPage({bool dark = false, String? homeownerFirstName}) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        platformBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: ProviderScope(
        child: MaterialApp(
          home: TrExtraCostPage(homeownerFirstName: homeownerFirstName),
        ),
      ),
    );
  }

  group('TrExtraCostPage', () {
    testWidgets(
      'renders subtitle with homeowner first name in light and dark',
      (tester) async {
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            buildPage(dark: dark, homeownerFirstName: 'Aroha'),
          );
          await tester.pumpAndSettle();

          expect(find.text('Request extra cost'), findsOneWidget);
          expect(
            find.text('Aroha must approve before billing'),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('extra_cost_amount_field')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('extra_cost_description_field')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('extra_cost_submit_button')),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('validation matrix disables submit for invalid inputs', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      Future<void> enter(String amount, String desc) async {
        await tester.enterText(
          find.byKey(const Key('extra_cost_amount_field')),
          amount,
        );
        await tester.enterText(
          find.byKey(const Key('extra_cost_description_field')),
          desc,
        );
        await tester.pump();
      }

      bool isEnabled() {
        final btn = tester.widget<THButton>(
          find.byKey(const Key('extra_cost_submit_button')),
        );
        return btn.onPressed != null;
      }

      // Empty
      expect(isEnabled(), isFalse);
      // Zero
      await enter('0', 'Tap');
      expect(isEnabled(), isFalse);
      // Negative
      await enter('-12.50', 'Tap');
      expect(isEnabled(), isFalse);
      // Non-numeric
      await enter('abc', 'Tap');
      expect(isEnabled(), isFalse);
      // Empty description
      await enter('48.50', '   ');
      expect(isEnabled(), isFalse);
      // Valid
      await enter('48.50', 'Replacement tap cartridge');
      expect(isEnabled(), isTrue);
    });

    testWidgets('pushTrExtraCost pops with exact (kind, amount, description)', (
      tester,
    ) async {
      (String, Decimal, String)? result;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await pushTrExtraCost(
                      ctx,
                      homeownerFirstName: 'Mere',
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

      await tester.tap(
        find.byKey(const Key('extra_cost_kind_${JobAdjustment.kindTravel}')),
      );
      await tester.enterText(
        find.byKey(const Key('extra_cost_amount_field')),
        '35.00',
      );
      await tester.enterText(
        find.byKey(const Key('extra_cost_description_field')),
        'Parking & bridge toll',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('extra_cost_submit_button')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.$1, JobAdjustment.kindTravel);
      expect(result!.$2, Decimal.parse('35.00'));
      expect(result!.$3, 'Parking & bridge toll');
    });
  });
}
