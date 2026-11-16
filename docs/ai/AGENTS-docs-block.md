<!-- Paste into the repo-root AGENTS.md and mobile/AGENTS.md (replace any block that points at docs/specs/, docs/MVP-SPEC*.md or docs/design/v1.6*). -->
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
| Tokens, components, mockups, notices | `docs/DESIGN.md`, `docs/design/mockups/index.html`, `docs/design/DESIGN_GUIDE.md` |
| MCPs, rules, skills | `docs/ai/AI-TOOLING.md` |

Scope rule: changes to decisions recorded in `docs/MVP.md` (hourly vs quotes, payment timing, materials, cancellations, in-app payments) need explicit owner sign-off first; record the superseded decision in MVP §7. Flow v2 (pay at completion) is the current design; v1 remains only for in-flight jobs. The v2 design system (Trust Navy + Gold) is the visual source of truth; mockups are at `docs/design/mockups/index.html`. Update docs via the `docs-sync` skill.
