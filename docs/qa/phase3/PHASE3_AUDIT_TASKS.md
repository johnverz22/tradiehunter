# Phase 3 Audit — Task Checklist

Source: audit of `feat(mobile): phase 3` (`9e9011c`) and QA screenshots (`0bc055a`) against
`docs/design_system_migration_plan.md` §4.0, §4.2 and the Phase 3 "done when" criteria.

**Verdict: FAIL** (functional blocker B1 + widget-fidelity findings W1–W12 below) — v1 Home / Jobs screens crash inside the v2 shell (B1). Do not ship with `'shell'` in `v2Screens` until B1 is closed.

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

- [x] **m4. (withdrawn / superseded)** The globe icon on "Continue with Google" matches the generated reference (`docs/design/flutter/screens/sign_in_screen.dart` uses `Icons.public_rounded`). The missing password lock icon is tracked as **W3** below.

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

---

# Widget fidelity audit — Phase 2 widgets and Phase 3 usage vs `docs/design/mockups/index.html`

Method: compared the mockup's generated CSS (`.fld`, `.btn`, `.ibtn`, `.otp`, `.pl`, `.seg`, `.sw`, `.bub`, `.dock`, `.lr`, `.s-*` type classes) and screen markup
(Sign in, Verify email, Chat, Notifications, Profile & settings, Choose your role) with `mobile/lib/ui/design/th_widgets.dart`,
`th_tokens.dart`, the Phase 3 screens, and the QA screenshots (measured: 402pt-wide screenshot ≈ 1.79 px/pt).
Mockup has **no** screens for signup, messages_list or a separate settings page — for those, the rule is "compose from `.fld` / `.btn` / `.lr` / `.card`", so the same widget findings apply.

## Spec comparison (what matches, what does not)

