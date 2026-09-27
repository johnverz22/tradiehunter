---
inclusion: always
---
# Tech stack — Blueprint Marketplace

- **Backend**: .NET 10 (ASP.NET Core Web API), EF Core, ASP.NET Identity + JWT auth, SignalR for real-time (chat, job-status transitions, match notifications), Hangfire for scheduled reminder jobs.
- **Web**: React, single app with role-based routing (homeowner / tradie / admin behind one shell).
- **Mobile**: Flutter, single app with role-based views (not two separate apps).
- **Real-time**: SignalR hubs are the single real-time layer — both React and Flutter clients connect to the same hub endpoints. Do not introduce a second real-time system (e.g. Firebase) alongside it.

Full rationale: `docs/ARCHITECTURE.md`.

## Conventions
- Money: `decimal`, never float.
- Timestamps: UTC in the database; localize at the client.
- One codebase per platform, gated by role — never fork into per-role apps.
- New third-party dependencies not already named above require a note in the PR description explaining why.
- Backend `dotnet` commands must always run inside the API container (OrbStack) — `dotnet` is NOT installed on the host. Use `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"`.

## Design system
- Source of truth: `docs/design/design-system.html` (tokens) and `docs/design/mockup/` (screen mockups).
- Brand color driven by `--hue` CSS variable (dev brand "Fixo", `--hue: 209`). Never hardcode hex brand colors.
- Both light and dark themes are required for every UI component. If only one theme exists, add the other.
- Mobile tokens: `mobile/lib/theme/design_tokens.dart`. Web tokens: `web/src/theme/design-tokens.css`.
