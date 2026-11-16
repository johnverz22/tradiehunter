---
name: docs-sync
description: Keep TradieHunter documentation consolidated and truthful. Use after any change to behaviour, scope, schema, config, flow, design tokens, tests or release status, and whenever someone is about to add a new doc file. Routes the change to the one doc that owns it and forbids per-version spec folders.
---
# Docs sync

The `docs/` folder holds **one file per type**; history lives in git, not in version folders.

| Change | Update only |
|---|---|
| Product goal, persona, business rule, metric, compliance item | `docs/PRD.md` |
| What is in or out of scope, a superseded decision | `docs/MVP.md` |
| A phase finished, verified, or deferred; a new open item | `docs/MILESTONES.md` |
| Behaviour, state machine, data model, endpoint, config key, money rule | `docs/SPECS.md` |
| Stack, seam, job, container, topology | `docs/ARCHITECTURE.md` |
| Email, Firebase, deployment runbook | `docs/OPERATIONS.md` |
| Test commands, seed accounts, harnesses | `docs/TESTING.md` |
| Manual test cases | `docs/QA.md` |
| Tokens, components, frames, notices, gates | `docs/DESIGN.md` (+ `docs/design/` sources) |
| MCPs, rules, skills, agent workflow | `docs/ai/AI-TOOLING.md` |

## Rules
1. Edit in place; never create `vX.Y/` folders, `*-plan.md`, `*-progress.md`, audit logs or session notes. If something is only useful for a week, it belongs in the PR.
2. Describe what **is**, not what was planned. Mark anything unverified as such (🟡) and list it in MILESTONES → Open items.
3. A decision that overrides an earlier one: change the earlier text, add a row to MVP §7 "Superseded decisions".
4. Brand: prose says **TradieHunter**. Keep `Fixo*` only for real code identifiers (see `docs/README.md`).
5. Money is `decimal`, time is UTC, every status change goes through `IJobStatusService`: never document a path that breaks this.
6. Update cross-links and the README index when a heading anchor moves. Do not paste secrets, tokens or production credentials into docs.
7. Before finishing: grep the docs for stale terms (`Blueprint Marketplace`, `TradieFixo`, `docs/specs/`, `MVP-SPEC`, `v1.6.2/`).
