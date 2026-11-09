# Running Tests — TradieFixo

Two test layers, both targeting the QA specs in `docs/specs/`:

- **Flutter integration tests** — drive the real mobile app UI on a simulator (P1–P7, P10 mobile)
- **Playwright e2e tests** — drive the React admin web in headless Chromium (P1/P4/P6/P7/P10 admin)

The canonical manual test checklists are in `docs/specs/v1.3/qa/` (QA-00 through QA-13).
The consolidated functional guide is `docs/specs/v1.3/QA-functional-testing-guide.md`.

---

## Prerequisites (one-time)

| What | Check |
|---|---|
| Docker / OrbStack stack up | `docker compose ps` — api, db, redis, azurite all healthy |
| Flutter SDK on host | `/Users/john/Develop/flutter/bin/flutter --version` |
| Node ≥ 20 | `node --version` |
| Playwright + Chromium | `ls web/node_modules/@playwright/test` |
| `integration_test` in pubspec | `grep integration_test mobile/pubspec.yaml` |

**Seed test accounts** (run once after a fresh DB, idempotent):

```sh
# Seeds: homeowner-a, tradie-verified, unverified, staff — all @fixo.test
bash scripts/seed-test-accounts.sh

# Also seed pending credentials so the admin web credential queue has data:
python3 scripts/e2e-credentials.py --keep
```

> **v1.3 note:** The seed script creates `tradie-verified@fixo.test` without bank
> details. To test payout flows (QA-12), add bank details manually via the mobile
> onboarding wizard or directly via `PUT /api/profile` after seeding.
> `TRADIE-PAUSED` (`IsAvailable=false`) must also be created manually for
> availability-toggle tests — see §"State each test needs" below.

---

## Part 1 — Flutter Integration Tests (mobile)

### Boot a simulator

```sh
# List available simulators
/Users/john/Develop/flutter/bin/flutter devices

# Boot one (if not already running)
open -a Simulator
# or: xcrun simctl boot <UDID>
```

For **two-device flows** (P3 matching, P5 lifecycle, P6 cancellation) you need two simulators running simultaneously with different device IDs.

### API base URL

| Simulator type | URL in `integration_test/helpers/test_config.dart` |
|---|---|
| iOS Simulator | `http://localhost:5000` (default) |
| Android Emulator | `http://10.0.2.2:5000` |

Override for either:

```sh
--dart-define FIXO_API_URL=http://localhost:5000
```

### Run commands

```sh
cd mobile

# Run a single file
/Users/john/Develop/flutter/bin/flutter test \
  integration_test/auth_test.dart \
  --device-id "iPhone 17 Pro"

# Run all integration tests (single-device flows only)
/Users/john/Develop/flutter/bin/flutter test \
  integration_test/ \
  --device-id "iPhone 17 Pro"

# Run with verbose output
/Users/john/Develop/flutter/bin/flutter test \
  integration_test/auth_test.dart \
  --device-id "iPhone 17 Pro" \
  --reporter expanded
```

### Two-device flows (P3, P5, P6)

These tests use `--dart-define FIXO_PERSONA=homeowner|tradie` to split which simulator runs which role. Each side **self-seeds its own fixture jobs via the API** (`helpers/fixture_helper.dart`), so the two sides no longer need to coordinate — either persona can also run alone on a single simulator. Run in **two terminals**:

```sh
# Terminal 1 — homeowner simulator
cd mobile && /Users/john/Develop/flutter/bin/flutter test \
  integration_test/matching_test.dart \
  --device-id "iPhone 17 Pro" \
  --dart-define FIXO_PERSONA=homeowner

# Terminal 2 — tradie simulator (different device ID)
cd mobile && /Users/john/Develop/flutter/bin/flutter test \
  integration_test/matching_test.dart \
  --device-id "iPhone 17 Pro Max" \
  --dart-define FIXO_PERSONA=tradie
```

> **Stagger the launches.** Two simultaneous `flutter test` iOS builds share
> `mobile/build` and the second fails (rsync exit 255). Wait for
> "Xcode build done" on the first persona before starting the second.

Same pattern applies to `job_lifecycle_test.dart` and `cancellation_test.dart`.

### Useful dart-defines

