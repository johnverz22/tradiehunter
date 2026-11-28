# E2E Flow Unification: one recordable flow per feature, everything else folded in or retired

> **Repo / branch:** `johnverz22/tradiehunter` @ `main` (there is no `dev` branch on the remote; remote branches are `main`, `feat/admin-user-detail`, `fix/e2e-findings`, and the latter two have no commits ahead of `main`)
> **Purpose:** Replace today's six overlapping E2E layers with a single set of **demo-grade, independently recordable flows**, one per developed feature (hourly booking, project booking, disputes, extra cost, homeowner search, tradie verification, chat, schedule, sign up, profile setup, and so on). Flows compose into one master tour. Anything that is not a flow is either folded into one or deleted.
> **Status:** Approved. **U0 done except U0.4 (needs the owner's machine); U1 done; U2 in progress.** Decisions in section 2 and the former open items (section 7) are owner-confirmed. · **Prepared:** 2026-11-28
> **Naming rule:** code identifiers stay `Fixo`; user-facing text is TradieHunter. Do not rename.
> **Convention:** `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S <= 1h, M <= half a day, L >= 1 day.
> **Relationship to other plans:** supersedes the runner and layout parts of `03_e2e_realignment_plan.md` and builds on `08_e2e_persona_fabric_plan.md` (persona fabric + manifest stay as the foundation). Update both files' status headers when this lands. Quote scenarios come from `10_homeowner_quotes_visibility_plan.md`.

---

## 0. Read first

`docs/TESTING.md`, `docs/SPECS.md` (job state machine, v2 payment flow, cancellation, dispute and review rules, s362F), `docs/MVP.md` (admin scope), `AGENTS.md` (ask before adding dependencies), `docs/todos/08_e2e_persona_fabric_plan.md` (sections 1, 2 and the Decisions appendix).

Code to read before P1: `scripts/e2e-demo.py`, `scripts/e2e-demo/admin_pov.mjs`, `scripts/e2e-personas.py`, `scripts/e2e-journey.py`, `scripts/run-e2e.sh`, `mobile/integration_test/demo_tour_test.dart`, `mobile/integration_test/helpers/{demo_helper,manifest_helper,fixture_helper,auth_helper,api_helper}.dart`.

## 1. Findings (the current state)

### 1.1 Six layers, one purpose

| Layer | Files | Verdict |
|---|---|---|
| **A. Demo tour** | `scripts/e2e-demo.py` (761 lines), `demo_tour_test.dart` (555), `e2e-demo/admin_pov.mjs` (301), `helpers/demo_helper.dart` | **Keep and split.** This is the recordable target. It is one monolith with one hourly direct-request path plus a dispute branch. |
| **B. API journey** | `scripts/e2e-journey.py` (1555 lines, 10 scenarios) | **Fold.** Scenarios become the pre-roll and post-assertions of flows. The money, audit-trail and state-machine assertions are valuable and must survive. |
| **C. Persona fabric** | `scripts/e2e-personas.py` (593) | **Keep.** Foundation for every flow. |
| **D. Flutter `integration_test`** | 10 suites (`auth`, `job_request`, `payment`, `dispute`, `cancellation`, `job_lifecycle`, `matching`, `v2_flows`, `live_chat`, `persona_fabric`) | **Fold.** Mostly screen-in-isolation checks driven by API fixtures; overlaps B. Their assertions move into flow scenes. |
| **E. Web Playwright** | 15 files in `web/e2e` | **Fold.** Admin-only, mostly page-load checks. Admin steps become admin scenes inside flows. |
| **F. Maestro** | 17 YAML flows in `.maestro/` | **Retire.** Not referenced in `TESTING.md` or CI; the fabric plan already chose `integration_test` over Maestro. Map `08_onboarding.yaml` to the profile-setup flow first. |

Runner: `scripts/run-e2e.sh` (configs `C0/C1/C2/J/FABRIC`). CI: `.github/workflows/e2e-mobile.yml` (nightly Android, noted as untested on CI).

### 1.2 Out of scope (kept, but separated)

- **Documentation-capture suites:** `screenshots_test.dart`, `screenshots_device_test.dart`, `screenshots_fixup_test.dart`, `screenshots_variants_test.dart`, `scripts/run-shots.sh`, `run-device-sweep.sh`, `mk-*-fixtures`, `compare-shots.py`, `check-*.py`, `web/e2e/admin-shots.mjs`, `p3/p4/p12-smoke.sh`. These produce design/QA captures, not flow E2E. Leave them where they are and document the boundary in `TESTING.md`.
- `scripts/one-off/` (dead patch scripts): unrelated, do not touch here. Flag to the owner for a separate cleanup.
- `web/e2e/responsive.spec.ts`: a layout check, not a flow. Park with the capture suites (see P7.4).

### 1.3 Coverage gaps the new flows must close

Zero or isolated coverage today: **change schedule** (backend `POST/GET /jobs/{id}/schedule`, `/tradie/schedule`, `th_schedule_sheet.dart`), **homeowner search/browse** (`/find-tradie`, `/categories`, `ho_browse_tradies_screen`, `/tradie/:id`), **project booking on a recordable screen** (quotes are API-only), **extra-cost adjustments** (`POST/GET /jobs/{id}/adjustments`, respond, withdraw, evidence; `ho_extra_cost_screen`, `tr_extra_cost_page`), **real signup + OTP on device** (only in the API fabric), cancellation, receipt reject/resubmit, blocks and reports, notifications, earnings, availability, messages list, open job board, tradie quote sheet.

### 1.4 Known blockers

- **`LINZ_API_KEY`:** available in `.env` (owner confirmed). Flows use native address lookup and the native post-job form. The old "direct request because the form needs LINZ" workaround goes away for flows that post jobs. Keep a documented API fallback only if the key is missing, and say so in the run report.
- **Native photo picker:** cannot be driven by `integration_test`. Photo and credential uploads stay an API step, listed in the run report as a native gap (rule from `08`: documented, not worked around). P8.2 investigates only whether an existing, already-present mechanism can cover it.
- **No Docker, Flutter or Xcode in the planning sandbox:** every task below that runs the stack is verified by the owner on their machine. The implementer reads, restructures and writes, and states what was and was not run.

## 2. Decisions (owner-confirmed)

1. **Platform:** iOS simulators only for now. Android is a later phase (P9), not designed away: keep device ids and `10.0.2.2` rewriting from `run-e2e.sh` in the shared lib.
2. **Scope of unify:** fold layers B, D, E into flows and retire F. The result is flows plus the unchanged capture suites. No separate fast non-visual tier.
3. **LINZ key:** available via `.env`; flows use native address entry.
4. **Granularity:** one flow per feature, **independently recordable**, plus a `tour` that composes them.
5. **Quote price change** is the extra-cost adjustment mechanism (`/jobs/{id}/adjustments*`). There is no separate quote-revision path.
6. **Variants are separate flows**, not scenes inside a parent flow. The owner's list is not exhaustive; flows are added wherever developed features lack one (see 4.1-4.3).
7. **The `tour` includes every flow.**
8. **CI:** `e2e-mobile.yml` is replaced, not kept, so the repo has one unified suite (U7.7).
9. **Token rotation:** the owner will rotate the pasted PAT later; not a task here.

## 3. Target architecture

```
scripts/e2e/
  run.py                 # the ONLY entry point: run.py <flow>... | --all | --tour | --list
  lib/
    stage.py             # signal server, Show/timeline, captions, pace, --record, --capture-sims
    sims.py              # simulator pick/boot/arrange, build with timeout
    fabric.py            # provision/reuse/cleanup manifest via e2e-personas.py
    api.py               # http/login/poll/upload helpers (from e2e-journey.py)
    asserts.py           # decimal money, status order, audit trail (from e2e-journey.py)
    report.py            # run report, native-gap list, JUnit
  flows/
    <flow_id>.py         # declares actors, persona needs, pre-roll, post-asserts

mobile/integration_test/
  flows/<flow_id>_flow_test.dart     # homeowner() / tradie() scene functions per flow
  scenes/                            # reusable scenes: login, post_job, accept_offer, chat, pay, review...
  helpers/                           # existing helpers, trimmed

web/e2e/flows/<flow_id>.mjs          # admin scene(s) for that flow (headed Chromium)
```

**Flow contract (every flow must meet all of these):**
- Runs alone: `python3 scripts/e2e/run.py booking_hourly` provisions or reuses its own minimal personas, plays, cleans up.
- **Pre-roll before recording** builds only the state the flow does not show (existing pattern from the dispute scene's `_bookedJob`), through real API routes. Recording starts after pre-roll.
- Declares which actors it needs (homeowner / tradie / admin) and starts only those, so single-actor flows record one simulator.
- Ends with post-assertions through the API (status path, decimal amounts, audit markers). A flow that plays without asserting is not done.
- Pace, captions, cursor, `--record`, `--capture-sims`, `--manifest`, `--keep-accounts`, `--cleanup`, `--only-preflight`, `--fail-fast`, `--retry`, `--timeout`, `--pace`, `--theme` all keep working from the single CLI.
- `tour` runs the flows in a fixed order on one fabric run with no duplicated scene code.

**Safety rules (from `08`, still binding):** local stack only (refuse non-localhost `FIXO_API_URL`); all transitions through real API routes, never DB writes; money is decimal strings; do not fabricate data the app cannot fetch; no new third-party dependencies without asking; anything blocked by a missing backend endpoint is documented, not worked around; do not invent admin features beyond `docs/MVP.md`.

## 4. Flow catalog

Actors: **H** homeowner (iOS sim), **T** tradie (iOS sim), **A** admin (headed Chromium). "Absorbs" lists the old tests whose assertions must move into the flow.

### 4.1 Core booking

| Flow id | Story | Actors | Absorbs |
|---|---|---|---|
| `booking_hourly` | Post hourly job (native address) -> quick match / radar -> tradie accepts offer -> check-in -> check-out -> approve itemised amount -> bank-transfer receipt -> admin verifies -> review -> payout | H T A | journey `happy-path`; `matching_test`, `job_request_test`, `job_lifecycle_test`, `payment_test`; current demo main path |
| `booking_hourly_direct` | Request a specific tradie from their profile, countdown, accept | H T | demo's current direct-request path |
| `booking_hourly_reoffer` | Tradie declines -> re-offer to the next; post with no match -> withdraw -> repost | H T | journey `hourly-decline-reoffer`, `withdraw-no-match-repost` |
| `booking_project` | Post project (s362F gate visible) -> tradies submit quotes via quote sheet -> homeowner compares, "Compare quotes" -> accepts -> books | H T T | journey `competing-quotes`, `homeowner-quotes-visibility`; `v2_flows_test` accept-quote |
| `booking_project_board` | Open project board: tradie quotes without invite, suburb masking, one quote per tradie, close window, accept books | H T T | journey `open-board-quotes` |
| `booking_extra_cost` | Hourly job, mid-job: tradie adds materials / cost adjustment with evidence -> homeowner approves, rejects or tradie withdraws -> final amount includes it | H T | **new**; `v2_flows_test`; backend `/jobs/{id}/adjustments*` |
| `booking_price_change` | Project job booked at the accepted quote; tradie raises an adjustment to change the agreed price (e.g. scope grew), homeowner approves or rejects, final amount and payment reflect it. Same adjustment endpoints as `booking_extra_cost`, project job instead of hourly | H T | **new**; `v2_flows_test`; backend `/jobs/{id}/adjustments*` |
| `booking_no_show` | Booked job, scheduled start passes by 15 min, homeowner reports tradie no-show (reassign or cancel) and tradie reports homeowner no-show (cancel); flags logged | H T | **new**; `POST /jobs/{id}/no-show`; SPECS section 8. Time-gated, see Appendix C risk R4 |
| `booking_dispute_refund` | Dispute after payment resolved for the homeowner -> refund appears in the refund queue -> admin processes with proof -> homeowner notified. Confirm in code that v2 can reach this (Appendix C risk R5) | H T A | **new**; SPECS sections 5 and 6 |
| `booking_review` | After Completed: rating sheet both ways, blind reviews (hidden until both submit), review appears on the public profile (`/users/:id`, `/tradie/:id`) | H T | journey review steps; `ho_review_screen` / `th_rating_sheet` coverage |
| `booking_cancel` | Cancel from each side and state (before accept, after accept, active); reason codes, no refund in v2, flag consequences | H T | journey `cancellations`; `cancellation_test` |
| `booking_dispute` | Dispute from an active job with attachments -> admin resolves to Completed or Cancelled -> blind reviews | H T A | journey `dispute-attachments-reviews`; `dispute_test`; current demo dispute branch; `disputes.spec.ts`, `refunds.spec.ts` |
| `payment_receipt_resubmit` | Receipt rejected by admin -> `AwaitingPayment` -> homeowner resubmits -> verified | H A | journey `receipt-reject-resubmit`; `payments.spec.ts` |

### 4.2 Discovery, identity, setup

| Flow id | Story | Actors | Absorbs |
|---|---|---|---|
| `homeowner_search` | Categories -> find tradie by service + address -> browse -> public profile -> direct request | H T | **new**; `v2_flows_test` request part |
| `signup_homeowner` | Real signup, MailHog OTP, onboarding, first login | H | `auth_test`; fabric signup |
| `signup_tradie` | Real signup + OTP, role selection | T | `auth_test` |
| `tradie_profile_setup` | Wizard: Work, Trades, Verification, Payout -> dashboard | T | Maestro `08_onboarding.yaml`; demo wizard scene |
| `tradie_verification` | Tradie submits credentials (upload via API, native gap) -> admin approves one, rejects one -> tradie sees result and re-submits | T A | `e2e-credentials.py`; `credentials.spec.ts`; demo admin scenes |
| `chat` | Two-way chat in a job, messages list, unread, live reconnect | H T | journey chat steps; `live_chat_test` + `run-live-chat.sh` |
| `change_schedule` | Propose and confirm a new schedule from the chat / job screen (`th_schedule_sheet`), tradie schedule view | H T | **new**; zero coverage today |

### 4.3 Supporting features ("and so on", all already developed)

| Flow id | Story | Actors | Absorbs |
|---|---|---|---|
| `signin_session` | Splash, sign in, wrong password, sign out, role select for a multi-role account, session restore on relaunch | H T | `auth_test`; Maestro login flows |
| `profile_settings` | Profile and settings screens (`/profile`, `/settings`), edit details, theme switch, view own public profile | H T | **new** |
| `tradie_daily` | Availability toggle, available jobs, earnings, job lists | T | **new** |
| `notifications` | Notification center, deep link from a quote / job push | H T | **new**; see `09` and `10` F5 |
| `safety_blocks_reports` | Block a user, report, effect on matching and lists | H T A | **new** |
| `admin_ops` | Admin sign-in (redirect when unauthenticated, wrong credentials), quote-window settings (staff read-only vs superadmin 1-720), overdue-payments view, audit log | A | journey `quote-settings`; `admin-quotes-settings*.spec.ts`, `auth.spec.ts`, overdue part of `payments.spec.ts` |
| `admin_payouts_refunds` | Payout queue, masked bank numbers, batches, process-payout validation (reference required), refund queue (exact 2dp, proof required) | A | `payouts.spec.ts`, `refunds.spec.ts` |
| `admin_users_flags` | Users list, flagged filter (threshold hit), user page actions, deactivate / reactivate with required note, RBAC smoke (non-staff cannot reach admin) | A | `users.spec.ts`, SPECS section 8 |
| `admin_staff_invite` | Superadmin invites staff (24 h token), staff accepts and signs in, role limits | A | **new**; SPECS section 1 |

### 4.4 Tour

`tour` runs **every** flow in the catalog, in this order: `signup_homeowner`, `signup_tradie`, `signin_session`, `tradie_profile_setup`, `tradie_verification`, `homeowner_search`, `booking_hourly_direct`, `booking_hourly`, `booking_hourly_reoffer`, `chat`, `change_schedule`, `booking_extra_cost`, `booking_project`, `booking_project_board`, `booking_price_change`, `payment_receipt_resubmit`, `booking_cancel`, `booking_no_show`, `booking_dispute`, `booking_dispute_refund`, `booking_review`, `tradie_daily`, `notifications`, `safety_blocks_reports`, `profile_settings`, `admin_users_flags`, `admin_payouts_refunds`, `admin_staff_invite`, `admin_ops`. `--skip a,b` and `--only a,b` filter it. Because the tour is long (U8.4), it records as numbered parts if needed; the order above is the contract.

## 5. Phases

### Phase U0: Decisions and prep (no behaviour change)

- [x] **U0.1** Open items O1-O5 answered by the owner (section 7) (S)
- [x] **U0.2** Coverage map built: every test in layers B, D, E, F with the absorbing flow. See Appendix A. Nothing is deleted in later phases unless it has a row there (S)
- [x] **U0.3** SPECS read; rules each flow must assert recorded in Appendix B (S)
- [ ] **U0.4** **Owner action.** Record a baseline: owner runs `scripts/run-e2e.sh FABRIC` and `python3 scripts/e2e-demo.py --only-preflight` and pastes pass/fail. Needed so regressions are attributable (S)

### Phase U1: Extract the shared lib (behaviour-preserving)

- [x] **U1.1** Create `scripts/e2e/lib/` and move signal server, Show/timeline, captions, `--record`, `--capture-sims`, simulator handling, fabric provisioning and report writing out of `e2e-demo.py` unchanged (M). Done: `lib/{api,asserts,stage,sims,fabric,report}.py`. Small deliberate changes: `pick_simulators` takes udids instead of `args`; `provision_fabric` takes persona counts (defaults = old demo); `start_recording`/`stop_recording`/`start_signal_server` extracted from `main()`; `fabric.record_job` replaces the demo's dependency on `e2e-journey.py`. Not moved yet (belongs with the U2 CLI): simulator build-with-timeout, `preflight`, and the demo-only `prepare_fabric`
- [x] **U1.2** Move API helpers and decimal/status/audit assertions out of `e2e-journey.py` into `lib/api.py` and `lib/asserts.py` (M). `e2e-journey.py` now imports them (scenarios untouched); `write_junit` moved to `lib/report.py`. Bug fixed on the way: the journey's `--timeout` never reached `poll()` (default bound at definition time); `lib.api.set_poll_timeout` makes it work, covered by a test
- [x] **U1.3** Re-point `e2e-demo.py` to the lib; owner confirms the current demo still plays identically (M). Owner ran it: preflight PASS, `--single-flow` PASS (25 scenes, 8m28s), `e2e-journey.py --scenario all` PASS (10 scenarios on a fresh manifest). The admin payout scene timed out because `admin_pov.mjs` used the stale selector `#payout-transfer-reference` (`<Field>` generates the id now); fixed to a label locator. Pre-existing, not caused by the refactor. **Re-check on the next demo run** that the payout and later admin scenes play. Also fixed by the owner's run: persona cleanup 415 (deactivate needs a `reason` body) and stale superadmin defaults (`admin@tradiehunter.nz` / `Admin1!TH`)
- [x] **U1.4** Confirm no new dependency (stdlib only stays true) (S). Confirmed: lib and its tests import stdlib only. Self-tests: `cd scripts && python3 -m unittest discover -s e2e/tests -t .` (15 tests, no stack needed)

### Phase U2: Flow contract and the single CLI

- [ ] **U2.1** Define the flow descriptor (id, title, actors, persona needs, pre-roll, scenes, post-asserts, dependencies) and the registry (M)
- [ ] **U2.2** Write `scripts/e2e/run.py` with `<flow>... | --all | --tour | --list`, carrying over every flag listed in section 3 (M)
- [ ] **U2.3** Per-flow persona sizing: each flow asks the fabric for the minimum (`--homeowners N --tradies N --staff 1|2`). Reuse via `--manifest` still works (S)
- [ ] **U2.4** Dart side: split `demo_tour_test.dart` into `integration_test/scenes/` and a dispatcher selected by `--dart-define=FLOW=<id>` plus `FIXO_PERSONA`. Keep the `__DEMO_DONE__` marker (L)
- [ ] **U2.5** Web side: split `admin_pov.mjs` into scene modules under `web/e2e/flows/` (M). Lesson from U1.3: `scene()` currently swallows a failed UI scene and logs it as an "API fallback", so the run still says PASS. In the split, a failed UI scene must fail the flow unless the scene is a declared, documented fallback

### Phase U3: Port the existing demo into flows

- [ ] **U3.1** `booking_hourly_direct` (current direct-request path) running end to end through the new CLI (M)
- [ ] **U3.2** `booking_dispute` (current dispute branch, plus the journey's attachments and blind reviews) (M)
- [ ] **U3.3** `tradie_profile_setup` and `tradie_verification` from the current wizard and admin credential scenes (M)
- [ ] **U3.4** `tour` reproduces today's full demo from composed flows. Owner compares against a recording from U0.4 (M)

### Phase U4: Booking flows

- [ ] **U4.1** `booking_hourly` with native address (LINZ) and quick match / radar. Verify the radar scene and the previous "seeded tradie gets the offer" issue: the flow must ensure only fabric tradies are available to match (L)
- [ ] **U4.2** `booking_hourly_reoffer` (S)
- [ ] **U4.3** `booking_project` including the tradie quote sheet and the s362F boundary (L)
- [ ] **U4.4** `booking_project_board` (M)
- [ ] **U4.5** `booking_cancel` across states and both sides (M)
- [ ] **U4.6** `payment_receipt_resubmit` (S)
- [ ] **U4.7** `booking_no_show` and `booking_dispute_refund` once R4 and R5 are resolved; otherwise record each as parked with the reason (M)

### Phase U5: New-coverage flows

- [ ] **U5.1** `booking_extra_cost`: confirm what the mobile screens expose first (`ho_extra_cost_screen`, `tr_extra_cost_page`); script approve, reject and withdraw paths with evidence (L)
- [ ] **U5.2** `booking_price_change` (project job, adjustment raises the price, approve and reject paths) and `booking_review` (M)
- [ ] **U5.3** `homeowner_search` (M)
- [ ] **U5.4** `change_schedule` (M)
- [ ] **U5.5** `chat` including messages list and reconnect; fold `run-live-chat.sh` (M)
- [ ] **U5.6** `signup_homeowner`, `signup_tradie` with real OTP via MailHog (M)

### Phase U6: Supporting flows

- [ ] **U6.1** `tradie_daily` (M)
- [ ] **U6.2** `notifications` (M; depends on `09` and the `10` F5 deep-link fix, otherwise document the gap)
- [ ] **U6.3** `safety_blocks_reports` (M)
- [ ] **U6.4** `admin_ops`, `admin_users_flags`, `admin_payouts_refunds`, `admin_staff_invite` (L)
- [ ] **U6.5** `signin_session` and `profile_settings` (M)
- [ ] **U6.6** Gap sweep: walk every route in `mobile/lib/router/app_router.dart` and every `web/src` admin page, list any screen no flow visits, and add a flow or scene for it. Record the result as an appendix (S)

### Phase U7: Fold, retire, clean up

- [ ] **U7.1** For each row of the U0.2 coverage map, confirm the absorbing flow asserts the same thing. Owner signs off the map (M)
- [ ] **U7.2** Delete layer D suites that are fully absorbed; keep `helpers/` only as used by flows. Remove `persona_fabric_test.dart` when `FABRIC`-equivalent coverage exists in flows (M)
- [ ] **U7.3** Delete absorbed Playwright specs and `.maestro/`; keep `playwright.config`, `fixtures/auth.setup.ts` if flows use them (S)
- [ ] **U7.4** Move `web/e2e/responsive.spec.ts` next to the capture suites, or park with a reason (S)
- [ ] **U7.5** Retire `scripts/run-e2e.sh`, `run-live-chat.sh`, `e2e-journey.py`, `e2e-demo.py`, `e2e-credentials.py` after grep shows no remaining references (docs, CI, other scripts). Leave a one-line shim for `e2e-demo.py` that forwards to `run.py --tour` for one release (S)
- [ ] **U7.6** Update every reference listed in Appendix C (docs, `AGENTS.md`, agent skills, MCP configs) and the `03` and `08` status headers. Keep `scripts/seed-test-accounts.sh`: the capture suites still use it (M)
- [ ] **U7.7** Replace `.github/workflows/e2e-mobile.yml`: remove the Android job and its nightly `schedule`; add a `workflow_dispatch`-only macOS job that starts the stack and runs `python3 scripts/e2e/run.py --all --fail-fast` on an iOS simulator. Mark it untested on CI in the header, same as today's. Wire a nightly trigger only after the owner has run it green once (S)

### Phase U8: Hardening

- [ ] **U8.1** Each flow run twice back to back on one stack without cleanup between: no collisions (M)
- [ ] **U8.2** Each flow recorded once by the owner; fix anything unreadable at `--pace 3` (M)
- [ ] **U8.3** Run report lists the native gaps per flow (photo picker, any LINZ fallback) (S)
- [ ] **U8.4** Time budget: record each flow's runtime; flows over about 8 minutes get split (S)

### Phase U9: Android (later, not in this plan's scope)

- [~] **U9.1** Parked by owner decision (iOS first). Entry condition: tour green on iOS. Reuse `E2E_TRADIE_DEVICE`, the `10.0.2.2` rewrite and the Android emulator steps from the old `e2e-mobile.yml` (recover from git history).

## 6. Risks

| Risk | Mitigation |
|---|---|
| Deleting the API journey loses fast, headless regression signal | Decision 2 accepts this. Keep the assertions (U1.2) and the coverage map (U0.2 / U7.1) so nothing silently disappears. If the owner wants a fast gate later, a `--headless` flow mode can reuse `lib/api.py` without new scenario code. |
| Two simulator builds collide on `mobile/build` | Flows run sequentially. The tour never parallelises iOS builds (existing rule in `TESTING.md`). |
| Quick match offers jobs to seeded tradies, not fabric ones | U4.1 sets availability so only fabric tradies match, and restores it on exit (existing demo-tradie parking). |
| LINZ rate limits or lookup drift during recordings | Native lookup only when the key is present; report the fallback when not. |
| Flows grow long and unrecordable | U8.4 budget; split flows rather than add pace. |
| Backend gaps for schedule, adjustments or notifications deep links | Documented in the run report and this file, not worked around. |

## 7. Former open items (all resolved by the owner)

| # | Question | Answer | Where it landed |
|---|---|---|---|
| O1 | What is "change of quotation price"? | The extra-cost adjustment mechanism | `booking_price_change`, `booking_extra_cost` |
| O2 | Variants as separate flows or scenes? | Separate; the owner's list is not exhaustive, add more | Section 4 (adds `booking_review`, `signin_session`, `profile_settings`, U6.6 gap sweep) |
| O3 | Does the tour include every flow? | Yes | Section 4.4 |
| O4 | CI: park or keep? | Park or replace so there is one unified suite | U7.7 |
| O5 | Token rotation | Owner will do it later | Decision 9 |

**New open item (from U0.2):**

- **O6:** Some Playwright checks are not flow-shaped: the job-progress stepper accessibility and DOM checks (`job-progress.spec.ts`: role/aria, sr-only text, connector drawing, no refresh button), responsive overflow and keyboard-drawer checks (`responsive.spec.ts`), and the credential empty-state. A recordable flow cannot sensibly assert them. Recommendation: keep them, unchanged, in `web/e2e/checks/` outside `run.py` and the tour, and say so in `TESTING.md`; the stepper's *active step per status* is asserted inside flows. Alternative: delete them. Decide before U7.3.

## 8. Definition of done

- `python3 scripts/e2e/run.py --list` shows every flow in section 4.
- Each flow runs alone, records alone, asserts through the API at the end, and cleans up after itself.
- `python3 scripts/e2e/run.py --tour` plays every flow on iOS with no duplicated scene code.
- `e2e-mobile.yml` is replaced per U7.7 and no workflow references a removed script.
- The coverage map has no unabsorbed row; layers B, D (absorbed parts), E (absorbed parts) and F are gone; capture suites untouched.
- `docs/TESTING.md` describes the new entry point and the capture-suite boundary.
- Owner has run and recorded every flow at least once.

---

## Appendix A: Coverage map (U0.2)

Rule: nothing below is deleted until the absorbing flow asserts the same behaviour (U7.1). "Keep" means it stays outside the unified suite.

### A.1 API journey scenarios (`scripts/e2e-journey.py`)

| Scenario | Absorbed by |
|---|---|
| `happy-path` (`run_journey`) | `booking_hourly`, plus chat steps to `chat`, review steps to `booking_review` |
| `competing-quotes` | `booking_project` |
| `homeowner-quotes-visibility` (DTO/list contract, `(0,0)` precondition, hourly `(None,None)`, s362F at 29,999.99 / 30,000.00 / 45,000.00) | `booking_project` |
| `quote-settings` | `admin_ops` |
| `open-board-quotes` | `booking_project_board` |
| `hourly-decline-reoffer` | `booking_hourly_reoffer` |
| `withdraw-no-match-repost` | `booking_hourly_reoffer` (own scene; consider `booking_hourly_no_match` if it exceeds the runtime budget) |
| `cancellations` | `booking_cancel` |
| `receipt-reject-resubmit` | `payment_receipt_resubmit` |
| `dispute-attachments-reviews` | `booking_dispute`, `booking_review` |

### A.2 Flutter `integration_test`

| Suite / test | Absorbed by |
|---|---|
| `auth_test`: unverified login routes to OTP (P1-06) | `signup_homeowner` |
| `auth_test`: verified homeowner / tradie login reaches dashboard (P1-02) | `signin_session` |
| `auth_test`: wrong password banner (P9-03) | `signin_session` |
| `auth_test`: signup screen renders role cards and fields | `signup_homeowner`, `signup_tradie` |
| `job_request_test`: Post Job renders fields (P2-08), empty submit stays (P2-04) | `booking_hourly` (negative step in post scene) |
| `job_request_test`: P2-LINZ posts local job, starts matching, cancels | `booking_hourly`, `booking_cancel` |
| `job_request_test`: dashboard renders job cards (P2-09) | `booking_hourly` |
| `matching_test` (P3-03/04/11, both sides) | `booking_hourly` |
| `payment_test` (P4-13 bank details + upload, under review) | `booking_hourly`, `payment_receipt_resubmit` |
| `job_lifecycle_test` (check in, check out, approve itemised, review) | `booking_hourly`, `booking_review` |
| `cancellation_test` (P6-04/06: reasons, dismiss keeps job, tradie account-flag warning) | `booking_cancel` |
| `dispute_test` (P7-04: render, empty details blocked, submit leaves) | `booking_dispute` |
| `v2_flows_test`: accept quote books; s362F gate; quote visibility (3 tests) | `booking_project` |
| `v2_flows_test`: approve extra-cost request | `booking_extra_cost` |
| `v2_flows_test`: direct tradie request from profile | `homeowner_search`, `booking_hourly_direct` |
| `v2_flows_test`: tradie sees no quote UI on homeowner route | `booking_project` (negative scene) |
| `live_chat_test` (two-client send + reconnect) and `run-live-chat.sh` | `chat` |
| `persona_fabric_test` (login and view API-created job, both personas) | Superseded: every flow runs on the fabric. Delete at U7.2 |
| `demo_tour_test` | Split into scenes (U2.4), then `tour` |
| `screenshots_*_test` (4 files) | Keep (capture suites) |

### A.3 Web Playwright (`web/e2e`)

| Spec | Absorbed by |
|---|---|
| `auth.spec` | `admin_ops` |
| `credentials.spec` (queue order, row info, reject needs reason, approve removes, empty state) | `tradie_verification`; empty state per O6 |
| `payments.spec` (queue loads, amount + FIXO- reference, reject needs reason, verify removes row) | `booking_hourly`, `payment_receipt_resubmit` |
| `payments.spec` overdue view and link | `admin_ops` |
| `disputes.spec` (list, open shows context + evidence, resolve confirmation modal) | `booking_dispute` |
| `refunds.spec` | `admin_payouts_refunds`, `booking_dispute_refund` |
| `payouts.spec` | `admin_payouts_refunds` |
| `users.spec` (list, flagged filter, profile actions, RBAC smoke) | `admin_users_flags` |
| `admin-quotes-settings.spec`, `admin-quotes-settings-staff.spec` | `admin_ops` |
| `persona-fabric.spec` | Superseded by flow admin scenes. Delete at U7.3 |
| `job-progress.spec` active step per status | `booking_hourly`, `booking_cancel` admin scenes |
| `job-progress.spec` a11y / DOM checks, `responsive.spec` | O6 (recommended: keep in `web/e2e/checks/`) |
| `admin-shots.mjs` | Keep (capture) |
| `fixtures/auth.setup.ts`, `fixtures/superadmin.setup.ts` | Keep while flows or checks use them |

### A.4 Maestro (`.maestro/`)

| Flow | Absorbed by |
|---|---|
| `shared/login*.yaml`, `homeowner/01_login` | `signin_session` |
| `homeowner/02_post_job` | `booking_hourly` |
| `homeowner/03_choose_tradie` | `homeowner_search`, `booking_hourly_direct` |
| `homeowner/04_cancel_dismiss` | `booking_cancel` |
| `homeowner/05_payment_status` | `booking_hourly` |
| `homeowner/06_quote_visibility` | `booking_project` |
| `tradie/01_home`, `06_earnings`, `07_jobs_list` | `tradie_daily` |
| `tradie/02_lead`, `03_job_booked`, `05_complete` | `booking_hourly` |
| `tradie/04_job_inprogress_extra_cost` | `booking_extra_cost` |
| `tradie/08_onboarding` | `tradie_profile_setup` |

### A.5 Scripts

| Script | Fate |
|---|---|
| `e2e-demo.py`, `e2e-demo/admin_pov.mjs` | Split into `scripts/e2e/` and `web/e2e/flows/`; shim then delete |
| `e2e-journey.py` | Helpers to `lib/`, scenarios to flows, then delete |
| `e2e-credentials.py` | Absorbed by `tradie_verification` (keep its DB-state assertions as API asserts) |
| `e2e-personas.py` | Keep, becomes `lib/fabric.py`'s backend |
| `run-e2e.sh`, `run-live-chat.sh` | Replaced by `run.py` |
| `seed-test-accounts.sh` | Keep (used by `p12-smoke.sh`, `mk-v2-shot-fixtures.py`, capture suites) |

## Appendix B: Rules each flow must assert (U0.3, from `docs/SPECS.md`)

| Area | Rule | Flows |
|---|---|---|
| State machine (v2) | Requested -> Booked (tradie accepts before expiry) -> InProgress (check-in) -> AwaitingConfirmation (check-out with final hours) -> AwaitingPayment (homeowner approves) -> PaymentReview (receipt) -> Completed (staff verify). Every transition writes `JobStatusHistory` and publishes SignalR `JobStatusChanged`. | `booking_hourly*`, `booking_project*` |
| Money | `FinalAmount = LabourAmount + sum(Approved adjustments)`; payment and payout gross = final; commission on labour only by default; decimals only. Fixed quote: agreed price + approved adjustments. | `booking_hourly`, `booking_extra_cost`, `booking_price_change`, `admin_payouts_refunds` |
| Estimate banner | "Higher than estimate" when final > estimate x 1.15 | `booking_hourly`, `booking_extra_cost` |
| Adjustments | Tradie proposes during Booked / InProgress / AwaitingConfirmation; kinds Materials / ExtraLabour / Travel / Other; description <= 500, amount > 0, optional evidence; only homeowner responds; tradie may withdraw while Pending; Pending expire after 48 h (not drivable in a flow, assert via API fields only); approve is blocked while any is Pending; only Approved count | `booking_extra_cost`, `booking_price_change` |
| Cancellation | Any pre-Completed state -> Cancelled by homeowner, tradie, admin or system, with a reason code; no refund in v2; tradie cancel warns about account flag | `booking_cancel` |
| Disputes | Either party from any active state; reason, details, evidence; admin sees chat + evidence; resolves to Completed or Cancelled with outcome full / partial / none; no automation; refund only for post-payment dispute resolved for the homeowner | `booking_dispute`, `booking_dispute_refund` |
| Receipt | Reject with reason: PaymentReview -> AwaitingPayment; one Payment row reused across re-uploads; receipt SHA-256 unique (duplicate receipt rejected); bank details from config, never placeholders | `payment_receipt_resubmit` |
| Staff queue | Expected amount beside receipt; age amber over 15 min, red over 30 | `booking_hourly` admin scene |
| Overdue payment | Reminders at 24 h and 72 h, then `OverduePayment` flag blocks posting; time-gated, so the flow shows the view and asserts the block through the API only if a flagged state can be set via real routes, else document | `admin_ops` |
| Reviews | Both parties, 1-5 stars + optional comment; hidden until both submit or 7 days; only after Completed; zero reviews shows "New to TradieHunter", never 0.0; average below 3.0 after 3 reviews creates a `LowRating` flag | `booking_review` |
| Quotes (projects) | Up to 3 concurrent quote requests; 72 h window; accept books and declines the rest atomically; GST rule on quotes; accepted quote >= NZD 30,000 incl. GST needs contract confirmation (s362F) | `booking_project` |
| Open board | Project jobs only; masked to suburb until Booked; quote without invite; one quote per tradie; invite-only, out-of-range, blocked excluded; board closes at `QuotesCloseAtUtc` | `booking_project_board` |
| Matching | Candidate = verified, active, available, not blocked, in radius, with approved licence when the service requires one; decline/timeout offers next; exhausted -> Cancelled `no_tradie_found`; direct request: one pending per hourly job (409), decline leaves job Requested | `booking_hourly`, `booking_hourly_reoffer`, `booking_hourly_direct` |
| Address privacy | Tradie sees suburb until Booked; exact address and phone from Booked | `booking_hourly`, `booking_project_board` |
| Chat | Job-scoped; unlocked at Booked and after; readable by staff during disputes; quick replies | `chat`, `booking_dispute` |
| Schedule | Propose or confirm only while Booked; one party proposes, the other confirms; date is UTC date plus a time slot; push to the other party | `change_schedule` |
| Flags and safety | Block excludes from matching; report creates an `Abuse` flag; deactivate / reactivate need a note, audited, note not emailed; deactivation locks the account | `safety_blocks_reports`, `admin_users_flags` |
| Roles | Only Homeowner and Tradie self-register; Staff and Superadmin via invite (24 h token) | `signup_*`, `admin_staff_invite` |
| Auth | Email + 6-digit OTP; unverified login routes to OTP; lockout returns 429 | `signup_*`, `signin_session` |
| Earnings | Server-computed decimals, Pacific/Auckland Monday-start week: earned net, processed, pending, failed | `tradie_daily`, `admin_payouts_refunds` |
| Audit | Admin actions store old/new JSON | `admin_ops`, `tradie_verification`, `admin_users_flags` |

## Appendix C: U0 findings, risks and references

### C.1 References that must change at retirement (feeds U7.5 / U7.6)

- **CI:** `.github/workflows/e2e-mobile.yml` (U7.7).
- **Docs:** `docs/TESTING.md`, `docs/QA.md`, `docs/todos/03_e2e_realignment_plan.md`, `docs/todos/08_e2e_persona_fabric_plan.md`; also mentioned in `01`, `07`, `09` (history; add a "superseded by 12" note rather than rewrite).
- **Agent instructions and skills:** `AGENTS.md`, `.devin/skills/e2e-demo/SKILL.md`, `agent/skills/v2-e2e-explorer/SKILL.md`, `.agents/skills/v2-e2e-explorer/SKILL.md`.
- **Maestro tooling (not just YAML):** `mcp.json`, `.agent/mcp_config.json`, `.agents/mcp_config.json`, `opencode.json`, `docs/ai/AI-TOOLING.md` reference `.maestro`. Retiring Maestro means removing its MCP entries too. Ask the owner before touching MCP configs, since other agent tooling may rely on them.
- **Code:** `mobile/integration_test/helpers/{manifest_helper,demo_helper,test_config}.dart` mention retired scripts in comments or paths; `v2_flows_test.dart` references `run-e2e.sh`.
- **Archive docs** (`docs/archive/*`) are history; leave them.

### C.2 Risks found while mapping

| # | Risk | Plan response |
|---|---|---|
| R1 | `ScheduleService` and its docs say "Confirmed" jobs but the guard is `JobStatus.Booked`; the endpoint comment and error message are stale. Behaviour is Booked-only. | `change_schedule` asserts against `Booked`. Flag the stale wording to the owner; do not fix it in this plan. |
| R2 | The old demo avoided quick match because it would offer jobs to seeded tradies. | U4.1 isolates matching to fabric tradies. |
| R3 | `job-progress.spec.ts` and `responsive.spec.ts` are not flow-shaped. | O6. |
| R4 | No-show reporting is available only 15 minutes after the scheduled start, and the schedule is date-based, so a flow cannot wait for it. | U4.7: use only real routes; if no real route can reach the state, park `booking_no_show` with the reason (documented, not worked around). |
| R5 | Refunds exist in v2 only for a post-payment dispute resolved for the homeowner; the state path to reach that is not obvious from `SPECS.md`. | U4.7: confirm in `JobStatusService` and `AdminController` first; park if unreachable. |
| R6 | Overdue payment, adjustment expiry (48 h), auto-approve (48 h) and quote expiry are time-gated Hangfire jobs. | Flows show the resulting views and assert contract fields; they do not fast-forward time. |
| R7 | Google login (`RequiresRegistration`) cannot be driven natively. | Out of scope; document as a native gap. |
| R8 | Hangfire jobs only fire if workers run in the local stack; reveal of blind reviews (7 days) is time-gated. | `booking_review` asserts hidden-until-both-submit, not the 7-day path. |
