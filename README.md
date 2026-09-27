# Blueprint Marketplace

A two-sided marketplace connecting homeowners and tradies in New Zealand — transparent pricing, real-time matching, and accountability through reviews.

This repo is a **scaffold**, not generated app code. Folders are placeholders with their own starter guides; you run each framework's official generator yourself (see each subfolder's `STARTER_GUIDE.md`). Docs, milestones, and the design system are already in place.

## Repo layout

```
blueprint-marketplace/
├── docs/                  # Product docs, MVP spec, architecture, milestones, design system
│   ├── PRD.md
│   ├── UX-RESEARCH.md
│   ├── MVP-SPEC.md
│   ├── ARCHITECTURE.md
│   ├── MILESTONES.md
│   └── design/design-system.html
├── backend/               # .NET (ASP.NET Core + SignalR) — STARTER_GUIDE.md inside
├── web/                   # React (admin + homeowner + tradie web) — STARTER_GUIDE.md inside
├── mobile/                # Flutter (single app, role-based) — STARTER_GUIDE.md inside
├── AGENTS.md              # Shared instructions: OpenCode, Antigravity, any AGENTS.md-reading tool
├── GEMINI.md              # Antigravity-specific project rules (highest priority for Antigravity)
├── opencode.json          # OpenCode config (permissions, project metadata)
├── .agent/rules/          # Antigravity workspace rules, split by area
└── .kiro/                 # Kiro steering + specs
    ├── steering/product.md, tech.md, structure.md
    └── specs/             # Kiro will generate feature specs here
```

## Quick start

1. Read `docs/PRD.md` and `docs/MVP-SPEC.md` first — every AI tool config below points back to these as the source of truth.
2. Pick a folder (`backend/`, `web/`, `mobile/`) and follow its `STARTER_GUIDE.md` to run the official generator (`dotnet new`, `npm create vite`, `flutter create`).
3. Open the repo root in whichever AI coding tool you use:
   - **OpenCode** — reads `AGENTS.md` + `opencode.json` automatically.
   - **Antigravity** — reads `GEMINI.md` first, then `AGENTS.md`, then `.agent/rules/*.md`.
   - **Kiro** — reads `.kiro/steering/*.md` automatically; use `.kiro/specs/` for feature specs as you build them.
4. All three tools are pointed at the same docs — there is one source of truth (`docs/`), not three separate briefs.

## Design system

Open `docs/design/design-system.html` directly in a browser (or drag it into any AI coding tool as reference) — it's the "Blueprint" token system: brand hue variable, type scale, spacing, and core components (tradie card, job stepper, badges, buttons).
