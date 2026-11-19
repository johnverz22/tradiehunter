# TradieHunter — Phase 4 (Homeowner) Audit & Issue Tracker

> **Audits:** `docs/todos/02_design_system_fix_plan.md` Fix-2 (homeowner) and the output in `docs/runs/v2/`.
> **Branch:** `dev` @ `5fdc781` · **Audited:** 2026-11-19 (rev 2; rev 1 on 2026-11-18 had no usable images) · **Scope:** mobile, homeowner persona.
> **Purpose:** a register only. Nothing here is fixed by this document. Each row has a status and, later, a PR. Fixes are batched by root cause (§8), not one by one.
> **Status values:** `Open` (confirmed) · `Verify` (probable, needs a look) · `Decision` (owner must choose) · `Fixed` (put the PR/commit in the row).

---

## 0. Evidence reviewed and its limits

Rev 1 found that the committed screenshots were old v1 captures. Commit `5fdc781` replaced them with a real `UI_V2=all` run, so this revision is based on images.

| Run | Folder | Text scale | Notes |
|---|---|---|---|
| 100% | `docs/runs/v2/screenshots/` | 1.0 | iPhone 17 Pro, light + dark, homeowner + tradie + shared, 0 exceptions logged |
| 200% | `docs/runs/v2/screenshots-text200/` | 2.0 | same matrix, 0 exceptions logged |

**What I reviewed:** every homeowner pair image in light at 100% and 200% (home, jobs, post job quick/project captures, choose tradie, tradie profile, job booked, extra cost, payment, payment status, dispute, quotes, request sent, review completion, review), a dark spot check of home, and a native-pixel crop of body text. **Not reviewed screen by screen:** dark theme (spot check only), chat, notifications, profile, shared/auth, radar, the job-state variants (cancelled, disputed, expired), cancel sheet, browse, categories, homeowner public profile.

**Caveats you gave (recorded here so they are not lost):**
- Tradie images are a **v1 baseline**: Phase 5 tradie v2 screens are not built (Fix-3 unchecked). They are out of scope for this audit.
- Intentional skips are in `skipped*.txt`: tradie offline confirm sheet (`01b_home_offline`), `06_extra_cost`, `07_complete`, `08_earnings`, and `02b_lead_expired` (needs the `SHOT_EXPOFFER_JOB` fixture).
- At 200% the driver logged non-fatal hit-test warnings on partly off-screen login and navigation targets. **Those warnings are not in the repo**: every `exceptions*.txt` is empty (P4-14).
- `v2Screens` flips stay gated on visual sign-off (§4.3 activation rule). Nothing here flips a flag.

---

## 1. Summary

| Section | Open | Verify | Decision | Fixed |
|---|---|---|---|---|
| 2. Evidence and process | 6 | 1 | 0 | 2 |
| 2b. Capture content problems | 4 | 0 | 0 | 0 |
| 3. Owner observation O-1: normal text is thinner than the mockup | 3 | 0 | 1 | 0 |
| 4. Owner observation O-2: the 200% scale is messy | 10 | 0 | 1 | 0 |
| 5. Visual deviations at 100% (confirmed from the images) | 14 | 2 | 0 | 0 |
| 6. Open items carried over from the fix plan (IDs P4-40…50 were P4-30…40 in rev 1) | 6 | 2 | 1 | 0 |
| **Total (53)** | **43** | **5** | **3** | **2** |

The five things that matter most:

1. **200% text scale is broken on most Phase 4 screens** even after `5fdc781`: the tradie name collapses to two characters on the choose-tradie card, sticky action bars truncate their buttons ("Refre…", "Approve …", "Request for a …"), and the home hero amount breaks into "$171 / .00" (§4).
2. **Thin text is real and measured:** the same body style at the same size has visibly thinner strokes in the app than in the mockup (§3).
3. **Several screens deviate in structure**, not polish: payment status has lost its icon and headline, the tradie profile has no Services and rates, extra-cost approval is below the fold, home category tiles are about half size (§5).
4. **Capture quality:** the `ho_request_sent` capture is the wrong screen, the payment capture is the "bank details unavailable" error, review shows the prompt rather than the rating sheet, and the run was made from a dirty tree (§2).
5. **The mockup PNGs are stale**, so some deviations (review chips, dispute reasons) are the mockup's fault, not the app's (P4-09).

