# Implementation Tasks — v1.4

**Version:** 1.4  
**Date:** 2026-10-26  
**Status:** Completed — all tasks implemented and verified against codebase

Each task references one or more findings from `audit-findings.md`. Tasks are ordered by priority group, then by dependency order within the group.

> [!IMPORTANT]
> Do not modify application source code until this spec is approved.  
> Do not rename internal identifiers (`FixoWordmark`, `fixo` package, `FixoTheme`, `FixoApi`, `nz.co.fixo.fixo`, etc.) — only user-visible text changes.

---

## Priority 1 — Must complete before release

---

### [x] TASK-BRAND-01 · Update `FixoWordmark` widget text

**Findings:** TH-BRAND-001  
**File:** `mobile/lib/core/widgets/fixo_buttons.dart`

**Change:**
```dart
// Before
TextSpan(text: 'Tradie', style: ...),
TextSpan(text: 'Fixo',   style: amberStyle),

// After
TextSpan(text: 'Tradie',  style: ...),
TextSpan(text: 'Hunter',  style: amberStyle),
```

**Constraints:**
- Preserve the exact `TextStyle` applied to each span (font weight, size, letter spacing)
- Do not rename the class `FixoWordmark`
- Do not alter any other method or property of the widget

**Acceptance criteria:**
1. `FixoWordmark` renders "TradieHunter" with "Hunter" in amber on all screens that embed it
2. No visual regression on font size, weight, or spacing compared to prior renders
3. Widget class name remains `FixoWordmark` in source

**Regression risk:** All screens embedding `FixoWordmark` — verify: onboarding header, login screen, signup screen, homeowner dashboard header, tradie dashboard header

---

### [x] TASK-BRAND-02 · Update splash screen inline `TextSpan`

**Findings:** TH-BRAND-002  
**File:** `mobile/lib/features/shared/screens/splash_screen.dart`

**Change:** Lines 89–92 contain an inline `RichText` / `TextSpan` that replicates the wordmark pattern directly (not via `FixoWordmark` widget).

```dart
// Before — approximate
TextSpan(text: 'Tradie', style: darkStyle),
TextSpan(text: 'Fixo',   style: amberStyle),

// After
TextSpan(text: 'Tradie',  style: darkStyle),
TextSpan(text: 'Hunter',  style: amberStyle),
```

**Alternative approach (preferred):** If the inline spans are functionally identical to `FixoWordmark`, replace the inline implementation with a call to `FixoWordmark(...)` to eliminate the duplication. Verify visual match before committing this approach; if any style differs (e.g., larger font on splash), keep the inline approach and update text only.

**Acceptance criteria:**
1. Splash screen renders "TradieHunter" with "Hunter" in amber
2. Visual style of the wordmark is unchanged

---

### [x] TASK-BRAND-03 · Update hardcoded Flutter fallback strings

**Findings:** TH-BRAND-002  
**File:** `mobile/lib/main.dart`
- `mobile/lib/views/settings_screen.dart`
- `mobile/lib/views/auth/role_select_screen.dart`

**Changes:**

| File | Line(s) | Before | After |
|---|---|---|---|
| `main.dart` | 185 | `'TradieFixo'` | `'TradieHunter'` |
| `settings_screen.dart` | 186 | `'TradieFixo v1.0.0'` | `'TradieHunter v1.0.0'` |
| `settings_screen.dart` | 192 | `'TradieFixo v1.0.0'` (if duplicate) | `'TradieHunter v1.0.0'` |
| `role_select_screen.dart` | 61 | `"How will you be using TradieFixo?"` | `"How will you be using TradieHunter?"` |

**Do not change:** `signup_screen.dart:9` docstring — it is not user-facing.

**Acceptance criteria:**
1. Settings screen shows "TradieHunter vX.X.X" (or no fallback string at all if dynamic config works via TASK-CONFIG-01)
2. Role selection screen shows "How will you be using TradieHunter?"
3. No remaining `'TradieFixo'` strings in these files

