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
- Source of truth: `docs/design/design-system.html` (tokens); for v1.7 mobile UI, `docs/design/v1.6/html/frames-homeowner.html` and `docs/design/v1.6/html/frames-tradie.html` are the visual source of truth. Read `docs/design/v1.6/docs/HANDOFF.md` for the full design contract: inline SVG icon rules (no sprite refs), CTA sticky-bar placement, component patterns, and full frame inventory. Mockups are excluded from inputs, deliverables and acceptance; do not match, update or replace them. This supersedes legacy mockup instructions and all v1.5 spec references.
- Preserve hourly pricing, manual payment review, disputes, permissions, role views, routes, repository/ViewModel layering, Decimal/UTC and SignalR transitions. Do not fabricate missing data or bypass functional/provider decision gates.
- Brand color driven by `--hue` CSS variable (dev brand "Fixo", `--hue: 209`). Never hardcode hex brand colors.
- Both light and dark themes are required for every UI component. If only one theme exists, add the other.
- Mobile tokens: `mobile/lib/theme/design_tokens.dart`. Web tokens: `web/src/theme/design-tokens.css`.
- **No hardcoded values in mobile UI code.** All spacing, radii, font sizes, font weights, colors, alpha tints, durations, letter spacing, shadows, and component sizes must come from the token classes in `design_tokens.dart` (`Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `Durations`, `Tracking`, `THColors`). Never write raw numeric literals or `Color(0x...)` in view/widget files. See `mobile/HARDCODED_AUDIT.md` for the full audit and the list of tokens to use for each category. If a needed token doesn't exist, add it to `design_tokens.dart` rather than inlining the value.
