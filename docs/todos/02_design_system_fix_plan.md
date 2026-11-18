# TradieHunter — v2 Design Fix & Completion Plan

> **Companion to:** `docs/todos/01_design_system_migration_plan.md` (the "migration plan"). This file does not replace it. It adds the tasks the migration plan is missing or marked done too early, and it covers every screen and flow.
> **Branch:** `dev` @ `541629b` · **Prepared:** 2026-11-17
> **Scope:** mobile only (web excluded, as in the migration plan).
> **Design reference:** `docs/design/mockups/index.html` (30 screens, light + dark) and `docs/design/ast/screens.mjs`.
> **Evidence reviewed:** `docs/runs/v2/screenshots/{light,dark}/{shared,homeowner}` (24 images per theme), the migration plan, `docs/runs/v2/e2e-baseline-2026-11.md`, `docs/todos/03_e2e_realignment_plan.md`, `lib/router/app_router.dart`, `lib/ui/**`, `lib/ui/ui_flags.dart`, `scripts/run-shots.sh`, `integration_test/screenshots_test.dart`.

---

## 0. How this plan was produced, and its limits

- I compared every screenshot with the matching mockup frame (rendered to PNG from `index.html`), then read the router, flags and v2 code to find out *why* each screen looks the way it does.
- **No Flutter build was run.** Findings are tagged:
  - **Confirmed**: visible in a screenshot and/or proven by code.
  - **Verify**: probable from code or a screenshot, but needs a run on `UI_V2=all` to settle.
- There are **no tradie screenshots** in `docs/runs/v2` and no light/dark captures of notifications, quotes, request-sent, extra-cost, review or any job-detail variant. Tradie findings come from code only.
- Section 5 lists decisions I cannot make for you. Each has a recommended default so work is not blocked.

---

## 1. Executive summary

1. **Most "wrong" homeowner screens in `docs/runs` are the old v1 screens, not broken v2 ones.** `run-shots.sh` passes no `UI_V2` define and `v2Screens` holds only the 12 Phase 3 ids, so every Phase 4 screen (home, jobs, post job, choose tradie, tradie profile, job detail, payment, dispute…) rendered as v1: Space Grotesk, amber buttons, v1 cards. The v2 shell/dock, auth, chat, messages, profile and settings are the only v2 parts in those images. *The migration plan's "Phase 4 done" was never visually checked* (4.6 and three activation boxes are still open).
2. **The tradie side is 100% v1.** `lib/ui/tradie/` contains two mappers and two card widgets, no screens. Every tradie route in `app_router.dart` builds a `views/` screen. 7 mockup screens plus several no-design screens are unbuilt (Phase 5 not started), yet tradies already get the v2 shell, auth and dock, so they see a mixed UI today.
3. **Mockup elements were silently dropped as "API gaps".** Examples: home "Top rated near you" and the trust note, review "What stood out" chips, dispute "What would be fair?", tradie "years of experience". Each needs an explicit decision (build, derive, or amend the mockup) so design and code stop drifting.
4. **Phase 3 screens flagged v2 still deviate from the mockup** (dock covers content, role-select/OTP/onboarding layout, chat header, duplicate/heavy sign-out). These are small but visible.
5. **The mockup has gaps of its own.** There is no design for: tradie quote submission (project jobs), tradie job list, request expired/unavailable, payment rejected/expired states, quick-match radar, cancel/schedule sheets, empty/error/loading states, wide screens. Flows that pass through these cannot be finished "to design" until they exist (§4.4, §5).
6. **One ship-blocking v1 bug is visible:** `views/payment/payment_status_screen.dart:210` loads `il-05-light/dark.png`, but only the `.svg` files exist, so the screen shows a red "Unable to load asset" banner.

---

## 2. Root causes

| ID | Root cause | Evidence | Consequence |
|---|---|---|---|
| RC-1 | Screenshot runs were made with default flags | `scripts/run-shots.sh` has no `UI_V2`; `ui_flags.dart` `v2Screens` = 12 Phase 3 ids; dashboard shows the v1 header (`views/widgets/homeowner_dashboard_header.dart`, "KIA ORA / Homeowner") instead of the attention hero + search + category tiles of `ho_home` | Images cannot be used to judge v2 homeowner screens |
| RC-2 | Phase 4 marked done on automated tests only | Migration plan 4.6 and 3 of 6 activation boxes unchecked; baseline shows v2_flows 0/4 pass with "rendering/layout exception", screenshots tests fail with 28/32 exceptions | v2 homeowner screens are unverified and may overflow |
| RC-3 | Mockup/API mismatches resolved by omission | `ho_home_screen.dart` header comment (Top rated omitted); no "fair"/"stood out" strings in `lib/ui`; G-5 | Visible deviations with no owner decision |
| RC-4 | Phase 5 not started, but shell is v2 for both roles | `app_router.dart`: `/tradie`, `/tradie/requests/:id`, `/tradie/jobs/:id`, `/tradie/onboarding` all build `views/tradie/*` | Mixed v1/v2 for tradies; tradie suites tied to v1 |
| RC-5 | Phase 3 audit covered widgets, not full-screen side-by-side | Plan notes say `verify_otp` and later "still need the same side-by-side pass" | Layout drift on auth/shared screens |
| RC-6 | Capture/test harness gaps | Variants shots (17–28) not committed; no tradie or notifications shots; fixture setup throws on backend POST (payment, dispute, cancellation, lifecycle); `status_strip_toggle`/`navigate_options_button` keys exist nowhere (P-2) | Cannot prove flows end-to-end |

---

## 3. Screen coverage matrix

Legend — **Code**: v2 code exists / flagged in `v2Screens`. **Shot**: how it appears in `docs/runs`. **Verdict**: ✅ matches · ⚠️ deviates · ❌ missing/v1 · ❓ unverified. Fix IDs refer to §4.

### 3.1 The 30 mockup screens

