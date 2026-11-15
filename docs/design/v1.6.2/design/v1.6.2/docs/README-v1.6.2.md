# TradieHunter design system v1.6.2

Corrected drop of `docs/design/v1.6.1` produced by the v1.6.1 audit
(`../v1.6.1/FIX_SPECIFICATION.md`, findings F-101…F-118). Same structure as
v1.6.1 — this directory is the **source of truth for new screens and for the
HTML-to-Flutter transpiler** (`tools/design2flutter/` at the repo root).

## What changed vs v1.6.1

- **F-101** iPad master-detail frames no longer overflow: phantom status-bar
  column removed, `.md` gains `min-width:0`.
- **F-102/103** status-strip pills fixed to white ink (strip is navy in both
  themes); dark `pill-problem` uses `--ink-danger-d`.
- **F-104** hero stat tiles use semantic tokens (`--text-brand`,
  `--success-text`) — readable in dark.
- **F-105** all 29 inline `background:var(--surface)` overrides on progress
  segments deleted (they made dark segments invisible).
- **F-106** outdoor `--line` typo fixed: `rgba(25,57,87,.28)`.
- **F-107** shared classes (`.ill-card`, `.listitem`, `.herotile`, `.svc`,
  `.blob-*`) promoted into `kit.css`.
- **F-108/109** tonal button and map back button restored to the 48dp floor.
- **F-110/111** every icon-only control labelled (`aria-label`), every `<img>`
  has `alt`.
- **F-112** orange budget restored (max 2 per screen: 1 CTA + 1 urgency).
- **F-113** `:focus-visible` rings for keyboard users.
- **F-114/115/118** frequent inline colors tokenised (`--tint-brand`,
  `--av-tradie`/`--on-av-tradie`, `--press`, `--track`, `--on-hero-soft`,
  `--on-hero-faint`, `--hero-track`); hero-glass constants documented.
- **F-116/117** `.badge.good` dark override; annotation labels ≥ 12px.

## Verify

```bash
python3 tools/audit_full.py . ../v1.6.1/docs/audit-v162.json   # needs playwright + chromium
python3 tools/fix_v162.py                                       # idempotent; re-applies cleanly
```

Gates: see §4 of the fix specification. All gates PASS as shipped.

## Rebuild artifacts

`./build.sh` (needs beautifulsoup4 + playwright) regenerates `build/` and
`frames/` from `html/`.
