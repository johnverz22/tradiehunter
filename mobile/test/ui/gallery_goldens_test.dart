// Phase 2.7: golden tests for the 30 generated v2 gallery screens, light + dark.
//
// Baselines live in test/ui/goldens/<id>_<light|dark>.png. Generate or refresh
// them with:  flutter test --update-goldens test/ui/gallery_goldens_test.dart
// Until a baseline PNG is committed the golden comparison for that screen is
// skipped (the render smoke check still runs); once committed it is enforced.
//
// Baselines are generated on the Flutter version pinned in
// .github/workflows/ci.yml. Text anti-aliasing shifts slightly between Flutter
// patch releases, so local runs on another patch version tolerate up to
// [_kPixelTolerance] of differing pixels; real layout/colour regressions are
// far above that. Refresh baselines only on the CI version.
import 'dart:io';

import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/gallery/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(393, 852);

/// Max fraction of differing pixels still treated as a match (1%).
const double _kPixelTolerance = 0.01;

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= _kPixelTolerance) {
      debugPrint(
        'golden $golden differs by '
        '${(result.diffPercent * 100).toStringAsFixed(2)}% (within tolerance)',
      );
      return true;
    }
    throw FlutterError(
      'Golden "$golden" differs by '
      '${(result.diffPercent * 100).toStringAsFixed(2)}% '
      '(tolerance ${(_kPixelTolerance * 100).toStringAsFixed(0)}%). '
      'Refresh only on the CI Flutter version.',
    );
  }
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final current = goldenFileComparator;
    if (current is LocalFileComparator) {
      goldenFileComparator = _TolerantGoldenComparator(
        current.basedir.resolve('gallery_goldens_test.dart'),
      );
    }
    const base = 'assets/fonts/v2';
    await _loadFont('Lexend', [
      '$base/Lexend-Regular.ttf',
      '$base/Lexend-Medium.ttf',
      '$base/Lexend-SemiBold.ttf',
      '$base/Lexend-Bold.ttf',
      '$base/Lexend-ExtraBold.ttf',
    ]);
    await _loadFont('Source Sans 3', [
      '$base/SourceSans3-Regular.ttf',
      '$base/SourceSans3-Medium.ttf',
      '$base/SourceSans3-SemiBold.ttf',
      '$base/SourceSans3-Bold.ttf',
    ]);
  });

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
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
