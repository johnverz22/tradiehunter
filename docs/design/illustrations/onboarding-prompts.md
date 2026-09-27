# Onboarding Illustrations — Generation Prompts

**Status:** placeholder in code. Replace `Text('Illustration Area')` at
`mobile/lib/views/onboarding_screen.dart:77` with `Image.asset(...)` or
`SvgPicture.asset(...)`.

**Why these prompts exist:** neither the mockup
(`docs/design/mockup/mobile/02-onboarding.html:143`) nor the Flutter screen
specifies artwork — both just render a brand-100 block with the literal text
`Illustration Area`. The three slides below are inferred from the copy in
`_slides` (`onboarding_screen.dart:19-35`).

---

## 1. Technical spec (all three)

### The box is flexible, not fixed

The illustration sits in an `Expanded` (`onboarding_screen.dart:65`), so its
height is whatever is left after fixed chrome, and it **changes per device**.
Measured against the real theme + button metrics (`fixo_buttons.dart:20-22`
48 pt CTA, `fixo_theme.dart:64-68` `headlineSmall` 24 px / 1.33, `bodyLarge`
15 px), the fixed chrome totals **~394 pt**:

```
art height = screenHeight - safeTop - safeBottom - 394
```

| Device | Screen | Art box (pt) | Aspect (H/W) |
|---|---|---|---|
| iPhone SE | 375×667 | 327 × 253 | **0.77 — wider than tall** |
| iPhone 13/14 | 390×844 | 342 × 369 | 1.08 |
| iPhone 14 Pro Max | 430×932 | 382 × 445 | 1.16 |
| Pixel 7 | 412×915 | 364 × 473 | **1.30 — tall** |

Width is deterministic at `screenWidth - 48` (the `horizontal: 24` margin).
Height swings from 253 pt to 473 pt — a **0.77 to 1.30 aspect range**, so no
single fixed canvas fits every device.

### How to handle it

The brand-100 fill is painted by the `Container` itself
(`onboarding_screen.dart:68-74`), **not** by the image. So generate with a
**transparent background** and let the container supply the colour. Then
letterboxing is invisible and one asset works at every ratio:

| Property | Value |
|---|---|
| Canvas | **1024 × 1280 px** (4:5 — mid-range, matches Pixel 7 / Pro Max) |
| Background | **Transparent.** The `Container` provides the `#E1EBF4` / `#1B2937` fill. |
| Render with | `BoxFit.contain` inside the existing `alignment: Alignment.center` |
| Critical safe zone | Subject must fit within the **central 62%** of the canvas. On an iPhone SE the box crops to 0.77 and anything in the outer 15% top/bottom is clipped. |
| Line weight | Keep strokes thin relative to canvas; at 253 pt tall on an SE, a 4 px-equivalent stroke renders ~1.3 device px and greys out. Prefer 8-10 px at 1024 wide. |
| Text in image | **None.** All copy is rendered in Flutter. Any lettering the model invents will be wrong and cannot be localised. |
| Output format | SVG preferred (scales to 3x, ~8 KB). If raster: PNG-24 @3x with alpha. |
| Container radius | 4 px — effectively square corners. **Do not bake rounded corners or edge shadows into the art.** |
| Theme | Two variants per illustration — light + dark. See §6. |

> **Alternative if you'd rather have deterministic geometry:** replace the
> `Expanded` with `AspectRatio(aspectRatio: 4/5, child: Align(alignment:
> Alignment.topCenter, child: ...))` and let the freed space fall to the text
> block. That breaks from the mockup's `flex: 1`, so flag it before changing —
> per `AGENTS.md` the mockup is law. The transparent + `contain` route above
> needs no layout change.

### Palette (exact — copy these hex values into the prompt)

| Token | Hex | Role |
|---|---|---|
| brand-900 | `#193957` | Outlines, darkest linework |
| brand-700 | `#29537A` | Secondary shapes, clothing, structure |
| brand-500 | `#3C75AA` | Primary mid-tone, large fills |
| brand-300 | `#89AFD2` | Light fills, background elements |
| brand-100 | `#E1EBF4` | Container fill behind the art (light) — **not in the image** |
| brand-100 (dark) | `#1B2937` | Container fill behind the art (dark) — **not in the image** |
| amber | `#E38B29` | Accent — **use sparingly, one focal element per illustration** |
| amber-dark | `#B96A18` | Amber shading |
| green | `#3A7D5C` | Success / verified only |
| ink | `#1D2226` | Line art on light only |
| paper | `#F6F4EE` | Warm off-white, small highlights |