| Flag | Purpose |
|---|---|
| `FIXO_PERSONA=homeowner\|tradie` | Which role suite to run (matching/lifecycle/cancellation) |
| `FIXO_API_URL=…` | API base URL (default `http://localhost:5000`; Android emulator `http://10.0.2.2:5000`) |
| `FIXO_DISABLE_PUSH=true` | Skips the iOS notification-permission request at startup — prevents the system dialog stalling or overlaying tests/screenshots |

### Test files at a glance

| File | Covers | Personas | Devices |
|---|---|---|---|
| `auth_test.dart` | P1 login, OTP, signup | Homeowner, Tradie | 1 |
| `job_request_test.dart` | P2 post job | Homeowner | 1 |
| `matching_test.dart` | P3 offers, accept/decline | Homeowner + Tradie | 1–2 |
| `payment_test.dart` | P4 receipt upload, status | Homeowner | 1 |
| `job_lifecycle_test.dart` | P5 check-in → confirm → review | Tradie + Homeowner | 1–2 |
| `cancellation_test.dart` | P6 cancel sheet, fees, flag warning | Homeowner + Tradie | 1–2 |
| `dispute_test.dart` | P7 open dispute, evidence | Homeowner | 1 |

The screenshot drivers (`screenshots_test.dart`, `screenshots_fixup_test.dart`)
also live in `integration_test/` — `flutter test` only runs files under that
directory on-device, so they cannot be moved out. They are excluded by running
the functional files explicitly (see the per-suite commands / run scripts),
not by sweeping the whole directory. Driver usage:
`--dart-define FIXO_PERSONA=…` + `SHOT_*_JOB=<id>` defines — see
`docs/runs/v1.4/screenshots/README.md`.

> **P10 mobile coverage** (availability toggle, blind reviews, rebrand, photo limits,
> bank details, materials disclaimer) is currently covered by the manual checklist
> QA-12 only — no automated integration test files exist for P10 yet.

### Helpers

| File | Purpose |
|---|---|
| `helpers/test_config.dart` | API URL, test account credentials (`kHomeownerEmail`, `kTradieEmail`, `kStaffEmail`, `kUnverifiedEmail`, `kDemoTradieEmail`), timeout constants (`kNetworkSettle`, `kMatchingSettle`) |
| `helpers/auth_helper.dart` | `loginAs()`, `loginAsHomeowner()`, `loginAsTradie()`, `gotoLogin()`, `pumpFor()`, `pollUntil()` |
| `helpers/api_helper.dart` | Direct API calls: tokens, job create/status, offer dispatch/respond, check-in/out, confirm, payment open/upload/verify, tradie availability |
| `helpers/fixture_helper.dart` | Self-seeding job fixtures — `requestedJob()` … `completedJob()` drive a fresh job to any state via the API and return its ID; `parkCompetingTradies()` keeps the demo tradie from winning offers |

---

## Part 2 — Playwright E2E Tests (admin web)

### Prerequisites

Stack must be running and staff account must exist:

```sh
docker compose up -d
bash scripts/seed-test-accounts.sh   # creates staff@fixo.test / Test1234!
```

### Run commands

```sh
cd web

# Run all e2e tests (starts vite dev server automatically)
npm run test:e2e

# Interactive UI mode (great for debugging)
npm run test:e2e:ui

# Run a single spec file
npx playwright test e2e/credentials.spec.ts

# Show HTML report after a run
npm run test:e2e:report
```

### Test files at a glance

| File | Covers |
|---|---|
| `e2e/auth.spec.ts` | Login page, unauthenticated redirect, wrong credentials |
| `e2e/credentials.spec.ts` | P1 credential queue — list, approve, reject, validation |
| `e2e/payments.spec.ts` | P4 payment queue — list, verify, reject, validation |
| `e2e/refunds.spec.ts` | P6 refund queue — list, process, validation, decimal precision |
| `e2e/disputes.spec.ts` | P7 dispute list and detail — resolve validation |
| `e2e/users.spec.ts` | P7 user list, flagged filter, RBAC smoke |

