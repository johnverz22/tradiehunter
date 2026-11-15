# Prompt: Generate a screen from a mockup

> Use with any coding agent (Claude Code, Cursor, Windsurf, Gemini CLI).
> Replace `{FRAME}` (e.g. H13) and `{FEATURE}` (e.g. chat).

---

You are implementing the `{FRAME}` screen of the Fixo mobile app (TradieHunter
repo). Work through the `new-screen-from-mockup` skill in `agent/skills/`.

Context you must load first:
- `agent/AGENT_GUIDE.md` — architecture, token tables, component mapping
- `docs/design/v1.6.2/html/` — find every `[data-frame]` whose id starts with
  `{FRAME}`; read the frame markup and the `kit.css` rule for EVERY class used
- `tools/design2flutter/output/{FRAME}_*.dart` — the generated scaffold

Task:
1. Scaffold with the transpiler (do not hand-copy pixel values):
   `bash agent/skills/new-screen-from-mockup/scripts/new-screen.sh {FRAME} {FEATURE}`
2. Move the file into `mobile/lib/views/{FEATURE}/`, rename the class
   `{Feature}Screen`, wire the existing view model / repository for this feature.
3. Replace `TH*` scaffolding with existing `Fixo*` widgets where the mapping
   table (AGENT_GUIDE §4) says they exist.
4. Stress-test: long strings, 1.3x text scale, 360dp width, light/dark/outdoor.

Hard constraints:
- Every color via `THColors`; every dimension via Space/Radii/Sizes; type via
  THType. No `Color(0x…)`, no magic numbers.
- One amber primary CTA + at most one urgency element.
- `.faderow` → horizontal ListView with fade; `.badges` → Wrap.
- Dark mode = token swap only; no theme conditionals in the view.

Deliver: the screen file, router registration, and a note listing any `TH*`
contracts you had to implement. Finish with `dart format`, `flutter analyze`.
