# TradieHunter Design System Bundle — v1.6.1

AI-ready integration bundle for the TradieHunter / Fixo mobile app. Produced
from the v1.6.1 design-system audit; contains the corrected design artifacts,
the HTML-to-Flutter AST transpiler, and the complete agent tooling package.

## Contents

| Path | What |
|---|---|
| `FIX_SPECIFICATION.md` | Audit of `docs/design/v1.6.1` — findings F-101…F-118, remediations, regression gates, verification results |
| `design/v1.6.2/` | **Corrected design artifacts** (drop-in replacement for v1.6.1): 12 HTML mockup files (141 frames, light/dark/outdoor), `kit.css`, `tokens/` (json + css + dart parity), `fonts/`, `assets/`, `tools/` (audit + idempotent fix script), `docs/` |
| `tools/design2flutter/` | **HTML → Flutter AST transpiler** (Node.js + parse5): `src/` (parse, widgetMap, tokens, emit, CLI), `test/smoke.js` (end-to-end proof), `th_components.dart` (widget contract), `output/` (141 generated scaffolds) |
| `agent/AGENT_GUIDE.md` | Architectural overview, full CSS→Dart token mappings, component mapping table, step-by-step workflows (new screen / refactor / audit) |
| `agent/skills/` | Three reusable skills with runnable scripts: `new-screen-from-mockup`, `widget-refactor`, `ui-audit` |
| `agent/prompts/` | Prompt templates for the three workflows |
| `agent/setup.sh`, `agent/Makefile` | One-shot setup + make targets (audit / transpile / check / smoke / flutter) |
| `rules/.cursorrules`, `rules/.windsurfrules`, `rules/CLAUDE.md` | Strict coding conventions, widget naming standards, token enforcement, prohibitions |
| `package.json` | npm entry points for the whole toolchain |

## Install (into the repository root)

```bash
unzip tradiehunter-design-system-v1.6.1-bundle.zip -d bundle
cp -r bundle/design/v1.6.2 docs/design/            # corrected artifacts
cp -r bundle/tools/design2flutter tools/            # transpiler
cp -r bundle/agent agent/                           # agent bundle
cp bundle/rules/.cursorrules bundle/rules/.windsurfrules .
cp bundle/rules/CLAUDE.md .
cp bundle/package.json .
cp bundle/FIX_SPECIFICATION.md docs/design/v1.6.1/
bash agent/setup.sh                                 # verify everything end-to-end
```

## Quick verification (from the repo root)

```bash
bash agent/setup.sh          # deps + audit gates + transpile + lint + smoke
make -C agent verify         # same, via make
npm run audit                # design audit only
npm run transpile            # regenerate Flutter scaffolds
```

Expected: **7/7 audit gates PASS**, **141 screens generated, 0 skipped**,
**SMOKE PASS**. Flutter-side checks (`make -C agent flutter`) need the
Flutter SDK: `dart format`, `flutter analyze`, `flutter test`.

## What was fixed (summary)

Critical: iPad master-detail 122px overflow + phantom status-bar column;
dark-mode status-strip pills (1.33:1). High: dark stat tiles (1.22/2.24:1),
dark `pill-problem` (2.67:1), 29 inline segment overrides killing dark
progress. Medium: outdoor line-token typo (pink→navy), class fragmentation
across files, 44dp tap targets, 16 unlabeled icon buttons, 88 images without
alt, orange-budget violations. Low: focus-visible, inline color tokenisation,
annotation 12px floor, dark avatar ink. Full detail with evidence and
verification tables: `FIX_SPECIFICATION.md`.

## Requirements

Node ≥ 18 (parse5), Python 3 with beautifulsoup4 + playwright (chromium) for
the audit. Flutter SDK only for the optional mobile-side targets.
