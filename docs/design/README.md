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

The legacy v1.7 system is archived at `docs/archive/design-legacy-v1/`.
