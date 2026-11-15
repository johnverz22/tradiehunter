# v1.6 Design Deliverables — Audit Context

**Purpose:** This document gives an external auditor (human or model) the ground truth, conventions, and known limitations needed to audit the v1.6 visual-design deliverables for correctness and improvement. Audit findings should reference the governing specs, not personal taste.

**Do not assume the PNGs are screenshots of the app.** They are static renderings of hand-written HTML/CSS that approximates the Flutter design language. Judge them against the specs below and internally against each other.

---

## 1. What exists and where

| Path | Contents |
|---|---|
| `docs/design/v1.6/assets/` | 15 abstract SVG assets + `il-01`–`il-08` spot illustrations in `-light` and `-dark` variants (31 SVGs total) |
| `docs/design/v1.6/frames/` | 150 rendered PNGs: `style-tile.png`, 75 component-sheet frames, 52 light-mode screen frames, 15 `-outdoor` variants, 7 `-dark` frames |
| `docs/design/v1.6/html/` | Source HTML per group + shared `kit.css` (the token/component stylesheet) + `sprite.html` (icon sprite) |
| `docs/design/v1.6/html/prototype.html` | Clickable prototype of the 4 core flows (open `build/prototype.html`) |
| `docs/design/v1.6/build.sh` + `render.mjs` | Re-render pipeline: assembles `html/*.html` into `build/` (inlining the sprite + copying `kit.css`), screenshots every `[data-frame]` element to `frames/` at 1× via Playwright + system Chrome |

**Regenerate:** `cd docs/design/v1.6 && ./build.sh` (requires `web/node_modules/playwright-core` and Google Chrome installed). `build/` is generated output — audit `html/` sources, not `build/`.

## 2. Governing documents (in priority order)

1. `docs/specs/v1.6/specification.md` — layout, hierarchy, component contract (§3), per-screen structure (§4), AC-01–08 (§6). **Functional matters win here.**
2. `docs/specs/v1.6/visual-design.md` — colour system (§2), abstract assets (§3), depth/materials (§4), type/icons (§5), illustration (§6), per-screen treatments (§7), motion (§8), deliverables (§9), AC-VD-01–10 (§10). **Visual treatment wins here.**
3. `docs/specs/v1.6/tasks.md` — task checklists V16-21–V16-26 with acceptance criteria.
4. `mobile/lib/theme/design_tokens.dart` — programmatic token source of truth (hue 209).
5. `docs/design/design-system.html` — original token sheet (note: `mobile/AGENTS.md` says legacy mockups in `docs/design/mockup/` are **excluded** from inputs/acceptance — do not audit against them).

## 3. Confirmed token values (from `DesignTokens`, hue 209)

| Token | Hex | Role |
|---|---|---|
| navy `brand900` | `#193957` | headings, hero bands, active pills, dark-mode base |
| `brand700` | `#29537A` | secondary structure |
| blue `brand500` | `#3C75AA` | info, tonal fills, avatars, completed progress |
| `brand300` | `#89AFD2` | dark-mode brand foreground |
| amber | `#E38B29` | primary CTA, urgency, the one accent per screen |
| amberDark | `#B96A18` | amber shading / countdown text on light |
| green | `#3A7D5C` | verified/done only |
| red | `#B23A2E` | disputes/rejected only |
| cream `paperLight` | `#F6F4EE` | app background |
| surface | `#FFFFFF` | cards |
| onAmber | `#241300` | CTA label colour (dark ink on amber, ≥4.5:1) |

Dark neutrals: `paperDark #14181B`, `paperLineDark #262C30`, `cardDark #1E2328`, `brand100Dark #1B2937`, `inkDark #ECEAE3`, `inkSoftDark #9AA4AC`. Semantic dark inks: success `#8FC9A8`, danger `#E8968E`. Light semantic inks: success `#2E6B4E`, danger `#B23A2E`, accent `#8F4F08`.

**Tints** are opacity composites over cream (light) or `#14181B` (dark) at 6/12/20/32% — the exact composited hexes are on `style-tile.png`. **Gradients** (only these four): `heroGradient` navy→blue 135°, `warmBg` cream→peach ↓, `coolBg` blue-12%→cream ↓, `ctaSheen` `#EB9A3F`→`#E38B29` ↓.

**Type:** Space Grotesk for hero numbers (40/700), display (28/700), section (20/600); IBM Plex Sans for card titles (18/600), price (24/700 tabular), body (16), secondary (14), caption (12/500 min); IBM Plex Mono for reference codes only.

**Radii:** card 20, control/input 14, tile 16, sheet 28, pill 999. **Heights:** primary 56, secondary 52, inputs 56, tonal/ghost 48, all targets ≥48. **Shadows:** card `0 1 2 + 0 8 24` navy 6–8%; sheet `0 -12 32` navy 12%; CTA `0 6 16` amber 25% (dark: glow `0 6 20` amber 30%, no drop shadow).

## 4. Frame naming and the S02–S04 ID collision

