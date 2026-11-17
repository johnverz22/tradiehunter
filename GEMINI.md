# GEMINI.md — Fixo project rules

Antigravity-specific overrides. Read alongside `AGENTS.md` (shared rules); this file takes priority for Antigravity sessions only.

## Autonomy profile
Recommended: **Review-driven development** — balanced autonomy with checkpoints. This project touches payment-adjacent flows (deferred to V1.1) and auth, so avoid Agent-driven (minimal-review) mode once those areas are in scope.

## Context to load first
1. `docs/PRD.md`
2. `docs/MVP.md`
3. `docs/ARCHITECTURE.md`
4. `.agent/rules/*.md` for area-specific detail (backend/frontend/mobile)

## Project-specific notes
- Design tokens live in `docs/design/mobile/tokens/tokens.json` — the single source of truth for colour, type, spacing and motion. For v2 mobile UI, the visual source of truth is `docs/design/mobile/mockups/index.html` (30 screens, light + dark); read `docs/DESIGN.md` for the full design contract (component vocabulary, CTA placement, feedback notices). Preserve marketplace behavior and functional/data gates; do not fabricate missing data. Both light and dark themes are required.
- Backend `dotnet` is NOT installed on the host — always run `dotnet` inside the API container (OrbStack): `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"`. See `.agent/rules/backend.md` for details.
- When generating backend code, check `.agent/rules/backend.md` for .NET conventions before writing.
- When generating web code, check `.agent/rules/frontend.md`.
- When generating mobile code, check `.agent/rules/mobile.md`.
- **No hardcoded values in mobile UI code.** All spacing, radii, font sizes, font weights, colors, alpha tints, durations, letter spacing, shadows, and component sizes must come from token classes in `mobile/lib/theme/design_tokens.dart` (`Space`, `Radii`, `Sizes`, `THType`, `THColors`, `Durations`). Access colours via `context.th.<name>`. Never write raw numeric literals or `Color(0x...)` in view/widget files. If a needed token doesn't exist, add it to `design_tokens.dart` and `docs/design/mobile/tokens/tokens.json`. Reusable `TH*` widgets (`THAppBar`, `THButton`, `THCard`, `THBadge`, `THNotice`, etc.) must be used instead of re-inlining the same container-decoration patterns.
