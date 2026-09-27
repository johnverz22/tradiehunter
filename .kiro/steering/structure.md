---
inclusion: always
---
# Project structure — Blueprint Marketplace

```
blueprint-marketplace/
├── docs/           # PRD, UX research, MVP spec, architecture, milestones, design system
│   ├── design/
│   │   ├── design-system.html   # Source of truth for color, type, spacing tokens
│   │   └── mockup/              # Screen mockups (light theme; add dark where missing)
│   │       ├── mobile/          # 01-splash … 15-homeowner-profile
│   │       └── web/             # 01-admin-login … 08-admin-settings
│   └── specs/      # Implementation task specs grouped by milestone (M1 … M5)
├── backend/        # .NET Web API (scaffold via `dotnet new` — see backend/STARTER_GUIDE.md)
├── web/            # React app (scaffold via `npm create vite` — see web/STARTER_GUIDE.md)
├── mobile/         # Flutter app (scaffold via `flutter create` — see mobile/STARTER_GUIDE.md)
├── AGENTS.md       # Shared cross-tool instructions (OpenCode, Antigravity)
├── GEMINI.md       # Antigravity-specific rules
├── opencode.json   # OpenCode config
└── .agent/rules/   # Antigravity workspace rules, split by area
```

Use `.kiro/specs/` to generate feature specs as features are built — one spec per feature (e.g. `job-request-flow`, `tradie-matching`, `chat-and-status`), each covering requirements, design, and task breakdown before implementation starts.
