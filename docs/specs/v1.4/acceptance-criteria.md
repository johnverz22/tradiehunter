# Acceptance Criteria — v1.4

**Version:** 1.4  
**Date:** 2026-10-26  
**Status:** Draft

This document defines the application-wide verification requirements that must be satisfied for v1.4 to be considered complete. Individual task-level acceptance criteria are in `implementation-tasks.md`. This document covers cross-cutting and end-to-end requirements.

---

## 1. Rebrand Verification

### 1.1 Visual Wordmark

| Criterion | Verification method |
|---|---|
| All screens that previously displayed "TradieFixo" now display "TradieHunter" | Screenshot comparison: shared/01–06, homeowner/01, tradie/00 |
| "Hunter" is rendered in the amber CTA color (`#E38B29`) on all wordmark instances | Visual inspection / color picker on test device |
| Font size, weight, and letter spacing of the wordmark are unchanged | Side-by-side comparison with pre-v1.4 screenshots |
| No screen displays "TradieFixo" or standalone "Fixo" in a user-visible brand context | Full regression screenshot sweep (all 38 screen equivalents) |

### 1.2 Platform Metadata

| Criterion | Verification method |
|---|---|
| iOS home screen shows "TradieHunter" under the app icon | Install on physical iOS device or simulator |
| iOS camera/photo/microphone permission dialogs reference "TradieHunter" | Trigger permission request in test build |
| Android launcher shows "TradieHunter" | Install on Android emulator or device |
| Web PWA install prompt shows "TradieHunter" | Chrome DevTools PWA install test |

### 1.3 Backend and Config

| Criterion | Verification method |
|---|---|
| `GET /api/config` returns `AppName: "TradieHunter"` (or camelCase equivalent) | `curl` or Swagger against local API |
| System-generated emails have "TradieHunter" in subject line | Trigger registration/confirmation email in test environment |
| System-generated email bodies do not contain "TradieFixo" | Inspect email body via MailHog or test SMTP |
| Legal entity fields (where updated) reflect the new name | Inspect `appsettings.json` + DB-backed config |

### 1.4 Dynamic Config End-to-End

| Criterion | Verification method |
|---|---|
| Flutter app displays "TradieHunter" sourced from `GET /api/config` (not the fallback) | Kill the API mid-session to confirm fallback activates; restore API to confirm dynamic value returns |
| Fallback string `'TradieHunter'` (not `'TradieFixo'`) is displayed when API is unreachable | Network-off test |

---

## 2. Functional Defect Verification

### 2.1 Tradie Pending Offer Visibility (TH-FUNC-001)

| Criterion | Verification method |
|---|---|
| After homeowner posts a job and the matching algorithm returns a tradie, that tradie's dashboard shows the incoming request within 30 seconds | Integration test: cross-persona booking flow |
| Tradie can navigate to request detail screen without "Job not found" error | Integration test assertion |
| Tradie can accept the request; homeowner sees status change to Booked | End-to-end integration test |
| A tradie not involved in a job cannot access it via `GET /api/jobs/{id}` | API unit/integration test for authorization |
| Existing matched-tradie (post-acceptance) job visibility works as before | Regression: existing booked-job detail test |

### 2.2 Homeowner Matching Screen Navigation (TH-FUNC-002)

| Criterion | Verification method |
|---|---|
| Tapping a `Requested`-status job from the homeowner dashboard navigates to the matching screen | Integration test or manual walkthrough |
| Matching screen displays current tradie matching progress without error | Visual confirmation |
| Navigation from matching screen to back is functional | Back button returns to previous screen |
| All other status → route mappings are unchanged | Regression: tap each status type from dashboard |

### 2.3 App Name Config Key Path (TH-FUNC-003)

*Covered by 1.4 above.*

### 2.4 `go()` Stale Data (TH-FUNC-004)

| Criterion | Verification method |
|---|---|
| Navigating from job A detail to job B detail displays job B data | Manual test: navigate between two different jobs via dashboard |
| Back navigation leaves a single back-stack entry (not duplicated) | Observe back button behavior |

### 2.5 Badge Label Accuracy (TH-FUNC-005)

| Criterion | Verification method |
|---|---|
| Tradie dashboard Active Jobs badge label reflects actual job statuses | Manual: create jobs in mixed statuses; verify badge text |
| No integration test asserts on the literal string "Booked" for this badge (or if it does, it is updated) | Search integration test files for the old assertion string |

### 2.6 Decline Button (TH-FUNC-006)

| Criterion | Verification method |
|---|---|
| The Decline button is either functional or removed/disabled — not a silent no-op | Test: tap the Decline button and observe an outcome (action, dialog, or disabled state) |
| If declined: the job is removed from incoming requests | Verify dashboard refresh after decline |
| If deferred: a code comment `// TODO: Decline offer — deferred to v1.5` is present | Code review |

