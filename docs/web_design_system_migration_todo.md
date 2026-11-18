# Web Admin Design System Migration — Todo

> Companion to `docs/web_design_system_migration_plan.md` (read it first; section numbers refer to it).
> Strategy assumed: **Option B** (edit `web/` in place behind a temporary compat shim). If D1 changes, Phase 1+ tasks are rewritten.
> Convention: `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S ≤ 1h, M ≤ half a day, L ≥ 1 day.
> Every page task (P3/P4) uses the **per-page recipe** (plan §4) and is done only when its parity list is complete, its frame matches in light + dark at 1280/820/390, lint + build + its e2e spec + render-probe pass, and a reviewer who did not write it has checked it.

---

## Phase 0 — Sign-off and baseline

- [ ] **0.1** Owner confirms strategy D1 (B / A / flagged `src/ui/`) (S)
- [ ] **0.2** Owner answers D2–D8 or accepts the proposed defaults (S)
- [ ] **0.3** Confirm `dev` is green: `npm run lint`, `npm run build`, `npm run test:e2e` in `web/` (S)
- [ ] **0.4** Capture before-shots of all 17 routes, light + dark, 1280/820/390 via `web/e2e/admin-shots.mjs`; keep outside the repo (M)
- [ ] **0.5** Tag `pre-web-design-migration`; create branch `design-web-migration` off `dev` (S)
- [ ] **0.6** Run `node docs/design/web/tools/build.mjs --check` and confirm green (S)

## Phase 1 — Foundation

- [ ] **1.1** Copy `tokens/tokens.css`, `tokens/theme.css` → `web/src/theme/`; copy `css/kit.css` → `web/src/theme/components.css`; delete `design-tokens.css` (S)
- [ ] **1.2** Rewrite `web/src/index.css`: new import order, remove old `@theme` and `@custom-variant`, keep resets and base type (M)
- [ ] **1.3** Copy `fonts/` → `web/public/fonts/`; import `fonts.css` first; remove Google Fonts `<link>`s (S)
- [ ] **1.4** `web/index.html`: keep blocking theme script; update `theme-color`, title, description (S)
- [ ] **1.5** Write `web/src/theme/legacy-compat.css`: variable aliases, legacy `@theme` colour names, legacy class shims, layout/type vars per D3; tag each rule `legacy: remove in P6` (L)
- [ ] **1.6** Add sync check (`web/scripts/sync-design.mjs` + npm script + CI step) that fails when `web/src/theme/{tokens,theme,components}.css` differ from `docs/design/web` (M)
- [ ] **1.7** Add lint/CI guard banning new legacy names outside `legacy-compat.css` (M)
- [ ] **1.8** Verify: lint, build, full e2e, screenshot diff vs 0.4, design gate (M)

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
