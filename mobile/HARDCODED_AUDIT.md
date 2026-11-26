# Hardcoded-values audit (v2)

Rule: no raw spacing, radius, font size/weight, colour, alpha, duration or component size in `lib/ui/**`
outside `lib/ui/design/th_tokens.dart`. Tokens come from `docs/design/mobile/tokens/tokens.json`.

| Literal | Use instead |
|---|---|
| `EdgeInsets` / `SizedBox` numbers | `Space.s1`…`Space.s9` |
| `BorderRadius.circular(N)` | `Radii.*` |
| `fontSize` / `FontWeight.wNNN` | `THType.*`, `THText(style: ...)` |
| `Color(0x…)`, `Colors.white/black/red` | `context.th.<name>` (`Colors.transparent` allowed) |
| `Duration(milliseconds: N)` | `THDurations.*` |
| raw button/input/avatar sizes | `Sizes.*` |

Quick scan (should print only token files and documented one-offs):

```sh
cd mobile
grep -rnE "Color\(0x|Colors\.(white|black|red|grey)|BorderRadius\.circular\([0-9]|Duration\(milliseconds: [0-9]|fontSize: [0-9]" lib/ui \
  | grep -v "lib/ui/design/th_tokens.dart"
```

Done (2026-11-26): inline `FontWeight.wNNN` → `FW.*` and border width `1.5` → `Sizes.borderStrong` across `lib/ui`.

Still open (all inside the widget library `lib/ui/design/th_widgets.dart` unless noted):
- Small font sizes (9.5, 10.5, 11, 11.5, 12.5, 13, 14.5, 15) used as `copyWith(fontSize: …)` / `TextStyle`; also `tr_job_parts.dart:112`, `tr_job_inprogress_screen.dart:325`, `tr_job_booked_screen.dart:341`.
- Colours: `THButtonKind.inverse` / avatar inverse (`Color(0xFF1E3A8A)`, `Colors.white`), shadow tints (`0x0F0F172A`, `0x101E3A8A`), glass badge alpha 0.18, switch thumb white.
- `tr_photo_viewer.dart`: `Colors.black/white/white54/white70` (full-screen viewer chrome).
- Radii: 3, 5, 8, 36 in progress bars, dots, bars and illustration.

Tracked as plan item 6.12-h. Add tokens to `tokens.json`, run `build.mjs`, then replace.
