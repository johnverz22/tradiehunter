import 'package:fixo/views/widgets/job_progress.dart';
import 'package:fixo/views/widgets/job_status_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // v1.7 (P12-15): status-only progress resolves under the v2 stepper.
  const v2Titles = JobStepperFlow.v2Titles;
  const stages = {
    'Requested': 0,
    'AwaitingPayment': 0,
    'PaymentReview': 0,
    'Booked': 1,
    'InProgress': 2,
    'AwaitingConfirmation': 2,
    'Completed': 3,
    'Cancelled': null,
    'Expired': null,
    'Disputed': null,
    'FutureState': null,
    '': null,
  };
  for (final entry in stages.entries) {
    test('${entry.key} has only authoritative progress', () {
      expect(
        JobStatusPresentation.forStatus(entry.key).progressStage,
        entry.value,
      );
    });
  }
  testWidgets(
    'wide progress shows full sequence and unknown refresh is explicit',
    (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: JobProgress(status: 'AwaitingConfirmation')),
        ),
      );
      expect(find.text('Step 4 of 6 · Review & approve'), findsOneWidget);
      expect(find.text('View all steps'), findsOneWidget);
      await tester.tap(find.text('View all steps'));
      await tester.pumpAndSettle();
      for (final label in v2Titles) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('Hide steps'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobProgress(
              status: 'FutureState',
              onRefresh: () => refreshes++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Refresh status'));
      expect(refreshes, 1);
      expect(find.text('Completed'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('progress is readable at 320px/$scale dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        for (final entry in stages.entries) {
          final presentation = JobStatusPresentation.forStatus(entry.key);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: JobProgress(
                        status: entry.key,
                        initialExpanded: entry.value != null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text(presentation.label), findsWidgets);
          if (entry.value == null) {
            expect(find.textContaining('Step '), findsNothing);
            expect(find.text('Completed'), findsNothing);
          } else {
            // The caption renders as main + sublabel texts (plus the
            // invisible combined measurement text), so match loosely.
            expect(find.textContaining('Step '), findsWidgets);
            for (final label in v2Titles) {
              expect(find.text(label), findsWidgets);
            }
            expect(
              find.bySemanticsLabel(
                RegExp('Requested.*Booked.*In progress.*Review & approve.*Pay.*Completed'),
              ),
              findsOneWidget,
            );
          }
        }
        semantics.dispose();
      });
    }
  }
}