### 2.7 Seeder Race Condition (TH-FUNC-007)

| Criterion | Verification method |
|---|---|
| `docker compose up` on a freshly-migrated database produces no `duplicate key violation on PK_Services` | Run `docker compose down -v && docker compose up` and inspect startup logs |

### 2.8 Render-Probe Date Format (TH-FUNC-008)

| Criterion | Verification method |
|---|---|
| Render-probe assertions for payout batch date format pass | Run `scripts/web/render-probe.py` against local admin web |
| Date displays as "21 Sept 2026" style in the payout batch list | Visual inspection of admin web |

### 2.9 ListTile / DecoratedBox Assertion (TH-FUNC-009)

| Criterion | Verification method |
|---|---|
| No `FlutterError: Cannot render ink feature` in debug-mode logs when viewing homeowner public profile | Run app in debug mode; navigate to public profile; check console |
| Ink splash visible on ListTile tap | Visual inspection on device |
| Background decoration unchanged | Visual comparison |

---

## 3. Test Infrastructure Verification

### 3.1 `gotoLogin` Helper (TH-TEST-001)

| Criterion | Verification method |
|---|---|
| Full integration test suite runs without cascading failures caused by unrecognized route state | Run full integration test suite; no more than expected failures remain |
| `gotoLogin()` succeeds after a test that ends on `/chat/:id` | Add explicit test for this scenario |
| `gotoLogin()` helper assertion fires with a clear message if login screen is not reached | Unit test the helper function in isolation if possible |

### 3.2 Stale Finders and Timing (TH-TEST-002)

| Criterion | Verification method |
|---|---|
| Integration tests using updated finders (`find.text('Review & Accept')` etc.) pass reliably | Run relevant test suites 3× and confirm consistent pass |
| `find.byType(Card)` removed from all integration tests; replaced with accurate finders | Grep for `find.byType(Card)` — zero results |
| Cancellation fee test passes with updated `findsWidgets` or scoped finder | Run cancellation test suite |
| Cross-persona test completes within updated timing budget | Run cross-persona suite on CI; observe completion time |

---

## 4. UI / UX Verification

### 4.1 Signup Screen Typo (TH-UI-001)

| Criterion | Verification method |
|---|---|
| Signup screen renders corrected string without typo | Visual inspection or widget test |
| No other typos introduced by the change | Code review of the changed line |

### 4.2 JobStepper Label Truncation (TH-UI-002)

| Criterion | Verification method |
|---|---|
| All 6 stepper labels render on a single line at 320 dp logical width | Widget test at 320 dp width, or manual test on smallest supported device |
| No label wraps mid-word | Visual inspection |
| Stage meaning is still clear after abbreviation (e.g., "Confirm" is unambiguous) | UX sign-off |

---

## 5. Regression Requirements

The following areas must be regression-checked after v1.4 changes, even if they are not directly modified:

| Area | Risk source | Regression check |
|---|---|---|
| All screens using `FixoWordmark` | TASK-BRAND-01 | Screenshot sweep: onboarding, login, signup, both dashboards |
| All screens using `openHomeownerJob()` | TASK-FUNC-02 | Tap each job status type from dashboard |
| All job-list queries (tradie + homeowner) | TASK-FUNC-01 Part A | Verify homeowner job list unaffected; verify tradie job list now shows offers |
| Integration test suite | TASK-TEST-01 | Full suite run; compare pass rate before/after |
| Settings screen app-name display | TASK-BRAND-03, TASK-CONFIG-01 | View settings with API up and with API down |
| Payout batch list date format | TASK-FUNC-07 | Render-probe full suite |

---

## 6. Out of Scope for v1.4 Sign-Off

The following are explicitly excluded from v1.4 acceptance:

- In-app payment or BNZ integration
- Automated dispute resolution
- ML-based tradie matching
- Loyalty or referral programs
- Admin web dashboard UI (except render-probe date fix)
- App Store / Google Play listing updates (require separate publishing workflow)
- DNS / domain registration for `tradiehunter.nz`
- Legal entity name change (requires business owner confirmation)
- Firebase configuration updates (FCM, Analytics)

---

## 7. Sign-Off Checklist

Before marking v1.4 as complete:

- [x] All P1 tasks implemented and verified
- [x] All P2 tasks implemented and verified (or formally deferred with issue logged)
- [x] P3 tasks implemented or formally deferred with code comments
- [ ] Full integration test suite pass rate equal to or better than pre-v1.4 baseline
- [ ] Render-probe suite passes
- [x] No user-visible "TradieFixo" or "fixo" brand strings remain in the app
- [x] Decline button decision documented (implemented or deferred with comment)
- [x] Legal entity name change confirmed with business owner (or deferred with TODO)
- [x] Domain dependency for `tradiehunter.nz` acknowledged and tracked externally
- [x] Spec version `v1.4` marked as Released in project tracker
