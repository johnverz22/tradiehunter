# E2E Persona Fabric: one manifest, three tiers

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Turn the current single-journey E2E/QA coverage into a realistic, automated functional test across the API, mobile (Flutter) and web admin (React) tiers. All three tiers exercise the **same users and jobs**, provisioned once per run.
> **Status:** P0–P6 complete (P2.9 and P3.6 parked by design; mobile device run in `FABRIC` gated on `E2E_DEVICE` simulator). · **Prepared:** 2026-11-26 · **Updated:** 2026-11-26
> **Naming rule:** code identifiers stay `Fixo`; user-facing text is TradieHunter. Do not rename.
> **Convention:** `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S <= 1h, M <= half a day, L >= 1 day.
> **Relationship to other plans:** extends `03_e2e_realignment_plan.md` (E6.6 integrated API journey gate is already merged). Update that file's status when this lands.

---

## 0. Read first

`docs/TESTING.md`, `docs/QA.md`, `docs/SPECS.md` (job state machine, v1/v2 payment flows), `docs/ai/AI-TOOLING.md`, `docs/MVP.md`, `scripts/e2e-journey.py`, `scripts/run-e2e.sh`, `scripts/web/render-probe.py`, `mobile/integration_test/helpers/fixture_helper.dart`.

Already present and relevant: `scripts/e2e-credentials.py`, `scripts/seed-test-accounts.sh`, and `web/e2e/*.spec.ts` with `@playwright/test ^1.49.1` in `web/package.json`. Playwright is therefore **not a new dependency**; still confirm with the owner before adding anything else (AGENTS.md).

## 1. Architecture

Provision fresh users **once per run** at the API tier and persist them to a run-scoped manifest (JSON: role, email, password, user id, created job ids). The mobile and web tiers consume that manifest, so all three tiers drive the same jobs end to end.

```
e2e-personas.py ──► manifest.json ──┬─► e2e-journey.py   (API tier)
                                    ├─► mobile (Maestro YAML or integration_test)
                                    └─► web admin (render-probe / Playwright)
```

## 2. Safety rules (apply to every task)

- Local docker stack only. **Refuse non-localhost `FIXO_API_URL`.**
- All job transitions go through real API routes. Never write DB rows directly or bypass `IJobStatusService`-backed endpoints.
- Money stays decimal. Assert decimal strings, never floats.
- Do not fabricate data the app cannot fetch.
- Preserve `--fail-fast`, `--retry`, timeout and cleanup flags on `run-e2e.sh`; give every new entry point the equivalent.
- No new third-party dependencies without asking.
- Anything blocked by a missing backend endpoint is **documented, not worked around**.
- Do not invent admin features beyond `docs/MVP.md`.

---

## Phase P0 — Recon (no code)

- [x] **P0.1** Read the docs listed in §0; note the cancellation rules, review-eligibility rules and dispute rules from `SPECS.md` that the scenarios below must encode (S)
  - Done: findings in *Decisions and parked items* §A-§G. Rules P2.6/P2.8 encode (`SPECS.md` §4, §8): any pre-Completed state -> `Cancelled` by homeowner/tradie/admin/system with a reason code, no refund in v2, non-monetary consequences only (flags); any active state -> `Disputed` by either party, admin resolves to `Completed` or `Cancelled`; reviews are blind (hidden until both submit or 7 days) and only after `Completed`; receipt reject = `PaymentReview -> AwaitingPayment`.
- [x] **P0.2** Determine how the API exposes signup and verification (email code, token, auto-verify in dev?) so `e2e-personas.py` can drive it for real (S)
  - Done: OTP via MailHog (§A), staff invite and tradie onboarding (§B).
- [x] **P0.3** Determine whether the API can still create **v1** jobs. If not, drop the v1 scenario and record why (S)
  - Done: v1 only via stack config, see §C. P2.9 parked.
- [x] **P0.4** Check which staff flows the mobile app exposes. If none, staff is API + web only (S)
  - Done: no staff UI in the mobile app, see §D. P3.6 parked.
- [x] **P0.5** Confirm from `docs/MVP.md` what the web admin covers in MVP scope: payments, disputes, users, jobs. Record the list; it bounds P4 (S)
  - Done: admin scope, see §E.
- [x] **P0.6** Inventory what `e2e-journey.py` hardcodes (`*@fixo.test` creds, seeded accounts) so P2 can switch it to manifest loading without breaking the single-journey gate (S)
  - Done: only `HOMEOWNER`/`TRADIE`/`STAFF` module constants, used by `run_journey`; `DEMO_TRADIE` parking is separate and stays.

## Phase P1 — Persona provisioning (`scripts/e2e-personas.py`, new)

- [x] **P1.1** CLI: `--homeowners N --tradies N --staff 1|2 --run-id ID --out PATH`; default run id is a timestamp slug (S)
- [x] **P1.2** Create accounts as `qa+<runid>-<role>-<n>@fixo.test` through real signup and verification as the API exposes it (M)
- [x] **P1.3** Complete any role onboarding the tradie needs to receive matches (profile, trade, service area, payout details if required by the API) (M)
- [x] **P1.4** Write the manifest JSON: role, email, password, user id, created job ids (job ids appended by later tiers) (S)
- [x] **P1.5** Namespacing is enough to leave data in the DB; add optional `--cleanup` that only touches `qa+<runid>-*` accounts via supported API routes (S)
- [x] **P1.6** Refuse non-localhost `FIXO_API_URL`; support `--timeout`, `--retry` (S)
- [x] **P1.7** `python3 -m py_compile scripts/e2e-personas.py` (S)
- [x] **P1.8** Run `scripts/e2e-personas.py` on the real local stack (`make docker`), fix whatever drifts from the mock (see §F risks), paste the output in the Results log (M)

## Phase P2 — API tier (extend `scripts/e2e-journey.py`)

- [x] **P2.1** Load personas from the manifest (`--manifest PATH`); keep the seeded-accounts path so the existing single-journey gate still works (M)
  - Done: first homeowner/tradie/staff of the manifest; job id appended on creation (`record_job`); a non-localhost `FIXO_API_URL` is now refused by the journey too; `run-e2e.sh` does not pass `--manifest` yet (P5.1).
- [x] **P2.2** Every step asserts the response **and** the resulting job via GET: status, history, exact-decimal amounts (M)
  - Done: `--match-mode auto|quick|direct`, `assert_booked`, `assert_completion_money`, `assert_payment_open`, `assert_payment_verified`, `assert_audit_trail`. Live-verified across all 7 scenarios.
  - **Correction to this plan's wording:** money is serialized as a JSON *number* (no string converter in the backend), so "decimal-string amounts" cannot be asserted literally. The journey parses responses with `Decimal`, which compares exactly without float rounding. `.NET` writes `85m` as `85`, so values can be int or Decimal; `dec()` normalises both.
- [x] **P2.3** Scenario: happy path v2 (live pass on jobs 400-402, 452, 462, manifest personas, direct request). post -> match -> offer -> accept -> book -> chat -> check-in -> check-out -> approve -> receipt -> staff verify -> complete -> review (M)
- [x] **P2.4** Scenario: competing offers (`competing-quotes` for Project jobs + `hourly-decline-reoffer` for sequential hourly decline-then-next-tradie). Live-verified; also fixed `JobFlowTransitions.IsValidV2` (`Requested -> Booked` for `UserRole.Homeowner` when accepting a project quote, verified by `JobFlowTransitionTests` 32/32) (M)
- [x] **P2.5** Scenarios: decline and withdraw paths; job with no matches; re-post (`hourly-decline-reoffer`, `withdraw-no-match-repost`, live-verified) (M)
- [x] **P2.6** Scenarios: cancellation by homeowner and by tradie, following the `SPECS.md` rules per state (`cancellations`, live-verified: tradie cancel `Booked -> Requested`, homeowner cancel `Booked -> Cancelled` and `InProgress -> Cancelled`) (M)
- [x] **P2.7** Scenario: staff rejects receipt -> homeowner resubmits -> staff verifies (`receipt-reject-resubmit`, live-verified) (M)
- [x] **P2.8** Scenarios: dispute open/resolve; chat in both directions; attachment upload; review eligibility rules (positive and negative cases) (`dispute-attachments-reviews`, live-verified) (L)
- [~] **P2.9** Scenario: v1 in-flight path. **Parked:** `JobFlow:Version` is a global stack setting stamped on each job at creation; the API cannot create a v1 job per request (§C). The existing journey already has the v1 branch; it runs only against a stack started with `JobFlow__Version=1` (M)
- [x] **P2.10** Append created job ids to the manifest so the mobile and web tiers can find them (`record_job`) (S)
- [x] **P2.11** JUnit XML output preserved; `--fail-fast`, `--retry`, `--timeout` preserved (S)
- [x] **P2.12** `python3 -m py_compile scripts/e2e-journey.py` (S)

## Phase P3 — Mobile tier (Flutter)

- [x] **P3.1** Choose the driver: `integration_test/` (`mobile/integration_test/persona_fabric_test.dart`) chosen over Maestro YAML because `mobile/lib/` currently only carries 2 `THTestId` hooks while `integration_test/` already has `Key`-based `auth_helper.dart` / `fixture_helper.dart` wired into `scripts/run-e2e.sh` (S)
- [x] **P3.2** Reuse existing `Key`s and `THTestId` ids without adding new hooks to `mobile/lib/` (S)
- [x] **P3.3** Add a manifest loader (`mobile/integration_test/helpers/manifest_helper.dart`, `E2E_MANIFEST` via `--dart-define` or env) (M)
- [x] **P3.4** Homeowner flow in `persona_fabric_test.dart` (logs in with manifest homeowner credentials, opens manifest `happy-path` job) (L)
- [x] **P3.5** Tradie flow in `persona_fabric_test.dart` (logs in with manifest tradie credentials, opens manifest `happy-path` job) (L)
- [~] **P3.6** Staff flow. **Parked:** the mobile app is Homeowner/Tradie only; Staff and Superadmin use the web admin (§D) (M)
- [x] **P3.7** Existing widget suite (`flutter test`, 620 tests) covers light and dark themes across v2 screens; `persona_fabric_test.dart` asserts behaviour, not pixels (M)
- [x] **P3.8** Documented: `run-e2e.sh FABRIC` runs `persona_fabric_test.dart` when `E2E_DEVICE` is set to a booted simulator/emulator (skipped with reason when unset); physical device only required for real APNs/FCM push or camera hardware (S)
- [x] **P3.9** `flutter analyze --fatal-infos` (0 issues) and `flutter test` (620/620 passed) (S)

## Phase P4 — Web admin tier (React)

- [x] **P4.1** Choose the harness: existing Playwright setup (`web/e2e/`, `@playwright/test ^1.49.1`, no new dependencies) (S)
- [x] **P4.2** Add manifest loading for the web tier (`web/e2e/persona-fabric.spec.ts` via `E2E_MANIFEST`) (S)
- [x] **P4.3** Staff persona logs into admin and verifies API-created jobs, payment queue, and user detail (M)
- [x] **P4.4** Assert job (`Completed`, personas, chat transcript) and user state (`email`) in the UI matches the API on rendered markup (M)
- [x] **P4.5** Dispute resolution verified on `/disputes/{jobId}` (`Resolved`) (M)
- [x] **P4.6** `npm run lint` (0 errors), `npm run build` (clean), and `persona-fabric.spec.ts` (passed) (S)

## Phase P5 — Orchestration (`scripts/run-e2e.sh` and friends)

- [x] **P5.1** Add `FABRIC` config to `scripts/run-e2e.sh`: personas -> API -> mobile -> web, passing `$MANIFEST` between tiers (M)
- [x] **P5.2** Preserve `--fail-fast`, `--retry`, `--timeout`, `--cleanup` across `run-e2e.sh`, `e2e-personas.py`, and `e2e-journey.py` (S)
- [x] **P5.3** Per-tier result summary (`PASS`/`FAIL`/`SKIP` with reason) printed and written to `$LOG_DIR/summary.txt` (S)
- [x] **P5.4** `bash -n scripts/run-e2e.sh` (passed) (S)

## Phase P6 — Docs and verification

- [x] **P6.1** Update `docs/TESTING.md` (new scripts, manifest format, `FABRIC` config) (S)
- [x] **P6.2** Update `docs/QA.md` (what the fabric covers; what is still manual) (S)
- [x] **P6.3** Update `docs/todos/03_e2e_realignment_plan.md` status and cross-link this plan (S)
- [x] **P6.4** `docs-sync`: no SPECS/MVP behaviour changed (S)
- [x] **P6.5** `python3 -m py_compile` (`e2e-personas.py`, `e2e-journey.py`), `bash -n scripts/run-e2e.sh`, `flutter analyze --fatal-infos` + `flutter test`, `web` `npm run lint` + `npm run build`, `dotnet test --filter JobFlowTransitionTests` all passed (S)
- [x] **P6.6** Run the **full pipeline once against the seeded local stack** (`bash scripts/run-e2e.sh FABRIC --fail-fast`) and paste the per-tier results below (M)
- [x] **P6.7** Documented parked/blocked items: `P2.9` (v1 requires `JobFlow__Version=1` stack restart), `P3.6` (no staff mobile UI by design), `P3.8` (`mobile` tier skipped when `E2E_DEVICE` is unset) (S)

---

## Definition of done

All three tiers run from one manifest against the local stack, per-tier results are recorded below, every compile/lint/analyze check in P6.5 passes, docs are updated, and blocked items are documented.

## Results log

**P1.8 first live run (2026-11-26, local docker stack + MailHog):**

- `e2e-personas.py` failed at `POST /admin/staff/set-password` ("Invalid token"). Cause: the staff-invite token only appears in the HTML token box when no `FrontendBaseUrl` activation URL is configured; the script read only the `text/plain` part and its longest-word fallback grabbed `support@tradiehunter.nz`. Fixed: `wait_for_mail(..., include_html=True)` + a base64url-charset filter in `invite_token_from`.
- Second run provisioned all 6 accounts but `e2e-journey.py --manifest` timed out at "tradie receives offer". Cause: `pick_service_id` took `services[0]` (id 4, Electrician) for rates and `tradeType` was hardcoded `"Plumbing"`; matching requires `TradeType == TradeCategory` enum name (`"Plumber"`) and a rate on `job.ServiceId`. Manifest tradies were invisible to matching. Fixed: default service id 1 and `tradeType` taken from the service's `category`.
- Third run: personas provision all 6 accounts cleanly (`test-logs/e2e-personas-1126054310/manifest.json`, serviceId 1 / tradeType Plumber); manifest tradies now appear in `/jobs/{id}/matches`. Journey still fails at "tradie receives offer" (45 s poll): sequential dispatch offers the top-ranked candidate first, and seeded `tradie-verified@fixo.test` (rating 5.0, 10 reviews) outscores the unrated QA tradies, so the pending offer sits with the seeded tradie for its 10-minute window. This is the §F predicted outcome — P2.2 should switch manifest runs to direct requests (`POST /jobs/{id}/request {tradieId}`, `CreateDirectRequestAsync`).

**Verification of the P1.8 fixes (2026-11-26, offline):** `invite_token_from` returns the base64url token from a body that also contains `support@tradiehunter.nz` and a URL, still handles `?token=` (URL-decoded), and raises `StepFailed` when no token-shaped word exists. Direct-request journey tested on a mock (see P2.2); the real-stack re-run of `e2e-journey.py --manifest` after this change is the next thing to do.

**P2.2 direct-request live run (2026-11-26, local docker stack + MailHog):** `e2e-personas.py` run `1126055601` provisioned all 6 accounts (`test-logs/e2e-personas-1126055601/manifest.json`, credentials 70-72, serviceId 1 / Plumber); `e2e-journey.py --manifest` with the default `auto` match mode took the direct-request path (`POST /jobs/{id}/request`, tradie id from `GET /profile`) and the full journey passed on job 400 in ~1s — offer received, accepted, checked in/out, itemised approval, receipt, staff verify, completed and reviewed. The §F seeded-tradie offer conflict is bypassed for manifest runs. Remaining P2.2 work: per-step assertions on job status, history and decimal-string amounts.

**P2.2 assertions live run (2026-11-26, local docker stack):** `e2e-journey.py --manifest test-logs/e2e-personas-1126055601/manifest.json` (run `ac1d6e5`, job 401) passed with all new assertions green: post-booking `flowVersion`/`matchedTradieId`/`matchedTradieName`/`hourlyRate`, post-checkout `finalHours`/`finalAmount`/`totalAmount` exact-decimal checks, and staff admin `statusHistory` ordering + `chatTranscript`. DTO field names match the live payloads. Sample `GET /jobs/{id}/payment` captured for the remaining payment-amount assertions: `{paymentId, jobId, jobTitle, jobStatus, amount (JSON number), currency, method, provider, reference, status, bankDetails, dueAtUtc, submittedAtUtc, verifiedAtUtc, rejectReason, reUploadCount, createdAtUtc, canUploadReceipt}` — e.g. job 401: amount 170.0, status Verified, reference TH-401.

**P2.2 payment-assertions live run (2026-11-26, local docker stack):** `e2e-journey.py --manifest test-logs/e2e-personas-1126055601/manifest.json` (run `4bd1c7e`, job 402) passed end-to-end including the new payment checks. Printed line: `payment open: amount == finalAmount, reference (payment 170.00 NZD, status 'Pending', canUploadReceipt=True)` — pre-verification status is `Pending`; after staff verify the payment is `Verified` with `canUploadReceipt=False`. P2.2 journey coverage is now fully live-verified.

**P6.6 full FABRIC pipeline run (2026-11-26, local docker stack + MailHog, `bash scripts/run-e2e.sh FABRIC --fail-fast`):**

```text
PASS     personas  (/Users/john/Develop/tradies/test-logs/e2e-FABRIC-20261126-142630/manifest.json)
PASS     api       (7 scenarios)
SKIP     mobile    (E2E_DEVICE not set)
PASS     web       (persona-fabric.spec.ts)
```

- `e2e-personas.py` provisioned 6 accounts (`qa+1126062630-*@fixo.test`, credentials 76–78 approved).
- `e2e-journey.py --scenario all` passed all 7 scenarios in 2s (jobs 462, 463, 464, 466, 469, 470, 471).
- `web/e2e/persona-fabric.spec.ts` logged in as the manifest staff persona and verified `/jobs/462`, `/payments`, `/disputes/471`, and `/users/{homeownerId}` in 4.3s.
- `mobile` was skipped cleanly because `E2E_DEVICE` was unset (no booted simulator).

## Decisions and parked items

### P0 findings (2026-11-26, from reading code and docs)

**A. Signup and verification.** `POST /auth/register` returns `{RequiresVerification, Email}` and emails a 6-digit OTP (10 min lifetime, stored hashed, so it cannot be read from the DB or API). `POST /auth/verify-email {email, code}` returns the JWT. The dev stack sends mail to MailHog (`docker-compose.yml`, `EmailSender__Host: mailhog`); its HTTP API (`:8025`, `/api/v2/search?kind=to&query=`) is how the script reads the code. Subject is `Your TradieHunter verification code` (`EmailSubjects.Otp`). Registering a tradie creates a `TradieProfile` stub with `TradeType = "General"`.

**B. Staff and tradie onboarding without DB writes.** Staff: superadmin `POST /admin/staff/invite` -> token in the invite email (`?token=` link in the templated mail, bare token in the legacy mail) -> `POST /admin/staff/set-password`. Tradie: `PUT /profile` (fields `phoneNumber`, `tradeType`, address, lat/lng, `serviceRadiusKm`, `isAvailable`), `POST /tradie/rates {rates:[{serviceId, hourlyRate}]}`, `POST /tradie/credentials` (multipart `file` + `type`; JPEG/PNG/PDF), then `POST /admin/credentials/{id}/review {status:"Approved"}` by staff. MVP rule: verified while holding >= 1 approved credential, so `/profile.isVerified` must turn true; the script fails if it does not. `scripts/seed-test-accounts.sh` instead flips `EmailVerified`/`IsVerified` in the DB, which the fabric must not do.

**C. v1 vs v2.** `JobFlow:Version` (both `appsettings.json` and `appsettings.Development.json` = 2) is stamped on each job at creation by `JobService`. There is no per-request override, so v1 jobs exist only when the stack runs with `JobFlow__Version=1`. P2.9 parked; `docs/QA.md` ENV-07 already assumes v2.

**D. Staff in the mobile app.** None. `auth_viewmodel.dart`: "Mobile users are always Homeowner or Tradie; Staff/Superadmin log into the web admin." Staff steps (receipt verify, credential review, dispute resolution) happen through the API tier and the web tier only. Mobile tests must not try to log in as staff.

**E. Web admin scope (`docs/MVP.md` line 32, `SPECS.md` admin section).** Dashboard, users + flags, credential queue, payment queue (v2 rows show itemised amount and completion date), refund queue (legacy flow only), payout queue + batches, disputes, audit/settings, job detail with progress stepper; superadmin-only: staff invites, Hangfire. P4 may assert on payments, disputes, credentials, users and job detail; refunds only for post-payment dispute outcomes. Existing Playwright specs in `web/e2e/` (auth, credentials, disputes, job-progress, payments, payouts, refunds, responsive) are the starting point.

**F. Risks to check on the first live run (P1.8).**
- `phoneNumber` validator and the `tradeType` vs service-category matching were not visible from the code read; the first live run shows if `PUT /profile` rejects `+6421900001` or if matching ignores a tradie whose `tradeType` (`Plumbing`) does not fit the chosen service. Script picks the first id from `GET /tradie/services` and falls back to 1.
- OTP and invite subjects are matched by substring (`verification code`, `invited`); a copy change in `EmailSubjects` breaks provisioning with a clear "no MailHog message" error.
- `seed-test-accounts.sh` sends `phone` and `tradeCategory`, but `ProfileUpdateDto` names are `phoneNumber` and `tradeType`; unknown JSON fields are ignored, so the seeded tradie may keep `TradeType = "General"`. Not changed here (out of scope), worth fixing separately.
- Seeded `tradie-verified@fixo.test` and the demo tradie share the Auckland location; `e2e-journey.py` still parks the demo tradie. Quick match offers one top candidate at a time, so with manifest tradies the offer may go to a seeded tradie instead of `personas[tradie 1]`; if so, the journey's `offers/pending` poll will time out and P2.2 should switch to direct requests (`POST /jobs/{id}/request {tradieId}`).
- Bank details for tradie payouts are not provisioned; P4.5 payouts and any payout assertion need them (open question: is there a test-safe way through `PUT /profile` `bankAccount*`?).

**G. Competing offers (affects P2.4).** `SPECS.md` §3: an hourly job allows one pending direct request (409 otherwise), and Quick match offers the top candidate then the next on decline/timeout; `MVP.md` lists "parallel offers for hourly jobs" as out of scope. True competition exists only for **projects**: up to 3 concurrent quote requests, 72 h window, accepting one declines the rest atomically. The brief's "2+ tradies bid on one job" is therefore a project-quote scenario, which needs >= 3 tradies in the manifest (default is 3).
