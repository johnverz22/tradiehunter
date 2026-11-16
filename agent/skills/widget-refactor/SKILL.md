---
name: widget-refactor
description: Extract, rename or refactor Fixo/TradieHunter Flutter widgets while keeping design-token discipline (no hardcoded colors/sizes, reuse Fixo* family, TH* contract for new components). Use when a build method grows past ~100 lines, a structure repeats 2+ times, or a review flags token violations.
---
# Widget refactor

## Procedure
1. Identify the target: duplicated structure (≥2 occurrences), build method
   > 100 lines, or a lint hit on hardcoded values.
2. Choose the home:
   - product-specific → `mobile/lib/widgets/fixo_<thing>.dart`, class `Fixo<Thing>`
   - design-system contract → `mobile/lib/widgets/th_components.dart`, class `TH<Thing>`
     (signature must match `tools/design2flutter/th_components.dart`).
3. Extract with tokens as parameters — never pixels the caller computed.
   Accept `THColors`/theme lookups inside the widget, not as parameters.
4. Update ALL call sites; run `rg "Color\(0x" mobile/lib` and
   `rg "fontSize: \d+_" mobile/lib` to prove no new hardcodes appeared.
5. If the structure also exists in mockups, update `tools/design2flutter/src/widgetMap.js`
   so the transpiler emits the new widget, then regenerate and diff:
   `node tools/design2flutter/src/index.js --design docs/design --out /tmp/gen`
6. `dart format` + `flutter analyze` + `flutter test`.

## Rules
- One widget per concern per file; private helpers `_buildXxx` stay in the screen.
- Props are semantic (label, kind, selected), not presentational (color, radius).
- A widget must work unchanged in light/dark/outdoor — theme branches inside a
  widget are allowed ONLY for the documented theme-invariant constants
  (THHeroGlass, THPalette) — never for palette colors.
- Never break the mapping table (docs/DESIGN.md §5) — extend it instead.
