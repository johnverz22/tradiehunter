# E2E Persona Fabric: one manifest, three tiers

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Turn the current single-journey E2E/QA coverage into a realistic, automated functional test across the API, mobile (Flutter) and web admin (React) tiers. All three tiers exercise the **same users and jobs**, provisioned once per run.
> **Status:** Not started · **Prepared:** 2026-11-26
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

- [ ] **P0.1** Read the docs listed in §0; note the cancellation rules, review-eligibility rules and dispute rules from `SPECS.md` that the scenarios below must encode (S)
- [ ] **P0.2** Determine how the API exposes signup and verification (email code, token, auto-verify in dev?) so `e2e-personas.py` can drive it for real (S)
- [ ] **P0.3** Determine whether the API can still create **v1** jobs. If not, drop the v1 scenario and record why (S)
- [ ] **P0.4** Check which staff flows the mobile app exposes. If none, staff is API + web only (S)
- [ ] **P0.5** Confirm from `docs/MVP.md` what the web admin covers in MVP scope: payments, disputes, users, jobs. Record the list; it bounds P4 (S)
- [ ] **P0.6** Inventory what `e2e-journey.py` hardcodes (`*@fixo.test` creds, seeded accounts) so P2 can switch it to manifest loading without breaking the single-journey gate (S)

## Phase P1 — Persona provisioning (`scripts/e2e-personas.py`, new)

- [ ] **P1.1** CLI: `--homeowners N --tradies N --staff 1|2 --run-id ID --out PATH`; default run id is a timestamp slug (S)
- [ ] **P1.2** Create accounts as `qa+<runid>-<role>-<n>@fixo.test` through real signup and verification as the API exposes it (M)
- [ ] **P1.3** Complete any role onboarding the tradie needs to receive matches (profile, trade, service area, payout details if required by the API) (M)
- [ ] **P1.4** Write the manifest JSON: role, email, password, user id, created job ids (job ids appended by later tiers) (S)
- [ ] **P1.5** Namespacing is enough to leave data in the DB; add optional `--cleanup` that only touches `qa+<runid>-*` accounts via supported API routes (S)
- [ ] **P1.6** Refuse non-localhost `FIXO_API_URL`; support `--timeout`, `--retry` (S)
- [ ] **P1.7** `python3 -m py_compile scripts/e2e-personas.py` (S)

## Phase P2 — API tier (extend `scripts/e2e-journey.py`)

- [ ] **P2.1** Load personas from the manifest (`--manifest PATH`); keep the seeded-accounts path so the existing single-journey gate still works (M)
- [ ] **P2.2** Every step asserts the response **and** the resulting job via GET: status, history, decimal-string amounts (M)
- [ ] **P2.3** Scenario: happy path v2. post -> match -> offer -> accept -> book -> chat -> check-in -> check-out -> approve -> receipt -> staff verify -> complete -> review (M)
- [ ] **P2.4** Scenario: competing offers. 2+ tradies bid on one job; homeowner picks one; the others end declined/withdrawn per spec (M)
- [ ] **P2.5** Scenarios: decline and withdraw paths; job with no matches; re-post (M)
- [ ] **P2.6** Scenarios: cancellation by homeowner and by tradie, following the `SPECS.md` rules per state (M)
- [ ] **P2.7** Scenario: staff rejects receipt -> homeowner resubmits -> staff verifies (M)
- [ ] **P2.8** Scenarios: dispute open/resolve; chat in both directions; attachment upload; review eligibility rules (positive and negative cases) (L)
- [ ] **P2.9** Scenario: v1 in-flight path, only if P0.3 says the API can still create v1 jobs (M)
- [ ] **P2.10** Append created job ids to the manifest so the mobile and web tiers can find them (S)
- [ ] **P2.11** JUnit XML output preserved; `--fail-fast`, `--retry`, timeout preserved (S)
- [ ] **P2.12** `python3 -m py_compile scripts/e2e-journey.py` (S)

