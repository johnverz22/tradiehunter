# Phase 6 → `main` integration guide

Branch: `phase6-v1-cutover`. This branch makes v2 the only UI and deletes v1.
**It has never been compiled** (the authoring sandbox had no Flutter SDK), so step 2 is mandatory.

## 0. What changed (one paragraph)

`lib/views/`, `lib/widgets/`, `lib/theme/`, `ui_flags.dart`, all `UI_V2` plumbing, the v1 fonts and `google_fonts`
are gone. The router, job-detail routers and tradie profile route are v2-only. `ThMatchingScreen`
(`lib/ui/homeowner/ho_matching_screen.dart`) replaces the v1 matching controller. `ThRatingSheet` / `ThScheduleSheet`
replace the v1 sheets. `FixoNotice*` is now `THNotice*`. `MaterialApp` runs on `THTheme`.

## 1. Sync the branch with `main`

```sh
git fetch origin
git checkout phase6-v1-cutover
git merge origin/main          # prefer merge over rebase: history is already pushed
```

Expected conflict zones (resolve toward **deleting v1**, then port the intent into `lib/ui/**`):

| Conflict | Resolution |
|---|---|
| `main` edited a file under `lib/views/`, `lib/widgets/` or `lib/theme/` (modify/delete) | Keep the deletion. Re-apply the behavioural change in the matching `lib/ui/` screen (`views/jobs/post_job_screen.dart` → `ui/homeowner/ho_post_job_screen.dart`, `views/payment/*` → `ui/homeowner/ho_payment_*`, `views/tradie/*` → `ui/tradie/tr_*`, `views/chat/*` → `ui/shared/chat_screen.dart`, …). |
| `main` added a new `import '…/views/…'` or `Fixo*` widget | Replace with the `TH*` equivalent: `FixoPrimaryButton`→`THButton(kind: accent)`, `FixoAppBar`→`THAppBar`, `FixoCard`→`THCard`, `FixoNotice`→`THNotice`, `StickyActionBar`→`THStickyBar`. |
| `pubspec.yaml` / `pubspec.lock` | Take `main`'s dependency changes, then re-delete `google_fonts` and the `assets/fonts/` + v1 `fonts:` entries; run `flutter pub get`. |
| `.github/workflows/ci.yml`, `scripts/run-e2e.sh`, `dev.sh` | Keep this branch's versions (no `UI_V2`, no boundary guard) and re-add any unrelated `main` additions. |

Quick check that nothing v1 crept back in after the merge:

```sh
cd mobile
grep -rnE "Fixo[A-Z]|DesignTokens|UI_V2|isV2Screen|package:fixo/(views|widgets|theme)/|'\.\./(views|widgets|theme)/" lib test integration_test
```
Only `lib/ui/gallery` comments may remain.

## 2. Make it compile (required)

```sh
cd mobile
flutter pub get
dart format lib test integration_test
flutter analyze --fatal-infos
```

Likely first errors, in order of probability:
1. **Unused imports / variables** left by the mechanical edits (`ref.watch(themeModeProvider)` in screens that no longer pass `themeMode`).
2. **`THTheme.light` / `.dark`** are used as getters/fields; if they are methods in your tree, add `()`.
3. **Ported tests** referencing keys or copy that differ between v1 and v2 (`matching_flow_test`, `address_resolution_test`, `profile_truthfulness_test`).
4. `th_tokens.dart` gained `THDurations.toggle/addressDebounce/sheetDelay/sheetDelayLong/notice*` — confirm no duplicate declarations.

## 3. Test

```sh
flutter test                                  # unit + widget
flutter test --update-goldens test/ui         # ONLY after eyeballing every diff
node ../docs/design/mobile/tools/build.mjs --check
```

Then, with the stack up (`docker compose up -d`) and simulators booted:

```sh
export E2E_DEVICE=<id>; export E2E_TRADIE_DEVICE=<id2>
scripts/run-e2e.sh C0 --seed
```

## 4. Owner QA checklist (deferred by you; run before merging)

- Homeowner: post job → quick match radar → accept → booked detail; direct request → request-sent screen (accept / decline / expiry / cancel); payment; review sheet; reschedule via chat schedule sheet.
- Tradie: home, jobs list (wide layout ≥ 744 px), offer countdown, check-in/out, extra-cost page, earnings.
- Light **and** dark, text scale 1.0 and 2.0, iPhone SE width.
- Push notification tap → notification centre → deep link.
- 404 route (`/nope`) shows the v2 not-found state.

## 5. Known gaps to decide on

- **Draft jobs** show a read-only fallback (v1 had "Edit job"). Add a ThPostJob edit mode if drafts are user-visible.
- **`ThScope`** still wraps ~60 screens and many test hosts. Redundant now that `MaterialApp` uses `THTheme`; remove in a follow-up PR with the compiler.
- **Dead code:** `TrRequestExtraCostSheet` and `TrCheckOutSheet` in `ui/tradie/tr_job_parts.dart` (pages replaced them).
- **Tests deleted** with v1 (e.g. v1 dashboards, tradie job detail, onboarding wizard, payment/dispute screens). v2 equivalents live in `test/ui/phase*_test.dart`; add coverage where a deleted test had no v2 twin.
- **Hardcode one-offs** listed in `mobile/HARDCODED_AUDIT.md`.

## 6. Merge

```sh
git push origin phase6-v1-cutover
# open PR → main; require: CI green (backend, mobile format+analyze+test, design gate, web)
# squash is fine; keep the PR description's list from §0 and §5
```

After merge: record the date in `docs/MILESTONES.md` / `docs/DESIGN.md`, delete the branch, and revoke any PAT that was shared during the migration.

## Rollback

`git revert -m 1 <merge-commit>` restores v1 wholesale (nothing else depends on the deleted files except the migrated `lib/ui` code, which is unaffected).