---

## 2. Evidence and process

| ID | Sev | Status | Finding | Evidence | Fix (later) |
|---|---|---|---|---|---|
| P4-01 | P0 | Fixed | No committed Phase 4 run (rev 1). | Run committed in `5fdc781`: 100% and 200%, `UI_V2=all`. | — |
| P4-02 | P0 | Fixed | Pair images compared mockup against v1 (rev 1). | `compare/` regenerated, 54/60 paired; the 6 gaps are tradie T-04/T-05/T-06 (unbuilt). | — |
| P4-03 | P1 | Open | Legacy v1-era images still sit beside the new ones (e.g. `01_dashboard.png`, `02_jobs_list.png`, `12_payment.png`, `13_payment_status.png`; 59 homeowner files per theme vs 45 in the 200% run). `shot-map.json` falls back to old names, so a missing new capture would silently pair a v1 image. | `ls screenshots/light/homeowner` | Delete files not in the §7.3 name list; drop the legacy fallbacks from `shot-map.json`. |
| P4-04 | P1 | Open | The run was made from an uncommitted tree: `run.json` says `14e1feb-dirty` for both runs, started 09:19Z (100%) and 12:47Z (200%), and the 200% fixes landed afterwards in `5fdc781`. The images cannot be reproduced from a commit. | `screenshots*/light/homeowner/run.json` | Re-run from a clean commit; make `run-shots.sh` refuse a dirty tree (or warn loudly). |
| P4-05 | P1 | Open | Test baseline still the pre-fix `e2e-baseline-2026-11.md` (2026-11-17). Post-Phase 4 C1 (homeowner e2e suites) result not recorded. | `docs/runs/v2/e2e-baseline-2026-11.md` | Re-run C1, write a new baseline file. |
| P4-06 | P1 | Verify | Plan notes for 2.1 and 2.2 say the Dart was never formatted, analyzed or tested in the authoring sandbox. No later note closes them. | plan §6 | Run `dart format`, `flutter analyze --fatal-infos` and the named `phase4_*` tests. |
| P4-07 | P1 | Open | No Phase 4 id is in `v2Screens` (gated on sign-off). By default the shipped app is still v1 for homeowners. | `ui_flags.dart` | Flip one id at a time after fixes below. |
| P4-08 | P2 | Open | Golden harness: 393×852, 1×, icon font not loaded (icons are squares), no scaled variant. | `mobile/test/ui/goldens` | Load the icon font; add `_200` goldens (P4-11). |
| P4-09 | P1 | Open | **Mockup PNGs are stale.** `index.html` and `ast/screens.mjs` no longer contain "What stood out" or "Hours too high"/"What would be fair" (D-9, D-10 amendments), but `mockups/png/` (exported in `12bb2cf`, before those edits) still shows them, so pair images for review and dispute compare against an outdated mockup. | grep of AST vs PNGs | Re-run `node docs/design/mobile/tools/mockup-shots.mjs`, then `scripts/compare-shots.py`; add a CI check that PNGs are newer than the AST. |

### 2b. Capture content problems

| ID | Sev | Status | Finding |
|---|---|---|---|
| P4-15 | P1 | Open | `ho_request_sent` at 100% is **not** the request-sent screen: it is Choose a Tradie again (200% shows the right screen). Driver timing or navigation issue. Running, expired and declined states (H-14) are therefore unseen at 100%. |
| P4-16 | P1 | Open | `ho_payment` shows only the **"bank details unavailable"** error state. The happy path (bank details, copy reference, upload tile, "Upload bank receipt") is never captured; its absence also means the bank config is missing in the capture environment. |
| P4-17 | P2 | Open | `ho_review` shows the "Leave a review" prompt page, not the rating/comment sheet. The sheet is not captured. |
| P4-18 | P2 | Open | Captures are the first viewport only. Below-the-fold content (home Active jobs, "Top rated", trust note; job-detail timeline; bottoms of forms) cannot be verified. Only `06b_post_quick_bottom` exists. Greeting shows "Homeowner" (fixture user; the plan says fall back to no name, so check the fallback separately). |

---

