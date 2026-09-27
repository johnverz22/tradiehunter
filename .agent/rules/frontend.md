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
   - Components must strictly replicate specifications from `docs/design/design-system.html`.
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

- **Tokens & Variables**: Design tokens must strictly match `docs/design/design-system.html`. Use `web/src/theme/design-tokens.css` as the single CSS token file — import it in `index.css`. For screen layout and composition, reference the mockups in `docs/design/mockup/web/`.
- **Brand Color**: The primary theme is driven dynamically by the `--hue` CSS custom property (dev brand "Fixo", `--hue: 209`). Never hardcode hex color values.
- **Theme Support**: Both light and dark themes are required. The token file provides `@media (prefers-color-scheme: dark)` overrides and a `[data-theme="dark"]` manual toggle. If only one theme is present, add the other.
- **Consistency**: Use design system typography scales, border radii, elevation shadows, and spacing units across all admin components.

## Scope & Access Control

- **Admin-Only Scope for MVP**:
  - The React application is strictly an **admin dashboard** for the MVP.
  - Homeowner and tradie user experiences belong exclusively to the Flutter mobile application.
- **Authentication & Authorization**:
  - Post-login routing is protected and gated by the `admin` role claim in the JWT.
  - Consume the exact same REST API and SignalR hub contracts as the Flutter app; do not fork backend endpoints or logic.
- **MVP Feature Screens (Tier 3 in `docs/MVP-SPEC.md`)**:
  - Admin Login.
  - Admin Dashboard (user management with verify/deactivate capabilities, live job list + status monitoring, flagged dispute reviews).
- **Bundle Isolation**:
  - Ensure admin routes are code-split cleanly to prevent accidental leakage into any future homeowner/tradie web bundles.
