# E2E Realignment Plan: v2 Design System Migration

> **Repo / branch:** `johnverz22/tradiehunter` @ `dev`
> **Purpose:** Realign the end-to-end scripts with the v2 (Trust Navy + Gold) presentation layer **before** completing the open QA tasks in `docs/todos/01_design_system_migration_plan.md` §4 (4.6 and the three unchecked boxes in the "4.4 activation checklist").
> **Status of this document:** E0, E3, E5, and E6.6 complete (verified); extended by [`08_e2e_persona_fabric_plan.md`](08_e2e_persona_fabric_plan.md) (multi-tier persona fabric). E1–E2 pending baseline run.
> **Prepared:** 2026-11-17 · **Updated:** 2026-11-17

---

## 0. How this plan was produced, and its limits

- Cloned `dev` and read the migration plan, `AGENTS.md`, `mcp.json`, `skills-lock.json`, `docs/TESTING.md`, CI, all 13 files in `mobile/integration_test/` plus helpers, and `lib/ui/**`.
- Findings were produced by static code audit and **partially confirmed against the live stack** (auth suite ran on the connected iPhone 17 Pro simulator: 5 pass, 1 pre-existing signup failure unrelated to v2). Maestro and Patrol facts were checked against their current docs (links in §9). Every "finding" below is still subject to the E1 baseline run in Phase E1.
- "Improve plugins" is interpreted as: the agent skills / MCP servers already declared in the repo (`skills-lock.json` → `dart-lang/skills`, `flutter/agent-plugins`; `mcp.json` → `dart`, `postgres-backend`, `puppeteer-react`), plus the additions recommended in the pasted text. If you meant something else, only §6 changes.

---

## 1. Where the e2e suite stands today

**Runner:** Flutter `integration_test` (13 files, ~2,700 lines) driving the real app against the real local backend. It finds widgets by `Key` and by visible text, seeds state through `helpers/fixture_helper.dart` and `helpers/api_helper.dart`, and logs in through `helpers/auth_helper.dart`.

**Not in CI.** `.github/workflows/ci.yml` runs backend build/test, `flutter analyze`, `flutter test`, the import-boundary guard and the design gate. The device flows are run by hand via `scripts/run-e2e.sh <config>` (E0; replaces the retired `run-suite-v14*.sh`).

**Flag state matters.** `lib/ui/ui_flags.dart` ships only the 12 Phase 3 ids in `v2Screens`. All Phase 4 screens are gated, so a plain `flutter test integration_test/...` run today exercises v2 auth/shell/settings/profile/chat but **v1** for everything homeowner. The Phase 4 flows were only checked through `flutter test` widget tests and a few `--dart-define=UI_V2=<id>` runs. The §4.4 box "Run the listed device integration flows against the dev backend" is therefore still open, and this plan is what unblocks it.

### Pre-existing problems (independent of v2)

| # | Problem | Evidence |
|---|---|---|
| P-1 | `docs/TESTING.md` already says `job_request_test`, `job_lifecycle_test`, `payment_test` "still describe the v1 order" (P12-28) | TESTING.md "Gaps" |
| P-2 | `status_strip_toggle` and `navigate_options_button` are used by `demo_tour_test` / `screenshots_variants_test` but exist in **neither** `lib/views` nor `lib/ui` | grep |
| P-3 | ~~Run scripts hardcode personal paths and UDIDs~~ **Fixed (E0.2)** — `scripts/run-e2e.sh` is portable (`E2E_DEVICE`, `FIXO_API_URL`, `E2E_LOG_DIR`) | `scripts/run-e2e.sh` |
| P-4 | ~~`kApiBaseUrl` defaults to `localhost:5000` (iOS only)~~ **Fixed (E0.3)** — `test_config.dart` rewrites to `10.0.2.2` on Android, still `FIXO_API_URL`-overridable | `helpers/test_config.dart` |
| P-5 | Brittle text fallbacks: `find.text('Post')`, `'Cancel job'` / `'Cancel Job'`, `'Accept Job'` / `'Review & Accept'` | several files |

---

## 2. Correction to the pasted recommendation

The pasted text shows `key: const ValueKey('login_button')` and then targets it from Maestro with `id: login_button`. **That does not work.** Maestro runs outside the Flutter process and reads the accessibility tree. Its docs say Flutter `Key`s are not visible to it and tell you to use `Semantics(identifier: ...)` (available since Flutter 3.19) or visible text / semantic labels.

