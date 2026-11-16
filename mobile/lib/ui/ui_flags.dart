/// Per-screen switch between the v1 screens and their v2 rebuilds
/// (design-system migration plan §4.0, task 2.10).
///
/// A route builder calls [isV2Screen] with the **v2 screen id** (the keys of
/// `thScreenBuilders`, e.g. `'sign_in'`, `'ho_home'`). It returns the v2
/// screen when the id is listed in [v2Screens], or when the app was started
/// with `--dart-define=UI_V2=all`; otherwise the route keeps building the old
/// screen. Rolling a screen back is a one-line change to [v2Screens].
///
/// Developers can try everything on v2 without editing code:
///   flutter run --dart-define=UI_V2=all
/// or a subset:
///   flutter run --dart-define=UI_V2=sign_in,onboarding
library;

/// Raw `--dart-define=UI_V2=…` value: empty, `all`, or comma-separated ids.
const String kUiV2Define = String.fromEnvironment('UI_V2');

/// Screens shipped on v2 (migration plan Phase 3). One id per ported screen;
/// rolling a screen back is a one-line removal here.
const Set<String> v2Screens = <String>{
  'shell', // ThShell (ui/shared/th_shell.dart) — swaps the ShellRoute builder
  'splash',
  'onboarding',
  'sign_in',
  'verify_otp',
  'role_select',
  'signup',
  'chat',
  'notifications',
  'profile',
  'messages_list',
  'settings',
};

/// Phase 3 screens that are real app screens, not gallery mockups — they
/// have no entry in `thScreenBuilders` (ui_flags_test checks the union).
const Set<String> nonGalleryV2Screens = <String>{
  'shell',
  'signup',
  'messages_list',
  'settings',
};

/// Pure resolver, parameterised so it can be unit-tested without
/// `--dart-define`. Prefer [isV2Screen] in app code.
bool resolveV2Screen(
  String id, {
  String define = '',
  Set<String> allowlist = const <String>{},
}) {
  final value = define.trim();
  if (value == 'all') return true;
  if (allowlist.contains(id)) return true;
  if (value.isEmpty) return false;
  return value.split(',').map((s) => s.trim()).contains(id);
}

/// True when [id] should render its v2 screen.
bool isV2Screen(String id) =>
    resolveV2Screen(id, define: kUiV2Define, allowlist: v2Screens);
