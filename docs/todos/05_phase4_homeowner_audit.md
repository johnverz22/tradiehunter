# TradieHunter — Phase 4 (Homeowner) Audit & Issue Tracker

> **Audits:** `docs/todos/02_design_system_fix_plan.md` Fix-2 (homeowner) and the output in `docs/runs/v2/`.
> **Branch:** `dev` @ `14e1feb` · **Audited:** 2026-11-18 · **Scope:** mobile, homeowner persona, light + dark.
> **Purpose:** a register only. Nothing here is fixed yet. Each row gets a status and, later, a PR. Fixes are batched by root cause in §6, not fixed one by one.
> **Status values:** `Open` (confirmed) · `Verify` (probable, needs a device run) · `Decision` (owner must choose) · `Fixed` (fill in with PR).

---

## 0. Read this first: what could and could not be audited

**The screenshots committed in `docs/runs/v2/screenshots/` are not a Phase 4 run.** They are the old v1-era captures the fix plan was written from:

- `light/homeowner/01_dashboard.png` shows the **v1** dashboard (gradient header "KIA ORA / Homeowner", Space Grotesk, translucent dock with orange centre button). The v2 `ho_home` (greeting, attention hero, search, category tiles) is not in any image.
- The homeowner images last changed in `541629b` (2026-11-17), before every Phase 4 commit. `00_post_login.png` and `01_dashboard.png` are byte-identical.
- `v2Screens` in `lib/ui/ui_flags.dart` contains **no `ho_*` id**, so any run without `UI_V2=all` renders v1 for every Phase 4 screen. There is no `run.json` beside the images to show which flags were used.
- `compare/` pair images and `coverage.md` were generated from those old captures, so "paired" means *v2 mockup vs v1 screen*.

**Therefore:** I could not inspect the Phase 4 e2e screenshots you mention (they are not on `dev`, or were not pushed). This audit uses what is verifiable in the repo: the code, tokens, font assets, tests, goldens (v2 widget renders at 393×852, 1×) and the plan's own notes. Anything that needs a real device is tagged `Verify`. **Push the new run (see P4-01) and I will convert every `Verify` row to confirmed or rejected from the images.**

---

## 1. Summary

| Area | Open | Verify | Decision |
|---|---|---|---|
| Evidence and process (P4-01…08) | 7 | 1 | 0 |
| Owner observations (P4-10…14) | 4 | 2 | 2 |
| Visual deviations seen in goldens (P4-20…25) | 0 | 6 | 0 |
| Carried-over open items from the fix plan (P4-30…40) | 8 | 1 | 2 |

Two root causes explain most of what you described:

1. **Typography weight:** the whole reading layer (body, meta, input, detail) is the lightest bundled weight (400). The mockup is declared at the same weights, so the gap is rendering plus a design-token choice, not a wrong font file (§3).
2. **200% text scale has no safety net:** the app does not clamp text scale, only 3 of 16 Phase 4 test files set a text scaler, no golden is scaled, and no 200% capture exists (§4).

---

## 2. Evidence and process

