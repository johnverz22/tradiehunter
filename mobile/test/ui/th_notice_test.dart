// Phase 2.8: THNotice v2 skin on top of the shared notice controller.
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/feedback/th_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required ThemeMode mode, required Widget body}) => ProviderScope(
  child: MaterialApp(
    theme: THTheme.light,
    darkTheme: THTheme.dark,
    themeMode: mode,
    builder: (context, child) => THNoticeHost(child: child ?? const SizedBox()),
    home: Scaffold(body: body),
  ),
);

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('shows, runs retry action and dismisses (${mode.name})', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        _app(
          mode: mode,
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => THNotice.error(
                context,
                NoticeCopy.checkInFailed,
                onRetry: () => retried = true,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(THDurations.base);

      expect(find.byKey(const Key('th-notice-banner')), findsOneWidget);
      expect(find.text(NoticeCopy.checkInFailed), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(retried, isTrue);
      expect(find.byKey(const Key('th-notice-banner')), findsNothing);
    });
  }

  testWidgets('push notice shows title and View action', (tester) async {
    var viewed = false;
    await tester.pumpWidget(
      _app(
        mode: ThemeMode.light,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => THNotice.push(
              context,
              title: 'New job',
              body: 'Fix tap',
              onView: () => viewed = true,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(THDurations.base);
    expect(find.text('New job'), findsOneWidget);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(viewed, isTrue);
  });

  testWidgets('auto-dismisses after the tone duration', (tester) async {
    await tester.pumpWidget(
      _app(
        mode: ThemeMode.light,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => THNotice.info(context, NoticeCopy.copied),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(THDurations.base);
    expect(find.byKey(const Key('th-notice-banner')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('th-notice-banner')), findsNothing);
  });
}
