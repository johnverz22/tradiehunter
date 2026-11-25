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
///
/// Phase 6.1: the default is now `all` (v2 everywhere). Pass
/// `--dart-define=UI_V2=` (empty) to fall back to the [v2Screens] allowlist
/// while the remaining v1 branches still exist; the whole flag is deleted
/// together with `lib/views/` in 6.2.
const String kUiV2Define = String.fromEnvironment('UI_V2', defaultValue: 'all');

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
  // Phase 4 non-gallery screens (wired via MatchingScreen / view builders)
  'ho_radar', // quick-match radar — add to v2Screens after pair images
  'ho_job_detail', // job detail router (booked, inProgress, completion, fallback)
  'categories', // service catalog category picker (interim composition N-01)
  'browse_tradies', // browse/find tradies search (interim composition N-01)
  'ho_user_profile', // homeowner public profile /users/:id (N-02)
  // Phase 5 non-gallery screens (no mockup; composed from TH*, needs-design)
  'tr_jobs', // tradie Jobs tab at /jobs (plan 5.8)
  'tr_profile', // tradie profile rating/rates/credentials rows (plan 5.8)
  'wide_layout', // TrJobsScreen master-detail pane at ≥744 px (plan 5.10)
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