> **P10 admin coverage** (payout queue, payout batches, payment SLA indicators,
> rebrand wordmark): fixture data for the render-probe exists in
> `scripts/web/fixtures/payouts/queue.json` and `batches.json`. A
> `e2e/payouts.spec.ts` Playwright spec has not been written yet — add it
> alongside `payments.spec.ts` for payout queue + process modal + batch pages.
> The SLA "Waiting" column and URGENT badge are best asserted in `payments.spec.ts`
> by injecting a `minutesSinceSubmission` value via the fixture.

### Auth state

`e2e/fixtures/auth.setup.ts` logs in as `staff@fixo.test` once and saves the session to `e2e/.auth/staff.json`. All spec files reuse this state — no repeated logins. The `.auth/` directory is gitignored.

If the token expires mid-run, delete `e2e/.auth/staff.json` and re-run.

### CI environment variable

On CI, set `VITE_API_URL` so the web app points at the backend container:

```sh
VITE_API_URL=http://localhost:5000 npm run test:e2e
```

---

## Part 3 — render-probe (web component snapshots)

`scripts/web/render-probe.py` renders a React page with a prefetched API fixture and asserts that specific strings appear (or are absent) in the rendered HTML. It is not a full Playwright flow — it tests layout and data-binding correctness without needing a live backend.

Fixture files live in `scripts/web/fixtures/`:

| Fixture | Route | Covers |
|---|---|---|
| `credentials/` | `/credentials` | P1 credential queue layout |
| `payments/` | `/payments` | P4 payment queue layout |
| `payouts/queue.json` | `/payouts` | **P10** payout queue — amounts, masking, status badges, no-bank-details banner |
| `payouts/batches.json` | `/payouts/batches` | **P10** batch list — period labels, progress, totals, status badges |
| `audit/` | `/audit-logs` | Audit log layout |

Run a specific fixture (`--page` is a module path under `web/src`, no extension):

```sh
python3 scripts/web/render-probe.py \
  --page features/payouts/pages/PayoutQueue \
  --fixture scripts/web/fixtures/payouts/queue.json

python3 scripts/web/render-probe.py \
  --page features/payouts/pages/PayoutBatches \
  --fixture scripts/web/fixtures/payouts/batches.json
```

The payouts fixtures assert (among other things): masked bank account numbers
(`····4831`, never the full number), the no-bank-details banner, commission
deduction display, and the link to `/payouts/batches`.

---

## Quick-reference cheatsheet

| What | Command |
|---|---|
| Seed test accounts | `bash scripts/seed-test-accounts.sh` |
| Seed pending credentials | `python3 scripts/e2e-credentials.py --keep` |
| Seed P3 matching data | `bash scripts/p3-smoke.sh` |
| Seed P4 payment data | `bash scripts/p4-smoke.sh` |
| List Flutter devices | `flutter devices` |
| Run Flutter auth tests | `cd mobile && flutter test integration_test/auth_test.dart --device-id "iPhone 17 Pro"` |
| Run all Flutter integration tests | `cd mobile && flutter test integration_test/ --device-id "iPhone 17 Pro"` |
| Run Playwright (all) | `cd web && npm run test:e2e` |
| Run Playwright (interactive) | `cd web && npm run test:e2e:ui` |
| Run one Playwright spec | `cd web && npx playwright test e2e/credentials.spec.ts` |
| Show Playwright HTML report | `cd web && npm run test:e2e:report` |
| Run render-probe (payouts queue) | `python3 scripts/web/render-probe.py --page features/payouts/pages/PayoutQueue --fixture scripts/web/fixtures/payouts/queue.json` |
| Run render-probe (payout batches) | `python3 scripts/web/render-probe.py --page features/payouts/pages/PayoutBatches --fixture scripts/web/fixtures/payouts/batches.json` |

---

## State each test needs

Mobile integration tests (P2–P7) **self-seed**: `FixtureHelper` drives a fresh
job through the real API (`create → match → offer accept → receipt → staff
verify → lifecycle`) and returns its ID, so no pre-seeded jobs or smoke-script
ordering is needed. The only prerequisites are the seeded **accounts** —
including a verified `tradie-verified` profile with rate + approved credential
(`seed-test-accounts.sh`) — and a healthy stack. `p3-smoke.sh`/`p4-smoke.sh`
remain useful for manual exploration only.

