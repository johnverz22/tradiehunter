# CLAUDE.md — working on TradieHunter

TradieHunter is a NZ tradie marketplace: .NET 10 API + Flutter app (homeowner/tradie) + React admin. It was developed as *Fixo*; user-facing text says **TradieHunter**, while code identifiers keep `Fixo` (`FixoApi`, `Fixo*` widgets, package `fixo`, `nz.co.fixo.fixo`, DB `fixo`, containers `fixo-*`). Do not rename them.

## Read first
`docs/README.md` is the map. Then, by task:
- behaviour, state machine, data, money → `docs/SPECS.md`; scope → `docs/MVP.md`; open work → `docs/MILESTONES.md`
- web admin UI → `docs/design/web/DESIGN_GUIDE.md` (`docs/design/web/mockups/index.html`); mobile UI → `docs/DESIGN.md` and `docs/design/mobile/DESIGN_GUIDE.md`; visual reference → `docs/design/mobile/mockups/index.html`; tooling → `docs/ai/AI-TOOLING.md`
- tests → `docs/TESTING.md`, `docs/QA.md`

## Non-negotiables
1. **Money** is `decimal(18,2)`, never float. **Time** is UTC in storage and on the wire, localised on the client.
2. **Spatial** queries use EF Core LINQ + NetTopologySuite. Never raw PostGIS SQL.
3. **Every job status change goes through `IJobStatusService`** (writes history, publishes SignalR). Never set `Job.Status` directly.
4. Run backend `dotnet` inside the container: `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <cmd>"`.
5. Respect the job flow version. `JobFlow:Version` is stamped on each job; v1 jobs keep the legacy pay-before-booking rules, v2 pays at completion. Never change one path while fixing the other.
6. Payment stays manual (bank transfer + receipt + staff verify). No in-app card payments, deposits, milestones or pre-booking chat without an explicit scope decision in `docs/MVP.md`.
7. Do not invent identity, badges, ratings, earnings, distances, contact details or fee claims in UI. Missing data is shown as unavailable, not zero.
8. Never commit secrets: `.env`, `appsettings.Development.json`, `firebase-service-account.json`, LINZ key, tokens.

## Mobile UI rules (Flutter)
- **Tokens only:** colours via `context.th.<name>` (`THColors`); `Space.*`, `Radii.*`, `Sizes.*`, `THType.*` for type. No `Color(0x…)`, no magic numbers. Missing token → add to `design_tokens.dart` and `docs/design/mobile/tokens/tokens.json`.
- **Reuse before create:** `THAppBar`, `THButton`, `THCard`, `THHero`, `THDock`, `THStickyBar`, `THBadge`, `THAvatar`, `THNotice`. New widgets follow the `TH*` contract in `docs/design/mobile/flutter/th_widgets.dart`.
- **Dark mode is a token swap**; a theme `if` inside a view is a bug. Support light/dark, 320 px width, text scale to 2.0, safe-area + keyboard. No outdoor variant.
- **Brand budget:** one gold (`accent`) action per screen. `brand` (navy) for secondary filled actions. Green = verified/done, red = problem/dispute.
- **Feedback:** use `THNotice` + `NoticeCopy`; no raw `SnackBar`.

## Web UI rules (React admin)
- **Tokens only** from `docs/design/web/` (extends the mobile master): `var(--ink)` / Tailwind `bg-surface`, `--sp-*`, `--r-*`; no hex. Reuse the existing shared components. One gold `btn-accent` per view or dialog. Light and dark are a token swap. `web/src/theme/` is still legacy v1.7 until migrated: follow `.agent/rules/frontend.md`.

## Workflows
- New or fixed screen: start from `docs/design/mobile/flutter/screens/<id>_screen.dart` stub, bind data, run `flutter analyze`. Widget extraction: `widget-refactor`. Design gate: `node docs/design/mobile/tools/build.mjs --check`.
- **After any behaviour, scope or status change: skill `docs-sync`**, and update only the owning doc. Do not create versioned spec folders, plans, progress logs or audit notes.

## Before committing
`dart format` · `flutter analyze` clean · `flutter test` green · backend `dotnet build` + `dotnet test` · for design changes `node docs/design/mobile/tools/build.mjs --check` and `node docs/design/web/tools/build.mjs --check`.
