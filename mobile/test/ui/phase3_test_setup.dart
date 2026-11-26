// Shared test bootstrap for the Phase 3 suites: loads the bundled v2 fonts
// (Lexend / Source Sans 3) exactly like test/ui/gallery_goldens_test.dart so
// widget tests measure real text metrics instead of the test fallback font.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Call from `setUpAll` in each Phase 3 suite.
Future<void> loadPhase3Fixtures() async {
  TestWidgetsFlutterBinding.ensureInitialized();
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
}