## 3. Owner observation O-1: normal text is thinner than the mockup

**Confirmed.** I cropped the same body style (`body`, 15 pt, Source Sans 3 w400) from the mockup PNG (`ho_payment_status-light`, 1170 px wide) and from the app capture (`16_payment_status_review`, 1206 px wide), both at 3×, at native pixels. Glyph size and shape match; stems in the mockup are clearly heavier. Both use the same declared weight, so this is not a wrong font file or a wrong token.

| ID | Sev | Status | Finding / cause |
|---|---|---|---|
| P4-10 | P1 | Open | Every reading style (`body`, `meta`, `input`, `detail`) is Source Sans 3 Regular (400), the lightest bundled weight. Medium (500) is bundled and declared in `pubspec.yaml` but no token uses it. Fonts verified as genuine static weights (stem of `l`: 135 → 209 units from 400 to 700). Contrast passes (`textSoft` 6.5–7.0:1 light), so this is stroke weight, not colour. |
| P4-10b | P1 | Open | The gap comes from the renderer: the mockup is rasterised by desktop Chromium from Google Fonts, which draws the same weight heavier than Flutter on iOS. The mockup is therefore a poor reference for stroke weight. Light-grey `textSoft` text at 13 pt (meta, labels, kv labels) suffers most. |
| P4-10c | P2 | Open | `TYPOGRAPHY.md` pubspec snippet omits Source Sans 3 Medium, which the real `pubspec.yaml` declares. |
| P4-10d | P1 | Decision | Pick: **(A)** body, meta, input, detail → w500 (one edit in `tokens.json`, then `node docs/design/mobile/tools/build.mjs`, regenerate goldens); **(B)** only `meta` and `detail` → w500; **(C)** keep 400 and change how the mockup is rendered (heavier PNG export) so it stops over-promising. Recommend A or B; try a 400/500 A/B on one screen on the simulator first. Headings (Lexend 600) look equivalent in both. |

---

## 4. Owner observation O-2: the 200% scale is messy

**Confirmed.** `5fdc781` fixed three real defects (`THGrid` fixed aspect ratio clipping tile labels, `THBadge` labels overflowing rows, `ThStateView.loading` nesting a viewport). The images show much more remains. The app does not clamp text scale anywhere, so every screen must absorb 2×.

| ID | Sev | Status | Screen | What the 200% image shows |
|---|---|---|---|---|
| P4-11 | P0 | Open | all | No safety net: only 3 of 16 `phase4_*` test files set a text scaler (`choose_tradie`, `post_job`, `radar`), no golden is scaled, and the clean 200% matrix did not stop these defects shipping. |
| P4-12 | P1 | Decision | all | Policy. Fixed chrome (dock labels, badges, eyebrows, pills, button labels) becomes 21–32 pt text. Choose: **(A)** unclamped everywhere, fix each overflow; **(B)** clamp chrome only (about 1.3×, `MediaQuery.withClampedTextScaling`) and keep body, headings and money unclamped. Recommend B. |
| P4-13 | P0 | Open | `ho_choose_tradie` | **Tradie name collapses to "Te / s…"** and the rating line breaks into "5 ( / .0", squeezed between the avatar and the rate column. Sort/filter pills wrap into five rows, pushing the list down. |
| P4-13b | P0 | Open | sticky action bars (systemic) | Button labels truncate with an ellipsis: tradie profile "Mes…" / "Request for a …", review completion "Dispute a…" / "Approve …", request sent "Pick some…" / "Cancel re…", payment "Refre…". The bar is a fixed single row. |
| P4-13c | P0 | Open | `ho_payment` | Sticky bar: the disabled-reason text becomes a tall centred column (about a third of the screen) overlaying the error card, with the button truncated. At **100%** the label already truncates ("Refresh pay…"). |
| P4-13d | P1 | Open | `ho_home` | Hero amount breaks to "$171 / .00" and collides with "Pay now"; category labels break mid-word ("Plumbi/ng", "Electric/al", "Carpen/try", "Paintin/g"), two rows are covered by the dock; dock labels are huge. |
| P4-13e | P1 | Open | `ho_jobs` | Segmented control label breaks "Complet/ed"; job titles split mid-number ("17950048 / 82") and fight the status badge; price and "Open chat" button squeeze together. |
| P4-13f | P1 | Open | `ho_post_job` | Placeholders ellipsise ("e.g. Fix a leaking kitch…"), eyebrows become huge caps, "Quick job · hourly" wraps in the segment. Sticky CTA plus its hint use roughly a quarter of the viewport. |
| P4-13g | P1 | Open | `ho_request_sent` | Countdown label "left to respond" overlaps the ring stroke; the ring sits inside a card under the rate row instead of leading the screen. |
| P4-13h | P2 | Open | `ho_quotes`, job detail | Tradie name wraps to three lines beside the badge; kv rows wrap values ("1 Test St, / Auckland") acceptably but waste width. |
| P4-14 | P2 | Open | harness | The 200% hit-test warnings (partly off-screen login and nav targets) are not saved: `exceptions*.txt` are empty. Make non-fatal warnings write to `warnings.txt` too, so the accessibility pass has them. |

