// THGrid / THTile: cells must grow with the text scale — a fixed aspect ratio
// overflowed by ~11px at 200% on the ho_home category grid (fix plan P-03).
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase3_test_setup.dart';

void main() {
  setUpAll(loadPhase3Fixtures);

  for (final scale in [1.0, 2.0]) {
    testWidgets('THGrid of labelled THTiles fits at ${scale}x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: THTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: THGrid(
                  columns: 4,
                  spacing: Space.s2_5,
                  children: [
                    THTile(Icons.water_drop_rounded, label: 'Plumbing'),
                    THTile(Icons.bolt_rounded, label: 'Electrical'),
                    THTile(Icons.hardware_rounded, label: 'Carpentry'),
                    THTile(Icons.format_paint_rounded, label: 'Painting'),
                    THTile(Icons.eco_rounded, label: 'Gardening'),
                    THTile(Icons.auto_awesome_rounded, label: 'Cleaning'),
                    THTile(Icons.home_rounded, label: 'Roofing'),
                    THTile(Icons.more_horiz_rounded, label: 'More'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}
