# Prompt: Run a UI audit

> Run as-is; optionally pass a design root (default docs/design/v1.6.2).

---

You are auditing the TradieHunter design mockups. Run the `ui-audit` skill in
`agent/skills/ui-audit/`:

```
bash agent/skills/ui-audit/scripts/audit.sh docs/design/v1.6.2
```

Then:
1. Read `/tmp/audit-v1.6.2.json` (frames[].{clip,trunc,tap,small,contrast,
   a11y,orange,inlineColor} and static[]).
2. Compare every finding against the known-false-positive list in the skill
   (S01 splash z-index, wordmark span.o tap hits, faderow intentional cuts,
   hero-glass constants). Do not "fix" those.
3. For each REAL finding, classify it against the fix spec
   (`docs/design/v1.6.1/FIX_SPECIFICATION.md`):
   - F-101 class (layout break) / F-102–105 (dark contrast) /
     F-106–107 (tokens, consistency) / F-108–111 (hit areas, a11y) /
     F-112 (orange budget) / F-114–118 (token hygiene)
4. Fix in the mockup SOURCE (`docs/design/v1.6.2/html/`), never in `build/`.
   If a systematic fix is warranted, extend `tools/fix_v162.py` (idempotent)
   instead of hand-editing.
5. Re-run the audit to zero; report gates before → after and files touched.

Rules of engagement: the probe proposes, you verify — open the flagged frame
and look at it before changing anything. Report anything you did not check.
