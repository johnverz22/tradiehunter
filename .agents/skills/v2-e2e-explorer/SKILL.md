---
name: v2-e2e-explorer
description: Autonomous exploration, visual QA evidence generation, and Maestro E2E flow authoring for the v2 (Trust Navy + Gold) Flutter mobile app.
metadata:
  model: inherit
  last_modified: Mon, 17 Nov 2026 21:39:00 GMT
---

# v2 E2E Explorer Skill

Use this skill when exploring the Fixo mobile app using Maestro / Maestro MCP, capturing visual QA screenshots against design mockups (`docs/design/mobile/mockups/index.html`), or authoring and debugging out-of-process E2E flows.

## 1. Hard Rules (Non-Negotiable)

1. **Target Environment & Accounts:**
   - Exploration runs **only** against the local Docker backend stack (`docker compose up -d`) and seeded `*@fixo.test` accounts (e.g., `homeowner-a@fixo.test`, `tradie-verified@fixo.test` with password `Test1234!`).
   - **Never** hit production endpoints.
   - **Never** commit real `LINZ_API_KEY` or third-party secrets to any file.

2. **No Faking or Altering Assertions:**
   - The agent may **not** weaken or edit an assertion just to make a failing test or flow pass.
   - Every failure must be classified and recorded:
     - `app_defect`: UI or logic bug in the application.
     - `v2_intentional`: Deliberate design system or flow change.
     - `test_sync`: Selector, timing, or fixture desynchronization.
     - `v1_legacy`: Pre-existing v1 defect or v1 screen waiting for migration.

3. **Deterministic Committed Suite:**
   - Free exploratory testing is for evidence gathering and defect discovery.
   - Committed Maestro flows (`.maestro/flows/**/*.yaml`) and Flutter `integration_test/` files must remain strictly deterministic with seeded fixtures and reproducible steps.

4. **Inspect Before Acting:**
   - Always query screen semantics or inspector hierarchy (`inspect_screen` / `maestro studio`) before tapping or typing to verify element presence and accessibility state.

5. **Record, Do Not Invent Business Behaviour:**
   - Adhere strictly to `docs/SPECS.md` and `docs/MVP.md` (e.g., Flow v2 pay-at-completion, manual bank transfer review, dispute triggers, cancellation windows).
   - If UI behaviour diverges from specifications, log it in the report rather than guessing or fabricating missing endpoints.

---

## 2. Test Identifier Contract

Flutter `Key` values live inside the Dart VM and are invisible to out-of-process drivers like Maestro.

- **Identifiers:** Every interactive element in `lib/ui` that exposes a `Key('foo')` must also expose an identical semantics identifier via `THTestId`, `.testId('foo')`, or auto-mirroring `TH*` primitives (`THButton`, `THTextField`, `THDock`, etc.):
  ```dart
  // Example:
  THButton(
    key: const Key('login_button'),
    label: 'Log in',
    onPressed: _submit,
  ) // automatically provides Semantics(identifier: 'login_button')
  ```
- **Validation:** Contract integrity is checked automatically by `mobile/test/ui/test_id_contract_test.dart`.
- In Maestro flows, target elements using `id: "identifier_name"`:
  ```yaml
  - tapOn:
      id: "login_button"
  ```

---

## 3. Seeded Accounts & Credentials

| Persona | Email | Password | Role / Purpose |
|---|---|---|---|
| Homeowner | `homeowner-a@fixo.test` | `Test1234!` | Primary homeowner persona |
| Tradie | `tradie-verified@fixo.test` | `Test1234!` | Verified & insured tradie persona |
| Staff / Admin | `staff@fixo.test` | `Test1234!` | Admin review & manual payment confirmation |
| Unverified | `unverified@fixo.test` | `Test1234!` | Unverified account (tests OTP gate) |

Seeding command: `python3 scripts/e2e-credentials.py --keep` and `scripts/seed-test-accounts.sh`.

---

## 4. Visual QA Screenshot Protocol

Maestro captures screenshots for direct visual comparison against the 30 v2 design mockups (`docs/design/mobile/mockups/index.html`):

- **Naming Convention:** `takeScreenshot: <screen_id>_<theme>`
  - Examples: `ho_home_light`, `ho_home_dark`, `ho_post_quick_light`, `ho_choose_tradie_light`, `ho_job_booked_light`, `ho_payment_status_light`.
- **Theme Testing:** Both Light and Dark modes are required by project rules. Ensure screenshots are captured under both themes where applicable.

---

## 5. Output Artifacts

Exploration sessions must record findings into:
1. `docs/runs/exploration-report.md`:
   - Summary of screens visited.
   - Screen inventory cross-referenced against the 30 v2 screen AST list in `docs/design/mobile/ast/screens.mjs`.
   - Maestro run outcomes and execution logs.
2. `docs/runs/e2e-defect-backlog.md`:
   - Itemized table of any visual regressions, missing identifiers, broken flows, or API mismatches discovered during exploration.
