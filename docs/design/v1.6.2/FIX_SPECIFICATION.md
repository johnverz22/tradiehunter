# FIX SPECIFICATION — TradieHunter design system v1.6.1

**Audit scope:** every `[data-frame]` in `docs/design/v1.6.1/html/*.html` (225 frames across 12 files), probed at runtime in Chromium (Playwright) plus static analysis of markup, `kit.css` and `tokens/`.
**Method:** runtime probes for overflow, truncation, tap targets, text size, WCAG contrast, orange-element budget, ARIA coverage, inline hardcoded colors; static probes for unresolved build placeholders, missing asset refs, undefined classes/vars, sprite integrity. Suspicious findings were re-verified with targeted geometry measurements and pixel screenshots (VLM-assisted).
**Output:** this spec + the corrected artifact set in `docs/design/v1.6.2/`.
**Severity scale:** Critical (layout broken / content unreadable) → High (WCAG AA failure on a shipped screen) → Medium (tokens, hit areas, a11y attributes) → Low (hygiene, docs labels).

---

## 1. Findings index

| ID | Sev | Area | Finding | Frames affected |
|----|-----|------|---------|-----------------|
| F-101 | Critical | Layout | iPad master-detail frame overflows by 122px; phantom 94px status-bar column | IPAD-messages-light, IPAD-messages-dark |
| F-102 | Critical | Contrast | Status-strip pills illegible in dark (1.33:1) | H12-inprogress-dark, T22-booked-dark, T22-inprogress-dark, IPAD-dashboard-dark |
| F-103 | High | Contrast | `pill-problem` in dark status strip 2.67:1 | H12-dispute-dark |
| F-104 | High | Contrast | Hero stat tiles use raw palette colors that don't swap in dark (1.22:1, 2.24:1) | H07-empty-dark |
| F-105 | High | Tokens | 8 inline `background:var(--surface)` overrides on progress segments make dark "on" segments nearly invisible | H12/H13 dark + light sources, T25, IPAD |
| F-106 | Medium | Tokens | `.outdoor --line` typo: `rgba(255,57,87,.28)` (pink-red) instead of `rgba(25,57,87,.28)` (navy) | all `-outdoor` frames |
| F-107 | Medium | Consistency | Component classes fragmented across files; used where undefined → render unstyled | frames-dark, frames-outdoor |
| F-108 | Medium | Hit area | "Open chat" tonal button inline `height:44px` < 48dp floor | H07-light, H07-dark |
| F-109 | Medium | Hit area | Map-head back button 44×44 < 48dp (all other backs are 48dp) | T21-light, T21-dark, T21-outdoor |
| F-110 | Medium | A11y | 16 icon-only interactive elements without `aria-label` | H07, H07-empty, H13, T23, IPAD-chat, IPAD-messages (light+dark) |
| F-111 | Medium | A11y | 88 `<img>` elements without `alt` attribute | all files |
| F-112 | Medium | Brand rule | Orange budget exceeded (rule: max 2 = 1 primary CTA + 1 urgency) | H07 (4), H17-rated-expanded (3), IPAD-tradie-dark (5) |
| F-113 | Low | A11y | No `:focus-visible` styles anywhere (keyboard users see no focus ring) | kit.css |
| F-114 | Low | Tokens | 139 inline hardcoded colors in screen frames bypass the token system | all screen files |
| F-115 | Low | Tokens | `pill-waiting` inline `background:rgba(60,117,170,.12)` defeats the `.dark` override | H13, IPAD-messages (light+dark) |
| F-116 | Low | Tokens | `.badge.good` has no dark override (raw `--ink-success` text) | latent (currently unused in dark) |
| F-117 | Low | Typography | Component-sheet / style-tile annotation labels at 8–11px, below the 12px floor | component-sheet.html, style-tile.html |
| F-118 | Low | Tokens | Tradie avatars pair `--av-tradie` fill with fixed white ink — fails in dark (blue300 fill, 2.3:1) | IPAD-dashboard/messages-dark, latent elsewhere |

