# E2E Flow Unification: one recordable flow per feature, everything else folded in or retired

> **Repo / branch:** `johnverz22/tradiehunter` @ `main` (there is no `dev` branch on the remote; remote branches are `main`, `feat/admin-user-detail`, `fix/e2e-findings`, and the latter two have no commits ahead of `main`)
> **Purpose:** Replace today's six overlapping E2E layers with a single set of **demo-grade, independently recordable flows**, one per developed feature (hourly booking, project booking, disputes, extra cost, homeowner search, tradie verification, chat, schedule, sign up, profile setup, and so on). Flows compose into one master tour. Anything that is not a flow is either folded into one or deleted.
> **Status:** Proposed, not started. Decisions in section 2 are owner-confirmed. · **Prepared:** 2026-11-28
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
| `booking_extra_cost` | Mid-job: tradie adds materials / cost adjustment with evidence -> homeowner approves, rejects or tradie withdraws -> final amount includes it | H T | **new**; `v2_flows_test`; backend `/jobs/{id}/adjustments*` |
| `booking_quote_change` | Project quote price change after booking (confirm mechanism, see Open item O1) | H T | **new** |
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
| `tradie_daily` | Availability toggle, available jobs, earnings, job lists | T | **new** |
| `notifications` | Notification center, deep link from a quote / job push | H T | **new**; see `09` and `10` F5 |
| `safety_blocks_reports` | Block a user, report, effect on matching and lists | H T A | **new** |
| `admin_ops` | Quote-window settings (staff read-only vs superadmin 1-720), users, payouts, audit log | A | journey `quote-settings`; `admin-quotes-settings*.spec.ts`, `users.spec.ts`, `payouts.spec.ts`, `job-progress.spec.ts`, `auth.spec.ts` |

### 4.4 Tour

`tour` order: `signup_homeowner` -> `signup_tradie` -> `tradie_profile_setup` -> `tradie_verification` -> `homeowner_search` -> `booking_hourly` -> `chat` -> `change_schedule` -> `booking_extra_cost` -> `booking_project` -> `booking_dispute` -> `admin_ops`. The tour may skip flows with `--skip`.

## 5. Phases

### Phase U0: Decisions and prep (no behaviour change)

- [ ] **U0.1** Confirm Open items O1-O5 (section 7) with the owner (S)
- [ ] **U0.2** Build the **coverage map**: every test in layers B, D, E, F, listed with the flow that absorbs it (start from section 4). Commit it as an appendix to this file. Nothing is deleted in later phases unless it has a row here (S)
- [ ] **U0.3** Read `docs/SPECS.md` and record the rules each flow must assert (cancellation, dispute, review eligibility, adjustments, schedule, s362F). Add as an appendix (S)
- [ ] **U0.4** Record a baseline: owner runs `scripts/run-e2e.sh FABRIC` and `python3 scripts/e2e-demo.py --only-preflight` and pastes pass/fail. Needed so regressions are attributable (S)

### Phase U1: Extract the shared lib (behaviour-preserving)

- [ ] **U1.1** Create `scripts/e2e/lib/` and move signal server, Show/timeline, captions, `--record`, `--capture-sims`, simulator handling, fabric provisioning and report writing out of `e2e-demo.py` unchanged (M)
- [ ] **U1.2** Move API helpers and decimal/status/audit assertions out of `e2e-journey.py` into `lib/api.py` and `lib/asserts.py` (M)
- [ ] **U1.3** Re-point `e2e-demo.py` to the lib; owner confirms the current demo still plays identically (M)
- [ ] **U1.4** Confirm no new dependency (stdlib only stays true) (S)

### Phase U2: Flow contract and the single CLI

- [ ] **U2.1** Define the flow descriptor (id, title, actors, persona needs, pre-roll, scenes, post-asserts, dependencies) and the registry (M)
- [ ] **U2.2** Write `scripts/e2e/run.py` with `<flow>... | --all | --tour | --list`, carrying over every flag listed in section 3 (M)
- [ ] **U2.3** Per-flow persona sizing: each flow asks the fabric for the minimum (`--homeowners N --tradies N --staff 1|2`). Reuse via `--manifest` still works (S)
- [ ] **U2.4** Dart side: split `demo_tour_test.dart` into `integration_test/scenes/` and a dispatcher selected by `--dart-define=FLOW=<id>` plus `FIXO_PERSONA`. Keep the `__DEMO_DONE__` marker (L)
- [ ] **U2.5** Web side: split `admin_pov.mjs` into scene modules under `web/e2e/flows/` (M)

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

### Phase U5: New-coverage flows

- [ ] **U5.1** `booking_extra_cost`: confirm what the mobile screens expose first (`ho_extra_cost_screen`, `tr_extra_cost_page`); script approve, reject and withdraw paths with evidence (L)
- [ ] **U5.2** `booking_quote_change` once O1 is answered (M)
- [ ] **U5.3** `homeowner_search` (M)
- [ ] **U5.4** `change_schedule` (M)
- [ ] **U5.5** `chat` including messages list and reconnect; fold `run-live-chat.sh` (M)
- [ ] **U5.6** `signup_homeowner`, `signup_tradie` with real OTP via MailHog (M)

