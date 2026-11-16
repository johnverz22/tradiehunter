# TradieHunter — Design System

Visual and interaction source of truth for the Flutter app. Web (React admin) is excluded from this doc. Layout and behaviour contracts are in [SPECS §10](SPECS.md#10-mobile-ux-contract-v15--v16); this file covers tokens, components, tooling and feedback. Current system version: **v2.0.0** (Trust Navy + Gold — Lexend + Source Sans 3).

## 1. Source of truth

| Path | What |
|---|---|
| `docs/design/tokens/tokens.json` | **Master source of truth.** Light + dark colour, type, space, radii, size, motion |
| `docs/design/tokens/tokens.css` | Generated CSS variables for mockups |
| `docs/design/tokens/design_tokens.dart` | Generated Dart: `Space`, `Radii`, `Sizes`, `THType`, `THColors`, `THTheme` |
| `docs/design/tokens/contrast-report.txt` | WCAG AA gate results (38 pairs, all passing) |
| `docs/design/DESIGN_GUIDE.md` | Canonical human-readable design guide (§1–§12) |
| `docs/design/COLOUR.md` | Colour token table, contrast summary, pairing rules |
| `docs/design/TYPOGRAPHY.md` | Type scale, font families, `pubspec.yaml` font setup |
| `docs/design/COMPONENTS.md` | Component vocabulary, v1→v2 widget mapping, screen inventory |
| `docs/design/flutter/th_widgets.dart` | Hand-written component library (~1,040 lines) |
| `docs/design/flutter/screens/` | Generated screen widgets (30 screens + route table) |
| `docs/design/mockups/index.html` | Generated light + dark HTML mockups (visual reference) |
| `docs/design/ast/screens.mjs` | 30 screen definitions (AST) |
| `docs/design/tools/build.mjs` | Generator pipeline (Node 18+, no deps) |
| `mobile/lib/theme/design_tokens.dart` | Dart tokens consumed by the app (copy from `docs/design/tokens/`) |

> [!NOTE]
> Brand assets (wordmarks, app icon, map pins, notification icon) are archived at `docs/archive/design-legacy-v1/assets/brand/` pending a formal v2 brand pass. Illustrations and textures are in the same archive. Do not copy from there for new UI work without owner sign-off.

## 2. Art direction

*Trust Navy + Gold.* Structured, authoritative navy paired with a single warm gold CTA. Dark is a first-class theme, not an inversion.

| Principle | Rule |
|---|---|
| Trust first | Navy carries structure. Verified and Insured badges always visible on a tradie. Money always labelled incl. GST and NZD. |
| One gold action | `accent` (gold) is the single primary CTA per screen. `brand` (navy) is for secondary filled actions. |
| Money is loudest | Final amounts use `moneyLg` on a hero card. |
| Long screens | Screens scroll. Primary actions live in the sticky bar, never below the fold. |
| Dark first-class | Brand lightens to periwinkle in dark; gold lightens; surfaces step up in blue-black. Not an inversion. |

## 3. Colour

See [COLOUR.md](design/COLOUR.md) for the full token table, contrast results and pairing rules.

Colours are accessed via `context.th.<name>` (Flutter) or `var(--<name>)` (CSS). **Never hardcode hex.** The build enforces WCAG AA (4.5:1) for all 19 text/background pairs per theme — `node docs/design/tools/build.mjs --check` fails if any pair regresses.

## 4. Typography

See [TYPOGRAPHY.md](design/TYPOGRAPHY.md) for the full type scale and `pubspec.yaml` setup.

Fonts: **Lexend** (headings, money, controls) and **Source Sans 3** (body). Bundled as assets in `pubspec.yaml` (not `google_fonts`). Minimum text size: 11 px (`label`). Respect text scaling to 2.0.

## 5. Space, shape, size

4pt scale: `s1` 4, `s1_5` 6, `s2` 8, `s2_5` 10, `s3` 12, `s3_5` 14, `s4` 16, `s5` 20, `s6` 24, `s7` 32, `s8` 40, `s9` 48.

| Token class | Key values |
|---|---|
| `Radii` | control 16, tile 18, card 20, hero 28, sheet 32, pill 999 |
| `Sizes` | button 54 (sm 44), input 56, tap min 44, dock 68, fab 56, stickyClearance 96, dockClearance 120 |

Screen gutter: 20. Elevation: cards use a two-layer soft shadow in light and a 1 px border only in dark. Hero cards use the gradient and a gold glow circle. No other shadows. Motion: 150 / 220 / 320 ms (`THDurations.fast/base/slow`).

## 6. Component vocabulary

See [COMPONENTS.md](design/COMPONENTS.md) for the full component table, v1→v2 widget mapping, and screen inventory.

| v2 widget | Role |
|---|---|
| `THButton(kind: accent)` | The one gold CTA per screen |
| `THButton(kind: primary)` | Secondary filled actions (navy) |
| `THAppBar` | Screen app bar |
| `THCard` | Cards |
| `THHero` | Hero card (navy gradient + gold eyebrow + large figure) |
| `THDock` | Bottom nav. HO gets FAB with `THHuntGlyph`; tradie does not |
| `THStickyBar` | Glass sticky action bar above home indicator |
| `THBadge` / `THProgress` | Status badges and job-lifecycle progress |

## 7. Feedback notices

All transient feedback uses `THNotice` (renamed from `FixoNotice` in v2). No `ScaffoldMessenger.showSnackBar`. Strings live in `mobile/lib/feedback/notice_copy.dart`.

| Tone | Method | Auto-dismiss |
|---|---|---|
| info | `THNotice.info` | 3 s |
| success | `THNotice.success` | 3 s |
| warning | `THNotice.warning` | 4 s |
| error | `THNotice.error` | 5 s |
| push | `THNotice.push(title, body, onTap)` | 5 s |

Architecture: `THNoticeHost` → `THNoticeController` (Riverpod `StateNotifier`) → `THNotice` static façade. Debug gallery at `/debug/notice-gallery`.

## 8. Regression gates (design changes must pass)

```bash
node docs/design/tools/build.mjs --check
```

This runs:
1. Contrast gate — 19 text/background pairs per theme at WCAG AA (4.5:1). Fails build if any pair regresses.
2. Stale-output check — regenerated tokens, Dart and HTML must match committed files.
3. Unknown-node check — every AST node type must have a registered builder.

After passing the build gate:
- `flutter analyze` clean
- `flutter test` green
- Visual QA against `docs/design/mockups/index.html` (light + dark)

## 9. Build pipeline

```bash
# From docs/design/
node tools/build.mjs          # regenerate tokens, Flutter, HTML
node tools/build.mjs --check  # CI gate: contrast + stale-output + unknown nodes
```

Requires Node ≥ 18. No other dependencies.

**Change a colour/size:** edit `tokens/tokens.json`, rebuild. Contrast gate tells you if accessibility broke.
**Change a screen:** edit `ast/screens.mjs`, rebuild, review `mockups/index.html`, commit generated files.
**Add a widget:** add to `ast/dsl.mjs`, register in `tools/build.mjs`, add to `flutter/th_widgets.dart`.
