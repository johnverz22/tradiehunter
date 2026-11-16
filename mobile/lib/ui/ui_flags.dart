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

/// Screens shipped on v2. Phases 3-5 add an id here as each screen's parity
/// checklist, tests and visual QA are done. Empty until Phase 3 lands.
const Set<String> v2Screens = <String>{};

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