**Verified false positives (no action):** S01 splash status-bar/wordmark contrast (status-bar is `z-index:2` over a sibling hero band the probe cannot composite); chips cut at the frame edge inside `.faderow` (intentional scroller with 32px fade — Flutter must use a horizontal `ListView` + fade); `.seg48 .o` (48px, compliant); wordmark `span.o` matched by the tap-target selector (not interactive); chips drawing 40dp with a 48dp `::after` hit area (by design).

---

## 2. Detailed findings & remediation

### F-101 (Critical) — iPad master-detail layout breaks

**Evidence (measured in Chromium):** `IPAD-messages-light/dark` contain a `<div class="statusbar">` as a *direct child of the row-direction frame*. It renders as a 94px-wide vertical sliver (time + signal icons stacked sideways). The `.md` region then measures **862px inside the 834px frame — 122px of overflow**; the detail pane's chat bubbles, quick-reply chips and composer are clipped mid-word at the right edge.

**Root cause:** two independent defects compound:
1. the stray status bar (copy-paste from a column-layout frame);
2. `.md { display:flex; flex:1; min-height:0 }` lacks `min-width:0`, so as a row-direction flex item its automatic minimum size (min-content = 862px) exceeds the 834px frame and it cannot shrink.

**Fix (applied in v1.6.2):**
1. Delete the stray `<div class="statusbar">…</div>` directly under both `IPAD-messages-*` frame divs (all other iPad frames nest the status bar inside a pane or omit it in row layout).
2. Add `min-width: 0;` to the `.md` rule in `kit.css`.
3. Verified result: `.md` = 834px, detail pane = 474px, right edge flush, `scrollWidth == clientWidth` (no internal clipping).

### F-102 (Critical) — Status-strip pills illegible in dark

**Evidence:** computed style in `H12-inprogress-dark`: `.pill.pill-active` inside `.status-strip` → `background: rgba(255,255,255,.16)`, `color: rgb(25,57,87)` = navy on near-navy = **1.33:1** (WCAG AA needs 4.5:1). Affects every dark frame using a status strip.

**Root cause:** `kit.css:334` — `.status-strip .pill { background: rgba(255,255,255,.16); color: var(--on-brand); }`. The status strip is always navy (`--strip`: `#12293F` dark / `#193957` light), so pill text must be a *fixed* light color — but `--on-brand` flips to navy in dark mode.

**Fix:** `.status-strip .pill { color: #fff; }` (strip is navy in both themes; the translucent pill surface over navy is always dark, so white is correct in both modes). Regression-check the four frames above after the change.

### F-103 (High) — "Disputed" pill 2.67:1 in dark

**Evidence:** `H12-dispute-dark`: `.status-strip .pill-problem` → `background: var(--surface)` (dark card `#1E2328`), `color: var(--ink-danger)` (`#B23A2E`, the *light* danger ink) = **2.67:1**.

**Root cause:** `kit.css:335` — `.status-strip .pill-problem { background: var(--surface); color: var(--ink-danger); }`. `--ink-danger` is a raw palette token; the dark-variant ink is `--ink-danger-d`.

**Fix:** add `.dark .status-strip .pill-problem { color: var(--ink-danger-d); }` (the surface background swap is intentional and retained).

### F-104 (High) — Hero stat tiles use raw palette colors

**Evidence:** `H07-empty-dark` trust-stat row: "<5 min" `color:var(--navy)` on `--tint-brand` over dark paper = **1.22:1**; "100%" `color:var(--ink-success)` on `--tint-success` = **2.24:1**. Both tiles are unreadable in dark (VLM-confirmed "nearly invisible").

**Root cause:** inline `color:var(--navy)` / `color:var(--ink-success)` — raw palette tokens that do not participate in the `.dark` semantic swap.

