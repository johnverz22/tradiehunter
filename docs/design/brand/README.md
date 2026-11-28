# TradieHunter Brand Art (Canonical Source)

Canonical source art for TradieHunter (white-label code identifiers remain `Fixo`).

## Inventory

| File | Use |
|---|---|
| `svg/logo.svg` | Colour emblem (navy house `#1E3A8A`, light-blue hammer `#8FA8F2`, orange handle `#B45309`), transparent background. Used on light surfaces. |
| `svg/logo-white.svg` | All-white emblem for navy / dark surfaces (`sidebar`, `hero`, `on-dark`, dark theme, email header PNG). |
| `svg/logo-monochrome.svg` | All-black emblem (`#000000`), reference only. |
| `svg/logo-on-white.svg` | Emblem on a white 512x512 square, reference only. |
| `animated/tradiehunter_loader.json` | Lottie tradie lookup animation (720x720, 60 fps, 312 frames / 5.2 s, shape layers only). |
| `animated/README.md` | Usage guide for the Lottie loader. |

## Colour Rules

- Light theme / light surfaces: `svg/logo.svg` (`#1E3A8A` house, `#8FA8F2` hammer, `#B45309` handle).
- Dark theme / dark surfaces (`.sidebar`, `.hero`, `.on-dark`, mobile dark mode): `svg/logo-white.svg`.
- Never re-export, recolour, or re-trace these files; copy byte-for-byte to target platforms.
