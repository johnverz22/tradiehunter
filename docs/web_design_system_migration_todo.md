# Web Admin Design System Migration — Todo

> Companion to `docs/web_design_system_migration_plan.md` (read it first; section numbers refer to it).
> Strategy assumed: **Option B** (edit `web/` in place behind a temporary compat shim). If D1 changes, Phase 1+ tasks are rewritten.
> **Manual/e2e verification is deferred by the owner (2026-11-18):** scripted tasks proceed first; every e2e run, screenshot and visual check below marked *deferred* is done manually later. Until then "verified" in this file means lint + build + design gate + guards only.
> Convention: `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S ≤ 1h, M ≤ half a day, L ≥ 1 day.
> Every page task (P3/P4) uses the **per-page recipe** (plan §4) and is done only when its parity list is complete, its frame matches in light + dark at 1280/820/390, lint + build + its e2e spec + render-probe pass, and a reviewer who did not write it has checked it.

---

## Phase 0 — Sign-off and baseline

- [x] **0.1** Owner confirms strategy D1: **B approved 2026-11-18** (S)
- [x] **0.2** Owner answers D2–D8: **all proposed defaults approved 2026-11-18** (S)
- [~] **0.3** Baseline in `web/` on the `design` branch: `npm ci`, `npm run lint` (0 errors, 1 warning: `isAdminAuthenticated` in `services/adminApi.ts`) and `npm run build` pass. **Deferred by owner (2026-11-18), to be done manually later — e2e not run:** `npm run test:e2e` needs a live API and a Chromium install, neither available in the cloud session; run it locally and record the result here (S)
- [~] **0.4** Capture before-shots of all 17 routes, light + dark, via `web/e2e/admin-shots.mjs` (it uses 1440/900x1180/390 and writes to `docs/runs/...` inside the repo; set it to write outside the repo or do not commit the output). **Deferred by owner (2026-11-18), to be done manually later — needs a browser and the live app. Without these shots, the Phase 1.8 and 5.1 visual diffs have no baseline; the `pre-web-design-migration` tag lets them be captured from the old UI at any time** (M)
- [x] **0.5** Tag `pre-web-design-migration` and create branch `design-web-migration`. Branched off `design`, not `dev`: `dev` lacks `docs/design/web` and `design` lacks 12 `dev` commits, so merge `dev` into the branch before the final merge (S)
- [x] **0.6** Run `node docs/design/web/tools/build.mjs --check` and confirm green: `check ok: 18 frames, 26 files, contrast 126/126 pass` (S)

## Phase 1 — Foundation

- [x] **1.1** Copy `tokens/tokens.css`, `tokens/theme.css` → `web/src/theme/`; copy `css/kit.css` → `web/src/theme/components.css`; delete `design-tokens.css` (S)
  - Done: Copied `tokens.css`, `theme.css`, `kit.css`→`components.css`; deleted `design-tokens.css`.
- [x] **1.2** Rewrite `web/src/index.css`: new import order, remove old `@theme` and `@custom-variant`, keep resets and base type (M)
  - Done: `index.css` rewritten: new import order, old `@theme`/`@custom-variant` removed, base type/focus/hr on new tokens, shell sizes derived from `--sz-*`.
- [x] **1.3** Copy `fonts/` → `web/public/fonts/`; import `fonts.css` first; remove Google Fonts `<link>`s (S)
  - Done: Fonts copied to `public/fonts/`, loaded by `<link>` in `index.html` (not CSS `@import`: Vite would rewrite the font URLs and drop the woff2 files); Google Fonts removed; two preloads.
- [x] **1.4** `web/index.html`: keep blocking theme script; update `theme-color`, title, description (S)
  - Done: `theme-color` `#1E3A8A`, title and description say TradieHunter; blocking theme script and `fixo-theme` key untouched (6.3).
- [x] **1.5** Write `web/src/theme/legacy-compat.css`: variable aliases, legacy `@theme` colour names, legacy class shims, layout/type vars per D3; tag each rule `legacy: remove in P6` (L)
  - Done: `legacy-compat.css` written: variable aliases, legacy Tailwind colour names, classes with no kit equivalent, legacy stepper/timeline scoped with `:has()`.
- [x] **1.6** Add sync check (`web/scripts/sync-design.mjs` + npm script + CI step) that fails when `web/src/theme/{tokens,theme,components}.css` differ from `docs/design/web` (M)
  - Done: `web/scripts/sync-design.mjs`, `npm run design:sync` / `design:check`, CI step in `web-build-test`; 24 files identical.
- [x] **1.7** Add lint/CI guard banning new legacy names outside `legacy-compat.css` (M)
  - Done: `web/scripts/check-legacy-names.mjs` ratchet + `legacy-baseline.json` (302 uses in 42 files), `npm run design:legacy` / `design:legacy:update`, CI step.
- [~] **1.8** Verify: lint (0 errors, same 1 warning), build and design gate pass; `design:check` and `design:legacy` pass. **Deferred by owner:** full e2e and screenshot diff vs 0.4 (M)
  - Known visual deltas to look for in the manual pass: `.btn-danger` is now the kit's filled danger button (legacy was outline; 3 files); `--brand-500` maps to `--ink-brand`, so the white-on-`--brand-500` avatar in `UserDetailPage` needs a contrast check in dark mode; legacy `.table`/`.th`/`.td` take the kit table look

## Phase 2 — Shared components and shell