---

### [x] TASK-CONFIG-01 · Fix `localeConfigProvider` JSON key path

**Findings:** TH-FUNC-003  
**File:** `mobile/lib/viewmodels/locale_viewmodel.dart`

**Problem:** `response['appName']` should be `response['brand']['appName']` (verify actual JSON serialization casing by inspecting a live `/api/config` response or the `JsonSerializerOptions` in `backend/Program.cs`).

**Steps:**
1. Confirm whether the backend serializes property names as camelCase (`brand.appName`) or PascalCase (`Brand.AppName`) by checking `JsonSerializerOptions` / `System.Text.Json` config in `backend/Program.cs`
2. Update the key path in `locale_viewmodel.dart` to match
3. Verify that `appName` value flows through to `main.dart` and replaces the fallback

**Acceptance criteria:**
1. After fixing, `main.dart` receives `"TradieHunter"` from the API (once TH-BRAND-003 backend update is also applied)
2. Fallback string `'TradieFixo'` in `main.dart` is still present as a safety net but is no longer activated in normal operation
3. No null-pointer exception when `/api/config` is unavailable (fallback must still function)

---

### [x] TASK-BRAND-04 · Update backend brand configuration

**Findings:** TH-BRAND-003  
**Files:**
- `backend/Options/BrandOptions.cs`
- `backend/appsettings.json`
- `backend/Models/PaymentOptions.cs`
- `backend/Services/SmtpEmailSender.cs`

**Changes:**

| File | Field | Before | After |
|---|---|---|---|
| `BrandOptions.cs` | Default `AppName` | `"TradieFixo"` | `"TradieHunter"` |
| `appsettings.json` | `Brand.AppName` | `"TradieFixo"` | `"TradieHunter"` |
| `appsettings.json` | `Brand.SupportEmail` | `support@tradiefixo.nz` | `support@tradiehunter.nz` *(pending domain)* |
| `appsettings.json` | `LegalEntityName` | `"TradieFixo Ltd"` | `"TradieHunter Ltd"` *(confirm legal name)* |
| `appsettings.json` | `TermsOfServiceUrl` | `tradiefixo.nz/...` | `tradiehunter.nz/...` *(pending domain)* |
| `appsettings.json` | `PrivacyPolicyUrl` | `tradiefixo.nz/...` | `tradiehunter.nz/...` *(pending domain)* |
| `PaymentOptions.cs` | `AccountName` | `"TradieFixo Ltd"` | `"TradieHunter Ltd"` *(confirm legal name)* |
| `SmtpEmailSender.cs` | Email subjects/bodies | "TradieFixo" × N | "TradieHunter" |

> [!CAUTION]
> **Domain dependency:** `tradiehunter.nz` must be registered and DNS configured before `SupportEmail`, `TermsOfServiceUrl`, and `PrivacyPolicyUrl` are updated in production config. Use a placeholder `// TODO: update when domain is live` comment if domain is not yet registered, and do not break existing email links until the new domain is live.

> [!NOTE]
> **Legal name dependency:** Confirm the legal entity name change with the business owner before updating `LegalEntityName` and `AccountName`. These affect payment records and emails.

**Acceptance criteria:**
1. `/api/config` response contains `"AppName": "TradieHunter"` (or camelCase equivalent)
2. System-generated emails display "TradieHunter" in subject and body
3. No remaining "TradieFixo" in backend brand config (excluding code comments and internal identifiers)

---

### [x] TASK-BRAND-05 · Update platform metadata to "TradieHunter"