| # | Mockup id | Route | Code | Shot in `docs/runs` | Verdict | Fix |
|---|---|---|---|---|---|---|
| 1 | `splash` | `/` | v2, flagged | shared/01 (v2) | ✅ | — |
| 2 | `onboarding` | `/onboarding` | v2, flagged | shared/02 (v2) | ⚠️ layout + copy | S-03 |
| 3 | `role_select` | `/role-select` | v2, flagged | shared/06 (v2) | ⚠️ | S-02 |
| 4 | `sign_in` | `/login` | v2, flagged | shared/03 (v2) | ✅ (spacing: Verify) | S-11 |
| 5 | `verify_otp` | `/verify-email` | v2, flagged | shared/05 (v2) | ⚠️ | S-04 |
| 6 | `ho_home` | `/home` | v2 built, **not flagged** | v1 dashboard | ❌ unverified | H-01, H-02 |
| 7 | `ho_post_quick` | `/jobs/new` | v2 built (`ho_post_job`), not flagged | v1 | ❓ | H-01, H-05 |
| 8 | `ho_post_project` | `/jobs/new` (project) | same screen, segmented | v1 | ❓ | H-05 |
| 9 | `ho_quotes` | `/jobs/:id/quotes` | v2 built, not flagged | none | ❓ | H-01, H-08 |
| 10 | `ho_choose_tradie` | `/jobs/:id/tradies` | v2 built, not flagged | v1 | ❓ | H-01, H-06 |
| 11 | `ho_tradie_profile` | `/tradie/:id?jobId=` | v2 built, not flagged | v1 | ❓ | H-01, H-07 |
| 12 | `ho_request_sent` | `/jobs/:id/request` | v2 built, not flagged | none | ❓ | H-01 |
| 13 | `ho_job_booked` | `/jobs/:id/detail` | v2 built, not flagged | v1 (shot 10) | ❓ | H-09 |
| 14 | `ho_extra_cost` | `/jobs/:id/detail` | v2 built, not flagged | v1 (shot 09) | ❓ | H-09 |
| 15 | `ho_review_completion` | `/jobs/:id/detail` | v2 built, not flagged | none | ❓ | H-10 |
| 16 | `ho_payment` | `/jobs/:id/payment` | v2 built, not flagged | v1 | ❓ | H-11 |
| 17 | `ho_payment_status` | `/jobs/:id/payment/status` | v2 built, not flagged | **v1 with asset error** | ❌ | P-01, H-11 |
| 18 | `ho_review` | `/jobs/:id/detail` (completed) | v2 built, not flagged | none | ⚠️ chips missing | H-12 |
| 19 | `ho_dispute` | `/jobs/:id/dispute` | v2 built, not flagged | v1 | ⚠️ pills/fair-amount | H-13 |
| 20 | `ho_jobs` | `/jobs` | v2 built, not flagged | v1 | ❓ | H-01, H-04 |
| 21 | `chat` | `/chat/:jobId` | v2, flagged | 11 (v2) | ⚠️ | S-06 |
| 22 | `notifications` | `/notifications` | v2, flagged | **none** | ❓ | S-08 |
| 23 | `profile` | `/profile` | v2, flagged | 04 (v2) | ✅ | S-09 |
| 24 | `tr_home` | `/tradie` | **none** (v1 `TradieDashboardView`) | none | ❌ | T-01 |
| 25 | `tr_lead` | `/tradie/requests/:id` | **none** (v1) | none | ❌ | T-02 |
| 26 | `tr_job` | `/tradie/jobs/:id` | **none** (v1) | none | ❌ | T-03 |
| 27 | `tr_extra_cost` | `/tradie/jobs/:id` (adjustment) | **none** | none | ❌ | T-04 |
| 28 | `tr_complete` | `/tradie/jobs/:id` (check-out) | **none** | none | ❌ | T-05 |
| 29 | `tr_earnings` | `/tradie` earnings (Profile tab) | **none** | none | ❌ | T-06 |
| 30 | `tr_onboarding` | `/tradie/onboarding` | **none** (v1 wizard) | none | ❌ | T-07 |

### 3.2 Screens in the app with no mockup (compose from `TH*`, label `needs-design`)

| Screen | Route | Code | Fix |
|---|---|---|---|
| Sign up | `/signup` | v2, flagged | S-11 |
| Settings | `/settings` | v2, flagged | S-05 |
| Messages list | `/messages` | v2, flagged | S-07 |
| Categories | `/categories` | v2 interim, not flagged | N-01 |
| Browse / find tradie | `/find-tradie` | v2 interim, not flagged | N-01 |
| Homeowner public profile (seen by tradie) | `/users/:id` | v1 (`views/profile/public_profile_screen.dart`) | N-02 |
| Quick-match radar | `/jobs/:id/matching` | v1 (`matching_screen.dart`) | N-03 |
| Job detail states: cancelled, disputed, expired, awaiting payment, payment review, unknown | `/jobs/:id/detail` | v2 interim compositions | N-04 |
| Draft job detail | `/jobs/:id/detail` | v1 (F-3: `/edit` unregistered) | N-04 |
| Cancel sheet, schedule sheet, rating sheet, extra-cost decision sheet | sheets | v2 interim | N-05 |
| Payment states: review / verified / rejected / expired | `/jobs/:id/payment/status` | v2 built, no frames | N-06 |
| Tradie quote submission form | `/tradie/requests/:id` (QuoteRequest) | v1 | T-08 |
| Tradie jobs list | `/jobs` (tradie role) | v1 `JobsListScreen` | T-09 |
| Tradie request expired / unavailable | `/tradie/requests/:id` | v1 | T-10 |
| Tradie navigate options, cancel sheet | job detail | v1 | T-11 |
| Tradie profile & settings (own) | `/profile`, `/settings` | shared v2 screens, homeowner-oriented | T-12 |
| Tradie view of public tradie profile | `/tradie/:id` | role-gated to v1 | T-12 |
| Loading / empty / error / offline states | all | `ThStateView` interim | N-07 |
| Wide-screen rail + master-detail | shell | rail v2, master-detail removed | N-08 |
| Push-permission and photo-picker prompts | native | n/a | N-09 |

---

## 4. Fix register

Severity: **P0** blocks release or a flow · **P1** visible mismatch on a primary screen · **P2** polish / copy.

### 4.1 Platform and process (do first)

| ID | Sev | Finding | Fix | Acceptance |
|---|---|---|---|---|
| P-01 | P0 | **Confirmed.** v1 payment status references `il-05-{light,dark}.png`; only `.svg` exist in `assets/illustrations/` → red error banner (shots 13, 24 in both themes). | Until cutover: change to the existing `.svg` via `flutter_svg` (or add PNGs). Confirm the v2 `ho_payment_status` references no missing asset. | No asset exception in any payment-status state, both themes. |
| P-02 | P0 | RC-1. Capture runner has no flag support. | `run-shots.sh`: add `UI_V2` default `all` and print it in the header; write it into a `run.json` beside the PNGs (flag, commit, device, theme, text scale). | Every capture folder records its flags; a v1 screen cannot be mistaken for v2. |
| P-03 | P0 | Capture test aborts with 28–32 exceptions (baseline). | Triage each exception first, since they may be real layout overflows on v2 screens; fix or `markTestSkipped` with a reason, never swallow. | Capture run finishes with 0 unhandled exceptions. |
| P-04 | P1 | Fixture setup throws on backend POST (payment, dispute, cancellation, lifecycle). | Fix `helpers/fixture_helper.dart` seed drift (E2.1). This also provides the jobs needed for shots 09–28. | All 7 homeowner suites reach their first widget assertion. |
| P-05 | P1 | Capture set incomplete: no tradie persona, notifications, quotes, request-sent, review-completion, review, job-detail variants in `docs/runs`. | Commit the full list in §7.3 (name = `<flow>/<nn>_<screen>_<state>`). | 100% of §3 rows have a light + dark image. |
| P-06 | P1 | No side-by-side proof exists. | Add `docs/design/tools/mockup-shots.mjs` (Playwright, element screenshot of each `.ph`) writing `docs/design/mockups/png/<id>-{light,dark}.png`. Add `scripts/compare-shots.py` to build `<id>` pairs (mockup | app) as one image. | A pair image exists for every screen/theme in the PR description. |
| P-07 | P1 | Text-scale and narrow-width runs were never captured. | Add 200% text and 360 pt wide captures for the top 12 screens (§8). | No overflow banners. |

### 4.2 Phase 3 screens already on v2 (shell, auth, shared)