## Phase P3 — Mobile tier (Flutter)

- [ ] **P3.1** Choose the driver: prefer Maestro YAML flows (Maestro MCP is configured); otherwise `integration_test/` driver tests using `fixture_helper.dart` patterns. Record the decision and why (S)
- [ ] **P3.2** Maestro needs `Semantics(identifier: ...)`; Flutter `Key`s are invisible to it (see `03_e2e_realignment_plan.md` §2). Reuse `THTestId` ids rather than adding new hooks where possible (S)
- [ ] **P3.3** Add a manifest loader for the chosen driver so persona credentials and job ids are read, not hardcoded (M)
- [ ] **P3.4** Homeowner flow: post job, see offers, accept, chat, approve completion, submit receipt (L)
- [ ] **P3.5** Tradie flow: see request, accept, check in, check out (L)
- [ ] **P3.6** Staff flow only if P0.4 found one in the app (M)
- [ ] **P3.7** Run flows in light and dark wherever they screenshot. Assert behaviour, not pixels, except the existing golden/render checks; respect the v2 design contract (M)
- [ ] **P3.8** Verify on a debug build on emulator/simulator. Document whether any step requires a physical device (S)
- [ ] **P3.9** If mobile code was touched: `flutter analyze --fatal-infos` and `flutter test` (S)

## Phase P4 — Web admin tier (React)

- [ ] **P4.1** Choose the harness: extend `scripts/web/render-probe.py` or use the existing Playwright setup in `web/e2e/`. Check `web/package.json` first; ask before adding any dependency (S)
- [ ] **P4.2** Add manifest loading for the web tier (S)
- [ ] **P4.3** Staff persona logs into admin and finds the payment submitted by the API tier (M)
- [ ] **P4.4** Assert job and user state in the UI matches the API (status, decimal-string amounts) on rendered markup, as `render-probe` does (M)
- [ ] **P4.5** Handle dispute resolution only if the admin UI exposes it per P0.5 (M)
- [ ] **P4.6** If web was touched: `npm run lint`, `npm run build`, and the relevant `npm run test:e2e` specs (S)

## Phase P5 — Orchestration (`scripts/run-e2e.sh` and friends)

- [ ] **P5.1** Add a single pipeline entry: personas -> API -> mobile -> web, passing the manifest path between tiers (M)
- [ ] **P5.2** Preserve `--fail-fast`, `--retry`, timeout and cleanup flags; add the equivalent to every new entry point (S)
- [ ] **P5.3** Per-tier result summary at the end (pass/fail/skipped, with reasons for any skip) (S)
- [ ] **P5.4** `bash -n scripts/run-e2e.sh` and any other shell file changed (S)

## Phase P6 — Docs and verification

- [ ] **P6.1** Update `docs/TESTING.md` (new scripts, manifest format, how to run each tier) (S)
- [ ] **P6.2** Update `docs/QA.md` (what the fabric covers; what is still manual) (S)
- [ ] **P6.3** Update `docs/todos/03_e2e_realignment_plan.md` status and cross-link this plan (S)
- [ ] **P6.4** Run the `docs-sync` skill if SPECS/MVP behaviour was affected (S)
- [ ] **P6.5** `python3 -m py_compile` on all new/changed scripts; `bash -n` on shell changes; mobile and web checks if touched (S)
- [ ] **P6.6** Run the **full pipeline once against the seeded local stack** and paste the per-tier results into this file (M)
- [ ] **P6.7** List every scenario blocked by a missing backend endpoint, with the endpoint needed. Document; do not work around (S)

---

## Definition of done

All three tiers run from one manifest against the local stack, per-tier results are recorded below, every compile/lint/analyze check in P6.5 passes, docs are updated, and blocked items are documented.

## Results log

_(paste the P6.6 run output here)_

## Decisions and parked items

_(record P0 findings, P3.1/P4.1 driver choices, and anything `[~]` here)_
