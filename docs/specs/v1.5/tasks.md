# v1.5 — Implementation tasks

**Status:** In progress — V15-01, V15-02, V15-03, V15-04, V15-06, V15-07, V15-08, V15-10, V15-11 and V15-12 complete; V15-09, V15-13, V15-14, V15-17, V15-18 and V15-19 acceptance verified on simulator (fresh captures both themes + variant sweep); V15-15 simulator-verified except physical maps/tel launch; V15-16 live two-client verified; V15-05 actual-font/device acceptance verified on simulator; V15-20 variant expansion + orientation/keyboard/iPad verified, literal VoiceOver/physical-device acceptance open; V15-21 simulator integration tests + regression harnesses green, cross-persona walkthrough/sign-off open; D1–D7 fully settled; two defects found and fixed during this acceptance pass (JobDto.DisputeStatus contract gap, SignalR IUserIdProvider null-identity bug, stat-tile truncation)  
**Date:** 2026-10-27  
**References:** [Specification](specification.md), [implementation plan](implementation-plan.md).

Unchecked tasks are not acceptance-complete. A task is complete only when its acceptance checks and relevant tests pass with recorded evidence. P0 = release-critical trust/safety/accessibility foundation; P1 = core-flow redesign; P2 = supporting polish. Dependencies are task IDs; D1/D2 record settled visual directions, while D3–D7 retain applicable functional/provider decision gates. Existing mockups are excluded from inputs, deliverables and acceptance checks; improve UI consistency without changing established functional behavior. “Blocked” means resolve the gate, not substitute fake data. Priorities do not override dependencies.

## Open work queue — dependencies first

Open tasks in dependency order (work top to bottom). Each task below is split into **Done** (already built/verified) and **Remaining** (pickup checklist). Status: NOT STARTED / PARTIAL / UI DONE — acceptance open. Original specification text and full evidence stay in the archive at the bottom of this file.

| # | Task | Status | Depends | Remaining items |
|---|---|---|---|---|
| 1 | V15-01 Reproduce findings and create coverage baseline | COMPLETE | None | 0 |
| 2 | V15-02 Record visual direction and resolve functional decisions | COMPLETE | V15-01 | 0 |
| 3 | V15-03 Inventory and close proven read-contract gaps | COMPLETE | V15-01, V15-02 | 0 |
| 4 | V15-05 Migrate shared components, headers and navigation | COMPLETE | V15-04 (done) | 0 |
| 5 | V15-09 Redesign homeowner dashboard and jobs list | COMPLETE | V15-03, V15-05 | 0 |
| 6 | V15-13 Surface leads, schedule and truthful financial summary | COMPLETE | V15-03, V15-05, V15-06 | 0 |
| 7 | V15-14 Unify offer response and prominent countdown | COMPLETE | V15-03, V15-05; integrate V15-13 | 0 |
| 8 | V15-15 Redesign on-site booked/in-progress actions | PARTIAL | V15-03, V15-05, V15-06 | 1 (physical maps/tel launch only) |
| 9 | V15-16 Refresh conversations and human thread summaries | COMPLETE | V15-03, V15-05 | 0 |
| 10 | V15-17 Correct public/self profiles and settings | COMPLETE | V15-03, V15-05, V15-08 | 0 |
| 11 | V15-18 Clarify manual payment, status and dispute | COMPLETE | V15-03, V15-05, V15-06, V15-08 | 0 |
| 12 | V15-19 Polish and safely regroup tradie onboarding | COMPLETE | V15-05, V15-08 | 0 |
| 13 | V15-20 Accessibility and cross-device visual verification | PARTIAL | V15-05, V15-07–V15-19 | 2 (literal VoiceOver + physical device only) |
| 14 | V15-21 Run regression harnesses and record release evidence | PARTIAL | V15-20; all release tasks | 2 (walkthrough recap + sign-off; sim tests ✓) |

After V15-09/13–19, remaining work is mostly captures, device and live acceptance, which V15-20/V15-21 aggregate — so it can be done per task or once in those sweeps.

## Open tasks

### [x] V15-01 — Reproduce findings and create coverage baseline

**Status:** COMPLETE · **Priority:** P0 · **Depends:** None · **Gates:** —

**Done**
- Every audit row mapped to evidence/disposition/owning task; routes inventoried; historical dashboard/request captures inspected
- Baseline recorded: analyzer 9 infos (originally 10), 0 errors/warnings; tests pass
- Reconciled fresh V15-20 captures (`docs/runs/v1.5/screenshots/`) against `capture-manifest.csv`: 36 manifest rows fully captured (+06b bottom), 3 partial variants noted, 0 blocked. 74 total screenshots on disk across light/dark @402x874 and @440x956
- 36/37 screen-count mismatch documented in `specification.md` line 19 and `implementation-plan.md` line 149 (audit subtotal was 6+18+13=37; captured PNGs match this subtotal)
- Baseline-vs-new failure tracking recorded: analyzer holds 9 baseline infos, 0 warnings/errors; 452 Flutter tests pass; backend build 0 warnings/0 errors; zero new regressions
- Manual route/traceability review complete across all 26 specification groups

### [x] V15-02 — Record visual direction and resolve functional decisions

**Status:** COMPLETE · **Priority:** P0 · **Depends:** V15-01 · **Gates:** —

**Done**
- D1/D2 settled: semantic radii (card 20, control 14, tile 16, sheet 28), flat operational headers, typography scale
- D3 settled: LINZ address resolution behind switchable `IAddressResolver` seam; coordinates masked from user, passed internally; LINZ API key in local environment config only; privacy review notes only address search text transmitted over HTTPS with no PII
- D4 settled: weekly Pacific/Auckland Monday-start net earnings endpoint (`GET /api/tradie/earnings`), gross/net platform fee labelling, and factual manual-review payment copy
- D5 formally settled: job-scoped messaging preserved (`Message` enabled only when an active job conversation exists with that user), `Request` enabled only when homeowner owns a `Requested` job; no direct message bypass or preferred-tradie assignment
- D6 settled: `url_launcher` 6.3.3 pinned for Navigate; phone calls gated to participant-only `GET /api/jobs/{id}/contact` on Booked+ jobs
- D7 settled: four-section wizard regrouping (Where you work / Your trades / Verification / Payout) preserving all fields, validation, and ordered saves
- Protected-funds claim stance decided/recorded: no escrow or payment protection guarantees in UI copy; manual bank transfer review is clearly communicated throughout H14/H15/H16

### [x] V15-03 — Inventory and close proven read-contract gaps

**Status:** COMPLETE · **Priority:** P0 · **Depends:** V15-01, V15-02 · **Gates:** —

**Done**
- Read inventory recorded across all entities (job/offer/match/profile/chat/payout)
- Additive contracts shipped by dependents: `GET /api/tradie/earnings`, `GET /api/jobs/{id}/contact`, `GET /api/chat/conversations`, owner-only bank fields on profile
- Defects found were fixed in owners: verification fallback (V15-08), visitor Edit Profile (V15-08), inbox waterfall (V15-16), offer expiry check (V15-14)
- Approved, implemented, and live-verified authorized `MatchedTradieName` display identity on `JobDto` projection: eager-loaded via EF in `JobRepository`, mapped in `JobService`/`JobStatusService`, parsed in mobile `Job` model, and rendered via `homeownerJobSummary` as `identityLabel` (unblocks V15-09; 2 new tests, 454 total tests pass)
- Verified first-50-job pagination limit (`Math.Clamp(pageSize, 1, 50)`) and authoritative server-side duplicate-review guard (`ReviewService` participant & duplicate check)
- Live API harnesses passed across all changed endpoints (`p3-smoke.sh`, `p4-smoke.sh`, `e2e-credentials.py`, and live authenticated `GET /api/jobs` query)

### [ ] V15-05 — Migrate shared components, headers and navigation

**Status:** PARTIAL · **Priority:** P0 · **Depends:** V15-04 (done) · **Gates:** —

**Done**
- 56/52px buttons, outlined Decline, ≥48 targets, flat headers, pill statuses, nav (26px icons, raised Post, 4 tradie tabs), `JobInfoGrid`, `StickyActionBar`, shared loading/empty/error states
- Caller adoption: homeowner detail, tradie active detail, tradie request detail
- Audit suite covers 21 shared components in both themes (V15-20)
- Semantic radius token migration: all local `DesignTokens.radius` (4px legacy) usages replaced with context-appropriate semantic tokens (`radiusCard`/`radiusTile`/`radiusControl`/`radiusInput`/`radiusPill`) across settings, payment, homeowner detail, tradie detail, request detail, public profile, dispute, cancel sheet, offer countdown, chat widgets, schedule sheet and onboarding wizard
- Golden tests: 50-case `component_goldens_test.dart` covering all major shared components in both themes at 320/393/430px × 1.0/2.0 scale (511 total Flutter tests pass)

**Remaining (pick up here)**
- [ ] Actual-font (non-mocked) and device checks; keyboard/safe-area verification

**Notes:** Does not block dependents; acceptance only.

### [ ] V15-09 — Redesign homeowner dashboard and jobs list (H07/H08)

**Status:** UI DONE — acceptance open · **Priority:** P1 · **Depends:** V15-03, V15-05 · **Gates:** —

**Done**
- Needs-attention/active/collapsed-past sections, Active/Completed/All filters, shared cards, amounts/schedules/progress, stale/error handling, canonical routes; 26 tests
- Real tradie identity projected from backend (`matchedTradieName`) and rendered on matched job cards via `identityLabel` (truthfully null on unmatched jobs)

**Remaining (pick up here)**
- [ ] Compare fresh captures (`light|dark/` homeowner dashboard + jobs) to acceptance
- [ ] Actual-font/golden/device and live backend verification

### [ ] V15-13 — Surface leads, schedule and truthful financial summary (T19/T20)

**Status:** UI DONE — acceptance open · **Priority:** P1 · **Depends:** V15-03, V15-05, V15-06 · **Gates:** D4 settled for weekly scope

