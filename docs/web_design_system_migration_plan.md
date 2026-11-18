# TradieHunter — Web Admin Design System Migration Plan

> **Scope:** `web/` (React admin) only. Mobile is covered by `docs/design_system_migration_plan.md`.
> **This document is docs-only.** Nothing in `web/` changes until the strategy in §2 is signed off.
> **Source of truth:** `docs/design/web/` (Trust Navy + Gold, web v1, inherits `docs/design/mobile/tokens/tokens.json`).
> **Replaces:** the legacy v1.7 admin theme in `web/src/theme/` (Space Grotesk + IBM Plex + amber, `--hue` knob).
> **Companion:** `docs/web_design_system_migration_todo.md` (checkable tasks, one per file or step).
> **Status:** proposed, 2026-11-18. Facts below were measured on branch `design` at `fd945e1`.

---

## 1. What we are migrating

### 1.1 The target (already built, gate green)

`node docs/design/web/tools/build.mjs --check` → `check ok: 18 frames, 26 files, contrast 126/126 pass`.

| Piece | Path | Role in the migration |
|---|---|---|
| Tokens (generated) | `tokens/tokens.css`, `tokens/theme.css` | Replace `web/src/theme/design-tokens.css` and the `@theme` block in `index.css` |
| Component kit (hand-written) | `css/kit.css` | Replaces `web/src/theme/components.css` (583 lines) |
| Fonts | `fonts/` (Lexend, Source Sans 3, self-hosted woff2) | Replace the Google Fonts `<link>` tags in `index.html` |
| Frames | `mockups/frames/*.html` (14 screens + 4 responsive) | Visual acceptance reference per page |
| Contract | `COMPONENTS.md`, `DESIGN_GUIDE.md` §10 | Class map, React prop contract, mapping table |

### 1.2 The app today (`web/`)

- 75 files under `src/`, ~10.2k lines including CSS. 17 routes, 14 shared components, 6 layout files.
- Presentation and data are already separate: every feature has `hooks/` (React Query) and `services/` holds `api.ts` / `adminApi.ts`. **None of that needs to change.**
- Legacy surface to migrate (files that reference it): `pill-*` 11, `btn-primary` 10, `stat-pill` 11, `card-title` 6, `btn-danger` 3, `table-container` 2, old brand utilities (`brand-900/700/500/300/100`) 21, `amber*` 22, `paper*` 22, `ink-soft` 34.
- 35 legacy CSS variables are used in `src/` but **not defined** by the new tokens (e.g. `--brand-900`, `--amber`, `--green`, `--red`, `--paper-line`, `--radius`, `--space-N`, `--shadow-card`, `--text-body`, `--topbar-height`, `--drawer-width`, `--safe-top`). DESIGN_GUIDE §10 maps most of them; the layout/type/safe-area ones need decisions (§6).
- Heaviest files (legacy refs / lines): `UserDetailPage` 43/491, `DisputeDetailPage` 41/338, `ProcessRefundModal` 31/253, `PaymentReviewModal` 29/202, `DataTable` 23/473, `DashboardPage` 19/381, `TopBar` 19/118.
- E2E safety net exists: 9 Playwright specs in `web/e2e/` (queues, disputes, users, job-progress, responsive, auth). They select mostly by role and text; the exceptions are `.step-label` (7 uses, the stepper has no such class in the new kit) and `locator('table tbody tr')` (22 uses, unaffected).
- Brand: the `--hue` white-label knob is used only in `design-tokens.css`. The design system **drops it** (DESIGN_GUIDE §12). `useBrandConfig` / `BrandWordmark` still drive the product name; the app strings still say `TradieFixo` (`index.html`, `useBrandConfig`, `fixo-theme` localStorage key).

---

## 2. Strategy decision: move `web/` aside and rebuild, or edit `web/` directly?

### Option A — Move `web/` to a new directory, rebuild progressively under the new system

`web/` → `web-legacy/` (or a new `web-v2/` beside it), rebuilt page by page.

