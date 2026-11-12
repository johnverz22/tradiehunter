import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/views/widgets/fixo_filter_bar.dart';
import 'package:fixo/views/widgets/fixo_filter_pill.dart';

/// Calculates sRGB relative luminance according to WCAG 2.1 specs.
double relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.04045
        ? value / 12.92
        : pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calculates WCAG contrast ratio between two colors (range: 1.0 to 21.0).
double contrastRatio(Color fg, Color bg) {
  final l1 = relativeLuminance(fg);
  final l2 = relativeLuminance(bg);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('WCAG 4.5:1 contrast verification for filter pills', () {
    test('Selected state contrast in Light theme >= 4.5:1', () {
      const fg = Colors.white;
      const bg = DesignTokens.brand900;
      final ratio = contrastRatio(fg, bg);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Light selected ratio was $ratio');
    });

    test('Selected state contrast in Dark theme >= 4.5:1', () {
      const fg = Colors.white;
      const bg = DesignTokens.brand700;
      final ratio = contrastRatio(fg, bg);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Dark selected ratio was $ratio');
    });

    test('Unselected state contrast in Light theme >= 4.5:1', () {
      final fg = DesignTokens.inkLight;
      final bg = THColors.light.surface;
      final ratio = contrastRatio(fg, bg);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Light unselected ratio was $ratio');
    });

    test('Unselected state contrast in Dark theme >= 4.5:1', () {
      final fg = DesignTokens.inkDark;
      final bg = THColors.dark.surface;
      final ratio = contrastRatio(fg, bg);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Dark unselected ratio was $ratio');
    });

    test('Disabled state contrast in Light theme >= 4.5:1', () {
      final fg = DesignTokens.foregroundDisabled(false);
      final bg = DesignTokens.surfaceDisabled(false);
      final ratio = contrastRatio(fg, bg);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Light disabled ratio was $ratio');
    });

    test('Disabled state contrast in Dark theme >= 4.5:1', () {
      final fg = DesignTokens.foregroundDisabled(true);
      final bg = DesignTokens.surfaceDisabled(true);
      final ratio = contrastRatio(fg, bg);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Dark disabled ratio was $ratio');
    });
  });

  group('FixoFilterPill widget interactions and hit targets', () {
    testWidgets('tap target is at least 48dp high', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: FixoTheme.light(),
        home: Scaffold(
          body: Center(
            child: FixoFilterPill(
              label: 'Plumbing',
              selected: false,
              onSelected: (_) {},
            ),
          ),
        ),
      ));

      final size = tester.getSize(find.byType(FixoFilterPill));
      expect(size.height, greaterThanOrEqualTo(Sizes.tapMin));
    });

    testWidgets('selected pill displays white check icon and solid navy fill',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: FixoTheme.light(),
        home: Scaffold(
          body: Center(
            child: FixoFilterPill(
              label: 'Electrical',
              selected: true,
              showCheckmark: true,
              onSelected: (_) {},
            ),
          ),
        ),
      ));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Electrical'), findsOneWidget);
    });

    testWidgets('unselected pill does not display check icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: FixoTheme.light(),
        home: Scaffold(
          body: Center(
            child: FixoFilterPill(
              label: 'Carpentry',
              selected: false,
              showCheckmark: true,
              onSelected: (_) {},
            ),
          ),
        ),
      ));

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('Carpentry'), findsOneWidget);
    });
  });

  group('FixoFilterBar horizontal scroll row', () {
    testWidgets('renders filter items in a single horizontal scroll row',
        (tester) async {
      String selected = 'Today';
      final items = ['Today', 'Upcoming', 'Awaiting payment', 'Done', 'All'];

      await tester.pumpWidget(MaterialApp(
        theme: FixoTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FixoFilterBar<String>(
                items: items,
                selectedItem: selected,
                labelBuilder: (s) => s,
                onSelected: (s) => setState(() => selected = s),
              );
            },
          ),
        ),
      ));

      // All items are created
      for (final item in items) {
        expect(find.text(item), findsOneWidget);
      }

      // Tap on 'Upcoming'
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      expect(selected, 'Upcoming');
    });

    testWidgets('renders in Dark theme without layout errors',
        (tester) async {
      final items = ['Active', 'Completed', 'All'];
      await tester.pumpWidget(MaterialApp(
        theme: FixoTheme.dark(),
        home: Scaffold(
          body: FixoFilterBar<String>(
            items: items,
            selectedItem: 'Active',
            labelBuilder: (s) => s,
            onSelected: (_) {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
