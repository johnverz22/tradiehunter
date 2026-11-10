import 'dart:io';

import 'package:fixo/feedback/fixo_notice.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Static lint check (Sub-task 8-H)', () {
    test('Zero occurrences of ScaffoldMessenger / SnackBar in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final forbidden = [
        'ScaffoldMessenger.of',
        'showSnackBar',
        'SnackBar(',
      ];

      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          for (final pattern in forbidden) {
            if (content.contains(pattern)) {
              violations.add('${file.path} contains "$pattern"');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Legacy SnackBar usage found! All feedback must use FixoNotice instead:\n'
            '${violations.join('\n')}',
      );
    });
  });

  group('FixoNoticeController unit tests', () {
    test('initial state is null', () {
      final controller = FixoNoticeController();
      expect(controller.state, isNull);
      controller.dispose();
    });

    test('show sets state and dismiss clears state', () {
      final controller = FixoNoticeController();
      const state = FixoNoticeState(
        message: 'Test info',
        tone: FixoNoticeTone.info,
      );

      controller.show(state);
      expect(controller.state, equals(state));

      controller.dismiss();
      expect(controller.state, isNull);
      controller.dispose();
    });

    test('showing a new notice replaces previous state', () {
      final controller = FixoNoticeController();
      const first = FixoNoticeState(
        message: 'First',
        tone: FixoNoticeTone.info,
      );
      const second = FixoNoticeState(
        message: 'Second',
        tone: FixoNoticeTone.error,
      );

      controller.show(first);
      expect(controller.state?.message, 'First');

      controller.show(second);
      expect(controller.state?.message, 'Second');
      expect(controller.state?.tone, FixoNoticeTone.error);
      controller.dispose();
    });
  });

  group('FixoNoticeHost widget tests', () {
    Widget createTestApp({
      required Widget child,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return ProviderScope(
        child: MaterialApp(
          theme: FixoTheme.light(),
          darkTheme: FixoTheme.dark(),
          themeMode: themeMode,
          builder: (context, c) => FixoNoticeHost(child: c ?? const SizedBox()),
          home: child,
        ),
      );
    }

    testWidgets('renders info notice and dismisses on close tap', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FixoNotice.info(context, NoticeCopy.copied),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      expect(find.text(NoticeCopy.copied), findsNothing);

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // finish slide-in animation

      expect(find.text(NoticeCopy.copied), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Close button meets tap target minimum (48dp)
      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      final closeBox = tester.getRect(find.ancestor(
        of: closeButton,
        matching: find.byType(SizedBox),
      ).first);
      expect(closeBox.width, greaterThanOrEqualTo(Sizes.tapMin));
      expect(closeBox.height, greaterThanOrEqualTo(Sizes.tapMin));

      // Tap close button
      await tester.tap(closeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // finish slide-out animation

      expect(find.text(NoticeCopy.copied), findsNothing);
    });

    testWidgets('renders success notice', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    FixoNotice.success(context, NoticeCopy.profileUpdated),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(NoticeCopy.profileUpdated), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('renders warning notice', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    FixoNotice.warning(context, NoticeCopy.noCallApp),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(NoticeCopy.noCallApp), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders error notice with onRetry action', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FixoNotice.error(
                  context,
                  NoticeCopy.checkInFailed,
                  onRetry: () => retried = true,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(NoticeCopy.checkInFailed), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(retried, isTrue);
      // Tapping action should dismiss notice
      expect(find.text(NoticeCopy.checkInFailed), findsNothing);
    });

    testWidgets('renders push notice with title, body, and View action',
        (tester) async {
      var viewed = false;

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FixoNotice.push(
                  context,
                  title: 'New Job Request',
                  body: 'Leaking sink in Grey Lynn',
                  onView: () => viewed = true,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('New Job Request'), findsOneWidget);
      expect(find.text('Leaking sink in Grey Lynn'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('View'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewed, isTrue);
      expect(find.text('New Job Request'), findsNothing);
    });

    testWidgets('renders correctly in dark theme', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          themeMode: ThemeMode.dark,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    FixoNotice.info(context, NoticeCopy.copied),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(NoticeCopy.copied), findsOneWidget);
    });
  });
}