| ID | Sev | Status | Finding | Evidence | Fix (later) |
|---|---|---|---|---|---|
| P4-01 | P0 | Open | No committed Phase 4 run. Images are v1. | §0. `ui_flags.dart` `v2Screens` has only shell/auth/shared ids. | Run `UI_V2=all ./scripts/run-shots.sh` (both themes, also `SHOT_TEXT_SCALE=2.0`), commit under `docs/runs/v2/`, replacing the legacy images. |
| P4-02 | P0 | Open | `compare/` pairs are mockup vs **v1**, so they cannot be used to judge v2. `coverage.md` shows 6 homeowner frames with no capture at all: `ho_post_project`, `ho_quotes`, `ho_request_sent`, `ho_review_completion`, `ho_review`, `notifications` (plus 7 tradie frames, expected). | `compare/coverage.md` | Re-run `scripts/compare-shots.py` after P4-01; use `--strict` as a PR gate. |
| P4-03 | P1 | Open | Committed capture names are the legacy set (`00_post_login` … `16_homeowner_profile`, 18 per theme). The §7.3 set (65 names, e.g. `01_home`, `06_post_quick`, `16_payment_status_review`) is absent, and `shot-map.json` mixes old and new names. | `ls light/homeowner`, `coverage.md` | Capture with the §7.3 names; `scripts/check-capture-names.py` must pass. |
| P4-04 | P1 | Open | No `run.json` next to the images (flags, commit, device, text scale are unrecorded). | `find docs/runs -name run.json` → none | Produced by `run-shots.sh` already; commit it. |
| P4-05 | P1 | Open | The only e2e record, `e2e-baseline-2026-11.md` (2026-11-17), predates the backend accept fix (Fix-0.3) and all Phase 4 work. It lists `v2_flows` 0/4 with a "rendering/layout exception" and 28 / 32 exceptions in the two capture suites. No post-Phase 4 result is recorded; the Fix-2 box "run C1 and attach results" is unticked. | baseline doc; plan §6 Fix-2 | Re-run C1 (`UI_V2=all`, homeowner), write `e2e-baseline-<date>.md`, link exception logs (`exceptions.txt`). |
| P4-06 | P1 | Verify | Plan notes for **2.1** (`ho_home`, `ho_jobs`) and **2.2** (`ho_post_job`, `ho_choose_tradie`, `ho_tradie_profile`, `ho_request_sent`) say the Dart was hand-wrapped and never formatted, analyzed or tested. Later commits only record verification for 0.1–1.3 and 2.3–2.6. | plan §6 notes 2.1, 2.2 | Run `dart format`, `flutter analyze --fatal-infos` and the named `phase4_*` tests; tick or file failures. |
| P4-07 | P1 | Open | No Phase 4 screen is activated (`ho_home`, `ho_jobs`, `ho_post_job`, … all absent from `v2Screens`; `ho_radar`, `ho_job_detail`, `categories`, `browse_tradies`, `ho_user_profile` are in `nonGalleryV2Screens` only). By default the shipped app is still v1 for homeowners. | `ui_flags.dart` | Flip ids one at a time per the activation rule (pair image light + dark, 100% and 200% text, flow test). |
| P4-08 | P2 | Open | Golden harness limits what can be audited: single 393×852 viewport, 1×, no scrolled content; Material icon font not loaded so icons render as squares; no golden filename indicates a scaled variant (62 files, all `<id>_{light,dark}.png`). | `mobile/test/ui/goldens`, `gallery_goldens_test.dart` | Load the icon font in the golden setup; add `_200` variants for the top screens (see P4-11). |

---

## 3. Owner observation O-1: normal text is thinner than the mockup

**Observed:** body and secondary text look slimmer, with less stroke and lower readability than the mockup.

### What I ruled out

| Check | Result |
|---|---|
| Font files are real static weights | Pass. `Lexend` 400→800 and `Source Sans 3` 400→700, each with its own `usWeightClass`; stem width of `l` grows 103→186 (Lexend) and 135→209 (Source Sans 3). Not one file copied four times. |
| Declared weights differ from the mockup | No. `tokens.json`, `design_tokens.dart`, `th_tokens.dart` and `mockup.css` all use headings 600 and body/meta/input/detail 400. |
| Colour too faint | No. `textSoft` on paper/surface is 6.5–7.0:1 light, 7.4–8.1:1 dark (contrast report). |
| Weight lost by a widget | Not found. `THText` only changes weight for `bold` (→ w700); the raw `Text` calls I sampled in `lib/ui/shared` set `THType` styles explicitly. |

### What is left

| ID | Sev | Status | Hypothesis | How to settle it |
|---|---|---|---|---|
| P4-10 | P1 | Open | **Every reading style is the lightest bundled weight.** `body`, `meta`, `input` and `detail` are `w400` in Source Sans 3 Regular, a light face at 13–15 pt. Source Sans 3 **Medium (500) is bundled and declared in `pubspec.yaml` but no token uses it**. | Add a body-weight token and A/B: body/meta at 400 vs 500 on a simulator, same screen, same scale. |
| P4-10b | P1 | Verify | **Renderer difference.** The mockup is rendered by desktop Chromium from Google Fonts at 3×; the app is rendered by Flutter on iOS. Chromium's text rasterization usually looks heavier than Flutter's for the same weight, so identical numbers can read as "thinner". | Same A/B: crop the same text from `docs/design/mockups/png` and from a device capture at equal pixel size. |
| P4-10c | P2 | Open | Docs drift: `TYPOGRAPHY.md` pubspec snippet omits Source Sans 3 Medium, which the real `pubspec.yaml` declares. | Update `TYPOGRAPHY.md` when P4-10 is decided. |
| P4-10d | P1 | Decision | If A/B confirms the gap, choose: **(A)** body, meta, input, detail → w500 (one token edit in `tokens.json`, run `node docs/design/tools/build.mjs`, regenerate goldens); **(B)** only `meta` and `detail` → w500, body stays 400; **(C)** keep 400 and change the mockup render to match. Recommend A or B by the A/B result. Not a per-screen fix. | Owner picks after the A/B. |

