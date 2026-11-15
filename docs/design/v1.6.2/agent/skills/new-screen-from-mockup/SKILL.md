---
name: new-screen-from-mockup
description: Scaffold a new Fixo/TradieHunter Flutter screen from a v1.6.2 HTML mockup frame using the design2flutter AST transpiler, then wire it into the app. Use when implementing any screen listed in docs/design/v1.6.2/html/frames-*.html or when a task says "build screen Hxx/Txx/Sxx".
---
# New screen from mockup

## Procedure
1. Locate the frame: `node tools/design2flutter/src/index.js --design docs/design/v1.6.2 --list | grep <prefix>`.
2. Read the frame's HTML AND the kit.css rules for every class it uses. Inline
   `style=` attributes are overrides — verify each one before porting.
3. Scaffold: `node tools/design2flutter/src/index.js --design docs/design/v1.6.2 --out /tmp/gen --frames <id>`.
4. Copy the generated file to `mobile/lib/views/<feature>/<name>_screen.dart`,
   rename the class to the real feature name, keep the provenance header.
5. Replace mock content with view-model bindings; replace
   `onPressed: () { /* TODO: wire action */ }` with router intents.
6. Swap `TH*` scaffolding for existing `Fixo*` widgets where equivalents exist
   (mapping table in AGENT_GUIDE §4). Implement missing `TH*` contracts once,
   in `mobile/lib/widgets/th_components.dart`.
7. Register the route in the app router.

## Acceptance checklist
- [ ] Zero raw colors/pixels — every value is a Space/Radii/Sizes/THType token.
- [ ] Renders correctly in light, dark AND outdoor (colors from THColors only).
- [ ] Long strings, 1.3x text scale, 360dp width: no overflow (audit F-04 lesson).
- [ ] Icon-only controls have tooltips/semantics; decorative art unlabeled.
- [ ] Orange budget respected (≤ 2: one CTA + one urgency).
- [ ] `dart format` + `flutter analyze` clean.

## Common pitfalls (from the v1.6.1 audit)
- Widget re-derives a size a token already has (appbar 72 vs `Sizes.appBar` 56).
- Back button shown only via `Navigator.canPop()` — screens reached by
  `context.go` lose it.
- `.faderow` implemented as a clipped Row — must be a horizontal ListView + fade.
- Badge rows in `Row(spaceBetween)` overflow — use `Wrap`.
- Primary CTA amber for every list item — one amber primary per screen.