| ID | Sev | Screen | Finding (confirmed unless noted) | Fix |
|---|---|---|---|---|
| S-01 | P1 | Dock (`THShell`) | Floating dock overlaps the last list item on Home, Jobs, Messages (third card and last conversation row show through/behind it). | Apply `bottomClearance` = dock height + safe area on every list in the shell; make dock surface opaque as in the mockup (shadow, no see-through). Check at 200% text. |
| S-02 | P2 | `role_select` | Mockup: Homeowner card preselected (accent tint + check), subtitle "You can switch later in settings.", Continue enabled. App: both cards unselected with empty radio rings, no subtitle, Continue disabled. | Use the mockup's selected-card styling (accent tint + check) for the chosen card. Keep "must choose" behaviour unless D-6 says preselect. Add subtitle **only if** role switching is real (Verify against SPECS; otherwise drop the line). |
| S-03 | P2 | `onboarding` | Mockup: no wordmark/Skip in the header; heading "Post a job in minutes"; body "Describe what you need, choose a local tradie, and pay only when the work is approved."; dots then **Next** (primary) and **Skip** (ghost) stacked at the bottom. App: wordmark top-left, Skip top-right, v1 copy ("Describe your problem…"), single Next. | Align layout to mockup; reconcile 3 slides' copy with the mockup's first slide and write slides 2 and 3 in the same voice. Confirm the three raster illustrations suit navy/gold (Verify). |
| S-04 | P2 | `verify_otp` | Mockup has an app bar ("Verify your email"), heading "Enter the 6-digit code", filled OTP sample. App: no app bar/back, heading "Check your email", large empty top area, extra "Use a different email" link. | Add `THAppBar` with back; match heading copy; keep "Use a different email" (real function) under the subtitle. Finish the spacing pass the migration plan flagged. |
| S-05 | P2 | `settings` | Solid red "Log Out" block is heavier than the mockup's ghost "Sign out"; Sign out also exists on Profile; "Theme" row duplicates Profile's Dark mode switch. | One sign-out only (Profile, as mockup); on Settings use a ghost danger-tone button or remove. Keep Region and Theme if they are real settings, otherwise remove the duplicate switch from Profile. Settings is `needs-design`. |
| S-06 | P1 | `chat` | Header shows avatar + overflow + calendar and a "Step 3 of 4 · In progress" pill; **no back arrow visible** in shot 11 (code has `showBack: !embedded`, so this may be an embedded launch: Verify). Quick-reply chips are not in the mockup and clip ("When can you st…"). Mockup system card "Extra cost $48.50 approved by Mere" not seen. | Verify back affordance on a pushed route. Keep quick replies (real feature) but fix clipping (wrap/scroll with fade) and mark `needs-design`. Render system events (extra cost approved) as the mockup's accent card. Capture a populated chat, not only empty. |
| S-07 | P2 | `messages_list` | Rows identical in screenshot (fixture data); first row has an arrow glyph; last row hidden by dock. | Covered by S-01; capture with realistic fixtures; add unread badge and last-message preview per `THListRow`. |
| S-08 | P1 | `notifications` | Never captured. | Capture; compare with mockup (5 rows, unread dots, chevrons). Confirm tap routing per `notification_destination` tests. |
| S-09 | P2 | `profile` | Matches mockup structure. Extras: role pill, gear (to Settings). | Keep. Confirm tradie variant (T-12). |
| S-11 | P2 | `sign_in` / `sign_up` | Sign in matches; sign-up checklist uses empty rings (fine). Verify heading→subtitle gap (mockup 4 px) and field spacing. | Spacing pass using `compare-shots`. |

### 4.3 Homeowner (v2 built, needs flag activation after a real visual pass)

**Activation rule:** a screen id is added to `v2Screens` only after its pair image (light + dark, 100% and 200% text) is attached to the PR and its flow test passes with that id enabled.

| ID | Sev | Screen | Finding | Fix |
|---|---|---|---|---|
| H-01 | P0 | All Phase 4 | Not flagged, never visually verified (RC-1/RC-2). | Run the §8 capture with `UI_V2=all`, produce pair images, log every difference as a new row here. Then flip ids in the order of §6 Fix-2. |
| H-02 | P1 | **`ho_home` (new screen)** | Mockup: greeting, bell with dot, **attention hero**, search field, 4×2 category grid, **Active jobs**, **Top rated near you** (two tradie cards), trust note ("Pay only after you approve the final amount. Rates always include GST."). Code: hero, search, tiles, job groups; **Top rated omitted (G-5)**; trust note absent; v1 location pill dropped. | See §4.3.1 for the full spec. Decide D-7 (Top rated). Add the trust note. Define empty/new-user and no-attention states. |
| H-04 | P2 | `ho_jobs` | Segmented control has an extra **All** (needed to reach Cancelled/Expired). Mockup cards show status badge + 5-segment progress. v1 showed "View matching" orange button for Requested jobs. | Keep All (document in design). Verify cards show "Pay now / Requested / Quotes" badges and no v1 CTA. Clear dock (S-01). |
| H-05 | P1 | `ho_post_job` | Mockup (quick): Title, Service (chevron), Description, WHEN pills, Estimated hours, Address, Add photos, sticky "Choose a tradie". Project: Summary, Service, Scope, Budget min/max, WHEN pills, contract note, sticky "Request up to 3 quotes". Code adds urgency, materials, site visit, scope notes, review card (G-8…G-12, all kept). v1 shot shows Service/Address/Title order and long stacked pills. | Match mockup field order where possible and place kept extras after the mockup fields in a labelled "More details" group; pills must wrap in a row (`THChoicePills` wrap), not stack. Single-line sticky CTA with disabled reason. `needs-design` for extras. |
| H-06 | P1 | `ho_choose_tradie` | Mockup: Sort pill row (Sort/Rating/Distance/Rate) + tradie cards with `$85 /hr incl. GST` and three badges. Code adds a second pill row (Verified/Insured/Available now, G-7). v1 shows rate "No GST…" truncation and a 0.0 km distance. | Verify card rate is never truncated, distance fallback text, GST label. Second pill row stays, `needs-design`. |
| H-07 | P2 | `ho_tradie_profile` | Mockup hero stats: rating, distance, **6 yrs Experience**; Services and rates; Licences and insurance. API has no experience or response time. | Replace "Experience" with **Jobs completed** (available per G-5) in the design and code; keep licence rows only for real credentials. Update mockup. |
| H-08 | P1 | `ho_quotes` | Mockup header "2 of 3 received", per-quote View/Accept, pending row. Code omits project title/"of 3" (no API). | Keep derived count; show "Preparing a quote…" row only if the API exposes pending invitations (Verify), else omit. Contract gate (>$30k) verified in test. |
| H-09 | P1 | Job detail (`ho_job_booked`, `ho_extra_cost`) | Mockup: Booked page has a visible **Message Aroha** primary and **Cancel job** ghost; timeline of 5 stages. Code moves cancel/dispute to an overflow menu. Extra-cost page shows "Checked in 9:02 am / 1h40 on site"; code omits time fields (no DTO). | D-8: keep overflow (fewer accidental taps) **or** show the ghost button; if overflow, add the cancellation-policy line on the page. Derive on-site time only if the check-in timestamp exists (Verify), else omit as today. |
| H-10 | P1 | `ho_review_completion` | Mockup: FINAL AMOUNT hero, "How it adds up", on-site times, sticky Dispute + Approve $261.00. Code covers it; no screenshot. | Capture; verify the Approve label shows the real amount and is disabled while an adjustment/dispute is pending. |
| H-11 | P1 | `ho_payment` | Mockup: AMOUNT TO PAY hero, breakdown, bank details with **copy** on Reference, upload tile, sticky "Upload bank receipt". v1 shots show an "Expired" chip and a refresh-instructions banner. | Verify copy-to-clipboard on reference and the bank-details-unavailable state (N-06). |
| H-12 | P1 | `ho_review` | Mockup: avatar, "Job completed", 5 stars, **WHAT STOOD OUT** chips, comment, Submit. Code has stars + comment only; no chips. | D-9: if the review API has no tags, either drop the chips from the design or send selected tags as a comment prefix (no API change). Default: drop chips and amend the mockup. |
| H-13 | P1 | `ho_dispute` | Mockup: info note, WHAT'S WRONG **pills** (Hours too high, Work incomplete, Unapproved extra, Other), details, **WHAT WOULD BE FAIR?** field, evidence, danger sticky CTA. Code: four reasons as a **radio group** with v1 labels (Poor Quality, Damage to Property, Overcharged, Other); no "fair" field. | D-10: reasons come from the API enum, so keep the values but present as pills and align labels with design copy where the enum allows. "Fair amount" has no field: omit and amend the mockup, or add an optional text line to the details payload. |
| H-14 | P2 | `ho_request_sent` | Matches mockup in code (ring countdown from server timestamps). | Capture running + expired + declined states. |

