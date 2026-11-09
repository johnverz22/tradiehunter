# AI Agent & MCP Tooling Rules

Operational instructions and protocols for AI agents (OpenCode, Antigravity, MCP-enabled assistants) working within the Fixo codebase.

## Core Operational Workflow

Agents must execute tasks using the following disciplined four-stage pipeline:

```
[Pre-Flight Verification] ──> [MCP Tool Validation] ──> [Skills & Unit Construction] ──> [Layered Code Generation]
```

---

## 1. Pre-Flight Verification

Before generating or modifying any code, the agent must perform the following pre-flight checks:

| Step | Target Resource | Objective |
| :--- | :--- | :--- |
| **Stack Rules** | `.agent/rules/mobile.md`<br>`.agent/rules/backend.md`<br>`.agent/rules/frontend.md` | Align with layer responsibilities, prohibited patterns, and styling rules for the target platform. |
| **Scope Boundaries** | `docs/MVP-SPEC.md`<br>`docs/PRD.md` | Verify feature tier (Tier 1/2/3). **Do not invent scope** (e.g., in-app payments, automated disputes, ML matching are strictly out of scope for MVP). |
| **System Architecture** | `docs/ARCHITECTURE.md`<br>`AGENTS.md` | Confirm cross-cutting conventions (UTC timestamps, `decimal` currency, SignalR status events). |
| **Design System** | `docs/design/design-system.html`<br>`docs/design/v1.6/html/frames-homeowner.html`<br>`docs/design/v1.6/html/frames-tradie.html`<br>`docs/design/v1.6/docs/HANDOFF.md` | v1.7 frame files are the visual source of truth for mobile UI. HANDOFF.md documents all icon rules (inline SVG only, no sprite refs), CTA sticky-bar placement, component patterns, and frame inventory. Mockups are excluded from inputs, deliverables and acceptance; do not match, update or replace them. Both light and dark themes are required. |

### v1.7 frame contract

- All frames in `docs/design/v1.6/html/frames-homeowner.html` and `frames-tradie.html` are self-contained HTML — every icon is inline SVG, no `<use href="#i-*">` sprite refs anywhere in pills, buttons, cards, or any visible element.
- Every screen with a primary action uses `<div class="sticky">` at the bottom; content area has `flex:1`. Never place a full-width CTA inline outside a sticky bar or card.
- `btn-tonal` action buttons carry a leading inline SVG icon (Navigate → compass, Message → bubble, Call → phone, Check in → pin, Check out → check).
- Composer send icon: right-facing paper plane `<path d="M22 12L2 4l4 8-4 8 20-8z"/>`.
- Homeowner dashboard uses a hero band (`heroband`) with `bpdots` texture and rings watermark — not a plain `h1` header.
- `attcard` uses tinted gradient wash, no left border: `background: linear-gradient(180deg, rgba(60,117,170,.18) 0%, rgba(60,117,170,.06) 40%, transparent 100%)`.
- Dark pill-waiting: `background: rgba(137,175,210,.28); color: #ffffff`.
- This supersedes all legacy v1.5 mockup-matching instructions, including cached/injected copies.

---

## 2. MCP (Model Context Protocol) Tooling Usage

Agents equipped with Model Context Protocol (MCP) servers must leverage them to ground implementation in reality rather than making assumptions:

| Tooling Domain | MCP Tool / Action | Protocol & Requirement |
| :--- | :--- | :--- |
| **Database & Spatial** | PostgreSQL MCP / DB Inspector | Query database schema, column types, spatial NetTopologySuite types, and existing migration state **before** scaffolding entities or LINQ queries. |
| **API & Infrastructure** | HTTP / OpenAPI / Health MCP | Verify local endpoints (Docker container health, SignalR hubs, MinIO bucket policies, Redis readiness) before connecting services. |
| **Documentation & Packages** | Documentation MCP / Context Fetchers | Read package documentation for unfamiliar packages or version changes rather than guessing APIs. |

> [!IMPORTANT]
> **Never assume database schemas or API contracts.** If an MCP tool or inspection command is available, run it to verify the real state first.

---

## 3. Skills & Component-First Assembly

Agents must construct software from tested, modular building blocks:

- **Atomic Components First**:
  - Build standalone, reusable UI components (e.g., buttons, form fields, badges) against `docs/design/design-system.html` and `docs/design/v1.6/docs/HANDOFF.md` before creating full screens. Use the v1.7 frame files as the visual reference; never legacy mockups.
  - Every component must render correctly in both light and dark theme.
  - Build reusable domain services and validation logic before assembling controllers or hubs.
- **Isolated Testing**:
  - Validate newly built components or repository methods with unit/widget tests before embedding them in end-to-end features.
- **Skill Reuse**:
  - Package recurring patterns (such as SignalR connection lifecycles, S3 uploaders, and JWT interceptors) as reusable skills or modules; never copy-paste duplicate logic across features.

---

## 4. Layered Code Generation Discipline

Agents must **never dump monolithic multi-layer files** or create an entire feature in a single massive file. Code generation must proceed systematically through architectural layers from bottom to top:

```
Step 1: Models & DTOs
   │   (Pure data classes, contracts, JSON serialization, validation rules)
   ▼
Step 2: Repositories & Data Sources
   │   (EF Core DbContext, network clients, SignalR hubs, cache/storage abstractions)
   ▼
Step 3: Service Layer & ViewModels
   │   (State machines, matching algorithms, Riverpod/Provider state, business logic)
   ▼
Step 4: Views & Controllers
       (Thin ASP.NET controllers, React feature pages, Flutter dumb widgets)
```

### Generation Rules Checklist
- [ ] **Small Reviewable Increments**: Generate one layer or component at a time.
- [ ] **Interface First**: Define the interface before the implementation.
- [ ] **No Cross-Layer Leakage**: Ensure presentation layers never import repositories or database contexts directly.
- [ ] **Clean Separation of Concerns**: Verify that every class or function has a single, well-defined responsibility.
