import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/views/widgets/cancel_job_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const homeownerReasons = [
    ('changed_mind', 'Changed mind / no longer needed'),
    ('found_alternative', 'Found another tradie'),
    ('price_too_high', 'Price higher than expected'),
    ('scheduling_conflict', 'Scheduling conflict'),
  ];

  const tradieReasons = [
    ('schedule_conflict', 'Schedule conflict / double booked'),
    ('emergency', 'Personal or family emergency'),
    ('vehicle_breakdown', 'Vehicle or equipment breakdown'),
  ];

  void setTestView(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildSheetHarness({
    required Widget child,
    bool isDark = false,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: isDark ? FixoTheme.dark() : FixoTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('CancelJobSheet warning display', () {
    testWidgets('shows homeowner default warning copy', (tester) async {
      setTestView(tester);
      await tester.pumpWidget(
        buildSheetHarness(
          child: const CancelJobSheet(
            isTradie: false,
            reasons: homeownerReasons,
          ),
        ),
      );

      expect(
        find.text('Cancellation fees may apply depending on how far along the job is.'),
        findsOneWidget,
      );
    });

    testWidgets('shows tradie default warning copy', (tester) async {
      setTestView(tester);
      await tester.pumpWidget(
        buildSheetHarness(
          child: const CancelJobSheet(
            isTradie: true,
            reasons: tradieReasons,
          ),
        ),
      );

      expect(
        find.text('Repeated cancellations will flag your account and may affect your ranking.'),
        findsOneWidget,
      );
    });

    testWidgets('custom warning overrides default copy', (tester) async {
      setTestView(tester);
      await tester.pumpWidget(
        buildSheetHarness(
          child: const CancelJobSheet(
            isTradie: false,
            reasons: homeownerReasons,
            warning: 'Job is already in progress. Incurred labor charges apply.',
          ),
        ),
      );

      expect(
        find.text('Job is already in progress. Incurred labor charges apply.'),
        findsOneWidget,
      );
      expect(
        find.text('Cancellation fees may apply depending on how far along the job is.'),
        findsNothing,
      );
    });
  });

  group('CancelJobSheet interaction & result', () {
    testWidgets('confirm button disabled until reason selected', (tester) async {
      setTestView(tester);
      await tester.pumpWidget(
        buildSheetHarness(
          child: const CancelJobSheet(
            isTradie: false,
            reasons: homeownerReasons,
          ),
        ),
      );

      final confirmFinder = find.byKey(const Key('cancel_confirm_button'));
      expect(confirmFinder, findsOneWidget);
      final confirmButton = tester.widget<FilledButton>(confirmFinder);
      expect(confirmButton.onPressed, isNull);

      // Select a reason
      await tester.tap(find.text('Found another tradie'));
      await tester.pumpAndSettle();

      final updatedButton = tester.widget<FilledButton>(confirmFinder);
      expect(updatedButton.onPressed, isNotNull);
    });

    testWidgets('confirming with reason and notes pops correct record', (tester) async {
      setTestView(tester);
      ({String reasonCode, String? notes})? sheetResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: FixoTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  sheetResult = await showModalBottomSheet<({String reasonCode, String? notes})>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => const CancelJobSheet(
                      isTradie: false,
                      reasons: homeownerReasons,
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap radio
      await tester.tap(find.text('Scheduling conflict'));
      await tester.pumpAndSettle();

      // Enter notes
      await tester.enterText(find.byType(TextField), 'Travelling out of town tomorrow');
      await tester.pumpAndSettle();

      // Tap Confirm
      await tester.tap(find.byKey(const Key('cancel_confirm_button')));
      await tester.pumpAndSettle();

      expect(sheetResult, isNotNull);
      expect(sheetResult!.reasonCode, 'scheduling_conflict');
      expect(sheetResult!.notes, 'Travelling out of town tomorrow');
    });

    testWidgets('confirming with empty notes returns null notes in record', (tester) async {
      setTestView(tester);
      ({String reasonCode, String? notes})? sheetResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: FixoTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  sheetResult = await showModalBottomSheet<({String reasonCode, String? notes})>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => const CancelJobSheet(
                      isTradie: true,
                      reasons: tradieReasons,
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personal or family emergency'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel_confirm_button')));
      await tester.pumpAndSettle();

      expect(sheetResult, isNotNull);
      expect(sheetResult!.reasonCode, 'emergency');
      expect(sheetResult!.notes, isNull);
    });

    testWidgets('dismissing with Keep Job pops null', (tester) async {
      setTestView(tester);
      ({String reasonCode, String? notes})? sheetResult;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: FixoTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  sheetResult = await showModalBottomSheet<({String reasonCode, String? notes})>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => const CancelJobSheet(
                      isTradie: false,
                      reasons: homeownerReasons,
                    ),
                  );
                  dismissed = true;
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('cancel_dismiss_button')));
      await tester.tap(find.byKey(const Key('cancel_dismiss_button')));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(sheetResult, isNull);
    });
  });

  group('CancelJobSheet responsive & theme sanity', () {
    for (final isDark in [false, true]) {
      testWidgets('renders cleanly on 320px narrow viewport dark=$isDark', (tester) async {
        setTestView(tester, size: const Size(320, 700));
        await tester.pumpWidget(
          buildSheetHarness(
            isDark: isDark,
            child: const SingleChildScrollView(
              child: CancelJobSheet(
                isTradie: false,
                reasons: homeownerReasons,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancel this job'), findsOneWidget);
        expect(find.text('Keep Job'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
