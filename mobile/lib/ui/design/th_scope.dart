import 'package:flutter/material.dart';

import 'th_tokens.dart';

/// Wraps a v2 subtree in the Trust Navy + Gold theme while the rest of the app
/// keeps `FixoTheme` (migration plan §4.0).
///
/// [themeMode] is the app's existing theme preference (`themeModeProvider`);
/// the caller passes it in so `lib/ui/**` never imports `views/**` (plan 2.4).
/// `ThemeMode.system` follows the platform brightness.
class ThScope extends StatelessWidget {
  const ThScope({super.key, required this.child, this.themeMode = ThemeMode.system});

  final Widget child;
  final ThemeMode themeMode;

  /// Resolves the effective brightness for [themeMode].
  static Brightness resolveBrightness(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = resolveBrightness(context, themeMode) == Brightness.dark;
    final theme = dark ? THTheme.dark : THTheme.light;
    return Theme(
      data: theme,
      child: DefaultTextStyle(style: THType.body.copyWith(color: theme.extension<THColors>()!.text), child: child),
    );
  }
}