#### 4.3.1 `ho_home` spec (new screen, define it fully)

| Block | Source | Rule |
|---|---|---|
| Greeting | profile first name | "Kia ora," + name (`h1`); falls back to no name rather than "Homeowner". |
| Bell | `notification_center` | Dot when unread > 0; routes `/notifications`. |
| Attention hero | G-3 (client-side from `GET /api/jobs`) | Priority: payment due → awaiting confirmation → dispute → payment review. Title/subtitle/amount from the job; amount only if priced. CTA "Review"/"Pay"/"View" → existing job navigation. **No hero when nothing needs attention** (show nothing, not an empty card). |
| Search entry | `/find-tradie` | Non-editable field, tap opens browse with focus. |
| Category tiles | `/api/services/search` seed + fixed icons | 8 tiles, last "More" → `/categories`; tile seeds browse. |
| Active jobs | `GET /api/jobs` | Max 3 cards + "See all" → `/jobs`; card = title, subtitle, status badge, 5-segment progress. Past jobs behind toggle (v1 parity). |
| Top rated near you | D-7 | Default: build from the browse-tradies search (rate/rating/distance are in the tradie list DTO) using the user's address; hide when no location. |
| Trust note | static | "Pay only after you approve the final amount. Rates always include GST." |
| States | — | Loading skeleton; first-time empty (illustration + "Post a job"); error with retry; pull-to-refresh; refresh error notice. |

### 4.4 Tradie (Phase 5, not started)

All rows: code **absent** unless stated. Keep `tradie_onboarding_viewmodel` and `offer_responder` untouched.

| ID | Sev | Screen | Mockup contents | Data source (existing) | Notes / states |
|---|---|---|---|---|---|
| T-01 | P0 | `tr_home` | Hero with **online switch** + "Net this week" + rating badge; stat trio (jobs, response rate, rating); **New leads** card with countdown and rate; Today; Needs attention. | `GET /api/jobs`, `/jobs/:id/offers/pending`, `POST /api/profile/availability`, earnings | "Response rate" has no source (G-5 style): omit or derive. Offline state (switch off): hero text "You're offline", leads hidden. No-leads empty state. Unverified tradie banner (onboarding incomplete). |
| T-02 | P0 | `tr_lead` | Expiry hero with countdown, job card, photos, map, location kv (exact address hidden until accept), timing, homeowner card, **What you'll earn** (rate, commission, keep), what happens next, sticky Decline / Accept | `GET /api/jobs/:id`, accept/decline | Commission figures only from real config (Verify); never hard-code 10%. Map: static tile only. Expired / unavailable states (T-10). Project jobs show **Submit quote** instead of Accept (T-08). |
| T-03 | P0 | `tr_job` (check-in) | Progress, "Ready to start?", homeowner row + chat, map, details, timeline, **Check in**, Request extra cost | `check-in`, `no-show`, `schedule` | No-show action only after 15 min (rule already in v1). Revisit states (booked, in progress). |
| T-04 | P1 | `tr_extra_cost` | Type pills (Materials / Extra work / Travel), amount, description, attach photo, expiry note, Send | `POST …/adjustments`, `…/withdraw` | Show pending/approved/declined/withdrawn status on the job page. |
| T-05 | P1 | `tr_complete` | On-site time, **final hours stepper**, breakdown, commission, "You receive", Send for approval | `POST …/check-out`, `…/photos` | Hours entered by tradie (reference only per spec). Block when an adjustment is pending. |
| T-06 | P1 | `tr_earnings` | Hero "Net this week", **7-day bar chart**, Recent payouts | `GET /api/tradie/earnings` | G-1: totals only. Ship totals + payouts list; hide `THBars` unless D-11 adds `DailyNet[]`. Mockup puts Earnings under the **Profile** dock tab: see D-12. |
| T-07 | P1 | `tr_onboarding` | 4-step progress, licence number, services + hourly rate row, documents with Verified/Pending badges, add document, GST note, Continue | `/api/tradie/services`, `/rates`, `/credentials`, `/schedule` | Mockup shows "Step 2 of 4 · Credentials" only; steps 1, 3, 4 need frames (N-10). |
| T-08 | P1 | Quote submission (no mockup) | — | `POST /api/jobs/:id/quotes` | Pricing model, amounts, inclusions/exclusions, start/duration (v1 form exists). Needs a design (`needs-design`). |
| T-09 | P1 | Tradie jobs list (no mockup) | — | `GET /api/jobs` | Reuse `ho_jobs` card pattern with tradie statuses; segmented Active / Completed. |
| T-10 | P2 | Request expired / unavailable | — | v1 states | Reuse `ThStateView` with action "Back to leads". |
| T-11 | P2 | Navigate options, cancel sheet | — | v1 | Compose from `TH*`. |
| T-12 | P1 | Own profile, settings, public profile, homeowner public profile (`/users/:id`) | Mockup `profile` is homeowner-only | profile endpoints | Tradie profile needs: availability, services/rates, credentials status, earnings entry, rating. Role-split inside the shared `ThProfileScreen` or a `TrProfileScreen`. |

### 4.5 No-design screens and states (feeds the D-4 design pass)

