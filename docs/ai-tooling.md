# AI Development Tooling — Blueprint Marketplace

Reference document for MCP servers and AI coding tool configuration on this project.
Keep this in sync when adding, removing, or changing tooling.

---

## Project Stack

| Layer | Technology |
|---|---|
| Backend | .NET 10, ASP.NET Core Web API, EF Core, ASP.NET Identity + JWT |
| Real-time | SignalR (chat, job-status transitions, match notifications) |
| Mobile | Flutter / Dart 3.13.4 — single app, role-based (homeowner / tradie) |
| Web admin | React 19, TypeScript, Vite, TanStack Query, react-router-dom v7, Tailwind CSS v4 |
| Database | PostgreSQL 16 + PostGIS (dev); EF Core with Npgsql + NetTopologySuite |
| Cache | Redis 7 (SignalR backplane + Hangfire) |
| Blob storage | MinIO locally (S3-compatible); swappable to AWS S3 / Azure Blob in prod |
| Scheduling | Hangfire (Redis backend) |
| Push | Firebase Cloud Messaging (FCM) via Firebase Admin SDK |
| Infrastructure | Docker Compose on OrbStack |
| CI/CD | GitHub Actions (`.github/workflows/ci.yml`) |

---

## MCPs

### Dart / Flutter

**Server:** `dart mcp-server` (Dart SDK built-in)
**Config location:** `.kiro/mcp.json`, `mcp.json`, `.agents/mcp_config.json`
**Command:** `/Users/john/Develop/flutter/bin/dart mcp-server --flutter-sdk /Users/john/Develop/flutter`

> ⚠️ Must use the **full path** to the Dart binary. The `dart` command is not on the system PATH
> unless Flutter's `bin/` is explicitly added. The bare `dart` command in `mcp.json` and
> `.agents/mcp_config.json` is broken — fix those configs to use the full path.

Capabilities this MCP provides:

- Dart/Flutter static analysis (`analyze_files`)
- pub.dev package search (`pub_dev_search`)
- Dart formatting (`dart_format`)
- Running Flutter/Dart tests (`run_tests`)
- Listing connected devices (`list_devices`)
- Launching / hot-reloading Flutter apps (`launch_app`, `hot_reload`, `hot_restart`)
- Widget inspector
- Reading pubspec dependencies
- Code navigation via LSP

Relevant to this project because Flutter is the primary client. Agent should use this MCP before
writing Riverpod, go_router, Dio, or signalr_netcore code to inspect actual package APIs and run
`flutter analyze` to catch errors early.

---

### PostgreSQL

**Server:** `@modelcontextprotocol/server-postgres` (npx)
**Config location:** `.kiro/mcp.json`, `mcp.json`, `.agents/mcp_config.json`
**Connection:** `postgresql://fixo:fixo_dev@localhost:5432/fixo` (dev only — Docker Compose container)

> ⚠️ The Postgres container must be running (`docker compose up -d db`) before connecting.
> Never commit real production credentials to any MCP config file.

Capabilities:

- Schema inspection (tables, columns, indexes, constraints)
- Read-only SQL queries against the live dev database
- Verify migration state before scaffolding new EF Core entities
- Inspect PostGIS spatial column types (`geometry(Point, 4326)`)
- Query existing data to validate seeding or auth flows

Current schema (as of `InitialCreate` migration):

| Table | Purpose |
|---|---|
| `AspNetUsers` | Identity users — `FirstName`, `LastName`, `Role`, `CreatedAtUtc`, `IsActive` |
| `AspNetRoles` | Identity roles |
| `TradieProfiles` | `TradeType`, `IsVerified`, `IsAvailable`, `Location` (PostGIS Point/GIST index), `ServiceRadiusKm` |
| `AspNetUser*` | Standard Identity junction/claims tables |

Use this MCP before writing any EF Core LINQ or migration to verify column types match your
model. Particularly important for the `Location` field (PostGIS `geometry(Point, 4326)`) and
`ServiceRadiusKm` (`numeric(18,2)`).

---

### Browser / Puppeteer

**Server:** `@modelcontextprotocol/server-puppeteer` (npx)
**Config location:** `.kiro/mcp.json`, `mcp.json`, `.agents/mcp_config.json`

Capabilities:

- Launch Chromium and navigate to URLs
- Click, type, screenshot
- Inspect DOM and computed styles
- Capture console errors and network requests
- End-to-end verification of the React admin UI

Use this MCP to:

- Verify the React admin dashboard renders correctly after UI changes
- Check that design tokens (Tailwind CSS variables, `--hue`) are applied correctly
- Test light/dark theme toggles visually
- Catch console errors from the running web app
- Verify auth flows in the browser

**Prerequisite:** React dev server must be running (`npm run dev` in `web/`, port 3000, or via
Docker Compose `web` service on port 3000).

---

### GitHub

**Server:** `@modelcontextprotocol/server-github` (npx)
**Config location:** `.kiro/mcp.json` only (not yet in other agent configs)

