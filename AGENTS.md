# AGENTS.md — Fixo Marketplace

Read by: OpenCode, Antigravity (as of v1.20.3+), and any other AGENTS.md-compatible tool.

## What this project is
A two-sided marketplace for homeowners and tradies. White-label ready — "Fixo" is the development brand. Full context lives in `docs/` — read `docs/PRD.md` and `docs/MVP-SPEC.md` before generating any feature code. Do not invent scope beyond `docs/MVP-SPEC.md`'s Tier 1/2/3 scope without flagging it.

## Stack
- **Backend**: .NET 10 (ASP.NET Core Web API), EF Core + PostgreSQL/PostGIS (dev), ASP.NET Identity + JWT, SignalR for real-time (chat, job-status, match notifications), Hangfire for scheduled reminders, Firebase Admin SDK for FCM push.
- **Mobile (primary)**: Flutter, single app with role-based views (homeowner/tradie — not two separate apps). This is the main client for the MVP.
- **Web (admin only)**: React, scoped to admin dashboard only for MVP. Not a homeowner/tradie client.
- **Infrastructure**: Docker Compose (OrbStack locally) — PostgreSQL+PostGIS, Azurite (Azure Blob Storage emulator), Redis (SignalR backplane + Hangfire).
- Full rationale in `docs/ARCHITECTURE.md`.

## Conventions
- One codebase per platform, role-based UI — never scaffold a second app for a second role.
- Money and pricing fields: always decimal, never float.
- All timestamps: UTC in the database, localized at the client. Locale settings are configuration-driven (see `docs/ARCHITECTURE.md`).
- Every job-status transition must go through the SignalR hub, not a REST-only side channel, so both web and mobile stay in sync.
- Follow the token system in `docs/design/design-system.html` for any UI work — brand color is the `--hue` CSS variable, not a hardcoded blue. For v1.7 mobile UI work, follow the frame files `docs/design/v1.6/html/frames-homeowner.html` and `docs/design/v1.6/html/frames-tradie.html` as the visual source of truth; read `docs/design/v1.6/docs/HANDOFF.md` for the full design contract (icon rules, CTA placement, component patterns). Existing mockups are excluded from inputs, deliverables and acceptance checks: do not match, update or replace them. This direction supersedes legacy mockup-matching/global sharp-radius instructions, including cached tool rules. Preserve hourly pricing, manual payment review, disputes, permissions, routes/callbacks, repository/ViewModel layering and SignalR behavior; never fabricate missing data or bypass functional decision gates. Both light and dark themes are required; add light theme if only dark is present.
- **No hardcoded values in mobile UI code.** All spacing, radii, font sizes, font weights, colors, alpha tints, durations, letter spacing, shadows, and component sizes must come from the token classes in `mobile/lib/theme/design_tokens.dart` (`Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `Durations`, `Tracking`, `THColors`). Never write raw numeric literals or `Color(0x...)` in view/widget files. See `mobile/HARDCODED_AUDIT.md` for the full audit and the list of tokens to use for each category. If a needed token doesn't exist, add it to `design_tokens.dart` rather than inlining the value.
- Local dev runs via `docker compose up` (OrbStack). Flutter runs on the host (emulator/simulator), not in Docker.
- Backend `dotnet` commands must always run inside the API container — `dotnet` is NOT installed on the host. Use `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"` (e.g. restore, build, test, ef migrations).
- Use EF Core spatial LINQ (NetTopologySuite), never raw PostGIS SQL — keeps the SQL Server swap path open for production.

## Out of scope for MVP (see docs/MVP-SPEC.md)
Do not implement without explicit sign-off: in-app payments/BNZ integration, automated dispute resolution, ML-based matching, loyalty/referrals. These are V1.1+.

## Working style
- Prefer small, reviewable increments over large multi-file generations.
- Ask before adding a new third-party dependency not already named in `docs/ARCHITECTURE.md`.
- Nested `AGENTS.md` files may be added inside `backend/`, `web/`, `mobile/` for framework-specific detail as those folders are scaffolded.
- Verify behaviour with the repo's own harnesses before calling work done: `scripts/web/render-probe.py` asserts on a page's rendered markup, `scripts/e2e-credentials.py` (`--inspect` to look, no flags to run and clean up) drives the live API + DB. Details in `docs/ai-tooling.md` → Verification Scripts.
- Address-resolution regression checks (from repo root): `docker compose run --rm --no-deps -v "$PWD:/workspace" --entrypoint dotnet api run --project /workspace/scripts/address-resolution-tests/AddressResolutionTests.csproj`; mobile checks: `flutter test test/address_resolution_test.dart` from `mobile/`. These use fixtures, not the live LINZ service. Keep `LINZ_API_KEY` in local ignored environment configuration, never in Flutter or tracked settings; see `docs/ARCHITECTURE.md` for the provider seam and remaining live-verification gate.
