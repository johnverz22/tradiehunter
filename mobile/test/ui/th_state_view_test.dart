// Phase 2.9: ThStateView loading / empty / error / presets, light + dark.
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/feedback/th_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool dark = false, bool reduceMotion = false}) => MaterialApp(
      theme: dark ? THTheme.dark : THTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: SizedBox(height: 700, child: child)),
      ),
    );

void main() {
  for (final dark in [false, true]) {
    final t = dark ? 'dark' : 'light';

    testWidgets('loading shows skeleton rows and label ($t)', (tester) async {
      await tester.pumpWidget(_app(const ThStateView.loading(label: 'Loading jobs…'), dark: dark));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Loading jobs…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty shows title, body and action ($t)', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(
        ThStateView.empty(
          icon: Icons.work_off_outlined,
          title: 'No jobs yet',
          body: 'Post your first job.',
          actionLabel: 'Post a job',
          onAction: () => tapped = true,
        ),
        dark: dark,
      ));
      expect(find.text('No jobs yet'), findsOneWidget);
      expect(find.text('Post your first job.'), findsOneWidget);
      await tester.tap(find.text('Post a job'));
      expect(tapped, isTrue);
    });

    testWidgets('error shows retry only when a handler is given ($t)', (tester) async {
      await tester.pumpWidget(_app(const ThStateView.error(message: 'Something broke'), dark: dark));
      expect(find.text('Something broke'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      var retried = false;
      await tester.pumpWidget(_app(ThStateView.error(message: 'Something broke', onRetry: () => retried = true), dark: dark));
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });
  }

  testWidgets('presets carry the v1 copy, area and actions', (tester) async {
    await tester.pumpWidget(_app(ThStateView.preset(ThStatePreset.emptyLeads, area: 'Grey Lynn')));
    expect(find.text('No new leads right now'), findsOneWidget);
    expect(find.textContaining('Grey Lynn'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);

    var back = false;
    var support = false;
    await tester.pumpWidget(_app(ThStateView.preset(
      ThStatePreset.jobNotFound,
      onAction: () => back = true,
      onSecondary: () => support = true,
    )));
    await tester.tap(find.text('Back to my jobs'));
    await tester.tap(find.text('Contact support'));
    expect(back && support, isTrue);
  });

  testWidgets('loading does not animate with reduce-motion on', (tester) async {
    await tester.pumpWidget(_app(const ThStateView.loading(), reduceMotion: true));
    await tester.pumpAndSettle(); // would time out if the pulse kept repeating
    expect(tester.takeException(), isNull);
  });
}