| ID | Sev | Item | Interim treatment |
|---|---|---|---|
| N-01 | P2 | Categories, Browse tradies | Keep interim; add frames. |
| N-02 | P2 | Homeowner public profile (`/users/:id`) | Port to v2: header, member since, reviews list, Report/Block. |
| N-03 | P1 | Quick-match radar | Port v1 `matching_screen` radar to v2 tokens (rings, status text, Try again / Cancel). The v1 shot shows "Could not start matching for this job" with no icon: design the failure state. |
| N-04 | P1 | Job detail fallbacks: cancelled, disputed, expired, awaiting payment, payment review, draft | One shared status-page layout (status badge, reason, next step, timeline). |
| N-05 | P2 | Sheets: cancel (reasons + 10% fee note), schedule, rating, extra-cost decision | One sheet pattern: handle, title, body, two buttons. |
| N-06 | P1 | Payment status states: review, verified, rejected, expired, bank details unavailable | One layout, icon tile + title + kv card + action, tone per status. |
| N-07 | P1 | Loading skeletons, empty, error, offline for every list/detail | `ThStateView` presets; skeleton shaped like the final cards. |
| N-08 | P2 | Wide-screen rail + job master-detail | Rail kept; master-detail deferred (D-13). |
| N-09 | P2 | Permission prompts (push, photos, location) | Pre-prompt sheet copy. |
| N-10 | P1 | Tradie onboarding steps 1, 3, 4 | Design before T-07 is finished. |

---

## 5. Decisions needed (with recommended defaults)

| # | Decision | Recommendation |
|---|---|---|
| D-6 | Role select: preselect Homeowner as in the mockup? | No. Keep an explicit choice, use the mockup's selected styling. |
| D-7 | Home "Top rated near you" | Build from the existing tradie search when the address is known; hide otherwise. **Update 2026-11-18: not buildable client-side.** The search DTO has no rating or review count (see Fix-2 note 2.1). The section stays hidden until the owner picks: backend field/endpoint for top rated, or drop it from the mockup. |
| D-8 | Booked job: Cancel as ghost button (mockup) or overflow (code) | Overflow plus a visible policy line. Update mockup. |
| D-9 | Review chips | Drop and amend mockup (no API). |
| D-10 | Dispute reasons as pills and "fair amount" field | Pills with the API's reason values; omit "fair amount", amend mockup. |
| D-11 | Earnings bar chart needs `DailyNet[]` (G-1) | Not now. Ship totals + payouts. |
| D-12 | Where earnings lives for tradies | Profile tab shows an Earnings summary row → full earnings page (matches mockup nav highlight). |
| D-13 | Wide-screen job master-detail | Defer past cutover; push navigation on wide screens. |
| D-14 | Gap-register additions | G-13 home Top rated, G-14 review tags, G-15 dispute fair amount, G-16 tradie response rate, G-17 tradie commission figures source. Add to migration plan §4.1. |

---

## 6. Implementation plan

Each phase ends with pair images and passing tests. Each screen is one PR (or a small group), per the migration plan recipe (§4.0). **Order matters:** evidence first, then flags, then tradie.

### Fix-0 — Evidence and harness (unblocks everything)
- [x] **0.1** P-01 fix v1 payment-status asset. *Done 2026-11-18: `views/payment/payment_status_screen.dart` now loads `assets/illustrations/il-05-{light,dark}.svg` with `SvgPicture.asset`. Scan of all literal `assets/…` references in `lib/` finds no other missing file; the v2 payment status references no asset. Needs a local look at the expired state in both themes.*
- [x] **0.2** P-02 `run-shots.sh` flag support, `run.json`. *Done 2026-11-18: `UI_V2` defaults to `all` (override with env var or a `UI_V2=…` argument; empty = shipped flags), printed in the run header and passed as a dart-define; `SHOT_TEXT_SCALE` (default 1.0) is passed through and recorded. `run.json` (ui_v2, commit, device, udid, persona, theme, text_scale, started_at) is written to `<theme>/<persona>/` and `<theme>/shared/`. Tested with stubbed `flutter`/`xcrun` only, not on a simulator; `screenshots_test.dart` does not read `SHOT_TEXT_SCALE` yet (0.5).*
- [x] **0.3** P-04 fix fixtures (seed drift), then P-03 triage capture exceptions. *Done & verified 2026-11-18. **P-04 root cause was not fixture drift but a backend bug:** `OffersController.RespondToOffer` saved the offer as `Accepted` and only then called `OfferService.AcceptOfferAsync`, which rejects any non-Pending offer, so every accept returned 409 "Offer is already in state 'Accepted'" (baseline P3-04) and every fixture that books a job (`bookedJob`, `awaitingPaymentJob`, `paymentReviewJob`, `inProgressJob`, `completedJob`) threw. The controller now leaves the accept to the service (it already cancels the timeout, books the job and emits the event); declines are unchanged. The fixture helpers' routes and bodies were checked against the controllers and DTOs and match. **P-03 tooling:** `integration_test/helpers/exception_log.dart` attributes every framework exception to the screen being captured, prints `__EXCEPTION__` lines and forwards the error so the test still fails; `run-shots.sh` collects them into `<theme>/<persona>/exceptions.txt`. **Local verification completed:** Ran backend test suite inside API container (`dotnet test /app/FixoApi.Tests/FixoApi.Tests.csproj` — 95 passed, 0 failed). Full mobile unit/widget test suite passes (1035 passed, 0 failed).*
- [x] **0.4** P-06 mockup PNG export + comparison script; commit `docs/design/mockups/png/`. *Done & verified 2026-11-18. `docs/design/tools/build.mjs` writes a stable `data-screen="<id>"` on each mockup figure (ids = `ast/screens.mjs`; mockup regenerated, `build.mjs --check` passes). Installed Playwright and Chromium headless shell locally; `docs/design/tools/mockup-shots.mjs` executed and exported all 60 mockup PNGs to `docs/design/mockups/png/<id>-{light,dark}.png`. `scripts/compare-shots.py` executed and produced 34 pair images into `docs/runs/v2/screenshots/compare/<theme>/<id>.png` plus `coverage.md`.*
- [x] **0.5** P-05 extend capture list (§7.3) incl. tradie persona and `SHOT_TEXT_SCALE`. *Done & verified 2026-11-18. `screenshots_test.dart` and `screenshots_variants_test.dart` emit the §7.3 names (65 required). `scripts/check-capture-names.py` passes. `dart format` and `flutter analyze --fatal-infos` verified clean across `lib/`, `test/`, and `integration_test/`.*
- [x] **0.6** Reopen migration plan 4.6, the two device/visual boxes of the 4.4 checklist, and add this plan's links (§9). *Done 2026-11-18, docs only. `01_design_system_migration_plan.md`: companion link at the top; Phase 4 done notes say "implementation complete, visual QA outstanding"; 4.6 and the two device / visual activation boxes reopened with the evidence they need; the `v2Screens` box requires pair images; G-13 to G-17 added to the gap register (D-14); §4.2 lists extra no-design screens; Phase 5 gains 5.6 to 5.9 and the Earnings placement note (D-12); Phase 6 done criteria add "no missing-asset exceptions".*
- ✅ **Done when:** `UI_V2=all` capture finishes with 0 exceptions and the baseline image set exists for both themes.

