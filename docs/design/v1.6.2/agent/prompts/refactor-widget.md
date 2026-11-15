# Prompt: Refactor a widget

> Replace `{TARGET}` (file or widget name).

---

You are refactoring `{TARGET}` in the Fixo mobile app (TradieHunter repo).
Follow the `widget-refactor` skill in `agent/skills/widget-refactor/`; read
`agent/AGENT_GUIDE.md` §3–4 for the token and naming tables first.

Steps:
1. Show the duplication/size problem you are solving (occurrences or line count).
2. Extract to the right home: `Fixo<Thing>` (product) or `TH<Thing>`
   (design-system contract, signature from
   `tools/design2flutter/th_components.dart`).
3. Parameters are semantic (label, kind, selected) — never presentational
   (color, radius) and never pixels the caller computed.
4. Update all call sites; if the mockup vocabulary is affected, update
   `tools/design2flutter/src/widgetMap.js`, regenerate and diff.
5. Verify with `bash agent/skills/widget-refactor/scripts/refactor-check.sh`
   — zero raw colors, zero inline fontSize, zero theme conditionals in views.
6. `dart format`, `flutter analyze`, `flutter test`.

Do not change visual behavior. If the refactor reveals a mockup/token gap,
stop and report it against the fix-spec taxonomy instead of inventing values.