| For | Against |
|---|---|
| Legacy keeps running untouched for hotfixes | Two Vite apps, two Dockerfiles, two Playwright configs, two sets of CI paths until cutover |
| No chance of a half-styled page reaching staging | The data layer (22 hooks, `api.ts`, `adminApi.ts`, SignalR, auth guards) must be copied or shared; fixes land in two places and drift |
| A visual side-by-side is trivial | `scripts/web/render-probe.py`, `docker-compose.yml`, `dev.sh`, `Makefile`, `.github/workflows/ci.yml`, AGENTS.md and docs all hard-code `web/` |
| | Git history and blame for 75 files are lost on the rebuilt copy |
| | An internal admin has no external users who need the old UI to stay live |

### Option B — Edit `web/` directly, staged behind a temporary compat layer

Swap the foundation first, keep every old class and variable resolving through a **temporary shim**, then migrate page by page and delete the shim.

| For | Against |
|---|---|
| One app, one build, one CI, one history | Between phases the app mixes old and new pages; needs discipline on the branch |
| Token names are deliberately stable (`--paper`, `--ink`, `--ink-soft`, `--surface`, `--sp-N`), and §10 ships a full legacy→new class map | The global token swap changes every page's colours at once (mitigated: it is the same palette family and the shim keeps layout intact) |
| Existing Playwright specs are the regression net from day one | |
| Hooks, services and routes are never touched | |
| Small codebase (~20 pages): per-page PRs stay reviewable | |

### Recommendation: **Option B (edit in place, staged with a shim)**

Reasons, in order of weight:

1. **The expensive part of Option A is not needed here.** The mobile plan rebuilds beside the old code because Flutter's `THColors`, `THType` and `THBadge` collide by name, the screens run to 2,000 lines, and Firebase/signing/push make a new project costly. None of that applies to `web/`: it is ~20 pages of React and Tailwind, and the design system was authored to be dropped into it (`DESIGN_GUIDE.md` §10).
2. **Option A duplicates the one layer that should not change.** Every hook and service would exist twice for the length of the migration.
3. **The repo wiring is path-based.** Moving `web/` touches Docker, compose, CI, scripts, agent rules and docs for no design benefit.
4. **The regression net already points at `web/`.** The Playwright suite and `render-probe.py` run against the real routes the whole way through.
5. **The shim removes the usual risk of in-place edits** (the app is unshippable until finished): after Phase 1 every unmigrated page still renders correctly, just on the new palette.

**When to switch to Option A instead:** the admin must stay deployable to production from the current UI while this runs for more than about two weeks and hotfixes keep landing, or the team wants a feature-flagged, route-by-route rollout in one running app. In that case use the mobile pattern (a `web/src/ui/` tree beside the old one, a per-route flag, an import-boundary guard) rather than a second project; that keeps the data layer shared and is cheaper than a moved directory.

> **Sign-off needed:** confirm Option B (or choose A / the flagged variant) before Phase 1. Everything below assumes B.

---

## 3. Approach under Option B

**Keep untouched:** `src/services/`, every `features/*/hooks/`, `features/branding/hooks`, `utils/`, `App.tsx` route table and guards, `main.tsx`, auth/JWT/SignalR behaviour, API contracts, permissions, routes.

**Change:** `src/theme/*`, `src/index.css`, `index.html`, `public/fonts`, `src/components/*`, `src/layout/*`, and the JSX/class names inside page files.

**Branching:** one long-lived branch `design-web-migration` off `dev`; one PR per phase (Phase 3 and 4: one PR per page or small group). Each PR must be buildable, lint-clean and e2e-green on its own.

### The compat shim (temporary)

`web/src/theme/legacy-compat.css`, imported **after** the new files, kept for the duration of Phases 1–5 and deleted in Phase 6. It contains only mappings, never new design:

