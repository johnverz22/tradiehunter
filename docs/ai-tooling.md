# AI Development Tooling — Blueprint Marketplace

Reference document for MCP servers and AI coding tool configuration on this project.
Keep this in sync when adding, removing, or changing tooling.

---

## v1.7 UI rules — frame design system (updated Nov 2026)

Read `docs/design/v1.6/docs/HANDOFF.md` before doing any frame or component work. Full frame inventory, design decisions, and implementation rules live there. Key points:

### Frames are self-contained HTML — no sprite sheet
All `<use href="#i-*">` sprite refs have been removed from every visible element in `frames-homeowner.html` and `frames-tradie.html`. **Every icon is now inline SVG.** Do not introduce new sprite refs in pills, buttons, list rows, cards, or any prominent element. Permitted contexts for sprite refs: none remaining — all converted.

When adding a new icon to a frame, use an inline `<svg viewBox="0 0 24 24" ...>` with the path directly. Match the sizing convention:
- Pill icons: `width="14" height="14"`
- Button icons: `width="20" height="20"` (tile buttons: `width="20" height="20"`)
- Navbar tabs: `width="22" height="22"`
- FAB: `width="26" height="26"`
- Avatar verified badge (`.vbdg`): `style="width:60%;height:60%"`
- Hero/status large: match the explicit `width`/`height` already on the `<svg>` wrapper

### CTA buttons always in sticky bar
Every screen with a primary action uses `<div class="sticky">` pinned at the bottom. Content area must have `flex:1` to push the sticky down. Pattern:
```html
<div class="pad center" style="flex:1;..."> <!-- content --> </div>
<div class="sticky"><div class="btn btn-primary">Label</div></div>
<div class="homebar"><i></i></div>
```
Never place a full-width `btn-primary/ghost/secondary` inline with `margin-top` and `width:100%` outside of a card — move it to the sticky bar.

### Send button icon
Composer send button uses right-facing paper plane, not upward arrow:
```html
<svg height="20" width="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 12L2 4l4 8-4 8 20-8z"/></svg>
```

### Homeowner dashboard (H07) hero band pattern
```html
<div class="heroband" style="padding-bottom:32px">
  <div class="bpdots" style="position:absolute;inset:0;opacity:.6;pointer-events:none"></div>
  <img src="../assets/rings-3-navy.svg" style="position:absolute;right:-50px;top:-30px;width:260px;opacity:.22;pointer-events:none"/>
  <div class="hero-statusbar statusbar on-dark">...</div>
  <!-- greeting, location pill, bell with amber dot -->
</div>
```
No "Post a new job" strip inside the hero — the FAB in the navbar is the single entry point for posting.

### attcard gradient (no left border)
```css
.attcard { background: linear-gradient(180deg, rgba(60,117,170,.18) 0%, rgba(60,117,170,.06) 40%, transparent 100%); border-top: none; border-left: none; }
```

### Dark mode pill-waiting
```css
.dark .pill-waiting { background: rgba(137,175,210,.28); color: #ffffff; }
```

### btn-tonal buttons carry icons
All `btn-tonal` action buttons have a leading inline SVG. Mapping:
- Navigate → compass polygon `points="3 11 22 2 13 21 11 13 3 11"`
- Message / Message Sarah → speech bubble `<path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>`
- Call → phone handset path
- Check in → map pin path
- Check out → checkmark polyline

---

## v1.6 UI rules — audit-driven visual refinements, no mockups

- Read `AGENTS.md`, `mobile/AGENTS.md`, `docs/specs/v1.6/specification.md`, `docs/specs/v1.6/visual-design.md`, and `docs/specs/v1.6/tasks.md` before continuing mobile UI work. The v1.6 spec and visual design guidelines govern layout, hierarchy, consistency, readability, accessibility, container language, tonal buttons, and locked brand palette; `docs/design/design-system.html` supplies base tokens.
- Existing mockups are excluded from inputs, deliverables and acceptance checks. Do not match, update, replace or generate replacement mockups.
- Preserve hourly pricing, manual bank-transfer payment review, disputes, booking transitions, permissions, role-based views, routes/callbacks, shared ViewModels/repositories, Decimal-safe money, UTC/localized timestamps and SignalR synchronization. Do not invent identity, badges, ratings, earnings, distances, contact details or other missing data. Functional/provider/data gates D3–D7 remain applicable.
- Use semantic tokens and reusable controls. Support both themes, narrow widths and large text, reachable actions with safe-area/keyboard handling, and truthful empty/error states. No unapproved dependencies or API changes.
- Work one logical group at a time; execute tasks sequentially, update `tasks.md`, and run `flutter test --reporter expanded` and `flutter analyze` from `mobile/` for application changes; compare diagnostics with the recorded baseline. Mocked-font tests do not establish actual-font, golden, device, route or live-flow acceptance.

## Project Stack