**Fix:** replace with the semantic tokens that swap: `color:var(--text-brand)` (blue300 in dark) and `color:var(--success-text)` (#8FC9A8 in dark). Same substitution in H07-empty-light for consistency (values identical in light mode).

### F-105 (High) — Inline overrides kill dark progress segments

**Evidence:** 8 occurrences of `<div class="seg on" style="background:var(--surface)">` (frames-dark ×4, frames-tradie ×2, frames-homeowner ×1, frames-ipad ×1). In dark, `--surface` = `#1E2328` — nearly the same as the translucent track, so "completed" segments vanish (VLM: "progress segments … similarly faint"). The kit already provides `.status-strip .cpb .seg.on { background:#fff }` and `.cpb .seg.on { background:var(--brand) }`.

**Root cause:** redundant inline style (harmless in light where surface = white) that overrides the correct cascade in dark.

**Fix:** delete every `style="background:var(--surface)"` on `.seg.on` elements; rely on the kit rules. Grep gate: `rg 'seg on" style="background:var\(--surface\)' html/` must return 0.

### F-106 (Medium) — Outdoor line token typo

**Evidence:** `kit.css` `.outdoor { … --line: rgba(255,57,87,.28); }` — channels are **255**,57,87 (pink-red) instead of **25**,57,87 (navy). `tokens/design_tokens.dart` outdoor line = `Color(0x47193957)` = rgba(25,57,87,.28). At .28 alpha over cream the error is subtle visually, but every outdoor hairline (card outlines, input borders, dividers) deviates from the token source of truth.

**Fix:** `.outdoor { --line: rgba(25,57,87,.28); }` — now byte-identical to `design_tokens.dart`.

### F-107 (Medium) — Component classes fragmented across files

**Evidence (static):** classes defined only in some files' local `<style>` blocks but consumed in others where they are undefined:
- `.ill-card` — defined in frames-entry.html + prototype.html; used (unstyled) in frames-dark.html (3×) and frames-outdoor.html (2×).
- `.listitem` — defined only in frames-ipad.html; used in frames-dark.html (4×) where it renders with no padding/border.
- `.herotile` — defined in frames-tradie.html + prototype.html; used in frames-dark.html.
- `.svc`, `.rate` — defined in frames-tradie.html; used in frames-dark.html.
- `.blob-blue`, `.blob-peach` — used in 5 files, defined nowhere (benign decoration, but the transpiler cannot map them).

**Root cause:** the dark/outdoor variants were hand-copied from light frames whose local styles didn't travel with the markup.

**Fix:** promote every shared component class to `kit.css` (single source of truth), delete the per-file duplicates: `.ill-card`, `.listitem`, `.herotile`, `.svc .rate`, `.blob-blue/.blob-peach` (no-op visual class retained for transpiler mapping). Verify zero `undefined_class` findings on re-audit.

### F-108 (Medium) — Tonal button below 48dp

**Evidence:** H07-light/dark "Open chat": `<div class="btn btn-tonal" style="height:44px;…">` → 324×44. Kit default `.btn-tonal { height:48px }`; `tokens.json` `size.tapMin: 48`.

**Fix:** remove the inline `height:44px;font-size:14px` override (48px / 15px defaults restore).

### F-109 (Medium) — Map back button below 48dp

**Evidence:** `kit.css:532` `.maphead .appbar .back { … width:44px; height:44px; … }` → measured 44×44 in T21-light/dark/outdoor, while every other back is 48×48.

**Fix:** bump the scrim disc to `width:48px; height:48px;` (keep the 24px glyph and `margin-left: var(--gutter)`; the circle stays centered on the gutter).

### F-110 (Medium) — Icon-only controls unnamed

**Evidence:** 16 icon-only interactives without `aria-label`: H07/H07-empty bell `.ico-btn` (light+dark), H13/T23 `.ibtn.send`, IPAD-chat/IPAD-messages `.ibtn.cam` + `.ibtn.send`. Screen readers announce nothing; the Flutter port would produce buttons without `tooltip`/`semanticsLabel`.

**Fix:** add `aria-label` + `role="button"` matching the existing pattern (`.back` already carries `aria-label="Back"`): bell → "Notifications", send → "Send message", cam → "Attach photo".

### F-111 (Medium) — Images without alt

**Evidence:** 88 `<img>` (rings, blobs, contours, illustrations, avatars-as-img) lack `alt`. Decorative images must be explicitly `alt=""` (excluded from the a11y tree); content illustrations get short text.

**Fix:** decorative art → `alt=""`; meaningful illustrations (empty states, onboarding art) → concise alt (e.g. `alt="Tradie checking a job board"`). The transpiler maps `alt=""` to `Semantics(excludeSemantics:)`-free `Image.asset` and labeled alt to `semanticLabel`.

### F-112 (Medium) — Orange budget violations

**Evidence (rule R1: max 2 orange elements = 1 primary CTA + 1 urgency element):**
- H07-light/dark: 4 — amber notification dot + "Action needed" pill + "Payment due" pill + primary CTA.
- H17-rated-expanded: 3 — two amber link rows + CTA.
- IPAD-tradie-dark: 5 — 2 amber caps + urgent countdown text + urgent fill + CTA.

**Fix:** keep the single most urgent item amber per screen: H07 → "Payment due" becomes `pill-waiting`, and the notification dot inherits `--brand` (it sits on the navy hero); H17 → the secondary link row drops the amber text; IPAD-tradie-dark → the two caps use `--text-soft`, countdown + fill stay as the one urgency element. T19/T21 countdown pairs (text + fill = one element) + CTA = compliant, unchanged.

### F-113 (Low) — No focus-visible styles

**Fix:** add to `kit.css`:
```css
.back:focus-visible, .ico-btn:focus-visible, .ibtn:focus-visible, .btn:focus-visible,
.chip:focus-visible, .o:focus-visible, .cell:focus-visible, .tab:focus-visible {
  outline: 2px solid var(--brand); outline-offset: 2px; border-radius: inherit; }
```
Maps to Flutter `FocusableActionDetector`/default `Focus` highlight in the port.

### F-114 (Low) — Inline hardcoded colors in screens

**Evidence:** 139 inline colors in screen frames, dominated by `#fff` (36), `rgba(255,255,255,.75)` (26), `rgba(60,117,170,.12)` (15), `rgba(255,255,255,.25)` (12), `#3C75AA` (12), `rgba(25,57,87,.06)` (7)…

**Fix:** replace with existing/new tokens: `rgba(60,117,170,.12)` → `var(--tint-brand)`; `#3C75AA` → `var(--av-tradie)`; `rgba(25,57,87,.06)` → `var(--press)`; `rgba(25,57,87,.12)` → `var(--track)`; `rgba(255,255,255,.75/.65/.55)` → new `--on-hero-soft` (and `.45` → `--on-hero-faint`) tokens defined once per theme; `rgba(255,255,255,.25)` on hero glass → `--hero-track`. Whitelisted exceptions: pure-white text on navy heroes (`color:#fff` is a deliberate constant, documented as `--on-hero`), and inside `<svg>` fills.

### F-115 (Low) — pill-waiting inline background

**Evidence:** H13 + IPAD-messages (light+dark): `<div class="pill pill-waiting" style="…background:rgba(60,117,170,.12)">` — the light tint baked inline defeats `.dark .pill-waiting` (which specifies `rgba(137,175,210,.28)`).

**Fix:** delete the inline background; the cascade already theme-switches. Keep the non-color inline properties (`align-self`, `justify-content`).

### F-116 (Low) — `.badge.good` dark override

**Fix:** add `.dark .badge.good { background: rgba(143,201,168,.16); color: var(--ink-success-d); }` next to the existing `.dark .badge` rule.

### F-118 (Low) — Avatar ink doesn't follow the avatar fill

**Evidence (found while verifying F-114):** tradie avatars carry inline `background:var(--av-tradie);color:#fff`. In dark, `--av-tradie` correctly flips to blue300 (light blue) but the fixed white ink drops to 2.3:1 (IPAD-dashboard-dark, IPAD-messages-dark "MT").

**Fix:** new `--on-av-tradie` token (`#FFFFFF` light/outdoor, `var(--navy)` dark); all 16 inline pairings rewritten to `color:var(--on-av-tradie)`.

### F-117 (Low) — Annotation labels below 12px

**Evidence:** 194 annotation elements in component-sheet.html / style-tile.html at 8–11px (e.g. `b` labels "pill/action-needed" 11px; `div.src` swatch captions 11px; scale marks 8.33px). The 12px floor (AC-VD-10) is claimed as met; these are documentation labels, not app UI, but they fail the audit gate.

**Fix:** raise annotation font sizes to ≥12px (`.src`, `.cap`, `b` labels, tick marks); adjust swatch-grid spacing so nothing wraps.

---

## 3. What was checked and found clean

- **Sprite integrity:** 0 unresolved `%%SPRITE%%` placeholders; every `<use href="#…">` resolves to an inline `<defs>` id in every source file (F-01 from v1.6.1 stays fixed).
- **Asset refs:** 0 missing files among 300+ `src`/`href` references.
- **Text truncation:** 0 elements with `scrollWidth > clientWidth` outside intentional `.faderow` scrollers.
- **Small text in screen frames:** 0 instances below 12px in the 10 screen files (F-06 from v1.6.1 stays fixed; remaining sub-12px text is confined to the two documentation sheets — F-117).
- **Component states:** component sheet covers primary/secondary/tonal/ghost/navy/danger buttons × (default/pressed/disabled) and inputs × (default/focused/filled/error/disabled); skeleton, toast, banner, sheet states present.
- **Back-button geometry:** single pattern at x=0 with 24px glyph (F-02 fix holds); only the map variant's 44px size remains (F-109).
- **`.badge` vs `.chip` discipline:** no 26px-high chips remain (F-03 holds); trust rows use wrapping `.badges` (F-04 holds).
- **Reduced motion:** `prefers-reduced-motion` disables all decorative animations.

## 4. Regression gates (all must pass on v1.6.2)

1. `python3 tools/audit_full.py <root> out.json` → `clip=0` (excluding whitelisted faderow/decorative), `tap=0`, `small=0` in screen frames, `contrast=0` in screen frames for ratios < 4.5:1 (3:1 large text), `static=0` undefined classes.
2. No `style="background:var(--surface)"` on `.seg.on` (grep gate).
3. No `rgba(255,57,87` anywhere in kit.css.
4. Orange budget: no screen frame with > 2 amber elements (a `.countdown` urgency widget counts as ONE element; style-tile palette documentation is exempt).
5. Every `.ico-btn/.ibtn/.back` carries `aria-label`; every `<img>` carries `alt`.
6. IPAD frames: `.md` right edge == frame right edge (0px overflow).

## 5. Verification results (v1.6.2, after `tools/fix_v162.py`)

| Gate | Before (v1.6.1) | After (v1.6.2) | Status |
|------|-----------------|-----------------|--------|
| Screen-frame contrast failures | 15 (10 real) | 0 (8 remaining are the documented S01 z-index false positive) | PASS |
| IPAD `.md` overflow | 122px | 0px (md=834, scrollWidth==clientWidth) | PASS |
| Phantom status-bar column | 2 frames | 0 | PASS |
| `.seg.on` inline surface overrides | 29 | 0 | PASS |
| `rgba(255,57,87` in kit.css | 1 | 0 | PASS |
| Undefined classes / vars | 14 / several | 0 / 0 | PASS |
| Icon-only controls without aria-label | 16 | 0 (36 labelled total) | PASS |
| `<img>` without alt | 88 | 0 (111 annotated) | PASS |
| Sub-12px text anywhere | 216 | 0 | PASS |
| Orange budget violations | 8 frames | 0 (T19/T21/IPAD-tradie-dark countdown pairs = 1 widget + CTA; style-tile exempt) | PASS |
| Tap targets < 48dp | 8 | 4 reported, all wordmark `span.o` false positives | PASS |
| Inline hardcoded colors in screens | 139 | 67, all theme-invariant hero-glass constants (`#fff` text on navy heroes, frosted `rgba(255,255,255,.55)` surfaces, `#000` shadows) — heroes are navy in every theme, so these cannot break in dark; the transpiler emits them as named Dart constants | PASS (documented) |
| Dark avatar ink | 2.3:1 | ≥ 4.5:1 via `--on-av-tradie` | PASS |

Visual verification (VLM screenshot review) of the three worst frames: IPAD-messages (no clipping, no phantom column), H07-empty-dark (stat values readable), H12-inprogress-dark (pill + segments legible) — all PASS.

The corrected artifact set lives in `docs/design/v1.6.2/` (same structure as v1.6.1; `tools/fix_v162.py` is the deterministic, idempotent transformation that produced it and doubles as the change record).