---

## 4. Owner observation O-2: the 200% scale is messy

**Observed:** at 200% text scale the layouts break down.

| ID | Sev | Status | Finding | Evidence |
|---|---|---|---|---|
| P4-11 | P0 | Open | **No safety net for 200%.** Only 3 of 16 `phase4_*` test files set a text scaler (`choose_tradie`, `post_job`, `radar`); home, jobs, booked, extra cost, review, review completion, payment, dispute, quotes, tradie profile, public profile, browse and categories never render above 1×. No golden is scaled. No 200% capture exists. | `grep -c textScale test/ui/phase4_*` |
| P4-12 | P1 | Decision | **Policy.** The app does not clamp text scale anywhere (no `textScaler` clamp in `lib/`), so every fixed-size element must absorb 2×. That is the right default for accessibility, but chrome built for one line (dock labels at 10.5 pt, badges, 11 pt eyebrows, segmented pills, sticky CTAs) turns into 21–22 pt text. Choose: **(A)** keep unclamped everywhere and fix each overflow; **(B)** clamp chrome only (dock, badges, pills, app bar title, ~1.3×) with `MediaQuery.withClampedTextScaling`, keep body, headings and money unclamped. Recommend B. | `lib/` grep; `th_shell.dart` dock label; `tokens.json` `railLabel`, `label`, `compact` |
| P4-13 | P1 | Verify | Probable break points to check at 200% on a 360 and a 393 pt device: dock (a 2.0 px overflow already had to be fixed at 1×, Fix-1.1); `ho_home` hero amount + Review button side by side, and the 4×2 category grid labels; `ho_choose_tradie` card with name, rate and three badges; booked/extra-cost kv rows (label left, value right); status badge + 5/6-segment progress on job cards; sticky CTA plus disabled-reason line leaving little scroll room (post job, dispute, payment); payment bank-detail rows with copy icons; `ho_post_job` WHEN pills with keyboard open. | Plan §8 step 1 lists the 12 screens to capture at 200% |
| P4-14 | P1 | Open | The harness cannot yet show it: `SHOT_TEXT_SCALE` is wired in `run-shots.sh` and recorded in `run.json`, but no 200% capture is committed. | `run-shots.sh`; P4-01 |

---

## 5. Visual deviations seen in the goldens (verify on device)

Source: side-by-side of `mobile/test/ui/goldens/<id>_light.png` against `docs/design/mockups/png/<id>-light.png`, at 393 pt width. Goldens are 1× and use a test icon font, so only layout and weight cues count. Each row needs a device capture to confirm.

| ID | Sev | Status | Screen | Deviation |
|---|---|---|---|---|
| P4-20 | P1 | Verify | `ho_home` | Category tiles look much smaller than the mockup (roughly 45 pt vs 80 pt by eye), so the 4×2 grid is less prominent and spaced differently. |
| P4-21 | P1 | Verify | `ho_job_booked` | The shell dock (with the centre quick-match button) is drawn over the sticky **Message Aroha** CTA. The mockup has no dock on this pushed screen. Could be a golden-harness artifact; if not, the CTA is hidden and the fix plan's "tradie dock has no centre action" question also applies to homeowner detail routes. |
| P4-22 | P2 | Verify | `ho_job_booked` | Key/value rows: values are left-aligned in a column with solid dividers; the mockup right-aligns values with dashed dividers. |
| P4-23 | P2 | Verify | `ho_job_booked` | Timeline: all stage titles render at the same bold weight; the mockup separates done/current (600) from upcoming (lighter). Reduces scan-ability. |
| P4-24 | P2 | Verify | `ho_dispute` | The `DETAILS` eyebrow label above the text field is missing, and the notice copy ("Our team reviews the dispute…") differs from the mockup ("Payment is paused while we review…") and uses a different icon. Check against `ast/screens.mjs`; amend whichever is wrong. |
| P4-25 | P2 | Verify | all | Text in the goldens reads lighter than in the mockup, consistent with O-1 (§3). Weight cannot be judged from 1× rasters; use device captures. |