---

## 5. Visual deviations at 100% (confirmed from the images)

| ID | Sev | Status | Screen | Deviation |
|---|---|---|---|---|
| P4-20 | P1 | Open | `ho_home` | Category tiles are small icon chips (about 50 px) instead of the mockup's large rounded squares, with a large gap between the two rows. |
| P4-21 | P2 | Open | `ho_home` | Search field is taller than the mockup and its icon and text sit at the top rather than vertically centred. |
| P4-22 | P2 | Verify | `ho_home` | Greeting reads "Homeowner" (fixture). Confirm the fallback is "no name" per §4.3.1 (P4-18). |
| P4-23 | P2 | Open | `ho_jobs` | 6 progress segments (mockup 5, already noted); each card adds a price and an "Open chat" row the mockup does not have; badge "Payment due" vs mockup "Pay now"; no "Quotes" badge (known). |
| P4-24 | P1 | Open | `ho_post_job` | At 100% the sticky CTA is translucent and form text shows through it ("Blank means total is confirmed…" behind "Choose a tradie"). Extra helper lines and section headings ("WHAT DO YOU NEED?", "WHEN DO YOU NEED HELP?") are not in the mockup; the description box is much taller. |
| P4-25 | P1 | Open | `ho_choose_tradie` | Shows "0.0 km away" and wraps it onto two lines; the plan promised a distance fallback ("Distance unavailable"). Back control is an arrow, mockup chevron. |
| P4-26 | P1 | Open | `ho_tradie_profile` | **No "Services and rates" card** (mockup's rate-locked info). Hero shows 2 stats where one is "2026" with a second "Member since" line repeating it; mockup has rating, distance, jobs done. Sticky bar is translucent and reviews show through; actions read Message / Request for a job vs Back / Request this tradie. |
| P4-27 | P2 | Open | `ho_job_booked` | Title says "Booked", not "Booked for <date>"; no sticky "Message <name>" CTA (inline Message button instead); kv values left-aligned in a column, mockup right-aligned with dashed dividers; timeline is a simple checklist, not the connected 5-stage stepper; profile link uses an external-link icon for an in-app screen. |
| P4-28 | P1 | Open | `ho_extra_cost` | The extra-cost request, the screen's primary action, is **below the Job details card** (below the fold at 100% and 200%). Mockup puts it directly under the status card. No "Checked in" line. |
| P4-29 | P1 | Open | `ho_payment_status` | **Lost its structure:** the mockup has a large icon tile, a headline "Receipt sent for review" and subtitle; the app shows a small pill and a paragraph, leaving most of the screen empty. The "Under review" badge replaces the mockup's "In review". |
| P4-30 | P2 | Open | `ho_payment` | "Method: BankTransfer" prints the raw enum value (needs a label). |
| P4-31 | P1 | Open | `ho_dispute` | Pills are API reasons (Poor Quality, Damage to Property, Overcharged, Other) as decided (D-10) but the mockup PNG still shows the old set (P4-09); title "Open dispute" vs "Dispute amount"; evidence is a large empty tile instead of a dashed "Add evidence" row; "DETAILS" eyebrow is "TELL US WHAT HAPPENED". |
| P4-32 | P1 | Open | `ho_quotes` | No "View quote" button and no duration / "fixed" pricing label (mockup shows both), so inclusions and start dates are unreachable from the list. No rating star. Pending-invite row omitted (known, H-08). |
| P4-33 | P1 | Open | `ho_review_completion` | Button reads "Approve & pay", not "Approve $<amount>" (H-10 acceptance); shows a **raw timestamp** "2026-11-18 17:02:50.152525" under "Completion submitted"; on-site times absent (no DTO, known). |
| P4-34 | P2 | Open | `ho_review` | Mockup PNG still shows chips (P4-09). Rating sheet not captured (P4-17). |
| P4-35 | P2 | Verify | dark theme | Home dark mirrors light (same defects, tokens look right). The rest of dark was not reviewed; the same pair images exist and need a pass. |

---

## 6. Open items carried over from the fix plan (IDs P4-40…50 were P4-30…40 in rev 1)

| ID | Sev | Status | Item | Source |
|---|---|---|---|---|
| P4-40 | P1 | Decision | **D-7 "Top rated near you"** hidden: the search DTO has no rating or review count. Backend field/endpoint, or drop from the mockup. | 2.1 |
| P4-41 | P2 | Open | Home search opens `/find-tradie` but cannot focus; first-time empty state has no illustration. | 2.1 |
| P4-42 | P2 | Open | `ho_post_job` project mode: bundled extras still sit between budget and WHEN; Hours still shows in Project mode. The project capture exists (`06c_post_project`) but was not reviewed. | 2.2 |
| P4-43 | P1 | Verify | Not yet reviewed against the images: radar `07_radar` / `07b_radar_error`, notifications, chat with approved adjustment, cancel sheet, job cancelled / disputed / expired, browse, categories, homeowner public profile. | 2.3, 1.3, 2.4, 2.6 |
| P4-44 | P2 | Open | Booked/extra-cost omit check-in time and on-site duration (no DTO field). | 2.4 |
| P4-45 | P2 | Open | Gallery goldens for `ho_jobs` and `ho_tradie_profile` need deliberate regeneration. | 2.1, 2.2 |
| P4-46 | P1 | Verify | Confirm the fixture/accept backend fix (Fix-0.3) lets payment, dispute, cancellation and lifecycle suites reach their first assertion. | 0.3, P4-05 |
| P4-47 | P2 | Open | `v2_flows` (quotes, extra cost, tradie profile) needs a re-run with `UI_V2=all`. | baseline |
| P4-48 | P1 | Open | Fix-2 "Done when" (every §3.1 homeowner row ✅, all ids in `v2Screens`, C0 and C1 pass) is not met. | plan §6 |

---

## 7. Tradie baseline (informational)

Tradie captures are v1 (Phase 5 not started). Recorded skips: `01b_home_offline` (confirm sheet), `06_extra_cost`, `07_complete`, `08_earnings`, `02b_lead_expired` (missing `SHOT_EXPOFFER_JOB`). Coverage gaps for T-04/T-05/T-06 are expected. No tradie findings are raised here.

## 8. Suggested order (fix later, batched by root cause)

1. **P4-13b / P4-13c (sticky action bars):** one shared component fix (stack buttons vertically and let the hint wrap at large scale; opaque bar), which clears four screens and P4-24/P4-26 bleed-through.
2. **P4-13 (choose-tradie card):** give the name flexible width and move rating/rate below at large scale.
3. **P4-12 decision, then P4-13d–h and P4-11:** clamp policy, then fix remaining overflows by component (grid labels, hero amount, segmented control, badges) and add 200% tests/goldens for the 13 uncovered screens.
4. **P4-10d decision:** weight A/B, then one token edit.
5. **P4-09, P4-03, P4-04, P4-15–18:** regenerate mockup PNGs, clean the capture folders, re-run from a clean commit with the missing captures.
6. **Structural deviations (P4-26, P4-28, P4-29, P4-32, P4-33, P4-20):** per screen, in journey order.
7. Re-run both capture sets, update statuses here, then flip `v2Screens` ids one at a time.

## 9. How this file is maintained

- Update the **Status** column in place; when fixed, put the commit/PR in the row.
- New findings get the next free `P4-` id under the closest section. Start `06_…` only for a new phase.
- Keep `Verify` rows until a device capture settles them.
