# Phase 3 Audit — Task Checklist

Source: audit of `feat(mobile): phase 3` (`9e9011c`) and QA screenshots (`0bc055a`) against
`docs/design_system_migration_plan.md` §4.0, §4.2 and the Phase 3 "done when" criteria.

**Verdict: FAIL** — v1 Home / Jobs screens crash inside the v2 shell (B1). Do not ship with `'shell'` in `v2Screens` until B1 is closed.

Not verified in this audit: `flutter analyze` / `flutter test` (SDK unavailable in the review sandbox). Confirm in CI.
Verified: `python3 scripts/check_ui_boundary.py` ok; `node docs/design/tools/build.mjs --check` ok (30 screens, contrast 38/38).

---

## Blocker

- [ ] **B1. Scope `ThScope` to shell chrome only, not the routed child**
  - `mobile/lib/ui/shared/th_shell.dart:94` wraps `widget.child` in `ThScope`; the file header (lines 15–17) says it must not.
  - Cause: `THTheme` installs only the v2 `THColors` extension; v1 widgets call `Theme.of(context).extension<THColors>()!` (65 sites, e.g. `widgets/th_components.dart:137,195,280`) → null-check crash.
  - Evidence: `docs/qa/phase3/` shots `06.38.52` (homeowner Home), `06.41.47` (tradie Home), `06.41.52` (My Jobs, also "BOTTOM OVERFLOWED BY 99276 PIXELS").
  - [ ] Wrap only `THDock` / `_ThNavRail` (and their Material) in `ThScope`; leave `widget.child` under the app theme
  - [ ] Fix/update the `th_shell.dart` header comment so it matches the code
  - [ ] Add shell test mounting real v1 `HomeownerDashboardView` and the tradie dashboard/jobs list under `ThShell` (provider overrides; stubs in `test/ui/phase3_shell_test.dart:89-100` hid this)
  - [ ] Add a Home-tab golden or screenshot test under the shell, light + dark
  - [ ] Re-shoot Home, Jobs, Chat, Profile on device after the fix
  - [ ] Until merged: remove `'shell'` from `v2Screens` (`mobile/lib/ui/ui_flags.dart`) if releasing

## Major

- [ ] **M1. Profile does not follow the v2 mockup**
  - Mockup (`docs/design/flutter/screens/profile_screen.dart`): avatar + name/email, Personal details / Payments / Notifications list, dark-mode switch, Help, ghost Sign out.
  - Built (`mobile/lib/ui/shared/profile_screen.dart`): v1 edit form in v2 chrome; read-only fields look editable; duplicate edit controls (header pencil ~L221 and "Edit Profile" button ~L274). See shots `06.38.59`, `06.42.11`.
  - [ ] Decide: rebuild to the mockup (edit moved to a sub-view) **or** record a deliberate deviation
  - [ ] Correct plan/commit notes: `profile` HAS a v2 design (only `messages_list`, `settings`, `signup`, rail are needs-design)
  - [ ] Keep existing profile actions (edit, block/report, device-token, role-specific tradie fields) and keys

- [ ] **M2. Complete the Phase 3 visual QA evidence (light + dark)**
  - [ ] Capture dark-mode shots for every Phase 3 screen (none exist today)
  - [ ] Add missing screens: splash, onboarding, verify_otp, role_select, chat thread, notifications, rail at ≥1024px
  - [ ] Move the two `iPhone 17 Pro … 2026-11-10` shots (old v1 UI, raw `DioException` text) out of `docs/qa/phase3/` into a baseline folder
  - [ ] Use sortable names (`NN--<screen>--<light|dark>.png`) and a short findings/sign-off note with commit sha
  - [ ] On-device mockup comparison vs `docs/design/mockups/index.html` (plan 3.5 follow-up)

- [ ] **M3. Golden re-baseline hygiene**
  - Commit re-blessed all 60 gallery goldens (file sizes −4 to −9%) on Linux/Flutter 3.47.9; "pixel-neutral" is asserted, not shown.
  - [ ] Re-bless only Phase 3 ids, or attach a zero-delta diff for the other screens
  - [ ] Land golden changes as their own commit stating why they moved

## Minor

