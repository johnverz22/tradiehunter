# TradieHunter — Running Tests

Automated layers; the manual release pass is [QA.md](QA.md). Commands assume macOS + OrbStack, Flutter on the host, `dotnet` only inside the `api` container.

## Prerequisites

| What | Check |
|---|---|
| Stack up | `docker compose ps`: api, db, redis, azurite healthy |
| Flutter SDK | `flutter --version` |
| Node ≥ 20 | `node --version` |
| Playwright | `ls web/node_modules/@playwright/test` |
| `integration_test` | `grep integration_test mobile/pubspec.yaml` |

Seed accounts after a fresh DB (idempotent), then credential data for the admin queue:

```sh
bash scripts/seed-test-accounts.sh
python3 scripts/e2e-credentials.py --keep
```

## Unit and widget tests

```sh
docker compose run --rm --entrypoint /bin/bash api -c "dotnet build && dotnet test"   # backend
cd mobile && flutter analyze && flutter test --reporter expanded                      # mobile
cd web && npx tsc -b && npx oxlint                                                    # web types + lint
```

Backend suites include `JobFlowTransitionTests` (one test per v2 edge), `JobMoneyTests`, `JobValidatorTests` and the email renderer/golden tests. Last recorded baseline (2026-11-09): `flutter test` 607/607, `flutter analyze` clean apart from pre-existing infos, `tsc -b` clean. **v1.7 has not been run through CI yet**; do that before flipping `JobFlow:Version`.

Mocked-font widget tests do not prove actual-font, golden, device, route or live-flow acceptance.

## Flutter integration tests (simulator)

```sh
cd mobile
flutter test integration_test/auth_test.dart --device-id "iPhone 17 Pro"
flutter test integration_test/ --device-id "iPhone 17 Pro"        # single-device flows
```

| Define | Purpose |
|---|---|
| `FIXO_API_URL` | API base (default `http://localhost:5000`; Android emulator `http://10.0.2.2:5000`) |
| `FIXO_PERSONA=homeowner\|tradie` | Which role runs in two-device suites |
| `FIXO_DISABLE_PUSH=true` | Skip the iOS notification prompt so it can't stall tests or screenshots |

**Two-device suites** (`matching_test`, `job_lifecycle_test`, `cancellation_test`): start the homeowner simulator, wait for "Xcode build done", then start the tradie simulator with a different device ID (two simultaneous iOS builds share `mobile/build` and the second fails). Each side self-seeds fixture jobs through the API (`helpers/fixture_helper.dart`).

**Running the suites (recommended):** `scripts/run-e2e.sh` runs suites sequentially and prints a pass/fail summary. The app is v2-only; a config just picks the persona(s). See `docs/todos/03_e2e_realignment_plan.md` §5.

**Integrated journey gate.** Before any device suite, `run-e2e.sh` runs `scripts/e2e-journey.py` (stdlib Python, no device): one job goes post → match → tradie accepts → chat both ways → check-in → check-out → homeowner approves → receipt → staff verify → Completed → review, with both personas reading the same job. It follows the v2 or v1 path from the job's `flowVersion`, like `FixtureHelper`. If it fails, the run stops (exit 1, or 2 when the stack/accounts are missing), because fixture-based suites would all fail in setUp for the same reason (the E1 baseline finding). Use `--no-journey` to skip it. It writes `journey.xml` (JUnit) next to the logs. With persona-manifest runs, `e2e-journey.py --manifest M --scenario competing-quotes|all` adds the project-quote competition scenario (needs 3 tradies). `run-e2e.sh` also un-parks the demo tradie on exit/Ctrl-C, since an aborted suite skips `tearDownAll`.

```sh
export E2E_DEVICE="<id from: scripts/run-e2e.sh --list-devices>"
export E2E_TRADIE_DEVICE="<second simulator id>"   # optional
scripts/run-e2e.sh C0 --seed        # homeowner + tradie personas
scripts/run-e2e.sh C1               # homeowner persona (the §4.4 gate)
scripts/run-e2e.sh C2               # tradie persona
scripts/run-e2e.sh J                # integrated homeowner+tradie API journey only (no device)
scripts/run-e2e.sh FABRIC           # persona fabric: personas -> API (7 scenarios) -> mobile -> web
scripts/run-e2e.sh C1 --fail-fast --retry 1   # stop on first red; retry once (FLAKY if it then passes)
```

**Persona fabric (`FABRIC`):** `scripts/e2e-personas.py` provisions fresh `qa+<runid>-<role>-<n>@fixo.test` accounts via real signup + MailHog OTP + staff-approved credentials and writes `manifest.json` (`personas[]`, `jobs[]`). `scripts/run-e2e.sh FABRIC` passes that manifest to `e2e-journey.py --scenario all` (7 scenarios: `happy-path`, `competing-quotes`, `hourly-decline-reoffer`, `withdraw-no-match-repost`, `cancellations`, `receipt-reject-resubmit`, `dispute-attachments-reviews`), `mobile/integration_test/persona_fabric_test.dart` (skipped if `E2E_DEVICE` is unset), and `web/e2e/persona-fabric.spec.ts` (`E2E_MANIFEST`). Supports `--fail-fast`, `--retry N`, `--timeout S`, `--cleanup`.

The v2 Booked cancel sheet has no "Keep job" button; `cancellation_test` dismisses it by tapping outside the sheet.

| File | Covers |
|---|---|
| `auth_test` | login, OTP, signup |
| `job_request_test` | post job |
| `matching_test` | offers, accept/decline |
| `payment_test` | receipt upload, status |
| `job_lifecycle_test` | check-in → confirm → review |
| `cancellation_test` | cancel sheet, penalties, flag warning |
| `dispute_test` | open dispute, evidence |

