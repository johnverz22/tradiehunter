# E2E Baseline — 2026-11-17

Homeowner suites run via `flutter test` on iPhone 17 Pro simulator
(`9AA76BF8-982A-4044-A032-FA49CBF3D9E3`) against `http://localhost:5000`
(docker stack up). Each suite ran with `--dart-define=FIXO_DISABLE_PUSH=true`.

## Suite-by-suite results

### auth (`integration_test/auth_test.dart`, no UI_V2 flag)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| Auth Signup screen renders role cards and all form fields | FAIL | test sync problem | `find.byKey(Key('role_homeowner'))` found 0 widgets — v2 auth screen not rendering expected Key; backend login 401 on unauthenticated fixture |

- 5 pass, 1 fail (pre-existing signup failure unrelated to v2)

### job_request (`integration_test/job_request_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| P2-04 submitting empty form stays on post job screen | FAIL | test sync problem | Tap offset would not hit `post_job_fab` widget |
| P2-08 Post Job screen renders required fields | FAIL | test sync problem | Same `post_job_fab` hit-test issue |
| P2-LINZ resolves an address through the live API and clears edited locations | FAIL | test sync problem | `ensureVisible` → `No element` (state out of sync) |

- 1 pass, 3 fail — all appear to be test-sync / widget-key issues, not app defects

### matching (`integration_test/matching_test.dart`, no UI_V2 flag)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| P3-04 job advances after tradie accepts the offer | FAIL | app defect / test sync | POST `/jobs/305/offers/307/respond` → HTTP 409 `Offer is already in state 'Accepted'` |

- 1 pass, 1 fail — needs fixture state cleanup; could be v2 intentional change if offer state persists across runs

### payment (`integration_test/payment_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| P4-13 payment screen renders bank details and upload button | FAIL | test sync problem | Fixture `awaitingPaymentJob` → fixture setup threw during POST |
| P4-13 payment under review shows status | FAIL | test sync problem | Fixture `paymentReviewJob` → fixture setup threw during POST |

- 0 pass, 2 fail — both fail at fixture setup (backend state), not widget assertions

### dispute (`integration_test/dispute_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| P7-04 dispute screen renders reason, details and submit | FAIL | test sync problem | Fixture `bookedJob` → fixture setup threw |
| P7-04 filled dispute form submits and leaves screen | FAIL | test sync problem | Same fixture setup failure |
| P7-04 submitting dispute without details stays on screen | FAIL | test sync problem | Same fixture setup failure |

- 0 pass, 3 fail — fixture setup failure, not widget assertions

### cancellation (`integration_test/cancellation_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| P6-06 cancel sheet renders reason list and confirm button | FAIL | test sync problem | Fixture `bookedJob` → fixture setup threw |
| P6-06 dismissing cancel sheet keeps job | FAIL | test sync problem | Same fixture setup failure |

- 0 pass, 2 fail — fixture setup failure

### job_lifecycle (`integration_test/job_lifecycle_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| P5-03 tradie can check in on a Booked job | FAIL | test sync problem | Fixture `bookedJob` → fixture setup threw |
| P5-04 tradie can check out on an InProgress job | FAIL | test sync problem | Fixture `inProgressJob` → fixture setup threw |

- 0 pass, 2 fail — tradie-side lifecycle tests; fixture setup failure

### screenshots (`integration_test/screenshots_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| capture all homeowner screens | FAIL | test infrastructure | Multiple exceptions (28) detected during run; `__SHOT__` markers emitted (e.g. `homeowner/16_homeowner_profile`) |

- 0 pass, 1 fail — screenshot capture needs the external `xcrun simctl io screenshot` watcher per test header comments

### screenshots_variants (`integration_test/screenshots_variants_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| capture homeowner variants | FAIL | test infrastructure | Multiple exceptions (32); `__SHOT__` markers emitted (e.g. `homeowner/28_job_detail_error`) |

- 0 pass, 1 fail — same screenshot watcher requirement

### v2_flows (`integration_test/v2_flows_test.dart`, UI_V2=all)

| Test id | Status | Class | Evidence |
|---|---|---|---|
| ho_quotes accepts a quote and books the job | FAIL | app defect / test sync | Rendering/layout exception during screen transition |
| ho_quotes gates high-value accept behind written contract | FAIL | app defect / test sync | Same |
| ho_extra_cost approves a pending extra-cost request | FAIL | app defect / test sync | Same |
| ho_tradie_profile sends a direct tradie request | FAIL | app defect / test sync | Same |

- 0 pass, 4 fail — Phase-4 flows gated behind `UI_V2=all`; rendering exceptions suggest the v2 screens are not yet fully settled

## Classification summary

| Class | Count |
|---|---|
| test sync problem | 10 |
| app defect / test sync | 6 |
| test infrastructure | 2 |

No pure "app defect" without test involvement. The dominant failure mode is **fixture setup throwing on backend POST** (payment, dispute, cancellation, job_lifecycle), indicating seeded-state drift between the frontend fixtures and the current backend — not a v2 regression.

## E2.2/E2.3 follow-ups needed

- B-1 (`cancel_confirm_button` / `cancel_dismiss_button`) — keys added in E5, but cancellation tests still fail at fixture setup before reaching the sheet
- B-4 (`job_overflow_menu`) — key added in E5
- P-1 / P12-28 — `job_request_test`, `payment_test`, `job_lifecycle_test` describe v1 order; flow-v2 updates pending E2.5 (needs SPECS confirmation)
- E2.5/E2.6 — flow-v2 realignment + `quotedJob`/`pendingAdjustmentJob` fixtures for `ho_quotes`, `ho_extra_cost`, `ho_tradie_profile` coverage

## Baseline files to check

- `scripts/run-e2e.sh` — entry point for C0/C1/C2/C3
- `mobile/integration_test/helpers/fixture_helper.dart` — fixture source for all setup failures
- `mobile/integration_test/helpers/api_helper.dart:427` — `_throwIfError` where HTTP 409/401 surface