- [ ] **m1. Accessibility / text scale**
  - [ ] Replace `FittedBox(scaleDown)` in `ui/shared/chat_screen.dart:784` (date divider) and `:862` (quick-reply chip) with wrapping layout
  - [ ] Add `Semantics(button, label)` to quick-reply chips (`chat_screen.dart:849`) and verify `auth_common.dart:176` (role toggle) and `role_select_screen.dart:193`
  - [ ] Add 2× text-scale tests for `TextOverflow.ellipsis` list rows (`messages_list_screen.dart:305,327,337`; `notifications_screen.dart:221,241`)
  - [ ] Confirm dock unread badge has non-colour signal (count/Semantics) at all sizes
  - [ ] Confirm all tap targets ≥ 44×44 (dock items, icon buttons, chips)

- [ ] **m2. Token discipline (no raw literals in `ui/auth`, `ui/shared`)**
  - [ ] Add `THType` slots for 10.5 / 11 / 13 / 14.5 / 15 and replace `fontSize:` literals (`th_shell.dart:268`, `chat_screen.dart:744,868`, `notifications_screen.dart:223,231,247`, `settings_screen.dart:94,160,205,250,258`, `messages_list_screen.dart:318,339`, `verify_otp_screen.dart:236`)
  - [ ] Add a bubble radius token for `chat_screen.dart:690-693` (18 / 6)
  - [ ] Tokenise `th_shell.dart` one-offs (`width: 56`, `48`, badge `9×9`)
  - [ ] Move splash/onboarding/chat durations and curves to motion tokens (`splash_screen.dart:22-24`, `onboarding_screen.dart:193`, `chat_screen.dart:102`); collapse to zero under reduce-motion
  - [ ] Optionally extend `scripts/check_ui_boundary.py` / add a raw-value grep gate for `fontSize:`, `Radius.circular(n)`, `Duration(`

- [ ] **m3. Remaining stubs (parity with v1, still dead taps)**
  - [ ] Forgot password (`sign_in_screen.dart:95`)
  - [ ] Payment methods, Region, Help Center, Terms (`settings_screen.dart:140,180,219,222`)
  - [ ] Chat Schedule action still opens v1 `ScheduleSheet` (`chat_screen.dart:319`) — port when job-detail screens move (Phase 4)

- [ ] **m4. Sign-in polish**
  - [ ] Replace generic globe icon on "Continue with Google" with the proper mark/asset
  - [ ] Add leading icon to Password field (Email has one) or confirm mockup intent (shot `06.39.15`)

## Nit

- [ ] `ThShell` triggers `Future.microtask(refresh)` from `build()` on each location change (`th_shell.dart` ~L88); prefer a router listener
- [ ] Use `MediaQuery.sizeOf/paddingOf/viewInsetsOf` instead of `.of` (`chat_screen.dart:485-486`, `onboarding_screen.dart:113`)
- [ ] Consider `EdgeInsetsDirectional` (57 non-directional sites) if RTL ever becomes a requirement

## Follow-ups (plan-consistent)

- [ ] Make the import-boundary guard transitive (`ui/shared/chat_screen.dart` → `widgets/schedule_sheet.dart` → `theme/design_tokens.dart`, `FixoNotice`)
- [ ] Confirm in CI that `widgets/schedule_sheet.dart` relative imports (`../../repositories/…`, `../../theme/…`) resolve (could not verify statically)
- [ ] Submit rail (≥1024px), settings, messages_list, signup and designed error/empty states to the D-4 design pass
- [ ] Re-run `flutter analyze`, `flutter test` (flag on, incl. old-screen flow tests), `check_ui_boundary.py`, `build.mjs --check`; record results with commit sha
- [ ] Update `docs/design_system_migration_plan.md` Phase 3 note once B1/M1 are resolved (currently marked done 2026-11-17)

## Confirmed OK (no action)

- 12 Phase 3 ids in `v2Screens`; `app_router.dart` `_pick(id, v1, v2)` keeps v1 fallbacks; paths/`extra`/deep links unchanged
- No changes to `models/`, `repositories/`, `network/`, `viewmodels/`, `utils/`, `views/`, `widgets/`, `theme/`
- Zero `Color(0x…)` / `Colors.*` (except `transparent`) in `ui/auth`, `ui/shared`; `ThScope` on all 11 screens
- Keys preserved (`role_homeowner` / `role_tradie` now in `auth_common.dart`)
- Shell role/tab logic, centre action (homeowner only), unread badge, chat hub send path match v1 behaviour
