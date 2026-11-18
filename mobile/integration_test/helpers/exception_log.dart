// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';

/// Attributes every framework exception raised during a capture run to the
/// screen being captured, so the P-03 triage (fix plan §4.1) starts from a
/// list instead of "multiple exceptions detected".
///
/// It never swallows anything: each error is recorded, printed as an
/// `__EXCEPTION__` line (collected by `scripts/run-shots.sh` into
/// `exceptions.txt`) and then forwarded to the handler that was installed
/// before, so the test still fails exactly as it did without this helper.
class ExceptionLog {
  ExceptionLog._();

  static String _current = 'startup';
  static final Set<String> _seen = <String>{};
  static final List<String> _lines = <String>[];
  static FlutterExceptionHandler? _previous;
  static bool _installed = false;

  /// Call inside the `testWidgets` body (the binding installs its own
  /// `FlutterError.onError` per test, so installing earlier gets replaced).
  static void install() {
    if (_installed) return;
    _installed = true;
    _previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _record(details);
      _previous?.call(details);
    };
  }

  /// Name the screen about to be pumped; exceptions raised while it settles
  /// are attributed to it. Use the same name as the `__SHOT__` marker.
  static void mark(String screen) => _current = screen;

  static void _record(FlutterErrorDetails details) {
    final message = details.exceptionAsString().split('\n').first.trim();
    final key = '$_current|$message';
    if (!_seen.add(key)) return;
    final line =
        '[$_current] ${details.library ?? 'unknown library'}: $message';
    _lines.add(line);
    print('__EXCEPTION__ $line');
  }

  /// Prints a one-block summary; call at the end of the capture test.
  static void finish() {
    print('__EXCEPTIONS__ ${_lines.length} distinct');
    for (final l in _lines) {
      print('  - $l');
    }
  }
}
