---
name: mockup-to-flutter
description: Translate HTML/CSS mockup frames (kit.css classes such as .appbar, .back, .pill, .badge, .chip, .faderow, .sticky, .heroband, .btn-tile) into Flutter widgets for the TradieHunter/Fixo mobile app using the repo's tokens. Use when implementing or fixing a mobile screen from docs/design html, or when a run screenshot differs from its mockup.
---
# Mockup → Flutter

## Procedure
1. Open the frame in `docs/design/v*/html/` and read the **kit.css rules for every class used**; do not eyeball pixels. Inline `style=` attributes are overrides - they are usually bugs or one-offs, check before copying.
2. Map each class with `references/css-to-flutter.md`. Reuse an existing widget (`FixoAppBar`, `StatusBadge`, `FixoCard`, `FixoPrimaryButton`...) before writing a new one.
3. Every number must be a token (`Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `Tracking`, `THColors`, `DesignTokens`). If missing, add it to `mobile/lib/theme/design_tokens.dart`. No raw literals or `Color(0x..)` in views (repo rule).
4. Build light and dark. Dark = token swap only.
5. Test with long text, 1.3x text scale, and a 360dp-wide device. A mockup frame is 402dp with short strings; overflow shows up only there.
6. Compare with the run screenshot using `design-vs-run-crosscheck`.

## Failure patterns seen in v1.6 (check these first)
- Widget re-derives a size the token already has (`FixoAppBar` 72dp vs `Sizes.appBar` 56).
- Back shown via `Navigator.canPop()` only; screens reached by `context.go` lose it.
- Label implemented with the interactive chip, or `Row` of badges that overflows. Use `Wrap`.
- CSS `overflow:hidden` + mask for a chip row becomes a clipped `Row`. It must be a horizontal `ListView` with fade.
- Primary CTA styled amber for every item in a list; the rule is one amber primary per screen.
- Icon swapped (paper plane → `arrow_forward`).
- Text in a `Row` without `Expanded` gets truncated.

Dart recipes in `references/recipes.md` are written against token names found in the repo but have NOT been compiled; run `flutter analyze` before committing.