| Test scenario | Required state | How to seed |
|---|---|---|
| P1 auth tests | `unverified@fixo.test` not verified | `seed-test-accounts.sh` (automatic) |
| P1 credential queue | ≥ 1 Pending credential | `python3 scripts/e2e-credentials.py --keep` |
| P3–P7 mobile | Verified tradie profile + homeowner account | `seed-test-accounts.sh`; jobs created per-test by `FixtureHelper` |
| P4 payment queue (web) | ≥ 1 `PaymentReview` job | `bash scripts/p4-smoke.sh`, or the mobile payment fixture path |
| P6 refund queue | Job cancelled after payment | Run P5 partially, cancel from homeowner |
| P7 disputes | ≥ 1 Open dispute | Run matching/lifecycle tests, open dispute from mobile |
| **P10 payout queue** | ≥ 1 `TradiePayout(Status=Pending)` | Complete a job end-to-end (P3→P5); tradie must have bank details set via `PUT /api/profile` |
| **P10 payout batch** | Pending payouts + Hangfire batch job run | Create payouts first, then trigger `PayoutBatchJob` via `/hangfire` or wait for Monday 2 AM UTC |
| **P10 availability toggle** | `TRADIE-PAUSED` account (`IsAvailable=false`) | Create a tradie account and call `POST /api/profile/availability { "available": false }`, or set `IsAvailable=false` directly in DB |
| **P10 blind reviews** | `Completed` job with no second review | Complete any job end-to-end; submit only one review |
| **P10 licence matching** | Service with `RequiresLicence=true` + tradie with/without matching credential | Use a Plumbing/Electrical/Building service; ensure TRADIE-2 has (or lacks) the matching `Approved` PGDB/EWRB/LBP credential |
| **P11 purge** | Data older than retention threshold | Reduce retention values in `appsettings.Development.json` temporarily (e.g. `ChatRetentionMonths: 0`) and trigger `DataRetentionPurgeJob` via Hangfire |

---
## Dummy accounts

Auto-seeded demo accounts

 Created on API startup in Development ( backend/Services/DemoSeedService.cs ,  AdminSeedService.cs ; creds in  backend/app
 settings.Development.json ):

 ┌────────────────────┬──────────────┬────────────┬──────────────────────────────────────────────────────────┐
 │ Email              │ Password     │ Role       │ Notes                                                    │
 ├────────────────────┼──────────────┼────────────┼──────────────────────────────────────────────────────────┤
 │  homeowner@fixo.nz │  Demo1!Fixo  │ Homeowner  │ "Sarah Mitchell" — seeded with jobs, chat, reviews       │
 ├────────────────────┼──────────────┼────────────┼──────────────────────────────────────────────────────────┤
 │  tradie@fixo.nz    │  Demo1!Fixo  │ Tradie     │ "James Ruru" / Ruru Plumbing Ltd, verified, Auckland CBD │
 ├────────────────────┼──────────────┼────────────┼──────────────────────────────────────────────────────────┤
 │  admin@fixo.nz     │  Admin1!Fixo │ Superadmin │ For the React admin web dashboard                        │
 └────────────────────┴──────────────┴────────────┴──────────────────────────────────────────────────────────┘

 Integration test accounts

 Created by  scripts/seed-test-accounts.sh  (run with  docker compose up -d  first, then  bash scripts/seed-test-accounts.s
 h  — idempotent):

 ┌────────────────────────────┬────────────┬───────────────────────────────────────────────────────────────┐
 │ Email                      │ Password   │ Purpose                                                       │
 ├────────────────────────────┼────────────┼───────────────────────────────────────────────────────────────┤
 │  homeowner-a@fixo.test     │  Test1234! │ Homeowner, email verified                                     │
 ├────────────────────────────┼────────────┼───────────────────────────────────────────────────────────────┤
 │  tradie-verified@fixo.test │  Test1234! │ Tradie, verified, approved License credential, $85.50/hr rate │
 ├────────────────────────────┼────────────┼───────────────────────────────────────────────────────────────┤
 │  unverified@fixo.test      │  Test1234! │ Homeowner with unverified email — tests the OTP gate (P1-06)  │
 ├────────────────────────────┼────────────┼───────────────────────────────────────────────────────────────┤
 │  staff@fixo.test           │  Test1234! │ Staff account for admin web — created via superadmin invite   │