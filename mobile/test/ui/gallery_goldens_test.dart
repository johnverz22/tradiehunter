// Phase 2.7: golden tests for the 30 generated v2 gallery screens, light + dark.
//
// Baselines live in test/ui/goldens/<id>_<light|dark>.png. Generate or refresh
// them with:  flutter test --update-goldens test/ui/gallery_goldens_test.dart
// Until a baseline PNG is committed the golden comparison for that screen is
// skipped (the render smoke check still runs); once committed it is enforced.
import 'dart:io';

import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/gallery/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(393, 852);

bool _hasBaseline(String name) => File('test/ui/goldens/$name.png').existsSync();

void main() {
  test('gallery exposes all 30 screens', () {
    expect(thScreenBuilders.length, 30);
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    for (final entry in thScreenBuilders.entries) {
      final name = '${entry.key}_$theme';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = _size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: THTheme.light,
            darkTheme: THTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: ThScope(
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              child: Builder(builder: entry.value),
            ),
          ),
        );
        // Not pumpAndSettle: some screens (splash, progress) may animate forever.
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        if (_hasBaseline(name)) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
        }
      });
    }
  }
}
