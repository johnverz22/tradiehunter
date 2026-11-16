# AI Development Tooling

How AI coding agents work in this repo: rules, skills, MCP servers and the design toolchain. Keep this in sync when tooling changes (skill `docs-sync`).

## 1. Where things live

| Path (repo root) | What |
|---|---|
| `CLAUDE.md`, `.cursorrules`, `.windsurfrules` | Agent rules: same content, three tool formats. `CLAUDE.md` is canonical; regenerate the others from it |
| `AGENTS.md`, `mobile/AGENTS.md` | Tool-neutral rules; keep the docs-map block from `docs/ai/AGENTS-docs-block.md` |
| `agent/skills/` | Skills (below). Claude Code users can symlink `.claude/skills` → `agent/skills` |
| `agent/Makefile`, `agent/setup.sh`, `package.json` | Toolchain entry points |
| `tools/design2flutter/` | HTML mockup → Flutter AST transpiler (Node + parse5), `th_components.dart` widget contract |
| `docs/design/` | Mockup frames, `kit.css`, tokens, assets, audit/build scripts |
| `scripts/` | Verification scripts ([TESTING.md](../TESTING.md)) |

## 2. Rules in one paragraph

Money `decimal`, time UTC, spatial LINQ only, every status change through `IJobStatusService`, respect the job flow version, no unapproved scope (in-app payments, deposits, milestones, pre-booking chat), no invented UI data, no secrets in git. Mobile: tokens only, reuse `Fixo*` widgets, dark mode is a token swap, ≤ 2 amber elements, 48 dp targets, 12 px floor, `FixoNotice` for feedback. Full text: `CLAUDE.md`.

## 3. Skills

| Skill | Use when |
|---|---|
| `mockup-to-flutter` | Building or fixing a screen from a frame (includes the scaffold script and CSS → Flutter references) |
| `widget-refactor` | A build method passes ~100 lines, a structure repeats twice, or a lint flags hard-coded values |
| `ui-audit` | Before committing mockup changes; runs the design gates ([DESIGN §8](../DESIGN.md#8-regression-gates-design-changes-must-pass)) |
| `mockup-html-qa` | Checking frames for missing icons, back-button geometry, pill overflow, sub-12 px text before porting to Flutter |
| `design-vs-run-crosscheck` | Comparing rendered frames with run screenshots into a discrepancy table |
| `docs-sync` | **After any behaviour, scope, schema, config or status change**: routes the edit to the single owning doc |

## 4. Toolchain commands

```bash
./agent/setup.sh          # installs Node + Python deps, runs audit, transpile, lint, smoke
make -C agent audit       # design audit gates on docs/design
make -C agent transpile   # regenerate Flutter scaffolds into tools/design2flutter/output (not committed)
make -C agent check       # structural lint of generated Dart
make -C agent smoke       # end-to-end pipeline proof
make -C agent flutter     # dart format + flutter analyze + flutter test
npm run verify            # audit + transpile + check + smoke
```

Requires Node ≥ 18, Python 3, `beautifulsoup4`, Playwright + Chromium. `tools/design2flutter/output/` is generated and gitignored; regenerate it instead of committing it.

New screen: `bash agent/skills/mockup-to-flutter/scripts/new-screen.sh H13 chat` (finds the frame, scaffolds into `mobile/lib/views/chat/`). Then wire view models, swap `TH*` scaffolding for `Fixo*` widgets, stress-test (long text, 1.3× scale, 360 dp, three themes).

## 5. MCP servers

| Server | Command | Use |
|---|---|---|
| **Dart / Flutter** | `<flutter-sdk>/bin/dart mcp-server --flutter-sdk <flutter-sdk>` (full path required; bare `dart` is not on PATH) | `analyze_files`, `pub_dev_search`, `dart_format`, `run_tests`, device list, launch/hot reload, widget inspector. Check real Riverpod / go_router / Dio / signalr_netcore APIs before writing code |
| **PostgreSQL** | `@modelcontextprotocol/server-postgres` → `postgresql://fixo:fixo_dev@localhost:5432/fixo` (dev only; needs `docker compose up -d db`) | Read-only schema inspection, migration state, PostGIS column types (`geometry(Point, 4326)`), validating seeds. Inspect the live schema rather than trusting docs |
| **Browser / Puppeteer** | `@modelcontextprotocol/server-puppeteer` | Verify the React admin at `:3000`: render, theme toggle, console errors, auth flow. Fallback: `scripts/web/render-probe.py` |
| **GitHub** | `@modelcontextprotocol/server-github` (needs `GITHUB_PERSONAL_ACCESS_TOKEN` in the environment) | Issues, PRs, CI status. Scope the token to this repo; never commit it |

Config files by tool: `.kiro/mcp.json` (Kiro), `mcp.json` (OpenCode), `.agents/mcp_config.json` (Antigravity). Known fix: OpenCode and Antigravity configs that use the bare `dart` command are broken; use the full SDK path. Optional: `fetch` MCP (needs `uv`), Playwright MCP for richer E2E. No .NET or Docker MCP exists; use `docker compose` and `dotnet` in the container, and Swagger at `http://localhost:5000/swagger`.

| MCP | Permission | Notes |
|---|---|---|
| dart | read + write host | Starts Flutter/Dart processes |
| postgres | dev DB | Prefer read-only queries |
| puppeteer | local browser | No external browsing needed |
| github | repo, token-scoped | Read-only token for read-only workflows |

## 6. Recommended workflows

- **Backend / EF Core:** inspect schema with the postgres MCP → check `backend/Migrations/` → `dotnet ef migrations list` in the container. Re-verify the PostGIS spatial index after migrations.
- **Flutter:** pub.dev search for the package → `analyze_files` before changes → `run_tests` after.
- **React admin:** start the web service → screenshot via Puppeteer → check console for TanStack Query, router and SignalR errors.
- **Docs:** `docs-sync` after every behaviour or status change.

## 7. Security

Dev credentials only in MCP configs and `.env.example`; rotate before production and never replicate the pattern there. `.env`, `appsettings.Development.json`, `backend/firebase-service-account.json` stay gitignored. The GitHub token lives in the shell profile or a secrets manager. Treat any token pasted into a chat or ticket as exposed and revoke it.