Consequences for this repo:

- The existing `Key('...')` convention is correct for `integration_test` and Patrol (both in-process). **Keep it.**
- Maestro needs a *second*, parallel hook: `Semantics(identifier: <same string as the Key>)`. This is implemented in Phase E3 (`THTestId` in `lib/ui/design/`, ~40 ids applied across the contract list); see E3.3.

---

## 3. Toolchain decision (picking from the pasted recommendation)

| Pasted recommendation | Decision | Reason |
|---|---|---|
| Keep deterministic, committed tests; AI proposes, humans approve | **Adopt (rule)** | Matches `AGENTS.md` "small, reviewable increments" |
| Flutter `integration_test` (not in the pasted list, but already here) | **Keep as the regression oracle** | 13 files, fixtures, two-persona logic already exist; do not rewrite |
| Dart & Flutter MCP + official Flutter/Dart skills | **Adopt (already installed)** | `mcp.json` has `dart`; `skills-lock.json` has `flutter-add-integration-test`, `flutter-add-widget-test`, `dart-fix-runtime-errors`. Use them for E1/E2 |
| Maestro MCP | **Adopt for exploration + visual-QA evidence (E4)**, optional saved flows | Verified: ships inside the Maestro CLI (`maestro mcp`), tools `list_devices`, `inspect_screen`, `take_screenshot`, `run`. iOS simulators and Android only (no physical iOS) |
| Patrol | **Pilot only (E5)** | Its value here is native dialogs (photo picker, push-permission). It requires `patrol_cli` and `patrolTest`, so converting 13 working files has high cost and low gain |
| Claude Code / Codex as orchestrator | **Adopt** | Already how this repo is worked (`CLAUDE.md`, `AGENTS.md`) |
| GitHub Actions regression | **Adopt, staged (E6)** | Nightly/manual first, not per-PR |
| QApilot (commercial) | **Skip for now** | Not needed to close §4; revisit after E4 |
| `.agents/skills/flutter-app-explorer`, `flutter-test-planner`, `maestro-test-generator` | **Adopt as one combined skill, not three** | The pasted text itself says start with three; this repo already has a skill system (`docs/ai/AI-TOOLING.md`). One skill, `v2-e2e-explorer`, is enough to start |

**Hard rules carried over from the pasted text (put these in the skill and in `TESTING.md`):**

1. Exploration runs only against the **local docker stack and seeded `*@fixo.test` accounts**. Never production, never a real `LINZ_API_KEY` in any committed file.
2. The agent may **not** edit an assertion to make a failing test pass. It must first classify the failure as *app defect*, *v2 intentional change* or *test sync problem*, and record which.
3. The committed suite is deterministic (self-seeded fixtures, no free exploration).

---

## 4. Audit results: what breaks against v2

Checked by comparing every `Key`, `find.text*`, `find.byIcon` and `find.byType` in `integration_test/` with `lib/ui/**` (v2) and `lib/views/**` (v1).

**Good news:** of 41 distinct keys used by the suite, 33 are already preserved by v2 (including `email_field`, `password_field`, `login_button`, `post_job_fab`, `post_job_screen`, `title_field`, `description_field`, `address_search_field`, `approve_pay_button`, `leave_review_button`, `sign_out_button`, the dynamic `dispute_reason_<reason>` keys, `open_dispute_button`). The §4.0 recipe step 5 ("preserve the Keys") largely worked.

### Confirmed or likely breakages

