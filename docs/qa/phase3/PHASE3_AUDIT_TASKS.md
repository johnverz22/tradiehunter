# Phase 3 Audit — Completion Checklist

Scope: verify Phase 3 work in [`design_system_migration_plan.md`](../../design_system_migration_plan.md) §§3.1–3.5 and §4.0 against the audit findings. Per owner direction, disregard the screenshots cited in the source audit. Defer work assigned to Phase 4 or later and design-pass follow-ups.

**Status: Phase 3 completion criteria verified.** The v2 shell remains enabled. No decision in this checklist rolls the redesigned navigation back to the v1 bottom bar.

## Blocker — B1: shell theme boundary

- [x] `ThScope` wraps only v2 shell chrome; the routed screen remains under the app theme.
- [x] `th_shell.dart` header describes the actual theme boundary.
- [x] Regression coverage mounts the real v1 homeowner dashboard and tradie Jobs list under `ThShell` with provider overrides.
- [x] Home-tab shell goldens cover light and dark.
- [x] Keep `'shell'` enabled in `v2Screens`; the v1 child crash is fixed and covered by the shell tests.

## Major — M1: designed profile

- [x] Rebuild the profile overview to follow its v2 design: avatar/name/email, Personal details, Payments and receipts, Notifications, Dark mode, Help and support, and ghost Sign out.
- [x] Move edit controls into the Personal details view. Read-only values render as values rather than disabled form fields.
- [x] Preserve profile update payloads, edit key, immediate tradie availability save, payout fields and bank validation, Settings navigation, and sign-out behavior. Block/report and device-token behavior remain in their existing public-profile and authentication flows.
- [x] Correct the Phase 3 plan note: `profile` has a v2 design; `settings` and `messages_list` remain no-design compositions.
- [x] Profile widget coverage exercises homeowner/tradie details and the light/dark modes.

## Phase 3 quality fixes

- [x] Match the mockup's editable field treatment: `THTextField` keeps its small-caps label inside the outlined field; 10.5 px label type and control radius match `.fld`.
- [x] Replace chat date-divider and quick-reply `FittedBox` scaling with wrapping. Quick replies expose button semantics and labels.
- [x] Preserve and verify semantics on auth role controls. Add 2× text-scale coverage for inbox and notification ellipsis rows.
- [x] Keep unread counts visible in the dock and exposed in its semantics; navigation buttons and icon actions meet the shared minimum target size.
- [x] Replace the audited raw type, chat-bubble radius, rail-size, and unread-dot values with design tokens. Token additions are generated from `docs/design/tokens/tokens.json`.
- [x] Move splash, onboarding, and chat motion values to motion tokens and respect reduced-motion settings.
- [x] Add the password leading lock icon shown in the sign-in design. Keep the Google globe icon, which matches the design reference.

## Deferred or excluded by scope

- Phase 3.5 on-device mockup comparison is a follow-up in the migration plan; it is not part of this code verification. The source audit screenshots were disregarded as requested.
- Historical re-baselining of the gallery goldens is outside this Phase 3 fix set. The only goldens added here are the two shell Home-tab regression images; existing gallery goldens were left alone.
- Chat Schedule still opens the v1 sheet until job-detail screens move in Phase 4.
- Forgot-password has no backend endpoint and remains the existing placeholder. Settings has no v2 design; its feature stubs and the wide rail remain D-4 design-pass items, not Phase 3 completion blockers.
- Optional router-listener cleanup, RTL conversion, and transitive import-boundary expansion are not required by Phase 3 §§3.1–3.5.

## Verification

- Flutter SDK: 3.47.5 (Dart 3.13.4).
- `flutter analyze`: pass, no issues.
- Phase 3 suites (`phase3_auth_test.dart`, `phase3_shared_test.dart`, `phase3_shell_test.dart`, `ui_flags_test.dart`): pass, 65 tests.
- `python3 scripts/check_ui_boundary.py`: pass.
- `node docs/design/tools/build.mjs --check`: pass (30 screens; contrast 38/38).
- Full `flutter test`: 832 passed; 60 gallery golden comparisons failed. The checked-in gallery baselines were previously re-blessed on Flutter 3.47.9 per the source audit; this verification ran on 3.47.5. No gallery baselines were re-blessed in this Phase 3 fix set.
