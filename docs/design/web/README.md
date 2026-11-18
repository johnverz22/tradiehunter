# TradieHunter web design v1 (Trust Navy + Gold, admin)

Design system for the React admin (`web/`). It inherits the mobile v2 palette, fonts, space and radii and adds web-only roles, a hand-written component kit and 18 generated frames, so mobile and web cannot drift.

```
tokens/tokens.json           web layer: extends ../mobile/tokens/tokens.json (=path and @alias references)
tokens/tokens.css            GENERATED  CSS variables, light + dark, type classes
tokens/theme.css             GENERATED  Tailwind v4 @theme mapping and t-* utilities
tokens/tokens.resolved.json  GENERATED  every resolved value, for tooling
tokens/contrast-report.txt   GENERATED  WCAG gate results (47 text + 16 non-text pairs per theme)
fonts/                       self-hosted woff2 (Lexend, Source Sans 3; latin + latin-ext) and OFL licences
fonts/fonts.css              GENERATED  @font-face rules
css/kit.css                  hand-written component kit (tokens only, linted)
ast/dsl.mjs                  node builders + STATUS tone map
ast/screens.mjs              18 admin frames as AST (14 screens + 4 responsive)
ast/sheet.mjs                component sheet definition
ast/screens.ast.json         GENERATED  the AST as JSON
mockups/index.html           GENERATED  screen gallery (light / dark / both, zoom)
mockups/system.html          GENERATED  foundations + every component state
mockups/frames/*.html        GENERATED  one page per frame (iframes in the gallery, so media queries are real)
tools/build.mjs              generator and gate (Node 18+, no dependencies)
DESIGN_GUIDE.md COLOUR.md TYPOGRAPHY.md COMPONENTS.md
```

```bash
node tools/build.mjs          # generate
node tools/build.mjs --check  # CI gate
```

Open `mockups/index.html` (needs the `frames/` folder next to it). `web/src` runs this system: `web/src/theme/` and `web/public/fonts/` are copies kept in sync by `npm run design:sync` and checked by `npm run design:check` (see `DESIGN_GUIDE.md` §10).
