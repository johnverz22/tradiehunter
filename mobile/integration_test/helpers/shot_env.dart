// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Run-level environment shared by the capture drivers
/// (`screenshots_test.dart`, `screenshots_variants_test.dart`).
///
/// Everything here is fixed by a `--dart-define` and then *asserted* against
/// what the app actually renders, so a folder labelled "dark" or "200% text"
/// can never silently hold different captures (fix plan P-02 / P-05 / P-07).

/// Forced app theme for the run: `light` or `dark`. Without it the app follows
/// the simulator's appearance.
const shotTheme = String.fromEnvironment('SHOT_THEME', defaultValue: 'light');

const _textScaleDefine = String.fromEnvironment(
  'SHOT_TEXT_SCALE',
  defaultValue: '1.0',
);

/// Text scale factor for the run (1.0 = 100%, 2.0 = 200%). An unparsable or
/// non-positive value fails the run instead of recording a wrong scale.
double get shotTextScale {
  final scale = double.tryParse(_textScaleDefine);
  if (scale == null || scale <= 0) {
    throw ArgumentError.value(
      _textScaleDefine,
      'SHOT_TEXT_SCALE',
      'must be a positive number such as 1.0 or 2.0',
    );
  }
  return scale;
}

/// Seeds the persisted theme mode (ThemeModeNotifier: 0 system, 1 light,
/// 2 dark). Call before `app.main()`.
Future<void> seedShotPrefs() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('theme_mode', shotTheme == 'dark' ? 2 : 1);
}

/// Pins the platform text scale for the whole test. It is set even at 1.0 so a
/// simulator with a non-default Dynamic Type setting cannot leak into a
/// capture labelled "1.0". Call before `app.main()`.
void applyShotTextScale(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = shotTextScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Fails the run if the rendered theme is not the forced one.
void expectShotTheme(WidgetTester tester) {
  final scaffold = find.byType(Scaffold);
  if (scaffold.evaluate().isEmpty) return;
  final brightness = Theme.of(tester.element(scaffold.first)).brightness;
  expect(
    brightness,
    shotTheme == 'dark' ? Brightness.dark : Brightness.light,
    reason: 'SHOT_THEME=$shotTheme but the app rendered $brightness',
  );
}

/// Fails the run if the app renders a different text scale than
/// `SHOT_TEXT_SCALE` (for example because a screen clamps it).
void expectShotTextScale(WidgetTester tester) {
  final scaffold = find.byType(Scaffold);
  if (scaffold.evaluate().isEmpty) return;
  final context = tester.element(scaffold.first);
  final rendered = MediaQuery.textScalerOf(context).scale(10) / 10;
  expect(
    rendered,
    closeTo(shotTextScale, 0.01),
    reason:
        'SHOT_TEXT_SCALE=$shotTextScale but the app rendered text at '
        '$rendered',
  );
}

/// Both assertions, for use right before a `__SHOT__` marker.
void expectShotEnvironment(WidgetTester tester) {
  expectShotTheme(tester);
  expectShotTextScale(tester);
}

/// Whether a fixture id define was supplied (`'0'` / empty = not provided).
bool hasFixture(String id) => id.isNotEmpty && id != '0';

/// Records a capture that was not taken, with the reason. `run-shots.sh`
/// collects these into `skipped.txt`; `scripts/compare-shots.py` then reports
/// the screen as missing, so a skipped capture is never silent.
void shotSkipped(String name, String reason) {
  print('__SHOT_SKIPPED__ $name | $reason');
}