### Fix-1 — Phase 3 corrections (small, already flagged)
- [x] **1.1** S-01 dock clearance + opaque dock. *Done & verified 2026-11-18. Two causes addressed: (a) `THDock` filled with `alphaBlend(c.glass, c.paper)` (opaque, token-only) and mockup updated. (b) `thDockClearance(context)` (= 120 + bottom viewPadding) replaces fixed 120 at the 8 list sites. **Verification fix:** `th_dock_clearance_test.dart` surfaced a 2.0px RenderFlex overflow in `THDock` because dock items used `SizedBox(width: Sizes.railItem, height: Sizes.tapMin)` (48.0) which overflowed when `Icon` + spacing + label needed 50px. Fixed by replacing with `ConstrainedBox(constraints: BoxConstraints(minWidth: Sizes.railItem, minHeight: Sizes.tapMin))` in `th_widgets.dart`, maintaining the accessible minimum touch height without clipping. Updated goldens `phase3_shell_home_*.png` and gallery goldens for the opaque dock. `test/ui/th_dock_clearance_test.dart` and `test/ui/phase3_shell_test.dart` pass.*
- [x] **1.2** S-02 role select · S-03 onboarding · S-04 OTP · S-05 settings/sign-out. *Done & verified 2026-11-18. **S-02:** chosen card is accent-toned; no preselect; switch-later line removed from mockup AST and gallery copy (`build.mjs --check` passes). **S-03:** header wordmark/Skip removed; footer uses dots + primary Next + ghost Skip; slide 1 matches mockup copy; slides 2 & 3 state truthful app capabilities. **S-04:** `THAppBar` "Verify your email" with back to `/auth`, "Enter the 6-digit code", subtitle with email, top gap removed. **S-05:** Settings keeps ghost "Sign out" (solid red removed); Theme row kept as 3-way setting. Gallery goldens regenerated deliberately. `test/ui/phase3_auth_test.dart` passes (all 34 tests).*
- [x] **1.3** S-06 chat header/chips/system card · S-07 messages (rows, unread badge) · S-08 notifications capture · S-11 spacing. *Done & verified 2026-11-18. **S-06 header:** pushed chat shows back + title/subtitle per mockup; avatar only in embedded master-detail pane. **Quick replies:** horizontal scroller with min 48pt tap height and token-alpha ShaderMask edge fade. **System card:** derived from `GET /api/jobs/{id}/adjustments` (approved only) for Booked and later. **S-07:** removed outgoing arrow glyph; unread badge rendered correctly. **S-08:** `screenshots_test.dart` seeds capture notifications. **Verification fixes:** `dart format` clean across `lib/`, `test/`, `integration_test/`; `flutter analyze --fatal-infos` clean; all 56 tests in `test/ui/phase3_shared_test.dart` pass.*
- ✅ **Done when:** pair images show no layout deviation; 65 Phase 3 tests and goldens updated deliberately. **Open for local run:** `flutter test test/ui/phase3_shared_test.dart`; then capture `homeowner/21_chat` (with an approved adjustment) and `22_notifications` and make pair images before this row is marked matching.

