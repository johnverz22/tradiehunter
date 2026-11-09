# M5 — Admin & Beta

Depends on: M4 (Reviews & Scheduling complete)

## Overview

Build the admin dashboard (React web), instrument success metrics, run end-to-end testing, and prepare for closed beta. This is Tier 3 from `docs/MVP-SPEC.md`.

---

## Tasks

### M5-01: Admin authentication (React)

- **Platform**: Web
- **Description**: Build admin login screen per mockup `docs/design/mockup/web/01-admin-login.html`. Email/password form, authenticates via `POST /api/auth/login`, stores JWT, redirects to dashboard. Route guard checks `admin` role claim. Unauthorized users see 403.
- **References**: `docs/design/mockup/web/01-admin-login.html`, `.agent/rules/frontend.md` § Scope & Access Control
- **Acceptance criteria**:
  - [ ] Login form with email + password
  - [ ] JWT stored securely (httpOnly cookie or secure storage)
  - [ ] Route guard on all `/admin/*` routes
  - [ ] Non-admin JWT rejected with clear error message
  - [ ] Uses design tokens from `web/src/theme/design-tokens.css`
  - [ ] Both light and dark theme

### M5-02: Admin dashboard — overview

- **Platform**: Web
- **Description**: Build admin dashboard overview per mockup `docs/design/mockup/web/02-admin-dashboard.html`. Summary cards: total users, active jobs, pending disputes, today's new signups. Charts: jobs by status, signups over time.
- **References**: `docs/design/mockup/web/02-admin-dashboard.html`, `.agent/rules/frontend.md` § Feature-Based Architecture
- **Acceptance criteria**:
  - [ ] `features/dashboard/` directory structure
  - [ ] `useDashboardStats` custom hook fetching `GET /api/admin/stats`
  - [ ] Summary cards as reusable components
  - [ ] Auto-refresh on interval or SignalR
  - [ ] Both light and dark theme

### M5-03: Admin user list & detail

- **Platform**: Web
- **Description**: Build user management per mockups `docs/design/mockup/web/05-admin-users-list.html` and `docs/design/mockup/web/03-admin-user-detail.html`. Sortable/filterable table of all users. Detail view shows profile, role, verification status, job history, reviews. Actions: verify, deactivate, change role.
- **References**: `docs/design/mockup/web/05-admin-users-list.html`, `docs/design/mockup/web/03-admin-user-detail.html`
- **Acceptance criteria**:
  - [ ] `features/users/` directory structure
  - [ ] `useUserList` hook with search, filter, sort, pagination
  - [ ] Verify button calls `POST /api/admin/users/{id}/verify`
  - [ ] Deactivate button calls `POST /api/admin/users/{id}/deactivate`
  - [ ] Confirmation modal before destructive actions
  - [ ] Both light and dark theme

### M5-04: Admin job list & detail

- **Platform**: Web
- **Description**: Build job management per mockups `docs/design/mockup/web/06-admin-jobs-list.html` and `docs/design/mockup/web/04-admin-job-detail.html`. Table of all jobs with status filter. Detail shows full job info, participants, chat transcript (read-only), status history, photos.
- **References**: `docs/design/mockup/web/06-admin-jobs-list.html`, `docs/design/mockup/web/04-admin-job-detail.html`
- **Acceptance criteria**:
  - [ ] `features/jobs/` directory structure
  - [ ] Status badge components matching design system
  - [ ] Read-only chat transcript view
  - [ ] Status history timeline
  - [ ] Job photos displayed
  - [ ] Both light and dark theme

### M5-05: Admin disputes view

- **Platform**: Web
- **Description**: Build disputes view per mockup `docs/design/mockup/web/07-admin-disputes.html`. List flagged disputes with job context, both parties' info, and admin resolution actions (resolve, escalate, cancel job). Manual resolution only for MVP (no automated dispute engine).
- **References**: `docs/design/mockup/web/07-admin-disputes.html`, `docs/MVP-SPEC.md` § "Won't-Have"
- **Acceptance criteria**:
  - [ ] `features/disputes/` directory structure
  - [ ] Dispute status filter (Open, Resolved, Escalated)
  - [ ] Resolution actions with confirmation
  - [ ] Chat context embedded in dispute detail
  - [ ] Both light and dark theme

