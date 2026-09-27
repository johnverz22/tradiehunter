# AGENTS.md — Fixo Marketplace

Read by: OpenCode, Antigravity (as of v1.20.3+), and any other AGENTS.md-compatible tool.

## What this project is
A two-sided marketplace for homeowners and tradies. White-label ready — "Fixo" is the development brand. Full context lives in `docs/` — read `docs/PRD.md` and `docs/MVP-SPEC.md` before generating any feature code. Do not invent scope beyond `docs/MVP-SPEC.md`'s Tier 1/2/3 scope without flagging it.

## Stack
- **Backend**: .NET 10 (ASP.NET Core Web API), EF Core + PostgreSQL/PostGIS (dev), ASP.NET Identity + JWT, SignalR for real-time (chat, job-status, match notifications), Hangfire for scheduled reminders, Firebase Admin SDK for FCM push.
- **Mobile (primary)**: Flutter, single app with role-based views (homeowner/tradie — not two separate apps). This is the main client for the MVP.
- **Web (admin only)**: React, scoped to admin dashboard only for MVP. Not a homeowner/tradie client.
- **Infrastructure**: Docker Compose (OrbStack locally) — PostgreSQL+PostGIS, MinIO (S3 blob storage), Redis (SignalR backplane + Hangfire).
- Full rationale in `docs/ARCHITECTURE.md`.

## Conventions
- One codebase per platform, role-based UI — never scaffold a second app for a second role.
- Money and pricing fields: always decimal, never float.
- All timestamps: UTC in the database, localized at the client. Locale settings are configuration-driven (see `docs/ARCHITECTURE.md`).
- Every job-status transition must go through the SignalR hub, not a REST-only side channel, so both web and mobile stay in sync.
- Follow the token system in `docs/design/design-system.html` for any UI work — brand color is the `--hue` CSS variable, not a hardcoded blue. Also refer to the mockup in `docs/design/mockup/`. Both light and dark themes are required; add light theme if only dark is present.
- Local dev runs via `docker compose up` (OrbStack). Flutter runs on the host (emulator/simulator), not in Docker.
- Backend `dotnet` commands must always run inside the API container — `dotnet` is NOT installed on the host. Use `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"` (e.g. restore, build, test, ef migrations).
- Use EF Core spatial LINQ (NetTopologySuite), never raw PostGIS SQL — keeps the SQL Server swap path open for production.

## Out of scope for MVP (see docs/MVP-SPEC.md)
Do not implement without explicit sign-off: in-app payments/BNZ integration, automated dispute resolution, ML-based matching, loyalty/referrals. These are V1.1+.

## Working style
- Prefer small, reviewable increments over large multi-file generations.
- Ask before adding a new third-party dependency not already named in `docs/ARCHITECTURE.md`.
- Nested `AGENTS.md` files may be added inside `backend/`, `web/`, `mobile/` for framework-specific detail as those folders are scaffolded.