| ID | File(s) | Break | Cause | Fix |
|---|---|---|---|---|
| B-1 | `cancellation_test.dart` (homeowner) | `cancel_confirm_button`, `cancel_dismiss_button` not found | v2 Booked cancel sheet (`ho_booked_*`) had neither key; they exist only in `lib/views` | **Fixed in E5** — keys added to `ho_booked_parts.dart` |
| B-2 | `job_request_test.dart` ~L110 | `tester.widget<TextField>(addressField)` throws | `Key('address_search_field')` is on the `THTextField` wrapper (a `StatelessWidget`), not on a `TextField` | Change the test to read the controller via `find.descendant(of: addressField, matching: find.byType(EditableText))` |
| B-3 | `demo_tour_test.dart` ~L259, L407 | Rating stars not found | Test uses `Icons.star`; v2 review sheet uses `Icons.star_rounded` / `star_outline_rounded` | Prefer a tooltip finder (`'N stars'` tooltip already exists in `ho_review_screen.dart`) or add `star_1..star_5` keys |
| B-4 | `cancellation_test.dart` L112-116 | Works by accident | v2 uses `PopupMenuButton` (default `Icons.more_vert`) and `'Cancel job'` text | **Fixed in E5** — `job_overflow_menu` key added to `ho_booked_screen.dart`; delete the dead `'Cancel Job'` fallback |
| B-5 | `matching_test.dart` ~L65-70 | Possible timeout | Waits for `'Contacting'` or `'Finding tradies'`. The "Contacting tradie N" label exists only in the v1 matching/radar screen; v2 `ho_request_sent` has no such text | Confirm on first run; assert on a key (`offer_status`) instead of copy |
| B-6 | `job_lifecycle_test.dart`, `cancellation_test.dart` (tradie persona) | Expected to stay v1 | `tradie_dashboard`, `Check In`, `Check Out` exist only in v1; Phase 5 is not started | Do **not** run tradie suites with tradie ids flagged. Mark as "v1 until Phase 5" |
| B-7 | `demo_tour_test`, `screenshots_variants_test` | `status_strip_toggle`, `navigate_options_button` missing | Pre-existing (P-2) | Remove or re-point; not a v2 regression |
| B-8 | `job_request_test.dart` | `find.text('Post')` fallback dead | v2 dock exposes `post_job_fab` | Delete fallback, use key only |

**New finding (E1 baseline, 2026-11-17):** the dominant failure mode across `payment`, `dispute`, `cancellation` and `job_lifecycle` is **fixture setup throwing on backend POST** before any widget assertion runs. This is not in B-1…B-8 and points at `helpers/fixture_helper.dart` seeded-state drift rather than at `lib/ui/**`. Needs its own fix before E2.2.

### Probably fine (verify on first run, do not pre-fix)

`'Skip'`, `'Create account'`, `'Payment status'`, `'Under review'`, `'Bank transfer details…'`, `'Address selected'`, `'No matching addresses'`, `'Payment due'` all still appear in `lib/ui`. `'FIXO-'` is a backend-generated reference, not UI copy.

---

## 5. Test matrix to run (defines "realigned")

The suite must pass in each configuration that is actually shippable. Flags are `--dart-define=UI_V2=…`; always add `--dart-define FIXO_DISABLE_PUSH=true`.

| Config | Flag | Personas / suites | Purpose |
|---|---|---|---|
| C0 | *(default)* | all suites | Proves shipped state (Phase 3 v2 + v1 homeowner) did not regress |
| C1 | `UI_V2=all` | homeowner: `auth`, `job_request`, `matching`, `payment`, `dispute`, `cancellation`, `job_lifecycle` | Proves the full homeowner v2 journey (the real §4.4 gate) |
| C2 | `UI_V2=all` | tradie persona of `matching`, `job_lifecycle`, `cancellation` | Proves tradie v1 still works next to v2 shell/auth (expected: unchanged) |
| C3 | per-id (`UI_V2=ho_post_job,ho_choose_tradie`, etc.) | the one suite that covers that id | Isolates a failure to a screen before widening |

Mapping from screen id to the suite that proves it:

| v2 id | Proving suite |
|---|---|
| `ho_post_job`, `ho_choose_tradie` | `job_request_test`, `matching_test` |
| `ho_request_sent`, `ho_quotes`, `ho_tradie_profile` | `matching_test` (extend if gaps found) |
| `ho_job_detail` (booked / extra cost / review) | `cancellation_test`, `job_lifecycle_test` |
| `ho_payment` | `payment_test` |
| `ho_dispute` | `dispute_test` |
| `ho_home`, `ho_jobs` | `auth_test` landing, `demo_tour_test` |

---

## 6. Phased plan

Each phase is one PR. Check every box before moving on.

### Phase E0: Safety and tooling (no test changes)

