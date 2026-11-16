import 'package:fixo/views/widgets/compact_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapBar({
    required Widget child,
    bool isDark = false,
    double width = 393,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  group('CompactProgressBar steps', () {
    // v1.7 (P12-15): a status-only bar resolves under the current v2 flow —
    // the 6-step Requested → Booked → In progress → Review & approve → Pay →
    // Completed stepper.
    testWidgets('Step 1: Requested renders step 1 of 6 and 1 segment', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapBar(child: const CompactProgressBar(status: 'Requested')),
      );
      expect(find.text('Step 1 of 6 · Requested'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Progress: Step 1 of 6 · Requested'),
        findsOneWidget,
      );
    });

    testWidgets('Step 2: Booked renders step 2 of 6 and 2 segments', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapBar(child: const CompactProgressBar(status: 'Booked')),
      );
      expect(find.text('Step 2 of 6 · Booked'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Progress: Step 2 of 6 · Booked'),
        findsOneWidget,
      );
    });

    testWidgets('Step 3: InProgress renders step 3 of 6 and 3 segments', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapBar(child: const CompactProgressBar(status: 'InProgress')),
      );
      expect(find.text('Step 3 of 6 · In progress'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Progress: Step 3 of 6 · In progress'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Step 6: Completed renders step 6 of 6 · Completed and all 6 segments',
      (tester) async {
        await tester.pumpWidget(
          wrapBar(child: const CompactProgressBar(status: 'Completed')),
        );
        expect(find.text('Step 6 of 6 · Completed'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Progress: Step 6 of 6 · Completed'),
          findsOneWidget,
        );
      },
    );

    testWidgets('legacy flowVersion-1 job keeps the 4-step order', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapBar(
          child: const CompactProgressBar(status: 'Booked', flowVersion: 1),
        ),
      );
      expect(find.text('Step 2 of 4 · Booked'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Progress: Step 2 of 4 · Booked'),
        findsOneWidget,
      );
    });

    testWidgets(
      'v2 stage drives the index directly (Review & approve = step 4)',
      (tester) async {
        await tester.pumpWidget(
          wrapBar(
            child: const CompactProgressBar(
              status: 'AwaitingConfirmation',
              stage: 3,
              flowVersion: 2,
            ),
          ),
        );
        expect(find.text('Step 4 of 6 · Review & approve'), findsOneWidget);
      },
    );
  });

  group('CompactProgressBar terminal states', () {
    testWidgets('Cancelled renders muted appearance without Done fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapBar(child: const CompactProgressBar(status: 'Cancelled')),
      );
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.textContaining('Step '), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.bySemanticsLabel('Progress: Cancelled'), findsOneWidget);
    });

    testWidgets('Expired renders muted appearance without Done fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapBar(child: const CompactProgressBar(status: 'Expired')),
      );
      expect(find.text('Expired'), findsOneWidget);
      expect(find.textContaining('Step '), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.bySemanticsLabel('Progress: Expired'), findsOneWidget);
    });

    testWidgets('Disputed renders muted appearance without Done fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapBar(child: const CompactProgressBar(status: 'Disputed')),
      );
      expect(find.text('Disputed'), findsOneWidget);
      expect(find.textContaining('Step '), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.bySemanticsLabel('Progress: Disputed'), findsOneWidget);
    });
  });

  group('CompactProgressBar responsiveness & themes', () {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('renders cleanly at 320px scale $scale in dark=$dark', (
          tester,
        ) async {
          await tester.pumpWidget(
            wrapBar(
              child: const CompactProgressBar(status: 'InProgress'),
              isDark: dark,
              width: 320,
              textScale: scale,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Step 3 of 6 · In progress'), findsOneWidget);
        });
      }
    }
  });
}