---

## 6. Open items carried over from the fix plan (Fix-2 notes)

| ID | Sev | Status | Item | Source |
|---|---|---|---|---|
| P4-30 | P1 | Decision | **D-7 `ho_home` "Top rated near you"** is hidden. The search DTO has no rating or review count. Choose: backend field/endpoint, or drop the section from the mockup. | 2.1 |
| P4-31 | P2 | Open | Home search field opens `/find-tradie` but cannot focus (browse has no free-text search). First-time empty state has no illustration. | 2.1 |
| P4-32 | P2 | Decision | `ho_jobs`: badge reads "Payment due" (mockup "Pay now"); no "Quotes" badge or "2 of 3 quotes in" subtitle (no DTO field); progress bar has 6 segments for v2 jobs (mockup draws 5). Align copy/design or amend the mockup. | 2.1 |
| P4-33 | P2 | Open | `ho_post_job` project mode: bundled extras still sit between budget and WHEN because `HoPostJobProject` is one widget; Hours still shows in Project mode (mockup omits it). | 2.2 |
| P4-34 | P1 | Open | Capture-only rows with nothing seen yet: `ho_request_sent` running / expired / declined (H-14), `ho_quotes`, `ho_review_completion`, `ho_review`, radar `07_radar` + `07b_radar_error`, notifications, populated chat with an approved adjustment. | 2.2, 2.3, 1.3 |
| P4-35 | P2 | Open | Booked/extra-cost pages omit check-in time and on-site duration (no DTO field). Cancel lives in the overflow menu with a policy tile (D-8): confirm the mockup was amended. | 2.4 |
| P4-36 | P2 | Open | Gallery goldens for `ho_jobs` (third segment) and `ho_tradie_profile` (Jobs done) were expected to change and need deliberate regeneration. | 2.1, 2.2 |
| P4-37 | P1 | Open | `ho_radar` and `ho_job_detail` still need light + dark pair images at 360 pt and 200% before `v2Screens` flips. | 2.3, 2.4 |
| P4-38 | P1 | Verify | Fixture/POST failures that blocked payment, dispute, cancellation and lifecycle suites were root-caused to a backend bug (Fix-0.3). Confirm those suites now reach their first widget assertion on a clean stack. | 0.3, P4-05 |
| P4-39 | P2 | Open | `v2_flows` (quotes, extra cost, tradie profile) needs re-run with `UI_V2=all` after the layout exceptions recorded in the baseline. | baseline |
| P4-40 | P2 | Open | Fix-2 "Done when" requires every §3.1 homeowner row ✅ with images, all homeowner ids in `v2Screens`, C0 and C1 passing. None is met today. | plan §6 |

---

## 7. Suggested order (fix later, batched by root cause)

1. **P4-01 → P4-05:** get a real `UI_V2=all` run committed (1× light/dark, plus 200%). Re-audit this document against the images; convert every `Verify` to confirmed or rejected and add any new rows.
2. **P4-10 / P4-10d:** run the weight A/B, owner decides A, B or C. One token change fixes all screens.
3. **P4-11 → P4-13:** decide the clamp policy (P4-12), add 200% widget tests and goldens for the 13 uncovered Phase 4 screens, then fix overflows by component (dock, badges, kv rows, sticky CTA), not by screen.
4. **P4-20 → P4-25 and P4-30 → P4-40:** per-screen fixes and decisions, in journey order from plan §6.
5. Flip `v2Screens` ids one at a time as each screen's pair image and flow test pass.

## 8. How this file is maintained

- Update the **Status** column in place; when fixed, put the PR in the row. Do not add a new audit file per run: add rows, or start `06_…` only for a new phase.
- New findings from the Phase 4 images get the next free `P4-` id under the closest section.
- Keep `Verify` rows until a device capture settles them.