**Findings:** TH-BRAND-004  
**Files:**
- `mobile/ios/Runner/Info.plist`
- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/web/manifest.json`

**Changes:**

| File | Key | Before | After |
|---|---|---|---|
| `Info.plist` | `CFBundleName` | `"Fixo"` | `"TradieHunter"` |
| `Info.plist` | `NSCameraUsageDescription` | `"Fixo needs camera access…"` | `"TradieHunter needs camera access…"` |
| `Info.plist` | `NSPhotoLibraryUsageDescription` | `"Fixo needs photo library…"` | `"TradieHunter needs photo library…"` |
| `Info.plist` | `NSMicrophoneUsageDescription` | `"Fixo needs microphone…"` | `"TradieHunter needs microphone…"` |
| `AndroidManifest.xml` | `android:label` | `"fixo"` | `"TradieHunter"` |
| `web/manifest.json` | `name` | `"fixo"` | `"TradieHunter"` |
| `web/manifest.json` | `short_name` | `"fixo"` | `"Tradie"` *(or "TH" — confirm with UX)* |

**Do NOT change:**
- `CFBundleIdentifier` — internal, tied to Apple developer profile
- `android:package` / applicationId `nz.co.fixo.fixo`
- Any `google-services.json` or Firebase configuration

**Acceptance criteria:**
1. iOS home screen displays "TradieHunter" under the app icon
2. iOS permission dialogs reference "TradieHunter"
3. Android launcher displays "TradieHunter"
4. Web PWA manifest shows "TradieHunter"
5. No "Fixo" or "fixo" user-visible strings remain in platform metadata files

---

### [x] TASK-FUNC-01 · Fix tradie pending offer visibility (end-to-end)

**Findings:** TH-FUNC-001  
**Priority:** P1 — tradies cannot accept jobs without this fix

This task requires coordinated changes across backend and mobile. Implement and test as a unit.

**Part A — Backend: widen `GetForUserAsync` query**  
File: `backend/Repositories/JobRepository.cs`

Add a second predicate to include jobs where the tradie holds a pending offer:
```csharp
// Add OR clause alongside existing MatchedTradieId == userId
|| (j.OfferedTradieId == userId && j.Status == JobStatus.PendingOffer)
```
Verify exact field name (`OfferedTradieId` or equivalent) in the `Job` entity.

**Part B — Backend: widen `GET /api/jobs/{id}` authorization**  
File: `backend/Controllers/JobsController.cs`

The access check for `GET /api/jobs/{id}` must permit a tradie with a pending offer to read the job detail. Add:
```csharp
|| (job.OfferedTradieId == currentUserId && job.Status == JobStatus.PendingOffer)
```
Ensure this check is additive (OR, not replacing the existing check).

**Part C — Mobile: subscribe to `onOfferLifecycle` on tradie dashboard**  
File: `mobile/lib/features/tradie/views/tradie_dashboard_view.dart`

The dashboard currently subscribes to `onNewJobMatch`. Add a subscription to `onOfferLifecycle` that triggers a refresh of the incoming requests section.

**Part D — Mobile: render pending-offer jobs in `_IncomingRequestsSection`**  
File: `mobile/lib/features/tradie/views/tradie_dashboard_view.dart`

`_IncomingRequestsSection` filters on `status == 'Requested'`. Update the filter to include the status value that represents a pending offer (verify the exact status string/enum used in the mobile model against the backend `JobStatus` enum).

**Acceptance criteria:**
1. After a homeowner posts a job, a matched tradie's dashboard shows the incoming request within the normal SignalR propagation window
2. Tradie can navigate to request detail screen without receiving "Job not found"
3. Accept action on request detail screen works end-to-end (homeowner sees status update)
4. Unrelated tradies cannot access the job via `GET /api/jobs/{id}`
5. Existing matched-tradie job visibility is unaffected (regression check)

---

### [x] TASK-FUNC-02 · Fix homeowner navigation to matching screen for in-flight jobs

**Findings:** TH-FUNC-002  
**File:** `mobile/lib/core/navigation/job_navigation.dart`

**Change:** In `openHomeownerJob()`, add an explicit case for `Requested` status that routes to `/jobs/:id/matching`:

```dart
case 'Requested':
  appRouter.push('/jobs/$jobId/matching');
  break;
