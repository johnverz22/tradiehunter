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
- [x] **2.1** `Button` (`kind`, `size`, `loading`, `icon`) — extract and adopt (M)
  - Done: `components/Button.tsx`: `Button` (`kind` default primary, `size`, `loading` with aria-busy and click blocked, `icon`, `block`) and `IconButton` (required `label` → aria-label). Not yet adopted by pages: raw `btn btn-*` markup is replaced per page in Phase 3/4.
- [x] **2.2** `Badge` (`tone`, `dot`, `size`) + `StatusBadge` on the new status map; `PayoutStatusBadge` follows (M)
  - Done: `components/Badge.tsx` (`tone`, `dot`, `size`); `StatusBadge` now uses the COMPONENTS.md status map with dot; `PayoutStatusBadge`/`BatchStatusBadge` moved to `Badge` (Pending→warn, Scheduled→info, Processed→ok, Failed→danger; Open→info, Processing→warn, Completed→ok: payout statuses are not in the design status map, mapped by legacy colour).
- [x] **2.3** `Field` (`label`, `help`, `error`, `optional`) with `aria-describedby` (M)
  - Done: `components/Field.tsx`: render-prop `Field` (`label`, `help`, `error`, `optional`) wiring `id`, `aria-describedby` (error first) and `aria-invalid` via `useId`; error shows icon + text.
- [x] **2.4** `EmptyState` (S)
  - Done: `components/EmptyState.tsx` (`title`, description child, `icon`, `action`).
- [x] **2.5** `Toast` (inverse surface, success/info auto-dismiss 3 s, errors persist and also appear inline) (M)
  - Done: `components/Toast.tsx` (`Toast`, `ToastProvider`) + `toast-context.ts` (`useToast`): info/ok auto-dismiss at 3 s, warn/danger persist with `role="alert"`, always a Dismiss button; provider mounted in `main.tsx`. No page calls it yet; per the design rule, errors must also be shown inline when pages adopt it. The kit defines no `.toast-ok/-warn/-danger` rules (tone lives in the icon tile), the classes are harmless hooks.

Existing components (keep names and props)
- [x] **2.6** `Banner` (`role` alert/status, icon tile, no side stripe) (S)
  - Done: `components/Banner.tsx` renders the kit markup (`.banner banner-{info|ok|warn|danger}`, `.tile.tile-xs` icon tile, `.banner-body`, `.banner-actions` with the shared `Button` ghost/sm). Props and variant names unchanged (`variant`, `children`, `action`, `className`); added optional `title` (shows `.banner-title` + `.banner-text`; without it the message renders as plain body text). Deviation: `success` is now `role="status"` (was `alert`) per COMPONENTS.md; only `error` is `role="alert"`. No page edited; the 17 call sites still pass only `children`, so frame-style titles are added when each page is migrated. Legacy baseline 289 → 283 uses (40 → 39 files).
  - [~] Deferred (manual): visual check of all four variants in light + dark against `dashboard` / `user_detail` / `dispute_detail` / `job_detail` frames; check the `action` button wraps sensibly at 390 (kit `.banner` does not wrap; if it squeezes, fix in the design system, not here).
- [x] **2.7** `Modal` + `ConfirmModal` (focus trap, Esc, return focus, Cancel first when destructive, bottom sheet < 640) (L)
  - Done: `components/Modal.tsx` renders the kit `.scrim > .modal(.modal-sm|.modal-lg) > .modal-head/.modal-body/.modal-foot`; the < 640 bottom sheet is now pure kit CSS, so `useBreakpoint`, the handle bar and the Tailwind/`card-pop` markup are gone. Props unchanged (`open`, `onClose`, `title`, `ariaLabelledBy`, `size`, `children`, `footer`, `showCloseButton`). Close is an `IconButton` (label "Close"). Focus: trap and Esc kept; focus is saved on open and restored in the effect cleanup (so it also returns when a parent unmounts the modal, e.g. `ProcessRefundModal`); initial focus = `[data-autofocus]`, else first focusable in the body, else first in the dialog (was: first focusable overall, often the ✕). Scrim closes on a press on the scrim itself only. `ConfirmModal`: props unchanged; title now in `.modal-head`, footer is Cancel (`secondary`) then commit (`accent`, or `danger` when `destructive`), Cancel gets `data-autofocus` when destructive; the warning icon is dropped (the frame has none; the destructive tone is the red button and the text). Legacy baseline 283 → 276 uses (39 → 37 files). No e2e selector changed (all specs use role/name).
  - Deviations to know: non-destructive confirms are now gold (`accent`, was navy `primary`) and Cancel is `secondary` (was ghost), per DESIGN_GUIDE "Confirm dialog"; destructive confirm is the kit's filled danger button.
  - Follow-ups (other tasks, not done here): `FilterBar` (2.9), `ProcessRefundModal` (4.6) and `AuditDiffModal` (4.11) still pass their own footer wrappers (`flex …` divs) and legacy classes; when migrated they should pass bare `Button`s so the kit's stacked footer works on phones. `AuditDiffModal` passes an `aria-label` prop that `Modal` ignores (pre-existing); give it a `title` when migrated.
  - [~] Deferred (manual): keyboard walk of a confirm and a destructive confirm (Tab/Shift+Tab trap, Esc, focus returns to the trigger, Cancel focused first when destructive); visual check against the `payments` frame modal in light + dark at 1280/820/390 (bottom sheet < 640, stacked footer, safe-area padding).