Helpers: `test_config.dart` (URL, accounts, timeouts), `auth_helper.dart`, `api_helper.dart`, `fixture_helper.dart` (`requestedJob()` … `completedJob()`, `parkCompetingTradies()`).

**Gaps:** `job_request_test`, `job_lifecycle_test` and `payment_test` still describe the v1 order and must be updated for flow v2 (P12-28). No automated mobile tests exist for P10 features (availability, blind reviews, bank details, photo limits). `screenshots_test.dart` drivers also live in `integration_test/`; run functional files explicitly rather than sweeping the directory.

## Admin web (Playwright)

```sh
cd web
npm run test:e2e              # headless, starts Vite
npm run test:e2e:ui           # interactive
npx playwright test e2e/credentials.spec.ts
npm run test:e2e:report
```

Specs: `auth`, `credentials`, `payments`, `refunds`, `disputes`, `users`. Login state is saved once by `e2e/fixtures/auth.setup.ts` (staff account) to `e2e/.auth/staff.json` (gitignored; delete if the token expires). On CI set `VITE_API_URL=http://localhost:5000`. **No `payouts.spec.ts` yet**; the SLA column and URGENT badge are best asserted in `payments.spec.ts` by injecting `minutesSinceSubmission`.

## Verification scripts

| Script | Verifies | Needs |
|---|---|---|
| `scripts/web/render-probe.py` | A React page's rendered HTML against a JSON fixture (19 fixtures passing at last run) | `web/node_modules`, node |
| `scripts/e2e-credentials.py` | Credential-review API end to end incl. DB state; cleans up after itself (`--inspect`, `--keep`) | stack up |
| `scripts/e2e-demo.py` | Recordable three-POV walkthrough | stack, 2 iOS sims, Playwright Chromium |
| `scripts/p3-smoke.sh`, `p4-smoke.sh` | Offer flows; payment data seeding (manual exploration only) | stack |
| `scripts/p12-smoke.sh` | Full v2 flow: post → pick → accept → in progress → adjust → complete → approve → pay → verify → payout | stack, `JobFlow:Version=2` |
| `scripts/address-resolution-tests`, `flutter test test/address_resolution_test.dart` | LINZ resolver contract and client behaviour | LINZ key (server) |

`render-probe` renders a page with React, React Query and a `MemoryRouter` via `vite build --ssr`, stubs `localStorage` and the axios adapter, seeds the query cache under the page's own query key (`prefetch`), and asserts `expect` needles against the HTML (React's `<!-- -->` separators stripped). Example: `python3 scripts/web/render-probe.py --page features/credentials/pages/CredentialQueue --fixture scripts/web/fixtures/credentials/multi-page.json`. `--keep` leaves `web/.probe/` for debugging. Exit code is non-zero on failure, so it is CI-safe. `scripts/one-off/` holds spent helper scripts kept for provenance only.

## Seed data and accounts (dev only)

Auto-seeded on API startup in Development (`DemoSeedService`, `AdminSeedService`; credentials in `appsettings.Development.json`):

| Email | Password | Role |
|---|---|---|
| `homeowner@fixo.nz` | `Demo1!Fixo` | Homeowner "Sarah Mitchell" with jobs, chat, reviews |
| `tradie@fixo.nz` | `Demo1!Fixo` | Tradie "James Ruru" / Ruru Plumbing Ltd, verified, Auckland CBD |
| `admin@fixo.nz` | `Admin1!Fixo` | Superadmin |

From `seed-test-accounts.sh` (all password `Test1234!`): `homeowner-a@fixo.test` (verified), `tradie-verified@fixo.test` (verified, approved licence, $85.50/hr, **no bank details**), `unverified@fixo.test` (OTP gate), `staff@fixo.test`. Create by hand: a second verified tradie, a paused tradie (`POST /api/profile/availability {"available": false}`), and bank details via `PUT /api/profile` for payout tests. The `@fixo.*` domains are test identifiers and stay.

## State each test needs

| Scenario | Required state |
|---|---|
| Credential queue | ≥ 1 Pending credential (`e2e-credentials.py --keep`) |
| Payment queue | ≥ 1 job in `PaymentReview` (v2: reached after homeowner approval) |
| Refund queue | Job cancelled after payment (legacy flow) or dispute resolved for homeowner |
| Disputes | ≥ 1 Open dispute |
| Payout queue | ≥ 1 `Pending` payout (complete a job; tradie needs bank details) |
| Payout batch | Pending payouts, then trigger `PayoutBatchJob` in `/hangfire` or wait for Monday 02:00 UTC |
| Blind reviews | Completed job with only one review submitted |
| Licence matching | Regulated service + tradie with and without an Approved matching credential |
| P11 purge | Not built; nothing to test |

## CI

GitHub Actions (`.github/workflows/ci.yml`) builds and tests backend and mobile. For Playwright on CI install browsers (`npx playwright install --with-deps chromium`) and set `VITE_API_URL`.

## Regression gate (design system)

Every PR runs, in CI, the same three checks you should run locally before pushing:

```sh
node docs/design/mobile/tools/build.mjs --check   # tokens, screens, WCAG contrast, stale outputs
cd mobile && dart format --set-exit-if-changed lib test integration_test
cd mobile && flutter analyze --fatal-infos && flutter test
```

Goldens live in `mobile/test/ui/goldens/`; regenerate with `flutter test --update-goldens test/ui` and review the diff by eye. **Regenerate only on the Flutter version pinned in `.github/workflows/ci.yml` (3.47.9).** `gallery_goldens_test.dart` tolerates up to 1% differing pixels so local runs on another patch version (text anti-aliasing) don't fail; bump the CI pin and the baselines together.
