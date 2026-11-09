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
- Design tokens live in `docs/design/design-system.html` — treat it as the source of truth for color, type, and spacing, not a static reference image. For v1.7 mobile UI, the visual source of truth is `docs/design/v1.6/html/frames-homeowner.html` and `docs/design/v1.6/html/frames-tradie.html`; read `docs/design/v1.6/docs/HANDOFF.md` for the full design contract (icon rules, inline SVG patterns, CTA placement, component patterns). Mockups are excluded: do not match, update or replace them. Preserve marketplace behavior and functional/data gates; do not fabricate missing data. Both light and dark themes are required. This direction supersedes legacy mockup-matching instructions.
- Backend `dotnet` is NOT installed on the host — always run `dotnet` inside the API container (OrbStack): `docker compose run --rm --entrypoint /bin/bash api -c "dotnet <command>"`. See `.agent/rules/backend.md` for details.
- When generating backend code, check `.agent/rules/backend.md` for .NET conventions before writing.
- When generating web code, check `.agent/rules/frontend.md`.
- When generating mobile code, check `.agent/rules/mobile.md`.
- **No hardcoded values in mobile UI code.** All spacing, radii, font sizes, font weights, colors, alpha tints, durations, letter spacing, shadows, and component sizes must come from token classes in `mobile/lib/theme/design_tokens.dart` (`Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `Durations`, `Tracking`, `THColors`). Never write raw numeric literals or `Color(0x...)` in view/widget files. See `mobile/HARDCODED_AUDIT.md` for the full audit. If a needed token doesn't exist, add it to `design_tokens.dart` rather than inlining the value. Reusable widgets (`FixoAppBar`, `FixoPrimaryButton`, `FixoCard`, `StatusBadge`, etc.) must be used instead of re-inlining the same container-decoration patterns.
