# AGENT GUIDE — TradieHunter design system → Flutter

This guide is the single entry point for AI agents (Claude Code, Cursor,
Windsurf, Gemini CLI, OpenCode) working on TradieHunter mobile screens. It
covers the architecture, the token system, the mockup → Flutter workflow and
the hard rules that keep generated code consistent.

**Read this file fully before writing any Dart in `mobile/`.**

## 1. Where things live

| Path | What |
|---|---|
| `docs/design/v1.6.2/html/` | **Source of truth mockups** (12 files, 141 `[data-frame]` screens, light/dark/outdoor) |
| `docs/design/v1.6.2/html/kit.css` | Component vocabulary + theme swap (`.dark`/`.outdoor` re-map custom properties) |
| `docs/design/v1.6.2/tokens/` | `tokens.json`, `tokens.css`, `design_tokens.dart` (parity-checked) |
| `docs/design/v1.6.1/FIX_SPECIFICATION.md` | Audit F-101…F-118 + regression gates — read before touching mockups |
| `tools/design2flutter/` | AST transpiler (Node.js + parse5): HTML frames → token-mapped Dart |
| `tools/design2flutter/output/` | Generated `*_screen.dart` files (scaffolds, not final screens) |
| `mobile/lib/theme/design_tokens.dart` | `Space`, `Radii`, `Sizes`, `THColors` (light/dark/outdoor ThemeExtension) |
| `mobile/lib/widgets/fixo_*.dart` | Existing widget family — **reuse before creating** |
| `agent/skills/` | Reusable agent skills (new screen, refactor, UI audit) |
| `agent/prompts/` | Prompt templates for the workflows above |

App identity: **Fixo** (product) by TradieHunter (company). Job ids look like
`FIXO-2481-JB`. Two roles: homeowner (H-frames) and tradie (T-frames), plus
shared auth (S), empty/error states (E), components (cmp-) and iPad layouts
(IPAD-).

## 2. Architecture at a glance

```
docs/design/v1.6.2 (HTML mockups, tokens)
        │  tools/design2flutter (parse5 AST → widget specs → Dart)
        ▼
mobile/lib/views/** (screens) ── mobile/lib/widgets/fixo_*.dart (components)
        │                                   │
        └───────── mobile/lib/theme/design_tokens.dart (Space/Radii/Sizes/THColors/THType)
```

- **One screen widget per frame.** Dark/outdoor are NOT separate widgets —
  they are the same widget with `THColors` swapped by `Theme`.
- **Screens compose widgets; widgets read tokens.** No screen imports a raw
  color, and no widget re-derives a size a token already has.
- **Mockup class vocabulary maps 1:1 to a widget.** `.appbar` → `FixoAppBar`,
  `.faderow` → scrolling chip row, `.badges` → `Wrap`, `.pill*` → `THStatusPill`
  kinds, etc. (full table in §4).

## 3. Design token mappings (CSS → Dart)

### Colors — ALWAYS through THColors

| CSS (kit.css var) | Dart (`theme = context.thColors`) |
|---|---|
| `--paper` | `theme.paper` |
| `--surface` / `--surface-2` | `theme.surface` |
| `--line` | `theme.line` |
| `--text` / `--text-soft` / `--text-brand` | `theme.text` / `theme.textSoft` / `theme.textBrand` |
| `--brand` / `--on-brand` | `theme.brand` / `theme.onBrand` |
| `--accent-text` | `theme.accentText` |
| `--success-text` / `--danger-text` | `theme.success` / `theme.danger` |
| `--tint-brand` / `--track` | `theme.tintBrand` / `theme.track` |
| `--av-tradie` / `--on-av-tradie` | `theme.avTradie` / `theme.onAvTradie` |

Raw palette (`--navy`, `--amber`, `--blue300`…) is **constant** and lives in
`THPalette`; use it only where the spec marks a value theme-invariant (e.g.
hero glass: heroes are navy in every theme — `THHeroGlass.soft/faint/track`).

**Never** write `Color(0xFF193957)` in a view. If a token is missing, add it
to `mobile/lib/theme/design_tokens.dart` AND `tokens.json` AND `kit.css`
(they are kept in parity), then use it.

### Spacing — the 4px grid (`Space`)

`Space.s1=4, s2=8, s3=12, s4=16, s5=20, s6=24, s7=32, s8=40`. The 20px screen
gutter is **`Space.gutter`**, not `Space.s5` (same value, different meaning).
Off-grid values compose: `3 * Space.s1`.

### Radii (`Radii`) and sizes (`Sizes`)

`Radii.card=20, control=14, tile=16, sheet=28, pill=999`.
`Sizes.tapMin=48, button=56, buttonSecondary=52, input=56, nav=68, appBar=56,
fab=56; avatar sm=36, md=44, lg=72, xl=88`.

### Typography (`THType`)

| CSS | Token |
|---|---|
| Space Grotesk 700/40 | `THType.hero` |
| Space Grotesk 700/28 | `THType.display` |
| Space Grotesk 600/20 | `THType.section` |
| IBM Plex Sans 600/18 | `THType.cardTitle` |
| IBM Plex Sans 700/24 | `THType.price` |
| IBM Plex Sans 400/16 | `THType.body` |
| IBM Plex Sans 400/14 | `THType.secondary` |
| IBM Plex Sans 500/12 | `THType.caption` (12px floor — nothing smaller ships) |
| IBM Plex Mono 500/13 | `THType.mono` |

## 4. Component mapping table