```

Remove `Requested` from the default/fallback case if it currently falls there.

**Pre-condition:** Verify that the matching screen (`/jobs/:id/matching`) handles a revisit correctly — i.e., it re-fetches current matching state rather than replaying the post-job form. If it does not, add a note that the screen needs a "re-entry" mode before this routing change is deployed.

**Acceptance criteria:**
1. Tapping a `Requested`-status job card from the homeowner dashboard navigates to the matching screen
2. The matching screen shows current tradie matching progress (not a blank or error state)
3. All other status → route mappings in `openHomeownerJob()` are unchanged

---

### [x] TASK-TEST-01 · Fix `gotoLogin` integration helper unrecognized-state handling

**Findings:** TH-TEST-001  
**File:** `mobile/integration_test/helpers/e2e_helpers.dart`

**Change:** In the `gotoLogin()` function, add a final fallback branch that handles unrecognized app states (routes other than dashboard, onboarding, verify-email):

```dart
// After all known-state branches:
else {
  // Unrecognized state — clear auth and force navigate to login
  await FlutterSecureStorage().deleteAll();
  appRouter.go('/auth');
  await tester.pumpAndSettle();
  assert(find.byKey(Key('email_field')).evaluate().isNotEmpty,
    'gotoLogin: failed to reach login screen from unrecognized state');
}
```

**Also add:** A post-`gotoLogin` assertion that the login screen email field is visible before the function returns, to catch future regressions.

**Acceptance criteria:**
1. After a test that leaves the app on `/chat/:id`, the next test's `gotoLogin()` call successfully navigates to the login screen
2. The helper assertion fires and reports clearly if navigation fails
3. All existing tests that currently pass continue to pass

---

## Priority 2 — Fix in v1.4 sprint

---

### [x] TASK-FUNC-03 · Fix `go()` stale data on same-pattern routes

**Findings:** TH-FUNC-004  
**File:** `mobile/lib/core/navigation/job_navigation.dart` and relevant job detail screen(s)

**Options (choose one after inspecting the detail screen implementation):**

**Option A — Use `push()` instead of `go()` for detail routes:**  
Replace `appRouter.go('/jobs/$jobId/detail')` with `appRouter.push('/jobs/$jobId/detail')` for programmatic job-detail navigation. This ensures a new widget instance is created. Verify back-button behavior is acceptable.

**Option B — Use `ref.invalidate()` / key-based rebuild:**  
In the job detail screen, key the stateful widget on the `jobId` route parameter. go_router will rebuild when the key changes even with `go()`.

**Acceptance criteria:**
1. Navigating from job A detail to job B detail (using `go()` or programmatic navigation) displays job B's data, not job A's
2. Back navigation from a detail screen behaves correctly (does not add extra entries to back stack)

---

### [x] TASK-FUNC-04 · Fix "N Booked" badge — show accurate status summary

**Findings:** TH-FUNC-005  
**File:** `mobile/lib/features/tradie/views/tradie_dashboard_view.dart`

**Change:** Replace the hardcoded `'${jobs.length} Booked'` with a label that reflects the actual content:

```dart
// Option A — generic count
'${jobs.length} Active'

// Option B — status breakdown (if UX approves)
'${inProgress.length} In Progress · ${booked.length} Booked'
```

Confirm preferred label format with UX before implementing.

**Acceptance criteria:**
1. Badge label accurately reflects job statuses present in the section
2. No automated test asserts on the literal string "Booked" for this badge (update any that do — see TH-TEST-002)

---

### [x] TASK-FUNC-05 · Resolve Decline button no-op — implement or explicitly defer

**Findings:** TH-FUNC-006  
**File:** `mobile/lib/features/tradie/views/tradie_dashboard_view.dart`

**Decision required by product owner before implementation.** Two options:

**Option A — Implement decline:**  
Wire `onDecline` to call the appropriate backend endpoint (e.g., `DELETE /api/jobs/:id/offer` or `POST /api/jobs/:id/decline`). Verify the endpoint exists; if not, note it as a separate backend task. Show a confirmation dialog before declining. Refresh the incoming requests section on success.

**Option B — Explicitly defer decline:**  
Remove the Decline button from the UI entirely, or replace it with a disabled button with tooltip "Coming soon". Add a code comment: `// TODO: Decline offer — deferred to v1.5`. The empty `onDecline: () {}` must not remain silently.

