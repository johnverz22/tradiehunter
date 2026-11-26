# TradieHunter design systems

| Folder | Platform | Start here |
|---|---|---|
| [`mobile/`](mobile/README.md) | Flutter app (homeowner and tradie). Master tokens | `mobile/DESIGN_GUIDE.md` |
| [`web/`](web/README.md) | React admin dashboard. Inherits mobile tokens | `web/DESIGN_GUIDE.md` |

Colour, fonts, space, radii and motion are defined once in `mobile/tokens/tokens.json`; web extends it. Each system has its own gate:

```bash
node docs/design/mobile/tools/build.mjs --check
node docs/design/web/tools/build.mjs --check
```

## Common changes (mobile)

| I want to… | Do this |
|---|---|
| Change a colour, radius, spacing or font | Edit `mobile/tokens/tokens.json` → `node docs/design/mobile/tools/build.mjs` → commit the regenerated `th_tokens.dart` / CSS. The `--check` gate fails on stale output or contrast < 4.5:1. |
| Change a screen | Update the mockup in `mobile/mockups/index.html`, run `build.mjs`, then edit the Flutter screen in `mobile/lib/ui/<role>/` using `TH*` widgets and `context.th` colours only. |
| Add a component | Add the `TH*` widget to `lib/ui/design/th_widgets.dart`, a gallery entry, and a golden under `mobile/test/ui/goldens/`. |

The legacy v1.7 system is archived at `docs/archive/design-legacy-v1/`.