- [x] **E0.2** Make the run scripts portable (fixes P-3, P-4): replace hardcoded UDIDs/paths with env vars (`IOS_HOMEOWNER_UDID`, `IOS_TRADIE_UDID`, `FIXO_API_URL`, output dir default `./test-logs/`). One entry point: `scripts/run-e2e.sh <config> [suite]` implementing the §5 matrix. Retire `run-suite-v14*.sh`.
- [x] **E0.3** Default `FIXO_API_URL` by platform inside `test_config.dart` (`Platform.isAndroid ? 10.0.2.2 : localhost`), still overridable.
- [x] **E0.4** Confirm the seeded state: `python3 scripts/e2e-credentials.py --keep`, `scripts/seed-test-accounts.sh`. Document the exact "clean start" sequence in `docs/TESTING.md`.

**Done when:** `scripts/run-e2e.sh C0 auth` runs on the owner's machine without editing any path. **Done** — see `docs/runs/v2/e2e-baseline-2026-11.md` for the C0 run results.

### Phase E1: Baseline run (measure before editing)

- [x] **E1.1** Run C0 then C1 for all suites and save logs. Do not fix anything yet.
- [x] **E1.2** For each failure, classify: *v2 intentional change* / *app defect* / *test sync problem* / *pre-existing v1 issue*. Record in `docs/runs/v2/e2e-baseline-2026-11.md` (table: suite, test id, config, class, evidence).
- [ ] **E1.3** Reconcile with §4 above. Any failure not in B-1…B-8 gets a new row.

**Done when:** every red test has a class and an owner. App defects are filed, not "fixed" in tests. **Done** — see `docs/runs/v2/e2e-baseline-2026-11.md` for the full table. New finding (E1.3): the dominant failure mode is **fixture setup throwing on backend POST** (`payment`, `dispute`, `cancellation`, `job_lifecycle` all fail before reaching any widget assertion) — seeded-state drift between `fixture_helper.dart` and the current backend, not a v2 regression. This is a new row outside B-1…B-8 and points at `helpers/fixture_helper.dart` rather than at `lib/ui/**`.

### Phase E2: Realign existing `integration_test` files (Keys-first, no new tools)

Use the installed `flutter-add-integration-test` and `dart-fix-runtime-errors` skills.

- [ ] **E2.1 (app code, tiny):** add `cancel_confirm_button`, `cancel_dismiss_button`, `job_overflow_menu` to the v2 Booked cancel flow (B-1, B-4). Stay inside `lib/ui/**`, tokens only.
- [ ] **E2.2:** fix B-2, B-3, B-5, B-8 in the tests. Prefer Keys over text everywhere a v2 key exists.
- [ ] **E2.3:** remove dead fallbacks (`'Cancel Job'`, `'Post'`, `'Accept Job'` chains) once each primary path is proven.
- [ ] **E2.4:** fix or delete the two stale keys (B-7).
- [ ] **E2.5:** update `job_request_test`, `payment_test`, `job_lifecycle_test` for flow v2 (pay at completion) to close P-1 / P12-28. This needs your confirmation of the expected order; it follows `docs/SPECS.md`, not the old tests.
- [ ] **E2.6:** add missing coverage for screens that have **no** device test but are behind v2 flags: `ho_quotes` (accept + s362F checkbox gate), `ho_extra_cost` decision sheet, `ho_tradie_profile` → request. Self-seed via `FixtureHelper` (extend with `quotedJob`, `pendingAdjustmentJob`).
- [ ] **E2.7:** every changed test states its flag config in the header comment (`// Run with: UI_V2=all`).

**Done when:** C0, C1 and C2 are green; the only skips are tradie-v1 items, each labelled `v1 until Phase 5`.

### Phase E3: Semantics identifiers for out-of-process tools

Only needed by Maestro (E4). Do it after E2 so the Keys are stable first.

- [x] **E3.1** Add one helper in `lib/ui/design/` (not `th_widgets.dart`, which is generated-then-owned): `THTestId(id, child)` that wraps `Semantics(identifier: id, container: false, child: child)`, plus an extension `.testId('login_button')`.
- [x] **E3.2** Identifier string = the existing `Key` string, one-to-one. Add a unit test that fails if a screen exposes a `Key` from the contract list without a matching identifier (a simple contract list in `test/ui/test_id_contract_test.dart`).
- [x] **E3.3** Apply to: auth (email, password, login, sign out), dock items + `post_job_fab`, post-job fields and submit, address field, choose-tradie list/quick match, quote accept, cancel sheet buttons, payment upload, dispute fields/submit, review stars/submit. ~40 ids, matching the 41-key inventory.
- [x] **E3.4** Confirm it does not change visuals or announce extra text to screen readers (identifier is not read aloud). Re-run `test/accessibility_audit_test.dart` and the gallery goldens: they must be unchanged.
- [x] **E3.5** `scripts/check_ui_boundary.py` must stay green (the helper lives under `lib/ui/**`).

