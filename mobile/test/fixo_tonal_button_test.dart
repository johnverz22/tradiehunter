import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/widgets/fixo_buttons.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildApp({
    required Widget child,
    bool isDark = false,
    double width = 393,
    double scale = 1.0,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDark ? FixoTheme.dark() : FixoTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 852),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('FixoTonalButton', () {
    testWidgets('renders icon and label in light theme with >=48px touch target', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          isDark: false,
          child: FixoTonalButton(
            key: const Key('tonal_btn'),
            icon: Icons.directions_outlined,
            label: 'Navigate',
            onPressed: () => tapped = true,
          ),
        ),
      );

      final buttonFinder = find.byKey(const Key('tonal_btn'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);
      expect(find.byIcon(Icons.directions_outlined), findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(DesignTokens.targetMinimum));
      expect(size.width, greaterThanOrEqualTo(DesignTokens.targetMinimum));

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);
    });

    testWidgets('renders in dark theme with >=48px touch target', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          isDark: true,
          child: FixoTonalButton(
            key: const Key('tonal_btn_dark'),
            icon: Icons.chat_bubble_outline,
            label: 'Message',
            onPressed: () => tapped = true,
          ),
        ),
      );

      final buttonFinder = find.byKey(const Key('tonal_btn_dark'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('Message'), findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);
    });

    testWidgets('disabled state does not fire callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          child: FixoTonalButton(
            key: const Key('disabled_btn'),
            label: 'Disabled',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('disabled_btn')));
      expect(tapped, isFalse);
    });

    testWidgets('loading state displays progress indicator and suppresses callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          child: FixoTonalButton(
            key: const Key('loading_btn'),
            label: 'Loading',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);

      await tester.tap(find.byKey(const Key('loading_btn')));
      expect(tapped, isFalse);
    });

    testWidgets('2-up row layout with 8px gap maintains >=48px height without overflow', (tester) async {
      await tester.pumpWidget(
        buildApp(
          width: 320,
          scale: 1.0,
          child: Row(
            children: [
              Expanded(
                child: FixoTonalButton(
                  key: const Key('btn_1'),
                  icon: Icons.chat_bubble_outline,
                  label: 'Message',
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FixoTonalButton(
                  key: const Key('btn_2'),
                  icon: Icons.phone_outlined,
                  label: 'Call',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final size1 = tester.getSize(find.byKey(const Key('btn_1')));
      final size2 = tester.getSize(find.byKey(const Key('btn_2')));
      expect(size1.height, greaterThanOrEqualTo(48.0));
      expect(size2.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('3-up row layout with 8px gap maintains >=48px height without overflow', (tester) async {
      await tester.pumpWidget(
        buildApp(
          width: 393,
          scale: 1.0,
          child: Row(
            children: [
              Expanded(
                child: FixoTonalButton(
                  key: const Key('btn_chat'),
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FixoTonalButton(
                  key: const Key('btn_call'),
                  icon: Icons.phone_outlined,
                  label: 'Call',
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FixoTonalButton(
                  key: const Key('btn_nav'),
                  icon: Icons.directions_outlined,
                  label: 'Navigate',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      for (final key in ['btn_chat', 'btn_call', 'btn_nav']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });
  });
}