> ⚠️ Requires a `GITHUB_PERSONAL_ACCESS_TOKEN` environment variable. Set it in your shell
> profile or in the MCP server's `env` block. Do **not** commit the token value.
> No GitHub remote is currently configured on this repo — set one up before this MCP is useful.

Once a remote is connected:

- Search code across the repo on GitHub
- View and create issues
- View and comment on pull requests
- Check CI run status from GitHub Actions

---

## Recommended Usage by Workflow

### Before writing backend (EF Core / migrations)
1. Run the postgres MCP to inspect current schema.
2. Check `backend/Migrations/` to confirm migration state.
3. Run `docker compose run --rm --entrypoint /bin/bash api -c "dotnet ef migrations list"` to verify applied migrations.

### Before writing Flutter code
1. Use the Dart MCP to search pub.dev for the package you need.
2. Use `analyze_files` on `mobile/lib/` to catch existing analysis issues before making changes.
3. After changes, use `run_tests` to run `flutter test`.

### After UI changes to React admin
1. Start the web dev server (or use the Docker `web` service).
2. Use the Puppeteer MCP to take a screenshot and verify visual output.
3. Check console for errors related to TanStack Query, react-router, or SignalR.

### When checking database state during backend development
1. Use the postgres MCP `query` tool with read-only SQL (`SELECT`, `EXPLAIN`).
2. Verify spatial index on `TradieProfiles.Location` is intact after migrations.

---

## Permissions

| MCP | Permission level | Notes |
|---|---|---|
| `dart` | Read + write (host filesystem, processes) | Starts Flutter/Dart processes on host |
| `postgres-backend` | Read + write (dev DB) | Dev credentials only; read-only queries strongly preferred |
| `puppeteer-react` | Browser automation | Sandboxed to local browser; no external browsing needed |
| `github` | Repo read + write (scoped to token) | Scope token to the single repo; use `repo:read` for read-only workflows |

---

## Security Considerations

1. **No production credentials** — all MCP configs use dev credentials from `.env` / Docker Compose defaults. Production has different credentials that must never appear in MCP config files.
2. **Postgres connection string** — the `postgresql://fixo:fixo_dev@localhost:5432/fixo` string in `mcp.json` and `.agents/mcp_config.json` contains dev credentials that match the values in `.env.example`. This is acceptable for local dev but must be rotated before production. Do not replicate this pattern for production config.
3. **GitHub token** — store the `GITHUB_PERSONAL_ACCESS_TOKEN` in your shell profile (`.zshrc` / `.bash_profile`) or a secrets manager. Never commit it.
4. **Puppeteer** — runs Chromium locally. No external network access needed for local UI testing.
5. **`.env` file** — is gitignored. Never commit `.env`; only commit `.env.example` with placeholder values.

---

## Known Limitations and Gaps

### fetch MCP — blocked

The `fetch` MCP (`mcp-server-fetch` via `uvx`) is defined in `~/.kiro/settings/mcp.json` but disabled because `uv` / `uvx` is not installed. To enable:

```sh
brew install uv
```

Then in `~/.kiro/settings/mcp.json`, set `"disabled": false`. This would allow the agent to
fetch live documentation pages (MDN, learn.microsoft.com, pub.dev, etc.).

### .NET / C# tooling — no dedicated MCP

There is no MCP equivalent for .NET tooling currently available via npx. The agent compensates by:

- Reading `backend/` source files directly
- Running `dotnet` commands inside the API container:
  `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"`
- Consulting the Swagger UI at `http://localhost:5000/swagger` (when API container is running)

### Docker inspection — no MCP

No Docker MCP is configured. Container status is checked via `docker compose ps` / `docker ps`
shell commands. A Docker MCP would add container log inspection and exec capabilities, but none
is currently available as a stable npx package.

### No git remote

The repo has no GitHub remote configured. Once `git remote add origin <url>` is run, the GitHub
MCP becomes fully useful for PR and issue workflows.

---

## Optional Tools (Not Currently Installed)

| Tool | Purpose | How to install |
|---|---|---|
| `fetch` MCP | Fetch live docs (MDN, MS Learn, pub.dev pages) | `brew install uv`, then enable in `~/.kiro/settings/mcp.json` |
| Playwright MCP | More capable E2E testing than Puppeteer | `npx @playwright/mcp` — useful when integration tests are added |

---

## Config File Locations

| File | Used by | Notes |
|---|---|---|
| `.kiro/mcp.json` | Kiro | Project-level; created during AI tooling setup |
| `~/.kiro/settings/mcp.json` | Kiro | Global; `fetch` MCP (disabled — needs `uv`) |
| `mcp.json` | OpenCode | dart command broken (no full path) |
| `.agents/mcp_config.json` | Antigravity | dart command broken (no full path) |
| `.agent/mcp_config.json` | Antigravity (old path) | Only has dart MCP |

> The dart MCP command in `mcp.json` and `.agents/mcp_config.json` uses `"command": "dart"` which
> does not resolve unless Flutter's `bin/` is in PATH. Update those to
> `"command": "/Users/john/Develop/flutter/bin/dart"` to fix Antigravity and OpenCode.