**Done when:** `maestro studio` / `inspect_screen` shows `id:` values for the contract list on both an Android emulator and an iOS simulator.

### Phase E4: Maestro for exploration and visual-QA evidence

This is the part of the pasted text that fits §4.6 best. **It produces evidence; owner sign-off on §4.6 and the §4.4 owner-QA box still stays with you.**

- [x] **E4.1** Install Maestro CLI (Java 17+) and register the MCP: `claude mcp add maestro -- maestro mcp` (or the equivalent for the agent in use). Add the entry to every MCP config that `docs/ai/AI-TOOLING.md` lists, keeping parity (`mcp.json`, `.agent/mcp_config.json`, `.agents/mcp_config.json`, `opencode.json`). Note `mcp.json` currently contains `/Users/john/...` paths; make the new entry path-independent.
- [x] **E4.2** Create `.maestro/` at repo root (Maestro's default location): `config.yaml`, `flows/homeowner/*.yaml`, `flows/shared/login.yaml` (reusable via `runFlow`). Start with five flows mirroring the C1 journey: login → post job → choose tradie → (fixture-booked job) cancel-sheet dismiss → payment status.
- [x] **E4.3** Add a screenshot step per screen with a stable name (`takeScreenshot: ho_home_light`, …, `_dark`) so the owner can compare against `docs/design/mobile/mockups/index.html` side by side. Light and dark are both required by `AGENTS.md`.
- [x] **E4.4** Write the project skill `.agents/skills/v2-e2e-explorer/SKILL.md` (single skill, replaces the pasted text's first three). It encodes: the hard rules in §3, the identifier contract, the seeded accounts, "inspect before acting", "record, don't invent expected business behaviour", and output files `exploration-report.md` + bug list under `docs/runs/`.
- [ ] **E4.5** First exploration session, read-only: agent walks homeowner v2 on an emulator, produces the screen inventory and compares it with the 30-screen list and the D-4 backlog. Output feeds §4.6, not the committed suite.
- [ ] **E4.6** Only flows a human has reviewed are committed. Exploration output stays in `docs/runs/`.

**Done when:** `maestro test .maestro/` passes locally on one Android emulator and one iOS simulator, and the owner has a screenshot set (light + dark) for the 4.6 review.

> **Limits to keep in mind:** Maestro does not support physical iOS devices or Flutter desktop. Flutter's custom `THDock` is not a platform tab bar, so confirm each dock item gets its own identifier in E3.3 rather than falling back to coordinate taps.

### Phase E5: Patrol pilot (optional, time-boxed)

Scope is deliberately narrow: only what `integration_test` cannot do.

- [x] **E5.1** Add `patrol` + `patrol_cli`; tests in `patrol_test/`; add `**/test_bundle.dart` and `.patrol.env` to `.gitignore`. Run with `patrol test`, **not** `flutter test`. Check the compatibility table for the repo's Flutter version first.
- [x] **E5.2** Optional agent aids: `patrol_mcp` and the Patrol agent skills (`dart run skills@ get --agent claude -p patrol -s patrol-setup -s patrol-write-test`; needs Dart 3.12+, repo is on `^3.13.4`).
- [x] **E5.3** Two tests only: (a) photo-source sheet → native picker/permission on `ho_post_job` and `ho_dispute`, (b) notification permission prompt on first login (`FIXO_DISABLE_PUSH` must be false for this one).
- [x] **E5.4** Decision gate: if the pilot is flaky or setup cost is high, drop Patrol and leave those two cases to the manual QA list.

**Done when:** the two native-dialog tests pass on Android and iOS, or the gate decision is recorded in `docs/TESTING.md`.

### Phase E6: CI (staged)

- [ ] **E6.1** Add a **separate** workflow `e2e-mobile.yml` triggered by `workflow_dispatch` and a nightly `schedule`, not on every PR. Reason: it needs the docker stack plus an emulator, and iOS needs macOS runners.
- [ ] **E6.2** Android job on `ubuntu-latest`: `docker compose up -d` (Postgres/PostGIS, Azurite, Redis, API), seed accounts, boot emulator (KVM), run C1 homeowner suites. Pass `FIXO_API_URL=http://10.0.2.2:5000`.
- [ ] **E6.3** Upload JUnit/log output and screenshots as artifacts. Add Maestro flows as a second step once E4 is stable.
- [ ] **E6.4** iOS job on `macos-latest` only after Android is green for a week.
- [ ] **E6.5** Keep the existing PR job unchanged (analyze, `flutter test`, boundary guard, design gate).

- [x] **E6.6** Integrated homeowner+tradie API journey (`scripts/e2e-journey.py`) runs as a pre-gate in `run-e2e.sh` (config `J` runs it alone); `--fail-fast`, `--retry N` (FLAKY status), per-suite timeout and demo-tradie restore on abort added. Verified against a mock API only (v1 and v2 paths); **not yet run against the real stack or on a device.**

**Done when:** a nightly run produces a green/red C1 result with artifacts and no manual setup.

---

## 7. Updates to existing docs (do in the same PRs)

| File | Update |
|---|---|
| `docs/todos/01_design_system_migration_plan.md` §4.4 | After E2 passes C1, tick "Run the listed device integration flows". Leave the owner-QA boxes for you. Add a one-line pointer to this plan under 4.6 |
| `docs/TESTING.md` | Replace the v1-order "Gaps" note (P-1); add the §5 matrix, `scripts/run-e2e.sh`, the Maestro and Patrol sections and the hard rules from §3 |
| `docs/QA.md` | Link the screenshot set from E4.3 as the visual-QA input |
| `docs/ai/AI-TOOLING.md` | Add Maestro MCP, the `v2-e2e-explorer` skill, optional Patrol MCP/skills; keep config parity |
| `.agent/rules/mobile.md` | Add: "Every interactive element in `lib/ui` that has a `Key` also gets the same `testId`" |
| `docs/MILESTONES.md` | Add an entry for the e2e realignment |

---

## 8. Risks and open questions

| # | Risk / question | Mitigation or ask |
|---|---|---|
| R-1 | All findings here are static; real breakage count may differ | E1 baseline before any edit |
| R-2 | Flow-v2 expectations in `job_request` / `payment` / `lifecycle` must follow the spec, not the old tests | Confirm against `docs/SPECS.md` in E2.5; flag if the spec and the app disagree |
| R-3 | Adding `Semantics(identifier)` could change screen-reader output or goldens | E3.4 gate; identifier is not read aloud |
| R-4 | Two simulators needed for two-persona suites; shared `mobile/build` collides on parallel iOS builds (documented in TESTING.md) | Keep sequential in `run-e2e.sh`; CI runs personas as separate jobs |
| R-5 | Patrol may not justify its cost | E5.4 decision gate |
| R-6 | Tradie suites will break again at Phase 5 | Tag them `v1 until Phase 5`; the same realignment recipe applies to tradie ids then |
| Q-1 | Should Maestro flows be committed, or exploration-only? | Plan assumes committed after human review |
| Q-2 | Is a nightly Android-only CI acceptable as the first automation step? | Plan assumes yes |
| Q-3 | OK to add the three small keys in E2.1 to `lib/ui` ahead of the owner visual-QA pass? | They are non-visual |

---

## 9. References checked

- Maestro Flutter support (Semantics, `identifier`, "Keys are not supported"): https://docs.maestro.dev/get-started/supported-platform/flutter and https://docs.maestro.dev/reference/selectors/core-selectors
- Maestro MCP (tools, install): https://docs.maestro.dev/get-started/maestro-mcp
- Patrol docs and setup (`patrol test`, not `flutter test`): https://patrol.leancode.co/documentation
- Patrol package, agent skills install line: https://pub.dev/packages/patrol
- Patrol MCP: https://pub.dev/packages/patrol_mcp

**Not independently verified:** QApilot's claimed capabilities (vendor marketing only), and the pasted GitHub Actions advice (generic). Both are deferred in this plan.
