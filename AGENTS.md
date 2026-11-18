# AGENTS.md — Fixo Marketplace

Read by: OpenCode, Antigravity (as of v1.20.3+), and any other AGENTS.md-compatible tool.

## What this project is
A two-sided marketplace for homeowners and tradies. White-label ready — "Fixo" is the development brand. Full context lives in `docs/` — read `docs/PRD.md` and `docs/MVP.md` before generating any feature code. Do not invent scope beyond `docs/MVP.md`'s Tier 1/2/3 scope without flagging it.

## Stack
- **Backend**: .NET 10 (ASP.NET Core Web API), EF Core + PostgreSQL/PostGIS (dev), ASP.NET Identity + JWT, SignalR for real-time (chat, job-status, match notifications), Hangfire for scheduled reminders, Firebase Admin SDK for FCM push.
- **Mobile (primary)**: Flutter, single app with role-based views (homeowner/tradie — not two separate apps). This is the main client for the MVP.
- **Web (admin only)**: React, scoped to admin dashboard only for MVP. Not a homeowner/tradie client. Design system: `docs/design/web/` (extends the mobile tokens). `web/src/theme/` and `web/public/fonts/` are synced copies: never hand-edit them; change `docs/design/web/`, run its build, then `npm run design:sync` in `web/`. Tokens and kit classes only; no retired v1.7 names (`npm run design:legacy`).
- **Infrastructure**: Docker Compose (OrbStack locally) — PostgreSQL+PostGIS, Azurite (Azure Blob Storage emulator), Redis (SignalR backplane + Hangfire).
- Full rationale in `docs/ARCHITECTURE.md`.

## Conventions
- One codebase per platform, role-based UI — never scaffold a second app for a second role.
- Money and pricing fields: always decimal, never float.
- All timestamps: UTC in the database, localized at the client. Locale settings are configuration-driven (see `docs/ARCHITECTURE.md`).
- Every job-status transition must go through the SignalR hub, not a REST-only side channel, so both web and mobile stay in sync.
- Follow the design system in `docs/design/mobile/DESIGN_GUIDE.md` and `docs/design/mobile/tokens/tokens.json` for any UI work. Colour via `context.th.<name>`, type via `THType.*`, space/radii/size via `Space.*`/`Radii.*`/`Sizes.*`. The visual reference for mobile screens is `docs/design/mobile/mockups/index.html` (30 v2 screens, light + dark). Read `docs/DESIGN.md` for the full design contract (component vocabulary, CTA placement, feedback notices). Preserve hourly pricing, manual payment review, disputes, permissions, routes/callbacks, repository/ViewModel layering and SignalR behavior; never fabricate missing data or bypass functional decision gates. Both light and dark themes are required.
- **No hardcoded values in mobile UI code.** All spacing, radii, font sizes, font weights, colors, alpha tints, durations, letter spacing, shadows, and component sizes must come from the token classes in `mobile/lib/theme/design_tokens.dart` (`Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `Durations`, `Tracking`, `THColors`). Never write raw numeric literals or `Color(0x...)` in view/widget files. See `mobile/HARDCODED_AUDIT.md` for the full audit and the list of tokens to use for each category. If a needed token doesn't exist, add it to `design_tokens.dart` rather than inlining the value.
- Local dev runs via `docker compose up` (OrbStack). Flutter runs on the host (emulator/simulator), not in Docker.
- Backend `dotnet` commands must always run inside the API container — `dotnet` is NOT installed on the host. Use `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"` (e.g. restore, build, test, ef migrations).
- Use EF Core spatial LINQ (NetTopologySuite), never raw PostGIS SQL — keeps the SQL Server swap path open for production.

## Out of scope for MVP (see docs/MVP.md)
Do not implement without explicit sign-off: in-app payments/BNZ integration, automated dispute resolution, ML-based matching, loyalty/referrals. These are V1.1+.

## Working style
- Prefer small, reviewable increments over large multi-file generations.
- Ask before adding a new third-party dependency not already named in `docs/ARCHITECTURE.md`.
- Nested `AGENTS.md` files may be added inside `backend/`, `web/`, `mobile/` for framework-specific detail as those folders are scaffolded.
- Verify behaviour with the repo's own harnesses before calling work done: `scripts/web/render-probe.py` asserts on a page's rendered markup, `scripts/e2e-credentials.py` (`--inspect` to look, no flags to run and clean up) drives the live API + DB. Details in `docs/ai/AI-TOOLING.md` → Verification Scripts.
- Address-resolution regression checks (from repo root): `docker compose run --rm --no-deps -v "$PWD:/workspace" --entrypoint dotnet api run --project /workspace/scripts/address-resolution-tests/AddressResolutionTests.csproj`; mobile checks: `flutter test test/address_resolution_test.dart` from `mobile/`. These use fixtures, not the live LINZ service. Keep `LINZ_API_KEY` in local ignored environment configuration, never in Flutter or tracked settings; see `docs/ARCHITECTURE.md` for the provider seam and remaining live-verification gate.

## Documentation map (consolidated)

All docs live in `docs/`, one file per type. Do not add versioned spec folders.

| Need | Read |
|---|---|
| Index, naming, conventions | `docs/README.md` |
| Product / scope / status | `docs/PRD.md`, `docs/MVP.md`, `docs/MILESTONES.md` |
| Behaviour, state machine, data model, money, config | `docs/SPECS.md` |
| Stack and seams | `docs/ARCHITECTURE.md` |
| Email + Firebase runbooks | `docs/OPERATIONS.md` |
| Test commands, seeds / manual QA | `docs/TESTING.md`, `docs/QA.md` |
| Web admin tokens, components, mockups | `docs/design/web/DESIGN_GUIDE.md`, `docs/design/web/mockups/index.html` |
| Mobile tokens, components, mockups, notices | `docs/DESIGN.md`, `docs/design/mobile/mockups/index.html`, `docs/design/mobile/DESIGN_GUIDE.md` |
| MCPs, rules, skills | `docs/ai/AI-TOOLING.md` |

Scope rule: changes to decisions recorded in `docs/MVP.md` (hourly vs quotes, payment timing, materials, cancellations, in-app payments) need explicit owner sign-off first; record the superseded decision in MVP §7. Flow v2 (pay at completion) is the current design; v1 remains only for in-flight jobs. The v2 design system (Trust Navy + Gold) is the visual source of truth; mockups are at `docs/design/mobile/mockups/index.html`. Update docs via the `docs-sync` skill.