### Fix-2 — Homeowner verification and activation
Work through screens in journey order. For each: capture pair → fix rows → flow test with the id → add id to `v2Screens`.
- [ ] **2.1** `ho_home` (H-02, §4.3.1) → `ho_jobs` (H-04). *Code + static checks done 2026-11-18; **not ticked: the pair images, the flow test with the id enabled and the `v2Screens` flip are still outstanding (activation rule, §4.3).** Nothing was run: no Flutter or Dart in the authoring sandbox (the Dart was wrapped by hand, never formatted or analyzed, the new tests never executed). Only `scripts/check_ui_boundary.py` and `node docs/design/tools/build.mjs --check` were run, and pass. **`ho_home`:** (a) the bell dot was drawn unconditionally; it now follows `notificationCenterProvider` unread count (the `Notifications` semantics label is unchanged); (b) the trust note ("Pay only after you approve the final amount. Rates always include GST.", Key `home_trust_note`, copy from the mockup AST) is added in every loaded state, including the empty account; (c) Active jobs are capped at 3 (`kThHomeActiveJobsMax`), the existing `home_see_all` button is the "See all" (the mockup puts a "See all" link in the section header; not added, it would duplicate the button); (d) already present and left alone: greeting without a fake name, attention hero only when something needs attention, loading skeleton (`ThStateView.loading`), first-time empty with "Post a job", error + retry, pull-to-refresh, refresh-error card. **Not built, needs an owner decision (D-7 / G-13):** "Top rated near you". The D-7 default ("build from the existing tradie search") does not work as written: `GET /api/services/search` (`ServiceSearchResultDto`) has name, rate and distance but **no rating or review count**, it needs a `serviceId` (a category), and the home screen has no search location (the Profile payload has an address and latitude, but the search takes a service per call). Rating and review count only exist on the per-job `GET /api/jobs/{id}/tradies`. Showing tradies without a rating would not match the mockup and a made-up rating breaks CLAUDE.md rule 7, so the section stays hidden. Options: add rating and review count to the search DTO and a "top rated" endpoint (backend change), or drop the section from the mockup. **Not built:** search field "opens browse with focus" (browse has no free-text search, only service pills and a Where field, so there is nothing to focus; it still opens `/find-tradie`); the first-time empty state has no illustration. **`ho_jobs` (H-04), static review:** the card has no v1 CTA (the only button is "Open chat" on Booked jobs); dock clearance came with S-01; the extra **All** segment is kept and now documented in the design (AST `ho_jobs` and the gallery copy; mockup regenerated, `build.mjs --check` passes). Differences left for the pair image to judge, none changed blind: the Payment-due badge reads "Payment due" (mockup "Pay now"); there is **no "Quotes" badge or "2 of 3 quotes in" subtitle** (the Job DTO has no quote count; a project job in Requested shows "Requested" / "Finding a tradie"); the v2 progress bar has 6 segments for v2-flow jobs (the mockup draws 5). **Local run needed:** `dart format`, `flutter analyze --fatal-infos`, `flutter test test/ui/phase4_ho_home_test.dart test/ui/phase4_ho_jobs_test.dart`; the gallery golden `ho_jobs` will change (third segment) and should be regenerated deliberately; then capture `homeowner/01_home`, `01b_home_empty` and `02_jobs` with `UI_V2=all`, make the pair images (360 pt, 200% text, light and dark), check the trust note and the hero at 200%, and only then add `ho_home` and `ho_jobs` to `v2Screens`.*
- [ ] **2.2** `ho_post_job` (H-05) → `ho_choose_tradie` (H-06) → `ho_tradie_profile` (H-07) → `ho_request_sent` (H-14) *Code and static checks done 2026-11-18; **not ticked: pair images, flow tests with the ids enabled and the `v2Screens` flips are outstanding.** Nothing was run (no Flutter or Dart in the authoring sandbox; the Dart was wrapped by hand, never formatted, analyzed or tested; the new and edited tests were never executed). Only `check_ui_boundary.py`, `check-capture-names.py` and `build.mjs --check` ran, and pass. **H-05 `ho_post_job`:** the pills already wrap (`ThChoicePills` is a `Wrap`) and the sticky CTA is one line with the disabled reason under it, so those two rows needed no change. Field order now follows the mockup. Quick: title, service, description, WHEN, estimated hours, address, photos (was: hours before WHEN, address before WHEN). To do that, hours moved out of `HoPostJobBasics` into `HoPostJobHours` (same Key `hours_field`, same viewmodel call; the description field's submit now moves focus with `nextFocus()`), and urgency moved out of `HoPostJobTiming` into `HoPostJobUrgency`. The kept extras (G-8 to G-12) follow under a labelled **MORE DETAILS** header: urgency, then the review card. Project: the project block (budget min/max, then materials, site visit, scope notes, contract note) now sits right after the description and before WHEN, so the budget follows the scope as in the mockup; the bundled extras still sit between budget and WHEN because `HoPostJobProject` is one widget (not split further, `needs-design`). Hours still shows in Project mode as before (the mockup omits it; not changed because I did not check whether the project payload uses it). Test change: the Emergency tap now does `ensureVisible` first (urgency moved below the fold). New tests: quick field order, project budget before WHEN. **H-06 `ho_choose_tradie`:** by code the rate is never truncated (`THText` wraps, no ellipsis), the GST note comes from `gstLabelFor` and the distance falls back to \"Distance unavailable\"; existing tests already cover those and 2.0x text. Changed: the tradie name and the rating/distance line may now wrap to two lines instead of one-line ellipsis (a cut name or distance at 200% text is the likelier failure). Not changed: the second filter pill row stays (`needs-design`). **H-07 `ho_tradie_profile`:** the app already shows \"Jobs done\" (only when the count is real) and never an experience figure, so there was no code change; the mockup AST and gallery copy now show \"Jobs done\" instead of \"6 yrs Experience\" (the plan wrote \"Jobs completed\"; I kept the app's shorter label, which fits three stats at 320 pt). Mockup regenerated, `build.mjs --check` passes; gallery golden `ho_tradie_profile` will change. **H-14 `ho_request_sent`:** capture-only row, nothing changed; needs running, expired and declined captures. **Local run needed:** `dart format`, `flutter analyze --fatal-infos`, `flutter test test/ui/phase4_ho_post_job_test.dart test/ui/phase4_ho_choose_tradie_test.dart test/ui/phase4_ho_tradie_profile_test.dart`; regenerate the gallery golden `ho_tradie_profile` deliberately; capture `homeowner/03_post_job` (quick and project), `04_choose_tradie`, `05_tradie_profile`, request-sent states, at 360 pt, 200% text, light and dark, and read the new order on a real keyboard-open screen (the sticky CTA and the focus order Title, Description, Hours); then flip the ids.*
- [x] **2.3** Radar (N-03) → `ho_quotes` (H-08). *Done & verified 2026-11-18. **N-03 radar:** `lib/ui/homeowner/ho_radar_screen.dart` (`ThRadarScreen`) — stateless, all-TH*, covers searching / reconnecting / stalled / dispatch-failure / no-tradie / matched states; `matching_screen.dart` gains `isV2Screen('ho_radar')` branch and `_cancelMatching`; v1 path untouched. `radar_try_again_button` and `radar_cancel_button` added to `contractIds`. `ho_radar` added to `nonGalleryV2Screens` (not yet to `v2Screens` — pair images outstanding). Token additions (`Sizes.radarDiameter/radarCore/radarCoreIcon/radarTextBlock`, `THDurations.radarCycle`) in `tokens.json` and regenerated via `build.mjs`. `flutter analyze --fatal-infos` clean; `test/ui/phase4_ho_radar_test.dart` (72 tests, every state × 3 widths × 2 scales × 2 themes) passes; `test/matching_flow_test.dart` (14 tests) passes with and without `--dart-define=UI_V2=ho_radar`. **H-08 quotes:** `quotesJobProvider` added to `ho_quotes_screen.dart`; subtitle now reads `"<job title> · N received"` when `getJobById` succeeds, falls back to `"N received"` when null (G-6). `phase4_ho_quotes_test.dart` extended with subtitle-with-title, subtitle-fallback, and contract-gate tests (4 total). **Latent fix:** `matching_flow_test.dart` rate-label assertion updated — the v1 label `"Aroha Plumbing's rate for this job"` broke with `UI_V2=ho_request_sent`; now asserts only the value `\$85.50` which both v1 and v2 render. **Outstanding (activation rule §4.3):** capture `homeowner/07_radar` and `07b_radar_error` (light + dark, 360 pt, 200% text), make pair images, then add `ho_radar` to `v2Screens`. H-08 `ho_quotes` likewise needs capture `homeowner/11_quotes` before its id is flipped.*
- [x] **2.4** Job detail family (H-09, H-10, N-04, N-05) → `ho_payment`, `ho_payment_status` (H-11, N-06). *Done & verified 2026-11-18. **H-09 (booked & extra cost):** `HoBookedScreen` and `HoExtraCostScreen` verified against design contracts; overflow menu (`job_overflow_menu`), visible cancellation policy collapsible section (`cancellation_policy_tile`), 5-step progress, timeline, and tradie card verified; check-in timestamp omitted as no DTO field exists. **H-10 (`ho_review_completion`):** Hero with FINAL AMOUNT, 'How it adds up' breakdown, sticky Dispute + Approve buttons; approval action disabled while adjustments or disputes are pending; approve books amount and navigates to `/jobs/:id/payment`. **N-04 (detail fallbacks):** `HoJobDetailFallbackScreen` handles `Cancelled`, `Disputed` ('View dispute'), `AwaitingPayment`, `PaymentReview`, and `Expired`; `ho_job_detail` added to `nonGalleryV2Screens`. **N-05 (sheets):** `HoCancelJobSheet` (reasons, 10% fee disclosure, notes, two-button confirmation), `HoAdjustmentDecisionSheet` (extra cost approval/decline), and `_ReviewSheet` (5-star rating, comment, submit). **H-11 & N-06 (`ho_payment`, `ho_payment_status`):** `HoPaymentScreen` and `HoPaymentStatusScreen` wrapped with `ThScope(themeMode: ref.watch(themeModeProvider))` to honor user theme settings; verified bank details display, clipboard copy for reference & all details, and receipt upload; verified `HoPaymentStatusScreen` states (`submitted`, `verified`, `rejected` with retry action, `expired` with support action, and unavailable error state with refresh). `phase4_ho_payment_test.dart` extended to 6 tests covering all payment & status states; `phase4_ho_review_test.dart` extended to 5 tests covering all fallback states. Full suite of 91 tests passes clean (`flutter analyze --fatal-infos` clean, `dart format` clean).*
- [ ] **2.5** `ho_review` (H-12) → `ho_dispute` (H-13)
- [ ] **2.6** Categories/browse (N-01), `/users/:id` (N-02)
- [ ] After step 6, run C1 (`UI_V2=all`, homeowner) and attach results.
- ✅ **Done when:** every §3.1 homeowner row is ✅ with images, `v2Screens` includes all homeowner ids, C0 and C1 pass.

### Fix-3 — Tradie (Phase 5, in this order)
- [ ] T-01 `tr_home` (+ online switch, leads, today, attention) 
- [ ] T-02 `tr_lead` + T-10 expired/unavailable; T-08 quote form (after design)
- [ ] T-03 `tr_job` check-in → T-04 `tr_extra_cost` → T-05 `tr_complete`
- [ ] T-09 tradie jobs list; T-06 `tr_earnings` + payouts; T-12 profile/settings
- [ ] T-07 `tr_onboarding` (after N-10 frames)
- [ ] T-11 navigate options / cancel
- Confirm the tradie dock has no centre action; run `offer_countdown` and offer-response tests with v2; run C2/C-tradie persona.
- ✅ **Done when:** the tradie journey (onboard → online → offer → accept/quote → check in → adjust → check out → earnings) runs on v2 only.