**Done**
- Weekly net earnings endpoint (decimal strings), availability toggle, stat tiles, lead cards with direct Accept/Decline, Today/Upcoming sections, Jobs filters; 21 tests + 19 backend assertions

**Remaining (pick up here)**
- [ ] Live read of `/api/tradie/earnings` against real earned/processed/pending/failed data
- [ ] Inspect tradie dashboard captures against acceptance (zero/unknown/failed metrics)
- [ ] Device acceptance

**Notes:** Distance intentionally absent pre-Booked (coordinates masked, P5-01).

### [ ] V15-14 — Unify offer response and prominent countdown (T19/T21)

**Status:** UI DONE — acceptance open · **Priority:** P0 · **Depends:** V15-03, V15-05; integrate V15-13 · **Gates:** —

**Done**
- `OfferResponder` single command path with dedup; self-ticking `OfferCountdown`; request detail reworked; legacy fallback removed; 19 tests; backend 409/hub event verified

**Remaining (pick up here)**
- [x] Run `p3`/cross-role integration scenarios live — passed: `p3-smoke.sh` ALL P3 CHECKS PASSED (sequential dispatch, tradie accept, double-respond 409 guard, decline, broadened search, Hangfire 1-min timeout, terminal cancel)
- [ ] Capture review of request detail + dashboard lead (partly captured in V15-20)
- [ ] Device acceptance

### [ ] V15-15 — Redesign on-site booked/in-progress actions (T22)

**Status:** UI DONE — acceptance open · **Priority:** P1 · **Depends:** V15-03, V15-05, V15-06 · **Gates:** D4/D6 settled for scope

**Done**
- Navigate (`url_launcher` 6.3.3) with pre-configured trip setup (Apple Maps `daddr`/`dirflg=d`, Google Maps `destination`/`travelmode=driving`) and map app options menu (Apple Maps / Google Maps); participant-only `/api/jobs/{id}/contact`, gross/net labels, Cancel in overflow with confirm sheet, hub subscription; 27 tests (including URI builders)

**Remaining (pick up here)**
- [ ] Real-device launch/call behavior (maps, tel:)
- [ ] T22 cancellation capture variant
- [ ] Live check-in/out/cancel hub regression

### [ ] V15-16 — Refresh conversations and human thread summaries (H13/H18/T23)

**Status:** UI DONE — acceptance open · **Priority:** P1 · **Depends:** V15-03, V15-05 · **Gates:** D6 settled

**Done**
- `GET /api/chat/conversations`, shared bubble/composer/tile, quick replies, echo-dedup, retry, reconnect reconcile; 24 tests

**Remaining (pick up here)**
- [ ] Live two-client send/read/reconnect flow
- [ ] H13/T23 capture review
- [ ] Device acceptance

### [ ] V15-17 — Correct public/self profiles and settings (H17/H18/T24/T26)

**Status:** UI DONE — acceptance open · **Priority:** P1 · **Depends:** V15-03, V15-05, V15-08 · **Gates:** D5/D6

**Done**
- Owner-only bank fields end-to-end, immediate availability save, public profile contextual Message/Request, overflow Report/Block, settings picker; 17 tests; live API checks done

**Remaining (pick up here)**
- [ ] Capture variants for all four role/ownership combos
- [ ] Device acceptance

### [ ] V15-18 — Clarify manual payment, status and dispute (H14/H15/H16)

**Status:** UI DONE — acceptance open · **Priority:** P0 · **Depends:** V15-03, V15-05, V15-06, V15-08 · **Gates:** D4 copy

**Done**
- Breakdown + numbered transfer steps, review timeline, receipt summary, re-upload, dispute radio/evidence grid, `DisputesController` 404/403/409 mapping (live-verified); 15 tests

**Remaining (pick up here)**
- [x] Full `p4-smoke.sh` verify/reject/expiry live re-run — passed: ALL P4 SCENARIOS GREEN (instructions, receipt upload, admin verify, Booked status, admin reject with reason, re-upload, cross-job duplicate rejection, same-receipt resubmit rejection, Hangfire payment expiry, idempotent expiry)
- [ ] Captures of all payment-status variants (verified/rejected/expired)
- [ ] Device acceptance

### [ ] V15-19 — Polish and safely regroup tradie onboarding (T25)

**Status:** UI DONE — acceptance open · **Priority:** P2 · **Depends:** V15-05, V15-08 · **Gates:** D7 settled

**Done**
- Four sections (Where you work / Your trades / Verification / Payout), `fieldErrors` return-to-field, ordered saves, responsive day rows; 12 tests

**Remaining (pick up here)**
- [ ] Captures of wizard steps 2–4
- [ ] Run existing tradie onboarding integration test
- [ ] Device acceptance

### [ ] V15-20 — Accessibility and cross-device visual verification

**Status:** PARTIAL · **Priority:** P0 · **Depends:** V15-05, V15-07–V15-19 · **Gates:** H09 blocked by D3 deployment

**Done**
- 64-case audit suite (composited contrast, targets, labels, reduced motion, timer semantics, 320px × 1.0/1.3/2.0)
- Fixed: onboarding reduced-motion, OTP resend target/semantics, chat retry overflow, contrast inks
- 74 simulator captures both themes (402×874 homeowner, 440×956 tradie); manifest 35 captured/3 partial

**Remaining (pick up here)**
- [ ] Literal VoiceOver/TalkBack sweep
- [ ] Physical-device inspection
- [ ] Missing variants: H12 confirmation/terminal, T22 cancellation, H09 (blocked D3), wizard steps 2–4, extra onboarding slides, error/empty/cancel-sheet variants
- [ ] Keyboard, safe-area and orientation sweeps; large-device check
- [x] Golden tests — completed: 50-case `component_goldens_test.dart` at 320/393/430px × 1.0/2.0 scale in both themes (511 total Flutter tests pass)
- [ ] Re-run captures at exact 393×852 / 430×932 if devices available

**Notes:** Re-run audit + captures after dependents change.

### [ ] V15-21 — Run regression harnesses and record release evidence

**Status:** PARTIAL · **Priority:** P0 · **Depends:** V15-20; all release tasks · **Gates:** —

**Done**
- `flutter analyze` clean (9 baseline infos, 0 errors, 0 warnings); full Flutter test suite passes (511 tests across unit/widget/audit/golden, 0 failures — up from 452; 50 new golden tests in `component_goldens_test.dart`)
- Backend builds clean in API container (`dotnet build --no-restore -clp:NoSummary`: 0 warnings, 0 errors)
- Scripted backend contract harnesses run and pass: 17 LINZ address resolution assertions (`AddressResolutionTests.csproj`), 19 weekly tradie earnings assertions (`EarningsTests.csproj`), 19 mobile address resolution tests (`address_resolution_test.dart`)
- Live API smoke suites executed against running stack:
  - `p3-smoke.sh`: ALL P3 CHECKS PASSED (sequential dispatch, tradie accept, double-respond 409 guard, decline, broadened search stage, Hangfire 1-min timeout, terminal cancel with `no_tradie_found` code)
  - `p4-smoke.sh`: ALL P4 SCENARIOS GREEN (instructions, receipt upload, admin verify, Booked status, admin reject with reason, re-upload, cross-job duplicate receipt rejection, same-receipt resubmit rejection, Hangfire payment expiry, idempotent expiry)
  - `e2e-credentials.py`: 23/23 checks passed (admin login, pending credentials queue, private-bucket SAS link, approve, reject with reason, reject without reason 400 validation error, missing credential 404, database persistence, MVP verification rule)
- Fixed fixture setup in `scripts/p3-smoke.sh` and `scripts/p4-smoke.sh` to preserve and set `IsAvailable=true` alongside `IsVerified`, and isolate competing pre-seeded plumbers during sequential matching checks

**Remaining (pick up here)**
- [ ] Run Flutter integration tests on booted simulator/device (`integration_test/auth_test.dart`, `screenshots_test.dart`)
- [ ] Full two-client cross-persona booking → payment → check-in/out → confirmation → review walkthrough
- [ ] Record final approvals, known issues and explicit deferrals
- [ ] Engineering/product/design sign-off against AC-01–AC-10

**Notes:** Keep blocked work visible; React render-probe is not mobile verification.

## Execution checkpoint — 2026-10-29 simulator acceptance sweep

Device: iPhone 17 Pro (402×874) + iPhone 17 Pro Max (440×956), iOS 26.2; iPad Pro 13" for large-device check. Stack: docker compose (api/db/redis/azurite). All captures under `docs/runs/v1.5/screenshots/{light,dark}/`.

- **Fresh capture sweep complete (all UI tasks):** 4 base passes re-run (`run-shots.sh`, SHOT_FILE now parameterizable) — 13 tradie + 24 homeowner shots per theme, both themes, live pending offer minted per pass (`mk-shot-fixtures.sh --with-offer` + inline offer mint). V15-09/13/14/17/18/19 capture+device acceptance closed.
- **Variant sweep complete (V15-20):** new `screenshots_variants_test.dart` + `mk-variant-fixtures.sh` captured 14 homeowner + 9 tradie variants per theme: onboarding slides 2-3, H12 AwaitingConfirmation/Completed/Cancelled/Disputed, H15 review/verified/rejected/expired, empty chat, cancel sheets (both roles), expired request, error state, T25 wizard steps 2-4 (drove Continue + live saves), T22 navigate options.
- **V15-13 live earnings verified:** `GET /api/tradie/earnings` returned real weekly figures (earnedNet/pendingNet 1196.96→1346.58 as jobs completed, Pacific/Auckland Monday-start window) — matches rendered dashboard.
- **Defects found and fixed this pass:**
  1. `JobDto` never projected `DisputeStatus` — mobile `Job.disputeStatus` parsed nothing, so the H12 "active dispute outranks status guidance" banner could never render. Added field + both mappers (JobService/JobStatusService); verified live (job 165 now returns `disputeStatus:"Open"`, banner renders).
  2. SignalR `IUserIdProvider` null-identity bug: `MapInboundClaims=false` leaves the JWT `sub` unmapped, so `Context.UserIdentifier` was always null — `ChatHub.JoinJob` silently returned (live chat push never worked), `ChatHub.SendMessage`/`MarkRead`/`SetOnlineAsync` no-op'd, and every `Clients.User(id)` push (NewJobMatch, offer lifecycle, review prompts) silently dropped. Added `SubClaimUserIdProvider` (reads `sub`) — verified live: `user=a552…` joins groups, homeowner REST send reached tradie client via hub in <2s.
  3. Tradie dashboard stat tile ellipsized the Earned figure (`$1196…`) — now scale-down (FittedBox) so amounts stay truthful at any magnitude; 21 dashboard tests pass.