**Accent rule:** amber is reserved in this design system for *the one action
that matters most on a screen*. In onboarding artwork it marks the single
point of focus per illustration. Using it on three or more elements flattens
the hierarchy.

---

## 2. Style prompt (prepend to every illustration)

```
Flat vector editorial illustration, 2.5D geometric style, drafted
technical-drawing aesthetic inspired by architectural blueprints and
schematic diagrams. Precise thin linework, clean straight edges, simple
geometric construction, subtle hatching and dotted dimension lines, generous
negative space. Strictly limited palette: #193957, #29537A, #3C75AA, #89AFD2,
#E1EBF4 with a single #E38B29 amber accent and small #F6F4EE paper highlights.
Solid flat fills, NO gradients, NO drop shadows, NO 3D rendering, NO glossy
effects, NO photorealism, NO text, NO lettering, NO logos, NO watermark.
Centered composition with balanced margins. ISOLATED SUBJECT ON A FULLY
TRANSPARENT BACKGROUND — no backdrop, no scene, no ground plane, no horizon.
Subject confined to the central 62% of the canvas with empty transparent margin
on all four sides, so it survives cropping to both 0.77 and 1.30 aspect ratios.
```

**Negative prompt** (if the tool supports one):
```
solid background, filled background, backdrop, scene, environment, ground
plane, shadow beneath, horizon, photorealistic, 3d render, gradient, drop
shadow, glossy, bevel, emboss, texture, grain, noise, sketch lines, marker,
watercolor, crayon, anime, manga, 3d character, emoji, sticker outline, white
outline, busy background, cluttered, text, letters, words, numbers, typography,
watermark, signature, logo, ui, screenshot, mockup, phone frame, device, hands
cropped, extra fingers, deformed
```

---

## 3. Illustration 1 — "Describe your problem"

**Slide copy** (`onboarding_screen.dart:20-24`)
> **Describe your problem** — Tell us what needs fixing and we'll connect you
> with the right local professionals.

**Suggested filename:** `assets/illustrations/onboarding_describe.png`

```
SUBJECT: A single homeowner's hand holding a smartphone, seen from a slight
three-quarter angle, thumb mid-tap. The phone screen shows a simple abstract
form with two empty input lines and a small amber circular submit button.
Radiating outward from the phone is a loose constellation of small geometric
problem-symbols — a dripping water drop, a flickering bolt, a cracked tile
square, a wobbly gauge needle — connected by thin dotted blueprint guide
lines with tiny tick marks, like a technical diagram pinning down a fault.
All the problem symbols are #89AFD2 line art except ONE, the water drop, which
is filled #E38B29 to mark it as the focal problem. The hand and phone are
#29537A and #3C75AA with #193957 linework.
```

**Visual rationale:** the phone form is the *input*; the radiating symbol
cluster is the platform's *interpretation* of the problem. The one amber drop
shows that a messy real-world problem gets resolved into a single specific
item.

---

## 4. Illustration 2 — "Get matched fast"

**Slide copy** (`onboarding_screen.dart:25-29`)
> **Get matched fast** — We find verified tradies near you and notify them
> instantly.

**Suggested filename:** `assets/illustrations/onboarding_match.png`

```
SUBJECT: A top-down abstract map plate — a large soft #3C75AA circle
representing a locality, overlaid with a faint blueprint street grid of thin
#89AFD2 lines. At the centre sits one small solid amber dot (#E38B29). Around
its perimeter, six evenly spaced small circular tradie avatars, each drawn as
a simple flat geometric head-and-shoulders silhouette in #29537A with #193957
outlines; one avatar carries a small circular #3A7D5C green badge with a
checkmark on its corner. From the centre dot, four short amber notification
rays shoot outward to the avatars, each ending in a small rounded-square
notification chip with a single abstract line inside. Thin dashed concentric
radius rings around the centre dot, annotated with tiny tick marks, like a
survey diagram.
```

**Visual rationale:** the geometry *is* the product claim — a radius query
around a point. Concentric rings make "near you" literal. The green check is
the only verified signal, so it appears exactly once.

---

## 5. Illustration 3 — "Chat and get it sorted"

**Slide copy** (`onboarding_screen.dart:30-34`)
> **Chat and get it sorted** — Confirm the job, chat directly, and leave a
> review when it's done.