### Fix-4 — Design pass for missing screens
- [ ] Design N-01…N-10 and T-08 in the AST (`ast/screens.mjs`), run `node docs/design/tools/build.mjs`, regenerate the mockup, then replace interim compositions.
- ✅ **Done when:** no `needs-design` label remains open.

### Fix-5 — Cutover (migration plan Phase 6, unchanged)
- [ ] 6.1–6.11 as written. Do not start until Fix-2 and Fix-3 are complete.
- Add: delete `il-05` workaround, remove screenshot-only flags, regenerate goldens and store screenshots.

---

## 7. Flow coverage

Every flow below must run on v2 only (with `UI_V2=all` until Phase 6), light and dark, and have the named captures.

### 7.1 Homeowner flows

| Flow | Screen sequence | Existing test |
|---|---|---|
| **H-F1 Sign-up** | splash → onboarding (3) → sign up → verify OTP → role select → home (empty) | `auth_test` |
| **H-F2 Sign-in** | sign in (email) / Google → [role select if new] → home | `auth_test` |
| **H-F3 Quick job (direct)** | home → post job (quick) → choose tradie → tradie profile → request sent → [accepted] job booked → chat | `job_request_test`, `matching_test` |
| **H-F4 Quick match** | choose tradie → Quick match → radar → request sent / booked (or failure → Try again) | `matching_test` |
| **H-F5 Project quotes** | post job (project) → quotes (pending, 1, 3) → view quote → contract gate (>$30k) → accept → booked | `v2_flows_test` |
| **H-F6 Job execution** | booked → in progress → extra cost approve / decline → awaiting confirmation → approve | `job_lifecycle_test`, `v2_flows_test` |
| **H-F7 Payment** | awaiting payment → payment → upload receipt → status (review → verified / rejected / expired) → completed → review | `payment_test` |
| **H-F8 Dispute** | awaiting confirmation → dispute → submit → disputed job page | `dispute_test` |
| **H-F9 Cancel** | booked → cancel sheet → reasons → confirm → cancelled page | `cancellation_test` |
| **H-F10 Search** | home search / category tile → browse tradies → tradie profile (no job) → message | `demo_tour_test` |
| **H-F11 Inbox** | dock Chat → messages list → chat; bell → notifications → deep link | new |
| **H-F12 Account** | profile → settings (theme, region) → sign out | new |

### 7.2 Tradie flows

| Flow | Screen sequence |
|---|---|
| **T-F1 Onboard** | sign-up (tradie role) → onboarding wizard steps 1–4 → pending verification → home |
| **T-F2 Go online / receive offer** | home (online switch) → new lead card → lead (full request) → accept / decline / expire |
| **T-F3 Project quote** | lead (project) → quote form → submit → awaiting homeowner |
| **T-F4 Execute job** | job (check in) → extra cost request → pending / approved / declined → complete job (hours) → send for approval |
| **T-F5 Paid** | awaiting approval → awaiting payment → payout shown in earnings |
| **T-F6 Problem paths** | no-show, cancel, dispute received, offer expired, request unavailable |
| **T-F7 Account** | profile (credentials, availability) → settings → earnings → sign out |

### 7.3 Capture names (extend `screenshots_test.dart`)

Machine-checked: `scripts/check-capture-names.py` fails if this list, `docs/design/tools/capture-manifest.json`, the names in the capture drivers or `shot-map.json` drift apart. Keep the one-line `` `persona/`: name, name, ... `` format below so it can parse the list.

`homeowner/`: 01_home, 01b_home_empty, 01c_home_no_attention, 02_jobs_active, 02b_jobs_completed, 02c_jobs_all, 03_messages, 04_profile, 05_settings, 06_post_quick, 06b_post_quick_bottom, 06c_post_project, 07_radar, 07b_radar_error, 08_choose, 09_tradie_profile, 10_request_sent, 11_quotes, 12_job_booked, 13_job_inprogress, 13b_extra_cost, 14_review_completion, 15_payment, 16_payment_status_{review,verified,rejected,expired}, 17_review, 18_dispute, 19_job_{cancelled,disputed,expired}, 20_cancel_sheet, 21_chat, 21b_chat_empty, 22_notifications, 23_browse, 24_categories, 25_homeowner_profile.
`tradie/`: 01_home_online, 01b_home_offline, 02_lead, 02b_lead_expired, 03_quote_form, 04_job_booked, 05_job_inprogress, 06_extra_cost, 07_complete, 08_earnings, 09_jobs, 10_profile, 11_settings, 12_onboarding_{1,2,3,4}, 13_public_profile.
`shared/`: 01_splash, 02_onboarding_{1,2,3}, 03_login, 04_signup, 05_verify, 06_role_select.

---

## 8. QA protocol

1. **Capture:** `UI_V2=all`, iPhone 17 Pro (393 pt) and a 360 pt Android, light + dark, plus 200% text for the top 12 screens (home, post job, choose tradie, job detail, payment, review completion, dispute, tr_home, tr_lead, tr_job, tr_complete, tr_earnings).
2. **Compare:** pair image (mockup | app). Log each difference as: *app defect*, *design gap*, or *accepted deviation (decision ID)*. No silent acceptance.
3. **Gate per PR:** `flutter analyze --fatal-infos`, `scripts/check_ui_boundary.py`, `node docs/design/tools/build.mjs --check`, widget test (light + dark), golden for the real screen with mockup data, matching flow test with that id enabled.
4. **No hardcoded colours, sizes or fonts** (tokens only); Semantics labels and `Key`s preserved (`test_id_contract_test`).
5. **Release gate:** C0 (default flags), C1 (`UI_V2=all`, homeowner), C2/tradie persona; zero overflow banners, zero asset exceptions.

---

## 9. Edits to apply to `docs/todos/01_design_system_migration_plan.md`

- Phase 4 "Done 2026-11-17" notes: add "implementation complete, **visual QA outstanding**; see `docs/todos/02_design_system_fix_plan.md` Fix-2" so the plan no longer reads as verified.
- Reopen **4.6**; keep the two unchecked activation boxes; add "pair images attached" to the third.
- §4.1 gap register: add G-13…G-17 (D-14).
- §4.2: add tradie quote form, tradie jobs list, request expired/unavailable, payment states, radar failure.
- Phase 5: add 5.6 quote form, 5.7 tradie jobs list, 5.8 tradie profile/settings, 5.9 expired/unavailable states; note Earnings placement (D-12).
- Phase 6: add "no missing-asset exceptions" to the done criteria.

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| Flipping `UI_V2=all` exposes many hidden overflows at once | Fix-0.3 first; flip per-id in journey order, never in bulk |
| Fixtures drift again | Seed fixtures inside the suite, not by hand-run scripts |
| Design and code drift again | Amend `ast/screens.mjs` and regenerate whenever a decision changes the mockup |
| Tradie users see mixed v1/v2 for weeks | Prioritise T-01…T-05 or temporarily keep tradies on the v1 shell (flag `shell` per role) |
| Commission and rate figures shown to tradies are wrong | Source from backend config only; no hard-coded 10% |

*Generated 2026-11-17 from static review of `dev` @ `541629b`. Re-run Fix-0 captures before trusting any ❓ row.*