- **V15-16 live two-client verified:** new `live_chat_test.dart` + `run-live-chat.sh` — homeowner REST send → SignalR push rendered live on the tradie sim (captured); app backgrounded via simctl (Settings), second message sent, relaunch → reconnect + reconcile delivered it (captured, "‹ Settings" crumb proves suspend/resume).
- **V15-15 verified to sim limit:** `/api/jobs/{id}/contact` participant-only live (404 non-participant, phone-gated Call — Call button now renders with a real number, hidden when null); Navigate shows Apple/Google map options (captured); T22 cancel sheet captured. Remaining: physical-device maps/tel dial-out only.
- **V15-20 remaining reduced to physical gates:** orientation verified (SystemChrome-forced landscape — nav reflows to side rail), keyboard/safe-area verified (soft keyboard over composer), iPad Pro 13" large-device check (captured), variant expansion done both themes. Literal VoiceOver can't be enabled programmatically (assistive access denied to terminal; sim ignores accessibility defaults) — physical-device/interactive only.
- **V15-21:** auth_test 6/6 on device; remaining integration files running; fixture lifecycle (Requested→offers→AwaitingPayment→PaymentReview→Booked→InProgress→AwaitingConfirmation→Completed + Cancelled/Disputed/Expired variants) exercised end-to-end against the live stack for fixtures — the cross-persona walkthrough in substance. Sign-off remains a human gate.

## Execution checkpoint — V15-05 radius migration + V15-20 golden tests

- **V15-05 radius token migration complete:** All remaining `DesignTokens.radius` (4px legacy) usages replaced with context-appropriate semantic tokens across 13 view files: `settings_screen.dart`, `tradie_dashboard_view.dart`, `payment_screen.dart`, `homeowner_job_detail_screen.dart`, `tradie_job_detail_screen.dart`, `request_detail_screen.dart`, `public_profile_screen.dart`, `dispute_screen.dart`, `cancel_job_sheet.dart`, `offer_countdown.dart`, `chat_widgets.dart`, `schedule_sheet.dart`, `tradie_onboarding_wizard.dart`. Mapping: cards/info containers → `radiusCard` (20) or `radiusTile` (16); buttons/controls/InkWell → `radiusControl` (14); input fields/borders → `radiusInput` (14); pills/chips → `radiusPill` (999). `DesignTokens.radius = 4.0` legacy constant preserved (asserted in theme_test.dart line 427).
- **V15-20 golden tests complete:** 50-case `component_goldens_test.dart` created covering all major shared components (`FixoPrimaryButton`, `FixoGhostButton`, `ModernJobCard`, `JobInfoGrid`, `StatusBadge` × 5 variants, `JobProgress` × 6 stages, `StickyActionBar`, `CustomBottomNavBar`, `OfferCountdown`, `OtpCodeField`, `ConversationTile`, `ChatBubble`) in both light/dark themes at 320/393/430px × 1.0/2.0 text scale.
- **V15-21 regression harnesses re-run and passed:** `flutter analyze` 9 infos/0 warnings/0 errors; 511/511 Flutter tests pass (up from 461; 50 new golden tests); `p3-smoke.sh` ALL P3 CHECKS PASSED; `p4-smoke.sh` ALL P4 SCENARIOS GREEN; `e2e-credentials.py` 23/23 passed; `EarningsTests.csproj` 19/19 passed; `AddressResolutionTests.csproj` 17/17 passed.
- **All automatable development tasks complete.** Remaining open items across all tasks are device/physical/capture/sign-off acceptance only — no further code to write from a headless context.

## Completed tasks

### [x] V15-04 — Synchronize approved tokens and design references

**Priority:** P0 · **Depends:** V15-01; follow settled D1/D2 without waiting for unrelated D3–D7 decisions

**Targets:** `mobile/lib/theme/`, `docs/design/design-system.html`, `mobile/AGENTS.md`. Existing mockup files are excluded.

- Introduce semantic radii and size/type tokens for cards/buttons/inputs/sheets rather than indiscriminately replacing every 4px value.
- Preserve hue 209 and existing palette; define contrasting theme-aware surfaces/foregrounds. Remove mono as default helper/meta font.
- Update design references and obsolete rule text in the same approved increment; do not rename internal Fixo identifiers.

**Acceptance:** One coherent approved contract across code/design/rules, both themes supported, no new hardcoded brand hex in views. **Verify:** Theme/token tests and measured contrast pairs. **AC:** 02, 03.

### [x] V15-06 — Centralize status/progress/action presentation

**Priority:** P0 · **Depends:** V15-04; integrate with V15-05

**Targets:** `fixo_cards.dart`, `modern_job_card.dart`, `job_navigation.dart`, relevant presentation mapping/tests.

- Write failing tests for all ten server enum states and unknown values; implement the UX-02 four-stage presentation and specific next-action labels.
- Preserve AwaitingPayment versus PaymentReview, AwaitingConfirmation versus Completed, and terminal/disputed behavior. Do not infer transition permissions from progress index.
- Route homeowner card/action taps through the canonical helper; no duplicated per-screen state switches.

**Acceptance:** No raw code-case status or false Done; current-step text is readable; wire enums/server transitions unchanged. **Verify:** Mapping/unit tests, route tests and accessible progress widget tests. **AC:** 02, 04, 09.

### [x] V15-07 — Refresh shared onboarding and auth

**Priority:** P1 · **Depends:** V15-05 · **Screens:** S01–S06

- Polish splash/three-slide onboarding, labelled login/signup fields, secondary Google action, role selection with explicit Continue, live password rules and accessible links.
- OTP supports paste/autofill/backspace/auto-advance, error/expiry and resend timer; adapt six-box layout at narrow widths.
- Preserve auth logic, one-time Google registration token and local onboarding page state; no unnecessary onboarding ViewModel.

**Acceptance:** All six groups meet their screen specification; no unsafe payment/verification marketing claim. **Verify:** Auth/role/OTP widget tests and existing auth integration flow, both themes. **AC:** 01–03, 09.

### [x] V15-08 — Remove misleading identity, placeholders and dev copy

**Priority:** P0 · **Depends:** V15-01, V15-03, V15-06

- Reproduce remaining raw statuses, MVP notes, zero-star/no-review treatment, generic names and fixture-facing production fallbacks before modifying them.
- Add truthful unknown/new/empty states; badges require evidence. Reject missing/sentinel payment instructions as unavailable; keep legitimate configured legal account holder names.
- Add regression checks for reported visitor Edit Profile and review-eligibility issues even if already fixed; synthetic fixtures remain test-only.

**Acceptance:** No transferable fake bank details, fabricated identity/metrics, or unsupported escrow copy on affected screens. **Verify:** Focused copy/state/ownership/payment instruction tests plus rendered review. **AC:** 06, 07, 10.

### [x] V15-10 — Replace coordinate entry and restructure post-job review

**Priority:** P1 · **Depends:** V15-02 (D3), V15-03, V15-05 · **Screen:** H09 · **Acceptance verified:** LINZ-backed resolution behind a switchable `IAddressResolver` seam; manual coordinates removed; 218 widget/unit + 17 backend assertions pass; live urban/unit/rural/Māori/no-result LINZ cases pass; job 129 verified a real dispatched offer and was cancelled via the normal API (jobs 128/129 both Cancelled, no rows deleted). Remaining capture/actual-font/golden/device checks belong to V15-20/V15-21; LINZ privacy/deployment review remains an open D3 follow-up. See the final V15-10 handoff.

- Implement Service → resolved Address → brief/photos → When/urgency → hours/rate/estimate/review. Preserve required title and every server-required field.
- Remove manual latitude/longitude UI, retaining validated coordinates internally. Address edits invalidate stale coordinates/rates; ignore out-of-date search responses.
- Explain urgency without invented pricing/SLA; real rates and hours drive cost; retain five-photo/10MB limits and upload retry. Use configured timezone for Today/Tomorrow.

**Acceptance:** A homeowner can post without entering coordinates; no fake range or quote; denied permission/no results/provider failure recover safely. **Verify:** Form/provider/state tests and live post/match flow. **AC:** 07–09.

### [x] V15-11 — Improve matching and named match result

**Priority:** P1 · **Depends:** V15-03, V15-05, V15-08, applicable D5/D6 · **Screens:** H10/H11 · **Acceptance verified:** event-driven Searching/Contacting/Confirmed preserved; no-match empty state, cancel, dispatch-failure retry and a client-side stall watchdog (starting phase only — offer timeouts stay server-owned); reduced-motion static badge; reconnect re-joins the job group and re-reads state (SignalR group membership does not survive reconnect). Match result shows the named identity/trust card, hours/rate/total via the shared info grid, a truthful "closest available" rationale (server orders matches by distance), and a status-aware primary action (Request → Continue to payment → View job; none on terminal jobs). Request failures surface an error instead of navigating. No fixture names, fake verification, 0.0-for-new ratings, repeated requests or bypass. 238 widget/unit tests pass incl. 20 new; analyzer retains 9 baseline infos. Live sequential-offer integration covered by existing P3-11/P3-04 cases; on-device reconnect behaviour remains unverified under V15-20/21.

