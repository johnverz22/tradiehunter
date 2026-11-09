import 'package:fixo/views/widgets/job_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapTimeline({
    required Widget child,
    bool isDark = false,
    double width = 393,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('JobTimeline collapsed & expanded behavior', () {
    testWidgets('collapsed by default: shows View all steps and compact bar', (tester) async {
      await tester.pumpWidget(wrapTimeline(
        child: const JobTimeline(status: 'Booked'),
      ));

      expect(find.text('Booked'), findsWidgets);
      expect(find.text('Step 2 of 4 · Booked'), findsOneWidget);
      expect(find.text('View all steps'), findsOneWidget);
      // Timeline details should not be shown when collapsed
      expect(find.text('Tradie matched & booked'), findsNothing);
      expect(find.text('Hide steps'), findsNothing);

      // Tap target is >= 48px
      final buttonSize = tester.getSize(find.widgetWithText(InkWell, 'View all steps'));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('expands inline when View all steps tapped', (tester) async {
      await tester.pumpWidget(wrapTimeline(
        child: const JobTimeline(status: 'InProgress'),
      ));

      expect(find.text('View all steps'), findsOneWidget);
      expect(find.text('Hide steps'), findsNothing);

      await tester.tap(find.text('View all steps'));
      await tester.pumpAndSettle();

      // Now expanded: shows full step titles and descriptions
      expect(find.text('Hide steps'), findsOneWidget);
      expect(find.text('Requested'), findsWidgets);
      expect(find.text('Booked'), findsWidgets);
      expect(find.text('In progress'), findsWidgets);
      expect(find.text('Done'), findsWidgets);
      expect(find.text('Job request submitted'), findsOneWidget);
      expect(find.text('Tradie matched & booked'), findsOneWidget);
      expect(find.text('Work underway on site'), findsOneWidget);
      expect(find.text('Work complete & verified'), findsOneWidget);

      // Tapping Hide steps collapses it back
      await tester.tap(find.text('Hide steps'));
      await tester.pumpAndSettle();

      expect(find.text('View all steps'), findsOneWidget);
      expect(find.text('Hide steps'), findsNothing);
      expect(find.text('Job request submitted'), findsNothing);
    });

    testWidgets('custom step dates format properly when provided', (tester) async {
      final now = DateTime(2026, 10, 30, 9, 30);
      await tester.pumpWidget(wrapTimeline(
        child: JobTimeline(
          status: 'Completed',
          initialExpanded: true,
          stepDates: {
            0: now.subtract(const Duration(hours: 3)),
            1: now.subtract(const Duration(hours: 2)),
            2: now.subtract(const Duration(hours: 1)),
            3: now,
          },
        ),
      ));

      expect(find.text('Oct 30, 9:30 AM'), findsOneWidget);
      expect(find.text('Oct 30, 8:30 AM'), findsOneWidget);
      expect(find.text('Oct 30, 7:30 AM'), findsOneWidget);
      expect(find.text('Oct 30, 6:30 AM'), findsOneWidget);
    });

    testWidgets('terminal state Cancelled renders friendly cancel label', (tester) async {
      await tester.pumpWidget(wrapTimeline(
        child: const JobTimeline(
          status: 'Cancelled',
          initialExpanded: true,
        ),
      ));

      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Job was cancelled'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });

    testWidgets('status unavailable shows recovery message and refresh button', (tester) async {
      var refreshed = false;
      await tester.pumpWidget(wrapTimeline(
        child: JobTimeline(
          status: 'UnknownState',
          onRefresh: () => refreshed = true,
        ),
      ));

      expect(find.text('Status unavailable'), findsOneWidget);
      expect(find.text('Job progress is unavailable. Refresh to check the latest status.'), findsOneWidget);
      expect(find.text('Refresh status'), findsOneWidget);

      await tester.tap(find.text('Refresh status'));
      expect(refreshed, isTrue);
    });
  });

  group('JobTimeline responsiveness & theme safety', () {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at 320px scale $scale in dark=$dark', (tester) async {
          await tester.pumpWidget(wrapTimeline(
            child: const JobTimeline(status: 'AwaitingConfirmation'),
            isDark: dark,
            width: 320,
            textScale: scale,
          ));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