1. Legacy CSS variables → new tokens, using the §10 table: `--brand-900 → --sidebar`, `--brand-700 → --brand`, `--brand-500 → --focus`, `--brand-100 → --brand-tint`, `--paper-line → --line`, `--amber → --accent`, `--green → --success`, `--red → --danger`, `--space-N → --sp-N`, `--shadow-card/pop → --sh-card/pop`, `--radius → --r-control`, plus `--font-*`.
2. Legacy Tailwind colour names (`bg-brand-900`, `text-amber-brand`, …) → the nearest new token inside an `@theme` block, so existing utilities keep producing CSS instead of silently dropping.
3. Legacy component classes (`.pill-*`, `.stat-pill`, `.card-title`, `.table-container`, `.th`/`.td`, old `.btn-*`) → the new kit rules (`.badge-*`, `.stat`, `.card-head h2`, `.table-wrap`, `.table`).
4. Layout/type/safe-area variables with no new equivalent (see §6): defined here until their decision lands.

Every shim rule carries a `/* legacy: remove in P6 */` comment so Phase 6 can find them with one grep. **No new code may use a legacy name** (lint rule added in Phase 1).

---

## 4. Phases

### Phase 0 — Sign-off and baseline (no code)

- Confirm strategy (§2) and the open decisions (§6).
- Capture before-shots of every route in light and dark at 1280, 820 and 390 with `web/e2e/admin-shots.mjs`; store outside the repo (CI artifact or a zip). Used for diffing, not committed.
- Record the baseline: `npm run lint`, `npm run build`, `npm run test:e2e` all green on `dev`.
- Tag `pre-web-design-migration` on the starting commit.

### Phase 1 — Foundation (app looks nearly the same, new tokens live)

Follows `DESIGN_GUIDE.md` §10 steps 1–3.

1. Copy `tokens.css`, `theme.css` to `web/src/theme/`; copy `css/kit.css` to `web/src/theme/components.css` (replacing the legacy file); remove `design-tokens.css` and the old `@theme` + `@custom-variant` from `index.css`. Import order: `tailwindcss` → `tokens.css` → `theme.css` → `components.css` → `legacy-compat.css`.
2. Copy `fonts/` to `web/public/fonts/`, import `fonts.css` first; remove the Google Fonts `<link>`s.
3. `index.html`: keep the blocking theme script, update `theme-color`, title and description.
4. Write `legacy-compat.css` (§3).
5. Decide and wire a **sync check**: a script (`web/scripts/sync-design.mjs`, or an npm script) that fails CI if `web/src/theme/{tokens,theme,components}.css` differ from `docs/design/web/{tokens,css}`, so the app cannot drift from the system. Generated files are copied, never hand-edited.
6. Add a lint/CI guard that rejects new uses of legacy names outside `legacy-compat.css`.

**Exit gate:** `lint`, `build`, full e2e green; every route renders with no unstyled element (compare with Phase 0 shots); `node docs/design/web/tools/build.mjs --check` green.

### Phase 2 — Shared components and shell (proves the recipe)

Order matters: pages depend on these. Each component keeps its **name and props** (COMPONENTS.md, *React contract*) and switches to the new classes; extract the missing five (`Button`, `Field`, `Badge`, `EmptyState`, `Toast`) because each appears 3+ times.

1. Foundations: `Button`, `Badge` (+ `StatusBadge` on the new status map), `Field`, `EmptyState`, `Toast`.
2. Existing components: `Banner`, `Modal` + `ConfirmModal` (focus trap, Esc, return focus, destructive → Cancel first, bottom sheet < 640), `DataTable` (sticky header, `aria-sort`, `.table-wrap`), `FilterBar`, `Pagination`, `PageHeader`, `StatCard`/`StatGrid`, `DescriptionList`/`InfoRow`, `JobProgressStepper` (new connector markup; update the 7 `.step-label` e2e assertions), `ThemeToggle`.
3. Shell: `AppShell`, `AdminLayout`, `SidebarNav` (240 / 64 rail / drawer), `MobileDrawer`, `TopBar`, `UserMenu`, `BrandWordmark`.