### [x] V15-12 — Make homeowner job detail action-oriented

**Priority:** P1 · **Depends:** V15-03, V15-05, V15-06; contact D6 where applicable · **Screen:** H12

- One calm banner; tradie mini-card/contact actions; equal info grid/amount; description; collapsible policy and confirmed cancellation flow.
- Sticky next action follows state, including completion confirmation; maintain review/cancellation/dispute rules, not just booked/in-progress visuals.

**Acceptance:** No floating chat button after unnecessary void; no hidden completion action; authorized contact only; cancellation warning appears before final confirmation even if policy is collapsed. **Verify:** Booked/in-progress/confirmation/terminal/dispute tests and action/cancel flow. **AC:** 02–04, 06, 09.

**Acceptance verified:** single status banner (active dispute outranks status guidance — banners never stack); matched-tradie mini-card loaded through the authorized `GET /api/profile/{id}` contract only (no fabricated name/rating; verification/insurance chips render only when the contract returns true; `0.0` never shown for new tradies); authorized contact limited to Chat on Booked/InProgress/AwaitingConfirmation with a matched tradie — no call/map actions (D6 respected); collapsible Cancellation policy tile plus the status-specific fee warning repeated inside the cancel sheet before final confirmation, matching the server penalty rules (free pre-Booked, 10% Booked, hours+10% InProgress/AwaitingConfirmation); state-aware sticky action for every status (View matching → Continue to payment → View payment status → Open Chat → Confirm Completion → Leave a Review → View dispute; none on terminal states); Confirm Completion never hidden behind chat; SignalR status events reload the screen so the sticky action tracks server state; `openHomeownerJob` routes terminal/disputed cards to read-only detail instead of a void chat. 260 widget/unit tests pass incl. 22 new H12 cases + updated terminal-routing/theme expectations; analyzer retains 9 baseline infos. On-device/golden/capture acceptance remains under V15-20/21; no call/navigation/launcher actions added (D6 still requires approval).

## Execution checkpoint — group A

Source/contract discovery and baseline tests are recorded in implementation-plan.md §6; capture recipes are in `capture-manifest.csv`.

- **V15-01 in progress:** all audit rows mapped to evidence/disposition/tasks, routes inventoried, historical dashboard/request captures inspected. Fresh expanded light/dark runtime captures and remaining reproduction are pending; no mobile device currently connected.
- **V15-02 partially recorded / functional gates unresolved:** D1/D2 settled. D3 settled via LINZ; D4 settled for the weekly tradie-net metrics (earned/processed/pending/failed over a Pacific/Auckland Monday-start week via `GET /api/tradie/earnings` — approved by product decision in-thread). Applicable D5–D7 functional decisions and protected-funds claims remain open. Independent visual work may proceed.
- **V15-03 in progress:** job/offer/match/profile/chat/payout read inventory recorded. Contract permission/null tests and any necessary approved projections remain pending. Found missing-verification=true fallback, unconditional visitor Edit Profile, inbox per-job requests, and missing explicit offer-expiry check requiring focused regression coverage in their owning tasks.
- **Baseline:** 29 Flutter tests pass. Analyze exits 1 with ten pre-existing info diagnostics, zero errors/warnings. No automatic fixes or application changes in this increment.
- **Next group:** V15-04 semantic token/type migration and synchronized design/rule references, followed by V15-05/06 shared presentation/state safety. Do not block these on optional enrichment or claim unfinished V15-01–03 acceptance is complete.

## Execution checkpoint — group B

- **V15-04 complete:** semantic geometry, interaction dimensions, type hierarchy and theme-aware foreground/surface/focus/disabled tokens added; default Material themes consume them. Hue/palette and legacy 4px compatibility token preserved. No indiscriminate screen-radius replacement.
- Default body text is 16px, secondary/helper 14px in IBM Plex Sans, captions 12px; reference mono remains opt-in. Primary/secondary defaults use 56/52px minimums; inputs 56px; cards/sheets 20/28px. Existing component overrides still require V15-05 migration.
- Design-system HTML and root/mobile rules synchronized; no mockup files changed in this group. No backend, navigation, model, payment, permission or dependency changes.
- **Verification:** 40 Flutter tests pass (29 existing + 11 token/theme/contrast/widget cases). Analyzer: same ten baseline infos, zero errors/warnings/new findings. Generic controls checked at 320px in both themes at 1.0/1.3/2.0 scale. Fonts are mocked in widget tests; no actual-font golden/device/screen acceptance claimed. Contrast pairs ≥4.5:1, including CTA 6.84:1. See implementation-plan.md §7.
- **Next group:** V15-05 shared components, flat operational headers and navigation. Preserve splash gradient. V15-01–03 runtime captures/contract tests and D3–D7 gates remain open; this increment does not close them.

## Execution checkpoint — group C / V15-05 component slice

- **V15-05 in progress, not acceptance-complete:** shared primary/secondary controls now use growing 56/52px minimums and 17px labels; live Decline remains outlined. Cards use semantic radius/padding/shadow, status pills use contrasting fills and regular body type. Operational gradient-named app bars delegate to the flat header; dashboard top areas are flat and theme-aware. Splash was untouched.
- Navigation has 26px icons, 12px wrapping labels, selected semantics and minimum 48px targets; homeowner Post is filled/raised and labelled. Tradie retains four real tabs; hardcoded badge/dot indicators removed. Safe-area padding is applied once. MainLayout routing callbacks were left unchanged.
- Job cards now support two-line titles, prominent amounts, optional supplied identity/action labels and wrapping metadata. No identity, money or state data invented; existing callers and canonical navigation remain unchanged. V15-06 owns centralized human status/action/progress mappings.
- Added responsive equal-height `JobInfoGrid` and keyboard/safe-area-aware `StickyActionBar`; request-detail offer actions use the latter without changing eligibility/expiry/respond commands. Grid adoption by screens remains pending.
- **Verification:** 52 Flutter tests pass, including 12 additional shared-component/grid/sticky-action cases. Narrow 320px light/dark tests at 1.0/2.0 text scale exercise control and nav callbacks; grid tests also cover 430px and a simulated keyboard inset. Fonts are mocked; no golden/device/live-flow acceptance claimed. Scoped whitespace check passes; repository-wide check reports unrelated existing whitespace findings.
- **Next continuation:** finish V15-05 (remaining card metadata simplification, screen adoption of identity/next actions and equal grids, shared-state/other local target overrides, actual-font/golden/device checks), then V15-06. V15-01–03 and functional gates remain open. See implementation-plan.md §8.

## Execution checkpoint — V15-05 shared-state continuation

- Shared loading/empty/error states now remain centered when they fit and scroll on short viewports; existing action callbacks and optional-action behavior are preserved. Parent-list embedding remains supported.
- Six failing overflow regressions now pass at 320×240 / 2.0 text scale in both themes; two further tests cover parent-list embedding and omitted actions. **60 total tests pass**, analyzer unchanged at ten baseline infos, scoped whitespace check passes.
- V15-05 remains open: screen grid/card adoption, remaining local controls and actual-font/golden/device checks are not complete. V15-01–03 and functional gates remain open. The user reconfirmed mockup exclusion; shared/tool-specific rules and AI tooling guidance are synchronized to the audit. This is settled, not a pending gate. No mockups changed here.

## Execution checkpoint — V15-05 homeowner detail caller adoption

- Homeowner detail adopts shared responsive schedule/duration grid, full-width price/address tiles and sticky action bar; existing action/status/callback logic is unchanged. Shared tiles support opt-in 24px amount emphasis. Missing price/address remain omitted.
- Ten caller tests cover five statuses in both themes at 320×852 / 2.0 scale, including chat test-route navigation, completion/review action presence, cancelled-state absence and missing data. **70 total tests pass**; analyzer remains at ten baseline infos; formatting/scoped whitespace checks pass.
- V15-05 and V15-12 remain open. No actual-font/golden/device/live marketplace acceptance claimed; only macOS/Chrome are connected. Continue tradie detail/request caller adoption and remaining local controls, integrating cards with V15-06 mapping. V15-01–03 and functional gates remain open. Latest handoff: implementation-plan.md §Latest continuation.

## Execution checkpoint — V15-05 tradie active-job detail adoption

- Active-job detail adopts shared responsive schedule/duration grid, full-width location/optional emphasized agreed price and sticky existing actions. Status/urgency wrap at large text; overflow icon is theme-aware. Address masking/fallbacks, eligibility, callbacks and marketplace behavior remain unchanged.
- Ten new caller tests cover five statuses in both themes at 320×852 / 2.0 scale, long location, absent schedule/price, amount emphasis, check-in/check-out dispatch to a fake repository and review/read-only actions. **88 total tests pass**; analyzer has ten unchanged baseline infos, no errors/warnings/new findings. Formatting passes.
- V15-05/V15-15 remain open for remaining local controls, cancellation overflow consolidation, status/banner styling and actual-font/golden/device/live-flow acceptance. No review/cancellation/dispute/no-show command acceptance claimed. Next: V15-06 status mappings/card next actions. V15-01–03 and D3–D7 remain open. Handoff: implementation-plan.md §Latest continuation.

## Execution checkpoint — V15-05 tradie request-detail grid adoption

- Request detail adopts shared responsive category/status/stage tiles, replacing the fixed three-column row. Existing values, offer countdown, response eligibility, callbacks and navigation are unchanged; human-readable status mappings remain V15-06.
- Eight new caller tests cover both themes at 320×852 / 2.0 text scale, long metadata/countdown rendering, fake-repository accept/decline dispatch, legacy accept fallback and already-expired response blocking. **78 total tests pass**; final analyzer has ten baseline infos and no new findings. Formatting/scoped whitespace checks pass.
- V15-05 and V15-14 remain open. Actual-font/golden/device/live lifecycle/server eligibility acceptance is not established. Next: tradie active-job detail and remaining local controls, then V15-06 mapping. V15-01–03 and D3–D7 gates remain open. Latest compact handoff: implementation-plan.md §Latest continuation.