**Suggested filename:** `assets/illustrations/onboarding_chat.png`

```
SUBJECT: Two overlapping abstract speech bubbles, drawn as flat rounded
rectangles with small triangular tails, arranged as a conversation. The left
bubble is #3C75AA with three short #E1EBF4 lines inside, pointing to a simple
geometric tradie silhouette (#29537A, #193957 outline) in a circular hard hat
shape. The right bubble is #E1EBF4 with #193957 lines, pointing to a simple
geometric homeowner silhouette in a circular avatar. Below and slightly
overlapping the bubbles, a compact rating element: five small rounded squares
in a row, the first three filled #E38B29 and the last two outlined in #89AFD2,
with a short horizontal bar beneath. Fine dotted connector lines link the
bubbles to the rating row, giving the whole composition a schematic feel.
```

**Visual rationale:** the two silhouettes make the two-sided marketplace
explicit. The amber 3-of-5 rating row is the terminal state of the journey and
carries the accent. Outlined (unfilled) stars signal this is a review *being
left*, not a score already received.

---

## 6. Dark-theme variant

The dark container fill is `#1B2937` instead of `#E1EBF4` (from
`DesignTokens.brand100Dark`, `design_tokens.dart:33`). The `isDark` branch at
`onboarding_screen.dart:69-72` already switches it, so **the art itself does not
change** — the background is transparent. Only two adjustments are needed:

- Illustration 3: the `#E1EBF4` bubble fill and its `#E1EBF4` inner lines
  assume a light container behind them. In dark, swap the bubble fill to
  `#ECEAE3` (ink-dark) and its inner lines to `#1B2937`.
- Re-check Illustration 1's `#F6F4EE` paper highlights and Illustration 2's
  `#89AFD2` linework against `#1B2937` for contrast; nudge to `#89AFD2` /
  `#ECEAE3` if they muddy.

Everything else holds: the full brand ramp works on both, and amber stays
`#E38B29` — do not dim it.

**If you only have budget for one set:** ship the light-mode art as-is with a
transparent background. Because the container supplies the fill, the same
transparent asset sits correctly on `#1B2937` too. The only real risk is
low-contrast linework, so verify Illustration 2's `#89AFD2` grid on dark before
shipping rather than assuming.

---

## 7. Tool-specific settings

| Tool | Settings |
|---|---|
| **Midjourney** | append `--ar 4:5 --style raw --stylize 150 --no text, letters, words, gradient, shadow, 3d render, photorealistic, watermark` — then remove the generated background in post; MJ has no true alpha |
| **DALL·E / GPT-image** | state dimensions ("1024×1280 portrait") and ask for "transparent background"; the style block works verbatim as a single prompt |
| **Firefly / SDXL** | use the negative-prompt column; CFG 6-8, 30 steps, seed locked across the three so the style matches |
| **Illustrator / Figma (manual)** | the style block is a valid spec: 4 px stroke `#193957`, flat fills, no gradients, no artboard fill. Cheapest route and the only one that gives true alpha + a tiny file. |

---

## 8. Wiring checklist

1. Export SVGs (or transparent PNGs @3x) to `mobile/assets/illustrations/`.
2. Add to `pubspec.yaml` under `flutter: assets:`.
3. Add `flutter_svg` to `pubspec.yaml` — per `AGENTS.md`, ask before adding any
   dependency not named in `docs/ARCHITECTURE.md`. `flutter_svg` is currently
   *not* listed there, so flag it or take the `Image.asset` PNG route instead.
4. Replace the placeholder `Container` at `onboarding_screen.dart:66-85`. Keep
   the `Container` (it owns the brand-100 fill and the 4 px radius) and swap
   only the `Text('Illustration Area')` child:
   ```dart
   child: Padding(
     padding: const EdgeInsets.all(DesignTokens.space6),
     child: Image.asset(_assets[index], fit: BoxFit.contain),
   ),
   ```
   The existing `alignment: Alignment.center` centres it. Do **not** add an
   `AspectRatio` unless you also accept the mockup deviation noted in §1.
5. Add the three paths to `_slides` (`onboarding_screen.dart:19`) as an `asset`
   field, or a parallel `static const _assets = [...]` list.
6. Run `flutter analyze`, then check on an SE-sized device *and* a Pro Max —
   that is the full 0.77-1.30 range — in **both** themes.