| Layer | Technology |
|---|---|
| Backend | .NET 10, ASP.NET Core Web API, EF Core, ASP.NET Identity + JWT |
| Real-time | SignalR (chat, job-status transitions, match notifications) |
| Mobile | Flutter / Dart 3.13.4 — single app, role-based (homeowner / tradie) |
| Web admin | React 19, TypeScript, Vite, TanStack Query, react-router-dom v7, Tailwind CSS v4 |
| Database | PostgreSQL 16 + PostGIS (dev); EF Core with Npgsql + NetTopologySuite |
| Cache | Redis 7 (SignalR backplane + Hangfire) |
| Blob storage | Azurite locally (Azurite blob service :10000); Azure Blob Storage in prod via `AzureBlob` config |
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
4. If the Puppeteer MCP is unavailable, verify the rendered markup instead with
   `scripts/web/render-probe.py` (see [Verification Scripts](#verification-scripts)).

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

## Verification Scripts

Browser automation is not always available (the Puppeteer MCP needs the dev server and its own
config — see Known Limitations). These repo scripts are the portable fallback: they take no
arguments beyond a fixture and run with nothing but python3, node and the docker stack.

| Script | Verifies | Needs |
|---|---|---|
| `scripts/web/render-probe.py` | A React page's **rendered HTML** against a JSON fixture | `web/node_modules`, node |
| `scripts/e2e-credentials.py` | The credential-review API end to end, including DB state | `docker compose up` (api + db) |
| `scripts/p3-smoke.sh` | Offer/accept/decline/timeout flows (curl + psql) | `docker compose up` |

### `scripts/web/render-probe.py`

Renders a page with React, React Query and a `MemoryRouter` into `<web>/.probe/` via
`vite build --ssr` (so `@/` aliases, CSS imports and `import.meta.env` all behave as in the app),
executes the bundle with `node`, and asserts substrings against the HTML.

```sh
python3 scripts/web/render-probe.py \
    --page features/credentials/pages/CredentialQueue \
    --fixture scripts/web/fixtures/credentials/multi-page.json
```

- `--page` is a module path under `web/src` (no extension). `--export` pins the component;
  without it a default export wins and the page's own file name is the fallback
  (admin pages use named exports like `export const CredentialQueue`).
- `--keep` leaves `web/.probe/` (`entry.tsx`, resolved `fixture.json`, bundle, `render.html`)
  in place for debugging; otherwise the directory is deleted. It is gitignored either way.
- Exit code is non-zero if any expectation fails, so it is CI-safe.

Fixtures live next to the feature they cover, e.g.
`scripts/web/fixtures/credentials/{empty,multi-page,null-fields}.json`:

```json
{
  "route": "/credentials",
  "prefetch": [
    { "key": ["admin", "credentials", "pending", { "page": 1, "pageSize": 20 }],
      "url": "/admin/credentials/pending",
      "body": { "items": [], "totalCount": 0, "page": 1, "pageSize": 20, "totalPages": 0 } }
  ],
  "expect": [
    { "label": "empty state text", "needle": "No credentials awaiting review." },
    { "label": "no Approve buttons", "needle": ">Approve</button>", "present": false }
  ]
}
```

How it works and what to watch for:

- `prefetch` seeds the TanStack Query cache under the **page's own query key** (copy it from the
  hook, e.g. `useCredentials.ts`) — that is what makes data render synchronously in `renderToString`.
- `api.defaults.adapter` is replaced, so **every** axios call is answered from the fixture. Each
  `prefetch[].url` is served automatically; add a `routes` array only for calls outside a prefetch
  (mutations, secondary queries). An unmatched call throws instead of silently rendering an error
  state.
- `localStorage` is stubbed because `services/api.ts`'s request interceptor reads the JWT from it.
- `expect` needles are matched against HTML with React's `<!-- -->` separators stripped, so write
  them as they appear in the DOM (e.g. `&lt;img …&gt;` for escaped text). Some ` | ` noise from
  icon `<svg>`s appears in the `<tbody>` dump printed with the results.


### `scripts/e2e-credentials.py`

Drives the credential-review contract the web queue consumes
(`GET /admin/credentials/pending`, `POST /admin/credentials/{id}/review`) against a **running**
stack: logs in as the seeded admin, seeds three Pending credentials for one dev tradie profile,
then exercises approve, reject, reject-without-a-reason (400) and review-of-a-missing-credential
(404), asserting both the responses and the resulting rows (read via `docker compose exec db psql`).

```sh
docker compose up -d api db
python3 scripts/e2e-credentials.py                 # seed -> assert -> clean up
python3 scripts/e2e-credentials.py --inspect       # read-only: dump queue + verification state
python3 scripts/e2e-credentials.py --keep          # leave the seeded rows for manual UI poking
python3 scripts/e2e-credentials.py --tradie-profile-id 5
```

- Every assertion prints `PASS`/`FAIL` with the observed value, and the script exits non-zero if any
  failed — it stops before cleanup on failure so the bad state can be inspected.
- It cleans up after itself (deletes the seeded rows, restores the tradie's `IsVerified`), so the
  dev DB ends as it started; `--inspect` before and after is the quickest way to confirm.
- stdlib only: HTTP via `urllib`, DB access via `docker compose exec db psql -tAc`. Admin credentials
  default to the `AdminSeed` values in `backend/appsettings.Development.json`; override with
  `FIXO_API_URL` / `FIXO_ADMIN_EMAIL` / `FIXO_ADMIN_PASSWORD`, or `--api-url` / `--token`.

### `scripts/one-off/`

Spent, task-specific scripts kept for provenance only — patch helpers, spec tick-off and
fixture-generation scripts from earlier milestones. They are **not** maintained and may be unsafe to
re-run (several mutate source files or the dev DB in place). Anything meant to be reused belongs in
`scripts/` proper with a docstring explaining its usage; one-shot helpers land here once their job
is done.


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