| Mockup (kit.css) | Flutter | Exists? |
|---|---|---|
| `.appbar` / `.back` / `.ico-btn` | `FixoAppBar` / `FixoBackButton` / `FixoAppBarAction` | yes |
| `.btn.btn-primary/.tonal/.ghost` | `FixoPrimaryButton` / `FixoTonalButton` / `FixoGhostButton` | yes |
| `.card` / `.tile` / `.list-group` | `FixoCard` / `FixoCard(radius: Radii.tile)` / `THListGroup` | card yes |
| `.av` (`.vbdg`) | `FixoAvatar` (verified badge) | yes |
| `.wordmark` | `FixoWordmark` | yes |
| `.pill.pill-{action,active,waiting,done,muted,problem}` | `THStatusPill(kind: …)` | contract |
| `.badge` (26px label) | `THBadge` | contract |
| `.chip` (40dp filter, 48dp hit) | `THFilterChip` | contract |
| `.faderow` | `THFadeRow` (horizontal ListView + 32px fade + snap) | contract |
| `.badges` | `Wrap(spacing: Space.s2, runSpacing: Space.s2)` | — |
| `.spread` | `Row(spaceBetween)`; long text children wrapped in `Expanded` | — |
| `.stack{,8,16,20}` | `Column(spacing: Space.s3/s2/s4/gutter)` | — |
| `.heroband` / `.maphead` / `.status-strip` | `THHeroBand` / `THMapHeader` / `THStatusStrip` | contract |
| `.cpb` (step progress) | `THStepProgress` | contract |
| `.countdown` (urgent) | `THCountdown` | contract |
| `.field`/`.input`/`.otp` | `THField`/`THInput`/`THOtpInput` | contract |
| `.seg48 .o` | `THSegmented` | contract |
| `.bubble`/`.composer`/`.msgrow` | `THChatBubble`/`THComposer`/`THMessageRow` | contract |
| `.navbar`/`.rail` + `.fab` | `THNavBar` + FAB | contract |

"Contract" = signature defined in `tools/design2flutter/th_components.dart`;
implement in `mobile/lib/widgets/th_components.dart` on first use (or map to
an existing Fixo widget and update the transpiler rule).

## 5. Workflow A — build a new screen from a mockup

1. **Find the frame.** `node tools/design2flutter/src/index.js --design
   docs/design/v1.6.2 --list | grep <Hxx|Txx|Sxx>`; open the frame in the HTML
   and read the `kit.css` rules for every class it uses. Inline `style=`
   attributes are overrides — usually one-offs; check before copying.
2. **Generate the scaffold.** `node tools/design2flutter/src/index.js --design
   docs/design/v1.6.2 --out tools/design2flutter/output --frames H13` then copy
   the file into `mobile/lib/views/<feature>/` and rename the class properly.
3. **Wire the real data.** Replace mock text with view-model bindings; replace
   `onPressed: () { /* TODO: wire action */ }` with navigation/intent calls
   via `context.go` (go_router).
4. **Swap scaffold components for real ones** where they exist (Fixo* family).
   Keep the token discipline of the scaffold.
5. **Stress-test:** long strings, `1.3x` text scale, 360dp width. A 402dp
   mockup with short labels hides overflows — this is audit finding F-04's
   lesson.
6. **Dark + outdoor:** run all three; colors must come right purely from
   `THColors` swaps. If a color needs an `if (dark)` in the view, you used a
   raw token (see F-104/F-105).
7. **Cross-check against the run screenshot** with the `design-vs-run-crosscheck`
   skill (docs/design/v1.6.1/skills/).

## 6. Workflow B — refactor / extract a widget

1. Spot repetition ≥ 2 or a build method > 100 lines.
2. Extract to `mobile/lib/widgets/`, name `Fixo<Thing>` (product family) or
   `TH<Thing>` (design-system contract), one widget per file concern.
3. Parameters are tokens/theme values, never pixels the caller computed.
4. Run the mockup-html-qa audit (below) if the change touches mockups.

## 7. Workflow C — run the automated UI audit

```bash
python3 docs/design/v1.6.2/tools/audit_full.py docs/design/v1.6.2 /tmp/audit.json
```

Gates (all must pass, see FIX_SPECIFICATION §4): no screen-frame contrast
failures, no sub-12px text, no undefined classes/vars, no unlabeled icon
buttons, no missing `alt`, orange budget ≤ 2 per screen (a countdown widget
counts as one), IPAD master-detail 0px overflow.

## 8. Hard rules (enforced by .cursorrules / .windsurfrules / CLAUDE.md)

1. Tokens only — no `Color(0x…)`, no raw dp literals where a token exists.
2. Reuse `Fixo*` widgets before creating new ones; new widgets go in
   `mobile/lib/widgets/` and follow the naming table above.
3. One amber primary CTA + at most one urgency element per screen.
4. Green = verified/done only; red = problem/dispute only; selection is
   2px brand border + brand tint + check, never amber.
5. 12px minimum text; 48dp minimum hit target (chips may draw 40dp with a
   48dp hit area).
6. `.faderow` semantics: horizontal scroll + fade — never a clipped Row.
7. Trust/credential rows wrap (`Wrap`), never `spaceBetween`.
8. Dark mode = token swap; a theme `if` inside a view is a bug.
9. Generated files (`// GENERATED` header) are regenerated, never hand-patched;
   fix the transpiler or the mockup instead.
10. After any mockup change: run the audit (§7); after any Dart change:
    `dart format` + `flutter analyze` + `flutter test`.

## 9. Setup

```bash
./agent/setup.sh            # installs node+py deps, runs audit + transpiler + smoke
make -C agent audit         # design audit only
make -C agent transpile     # regenerate Dart scaffolds
make -C agent check         # structural lint of generated Dart
make -C agent flutter       # dart format + flutter analyze + test (needs Flutter SDK)
```