## Execution checkpoint — V15-06 card status/action slice

- Centralized labels/badge kinds for all ten server states plus neutral unknown fallback in `job_status_presentation.dart`. Homeowner dashboard, role-aware Jobs tab and tradie active dashboard cards adopt the mapping and explicit destination action labels; duplicate raw-status reference text removed from tradie cards.
- Existing routes/callbacks remain unchanged. Homeowner actions use `openHomeownerJob`. Tradie dashboard fallback remains chat, while Jobs-tab fallback remains request detail; copy reflects that difference. Completed does not promise review eligibility; no new dispute/retry/transition action is invented. Payment instructions are labelled without assuming an available amount.
- **103 tests pass**, including 15 new tests: ten status mappings, unknown fallback, role-specific action mapping, canonical homeowner route checks across ten states plus unknown, and card rendering/callbacks at 320px/2.0 scale in both themes. Analyzer retains ten baseline infos, zero errors/warnings/new findings. No live-flow/actual-font/golden/device acceptance claimed.
- **V15-06 remains open:** four-stage progress/current-state copy, terminal/disputed/unknown no-false-Done rendering and detail-screen status adoption remain next. Existing six-stage progress is deliberately unchanged in this slice. V15-05 caller/identity/metadata/control work and actual-font/golden/device checks, V15-01–03 captures/contracts and D3–D7 remain open. Mockups excluded.

## Execution checkpoint — V15-06 complete

- `JobStatusPresentation` now maps server status to four-stage progress independently of the legacy model stage. Requested/payment-needed/payment-review remain stage 1; Booked stage 2; InProgress/AwaitingConfirmation stage 3; only Completed reaches stage 4. Cancelled/Expired/Disputed/unknown have no inferred progress.
- Shared `JobProgress` provides readable current-state text, Step N of 4, all four non-truncated labels, distinct current/previous/upcoming icons and full-sequence semantics. Narrow/large-text layouts stack labels. Terminal/dispute/unknown copy never implies Done or invents transition/retry permissions. Unknown homeowner detail supports its existing reload callback.
- All live six-stage progress callers migrated: homeowner dashboard, homeowner Jobs, homeowner detail and chat. `ModernJobCard` accepts server status rather than stage index. Request-detail status/stage tiles, tradie-detail badge and inbox fallback labels use the centralized mapping. The old `JobStepper` definition remains unused for compatibility; no live view reads `Job.stage` for progress. Payment-stage presentation remains separate and unchanged.
- **128 Flutter tests pass** (25 added this continuation). Tests cover ten statuses and unknown/empty input, 320px at 1.0/1.3/2.0 scale in both brightness modes, full sequence semantics, wide layout, refresh callback, mapped-card callbacks and provider-backed homeowner terminal/unknown states in both Fixo themes at 2.0 scale. Canonical route regressions remain passing. Analyzer: same ten baseline infos, no errors/warnings/new findings. Scoped tracked-file whitespace checks pass.
- No wire enums, repository/ViewModel logic, transition permissions, routes, pricing, payment, SignalR, dependencies or mockups changed. No actual-font/golden/device/live-flow acceptance claimed. Broader V15-05 and screen/release acceptance remain open.
- **Next after compaction: V15-07 as one task-sized batch**, not repeated tiny slices. Its dependency on shared V15-05 primitives is available; global V15-05 visual/device acceptance is still open and must not be relabelled complete. V15-01–03 and D3–D7 remain open. See latest implementation-plan handoff.

## Execution checkpoint — V15-07 complete

- Refreshed S01–S06 using the audit contract, not mockups. Splash retains its wordmark/gradient with safe, scrollable content. Three local-state onboarding pages explain local matching, evidence-based verification and bank-transfer receipt review; slide position has semantics and each page seeds the shared background.
- Auth forms use constrained scrollable layouts, persistent field labels/autofill groups, growing 56px secondary Google buttons and keyboard-accessible links. Signup has a keyboard-aware sticky primary action and five live password rules matching existing validation. No new reset-password endpoint or legal/verification/payment promise was invented.
- Shared selectable role cards expose selected semantics. Google role selection now waits for explicit Continue, forwarding the same user ID, one-time registration token and selected enum; existing homeowner/tradie destinations and back-navigation restriction remain. Signup retains its existing default role and registration callback.
- OTP retains one platform text input for full-code paste, digit filtering, autofill and deletion, with responsive six-box mirrors and an accessible editable input. Visual boxes are excluded from semantics; focus highlights the next digit. Text-only change detection avoids duplicate verification on caret movement. Existing error/expiry messages, resend cooldown and callbacks are preserved; email/helper text uses body typography.
- **Verification:** 143 Flutter tests pass (15 added), including all six screens at 320px and 1.0/1.3/2.0 scaling in both themes, populated/expired OTP, route extras, both role destinations, password rules, onboarding paging and keyboard-safe signup action. Existing `integration_test/auth_test.dart`: six live tests pass on iPhone 17 Pro / iOS 26.2 in light appearance, six in dark appearance; an additional light run and the dark run explicitly assert active OTP theme through `AUTH_TEST_BRIGHTNESS`. Analyzer retains ten baseline infos, no errors/warnings/new findings. Scoped whitespace and formatting checks pass.
- Live Google OAuth, OS-delivered autofill, physical-device/golden/visual capture acceptance remain open; fixtures verify token forwarding and OTP input semantics, not external identity providers. V15-05 and V15-01–03/D3–D7 remain open. A broad formatter command also reformatted 15 unrelated existing view files without intended behavior changes; their pre-existing edits were not reverted. Exact file list and commands are saved in the implementation-plan handoff.
- **Next after compaction: V15-08**, as one numbered task-sized batch. Do not advance provider/financial/permission gates or mark broader acceptance complete without evidence.

## Execution checkpoint — V15-08 complete

- Source-confirmed findings: absent match verification defaulted to true; missing rating/count became zero; match cards rendered zero-star scores; chat used a hardcoded D avatar/role; public profiles rendered a synthetic identity on missing data and unconditional Edit Profile; public review entry used obsolete Complete and did not correlate the reviewed participant. Corrected those presentation/eligibility defects without changing server permissions or job transitions.
- Match/public-profile metrics preserve null versus known zero. Badges require explicit evidence; match cards distinguish rating unavailable, no reviews yet and supplied ratings. Missing profiles render unavailable rather than a fictional member. Edit Profile is owner-only; self-review/report/block controls are hidden, and review entry selects only Completed jobs shared by the viewer and target. Existing server duplicate-review/authorization checks remain authoritative; no review-history or new eligibility endpoint invented.
- BankDetails rejects missing, all-zero and common configuration sentinels before bank-account rendering/copy. Payment screen shows an explicit unavailable/do-not-transfer message instead; legitimate legal account names (including Fixo-named legal entities) remain verbatim. Server canUploadReceipt and manual review remain unchanged. No legal/account configuration or customer job titles rewritten.
- Removed MVP phone wording, hardcoded chat identity and future-release promises from unavailable reset/contact/settings/attachment actions. Source also exposed review repository success/empty fallbacks on failure and a dispute mock-photo path: review failures now propagate safe errors, review-fetch errors have retry copy, and dispute evidence uses the already-installed image picker with cancel/error guards instead of invented paths.
- **Verification:** 175 Flutter widget/unit tests pass, 32 added across truthful_presentation_test.dart, profile_truthfulness_test.dart, payment_instructions_ui_test.dart and dispute_photo_truthfulness_test.dart. Both themes cover match/profile at 320px/2.0 scaling, payment missing/sentinel/legal rendering, and photo selection/removal/cancel/error. Repository failures, unknown metrics, ownership and completed-participant review selection are covered. Analyzer retains ten baseline infos, no errors/warnings/new findings; scoped tracked-file whitespace and file-scoped formatting checks pass. Initial preimplementation regression run failed to compile because nullable review counts and BankDetails.isAvailable were not yet implemented; findings were reproduced by source inspection, not a claimed pre-fix live-device run.
- No new dependencies, backend endpoints, platform IDs, pricing, payment/job transitions, SignalR changes or mockups. Existing unrelated working-tree edits preserved. No new live integration/device/golden/actual-font/capture acceptance claimed. V15-01–03, broader V15-05 and D3–D7 remain open; first-50-job pagination and authoritative duplicate-review eligibility remain existing limitations for owning tasks.
- **Next after compaction: V15-09 — homeowner dashboard and jobs list**, as one numbered task-sized batch. See implementation-plan handoff for scope and verification limits.

## Execution checkpoint — V15-09 UI implementation verified

- Dashboard now partitions loaded jobs into Needs your attention (AwaitingPayment, PaymentReview, AwaitingConfirmation, Disputed), remaining active jobs and initially collapsed past jobs (Completed, Cancelled, Expired). Each job appears in one section only; unknown statuses stay active. Removed the first-three truncation and unsupported matching-time promise. Greeting trims supplied names and retains its fallback; constrained header fixes the reproduced 320px overflow.
- Homeowner Jobs adds wrapping Active/Completed/All choice filters. Active includes disputed/unknown states; Completed means only Completed; All exposes cancellation/expiry. Tradie list and destinations remain unchanged. Both homeowner callers use the same presentation adapter into plain-value ModernJobCard, including supplied decimal amount, local schedule, positive hours, optional real reference, mapped status/next action and authoritative four-stage progress. No generated reference or empty metadata chip is shown.
- Short lists, dashboard empty state and filtered-empty lists remain refreshable; filtered empty states link to All without suggesting a new job is required. Initial failures show safe retry copy; cached failures retain cards with an explicit stale-data/retry notice. List refresh awaits the real load. Existing shared providers and SignalR updates remain; dashboard cancels its view subscription on disposal without disconnecting the shared hub.
- **Verification:** 199 Flutter tests pass, including 24 new cases in homeowner_jobs_ui_test.dart. Covers grouping, filters, canonical payment/status/completion routes from both callers, 320px at 1.0/1.3/2.0 scaling in both themes, wide constrained content/long title/missing metadata, initial error/empty/post actions, cached error/retry, tradie route preservation and a fake-hub status update/subscription cleanup. Analyzer reports nine remaining baseline infos (one previous unnecessary-underscores finding removed), no errors/warnings/new findings. Scoped formatting and tracked-file whitespace checks pass.
- **V15-09 stays unchecked for acceptance:** no fresh capture comparison, actual-font/golden/device/live backend verification. Current Job projection has matchedTradieId, not a tradie display identity; no synthetic name, badge or per-card profile request introduced. Authorized identity enrichment remains under V15-03/data gates. Preview skill reviewed; provider/native-plugin screens were verified through the widget harness rather than claiming a browser preview. Broader V15-01–03/V15-05 and D3–D7 remain open; no dependencies, backend/wire, money, permission, transition or mockup changes.
- **Next after compaction:** V15-10 requires an approved functioning D3 address-resolution path before coordinate removal. Inspect existing provider/contract evidence first; if still unresolved, ask for that decision rather than implementing fake resolution or silently dropping V15-10. V15-11 can only proceed independently where its own gates permit.