Foundations
- [ ] **2.1** `Button` (`kind`, `size`, `loading`, `icon`) — extract and adopt (M)
- [ ] **2.2** `Badge` (`tone`, `dot`, `size`) + `StatusBadge` on the new status map; `PayoutStatusBadge` follows (M)
- [ ] **2.3** `Field` (`label`, `help`, `error`, `optional`) with `aria-describedby` (M)
- [ ] **2.4** `EmptyState` (S)
- [ ] **2.5** `Toast` (inverse surface, success/info auto-dismiss 3 s, errors persist and also appear inline) (M)

Existing components (keep names and props)
- [ ] **2.6** `Banner` (`role` alert/status, icon tile, no side stripe) (S)
- [ ] **2.7** `Modal` + `ConfirmModal` (focus trap, Esc, return focus, Cancel first when destructive, bottom sheet < 640) (L)
- [ ] **2.8** `DataTable` (`.table-wrap`/`.table`, sticky header, `aria-sort`, hidden actions header, scrolls in wrapper) (L)
- [ ] **2.9** `FilterBar` (`role="search"`, chips `aria-pressed`) (S)
- [ ] **2.10** `Pagination` (`aria-current`, labelled prev/next) (S)
- [ ] **2.11** `PageHeader` + breadcrumb (S)
- [ ] **2.12** `StatCard` / `StatGrid` (attention variant, link label) (S)
- [ ] **2.13** `DescriptionList` / `InfoRow` (`dl`, `total` row, stacks < 640) (S)
- [ ] **2.14** `JobProgressStepper` (continuous connectors, vertical < 768); update the 7 `.step-label` e2e assertions to role/aria (D6) (M)
- [ ] **2.15** `ThemeToggle` (S)

Shell
- [ ] **2.16** `AppShell`, `AdminLayout` (240 / 64 rail / drawer breakpoints, content max 1280) (M)
- [ ] **2.17** `SidebarNav` + `navItems` (gold marker, `aria-current`, rail keeps labels in DOM) (M)
- [ ] **2.18** `MobileDrawer`, `TopBar`, `UserMenu` (`role="menu"`, arrow keys, Esc) (M)
- [ ] **2.19** `BrandWordmark` / `useBrandConfig` rendering on the new tokens (no `--hue`) (S)
- [ ] **2.20** Verify against `dashboard`, `dashboard_rail`, `dashboard_phone`, `nav_drawer`; e2e green (M)

## Phase 3 — Entry, simple and list pages

- [ ] **3.1** `AdminLogin` — frame `login` (M)
- [ ] **3.2** `Forbidden` — frame `forbidden` (S)
- [ ] **3.3** `DashboardPage` + `MetricsCard` — frame `dashboard`; charts per D2 (L)
- [ ] **3.4** `JobListPage` — frame `jobs` (M)
- [ ] **3.5** `UserListPage` — frame `users` (M)
- [ ] **3.6** `AuditLogsPage` (+ `features/admin/AuditLogs.tsx` wrapper) — frame `audit_logs` (M)
- [ ] **3.7** `SettingsPage` — frame `settings` (form pattern) (M)
- [ ] **3.8** `DisputesPage` — frame `disputes` (M)

## Phase 4 — Queues, detail pages and dialogs

Queues
- [ ] **4.1** `CredentialQueue` — frame `credentials` (M)
- [ ] **4.2** `PaymentQueue` + `PaymentReviewModal` — frame `payments` (L)
- [ ] **4.3** `OverduePayments` — queue pattern, no frame (M)
- [ ] **4.4** `PayoutQueue` + `ProcessPayoutModal` — frame `payouts` (L)
- [ ] **4.5** `PayoutBatches` — queue pattern, no frame (M)
- [ ] **4.6** `RefundQueue` + `ProcessRefundModal` — queue + dialog pattern, no frame (L)

Detail
- [ ] **4.7** `JobDetailPage` — frames `job_detail`, `job_detail_phone` (L)
- [ ] **4.8** `UserDetailPage` — frame `user_detail` (largest page, 43 legacy refs) (L)
- [ ] **4.9** `DisputeDetailPage` — frame `dispute_detail` (L)
- [ ] **4.10** `PayoutBatchDetail` — detail pattern, no frame (M)
- [ ] **4.11** `AuditDiffModal` — dialog pattern (S)

## Phase 5 — Review sweep

- [ ] **5.1** Whole-app screenshot pass vs 0.4 and frames, light + dark, 3 widths; log and fix differences (L)
- [ ] **5.2** Cross-page consistency audit with the `ui-audit` skill (M)
- [ ] **5.3** Accessibility pass: focus rings, keyboard on dialogs/menus/tables, 44 px targets, `forced-colors`, `prefers-reduced-motion` (M)
- [ ] **5.4** `responsive.spec.ts` and all e2e specs green on the final UI (S)

## Phase 6 — Cutover and cleanup

- [ ] **6.1** Grep proves zero legacy names outside `legacy-compat.css`; delete `legacy-compat.css`; remove guard allow-list (M)
- [ ] **6.2** Remove dead CSS, unused assets (`react.svg`, `vite.svg`) and unused components (S)
- [ ] **6.3** Rename `TradieFixo` → `TradieHunter` in `index.html` and `useBrandConfig`; handle `fixo-theme` key per D4 (S)
- [ ] **6.4** Update docs via `docs-sync`: `docs/design/web/DESIGN_GUIDE.md` §10/§12 + `README.md`, `docs/DESIGN.md`, `docs/MILESTONES.md`, `docs/ai/AI-TOOLING.md`, `AGENTS.md`/`CLAUDE.md`/`GEMINI.md`, `docs/README.md` (M)
- [ ] **6.5** Remove this todo and the plan file (fold lasting content into the docs above) (S)
- [ ] **6.6** Merge `design-web-migration` → `dev`; tag `web-design-v1` (S)

---

## Parked / blocked

_None yet. Add `[~] <task> — parked: <why>` here._
