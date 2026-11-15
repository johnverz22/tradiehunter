# CLAUDE.md — working on TradieHunter / Fixo

Read `agent/AGENT_GUIDE.md` before touching mobile/ or docs/design/. This file
is the quick contract; the guide has the full token tables and workflows.

## Project map

- `mobile/` — Flutter app (Fixo). Views in `lib/views/**`, widgets in
  `lib/widgets/fixo_*.dart`, tokens in `lib/theme/design_tokens.dart`.
- `docs/design/v1.6.2/` — design source of truth: HTML mockups (141 frames,
  `[data-frame]`), `html/kit.css` component vocabulary, `tokens/` parity files.
- `docs/design/v1.6.1/FIX_SPECIFICATION.md` — the audit (F-101…F-118) and the
  regression gates every mockup change must pass.
- `tools/design2flutter/` — HTML→Flutter AST transpiler (Node + parse5).
  Scaffold screens with it; never hand-copy pixel values from mockups.
- `agent/` — this bundle: guide, skills, prompts, setup scripts.

## Non-negotiables

1. **Tokens only.** Colors via `Theme.of(context).extension<THColors>()!`;
   spacing `Space.*` (gutter = `Space.gutter`); radii `Radii.*`; sizes
   `Sizes.*`; type `THType.*` (12px floor). No `Color(0x…)`, no magic numbers.
   Missing token → add to design_tokens.dart + tokens.json + kit.css together.
2. **Reuse before create.** FixoAppBar/BackButton/PrimaryButton/TonalButton/
   GhostButton/Card/Avatar/Wordmark/EmptyState exist. New widgets follow the
   `TH*` contract in tools/design2flutter/th_components.dart.
3. **Dark mode is a token swap.** The same screen renders light/dark/outdoor;
   a theme conditional inside a view is a bug.
4. **Brand budget.** Max 2 orange elements per screen (primary CTA + one
   urgency). Green = verified/done, red = problem/dispute, selection = brand
   border + tint + check (never amber). 48dp hit targets.
5. **Mockup semantics are binding.** `.faderow` = scrolling chips + fade;
   `.badges` = Wrap; `.spread` = spaceBetween with Expanded text.
6. **Generated files** (`// GENERATED` header) are regenerated, not patched.

## Workflows

- New screen: `node tools/design2flutter/src/index.js --design
  docs/design/v1.6.2 --out out --frames <id>` → copy into views/, wire data,
  stress-test (long text, 1.3x scale, 360dp, all themes).
- UI audit: `python3 docs/design/v1.6.2/tools/audit_full.py docs/design/v1.6.2
  /tmp/audit.json` — gates in FIX_SPECIFICATION §4.
- Full setup: `./agent/setup.sh` or `make -C agent <audit|transpile|check|flutter>`.

## Before committing

`make -C agent audit` green · `dart format` · `flutter analyze` clean ·
`flutter test` green. For mockup changes also re-run the audit and commit
regenerated `build/`/`frames/`.