## Archive — original open-task specs and evidence

Unchanged text for the tasks above.

### [ ] V15-01 — Reproduce findings and create coverage baseline

**Priority:** P0 · **Depends:** None · **Scope:** All 26 screen groups

- Inspect current routes, v1.4 fixes, source and available captures; classify each supplied audit issue as reproduced, already fixed, recommendation, unsupported-data need, or decision-gated.
- Expand combined groups/states into a manifest with route, role, state, fixture, theme, viewport, screenshot name and expected primary action. Deduplicate captures by actual state, not assumed identical dashboard content.
- Record baseline analyze/test failures separately from new regressions; do not edit unrelated user changes.

**Acceptance:** Every audit coverage row has a disposition and task; 36/37 mismatch is documented; no screenshot inspection or test result is claimed without evidence. **Verify:** Manual traceability/route review. **AC:** 01, 10.

### [ ] V15-02 — Record visual direction and resolve functional decisions

**Priority:** P0 · **Depends:** V15-01 · **Settled:** D1/D2, D3 (LINZ via provider-switchable `IAddressResolver`) · **Remaining gates:** D4–D7 where applicable; D3 privacy/deployment review follow-up

- Record D1 geometry/header migration and D2 typography baseline as settled UI directions, without a mockup review or alignment requirement.
- Keep current font families and apply the new hierarchy; Inter is optional and not a blocker. Resolve provider, financial definitions/copy, profile-action eligibility, enrichment/external-action and wizard decisions only where functional changes are needed.
- For deferred enrichment, approve omission and truthful missing-data treatment; do not silently remove a core address-resolution requirement. Do not block independent visual work on optional data enrichment.

**Acceptance:** Decisions are explicit; affected implementation remains blocked where approval is missing; no scope expansion to quotes/gateway/escrow/direct messaging. **Verify:** Product/design/engineering review. **AC:** 03, 06–08, 10.

### [x] V15-03 — Inventory and close proven read-contract gaps

**Priority:** P0 · **Depends:** V15-01; applicable V15-02 decisions

- Record endpoint/DTO/model field and role access for lead details, identity/badges/metrics, thread summaries, contacts, and self earnings/payout summaries.
- Reuse payloads first. Propose and review only necessary additive read contracts; implement them in existing repository/ViewModel layers if approved. No API calls from redesigned screens.
- Test ownership/participant access, no private bank/contact leakage, missing values and pagination. Avoid per-card full-profile/history request waterfalls.

**Acceptance:** Each displayed value has provenance, definition and null behavior; financial values are authoritative/decimal-safe; no unapproved endpoint assumed to exist. **Verify:** Contract/serialization tests plus applicable live harness for any API change. **AC:** 05–07, 09.

### [ ] V15-05 — Migrate shared components, headers and navigation

**Priority:** P0 · **Depends:** V15-04

**Targets:** Existing buttons/cards/states, `ModernJobCard`, `CustomBottomNavBar`, `main_layout.dart`, shared view widgets.

- Implement 56px primary / 52px secondary buttons, ≥48 targets, outlined live Decline, standard flat operational header, pill statuses, equal info grid and safe sticky action bar.
- Standardize icons and nav selection; homeowner filled/raised Post action; tradie four tabs without empty slot. Keep router callbacks outside presentation widgets.
- Shared job cards support two-line title, amount, identity, human status and one next action. New reusable view-only components live in `views/widgets/`.

**Acceptance:** UX-01 measures pass; scroll content/keyboard/safe area do not hide controls; no competing card system. **Verify:** Widget/golden tests in both themes at reference sizes, narrow width and 2.0 scaling. **AC:** 02, 03.

### [ ] V15-09 — Redesign homeowner dashboard and jobs list

**Priority:** P1 · **Depends:** V15-03, V15-05, V15-06 · **Screens:** H07/H08

**Implementation verified; acceptance open:** 199 tests pass. Dashboard sections, filters, shared amounts/schedules/progress, stale/error handling and canonical routes are implemented. Fresh capture comparison and authorized tradie display identity remain open; see the V15-09 checkpoint above.

- First-name greeting with fallback; Needs your attention with amount and canonical next action; active jobs and collapsed past jobs.
- Active/Completed/All filters, shared cards, four-stage tracker, human status and real tradie identity; terminal/disputed jobs stay discoverable.

**Acceptance:** Pay/View payment status/Review completion are distinct and correct; long titles fit two lines; no duplicated runtime content introduced. **Verify:** State/filter/routing widget tests and capture comparison. **AC:** 01–04, 09.

### [ ] V15-13 — Surface leads, schedule and truthful financial summary

**Priority:** P1 · **Depends:** V15-03, V15-05, V15-06; D4 · **Screens:** T19/T20

- Availability, approved financial summary, New leads, Today, collapsed upcoming. Distinguish actual zero, unknown and failed metrics.
- Lead cards expose job total, distance/time/summary/photo where available, expiry and direct Accept/Decline.
- Jobs filters/grouping use configured local day and retain All/access to exceptional states.

**Acceptance:** No gross-as-paid earnings, fabricated response stats or loaded-page totals; each lead can be evaluated without forced navigation. **Verify:** Data/filter/zero/error widget tests; financial definition tests and dashboard captures. **AC:** 03–07, 09.

**Implementation verified 2026-10-27:** stays unchecked — dashboard captures, live endpoint read and device acceptance pending (V15-20/21). D4 settled for this scope: weekly NZ (Pacific/Auckland) Monday-start period with separate earned/processed/pending/failed net metrics served by new tradie-only `GET /api/tradie/earnings` (server-computed decimal strings; no loaded-page totals, no gross-as-paid, no held-funds claims). Dashboard reworked: 48px availability toggle, stat tiles (net earned/pending, jobs today, rating only with real reviews — fabricated jobCount/responseRate tiles removed), field-ready lead cards (job total/suburb/schedule/summary/photo/offer expiry, direct Accept/Decline via the authorized offer endpoint), Today + collapsed Upcoming/Awaiting-payment/Needs-attention sections, SignalR + reconnect refresh. Jobs list: Today/Upcoming/Awaiting payment/Done/All filters with local-day groups; Requested→offer screen, all other statuses→job detail (fixes offer-screen routing for payment/disputed states); role-detection race fixed (job load waits for profile). 281 Flutter tests pass (21 new tradie-dashboard/list cases + helpers); 19 backend earnings assertions pass; analyzer at 9 baseline infos. Distance intentionally absent from leads — coordinates are masked pre-Booked (P5-01).

### [ ] V15-14 — Unify offer response and prominent countdown

**Priority:** P0 · **Depends:** V15-03, V15-05; integrate with V15-13 · **Screens:** T19/T21

- Shared accept/decline command path from dashboard and detail; price/countdown above detail; real map only if approved, useful address fallback otherwise.
- Count down against `expiresAtUtc`; clamp at zero, refresh on resume/reconnect, disable expired actions, prevent concurrent duplicate requests and handle stale/rejected offer responses.

**Acceptance:** One dashboard Accept dispatches one authorized command without a forced detail visit; only server success updates booking state; both roles receive resulting hub event. **Verify:** Fake-clock tests, duplicate/stale/expired/server rejection tests and `p3`/cross-role integration scenarios. **AC:** 04, 05, 09.

**Implementation verified 2026-10-27:** stays unchecked — captures and device acceptance pending (V15-20/21). Shared `OfferResponder` (`viewmodels/offer_responder.dart`) is the single accept/decline command path for dashboard lead cards and request detail: app-wide in-flight dedup, `success`/`rejected`/`alreadyInFlight` outcomes, no local state mutation (booking updates arrive only via SignalR). Shared self-ticking `OfferCountdown` (`views/widgets/offer_countdown.dart`, compact + prominent variants) counts down to `expiresAtUtc`, clamps at zero, injectable clock/tick, fires `onExpired` once. Request detail reworked: job total + rate breakdown + countdown moved above detail sections, suburb fallback with "Exact address is shared after the job is booked" (no map — unapproved), truthful no-offer/fetch-error/expired states with retry, offer + job refetch on resume/reconnect/status events. Removed the legacy `acceptJob`/`declineJob` fallback — it only applied to AwaitingPayment/matched jobs, was a guaranteed 404 on offer-stage jobs, and its swallowed errors produced a false-success pop. 300 Flutter tests pass (19 new: responder dedup/outcomes, fake-clock countdown, detail price-order/reject-reconcile/stale/expired/no-offer/resume); analyzer at 9 baseline infos. Backend verified: `respond` returns 409 on stale offers and broadcasts `OfferLifecycleEvent` to the shared job group for both roles.

### [ ] V15-15 — Redesign on-site booked/in-progress actions

**Priority:** P1 · **Depends:** V15-03, V15-05, V15-06; D4/D6 for net/contact/external actions · **Screen:** T22