The source specs reuse `S02`–`S04` for **both** the three onboarding slides and (in tasks.md's checklist) login/sign-up. Resolution used here — treat this as the corrected map, not a defect:

| File prefix | Screen |
|---|---|
| `S01` | splash · `S02`–`S04` | onboarding slides 1–3 |
| `S05-login` | login · `S06-signup` | sign-up · `S07-otp` | OTP · `S08-roleselect` | role select |
| `H07`–`H18` | homeowner screens per VD §7 · `T19`–`T26` | tradie screens |
| `E-*` | error/empty states (spec assigns no IDs; names invented here) |
| `IPAD-*` | iPad frames at 834×1194 |
| component frames | `pill-*`, `cpb-*`, `btn-*`, `input-*`, `leadcard-*`, `hero-*`, `trust-*`, `sheet-*`, `navbar-*` |

Suffixes: `-light`, `-dark`, `-outdoor` (flat high-contrast hero variant per VD §1/§3.2).

## 5. What to audit — checklist mapped to AC-VD

- **AC-VD-01 colour compliance:** grep `html/` + `assets/` for hex values; every one must be a §3 source colour or an rgba()/opacity derivation of one. The four gradients are the only gradients allowed.
- **AC-VD-02 orange proportion:** ≤2 orange usages per working screen (CTA + at most one urgency/countdown element); never decorative.
- **AC-VD-03 contrast:** text pairs ≥4.5:1 (≥3:1 for 18px+/700). Known-good pairs by construction: navy-on-cream, white-on-navy/gradient, onAmber-on-amber, inkSuccess/inkDanger/inkAccent on their tint fills, blue300 ink on dark surfaces. Verify chips/pills against their actual composite fills.
- **AC-VD-04 abstract placement:** no blobs/rings/grids/tool-shapes behind body text, fields or CTAs; top 30% or hero bands only. Note: `bpdots` on chat is a sanctioned 3–5% texture behind bubbles per VD §7-H13.
- **AC-VD-05 outdoor variants:** every hero-class screen should have an `-outdoor` frame: flat surfaces, no blobs/glass/gradient-over-text; hero band may remain if text still passes (S01, T19 keep flat-navy/gradient bands with white text).
- **AC-VD-06 illustration consistency:** IL-01–08 flat vector, palette-only, navy/blue clothing + orange accent, no photos, no text in art, dark variants re-tinted. **Expect weaker fidelity here — see §6.**
- **AC-VD-07 motion fallbacks:** prototype's reduce-motion toggle should disable pulse/slide animations; static frames imply static fallbacks exist.
- **AC-VD-08 component completeness:** all §9.4 states present; every button has a pressed frame.
- **AC-VD-09 realistic data:** no lorem ipsum/fixture names; NZ data throughout.
- **AC-VD-10 spec fidelity:** dimensions/tokens per §3–4 of specification.md: 28px pills (13/600), 4px compact bar + "Step N of 4", 20px cards, 56/52/48px controls, 48px targets, 1:2 decline/accept split, status strip on job detail, 72px message rows, 48×56 OTP cells, 56px list rows, 28px sheet radius + 40×4 grip.
- **Internal consistency:** same component must look identical wherever it appears (pill in component sheet vs in H07 vs in T20; card style across all screens; nav bar across all screens). Divergence between `component-sheet` and screen frames is a real finding.
- **Cross-theme consistency:** every light screen element must have a dark-theme counterpart that only changes colours/elevation, not layout or content.

## 6. Known limitations — weigh, don't just flag

These are documented deviations a fair audit should score as *limitations of the medium*, not spec violations:

1. **Hand-authored SVG illustrations.** IL-01–08 are code-drawn flat vectors — simpler and less refined than the AI-generated onboarding PNGs in `mobile/assets/illustrations/`. Evaluate palette/style fit (AC-VD-06) but expect a polish gap; they are concept drafts, not final art.
2. **Onboarding slide art are stand-ins.** Slides reuse IL-01/IL-07/IL-02 as placeholders, not purpose-built slide illustrations.
3. **Approximated effects.** Glass pills on H11 badges render as solid chips (outdoor-correct); blueprint noise/`-mask-image` fades are approximate; pin-ripple and sparkline animations exist only as static depictions + prototype CSS approximations.
4. **Shared-element transitions** in the prototype are cross-fade+rise approximations, not true element morphs. Press states are `:active` scale .98.
5. **Prototype canvas is 402px for all flows**, including the tradie flow whose reference size is 440px — layout identical, width reduced.
6. **Status-bar chrome** (time, battery) is a simplified mock and is missing on some frames.
7. **Spec-internal contradictions — resolved 2026-10-31 (product decisions):** (a) pill tint — spec §3.2's 15% wins over VD §2.2's 12%; kit uses 15%. (b) job-detail tonal buttons — **Navigate/Message/Call** confirmed (VD §7-H12's "Chat" was a dupe of "Message"; spec text should be amended). (c) entry-screen IDs — codified per §4 (slides S02–S04, then S05–S08); `visual-design.md` §7 renumbered to match.
8. **`.frame.dark` nesting** inside component-sheet cells: dark component variants wrap a `.frame.dark` div inside a `.cf.dk` cell — cosmetic wrapper, both paint the dark surface.
9. **`leadcard-low`** uses a neutral left accent bar (vs orange on default/high) — **confirmed decision**: neutral preserves "orange = urgency/action" semantics; VD §7-T19's blanket orange-accent text should be amended.
10. **Wizard sticky-CTA fade** is approximated by the `.sticky` gradient, not a dedicated 40px fade element.
11. **Homeowner bottom nav** renders Home/Jobs/Post-job/Messages/Profile with Post-job as the centre FAB — **confirmed canonical**; the app shell (`main_layout.dart`) differs and should be aligned to this, not vice versa.
12. **Request-detail earning line — confirmed decision:** hours × rate breakdown (commission% isn't guaranteed on the offer payload), so T21/IPAD-tradie/prototype show "Estimated · 2 h × $85.50/h". "You earn $153.90" remains only on post-acceptance screens (T22) per V16-16.
13. **Fonts via Google Fonts CDN** — if audited offline, frames fall back to system-ui and look wrong. Re-render with network or trust the PNGs.

## 7. Output format for findings

Report per finding: `frame/asset → spec reference → what's wrong → severity (blocker/major/minor) → suggested fix`. Separate *spec violations* (must fix) from *spec-internal conflicts* (needs a decision) from *medium limitations* (accept or improve).
