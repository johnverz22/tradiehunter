# TradieHunter design v2 (Trust Navy + Gold)

Tokens and a screen AST generate the Flutter code and the HTML mockups, so design and code cannot drift.

```
tokens/tokens.json         source of truth (light + dark, type, space, radii, sizes)
tokens/design_tokens.dart  GENERATED  Space, Radii, Sizes, THType, THColors, THTheme
tokens/tokens.css          GENERATED  CSS variables for the mockups
tokens/contrast-report.txt GENERATED  WCAG AA gate results
ast/dsl.mjs                node builders (the AST vocabulary)
ast/screens.mjs            31 screens as AST (homeowner, tradie, shared)
ast/screens.ast.json       GENERATED  the AST as JSON, for any other consumer
flutter/th_widgets.dart    hand-written component library
flutter/screens/*.dart     GENERATED  one StatelessWidget per screen + route table
mockups/index.html         GENERATED  long-form light and dark mockups
tools/build.mjs            the generator (Node 18+, no dependencies)
DESIGN_GUIDE.md            the design guide
```

```bash
node tools/build.mjs          # generate
node tools/build.mjs --check  # CI gate
```

Read `DESIGN_GUIDE.md` section 10 to integrate into `mobile/lib`.
