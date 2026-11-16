# design2flutter — HTML mockup → Flutter widget transpiler

AST pipeline that turns the TradieHunter design mockups
(`docs/design/html/frames-*.html`, 141 `[data-frame]` screens) into
token-mapped Flutter widget code.

```
HTML ─parse5→ DOM AST ─parse.js→ normalised frame trees
     ─widgetMap.js→ widget specs (kit.css class rules)
     ─emit.js→ Dart (Space/Radii/Sizes/THType/THColors tokens only)
```

## Quick start

```bash
npm install                # parse5 only
node src/index.js --design ../../docs/design --out output
node src/index.js --check output        # structural lint (balance, no raw hex, no HTML)
node test/smoke.js                     # end-to-end proof on the real mockups
```

Options: `--frames H07,T21` restricts to frame-id prefixes; `--list` prints
frames without generating.

## What it guarantees

- **Tokens only.** Every spacing/radius/size/color emitted as `Space.*`,
  `Radii.*`, `Sizes.*`, `THType.*`, `THColors.*` / `Fixo*` widget params.
  Raw `Color(0x…)` literals fail the lint. Off-grid values are composed from
  tokens (`3 * Space.s1`), never invented.
- **Reuse before create.** Elements map to the repo's existing widget family
  first (`FixoAppBar`, `FixoBackButton`, `FixoPrimaryButton`, `FixoTonalButton`,
  `FixoGhostButton`, `FixoCard`, `FixoAvatar`, `FixoWordmark`, `FixoEmptyState`);
  components that don't exist yet emit `TH*` names — see `th_components.dart`
  for the reference implementation contract and the component table in docs/DESIGN.md §5.
- **Theme-correct by construction.** One widget per frame; dark/outdoor are the
  same code — colors resolve through `Theme.of(context).extension<THColors>()`.
- **Provenance.** Every file header names the source frame and mockup geometry.
  `onPressed` stubs are explicit `() { /* TODO: wire action */ }`.
- **A11y carried over.** `aria-label` → widget `label`/tooltip; `alt=""` →
  no semantic label; labelled `alt` → `semanticLabel`.

## Mapping highlights (kit.css → Flutter)

| Mockup | Flutter | Note |
|---|---|---|
| `.faderow` | `THFadeRow` | horizontal `ListView` + 32px fade, snap — never a clipped `Row` |
| `.badges` | `Wrap` | trust rows wrap; never `spaceBetween` |
| `.spread` | `Row(spaceBetween)` | children get `Expanded` when text can grow |
| `.pill`/`.chip`/`.badge` | `THStatusPill`/`FixoFilterChip`/`THBadge` | interactive vs label distinction preserved |
| `.heroband`/`.maphead` | `THHeroBand`/`THMapHeader` | navy in all themes; glass via `THHeroGlass` constants |
| `.seg.on` inline overrides | deleted in the v1.6.2 design pass | the audit found these broke dark mode |
| 20px gutter | `Space.gutter` | not `Space.s5` |
| hero glass rgba | `THHeroGlass.*` | theme-invariant constants (heroes stay navy) |

## Limits (by design)

- Layout-only scaffolding: navigation, state and data wiring are TODO stubs.
- `dart format`/`flutter analyze` should run in the mobile project after
  copying files in (`make flutter-format` in the bundle root).
- Complex bespoke compositions (map pins, custom histograms) emit their text
  content and structure; treat those subtrees as manual port checklists.

## Files

- `src/parse.js` — parse5 AST walk, frame extraction, icon/style enrichment
- `src/widgetMap.js` — ordered class→widget rules (first match wins)
- `src/tokens.js` — CSS value → Dart token expressions
- `src/emit.js` — Dart rendering, quoting, token lint values
- `src/index.js` — CLI + structural Dart lint
- `test/smoke.js` — end-to-end proof (PoC: H07, H12, T21, S05, IPAD-messages)
- `th_components.dart` — reference contract for the `TH*` widgets
