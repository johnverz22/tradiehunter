# Typography — TradieHunter Design System v2

> Extracted from `DESIGN_GUIDE.md §3`. Single source of truth is `tokens/tokens.json`.
> Type tokens are accessed via `THType.*` in Dart.

## Type scale

| Style | Font | Size / weight | Use |
|---|---|---|---|
| `display` | Lexend | 28 / 600 | Splash-level headings |
| `h1` | Lexend | 24 / 600 | Screen titles |
| `h2` | Lexend | 20 / 600 | Card titles on hero, section headlines |
| `title` | Lexend | 16 / 600 | Card titles, list titles, section headers |
| `button` | Lexend | 15 / 600 | Buttons, pills, segmented control |
| `money` | Lexend | 17 / 600 | Rates and prices in lists |
| `moneyLg` | Lexend | 34 / 600 | Final amount, earnings, countdown |
| `label` | Lexend | 11 / 600, +1.2 tracking, caps | Eyebrows (`NEEDS YOUR ATTENTION`) |
| `body` | Source Sans 3 | 15 / 400 | Paragraphs |
| `meta` | Source Sans 3 | 13 / 400 | Secondary lines, captions |

## Font families

- **Lexend** — headings, money, controls. Fallback: `system-ui`.
- **Source Sans 3** — reading text. Fallback: `system-ui`.

Replaces v1.7: Space Grotesk (headings) + IBM Plex Sans (body) + IBM Plex Mono (codes).

## pubspec.yaml font setup (bundled assets — D-2 decision)

> [!IMPORTANT]
> Per owner decision (D-2, 2026-11-16), fonts are **bundled as woff2/ttf assets** in `pubspec.yaml`, not loaded via `google_fonts`. Download Lexend (weights 400–800) and Source Sans 3 (weights 400–700) from Google Fonts and place them in `mobile/fonts/`.

```yaml
flutter:
  fonts:
    - family: Lexend
      fonts:
        - asset: fonts/Lexend-Regular.ttf
          weight: 400
        - asset: fonts/Lexend-Medium.ttf
          weight: 500
        - asset: fonts/Lexend-SemiBold.ttf
          weight: 600
        - asset: fonts/Lexend-Bold.ttf
          weight: 700
        - asset: fonts/Lexend-ExtraBold.ttf
          weight: 800
    - family: Source Sans 3
      fonts:
        - asset: fonts/SourceSans3-Regular.ttf
          weight: 400
        - asset: fonts/SourceSans3-SemiBold.ttf
          weight: 600
        - asset: fonts/SourceSans3-Bold.ttf
          weight: 700
```

The family names `Lexend` and `Source Sans 3` must match exactly what `THType` and `THTheme` reference in `design_tokens.dart`.