**Exit gate:** shell and a representative queue + detail page verified at the three widths in both themes against `dashboard`, `dashboard_rail`, `dashboard_phone`, `nav_drawer`; e2e green.

### Phase 3 — Entry, simple and list pages

`AdminLogin` (`login`), `Forbidden` (`forbidden`), `Dashboard` (`dashboard`), `JobList` (`jobs`), `UserList` (`users`), `AuditLogs` (`audit_logs`), `Settings` (`settings`), `Disputes` (`disputes`).

### Phase 4 — Queues, detail pages and dialogs

Queue pattern (header, filter bar, table, row actions, pagination): `CredentialQueue` (`credentials`), `PaymentQueue` + `PaymentReviewModal` (`payments`), `OverduePayments`, `PayoutQueue` + `ProcessPayoutModal` + `PayoutStatusBadge` (`payouts`), `PayoutBatches`, `RefundQueue` + `ProcessRefundModal`.

Detail pattern (breadcrumb, header with badge and actions, `side` grid, money in a `dl` with a `total` row): `JobDetail` (`job_detail`, `job_detail_phone`), `UserDetail` (`user_detail`), `DisputeDetail` (`dispute_detail`), `PayoutBatchDetail`, `AuditDiffModal`.

Pages with **no frame** (refunds, batches, batch detail, credential review dialogs) reuse the queue and dialog patterns per DESIGN_GUIDE §12; do not invent new components for them.

### Per-page recipe (applies to every page in Phases 3 and 4)