### M5-06: Admin settings

- **Platform**: Web
- **Description**: Build admin settings per mockup `docs/design/mockup/web/08-admin-settings.html`. View/edit locale config (currency, phone format, timezone), matching radius, platform feature flags.
- **References**: `docs/design/mockup/web/08-admin-settings.html`
- **Acceptance criteria**:
  - [ ] Reads current config from `GET /api/admin/settings`
  - [ ] Saves via `PUT /api/admin/settings`
  - [ ] Form validation
  - [ ] Both light and dark theme

### M5-07: Admin API endpoints

- **Platform**: Backend
- **Description**: Create admin-only REST endpoints behind `[Authorize(Roles = "admin")]`: `GET /api/admin/stats` (dashboard summary), `GET /api/admin/users` (paginated, filterable), `POST /api/admin/users/{id}/verify`, `POST /api/admin/users/{id}/deactivate`, `GET /api/admin/jobs` (all jobs, filterable), `GET /api/admin/disputes`, `POST /api/admin/disputes/{id}/resolve`, `GET /api/admin/settings`, `PUT /api/admin/settings`.
- **References**: `.agent/rules/backend.md` § Controller Purity
- **Acceptance criteria**:
  - [ ] All endpoints require `admin` role
  - [ ] `AdminController` or split into `AdminUsersController`, `AdminJobsController`, etc.
  - [ ] Pagination and filtering on list endpoints
  - [ ] Verify action sets `IsVerified` flag on tradie profile
  - [ ] Deactivate action disables login

### M5-08: Success metrics instrumentation

- **Platform**: Backend
- **Description**: Instrument the four success metrics from `docs/MVP-SPEC.md`: activation rate (signups → first job within 24h), match-to-confirmation time (job created → Confirmed status), tradie response rate (match notification → accept/decline), review completion rate (completed jobs → reviews by both parties). Log to structured logging; expose via `GET /api/admin/metrics`.
- **References**: `docs/MVP-SPEC.md` § Success metrics
- **Acceptance criteria**:
  - [ ] Each metric calculated from existing data (no new tracking tables needed initially)
  - [ ] Exposed as JSON from admin endpoint
  - [ ] Time-windowed (last 7 days, last 30 days, all time)
  - [ ] Admin dashboard displays these metrics

### M5-09: End-to-end happy path test

- **Platform**: All
- **Description**: Write and run a full end-to-end test covering the happy path: homeowner registers → posts job → matching runs → tradie accepts → chat opens → schedule confirmed → job started → job completed → both parties review. Can be automated (integration test against running stack) or documented manual test script. Note: the mobile leg is demoable today on stub data (`/home` → Post a Job → `/jobs/:id/matching` auto-advances → match result → Request → `/chat/:jobId` → rating sheet demo on profile) — see `mobile/AGENTS.md`.
- **Acceptance criteria**:
  - [ ] Covers entire flow from registration to review
  - [ ] Tests both mobile (Flutter) and web (admin view of the same flow)
  - [ ] Documents expected state at each step
  - [ ] Identifies and logs any bugs found

### M5-10: Beta preparation

- **Platform**: All
- **Description**: Prepare for closed beta deployment: seed admin user, configure Firebase for production FCM, set up MinIO bucket policies, document beta test plan, prepare onboarding instructions for beta cohort (one NZ region).
- **Acceptance criteria**:
  - [ ] Admin seed user created via migration or startup script
  - [ ] FCM configured for production (not just dev)
  - [ ] Beta region defined (e.g., Auckland)
  - [ ] Beta test plan documented
  - [ ] Known limitations documented for beta testers

---

## Dependencies

- M1–M4 complete (full feature set)
- Firebase production project
- Hosting/deployment environment for beta

## Key risks

- Admin dashboard scope creep (keep to MVP list)
- Beta user recruitment and engagement
- Production infrastructure readiness