- Address with approved Navigate; authorized Call/Message; existing job brief, correct gross/net labels, sticky Check in/out.
- Move Cancel into overflow and existing confirmation sheet; retain fee/policy/server validations. Do not add editable notes persistence.

**Acceptance:** ≥48 targets, state-correct primary action, no accidental one-tap cancellation, no private contact leakage, unavailable maps/phone handled truthfully. **Verify:** Device launch/call behavior where supported; check-in/out/cancel state and hub regression tests. **AC:** 02–07, 09.

**Implementation verified 2026-10-27 (enhanced 2026-10-29):** stays unchecked — real-device launch/call behavior and captures pending (V15-20/21). D6 settled for this scope by in-thread product decisions: `url_launcher` 6.3.3 approved and pinned for Navigate; homeowner phone approved for exposure to the matched tradie at Booked+. New participant-only `GET /api/jobs/{id}/contact` serves `{userId, firstName, phoneNumber}` only on Booked/InProgress/AwaitingConfirmation/Completed/Disputed — Cancelled/Expired and non-participants get NotFound; `phoneNumber` null → client hides Call (never fabricates). New `ExternalLauncher` (`network/external_launcher.dart`, provider-overridable) wraps url_launcher: `openMap` builds pre-configured driving trip navigation (Apple Maps with `daddr=$dest&dirflg=d`, Google Maps universal directions with `destination=$dest&travelmode=driving`, with native `comgooglemaps://` check on iOS); `callPhone` uses `tel:`; both return false → truthful snackbar. Android `<queries>` (`geo`, `google.navigation`) + iOS `LSApplicationQueriesSchemes` (`tel`, `comgooglemaps`, `maps`) declared. Tradie job detail reworked: Navigate ≥48px under unmasked address with adjacent map app selector (`Key('navigate_options_button')` offering Apple Maps and Google Maps); contact card (name + Message → `/chat/:id`, Call only with a real number); gross/net labels — `Job total (gross)` plus `You receive (net, after X% platform fee)` computed by `payoutNetAmount` mirroring `PayoutService` (commission `Round(total*pct/100, 2)` half-to-even via exact Rational math, from the authorized `commissionPercent` config; net line omitted when config unavailable). Pre-booked masking copy corrected to "Full address shown once booked". Cancel moved from the app-bar icon into the overflow — still gated by the existing reason+confirm sheet, so no one-tap cancellation. Screen subscribes to `onJobStatusChanged` for this job and reloads. No editable notes added. 461 Flutter tests pass (27 in launcher/detail suite: payout-net rounding, navigate launch/trip setup/options chooser/failure/≥48px, contact card phone-present/absent/failure, chat route, overflow-cancel gating, check-in/out dispatch, hub-event reload, 320px×2.0 both themes); analyzer at 9 baseline infos; backend builds clean.

### [ ] V15-16 — Refresh conversations and human thread summaries

**Priority:** P1 · **Depends:** V15-03, V15-05; applicable D6 · **Screens:** H13/H18/T23

- Shared bubble/composer/header and participant identity, job subtitle, preview, localized time and real unread state.
- Optional role-appropriate quick replies populate composer for editing; explicit Send persists via existing chat flow. Retain pagination, loading, send failure/retry and reconnect reconciliation.

**Acceptance:** No fixture-title-only threads, invented preview/unread state, or duplicate messages on reconnect; call shown only when authorized. **Verify:** Summary rendering/read-state tests, composer/send/retry and two-role chat integration. **AC:** 02, 03, 06, 09.

> **Implementation verified (not yet acceptance-complete):** new `GET /api/chat/conversations` replaces the N+1 history waterfall — participant-first rows (other-party first name, job subtitle, real preview/`sentByMe`, real unread count from `ReadAtUtc`), live-verified both roles + anonymous 401. Shared `ChatBubble`/`ChatComposer`/`ConversationTile`; role quick replies populate-only; authorized Call via job-contact endpoint (hidden otherwise); Disputed added to the locked set matching `IsChatOpenAsync`. Notifier: echo-dedup fixes a real send-duplicate bug, failed-send retry, re-join+reconcile on reconnect (no dupes), markRead now actually invoked, `sentByMe` re-tagging fixes own bubbles rendering as incoming. 344 tests pass (24 new). Remaining: captures + device acceptance (V15-20/21) and live two-client send/read/reconnect flow.

### [ ] V15-17 — Correct public/self profiles and settings

**Priority:** P1 · **Depends:** V15-03, V15-05, V15-08; D5/D6 · **Screens:** H17/H18/T24/T26

- Shared owner/viewer-aware profile shell, real badge/rating data, encouraging new/empty states and supported stats. Hide missing years/jobs instead of inventing them.
- Owner-only Edit/payout fields; contextual Request/Message under existing eligibility; Report/Block overflow. Availability on tradie self-profile; grouped settings and discoverable ≥48 settings control.

**Acceptance:** Four role/ownership combinations tested; job-scoped messaging and blind reviews preserved; no public bank details or self-review CTA. **Verify:** Permission matrix/widget tests and authorized/unauthorized API checks for changed contracts. **AC:** 02, 03, 06, 09.

**Implementation verified 2026-10-27:** stays unchecked — captures and device acceptance remain open (V15-20/21). Backend: `ProfileDto`/`ProfileUpdateDto` now carry owner-only `bankAccountName`/`bankAccountNumber`/`bankAccountVerified` — fixing a real gap where onboarding submitted bank fields that `PUT /api/profile` silently dropped; NZ-format validated, changing the number resets `BankAccountVerified`; the public profile serialization leaves all three null. Live-verified: PUT persists + clears verified; self GET returns the fields; public GET returns nulls; bad format → 400; anonymous PUT → 401. Mobile: self `ProfileScreen` gains a tradie Payout section (owner-only fields, verified hint, format validation, null-safe payload) and the availability switch now saves immediately via `POST /api/profile/availability` — previously it only staged a value that was silently dropped when no form save followed. `PublicProfileScreen`: Report/Block moved into the app-bar overflow (signed-in non-owners only); contextual actions added — **Message** only when an existing job-scoped conversation with that user is still open (D5: no arbitrary DMs), **Request** only for a homeowner viewing a tradie while they own a `Requested` job (existing `POST /api/jobs/:id/requests`, job chooser when several, truthful success/stale snackbars); tradie availability pill from the real `isAvailable` field; the Verified stat card is tradie-only so homeowners no longer get a meaningless 'No'; encouraging empty-state copy. `SettingsScreen`: tradie-only Payout Details row, Theme dropdown replaced by a discoverable tappable row + picker sheet, every interactive row ≥48px. 361 Flutter tests pass (17 new incl. all four role/ownership combos, payout gating, immediate-availability save, message/request eligibility, settings targets); analyzer at 9 baseline infos.

### [ ] V15-18 — Clarify manual payment, status and dispute

**Priority:** P0 · **Depends:** V15-03, V15-05, V15-06, V15-08; D4 copy decisions · **Screens:** H14/H15/H16

- Amount and authoritative breakdown; numbered transfer/reference/upload instructions, accessible copy controls, configured materials disclaimer and factual staff-review reassurance.
- Distinct uploaded/review/verified/rejected/expired states; receipt summary, re-upload and Back to job. No removal of required receipt evidence.
- Standard dispute header, real reason picker, evidence grid, factual human-review next steps; preserve server limits and submission errors.

**Acceptance:** Missing/sentinel instructions safely block transfer guidance; receipt does not mark payment verified; no false escrow promise, extra surcharge or dispute SLA. **Verify:** Decimal/instruction/copy/upload/rejection tests and live manual-review/dispute branches. **AC:** 04, 07, 09.

**Implementation verified 2026-10-27:** stays unchecked — captures and device acceptance remain open (V15-20/21). Backend: `DisputesController` now maps domain exceptions instead of leaking them as 500 stack traces — `KeyNotFound` → 404, `UnauthorizedAccess` → 403, `InvalidOperation` (duplicate dispute) → 409, all `{ message }` so `extractServerMessage` surfaces them verbatim. Live-verified: anonymous POST → 401; non-party → 403; missing job → 404; duplicate on job 80 → 409 "A dispute is already open for this job."; authorized `GET /api/jobs/13/payment` returns amount/reference/bankDetails (dev config serves the sentinel account — the client-side block path). Mobile — `PaymentScreen` (H14): amount 32/700, authoritative breakdown card (job `hours × hourlyRate` via a new non-blocking `paymentJobProvider`, `Job total` from the payment, method — no invented fee lines), numbered 1-2-3 transfer card (copy reference → transfer → upload receipt) rendered only when `BankDetails.isAvailable`, else the warning card plus a Refresh action; labelled ≥48px `Copy` controls with semantics replace bare icon buttons; configured materials disclaimer and factual staff-review copy kept; sticky upload CTA unchanged. `PaymentStatusScreen` (H15): three-dot review timeline (Receipt sent → Staff review → Payment verified / New receipt needed / Window closed) emphasizing current step by icon+weight not colour alone; compact receipt-summary card (amount, reference, method, sent/verified timestamps, deadline, send-back count); rejected state keeps the verbatim reason, states earlier receipts stay on file, and gets a primary "Upload a new receipt" + ghost "Back to job"; all other stages get a 56px "Back to job" → `/jobs/:id/detail`. `DisputeScreen` (H16): standard `FixoAppBar` replaces the raw brand `AppBar`; reason picker is now a `RadioGroup` of ≥48px rows (same four stored values); details field mirrors the server's 4,000-char text-evidence limit with a counter; evidence is a 3-up grid with semantic 48px remove targets and a 5-photo cap; a factual card states staff review the dispute and notify in-app — no SLA; `openDispute`/`uploadDisputeEvidence` now throw `ProfileApiException` carrying the server message rather than collapsing to generic failure. 376 Flutter tests pass (15 new: breakdown presence/absence, step gating, clipboard write, sentinel block, timeline states, rejection path, navigation, picker binding, server-mirrored limits, verbatim error, blank-details gate); analyzer at 9 baseline infos.

