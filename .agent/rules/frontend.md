# Frontend Rules (React)

Architectural and implementation rules for the Fixo React web application.

## Architectural Pattern: Feature-Based Architecture & SoC

The frontend is organized by functional feature modules with a strict separation between data fetching, business state, and presentation.

| Layer | Responsibility | Allowed Elements | Prohibitions |
| :--- | :--- | :--- | :--- |
| **Data Layer (Hooks & Services)** | Handles all REST API requests, caching, mutation management, and SignalR hub connections. | TanStack Query (React Query) / SWR, custom hooks (e.g., `useJobList`, `useUserVerification`), API client instances. | **NO** JSX or visual layout logic. |
| **Feature Layer (Screens / Modules)** | Composes UI components and hooks for specific admin routes (e.g., `features/dashboard`, `features/disputes`). | Route pages, container components, hook integrations, layout composition. | **NO** direct inline `fetch`/`axios` calls; must consume Data Layer hooks. |
| **UI Layer (Components)** | Dumb, highly reusable presentation components (tables, badges, modal dialogs, inputs, buttons). | Pure React components driven exclusively by props and callbacks. | **NO** data fetching, network side-effects, or domain business logic. |

## Separation of Concerns (SoC) Guidelines

1. **Custom Data Hooks**:
   - All REST queries, mutations, and SignalR hub subscriptions must be encapsulated in custom hooks.
   - Components must never contain direct `fetch`, `axios`, or WebSocket calls.
   - Manage loading, error, and pagination states within hooks/query wrappers.
2. **Dumb, Reusable UI Components**:
   - UI elements must be presentation-only, receiving data via props and emitting user interactions via callbacks.
   - Components must follow `docs/design/web/COMPONENTS.md` (web design system v1).
3. **Directory Structure**:
   - Organize by feature folder:
     ```text
     src/
     ├── components/       # Shared dumb UI components (Button, Modal, Table)
     ├── features/         # Feature modules (Dashboard, Users, Jobs, Disputes)
     │   └── <feature>/
     │       ├── components/ # Feature-specific presentation widgets
     │       ├── hooks/      # Feature-specific data hooks
     │       └── pages/      # Route entry points
     ├── services/         # API client & SignalR hub connections
     └── theme/            # Design system tokens and CSS variables
     ```

## Design System & Theming

- **Source of truth:** `docs/design/web/` (v1, Trust Navy + Gold). Tokens are `docs/design/web/tokens/tokens.json`, which **extends the mobile master** `docs/design/mobile/tokens/tokens.json`; components are `docs/design/web/css/kit.css`; specs are in `docs/design/web/COMPONENTS.md`; the visual reference is `docs/design/web/mockups/index.html` (frames) and `system.html` (every component state). Colour changes are made in the mobile master, never in a web copy.
- **Tokens only:** colour via `var(--ink)`, `var(--surface)`, `var(--brand)` … or the Tailwind utilities from `theme.css` (`bg-surface`, `text-ink-soft`, `border-line`). Space `--sp-*`, radii `--r-*`, sizes `--sz-*`, type `.t-*` / `--ty-*`, shadows `--sh-*`. Never hardcode hex or `rgb()`. A missing token goes into `docs/design/web/tokens/tokens.json` (web-only) or the mobile master (shared), then rebuild.
- **Reuse before create:** `Banner`, `ConfirmModal`, `DataTable`, `DescriptionList`, `FilterBar`, `Modal`, `PageHeader`, `Pagination`, `StatCard`, `StatusBadge`, `JobProgressStepper`. Status tone comes from the STATUS map in `docs/design/web/ast/dsl.mjs`.
- **Brand budget:** one gold (`btn-accent`) commit action per view or dialog. Navy `btn-primary` for other filled actions, danger red only for destructive ones. Status is never colour-only.
- **Theme support:** light and dark are required and are a token swap (`:root`, `[data-theme="dark"]`, and the OS preference when `data-theme` is unset). A theme `if` inside a component is a bug.
- **Accessibility:** WCAG 2.2 AA. Visible focus (`--focus`), 44 px targets on coarse pointers, `line-strong` for control borders, `prefers-reduced-motion` respected, dialogs trap focus and return it.
- **Migration status:** done. `web/src/theme/{tokens,theme,components}.css` and `web/public/fonts/` are copies of `docs/design/web/`: never hand-edit them; change the design system, run `node docs/design/web/tools/build.mjs`, then `npm run design:sync` in `web/`. `npm run design:check` (drift) and `npm run design:legacy` (retired v1.7 names such as `pill-*`, `stat-pill`, `card-title`, `--amber`, `--space-N`) run in CI. App-level CSS for what the kit lacks goes in `web/src/index.css`, tokens only.
- **Design gate:** `node docs/design/web/tools/build.mjs --check` (contrast, kit lint, stale outputs) before committing design changes.

## Scope & Access Control

- **Admin-Only Scope for MVP**:
  - The React application is strictly an **admin dashboard** for the MVP.
  - Homeowner and tradie user experiences belong exclusively to the Flutter mobile application.
- **Authentication & Authorization**:
  - Post-login routing is protected and gated by the `admin` role claim in the JWT.
  - Consume the exact same REST API and SignalR hub contracts as the Flutter app; do not fork backend endpoints or logic.
- **MVP Feature Screens (Tier 3 in `docs/MVP.md`)**:
  - Admin Login.
  - Admin Dashboard (user management with verify/deactivate capabilities, live job list + status monitoring, flagged dispute reviews).
- **Bundle Isolation**:
  - Ensure admin routes are code-split cleanly to prevent accidental leakage into any future homeowner/tradie web bundles.

## Verifying Rendered Output

Browser automation is not guaranteed in this repo, so a UI change is not done until its *rendered
markup* has been checked:

- `npm run lint` and `npm run build` (the build runs `tsc -b`) must pass.
- Render the page and assert on its HTML with
  `scripts/web/render-probe.py --page <module under web/src> --fixture scripts/web/fixtures/<feature>/<case>.json`.
  Keep fixtures beside the feature they cover and assert the interesting states (empty, populated,
  multi-page, null fields, escaped text) — not just the happy path. Details in
  `docs/ai/AI-TOOLING.md` → Verification Scripts.
- The Puppeteer MCP remains the only way to observe real browser behaviour (layout, theme
  switching, console errors); use the probe when it is unavailable.

