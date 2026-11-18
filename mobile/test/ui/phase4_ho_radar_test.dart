// N-03: the v2 quick-match radar (ThRadarScreen) mounted directly, so these
// tests need no --dart-define=UI_V2. The flow behind it (SignalR, dispatch,
// stall watchdog, cancel) is covered by test/matching_flow_test.dart, which
// should also be run with --dart-define=UI_V2=ho_radar before the id is
// activated.
import 'package:fixo/ui/homeowner/ho_radar_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _starting = MatchingProgressState(jobId: '42');

const _contacting2 = MatchingProgressState(
  jobId: '42',
  phase: MatchingPhase.contactingTradie,
  offerIndex: 2,
  offersMade: 2,
);

const _noTradie = MatchingProgressState(
  jobId: '42',
  phase: MatchingPhase.noTradieFound,
);

const _matched = MatchingProgressState(
  jobId: '42',
  phase: MatchingPhase.matched,
);

/// A fixed point of the ripple, so nothing repeats and `pump` never hangs.
const _frame = AlwaysStoppedAnimation<double>(0.3);

Future<void> _pump(
  WidgetTester tester, {
  MatchingProgressState progress = _starting,
  Animation<double>? radar,
  bool reconnecting = false,
  bool stalled = false,
  bool dispatchFailed = false,
  bool busy = false,
  VoidCallback? onTryAgain,
  VoidCallback? onCancel,
  ThemeMode themeMode = ThemeMode.light,
  double width = 360,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ThRadarScreen(
        progress: progress,
        radar: radar,
        reconnecting: reconnecting,
        stalled: stalled,
        dispatchFailed: dispatchFailed,
        busy: busy,
        themeMode: themeMode,
        onTryAgain: onTryAgain ?? () {},
        onCancel: onCancel ?? () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('searching', () {
    testWidgets('animated radar, headline and Cancel', (tester) async {
      await _pump(tester, radar: _frame);
      expect(find.byKey(const ValueKey('matching-radar')), findsOneWidget);
      expect(find.text('Finding tradies near you…'), findsOneWidget);
      expect(find.text('Checking availability and distance'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion draws only the static core', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('matching-radar')), findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('contacting a tradie shows the index and progress dots', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, progress: _contacting2, radar: _frame);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Contacting Tradie 2…'), findsOneWidget);
      expect(find.bySemanticsLabel('Contacting tradie 2'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('reconnecting shows a truthful notice', (tester) async {
      await _pump(tester, reconnecting: true);
      expect(find.text('Connection lost — reconnecting…'), findsOneWidget);
    });

    testWidgets('stalled offers Try again and the stall line', (tester) async {
      var retries = 0;
      await _pump(tester, stalled: true, onTryAgain: () => retries++);
      expect(find.text('This is taking longer than usual.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('radar_try_again_button')));
      expect(retries, 1);
    });

    testWidgets('Cancel calls back', (tester) async {
      var cancels = 0;
      await _pump(tester, onCancel: () => cancels++);
      await tester.tap(find.byKey(const Key('radar_cancel_button')));
      expect(cancels, 1);
    });
  });

  group('dispatch failure', () {
    testWidgets('shows the designed failure state, not the radar', (
      tester,
    ) async {
      await _pump(tester, dispatchFailed: true, radar: _frame);
      expect(
        find.text('Could not start matching for this job.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey('matching-radar')), findsNothing);
      expect(find.text('Finding tradies near you…'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Try again is disabled while a dispatch is in flight', (
      tester,
    ) async {
      var retries = 0;
      await _pump(
        tester,
        dispatchFailed: true,
        busy: true,
        onTryAgain: () => retries++,
      );
      await tester.tap(find.byKey(const Key('radar_try_again_button')));
      expect(retries, 0);
    });
  });

  group('terminal states', () {
    testWidgets('no tradie found: reason, Go Back, no Cancel or Try again', (
      tester,
    ) async {
      await _pump(tester, progress: _noTradie, stalled: true);
      expect(find.text('No tradies available'), findsOneWidget);
      expect(
        find.text(
          'We couldn\'t find a match right now. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('no tradie found uses the server reason when given', (
      tester,
    ) async {
      await _pump(
        tester,
        progress: const MatchingProgressState(
          jobId: '42',
          phase: MatchingPhase.noTradieFound,
          reason: 'Nobody is free in Grafton today.',
        ),
      );
      expect(find.text('Nobody is free in Grafton today.'), findsOneWidget);
    });

    testWidgets('matched shows the found state', (tester) async {
      await _pump(tester, progress: _matched);
      expect(find.text('Tradie found'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('layout', () {
    final states = <String, MatchingProgressState>{
      'starting': _starting,
      'contacting': _contacting2,
      'noTradie': _noTradie,
      'matched': _matched,
    };

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final width in [320.0, 360.0, 840.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final entry in states.entries) {
            testWidgets(
              '${entry.key} ${mode.name} ${width.toInt()}pt x$scale: no overflow',
              (tester) async {
                await _pump(
                  tester,
                  progress: entry.value,
                  radar: _frame,
                  themeMode: mode,
                  width: width,
                  scale: scale,
                  stalled: entry.key == 'starting',
                  reconnecting: entry.key == 'starting',
                );
                expect(tester.takeException(), isNull);
              },
            );
          }

          testWidgets(
            'dispatch failure ${mode.name} ${width.toInt()}pt x$scale: '
            'no overflow, both buttons tappable',
            (tester) async {
              await _pump(
                tester,
                dispatchFailed: true,
                themeMode: mode,
                width: width,
                scale: scale,
              );
              expect(tester.takeException(), isNull);
              for (final key in const [
                'radar_try_again_button',
                'radar_cancel_button',
              ]) {
                final rect = tester.getRect(find.byKey(Key(key)));
                expect(rect.width, greaterThan(0), reason: key);
                expect(rect.right, lessThanOrEqualTo(width), reason: key);
              }
            },
          );
        }
      }
    }
  });
}
