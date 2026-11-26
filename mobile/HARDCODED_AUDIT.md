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

Known one-offs still in code: `THButton` secondary border width (1.5), `THButtonKind.inverse` colours, selected slot-chip
border width in `th_schedule_sheet.dart`. Move them into tokens when next touched.
