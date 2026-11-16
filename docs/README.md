# TradieHunter Documentation

One file per type. History lives in git; nothing here is versioned by folder. Status as of **v1.7, 2026-11-16**.

| Doc | Answers |
|---|---|
| [PRD.md](PRD.md) | Why, for whom, business rules, success metrics, compliance |
| [MVP.md](MVP.md) | What is in and out of scope; superseded decisions |
| [MILESTONES.md](MILESTONES.md) | What shipped, what is verified, **open items**, doc conflicts found |
| [SPECS.md](SPECS.md) | Behaviour: roles, data model, state machine, money, matching, payments, v1.7 flow, config |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Stack, seams, jobs, topology |
| [OPERATIONS.md](OPERATIONS.md) | Email and Firebase/Google runbooks |
| [TESTING.md](TESTING.md) | How to run automated tests, seeds, verification scripts |
| [QA.md](QA.md) | Manual release pass by actor, including v1.7 cases |
| [DESIGN.md](DESIGN.md) | Visual system, tokens, components, frame inventory, audit gates |
| [ai/AI-TOOLING.md](ai/AI-TOOLING.md) | Agent rules, skills, MCP servers, design toolchain |
| `design/` | Source assets: HTML frames, `kit.css`, tokens, illustrations, fonts, build + audit scripts |

## Naming: TradieHunter vs Fixo

The product was built as **Fixo** and rebranded to **TradieHunter** (v1.3 spec, v1.4 implementation). All prose, UI copy, push titles, emails and docs say TradieHunter, driven by `Brand:AppName`. To avoid a rename-everything migration, **code identifiers keep `Fixo`**: .NET project/namespace `FixoApi` / `Fixo*`, `FixoDbContext`, `Fixo*` Flutter widgets and `FixoTheme`, Dart package `fixo`, Android `nz.co.fixo.fixo`, iOS bundle `fixo`, database `fixo`, blob containers `fixo-photos` / `fixo-credentials` / `fixo-payments`, `FIXO_*` env/dart-defines, `@fixo.test` accounts, Firebase project `fixo-dev-75df4`. These are not bugs; do not rename them without a planned migration.

## Rules for editing docs

1. Update the owning doc in place (table in `agent/skills/docs-sync/SKILL.md`). No new versioned folders, plans, progress logs or audit notes.
2. Describe what exists. Unverified claims are marked and listed in MILESTONES → Open items.
3. A decision that overrides an earlier one is edited in place and logged in [MVP §7](MVP.md#7-superseded-decisions).
4. No secrets, tokens or production credentials. Dev seed accounts in TESTING are dev-only.

## What was removed in the consolidation

The old `docs/` held about 110 Markdown files (≈1.3 MB), a duplicated nested design bundle and ~200 generated Dart scaffolds. Merged into the docs above and deleted: MVP-SPEC v1.1/v1.2/v1.3, MILESTONES (old), UX-RESEARCH, `specs/v1.1`–`v1.7` (feature specs, task trackers, implementation plans, per-phase QA files, audit findings, hard-coded-value audit, sprint status, findings log, capture manifest), `audit-execution-progress`, `EMAIL-TEMPLATE-REVISION-PLAN` (implemented; runbook kept), `FRONTEND-TEST-SETUP` (tests exist; superseded by TESTING), `MOBILE-MOCKUP-PROMPTS`, the nested design bundle (duplicate `FIX_SPECIFICATION`, per-version READMEs/audits/changelog, one-off `fix_v161/fix_v162` scripts, generated `design2flutter/output`). Everything remains in git history; tag the pre-consolidation commit (`docs-archive-2026-11`) before merging.