- [x] **2.8** `DataTable` (`.table-wrap`/`.table`, sticky header, `aria-sort`, hidden actions header, scrolls in wrapper) (L)
  - Done: `components/DataTable.tsx` renders `.table-wrap > table.table` (sticky header from the kit, pagination inside the wrapper under the table as in the `jobs` frame), `<th scope="col">`, sortable headers are real `<button>`s with `aria-sort` on the sorted header only (was: click handler on the `<th>`), the actions column has a visually hidden "Actions" header and `td.actions`, right-aligned columns use `.num`, skeleton rows use `.skeleton` with `aria-busy` on the table, empty/error cells use `.muted`. Row actions use kit `Button` classes (`primary`→`btn-primary`, `ghost`→`btn-ghost`, `danger`→`btn-danger-outline` so a row stays calm; size sm). Props unchanged (`columns`, `rows`, `getRowKey`, `getRowClassName`, `onRowClick`, `isLoading`, `empty`, `error`, `sortState`, `onSort`, `rowActions`, `pagination`, `mobileCard`, `skeletonCount`); added optional `caption` (visible `<caption>`, for tables not under a heading; no page passes it yet). Tablet-portrait hiding of `detail` columns kept. Phone card list kept and restyled on tokens (`.card`, `--line`, `--surface-alt`, `--sh-pop`, `--danger*`, kit buttons, 44 px menu rows); removed the invalid `role="row"` on card `<li>`s. Legacy baseline 276 → 263 uses (37 → 36 files). No e2e selector changed (specs use `table tbody tr` and roles).
  - **Open decision D9 (needs owner):** DESIGN_GUIDE §6 / COMPONENTS.md say tables on phones *scroll inside their wrapper* (min 640 px); the app renders a **card list** under 640 px (with a "More" menu and 44 px actions). Removing it changes behaviour, so I kept it. Options: (a) keep the card list and add it to the design system as a phone pattern (recommended: better for the thumb-driven queues), (b) drop it and let the table scroll as designed (then delete `CardList`, `mobileCard` and the "More" menu in a follow-up). Does not block other tasks.
  - Known visual deltas for the manual pass: header cells are now the kit's uppercase label style on `--surface-alt`; row height `--sz-table-row`; the sort icon only shows on the active column (unchanged); pagination (still legacy-styled until 2.10) now sits inside the bordered wrapper; row-action danger buttons are outline, not filled.
  - [~] Deferred (manual): visual check of a queue and a list page against the `jobs` / `credentials` / `payments` frames in light + dark at 1280/820/390 (table scroll inside wrapper at 820; phone card list at 390); keyboard check of sort buttons (Enter/Space, `aria-sort` announcement) and the "More" menu.