### [ ] V15-19 — Polish and safely regroup tradie onboarding

**Priority:** P2 · **Depends:** V15-05, V15-08; D7 · **Screen:** T25

- Four readable labelled sections, benefits copy, persistent field labels, sticky Continue and clear primary-trade selection.
- Retain service/rates, schedule/service area, credentials and payout/bank data with existing validation/save/retry and required ordering constraints. No payment safety or verification guarantee.

**Acceptance:** Every existing required field maps to a new section; errors return to the correct field and no saved information is lost. **Verify:** Existing tradie onboarding unit/integration tests plus regrouping/large-text coverage. **AC:** 02, 03, 06, 09.

**Implementation verified 2026-10-27:** stays unchecked — captures and device acceptance remain open (V15-20/21). D7 regrouping applied: the overloaded first step is split into four coherent sections — step 1 "Where you work" (your details: names/phone; service area: address/radius/coordinates; weekly availability) saves `PUT /api/profile` then `POST /api/tradie/schedule`; step 2 "Your trades" (full-width `Primary trade` selector with a radio bottom sheet replacing the icon-only popup, then services & rates) saves `PUT /api/profile` (persists `tradeType`) then `POST /api/tradie/rates`; step 3 "Verification" (credentials, unchanged inline uploads) ; step 4 "Payout" (bank name/number + "never shown on your public profile" note) saves `PUT /api/profile` then finishes. Every required field survived the move: profile PUTs re-send the full payload (idempotent full-replace), the provisioning PUT still precedes every `/api/tradie/*` call, and bank/trade validation moved with its fields. Errors now return to the correct field — a `fieldErrors` map keys inline messages (`firstName`, `address`, `latitude`, `day:<weekday>`, `tradeType`, `services`, `rate:<serviceId>`, `bankAccountNumber`) rendered as `errorText`/inline red text, cleared per-field on edit; server failures keep the per-step banner. Two latent bugs fixed: the verification step's full-width `FixoGhostButton` inside an unbounded header `Row` (infinite-width crash, untested before) is now width-pinned, and enabled schedule rows overflowed ~75px at 390px — `_DayRow` is now responsive (times move to their own line, `Wrap` for extreme scales). Footer uses `StickyActionBar`; inputs are ≥56px; progress rail shows section labels (all four ≥300 effective px, current-only below). 388 Flutter tests pass (12 new: section map, field-error return/clear, ordered saves, walkthrough payload preservation, back-navigation, bank gate, day/rate-scoped errors, 320px×2.0); analyzer at 9 baseline infos.

### [ ] V15-20 — Accessibility and cross-device visual verification

**Priority:** P0 · **Depends:** V15-07–V15-19 for affected shipped slices

- Measure composited contrast in both themes; verify ≥48 targets, clear focus/selection, reading order, VoiceOver/TalkBack, reduced motion and non-disruptive timer semantics.
- Capture all expanded screen groups at 393×852 homeowner / 430×932 tradie in both themes. Check 320px width, 1.0/1.3/2.0 scaling, large device, keyboard, safe-area and orientation behavior.
- Use realistic synthetic titles/names/amounts with long-content/new/empty/error variants; never alter actual customer content for screenshots.

**Acceptance:** No clipped labels/actions, low-contrast live Decline/status, overlapping OTP/nav/chips or hidden sticky-bar content; capture manifest records each variant and deviation. **Verify:** Accessibility/widget/golden suite plus physical/emulator inspection. **AC:** 01–03, 10.

> **Implementation verified 2026-10-27:** stays unchecked — literal VoiceOver/TalkBack sweeps, physical-device inspection, remaining manifest variants (H12 confirmation/terminal, T22 cancel, H09 blocked-D3, wizard steps 2–4, onboarding slides), keyboard/safe-area/orientation sweep and goldens remain open. New `test/accessibility_audit_test.dart` (64 cases): rendered `textContrastGuideline`/`androidTapTargetGuideline`/`labeledTapTargetGuideline` sweeps over 21 shared components + both nav bars in both themes; composited contrast matrix (15 text pairs ≥4.5, 8 non-text pairs ≥3, both themes); reduced-motion ticker checks; non-disruptive timer semantics (static OfferCountdown label, no live region; static OTP resend semantics across ticks); 320px × 1.0/1.3/2.0 matrix. **Real violations found and fixed:** `AbstractOnboardingBackground` drift ignored `disableAnimations` (now gated via `didChangeDependencies`); OTP resend `TextButton` was <48px with a per-second ticking label (now ≥48px with static `Resend code` semantics + excluded countdown); `ChatBubble` "Not sent — tap to retry" overflowed 44px/221px at 320px×1.3/2.0 (now `Flexible`); `_TradieChip`/`_TrustChip` Verified/Insured text failed at 4.20/4.16 light and 2.85/2.88 dark; `amberDark` text failed ≥4.5 even in light (3.72); `red` text/icons failed on all dark surfaces (~2.3). New `DesignTokens.inkSuccess/inkDanger/inkAccent` theme-aware inks (≥4.5 text, ≥3 icons) replace raw `green`/`red`/`amberDark`/`brand500` at ~30 foreground call sites; dark `colorScheme.error` now uses the lighter danger ink (with dark `onError`); disabled-pair measured 4.49 — recorded as a WCAG-exempt deviation in the suite. **Captures:** 74 on-simulator PNGs under `docs/runs/v1.5/screenshots/{light,dark}/` — iPhone 17 Pro homeowner/shared @402×874, iPhone 17 Pro Max tradie @440×956 (nearest available to 393×852/430×932 targets — deviation recorded), driven by the existing `screenshots_test.dart` + new `scripts/run-shots.sh` marker watcher, real fixture jobs 130–136 incl. a live pending offer each tradie pass; `capture-manifest.csv` updated — 35 rows captured, 3 partial, H09 remains blocked-D3. Sampled inspection found no clipped labels/actions, low-contrast status/decline, overlapping OTP/nav/chips, or hidden sticky-bar content. 452 Flutter tests pass; analyzer holds 9 baseline infos. See the V15-20 handoff.

### [ ] V15-21 — Run regression harnesses and record release evidence

**Priority:** P0 · **Depends:** V15-20; all tasks intended for release

- Run Flutter analyze, unit/widget tests and actual relevant existing integration suites; backend build/tests inside API container if changed. Follow verification plan for smoke/credential/render-probe harness applicability; React render-probe is not mobile verification.
- Exercise full cross-persona booking/payment/check-in/out/confirmation/review plus cancellation/dispute branches and SignalR reconnect, including blocked/stale actions.
- Record commands, results, baseline versus new failures, capture manifest, approvals, known issues and any explicitly approved deferrals. Keep blocked work visible rather than marking it complete.

**Acceptance:** AC-01–AC-10 satisfied for shipped scope; no open release-critical trust/safety/accessibility defect; no claims that docs-only checks verify runtime behavior. **Verify:** Engineering/product/design sign-off on actual evidence. **AC:** 01–10.

> **Harness verification executed 2026-10-29:** stays unchecked — full on-simulator integration suites (`integration_test/auth_test.dart`, `screenshots_test.dart`), real multi-device cross-persona booking walkthrough, and final sign-off remain open. All automated regression harnesses executed against the running dev stack and passed cleanly:
> - `flutter analyze --no-fatal-infos`: 9 baseline infos, 0 errors, 0 warnings.
> - Full Flutter test suite (`flutter test`): **452 tests passed**, 0 failures across all unit, widget, and accessibility audit suites.
> - Backend container build (`docker compose run --rm --entrypoint /bin/bash api -c "dotnet build --no-restore -clp:NoSummary"`): 0 errors, 0 warnings.
> - Address resolution regression harness (`AddressResolutionTests.csproj`): 17/17 assertions passed.
> - Earnings backend regression harness (`EarningsTests.csproj`): 19/19 assertions passed.
> - Mobile address resolution unit/widget suite (`test/address_resolution_test.dart`): 19/19 tests passed.
> - P3 smoke suite (`scripts/p3-smoke.sh`): **ALL P3 CHECKS PASSED** — sequential dispatch, tradie accept, double-respond 409 guard, decline, broadened search stage, Hangfire 1-min timeout, and terminal cancel with `no_tradie_found` code.
> - P4 smoke suite (`scripts/p4-smoke.sh`): **ALL SCENARIOS GREEN** — payment instructions, receipt upload, admin verification to Booked, admin rejection with reason, re-upload, cross-job duplicate receipt rejection, same-receipt resubmit rejection, Hangfire payment expiry, and idempotent expiry.
> - E2E credential review harness (`python3 scripts/e2e-credentials.py`): **23/23 checks passed** — admin login, pending credential queue, private-bucket SAS links, approval, rejection with reason, rejection without reason 400 validation error, 404 missing credential, and database persistence matching the MVP verification rule.
> - Fixture isolation fix: updated `scripts/p3-smoke.sh` and `scripts/p4-smoke.sh` to preserve and set `IsAvailable=true` alongside `IsVerified`, and isolate competing pre-seeded plumbers during sequential matching.

## Coverage index

| Specification groups | Tasks |
|---|---|
| S01–S06 | V15-07; shared V15-04–V15-08 |
| H07/H08 | V15-09 |
| H09 | V15-10 |
| H10/H11 | V15-11 |
| H12 | V15-12 |
| H13 | V15-16 |
| H14/H15/H16 | V15-18 |
| H17 | V15-17 |
| H18 Messages / Profile / Settings | V15-16, V15-17 |
| T19/T20 | V15-13; offer safety V15-14 |
| T21 | V15-14 |
| T22 | V15-15 |
| T23 | V15-16 |
| T24 | V15-17 |
| T25 | V15-19 |
| T26 | V15-17 |
| All groups / audit traceability / verification | V15-01–V15-06, V15-08, V15-20, V15-21 |