**Acceptance criteria:**
1. The Decline button is either functional (Option A) or visibly absent/disabled with a code comment (Option B)
2. No empty callback `() {}` remains for this action

---

### [x] TASK-FUNC-06 · Fix ProfileService seeder / migration key conflict

**Findings:** TH-FUNC-007  
**File:** `backend/Services/ProfileService.cs`

**Change:** Guard the seeder with an existence check before inserting each service record:

```csharp
if (!await _db.Services.AnyAsync(s => s.Id == serviceId))
{
    _db.Services.Add(new Service { Id = serviceId, Name = "Plumber", ... });
}
```

Apply the same guard to all records inserted by the runtime seeder.

**Acceptance criteria:**
1. A fresh `docker compose up` with `dotnet ef database update` applied does not produce any `duplicate key violation on PK_Services` error
2. Unit test `ProfileService_SeedServices_NoConflict` (to be written as part of this task) passes

---

### [x] TASK-FUNC-07 · Fix render-probe date format to `en-NZ`

**Findings:** TH-FUNC-008  
**File:** `web/src/components/PayoutBatches/format.ts`

**Change:**
```ts
// Before
date.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })

// After
date.toLocaleDateString('en-NZ', { day: 'numeric', month: 'short', year: 'numeric' })
```

**Acceptance criteria:**
1. Render-probe test assertions for batch date format pass
2. Date displays as "21 Sept 2026" format (NZ convention) in the admin payout batch list

---

### [x] TASK-FUNC-08 · Fix `ListTile` / `DecoratedBox` assertion on homeowner profile screen

**Findings:** TH-FUNC-009  
**File:** `mobile/lib/features/homeowner/screens/public_profile_screen.dart`

**Change:** Wrap the `ListTile` (or its nearest `DecoratedBox` ancestor) with a `Material` widget:

```dart
Material(
  color: Colors.transparent, // Preserve DecoratedBox background
  child: DecoratedBox(
    decoration: ...,
    child: ListTile(...),
  ),
)
```

Alternatively, if the `DecoratedBox` is the direct parent, insert `Material(color: Colors.transparent)` between `DecoratedBox` and `ListTile`.

**Acceptance criteria:**
1. No `FlutterError: Cannot render ink feature` assertion in debug-mode test runs
2. Visual appearance of the profile tiles is unchanged
3. Ink splash animation is visible on tap (expected behavior after fix)

---

### [x] TASK-TEST-02 · Fix stale integration test finders and timing

**Findings:** TH-TEST-002  
**Files:** Multiple integration test files in `mobile/integration_test/`

**Sub-tasks:**

**TASK-TEST-02a** (TH-TEST-002a) — Update tradie "Accept" finder  
Search for `find.text('Accept')` in integration tests. Replace with the actual rendered button text:
- `find.text('Review & Accept')` or `find.text('Accept Job')` — verify against current UI

**TASK-TEST-02b** (TH-TEST-002b) — Fix `find.byType(Card)` for `ModernJobCard`  
Replace `find.byType(Card)` with a semantic finder that matches `ModernJobCard`:
- Option A: `find.byType(ModernJobCard)` (import the type)
- Option B: `find.byKey(Key('job_card_$jobId'))` if cards have keys
- Option C: `find.ancestor(of: find.text(jobTitle), matching: find.byType(Container))` — fragile, prefer A or B

**TASK-TEST-02c** (TH-TEST-002c) — Fix ambiguous "fee" finder  
Replace `find.textContaining('fee').findsOneWidget` with a more specific finder scoped to the relevant widget:
- `find.descendant(of: find.byKey(Key('cancellation_sheet')), matching: find.textContaining('fee'))`
- Or assert `findsWidgets` and verify the count explicitly