1. Write the **parity list** from the current file first: every button, link, filter, dialog, validation rule, empty/loading/error state, and what each calls. This is the checklist; behaviour must not change.
2. Re-read the matching frame in `docs/design/web/mockups/frames/` and `COMPONENTS.md` for the roles on the page.
3. Replace legacy classes/variables with kit classes and shared components; **no raw colours, sizes or font stacks**, tokens only; no `outline: none` without a replacement.
4. Keep hooks, query keys, route params and handlers exactly as they are.
5. Loading → skeleton/spinner with `aria-busy`; empty → `EmptyState` (what is empty, what to do); error → banner with Retry.
6. Run `npm run lint`, `npm run build`, the page's e2e spec, `scripts/web/render-probe.py --page <module> --fixture <json>` for the touched page, and screenshot light + dark at 1280/820/390.
7. Compare with the frame. A page is done when it matches the frame's structure and states, the parity list is complete, and nothing in the page uses a legacy name.
8. A reviewer other than the author checks the page against this list (the repo's `ui-audit` and `design-vs-run-crosscheck` skills fit here).

### Phase 5 — Review sweep (before cutover)

1. Whole-app pass: every route in light and dark at 1280/820/390 against the Phase 0 shots and the frames; list and fix differences.
2. Consistency audit across pages (same button kinds, same empty/error states, same dialog footers, one gold action per page) using the repo's `ui-audit` skill.
3. Accessibility pass per DESIGN_GUIDE §9: focus rings, keyboard on dialogs/menus/tables, targets on coarse pointers, `forced-colors`, `prefers-reduced-motion`.

### Phase 6 — Cutover and cleanup

1. `grep` proves zero uses of legacy variables/classes/utilities outside `legacy-compat.css`; then delete `legacy-compat.css` and the guard's allow-list.
2. Remove dead CSS, `react.svg`/`vite.svg` if unused, the `--hue` remnants, and unused components.
3. Rename user-facing and storage strings: `TradieFixo` → `TradieHunter` (title, description, `useBrandConfig` default); decide on the `fixo-theme` localStorage key (§6).
4. Final full pass: e2e, `responsive.spec.ts`, forced-colors, reduced-motion, keyboard-only walk of the dialogs and menus (DESIGN_GUIDE §9).
5. Update docs (below). Merge to `dev`; tag `web-design-v1`.

---

## 5. Documentation updates (done in Phase 6, via the `docs-sync` skill)

| File | Change |
|---|---|
| `docs/design/web/DESIGN_GUIDE.md` §10, §12 and `README.md` | Remove "the app has not been migrated yet"; state that `web/src/theme` is synced from this folder and how the sync check works |
| `docs/DESIGN.md`, `docs/MILESTONES.md` | Record web admin on design v1 and the verification done |
| `docs/ai/AI-TOOLING.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | Web UI rules: tokens only, no legacy names, run the sync check and render-probe |
| `docs/README.md` | Link or remove this plan (see note below) |

> **Note on repo rules:** `docs/README.md` rule 1 says "no new … plans, progress logs". This plan and its todo were requested explicitly and mirror `docs/design_system_migration_plan.md`, so they live in `docs/` while the work runs. When Phase 6 completes, fold anything lasting into the owning docs above and delete both files (history stays in git).

---

## 6. Open decisions (need an owner before the phase that needs them)

| # | Decision | Needed by | Proposed default |
|---|---|---|---|
| D1 | Strategy: B (in place + shim) vs A (moved directory) vs flagged `src/ui/` tree | Phase 0 | **B** |
| D2 | Dashboard **charts** (`Charts.tsx`) are not designed (DESIGN_GUIDE §12) | Phase 3 | Recolour with chart tokens, add a small chart spec to the design system before restyling |
| D3 | Layout/type/safe-area variables with no new equivalent: `--topbar-height`, `--drawer-width`, `--safe-top/bottom`, `--text-body/-display/-h2/-h3` | Phase 1 | Keep as app-level layout variables in `index.css`; map `--text-*` to the `t-*` classes in TYPOGRAPHY.md |
| D4 | Rename `fixo-theme` localStorage key to a TradieHunter key | Phase 6 | Rename and read the old key once for migration |
| D5 | White-label `--hue` is dropped; confirm no tenant needs per-brand colour | Phase 0 | Confirm dropped (design decision already recorded) |
| D6 | Replace e2e `.step-label` selectors with role/aria (`aria-current="step"`) | Phase 2 | Yes, in the stepper PR |
| D7 | Sync mechanism for tokens/kit (copy script + CI check vs importing from `docs/`) | Phase 1 | Copy script + CI check, so `web/` stays self-contained for Docker |
| D8 | Need for a bulk-selection bar, date-range picker, tooltips (not designed) | Phase 3–4 | None unless a page already has one; if so, add to the design system first |

Per repo rules, any new third-party dependency (for example a chart library change) needs approval first; this plan adds none.

---

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Silent loss of styling from legacy Tailwind names that no longer exist | Shim defines them in `@theme`; Phase 0/1 screenshot diff; guard bans new uses |
| Mixed old/new pages look inconsistent mid-migration | Same palette family and shared shell from Phase 2; PRs per phase; staging only after Phase 2 |
| Behaviour regressions in large pages (`UserDetail`, `DisputeDetail`) | Parity list per page, existing e2e, render-probe fixtures, reviewer who did not write the page |
| Generated design files edited by hand in `web/` | Sync check in CI (Phase 1) |
| Accessibility regressions (focus, dialogs, targets) | Gates in DESIGN_GUIDE §9 run per page; keyboard walk in Phase 6 |
| Scope creep into features or API | Presentation only; any needed API/data change is logged as a gap, not built here |

---

## 8. Definition of done

- Zero legacy names in `web/src`; `legacy-compat.css` deleted.
- `web/src/theme/{tokens,theme,components}.css` byte-identical to `docs/design/web` (sync check green).
- Every route matches its frame (or documented pattern for frameless pages) in light and dark at 1280/820/390.
- `npm run lint`, `npm run build`, full e2e and `render-probe` for every touched page pass; `node docs/design/web/tools/build.mjs --check` passes.
- Keyboard and screen-reader basics per DESIGN_GUIDE §9 verified on dialogs, menus, tables and the stepper.
- Docs updated (§5); this plan and the todo removed.