| Widget / token | Mockup spec | Flutter | Result |
|---|---|---|---|
| Type scale (`THType`) | display 28/600, h1 24/600, h2 20/600, title 16/600, button 15/600, money 17, moneyLg 34, label 11 ls 1.2, body 15 (Source Sans 3), meta 13 | identical values in `th_tokens.dart:72-143` | ✅ match |
| `THButton` | 54px (sm 44), r16 (sm r14), 15px (sm 14) Lexend 600, secondary border 1.5px | same (`th_widgets.dart:136-235`); screenshot sign-in button ≈ 54pt | ✅ match (dark `danger` fg uses `onAccent` #1A1005 vs #1A0505 — nit) |
| `THIconButton` | 44×44, r14, **primary r16**, secondary border **1.5px** | r14 for both kinds, border **1px** (`:249-262`) | ⚠️ minor (W11) |
| `THField` (display-only) | surface, 1px line, r16, pad 10/14, min 56, **label 10.5/600 ls .6 INSIDE the border above the value** | same (`:563-637`) | ✅ match |
| **`THTextField`** (Phase 3, real input) | must look like `.fld` | label rendered **above/outside** the border (`:726-738`), pad 14/14 + `isDense` | ❌ **W1/W2** |
| `THOtp` | 48×60, r14, border 1.5, 24px Lexend 600 | same | ✅ |
| `THPills` / `THSegmented` | pill pad 9/14, 13px/500; seg pad 10/4, r12 in r16 | same | ✅ |
| `THSwitch` | 52×30, thumb 24, on = success | same widget exists but Settings uses Material `SwitchListTile` | ❌ W8 |
| `THBubble` | r18/6, pad 10/14, max 80% | same | ✅ |
| `THDock` | 68px, r30, label 10.5/500 (selected = colour only), FAB 56 r20 + 4px paper border | same | ✅ (rail overrides weight, see W12) |

## Findings

### Major

- [ ] **W1. `THTextField` puts the label outside the border; mockup puts it inside (`.fld small`)**
  - Mockup: `<div class="fld"><small>EMAIL</small><div class="fv">…</div></div>` — one bordered box containing the 10.5px label and the value.
  - Built: `THTextField` (`mobile/lib/ui/design/th_widgets.dart:726-738`) renders `Text(label)` in a `Column` *above* a bordered `TextFormField`. The doc comment says it "mirrors `THField`" — it does not. Visible on every input: `…06.39.15.png` (sign-in), `…06.39.22.png` (signup), `…06.38.59.png` / `…06.42.11.png` (profile).
  - Introduced in Phase 3 (`9e9011c`); no test or golden references it. Gallery goldens only render display-only `THField`, so the gap passed CI.
  - Fix: rebuild `THTextField` as one `Container` (surface, 1px `line`, `Radii.control`, pad 10/14, `minHeight: Sizes.input`) holding the label `Text` and a borderless `TextFormField` (`InputBorder.none`, `isCollapsed: true`, `contentPadding: zero`); keep prefix/suffix inside the same row (`Row`: icon 18 → field → trailing). Drive focus colour (`textBrand` 1.5px) and error (`danger`) via a `Focus`/`FocusNode` listener and `FormFieldState`; render the error message *below* the box in `THType.meta` danger.
  - Add a golden/geometry test comparing `THTextField` to `THField` (same size and label position) and a widget test for focus/error/disabled/obscure.

- [ ] **W2. Field height is below the mockup minimum**
  - Mockup `.fld`: `min-height: 56px`; with an inside label the box is ≈ 58pt.
  - Built: ≈ 49pt measured (sign-in email 553→641px; profile First Name 590→677px). `contentPadding` 14/14 + `isDense` (`:741-744`) never reaches `Sizes.input` (56).
  - Fix: covered by the W1 rebuild (`minHeight: Sizes.input`). Add `expect(tester.getSize(find.byType(THTextField)).height, greaterThanOrEqualTo(Sizes.input))`.

- [ ] **W3. Label copy/casing and missing leading icon on sign-in**
  - Mockup/reference: `EMAIL`, `PASSWORD`, `FULL NAME`… (upper-case, 10.5px) with **mail** icon on Email and **lock** icon on Password (`docs/design/flutter/screens/sign_in_screen.dart`).
  - Built: `'Email'`, `'Password'`, `'Full name'`, `'First Name'`, `'Phone Number'`, `'Bank Account Name'` etc. in mixed/Title Case (`sign_in_screen.dart:143,162`; `sign_up_screen.dart:184,198,217`; `profile_screen.dart:279-382`). Password field has **no leading lock icon** (`sign_in_screen.dart:160-175`; `…06.39.15.png`).
  - Fix: do upper-casing inside the widget (`label.toUpperCase()`), so callers pass natural text; add `icon: Icons.lock_outline_rounded` to the password fields (sign-in, signup); keep the visibility toggle as trailing.

- [ ] **W4. Heading weight overridden to 700 (mockup is 600)**
  - `THType.h1/h2` are w600 by token, but screens force w700: `sign_in_screen.dart:129`, `verify_otp_screen.dart:155`, `sign_up_screen.dart:162`, `role_select_screen.dart:121`, `onboarding_screen.dart:131`. Visibly heavier "Welcome back" / "Create your account" in the screenshots.
  - Fix: delete the `fontWeight: FontWeight.w700` overrides; use `THText(..., style: THTextStyle.h1)` / `THType.h1` as-is.

- [ ] **W5. Chat composer does not match the mockup**
  - Mockup (`.sticky`): `.fld.phd` message field (r16, min 56, no label) + `.ibtn.k-primary` send (44×44, r16, **brand** fill) on a glass bar with top border.
  - Built (`chat_screen.dart:~880-935`): pill field (`Radii.pill`, padding 20), **accent circle** send button 56×56 with shadow, plus quick-reply chips with `FittedBox`.
  - Fix: use the W1 field (no label, hint "Message") and `THIconButton(kind: primary, icon: send)` inside `THStickyBar`; keep the attach button as secondary `THIconButton`. If a larger send target is wanted for accessibility, record it as a deliberate deviation in the plan (the mockup's 44pt is below the guide's own `Sizes.tapMin` 48 — raise the token, not just this screen).

- [ ] **W6. Notification rows differ from `.lr` rows**
  - Mockup: `.lr` card (surface, 1px line, r20, pad 12) with a **44×44 rounded-square (r14)** tinted icon tile, title 15/600 (`s-title` at 15px), meta 13, unread = 9px accent dot on the right.
  - Built (`notifications_screen.dart:~170-262`): r18 container pad 16, **circular** icon tile 44 with 24px icon, title **14.5**, time **11**, extra category line **11**, whole row tinted `tintBrand` when unread, 10px dot.
  - Fix: use `THListRow` (or the same `.lr` metrics): rounded-square `tb sm` tile r14, title 15, meta 13, drop the 14.5/11 literals; keep the dot, drop the whole-row tint (or document it).

### Minor

- [ ] **W7. Auth screens use 24px side gutters and 16px vertical gap; mockup uses 20 / 12**
  - Mockup `.col.body{gap:12px;padding:6px 20px 0}`. Auth screens: `ThAuthScroll(padding: fromLTRB(s6, s9, s6, s6))` and `Column(spacing: Space.s4)` (`sign_in_screen.dart:106-117`) → measured left edge 24pt on sign-in/signup vs 20pt on profile/messages (`…06.39.15.png` vs `…06.38.59.png`). Inconsistent inside v2 itself.
  - Fix: use `Sizes.gutter` (20) horizontally and `Space.s3` (12) as the column gap; top spacing per mockup (12/24 spacers, not `s9`).

- [ ] **W8. Settings does not use the v2 rows/switch, and the mockup has no separate "Settings" page**
  - Mockup "Profile & settings" is one screen: avatar + name + email, a card of `.lr` rows with 44pt tinted icon tiles (Personal details, Payments and receipts, Notifications), a **Dark mode switch** (`.sw`, 52×30, green on), Help and support, and a **ghost "Sign out"**.
  - Built (`…06.39.04.png`, `settings_screen.dart`): plain `ListTile`s without icon tiles, Material `SwitchListTile` (brand track, not `THSwitch`), a "Theme › System" sheet instead of a dark-mode switch, and a **solid red "Log Out"** (`THButtonKind.danger`) instead of ghost "Sign out".
  - Fix: build rows from `THListRow` + `THSwitch`; either add a Dark-mode `THSwitch` bound to `themeModeProvider` or log the Theme-sheet as a deliberate deviation; use `THButton(kind: ghost, label: 'Sign out')` (confirm the destructive style with design).

- [ ] **W9. Sign-in secondary copy and tertiary-text sizes**
  - "Forgot password?" is 15px (`THType.button`, `sign_in_screen.dart:196-200`); mockup is `s-title` at **13px**. "Don't have an account?" (8px gap) vs mockup "New here?" (4px gap); "Create account" 15px ✓.
  - Fix: `THType.title.copyWith(fontSize: 13)` via a token (see W10); keep the 48pt tap area using padding, not font size; align copy with the mockup or note the deviation.

- [ ] **W10. Off-scale font sizes in Phase 3 screens (mockup sizes only 10.5/11/11.5/13/14/14.5/15/16…, but via tokens)**
  - `fontSize:` literals: 10.5 (`th_shell.dart:268`, `verify_otp_screen.dart:236`), 11 (`chat_screen.dart:744`, `notifications_screen.dart:231,247`, `messages_list_screen.dart:318`, `settings_screen.dart:250,258`), 13 (`chat_screen.dart:868`, `messages_list_screen.dart:339`), 14.5 (`notifications_screen.dart:223`), 15 (`settings_screen.dart:94,160,205`).
  - Fix: add semantic slots to `THType` (e.g. `caption` 11, `fieldLabel` 10.5/ls .6, `rowTitle` 15, `chip` 13) generated from `tokens.json` (then `node docs/design/tools/build.mjs`), and replace the literals; add a grep gate for `fontSize:` in `lib/ui/{auth,shared}`.

- [ ] **W11. `THIconButton` border/radius**
  - Mockup `.ibtn.k-secondary` has `border:1.5px solid var(--line)`; `.ibtn.k-primary` has radius 16 (others 14). Built: 1px border, r14 for both (`th_widgets.dart:249-262`).
  - Fix: `side: BorderSide(color: c.line, width: 1.5)`; `radius = primary ? Radii.control : Radii.control - 2`; refresh gallery goldens.

- [ ] **W12. Shell rail label weight and sizes**
  - `th_shell.dart:268-270` sets 10.5px and **w700 when selected**; the mockup/`THDock` keep 10.5/500 and change colour only (bold on select shifts the label width). Rail is a needs-design item, but should reuse the dock's label style.
  - Fix: reuse `THDock`'s label style; selection = colour + pill background only.

## Test and process gaps behind these findings

- [ ] No test or golden covers `THTextField` (introduced in Phase 3); gallery goldens exercise only display-only `THField`, so Phase 3 screens can diverge from the mockup without a red build.
- [ ] Add a "mockup parity" test: for each `.fld`/`.btn`/`.ibtn`/`.lr` instance, assert measured size/radius/label position against `tokens.json`-derived constants (`Sizes.input`, `Sizes.button`, `Radii.control`).
- [ ] Add Phase 3 screen goldens (light + dark) for sign-in, signup, verify, profile, chat composer, notifications, settings, so the mockup comparison is reproducible rather than visual-only.
- [ ] Extend the design gate (or `scripts/check_ui_boundary.py`) with a grep for `fontWeight: FontWeight.w7`, raw `fontSize:` and `FittedBox` in `lib/ui/{auth,shared}`.
- [ ] Re-capture QA screenshots after W1–W6 so label-inside fields, composer and notification rows can be checked on device.
