# GEMINI.md — Fixo project rules

Antigravity-specific overrides. Read alongside `AGENTS.md` (shared rules); this file takes priority for Antigravity sessions only.

## Autonomy profile
Recommended: **Review-driven development** — balanced autonomy with checkpoints. This project touches payment-adjacent flows (deferred to V1.1) and auth, so avoid Agent-driven (minimal-review) mode once those areas are in scope.

## Context to load first
1. `docs/PRD.md`
2. `docs/MVP-SPEC.md`
3. `docs/ARCHITECTURE.md`
4. `.agent/rules/*.md` for area-specific detail (backend/frontend/mobile)

## Project-specific notes
- Design tokens live in `docs/design/design-system.html` — treat it as the source of truth for color, type, and spacing, not a static reference image. Also refer to the mockup in `docs/design/mockup/`. Both light and dark themes are required; add light theme if only dark is present.
- Backend `dotnet` is NOT installed on the host — always run `dotnet` inside the API container (OrbStack): `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"`. See `.agent/rules/backend.md` for details.
- When generating backend code, check `.agent/rules/backend.md` for .NET conventions before writing.
- When generating web code, check `.agent/rules/frontend.md`.
- When generating mobile code, check `.agent/rules/mobile.md`.
