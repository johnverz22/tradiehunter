---
name: design-vs-run-crosscheck
description: Compare rendered mockup frames with app run screenshots (rendered `docs/design/frames` vs the screenshot run folder) and produce a discrepancy table that separates UI deviations from test-fixture data and from unverifiable states. Use after a screenshot sweep or before signing off a screen.
---
# Design vs run cross-check

1. Pair frames to screenshots by the run folder's README mapping if it has one, else by screen name (H07↔01_dashboard, T19↔tradie/01_dashboard...). Keep a theme per pass.
2. `python3 scripts/make_pairs.py --design frames --run <screens dir> --out pairs.png --pair H07-light=homeowner/01_dashboard ...` makes side-by-side sheets. View them at full size for any screen you will report; small sheets only support impressions.
3. For each difference record: screen, design, run, **type**, likely cause, fix.
   - UI: layout, size, icon, colour, rule (one amber primary, 12px floor).
   - data: fixture strings ("Shot PROG 1794…"), empty lists.
   - unverifiable: backend states (bank details unavailable). Say what to re-run.
4. Cluster by cause. Repeated causes become a widget or token fix, not N screen fixes.
5. State what you did not compare (themes, screens, scroll positions).
Report as a table: screen | design | run | type (UI/data/unverifiable) | cause | fix.