### Phase U6: Supporting flows

- [ ] **U6.1** `tradie_daily` (M)
- [ ] **U6.2** `notifications` (M; depends on `09` and the `10` F5 deep-link fix, otherwise document the gap)
- [ ] **U6.3** `safety_blocks_reports` (M)
- [ ] **U6.4** `admin_ops` (M)

### Phase U7: Fold, retire, clean up

- [ ] **U7.1** For each row of the U0.2 coverage map, confirm the absorbing flow asserts the same thing. Owner signs off the map (M)
- [ ] **U7.2** Delete layer D suites that are fully absorbed; keep `helpers/` only as used by flows. Remove `persona_fabric_test.dart` when `FABRIC`-equivalent coverage exists in flows (M)
- [ ] **U7.3** Delete absorbed Playwright specs and `.maestro/`; keep `playwright.config`, `fixtures/auth.setup.ts` if flows use them (S)
- [ ] **U7.4** Move `web/e2e/responsive.spec.ts` next to the capture suites, or park with a reason (S)
- [ ] **U7.5** Retire `scripts/run-e2e.sh`, `run-live-chat.sh`, `e2e-journey.py`, `e2e-demo.py`, `e2e-credentials.py` after grep shows no remaining references (docs, CI, other scripts). Leave a one-line shim for `e2e-demo.py` that forwards to `run.py --tour` for one release (S)
- [ ] **U7.6** Update `docs/TESTING.md`, `docs/QA.md`, `AGENTS.md`, `docs/ai/AI-TOOLING.md` if they reference removed scripts; update `03` and `08` status headers (M)
- [ ] **U7.7** CI: `e2e-mobile.yml` runs the old configs. Decide with the owner whether it becomes a flow job or is parked (needs iOS runners; see O4) (S)

### Phase U8: Hardening

- [ ] **U8.1** Each flow run twice back to back on one stack without cleanup between: no collisions (M)
- [ ] **U8.2** Each flow recorded once by the owner; fix anything unreadable at `--pace 3` (M)
- [ ] **U8.3** Run report lists the native gaps per flow (photo picker, any LINZ fallback) (S)
- [ ] **U8.4** Time budget: record each flow's runtime; flows over about 8 minutes get split (S)

### Phase U9: Android (later, not in this plan's scope)

- [~] **U9.1** Parked by owner decision (iOS first). Entry condition: tour green on iOS. Reuse `E2E_TRADIE_DEVICE`, the `10.0.2.2` rewrite and the CI emulator job.

## 6. Risks

| Risk | Mitigation |
|---|---|
| Deleting the API journey loses fast, headless regression signal | Decision 2 accepts this. Keep the assertions (U1.2) and the coverage map (U0.2 / U7.1) so nothing silently disappears. If the owner wants a fast gate later, a `--headless` flow mode can reuse `lib/api.py` without new scenario code. |
| Two simulator builds collide on `mobile/build` | Flows run sequentially. The tour never parallelises iOS builds (existing rule in `TESTING.md`). |
| Quick match offers jobs to seeded tradies, not fabric ones | U4.1 sets availability so only fabric tradies match, and restores it on exit (existing demo-tradie parking). |
| LINZ rate limits or lookup drift during recordings | Native lookup only when the key is present; report the fallback when not. |
| Flows grow long and unrecordable | U8.4 budget; split flows rather than add pace. |
| Backend gaps for schedule, adjustments or notifications deep links | Documented in the run report and this file, not worked around. |

## 7. Open items for the owner

- **O1:** "Change of quotation price" after booking: is this the extra-cost adjustment mechanism (`/jobs/{id}/adjustments`), or does a separate quote-revision path exist or is one planned? `booking_quote_change` waits on this.
- **O2:** Flow granularity for variants (`booking_hourly_reoffer`, `booking_project_board`): separate flows as listed, or scenes inside their parent flow?
- **O3:** Should the `tour` include every flow, or only the section 4.4 list?
- **O4:** CI: park `e2e-mobile.yml` for now, or keep a nightly Android job until U9?
- **O5:** The PAT was pasted in chat with write access. Rotate it after this work.

## 8. Definition of done

- `python3 scripts/e2e/run.py --list` shows every flow in section 4.
- Each flow runs alone, records alone, asserts through the API at the end, and cleans up after itself.
- `python3 scripts/e2e/run.py --tour` plays the composed demo on iOS with no duplicated scene code.
- The coverage map has no unabsorbed row; layers B, D (absorbed parts), E (absorbed parts) and F are gone; capture suites untouched.
- `docs/TESTING.md` describes the new entry point and the capture-suite boundary.
- Owner has run and recorded every flow at least once.