- [x] **2.9** `FilterBar` (`role="search"`, chips `aria-pressed`) (S)
  - Done: `components/FilterBar.tsx`: tablet/desktop render the kit `.filterbar` with `role="search"` (replaces the flex/2-column-grid Tailwind classes); phone keeps search + "Filters" button + bottom sheet (`role="search"` on the row; button is a kit `Button` secondary with the count as a `Badge` plus sr-only "active filters", no longer an absolutely positioned colour-only circle on `--brand-700`). Sheet footer is now bare `Button`s (Clear all secondary, Apply gold) so the kit's stacked phone footer applies (closes the `Modal` follow-up for `FilterBar`). Props unchanged (`children`, `activeFiltersCount`, `onClear`). Chips are page-supplied children: the `aria-pressed` chip markup (`.chip`) is applied when each page is migrated, `FilterBar` has no chip logic.
  - [~] Deferred (manual): visual check against the `jobs` frame filter bar (search grows to 360, selects follow, wraps at 820) and the phone sheet at 390, light + dark.
- [x] **2.10** `Pagination` (`aria-current`, labelled prev/next) (S)
  - Done: `components/Pagination.tsx` renders `nav.pagination[aria-label="Pagination"]` with `.page-buttons`/`.page-btn`; prev/next are chevron icon buttons with `aria-label` (were `<`/`>` text), `type="button"` on all, `aria-current="page"` and prev-disabled-on-first unchanged, numbered buttons keep `aria-label="Page N"`. Props, summary text, page-window logic and the `totalCount === 0` early return unchanged.
  - [~] Deferred (manual): visual check of the pagination bar inside the table wrapper (`jobs` frame) in light + dark, incl. focus ring on page buttons and the 44 px coarse-pointer size.
  - Both: legacy baseline 263 → 262 uses (36 → 35 files); no e2e selector changed.
- [x] **2.11** `PageHeader` + breadcrumb (S)
  - Done: `components/PageHeader.tsx`: optional `nav.breadcrumb` (parent link from `backLink`, chevron, current crumb = `title` with `aria-current="page"`) above `.page-header` (`h1` + `badge` in `.row`, `.sub` for `description`, `.page-actions` for `actions`, still full width below the title on phones), `meta` row kept underneath; wrapped in the kit `.stack`. Props unchanged. The `ChevronLeft` back link became a breadcrumb: only one page uses `backLink` (`PayoutBatchDetail`, label "Payout batches"), so no label change is needed.
  - [~] Deferred (manual): visual check of the header and breadcrumb against the `user_detail` / `job_detail` frames, light + dark, 1280/390.
- [x] **2.12** `StatCard` / `StatGrid` (attention variant, link label) (S)
  - Done: `StatCard` renders `.card.stat` (+ `.stat-top`, `.tile tile-sm` tone from `accent`, `.stat-label`, `.stat-value`, `row between nowrap`); `hint` is now the attention variant (`tone-accent`, or `tone-danger` with `accent="red"`) with a warn/danger `Badge` carrying the hint text (was amber text, no border). Link variant keeps its full `aria-label`. Props unchanged; `color` still overrides the value colour (DashboardPage passes legacy `--amber-ink` / `--red-ink`, fixed when the page is migrated in 3.3). `StatGrid` renders `.grid c2|c3|c4`: 4 → 2 → 1 columns per the design (was 2 columns on phones); `cols.phone` is now ignored (no call site passes `cols`).
  - [~] Deferred (manual): check the dashboard stat row against the `dashboard` frame at 1280/820/390 (1 column on phones is a visible delta from the old 2), light + dark.
- [x] **2.13** `DescriptionList` / `InfoRow` (`dl`, `total` row, stacks < 640) (S)
  - Done: `DescriptionList` renders a real `<dl class="dl">`; `InfoRow` renders `<div><dt/><dd/></div>` (label left / value right from 640 px, stacked below, from the kit); added optional `total` (the `.total` row for money lists). `valueClassName` now goes on the `<dd>`. Props otherwise unchanged. Note: the standalone `components/InfoRow.tsx` (`value`/`mono` props, legacy `text-ink-soft`) is imported nowhere: left for task 6.2 (remove unused components).
  - [~] Deferred (manual): check the job and user detail definition lists against the `job_detail` / `user_detail` frames (label column width, `.mono` / urgent value colour) in light + dark.