**TASK-TEST-02d** (TH-TEST-002d) — Increase cross-persona timing budget  
Locate the 20-second poll timeout for the cross-persona test. Increase to at least 60 seconds (or the observed P95 completion time from CI logs). Document the rationale in a comment.

**Acceptance criteria:**
1. Tradie accept-flow test passes without finder errors
2. Job card finder does not produce "zero widgets" errors
3. Cancellation fee test does not fail on `findsOneWidget` multiplicity
4. Cross-persona test completes within the new timing budget on the target CI machine

---

### [x] TASK-UI-01 · Fix signup screen typographical error

**Findings:** TH-UI-001  
**File:** `mobile/lib/features/homeowner/screens/signup_screen.dart`

**Change:** Line 108:
```dart
// Before
'No accoutn yet? Join!'

// After (confirm exact wording with UX)
'Already have an account? Sign in.'
```

**Acceptance criteria:**
1. Signup screen renders the corrected string
2. No "accoutn" or other misspellings remain in user-visible strings in this file

---

### [x] TASK-UI-02 · Fix `JobStepper` "Confirmation" label truncation

**Findings:** TH-UI-002  
**File:** `mobile/lib/core/widgets/fixo_cards.dart`

**Change:** Update the Confirmation stage label. Preferred option: shorten to `"Confirm"`.

```dart
// Before (approximate)
'Confirmation'

// After
'Confirm'
```

If shortening is rejected by UX, apply `overflow: TextOverflow.ellipsis` and `maxLines: 1` to the label `Text` widget as a fallback.

**Acceptance criteria:**
1. All 6 stepper labels render on a single line at 320 dp logical width without wrapping or truncation mid-word
2. Labels remain legible at 320 dp (no ellipsis unless the label is genuinely too long)
3. Verify on both homeowner and tradie job detail screens

---

## Priority 3 — Fix or formally defer

---

### [x] TASK-UI-03 · Update `JobStepper` stage-count docstring

**Findings:** TH-UI-003  
**File:** `mobile/lib/models/marketplace.dart`

**Change:** Update the docstring at line 19 from `stage 0..3` to `stage 0..5` and list all six stages: Requested (0), Payment (1), Booked (2), In Progress (3), Confirmation (4), Completed (5).

**Acceptance criteria:**
1. Docstring accurately reflects the 6-stage model
2. No other stale stage-count references remain in `marketplace.dart`

---

## Task Dependency Map

```
TASK-BRAND-01 (wordmark widget)
TASK-BRAND-02 (splash inline)       ← independent of TASK-BRAND-01
TASK-BRAND-03 (Flutter fallbacks)   ← independent
TASK-CONFIG-01 (key path fix)  ──┐
TASK-BRAND-04 (backend config) ──┴─► together enable dynamic app name from config
TASK-BRAND-05 (platform metadata)   ← independent

TASK-FUNC-01 (tradie offers) ← backend Parts A+B must deploy before mobile Parts C+D
TASK-FUNC-02 (matching nav)  ← verify matching screen re-entry first
TASK-TEST-01 (gotoLogin fix) ← should be applied before running other integration tests
TASK-TEST-02 (stale finders) ← independent sub-tasks, can be parallelized
```

---

## Rebranding Checklist

After all brand tasks are complete, verify these surfaces show "TradieHunter":

- [x] Splash screen wordmark
- [x] Onboarding header wordmark
- [x] Login screen wordmark
- [x] Signup screen wordmark
- [x] Homeowner dashboard app bar wordmark
- [x] Tradie dashboard app bar wordmark
- [x] Role selection screen body text
- [x] Settings screen app-version label
- [x] iOS home screen app name
- [x] iOS permission dialog strings
- [x] Android launcher app name
- [x] Web PWA manifest name
- [x] System emails (subject + body)
- [x] `/api/config` `AppName` response field
