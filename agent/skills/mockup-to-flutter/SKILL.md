---
name: mockup-to-flutter
description: Build or fix a TradieHunter Flutter screen from an HTML mockup frame in docs/design/html (kit.css classes such as .appbar, .pill, .chip, .faderow, .sticky, .heroband, .btn-tile), scaffolding with the design2flutter transpiler and mapping to Fixo* widgets and design tokens. Use for "build screen Hxx/Txx/Sxx", for fixing a screen that differs from its mockup, or when a run screenshot deviates from the frame.
---
# Mockup → Flutter

Frames are the visual source of truth (see `docs/DESIGN.md`). Mockups that are wrong get built wrong: run the `mockup-html-qa` skill first if the frame looks off.

## Procedure
1. Locate the frame: `node tools/design2flutter/src/index.js --design docs/design --list | grep <prefix>` (or `bash agent/skills/mockup-to-flutter/scripts/new-screen.sh H13 chat`).
2. Read the frame HTML **and the kit.css rules for every class it uses**. Inline `style=` attributes are overrides, usually one-offs or bugs: verify each before porting. Do not eyeball pixels.
3. Scaffold: `node tools/design2flutter/src/index.js --design docs/design --out /tmp/gen --frames <id>`; copy to `mobile/lib/views/<feature>/<name>_screen.dart`, rename the class, keep the provenance header. Generated scaffolds are starting points, never patched in place.
4. Map classes with `references/css-to-flutter.md`; reuse `Fixo*` widgets (`FixoAppBar`, `FixoCard`, `FixoPrimaryButton`, `StatusBadge`, …) before writing new ones. Missing `TH*` contracts are implemented once in `mobile/lib/widgets/th_components.dart`.
5. Every number is a token (`Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `Tracking`, `THColors`, `DesignTokens`). A missing token is added to `design_tokens.dart`, `tokens.json` and `kit.css` together. No `Color(0x…)` or magic numbers.
6. Wire real data through view models and router intents; replace `/* TODO: wire action */`. Register the route in `app_router.dart`.
7. Stress test: long strings, 1.3× and 2.0× text scale, 320/360 dp width, light + dark + outdoor (dark is a token swap, never an `if` in a view).
8. Compare with the run screenshot using `design-vs-run-crosscheck`.

## Acceptance
- [ ] Zero raw colours/pixels · [ ] no overflow at the stress sizes · [ ] icon-only controls have semantics/tooltips · [ ] ≤ 2 amber elements (one CTA + one urgency) · [ ] truthful data: never invent ratings, badges, earnings, distances or contact details · [ ] server state machine untouched (display mapping only) · [ ] `dart format`, `flutter analyze`, `flutter test` clean.

## Failure patterns seen before
- Widget re-derives a size a token has (appbar 72 vs `Sizes.appBar` 56).
- Back button shown only via `Navigator.canPop()`; screens reached by `context.go` lose it.
- `.faderow` built as a clipped `Row` (must be a horizontal `ListView` + fade); badge rows in `Row(spaceBetween)` (use `Wrap`); text in a `Row` without `Expanded`.
- Primary CTA amber on every list item (one amber primary per screen); icon swapped (paper plane → arrow).
- Recipes in `references/recipes.md` were never compiled: run `flutter analyze`.