- [x] **2.14** `JobProgressStepper` (continuous connectors, vertical < 768); update the 7 `.step-label` e2e assertions to role/aria (D6) (M)
  - Done: `components/JobProgressStepper.tsx` renders the kit `ol.stepper` (`<li>` states `done` with a check icon, `current`, `halt` with a cross icon, none for steps not reached; `span.dot` + label `span` with `<small>` sublabel). Connectors and the vertical layout below 768 px come from the kit CSS (each step draws one connector back to the previous one). Props, `getJobProgress` and the step logic are unchanged. `role="list"` stays on the `ol` (list semantics survive `list-style: none`); the redundant `role="listitem"` is dropped; `aria-current="step"` kept (also on a completed job's last step, shown as `done`). The accessible name is now `Job progress` on the `ol` (was a nameless `aria-label` on a `div` plus "Job progress steps" on the `ol`); the sr-only summary is kept. The component renders its own `.card` > `.card-body` (the legacy shim used to give the stepper its card surface and the page does not wrap it; the `job_detail` frame also puts it in a card); caption is `.muted`. Removed the legacy `.stepper:has(> .step)` and `.step*` rules from `legacy-compat.css` (this component was their only user). Legacy baseline 253 → 248 uses (33 → 32 files).
  - e2e (D6): `web/e2e/job-progress.spec.ts` no longer uses `.step-label`, `.step-sublabel`, `.step-line` or `[role="listitem"]`; it finds the stepper with `getByRole('list', { name: 'Job progress' })`, steps with `getByRole('listitem')` and the active step with `[aria-current="step"]`, and asserts on text. The "last step has no connector" test no longer applies (the kit draws each connector as the `::before` of the step it leads into, so the first step has none): replaced by "first step draws no connector; each later step draws one back". The AwaitingConfirmation sublabel check is now strict (was skipped when the sublabel was not visible). Specs not run (deferred).
  - Deviations to know: the `job_detail` frame shows 5 steps (Awaiting confirmation as its own step); the app keeps the 4-step model of `getJobProgress` (mobile parity) with "Awaiting confirmation" as the sublabel, because changing the step list is a behaviour change. Expired and Disputed now halt like Cancelled (red, cross icon; the kit has no gold/other halt state); before, Expired was gold and Disputed red with a gold border. The 200 ms colour transition is gone (the kit stepper defines none).
  - [~] Deferred (manual): run `e2e/job-progress.spec.ts` against a live API; visual check of a Booked, InProgress, AwaitingConfirmation, Completed, Cancelled and Disputed job against the `job_detail` / `job_detail_phone` frames in light + dark at 1280/820/390 (horizontal ≥ 768, vertical below; connector turns red into a halted step; check/cross icons visible in `forced-colors`).
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

## Verification log

- 2026-11-18, task 2.14: `npm run lint` (0 errors, same 1 warning), `npm run build`, `design:check` (24 files identical), `design:legacy` (253 → 248 uses, 32 files), design gate (126/126) pass. **Deferred (manual):** `job-progress.spec.ts` run and the stepper visual check, see task 2.14.
- 2026-11-18, tasks 2.11–2.13: `npm run lint` (0 errors, same 1 warning), `npm run build`, `design:check` (24 files identical), `design:legacy` (262 → 253 uses, 33 files), design gate (126/126) pass.
- 2026-11-18, tasks 2.9–2.10: `npm run lint` (0 errors, same 1 warning), `npm run build`, `design:check` (24 files identical), `design:legacy` (263 → 262 uses, 35 files), design gate (126/126) pass.
- 2026-11-18, task 2.8: `npm run lint` (0 errors, same 1 warning), `npm run build`, `design:check` (24 files identical), `design:legacy` (276 → 263 uses, 36 files), design gate (126/126) pass.
- 2026-11-18, task 2.7: `npm run lint` (0 errors, same 1 warning), `npm run build`, `design:check` (24 files identical), `design:legacy` (283 → 276 uses, 37 files), design gate (126/126) pass.
- 2026-11-18, task 2.6: `npm run lint` (0 errors, same 1 warning), `npm run build`, `design:check` (24 files identical), `design:legacy` (289 → 283 uses, 39 files), design gate (126/126) pass.
- 2026-11-18, tasks 2.1–2.5: `npm run lint` (0 errors, same 1 warning), `npm run build`, `design:check`, `design:legacy` (302 → 289 uses, 40 files), design gate (126/126) pass. **Deferred (manual):** visual check of the new components and of `StatusBadge`/payout badges in tables, light + dark; keyboard check of `Toast` dismiss and `Button` loading state.

## Parked / blocked

- **D9 (open, not blocking):** phone layout of `DataTable` (card list vs scrolling table), see task 2.8.

_No parked tasks yet. Add `[~] <task> — parked: <why>` here._
