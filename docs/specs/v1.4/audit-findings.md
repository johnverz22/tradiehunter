# Audit Findings — v1.4

**Version:** 1.4  
**Date:** 2026-10-26  
**Status:** Draft

Issue IDs are stable across this version. Do not renumber.

Priority legend: **P1** = must fix before release · **P2** = fix in v1.4 sprint · **P3** = fix or formally defer

---

## Table of Contents

- [Functional Defects](#functional-defects)
- [Test Infrastructure](#test-infrastructure)
- [Branding](#branding)
- [UI / UX](#ui--ux)

---

## Functional Defects

---

### TH-FUNC-001 · P1 · Tradie pending offer is invisible across the entire app

**Summary:** A tradie who has received a job offer cannot see it anywhere in the application — not on their dashboard, not in their job list, and not on the job detail screen. The tradie is effectively locked out of the offer workflow.

**Root cause:** Confirmed (multi-layer).

**Evidence:**
- Test run: issue 9 ("Tradie sees incoming request" — 0 requests visible after homeowner posts job)
- Screenshot: `tradie/03_request_detail.png` — shows "Job not found" error on the request detail screen
- Source: `backend/Repositories/JobRepository.cs` — `GetForUserAsync` filters `MatchedTradieId == userId`; a tradie with a pending offer has `OfferedTradieId == userId`, which this query never returns
- Source: `mobile/lib/features/tradie/views/tradie_dashboard_view.dart:925` — `_IncomingRequestsSection` only renders jobs with `status == 'Requested'`, which is the homeowner-side status; the tradie offer object has a different status path
- Source: `mobile/lib/features/tradie/views/tradie_dashboard_view.dart` (SignalR subscription) — dashboard subscribes to `onNewJobMatch` but `MatchingService` emits `OfferLifecycleEvent` to the tradie's user group; only `request_detail_screen` listens to `onOfferLifecycle`, which is never reached because the route is inaccessible
- Source: `backend/Controllers/JobsController.cs` — `GET /api/jobs/{id}` denies access unless `MatchedTradieId == userId`, so even deep-linking to request detail returns 403/404

**Affected screens:** Tradie dashboard, tradie job list, tradie request detail  
**Affected user type:** Tradie  
**Affected source files:**
- `backend/Repositories/JobRepository.cs`
- `backend/Controllers/JobsController.cs`
- `backend/Services/MatchingService.cs`
- `mobile/lib/features/tradie/views/tradie_dashboard_view.dart`
- `mobile/lib/features/tradie/screens/request_detail_screen.dart`

**Regression risks:** Changes to `GetForUserAsync` affect all job-list queries; widen carefully with explicit status filters. Changes to the GET endpoint auth check must not expose jobs to unrelated tradies.

---

### TH-FUNC-002 · P1 · Homeowner cannot navigate back to matching screen for in-flight jobs

**Summary:** Once a homeowner leaves the post-job flow, there is no way to return to the matching screen to see which tradies have been contacted. The dashboard navigation routes a `Requested`-status job to chat instead.

**Root cause:** Confirmed.

**Evidence:**
- Test run: issue 10 ("Homeowner can revisit matching progress" — route not found)
- Source: `mobile/lib/core/navigation/job_navigation.dart:28` — `openHomeownerJob()` switch statement routes `Requested` status to `/chat/:id` (the default/fallback case). No case handles `Requested` → `/jobs/:id/matching`
- Source: `mobile/lib/features/homeowner/screens/post_job_screen.dart:374` — the only `go('/jobs/:id/matching')` call is in the post-job completion handler; no other navigation path exists

**Affected screens:** Homeowner dashboard job cards, homeowner job list  
**Affected user type:** Homeowner  
**Affected source files:**
- `mobile/lib/core/navigation/job_navigation.dart`

**Regression risks:** Changing the `Requested` case routing may affect other callers of `openHomeownerJob()`. Audit all call sites before changing.

---

### TH-FUNC-003 · P2 · `appName` from backend config never reaches Flutter — fallback always used

**Summary:** The Flutter app is designed to receive the app name from backend configuration so it can be centrally controlled. Due to a JSON key path mismatch, the Flutter app always falls back to the hardcoded string `'TradieFixo'`.

**Root cause:** Confirmed.

**Evidence:**
- Source: `mobile/lib/features/shared/viewmodels/locale_viewmodel.dart` — reads `response['appName']`
- Source: `backend/Controllers/ConfigController.cs` — returns `{ "Locale": {...}, "Brand": { "AppName": "...", "SupportEmail": "..." } }`
- The correct key path is `response['brand']['appName']` (camelCase after JSON serialization) or `response['Brand']['AppName']` (PascalCase, depending on `JsonSerializerOptions`). Neither matches the current `response['appName']` read.
- Effect: `main.dart:185` fallback `'TradieFixo'` is always active regardless of `appsettings.json Brand.AppName`

**Affected screens:** Any screen that displays the dynamically-sourced app name  
**Affected user type:** All  
**Affected source files:**
- `mobile/lib/features/shared/viewmodels/locale_viewmodel.dart`
- `backend/Controllers/ConfigController.cs` (reference only; no change required if key path fix is in Flutter)

**Note:** This defect means that fixing `appsettings.json` alone (TH-BRAND-003) will NOT propagate to Flutter until this key path is also fixed. Both must be fixed together for end-to-end rebrand via config.

---

### TH-FUNC-004 · P2 · `go()` navigation produces stale screen data on same-pattern routes

**Summary:** When navigating to a second job detail screen using `appRouter.go()` after previously visiting another job detail screen, the screen renders the data from the first visit. The `initState` lifecycle method does not re-execute because go_router reuses the widget state.

**Root cause:** Confirmed (go_router behavior when route pattern matches but path param changes; `go()` vs `push()` difference).

**Evidence:**
- Test run: screenshot sweep note referencing stale data on sequential detail navigations
- Source: standard go_router behavior — `go()` does not push a new entry; if the widget is already in the tree at that route shell, `initState` is not called again
- Affected in deep-link scenarios and programmatic navigation that uses `go()` for detail routes

**Affected screens:** Job detail (homeowner), job detail (tradie), potentially tradie request detail  
**Affected user type:** Homeowner, Tradie  
**Affected source files:**
- `mobile/lib/core/navigation/job_navigation.dart`
- Relevant screen `initState` / provider watch implementations for job detail screens

**Regression risks:** Switching to `push()` changes back-stack behavior; verify that back navigation does not leave unwanted entries.

---

### TH-FUNC-005 · P2 · Active Jobs badge always displays "N Booked" regardless of actual job statuses

**Summary:** The badge on the tradie dashboard Active Jobs section always reads "N Booked" even when the section contains jobs with statuses InProgress, AwaitingPayment, Completed, or Cancelled.

**Root cause:** Confirmed (hardcoded string).

**Evidence:**
- Screenshot: `tradie/00_post_login.png` — badge shows "3 Booked" but the section visually contains jobs with InProgress and AwaitingPayment indicators
- Source: `mobile/lib/features/tradie/views/tradie_dashboard_view.dart:925` — `'${jobs.length} Booked'` hardcoded

**Affected screens:** Tradie dashboard  
**Affected user type:** Tradie  
**Affected source files:**
- `mobile/lib/features/tradie/views/tradie_dashboard_view.dart`

**Regression risks:** Low. String-only change. Verify that any automated test asserting on "Booked" badge text is updated.

---

### TH-FUNC-006 · P2 · Incoming Request Decline button is a no-op

**Summary:** The Decline button rendered on incoming request cards on the tradie dashboard has an empty callback. Tapping it does nothing. It is unclear whether this is an intentional deferral or an accidental omission.

**Root cause:** Confirmed (empty callback). Intentionality unknown.

**Evidence:**
- Source: `mobile/lib/features/tradie/views/tradie_dashboard_view.dart:676` — `onDecline: () {}` (empty lambda)

**Affected screens:** Tradie dashboard — incoming requests section  
**Affected user type:** Tradie  
**Affected source files:**
- `mobile/lib/features/tradie/views/tradie_dashboard_view.dart`

**Action required:** The implementing developer must determine whether decline is intentionally deferred (add a TODO comment and a disabled-state visual) or should be implemented (wire to the existing decline API endpoint). Either outcome must be documented and the empty callback must not remain silently.

---

### TH-FUNC-007 · P3 · ProfileService auto-seeder conflicts with `SeedNZServices` migration

**Summary:** The `ProfileService` runtime seeder inserts service records (Plumber, Electrician) with the same primary key values as records already inserted by the `SeedNZServices` EF Core migration. This produces a `duplicate key violation on PK_Services` error during startup on a freshly-migrated database.

**Root cause:** Confirmed.

**Evidence:**
- Test run: issue 1 — startup error log `duplicate key value violates unique constraint "PK_Services"`
- Source: `backend/Services/ProfileService.cs:302` — inserts services without checking for prior existence via migration

**Affected area:** Backend startup / database seeding  
**Affected user type:** Development/test environment only (production database would already have records)  
**Affected source files:**
- `backend/Services/ProfileService.cs`

**Fix pattern:** Guard the seeder with an existence check (`if (!await _db.Services.AnyAsync(s => s.Id == id))`), or remove the runtime seeder entirely in favour of the migration seed.

---

### TH-FUNC-008 · P3 · Render-probe batch date format is not NZ locale

**Summary:** The admin web render-probe for `PayoutBatches` formats dates using the browser's default locale, producing "Sep 21, 2026" instead of the expected NZ format "21 Sept 2026". Money values are correctly pinned to `en-NZ` but the date formatting is not.

**Root cause:** Confirmed.

**Evidence:**
- Test run: issues 2 and 3 — render-probe assertions fail on date format ("Sep 21, 2026" vs "21 Sept")
- Source: `web/src/components/PayoutBatches/format.ts` — `toLocaleDateString(undefined, …)` uses the runtime locale instead of a pinned `'en-NZ'` locale

**Affected area:** Admin web — payout batch list  
**Affected user type:** Admin  
**Affected source files:**
- `web/src/components/PayoutBatches/format.ts`

---

### TH-FUNC-009 · P3 · `ListTile` inside `DecoratedBox` triggers debug-mode ink splash assertion

**Summary:** On the homeowner public profile screen, a `ListTile` is placed directly inside a `DecoratedBox`. Flutter's debug mode asserts that ink splashes from `ListTile` are hidden because there is no `Material` ancestor. This does not crash in release mode but produces assertion errors in debug and test runs.

**Root cause:** Confirmed.

**Evidence:**
- Test run: last line — `FlutterError: Cannot render ink feature for a ListTile that does not have a Material ancestor`
- Screenshot: `homeowner/16_homeowner_profile.png` — the profile tiles section corresponds to the code location
- Source: `mobile/lib/features/homeowner/screens/public_profile_screen.dart` — `ListTile` inside `DecoratedBox` without `Material` wrapper

**Affected screens:** Homeowner public profile (tradie public profile view from homeowner perspective)  
**Affected user type:** Homeowner  
**Affected source files:**
- `mobile/lib/features/homeowner/screens/public_profile_screen.dart`

**Fix:** Wrap `ListTile` (or its parent) with a `Material` widget. Ensure `color: Colors.transparent` if the `DecoratedBox` provides the background.

---

## Test Infrastructure

---

### TH-TEST-001 · P1 · `gotoLogin` integration helper fails after tests leave app on non-shell routes

**Summary:** The shared `gotoLogin()` helper used to reset the app state between integration tests does not handle the case where a previous test left the app navigated to a non-shell route (e.g., `/chat/:id`, `/tradie/jobs/:id`, `/jobs/:id/detail`, `/jobs/:id/matching`). When the next test calls `gotoLogin()`, the router still holds the previous route; the helper's state-detection logic does not recognize the state and fails to navigate to `/auth`. This cascading failure accounts for the majority (approximately 8) of the integration test failures in the recorded test run.

**Root cause:** Confirmed.

**Evidence:**
- Test run: issue 8 — "gotoLogin: unrecognized app state" logged before 8 consecutive test failures
- Source: `mobile/integration_test/helpers/e2e_helpers.dart` — `gotoLogin()` handles dashboard, onboarding, and verify-email states only; all other route states fall through without navigation

**Affected area:** Integration test infrastructure  
**Affected user type:** N/A (test infra)  
**Affected source files:**
- `mobile/integration_test/helpers/e2e_helpers.dart`

**Fix:** In the unrecognized-state branch: clear `flutter_secure_storage`, then call `appRouter.go('/auth')`. Add an assertion that the login screen is visible before returning from `gotoLogin()`.

---

### TH-TEST-002 · P2 · Multiple stale finders and timing issues in integration tests

**Summary:** Several integration tests use finders or timing budgets that do not match the current application rendering. These cause intermittent or consistent test failures independent of application correctness.

**Root cause:** Confirmed (test code out of sync with app code).

**Evidence:**
- Test run: issues 11, 12, 13, 14

**Sub-issues:**

| Sub-ID | Test run ref | Problem | Current code | Actual rendered text |
|---|---|---|---|---|
| TH-TEST-002a | Issue 11 | Tradie "Accept" finder never matches | `find.text('Accept')` | "Review & Accept" / "Accept Job" |
| TH-TEST-002b | Issue 13 | `find.byType(Card)` never matches job cards | `find.byType(Card)` | `ModernJobCard` is `Container`-based |
| TH-TEST-002c | Issue 14 | `findsOneWidget` on "fee" text matches 2 widgets | `findsOneWidget` | Cancellation bottom sheet shows fee text twice |
| TH-TEST-002d | Issue 12 | Cross-persona test times out | 20-second poll budget | Re-login + tradie load takes ~50 seconds |

**Affected area:** Integration tests  
**Affected user type:** N/A (test infra)  
**Affected source files:**
- `mobile/integration_test/` (multiple test files — identify by grep for `find.text('Accept')`, `find.byType(Card)`, `findsOneWidget`, timing constants)

---

## Branding

---

### TH-BRAND-001 · P1 · `FixoWordmark` widget hardcodes "Fixo" — affects all header wordmarks

**Summary:** The shared `FixoWordmark` widget, which renders the brand name in the two-tone style (dark first word, amber second word), hardcodes the text "Fixo" as the amber portion. All screens that use this widget will display "TradieFixo" until the widget is updated. The splash screen uses its own inline `TextSpan` (not the widget) and must be updated separately.

**Root cause:** Confirmed.

**Evidence:**
- Source: `mobile/lib/core/widgets/fixo_buttons.dart:508–511` — `TextSpan(text: 'Tradie')`, `TextSpan(text: 'Fixo')`
- Screenshots: `shared/01_splash.png`, `shared/02_onboarding.png`, `shared/03_login.png`, `shared/04_signup.png`, `homeowner/01_dashboard.png`, `tradie/00_post_login.png` — all show "TradieFixo" wordmark

**Affected screens:** Onboarding, login, signup, homeowner dashboard header, tradie dashboard header  
**Affected user type:** All  
**Affected source files:**
- `mobile/lib/core/widgets/fixo_buttons.dart` (FixoWordmark widget)

**Required change:** Change `TextSpan(text: 'Fixo')` to `TextSpan(text: 'Hunter')`. Preserve existing `TextStyle` (amber color, font weight). Do not change the widget class name `FixoWordmark` — it is an internal identifier.

---

### TH-BRAND-002 · P1 · Hardcoded "TradieFixo" strings scattered across Flutter source

**Summary:** Multiple Flutter source files contain hardcoded user-facing strings with the old brand name. These are not served from a central config and must each be updated individually.

**Root cause:** Confirmed.

**Evidence:**

| Location | Line(s) | Current string | User-facing? |
|---|---|---|---|
| `mobile/lib/features/shared/screens/splash_screen.dart` | 89–92 | Direct `TextSpan`: `'Tradie'` + `'Fixo'` (inline, not via `FixoWordmark`) | Yes |
| `mobile/lib/features/shared/screens/role_select_screen.dart` | 61 | "How will you be using TradieFixo?" | Yes |
| `mobile/lib/main.dart` | 185 | Fallback `appName: 'TradieFixo'` | Yes (fallback) |
| `mobile/lib/features/shared/screens/settings_screen.dart` | 186, 192 | Fallback `'TradieFixo v1.0.0'` | Yes (fallback) |
| `mobile/lib/features/homeowner/screens/signup_screen.dart` | 9 | Docstring only — `// TradieFixo signup` | No — do not change |

**Affected screens:** Splash, role-select, settings (fallback), anywhere appName fallback is displayed  
**Affected user type:** All  

---

### TH-BRAND-003 · P1 · Backend configuration retains "TradieFixo" in all brand strings

**Summary:** The backend's brand configuration — which is the intended source of truth for the app name in the dynamic config API — still uses the old brand name throughout. Because TH-FUNC-003 also prevents this config from reaching Flutter, both issues must be resolved together for the rebrand to be complete via the config path.

**Root cause:** Confirmed.

**Evidence:**

| File | Location | Current value |
|---|---|---|
| `backend/Options/BrandOptions.cs` | Line 5 | `AppName = "TradieFixo"` (default) |
| `backend/appsettings.json` | Line 45 | `"AppName": "TradieFixo"` |
| `backend/appsettings.json` | Line 46 | `"SupportEmail": "support@tradiefixo.nz"` |
| `backend/appsettings.json` | Line 35 | `"LegalEntityName": "TradieFixo Ltd"` |
| `backend/appsettings.json` | Lines 37–38 | `TermsOfServiceUrl` / `PrivacyPolicyUrl` — `tradiefixo.nz` domain |
| `backend/Models/PaymentOptions.cs` | — | `AccountName "TradieFixo Ltd"` |
| `backend/Services/SmtpEmailSender.cs` | Multiple | Email subjects and body text containing "TradieFixo" |

**External dependency note:** The domain `tradiefixo.nz` referenced in ToS/Privacy URLs and `SupportEmail` requires DNS/registrar action outside the codebase. Update the config values to the new domain once it is registered; do not block rebrand on this — substitute a placeholder or leave as TODO.

**Affected area:** Backend config, email notifications  
**Affected user type:** All (email recipients, API consumers)  

---

### TH-BRAND-004 · P2 · Platform metadata (iOS, Android, web) still shows "Fixo" to end users

**Summary:** Platform-level metadata visible to end users (app name on home screen, OS permission strings, web app manifest name) still uses the old "Fixo" name.

**Root cause:** Confirmed.

**Evidence:**

| File | Key | Current value | User-facing? |
|---|---|---|---|
| `mobile/ios/Runner/Info.plist` | `CFBundleName` (line 10) | `"Fixo"` | Yes — shown as app name on iOS home screen |
| `mobile/ios/Runner/Info.plist` | Camera usage (line 71) | `"Fixo needs camera access…"` | Yes — shown in iOS permission dialog |
| `mobile/ios/Runner/Info.plist` | Photo library usage (line 73) | `"Fixo needs photo library…"` | Yes |
| `mobile/ios/Runner/Info.plist` | Microphone usage (line 75) | `"Fixo needs microphone…"` | Yes |
| `mobile/android/app/src/main/AndroidManifest.xml` | `android:label` (line 3) | `"fixo"` | Yes — shown as app name on Android launcher |
| `mobile/web/manifest.json` | `name` | `"fixo"` | Yes — shown as PWA name |
| `mobile/web/manifest.json` | `short_name` | `"fixo"` | Yes |

**Do NOT change:**
- `CFBundleIdentifier` (`fixo`) — internal bundle ID; changing requires Apple developer account update
- `nz.co.fixo.fixo` applicationId — changing breaks Play Store identity
- `CFBundleDisplayName` if it differs from `CFBundleName` — verify before changing

**Affected area:** Platform metadata  
**Affected user type:** All (device home screen, permission dialogs, PWA)  

---

## UI / UX

---

### TH-UI-001 · P2 · Signup screen contains typographical error

**Summary:** The signup screen displays "No accoutn yet? Join!" — a transposition typo in "account" — visible to all new users.

**Root cause:** Confirmed (typo in source string).

**Evidence:**
- Screenshot: `shared/04_signup.png` — clearly visible
- Source: `mobile/lib/features/homeowner/screens/signup_screen.dart:108` — `'No accoutn yet? Join!'`

**Affected screens:** Signup  
**Affected user type:** All (pre-authentication)  
**Affected source files:**
- `mobile/lib/features/homeowner/screens/signup_screen.dart`

**Required change:** Replace `'No accoutn yet? Join!'` with `'Already have an account? Sign in.'` (or equivalent correct phrasing per UX review).

---

### TH-UI-002 · P2 · `JobStepper` "Confirmation" label wraps incorrectly on narrow columns

**Summary:** The "Confirmation" stage label in `JobStepper` wraps mid-word as "Confirmati\non" in the narrow column layout, degrading readability.

**Root cause:** Confirmed.

**Evidence:**
- Screenshot: `homeowner/09_job_detail_inprogress.png` — "Confirmati on" visible as mid-word wrap
- Screenshot: `homeowner/01_dashboard.png` — same symptom on dashboard job card stepper
- Source: `mobile/lib/core/widgets/fixo_cards.dart:66` — stage label "Confirmation" without truncation or abbreviation

**Affected screens:** Job detail (in-progress), homeowner dashboard job cards — any screen rendering `JobStepper`  
**Affected user type:** Homeowner, Tradie  
**Affected source files:**
- `mobile/lib/core/widgets/fixo_cards.dart`

**Recommended change:** Shorten label to `"Confirm"` or `"Done"` for the Confirmation stage. Alternatively, enforce `overflow: TextOverflow.ellipsis` and `maxLines: 1` on the label `Text` widget. Verify all 6 stage labels render correctly at minimum device width (320 dp logical pixels).

---

### TH-UI-003 · P3 · `JobStepper` stage-count docstring is stale

**Summary:** The `marketplace.dart` docstring for job stages states `stage 0..3` but the stepper renders 6 segments (stages 0–5: Requested, Payment, Booked, In Progress, Confirmation, Completed). This is a documentation defect only — no functional impact.

**Root cause:** Confirmed (stale comment).

**Evidence:**
- Source: `mobile/lib/models/marketplace.dart:19` — docstring `stage 0..3`
- Source: `mobile/lib/core/widgets/fixo_cards.dart:74` — 6-segment generation

**Affected screens:** None (documentation only)  
**Affected source files:**
- `mobile/lib/models/marketplace.dart`

**Required change:** Update docstring to `stage 0..5` and list all six stage names.
