# Phase 5 Sub-Plan — Tradie Screen Migration (Design System v2)

> **Repo / branch:** `johnverz22/tradiehunter` @ `dev` (HEAD `d3225d7` when this was written)
> **Parent plan:** `docs/design_system_migration_plan.md` → **Phase 5 — Tradie Flows** (tasks 5.1–5.5)
> **Suggested location:** `docs/design_system_phase5_tradie_subplan.md`
> **Prepared:** 2026-11-18 · **Revised:** 2026-11-18 after owner answers on D-P5-1…5 (see §3.1) · **Status:** plan only; this file is the only change
> **Audience:** the implementing model. Every work package says *what to create, what to copy from, what to wire to, which Keys to keep, what to test, and when it is done*, so no further discovery is needed.

---

## 0. How this was produced, and its limits

- Cloned `dev`, read the whole parent plan, the four v1 tradie screens (outlines + the logic blocks quoted below), `lib/router/app_router.dart`, `lib/ui/ui_flags.dart`, `lib/ui/design/th_widgets.dart` (widget inventory), the 7 `tr_*` gallery stubs, the finished Phase 4 ports (`ho_home_*` as the reference layout), the tradie tests and the repo's agent rules.
- **Static reading only.** No Flutter SDK or backend was available, so nothing was run. Anything marked **(verify)** must be confirmed by the first `flutter analyze` / `flutter test`.
- The Flutter plugin skills in this workspace (`async-safety`, `widget-composition`, `widget-golden-and-a11y-testing`) were used as a rule source in §2.3. Where they disagree with this repo's existing conventions (this repo uses `StateNotifier` Riverpod and `Key('snake_case')`, not Riverpod 3 `Notifier`), **the repo wins** — follow what Phase 3/4 code already does.
- **Credential note:** a GitHub PAT was pasted in the request. It is **not** written into this document or into memory. It is only needed to push; nothing here requires it. Consider rotating it, since it was shared in plain text.

---

## 1. Starting state (facts)

### 1.1 What is already in place (Phases 2–4, do not redo)

| Piece | Location | Use in Phase 5 |
|---|---|---|
| v2 tokens + widget library | `lib/ui/design/th_tokens.dart`, `th_widgets.dart` | build everything from `TH*`; extend only additively |
| `ThScope`, `ThShell` (tradie dock, 4 tabs, **no** centre action — already done in 3.1) | `lib/ui/design/th_scope.dart`, `lib/ui/shared/th_shell.dart` | tr_* screens inside the shell get the dock for free |
| Notice + state views | `lib/ui/feedback/th_notice.dart`, `th_state_view.dart` | all toasts/loading/empty/error |
| Per-screen flag | `lib/ui/ui_flags.dart` (`v2Screens`, `isV2Screen`, `nonGalleryV2Screens`) and `_pick(id, v1, v2)` in `app_router.dart` | one id per screen |
| Boundary guard | `scripts/check_ui_boundary.py` | `lib/ui/**` must not import `views/**`, `widgets/fixo_*`, `widgets/th_components.dart`, `theme/design_tokens.dart`, `theme/fixo_theme.dart` |
| Choice pills, key-value, timeline, progress, bars, sticky bar | `THPills`, `ThChoicePills` (`lib/ui/shared/th_choice_pills.dart`), `THKeyValue`, `THTimeline`, `THProgress`, `THBars`, `THStickyBar` | see per-screen mapping |
| Phase 4 test pattern | `test/ui/phase3_test_setup.dart` (`loadPhase3Fixtures()`), `test/ui/phase4_ho_home_test.dart` (361 lines) | copy the harness |
| Homeowner job-detail routing & status table | `lib/ui/homeowner/ho_job_status.dart` | **homeowner-only** copy; Phase 5 needs a tradie equivalent (see §4.0.2) |

### 1.2 The v1 tradie surface that has to be recreated

| v1 file | Lines | Route | v2 id(s) | Notes |
|---|---:|---|---|---|
| `views/tradie/tradie_dashboard_view.dart` | 2,016 | `/tradie` (inside `ShellRoute`) | `tr_home` (+ part of `tr_earnings`) | owns SignalR, pending offers, availability toggle, lead cards, today/overdue/upcoming sections |
| `views/tradie/request_detail_screen.dart` | 1,286 | `/tradie/requests/:requestId` | `tr_lead` | offer countdown, photo viewer, accept/decline, quote form sheet |
| `views/tradie/tradie_job_detail_screen.dart` | 1,796 | `/tradie/jobs/:jobId` | `tr_job`, `tr_extra_cost`, `tr_complete` | check-in/out, adjustments, cancel/dispute/no-show, rate homeowner |
| `views/tradie/tradie_onboarding_wizard.dart` | 1,677 | `/tradie/onboarding` | `tr_onboarding` | 4-step wizard; viewmodel (708 lines) stays untouched |
| `views/jobs/jobs_list_screen.dart` (tradie branch) | 474 | `/jobs` (tab) | **no v2 design** → `tr_jobs` (new id) | reached today through `ThJobsRoute(tradieFallback: JobsListScreen())` |
| `views/widgets/tradie_job_card.dart`, `offer_countdown.dart`, `sliding_availability_switch.dart` | 296 / 264 / 309 | — | rebuilt as `lib/ui/tradie/` widgets | v1 widgets cannot be imported from `lib/ui` |

Routes are **not** to change. Only one addition is proposed (D-P5-1, earnings).

### 1.3 Data layer — keep untouched (verified UI-independent)

`jobsViewModelProvider` (`loadTradieJobs`), `profileViewModelProvider` (`updateAvailability`, `profile['isAvailable'|'isVerified'|'isGstRegistered']`), `tradieEarningsProvider` / `TradieEarningsNotifier.load()` (`TradieEarningsState{isLoading,error,summary}`), `jobsRepositoryProvider` (`getPendingOffer`, `createQuote`, `checkIn`, `checkOut`, `withdrawAdjustment`, `reportNoShow`, `cancelJobWithReason`, `getJobContact`, adjustment calls), `offerResponderProvider` (`OfferResponder.respond` → `success | rejected | alreadyInFlight`), `jobHubClientProvider` (SignalR streams `onJobStatusChanged`, `onAdjustmentChanged`, reconnect), `reviewsRepositoryProvider`, `tradieOnboardingProvider` (`TradieOnboardingNotifier`), `localeConfigProvider` (commission %).

### 1.4 Models you will map from (field names verified in `lib/models/marketplace.dart`)

- `Job`: `id, title, category, suburb, status, stage, urgency, description, photoUrls, createdAtUtc, address, latitude, longitude, matchedTradieId/Name, homeownerId, serviceId, scheduledStartUtc/EndUtc, hours, hourlyRate, totalAmount, referenceCode, disputeStatus, timingPreference, estimatedHours/Total, finalHours, labourAmount, adjustmentsTotal, finalAmount, completionSubmittedAtUtc, jobType, agreedPricingModel, flowVersion, isAboveEstimateTolerance, budgetMin/Max, materialsBy, siteVisitWelcome, scopeNotes`
- `JobOffer`: `id, jobId, tradieId, offeredAtUtc, expiresAtUtc, response, stage, kind, hourlyRateSnapshot, message, tradieName, jobTitle`
- `CheckOutSummary`: `jobId, finalHours, hourlyRate, labourAmount, adjustmentsTotal, finalAmount, estimatedTotal, exceedsTolerance, toleranceNote, completionSubmittedAtUtc`
- `JobAdjustment`: `id, jobId, proposedByTradieId/Name, kind, description, amount, evidenceUrl, status, createdAtUtc, respondedAtUtc, responseNote, expiresAtUtc`
- `JobContact`: `userId, firstName, phoneNumber`
- `TradieEarnings`: `periodStartUtc, periodEndUtc, asOfUtc, timeZone, earnedNet, processedNet, pendingNet, failedNet` (all `Decimal?`; `pendingNet` is all-time and **must not be added to weekly figures**)

---

## 2. Ground rules for every package

### 2.1 Per-screen recipe (parent plan §4.0), restated as a checklist

For each screen, in this order:

1. **Write the parity checklist first** (list every button, sheet, navigation, notice, loading/empty/error state, SignalR subscription, timer and Key in the v1 file). Put it at the top of the PR description. The per-package tables below are the starting list; extend them if the code shows more.
2. Copy the stub `lib/ui/gallery/<id>_screen.dart` → `lib/ui/tradie/<file>.dart`; remove the `GENERATED` header; rename the class `Tr…Screen` → real name; it is now hand-owned.
3. Make it a `ConsumerWidget` / `ConsumerStatefulWidget`. All sample copy comes from existing providers through a **pure mapper** (`tr_<x>_mapper.dart`, no Flutter widgets, unit-tested). Money goes through `utils/money.dart`; never `double`.
4. Port each action to the *same* repository/viewmodel call the v1 screen used.
5. Use `ThStateView` (loading / empty / error) and `THNotice` (toasts, banners).
6. Keep every v1 `Key` the tests or integration tests rely on (§2.2).
7. Widget test (light + dark, 200% text) + mapper unit tests.
8. Wire in `app_router.dart` via `_pick('<id>', v1, v2)`. **Do not add the id to `v2Screens`** until visual QA passes (same policy as Phase 4).

### 2.2 Keys that must survive

| Key | Where it lives today | Relied on by |
|---|---|---|
| `tradie_dashboard` | dashboard `Scaffold` | `tradie_dashboard_test`, flow tests |
| `availability_button` | online/offline switch | `tradie_dashboard_redesign_test`, `sliding_availability_switch_test` |
| `stat_tile_pending`, `stat_tile_rating` | hero stats | `tradie_dashboard_redesign_test` |
| `today_card_cta` | today job card | `tradie_dashboard_redesign_test`, `tradie_job_card_test` |
| `tradie_filter_row` | tradie Jobs tab filter | `tradie_dashboard_test` |
| `request_<requestId>` (ValueKey on route) | `/tradie/requests/:id` | router |
| `photo_thumb_$i` | request photo strip | `offer_response_test` (`photo_thumb_0`) |
| `quote_amount_field`, `quote_cap_field`, `quote_duration_field`, `quote_exclusions_field`, `quote_gst_switch`, `quote_inclusions_field`, `quote_materials_switch`, `quote_max_field`, `quote_min_field`, `quote_pricing_<option>`, `quote_rate_field`, `quote_start_field`, `quote_submit_button`, `submit_quote_button` | quote sheet | integration + widget tests |
| `tradie_job_<jobId>` (ValueKey on route) | `/tradie/jobs/:jobId` | router |
| `check_in_button`, `check_out_button`, `check_out_submit_button`, `navigate_button`, `call_homeowner_button`, `message_homeowner_button`, `rate_homeowner_button`, `request_extra_cost_button`, `extra_cost_amount_field`, `extra_cost_description_field`, `extra_cost_submit_button`, `final_hours_field`, `adjustment_withdraw_<id>`, `status_strip_job_code` | job detail + sheets | `tradie_job_detail_test`, flow tests |
| `upload_document_button`, `day:<weekday>` | onboarding | `tradie_onboarding_wizard_test` |

> **Test-id contract (added upstream in `541629b`, after this plan was drafted):** `test/ui/test_id_contract_test.dart` requires that every id the e2e suite locates by `Key` also exists as a `Key('…')` under `lib/ui` and is exposed as `Semantics(identifier:)`. The shared `TH*` primitives mirror a `ValueKey<String>` into the identifier automatically (`lib/ui/design/th_test_id.dart`); for anything else use `THTestId` / `.testId()`. So for every Key in the table above: (1) put it as a **`ValueKey<String>`/`Key('…')` on a `TH*` widget** where possible, (2) wrap raw widgets with `.testId()`, (3) when a tradie id is used by `integration_test/**`, add it to `contractIds` in that test. Re-read that test file before starting 5.1 and follow its current rules.

> `status_strip_job_code` is the v1 `StatusStrip` job-code chip. v2 has no status strip; render the job reference as a `THBadge` / `THKeyValue` row and put the same Key on it, or update the test with a one-line note in the PR (decide once, apply everywhere).

### 2.3 Engineering rules (from the skills, aligned with Phase 3/4 code)

- **Async safety** (`async-safety`): handlers are `void` (`onPressed: () { _respond(accept: true); }` or an `unawaited(...)` that ends in a catch); a `mounted` guard after **every** `await` before using `context`; capture `ScaffoldMessenger`/`Navigator` before a gap; every `StreamSubscription` (`onJobStatusChanged`, `onAdjustmentChanged`, reconnect), `Timer` and `AnimationController` is cancelled/disposed; no empty `catch`; use `rethrow`, not `throw e`.
- **Widget composition** (`widget-composition`): no `Widget _buildX()` helpers — extract classes; `build()` ≤ ~80 lines, nesting ≤ 5; lists are lazy (`ListView.builder`/slivers) for anything unbounded; callbacks capture ids, not content; every gesture has a labelled focusable alternative; **no `Color(0x…)`, raw sizes or fonts** — `context.th.<n>`, `Space.*`, `Radii.*`, `Sizes.*`, `THType`.
- **Tests** (`widget-golden-and-a11y-testing`): pin device size × DPR; `pump()` not `pumpAndSettle()` for timers/countdowns; never suppress overflow; one `testWidgets` per (size, text-scale) tuple; never clamp `TextScaler`; contrast asserted on token values, not pixels.
- **Boundary:** nothing in `lib/ui/**` imports `views/**`. Anything that is currently a *public symbol in a view file* and is needed here must be **moved or re-implemented** (see §4.0.2).
- **No fabricated data.** If the DTO lacks a value the mockup shows, omit the element and record it in the gap register (§3). Do not invent timers, check-in times, response rates or chart values.

### 2.4 Standard verification (every PR)

```bash
cd mobile
dart format lib test
flutter analyze --no-pub --fatal-infos
python3 ../scripts/check_ui_boundary.py           # path may be repo-root scripts/
node ../docs/design/tools/build.mjs --check
flutter test test/ui/                              # all v2 suites
flutter test --dart-define=UI_V2=<this id>         # existing v1 tests that touch the route
flutter test --dart-define=UI_V2=all               # full suite once per package
```

---

## 3. Decisions and gap register (extends parent §4.1 / §5)

### 3.1 Decisions — all resolved by the owner on 2026-11-18

| # | Decision | Resolution |
|---|---|---|
| **D-P5-1** | `tr_earnings` has no route (stub says `/tradie (earnings)`, dock tab *Profile*). | **Approved.** Add one additive route `GoRoute(path: '/tradie/earnings')` declared **before** `/tradie/:id`, with `_pick('tr_earnings', …)`; v1 fallback = redirect to `/tradie` (v1 shows earnings in the hero). Update the path snapshot in `test/ui/route_contract_test.dart` in the same PR. Entry points: hero net figure on `tr_home` and a row on the profile screen. |
| **D-P5-2** | `tr_extra_cost` and `tr_complete` are full pages in the mockup but sheets in v1. | **Approved.** Router unchanged. Each is a standalone full-screen page launched by `Navigator.of(context, rootNavigator: true).push<T>(MaterialPageRoute(fullscreenDialog: true, …))` that pops with the payload, so URLs, deep links and Keys are unchanged and the v1 sheet stays for flag-off. |
| **D-P5-3** | Tradie **Jobs tab** (`/jobs` for role 1) has no v2 design but Phase 6 deletes `views/`. | **Approved.** Package **5.8** (`tr_jobs`, composed from `TH*`, `needs-design`). Not a blocker for 5.1–5.7; **is** a blocker for Phase 6. |
| **D-P5-4** | Onboarding mockup draws only the *Credentials* step; v1 has four steps. | **Design generated on demand.** Phase 5 builds all four steps now with the stub chrome (`THAppBar` + `THProgress` + `THStickyBar`) and interim `TH*` compositions for the three undrawn steps, flagged `needs-design`. When the owner asks, the designs for those steps are generated (AST → `build.mjs` → mockups) and the interim compositions are restyled to match. Not blocking. |
| **D-P5-5** | ≥ 1024 px navigation rail / job master-detail, and the homeowner public profile `/users/:id`. | **Design generated on demand, including backend integration.** Now in scope as on-demand packages **5.10** and **5.11** (below). They start only when the owner asks; the design is generated first, then the API gap check (parent §4.1 policy: derive client-side → omit → additive optional field with a backend test and a `docs/SPECS.md` note). |

### 3.2 New gaps found while reading (add to parent §4.1 table as G-13 …)

| # | Screen | Need | Finding | Resolution |
|---|---|---|---|---|
| **G-13** | `tr_home` stats | "Jobs this week", **"Response rate 96%"**, rating | No response-rate field exists anywhere in the DTOs read. Rating is in `profile` data (verify key name in `profile_viewmodel.dart` — v1 `stat_tile_rating` reads it). Weekly job count must be derived client-side from `GET /api/jobs`. | Show **two** tiles (Jobs this week, Rating) + keep v1 `stat_tile_pending`; **omit response rate**. Never show a placeholder `—%`. |
| **G-14** | `tr_home` hero | "Net this week" | `TradieEarnings.earnedNet` is the server's weekly net. v1 distinguishes *loaded zero* / *null (no figure)* / *error* — keep all three (`TradieEarningsState`). | Map 1:1 from `tradieEarningsProvider`; money via `utils/money.dart`; on error show the retry affordance v1 has (`onEarningsRetry`). |
| **G-15** | `tr_earnings` | 7-day bars | Same as **G-1**: only period totals exist. | Ship totals only; hide `THBars`. Four rows from the DTO: earned, processed, pending (label "all-time outstanding"), failed (hide when null/0). "Recent payouts" list: **no endpoint** → derive from jobs with status `Completed`/`AwaitingPayment`/`PaymentReview` using `finalAmount` from `GET /api/jobs` only if the amount is present; otherwise omit the section. |
| **G-16** | `tr_lead` | "Received 2 min ago · Job #TH-4821" | `JobOffer.offeredAtUtc` and `Job.referenceCode` exist. | Derive relative time client-side; omit the code if `referenceCode` is null. |
| **G-17** | `tr_lead` | Homeowner card "4.8 · 12 jobs posted" | No homeowner stats in `Job`/`JobOffer`. v1 shows none (verify). | Omit rating/jobs-posted; show avatar + first name only if the job payload provides it, else hide the card. |
| **G-18** | `tr_lead` | "Exact address — shared after you accept"; "Access" row | Server hides the address pre-booking (v1: `showFullAddress` only from Booked). "Access" is not a field. | Keep the "shared after you accept" row (truthful); **omit "Access"**. Distance: only if returned (verify); else omit. |
| **G-19** | `tr_job` | "Accepted — Yesterday 4:12 pm" timeline subtitles | No `acceptedAt` field. | Timeline shows state only (done/cur/todo), subtitles only for `scheduledStartUtc` and `completionSubmittedAtUtc`. |
| **G-20** | `tr_complete` | "On site 9:02 am to 11:34 am · 2 h 32 min reference" | `Job` has **no check-in/out timestamps** (grep for `checkIn` in the model found none). Phase 4's `ho_extra_cost` already omitted the same data. | **Omit the on-site card.** Keep the +/- hours stepper (`final_hours_field`) seeded exactly like v1. |
| **G-21** | `tr_complete` | "Commission (sample 10%, labour only)" | Commission % comes from `localeConfigProvider` (`commissionPercent`), exactly as v1 line ~547. | Use the real value; if config is unavailable, **hide the commission and "You receive" rows** (same as v1's null handling). Never print "sample". |
| **G-22** | `tr_extra_cost` | type pills Materials / Extra work / Travel, receipt attach | Must match the adjustment `kind` values v1 sends. | Read the v1 `_RequestExtraCostSheet` payload and reuse its exact `kind` strings, 24-h expiry copy and evidence upload call. |
| **G-24** | wide layout (5.10) | master-detail data | Expected to need no API change. | Confirm during 5.10; follow §4.1 policy if not. |
| **G-25** | `/users/:id` (5.11) and `tr_lead` homeowner card | homeowner stats (rating, jobs posted) | Not in the DTOs read (see G-17). | Decide with the owner during 5.11; optional additive field with backend test if approved. |
| **G-23** | `tr_job` | multi-state | The stub draws only *Booked*. v1 also handles InProgress, AwaitingConfirmation, Completed, Cancelled, Disputed. | Build a state selector (same pattern as `ThJobDetailRouter` / `ho_job_detail_state.dart`), one small widget per state. No state may fall through to a blank screen. |

---

## 4. Work packages

**Dependency order:** 5.0 → 5.1 → (5.2, 5.3 in parallel) → 5.4 → 5.5 → (5.6, 5.7, 5.8 in parallel) → 5.9. One PR per package; 5.3 may split into PR A–C (see there). **5.10 and 5.11 are on-demand** (only after the owner requests the design; see after 5.8).

Target file layout (mirror `lib/ui/homeowner/`):

```
lib/ui/tradie/
  tr_common.dart                 # shared tradie widgets (countdown chip, photo strip/viewer wrapper, availability row)
  tr_job_status.dart             # tradie status table (label, tone, stage, tradieAction, actionRequired)
  tr_home_screen.dart  tr_home_mapper.dart  tr_home_parts.dart
  tr_lead_screen.dart  tr_lead_mapper.dart  tr_quote_sheet.dart  tr_photo_viewer.dart
  tr_job_router.dart   tr_job_state.dart    tr_job_providers.dart
  tr_job_booked_screen.dart  tr_job_inprogress_screen.dart  tr_job_review_states.dart  tr_job_parts.dart
  tr_extra_cost_page.dart    tr_complete_page.dart
  tr_earnings_screen.dart    tr_earnings_mapper.dart
  tr_jobs_screen.dart        tr_jobs_mapper.dart
  tr_onboarding_screen.dart  tr_onboarding_steps.dart  tr_onboarding_mapper.dart
test/ui/phase5_tr_*_test.dart
```

---

### 5.0 Preparation (one small PR, no visible change)

**Goal:** remove every reason a tradie port would have to import `views/**`.

1. **Extract shared logic out of view files into `lib/ui/tradie/` (or `lib/utils/` when it is not UI):**
   - `isScheduledOnOrBeforeToday(...)` is a public symbol of `views/tradie/tradie_dashboard_view.dart`, imported by `views/jobs/jobs_list_screen.dart`. Re-implement in `tr_home_mapper.dart` (pure, with the existing tests ported); leave the v1 copy until Phase 6.
   - `tradieDayGroups(...)`, `TradieDayGroup` and the `_tradieWorkStatuses` / `_tradieAwaitingPaymentStatuses` sets (`jobs_list_screen.dart`) → `tr_jobs_mapper.dart`.
   - The dashboard's private sets `_bookedWorkStatuses`, `_awaitingPaymentStatuses`, `_isOverdue`, `_isScheduledToday` → `tr_home_mapper.dart` (copy values exactly; add a test that pins them against the v1 table).
2. **`tr_job_status.dart`**: tradie view of `JobStatusPresentation` (`tradieAction`, `tradieActionRequired`, `tradieDashboardAction`, label, badge tone). Copy the table values from `views/widgets/job_status_presentation.dart`; add a **parity test** that iterates the v1 table (test code may import v1) and asserts identical labels/flags.
3. **Reusable tradie widgets in `tr_common.dart`:**
   - `TrOfferCountdown` — rebuild `OfferCountdown` on `THDurations.countdownTick` (as `ho_request_sent_screen.dart` does). Keep: `clampedRemaining`, `formatClock` (`mm:ss`), `compactLabel`, injected `clock`, `onExpired` fired **once** post-frame. Expired state shows the v1 expired treatment. Timer cancelled in `dispose`; `mounted` guard in the callback.
   - `TrAvailabilityRow` — `THSwitch` with `Key('availability_button')`, loading/disabled state, semantics "Online/Offline". (v2 `THSwitch` has `on` only — check whether `onChanged` exists; if not, add it **additively** with a pixel-neutral default and re-run gallery goldens.)
   - `TrPhotoStrip` / viewer helper reusing `THPhotoStrip`, with `photo_thumb_$i` Keys, and the full-screen swipe viewer from `_PhotoGalleryViewer` (page indicator, close button, URL resolution identical to `_resolvePhotoUrl`).
4. Add `ui_flags.dart` ids now (not enabled): none — the allowlist stays empty for Phase 5 ids. Add the **non-gallery** ids to `nonGalleryV2Screens`: `tr_jobs`. (`tr_*` gallery ids already exist in `thScreenBuilders`; `ui_flags_test` checks the union.)

**Done when:** analyze + boundary guard green; mapper/status parity tests green; app behaviour unchanged.

---

### 5.1 `tr_home` — Tradie dashboard (flag `tr_home`, route `/tradie`)

**Source:** stub `lib/ui/gallery/tr_home_screen.dart` (229 lines). **Old:** `views/tradie/tradie_dashboard_view.dart`.
**Split into:** `tr_home_screen.dart` (≤ 250 lines, scaffold + providers), `tr_home_parts.dart` (hero, stats, leads section, lead card, today/overdue/upcoming sections, empty/verification banner), `tr_home_mapper.dart` (pure).

**Wiring (all existing):**

| Data | Source |
|---|---|
| jobs | `ref.watch(jobsViewModelProvider)` → `jobs`, `isLoading`, `error`; refresh `loadTradieJobs()` |
| profile | `ref.watch(profileViewModelProvider)` → `isAvailable` (default **true** when null), `isVerified`, first name, rating |
| earnings | `ref.watch(tradieEarningsProvider)`; `notifier.load()` on refresh and on SignalR payment events |
| pending offers | `jobsRepositoryProvider.getPendingOffer(jobId)` for each `Requested` job → `Map<String, JobOffer>` + `_offersLoaded` |
| accept/decline | `ref.read(offerResponderProvider).respond(jobId:, offer:, accept:)` |
| availability | `profileViewModelProvider.notifier.updateAvailability(!online)` |
| realtime | `jobHubClientProvider` — same subscriptions as v1 `_initSignalR` (job status → `_refreshJobsAndOffers()`; payment/earnings events → `earnings.load()`; reconnect → reload). Subscribe in `initState`, cancel in `dispose` |

**Mapper contracts (unit-test each):**
- `TrHomeGroups.from(List<Job>, DateTime now)` → `leads` (`status == 'Requested'`), `overdue`, `today`, `upcoming`, `awaitingPayment`, `disputed`. Sorting identical to v1: overdue by `scheduledStartUtc` asc (nulls last); today = action-required first, then by time.
- `weekJobCount(...)`, `heroNetLabel(TradieEarningsState)` → `{loaded|unavailable|error|loading}` + formatted amount.
- `showVerificationBanner = !profile.isLoading && isVerified != true`.
- `leadSubtitle(job)` (`category · distance? · timing`), only real fields.

**Parity checklist (port every item):**
- [ ] Hero: greeting (first name; omit if unknown), online/offline `THSwitch`, "Net this week" with the three earnings states, rating badge only with a real score + count
- [ ] Paused banner when `!isAvailable`: copy "You're currently paused. Toggle back on to receive new job offers." (as `THNotice` banner or `THCard(tone: accent)`)
- [ ] **Go-offline confirm sheet** shown only when going offline **and** any job is `Requested` or in booked-work statuses; `showModalBottomSheet(useRootNavigator: true)`; copy copied from `_GoOfflineSheet`
- [ ] Availability optimistic toggle with in-flight guard; on error `THNotice.error(NoticeCopy.statusUpdateFailed, onRetry: retry)` (the error is swallowed into `profileState.error` — compare before/after exactly like v1)
- [ ] Verification banner "Not verified yet … Review my setup" → `context.push('/tradie/onboarding')`
- [ ] Leads section: skeleton on first load, error row with retry, empty state, **animated lead card entry**, lead card = title, `category · distance · timing`, rate snapshot (`JobOffer.hourlyRateSnapshot`, GST label as v1), photo count, `TrOfferCountdown` badge, **View full request** → `/tradie/requests/:id`, Accept / Decline through `OfferResponder` with `_responding` set (one tap = one POST), `rejected` → `THNotice.error` ("Could not accept this offer — it may have expired." / "Could not decline this offer.") + refetch; `alreadyInFlight` → no-op; countdown expiry → refetch
- [ ] Today section: label with count, cards via `TrJobCard` (keep `Key('today_card_cta')`), empty state
- [ ] Overdue section (label, count, cards); upcoming / "collapsed" section; awaiting-payment; disputed ("Needs attention" in the stub)
- [ ] Pull-to-refresh (`_refreshAll`: jobs + earnings); app-lifecycle resume refresh (`didChangeAppLifecycleState`)
- [ ] Keys: `tradie_dashboard`, `availability_button`, `stat_tile_pending`, `stat_tile_rating`, `today_card_cta`
- [ ] Semantics labels for switch, lead actions, countdown

**Tests (`test/ui/phase5_tr_home_test.dart`):** mapper groups/sorting; each earnings state; leads loading/error/empty; accept/decline outcomes (3 enum values) with a fake `OfferResponder`; offline-confirm only when active work; availability failure notice; verification banner; light + dark; 200% text; countdown with injected clock using `pump(duration)`.
**Existing tests to run with `UI_V2=tr_home`:** `tradie_dashboard_test`, `tradie_dashboard_redesign_test`, `tradie_job_card_test`, `sliding_availability_switch_test`, `offer_response_test`, `dashboard_redesign_test`. Where they assert v1 text/structure, either keep the v1 assertion (flag off) or add a v2 twin — do **not** delete v1 tests in this phase.

**Done when:** all items ticked, tests green with the flag on and off, `/tradie` still resolves for deep links and post-job guard redirects (`ho_post_job_screen.dart:32` does `context.go('/tradie')`).

---

### 5.2 `tr_lead` — Request detail (flag `tr_lead`, route `/tradie/requests/:requestId`)

**Source:** stub `tr_lead_screen.dart` (275). **Old:** `request_detail_screen.dart` (1,286). **Split:** `tr_lead_screen.dart`, `tr_lead_mapper.dart`, `tr_quote_sheet.dart` (the form), `tr_photo_viewer.dart`, `tr_lead_states.dart` (offer-gone, check-error, not-found).

**State & wiring (port `_load/_reloadOffer/_reloadJobAndOffer/_listenToHub`):**
- Loads `Job` and pending offer from `jobsRepositoryProvider` (`getPendingOffer(requestId)`), SignalR listener for status/offer events, reload on app resume, hub subscription cancelled in `dispose`.
- Accept/decline → `offerResponderProvider.respond(...)` (shared in-flight protection with the dashboard — do **not** call the repository directly).
- Quote → `showModalBottomSheet<Map<String,dynamic>>` returning the payload → `jobsRepositoryProvider.createQuote(requestId, payload)`; `THNotice.success('Quote sent — the homeowner will compare it with the others.')`; `context.canPop() ? pop() : go('/tradie')`; `ProfileApiException` → `THNotice.errorDynamic(e.message)`; other → "Could not send your quote. Please try again."
- GST default: `profile['isGstRegistered']` (v1 `_profileGstRegistered()`).

**Layout (from stub):** `THAppBar` title/subtitle · `THHero` countdown card (`TrOfferCountdown`, "Online tradies get offers first…") · job card (category badge, timing badge, title, description) · photo strip → viewer · Location (`THKeyValue` rows; exact address "shared after you accept") · Timing and scope · price block (v1 `_PriceBlock`: total with hours × rate when available) · schedule card (v1 `_ScheduleCard`) · `THStickyBar` with **Decline** (secondary) and **Accept job** (accent) — or **Submit quote** when the job is a quote-type request (replicate v1's branch on `jobType` / `kind`; `submit_quote_button`).

**States (each its own widget, no blank screens):** loading · offer gone (`_OfferGone` copy) · offer check error + retry · request not found · expired (countdown 0 → disable actions, show gone state) · busy (disable buttons, `AbsorbPointer`).

**Quote sheet fields & Keys (copy exactly):** pricing-model chips (`quote_pricing_<option>`), `quote_amount_field`, `quote_rate_field`, `quote_min_field`, `quote_max_field`, `quote_cap_field`, `quote_duration_field`, `quote_start_field` (date/time picker, `_pickStart`), `quote_inclusions_field`, `quote_exclusions_field`, `quote_materials_switch`, `quote_gst_switch`, `quote_submit_button`. Port the v1 validation and payload keys **byte-for-byte**; add a test that builds the payload from the v1 and v2 sheets with the same inputs and compares maps (as Phase 4 did for post-job).

**Gaps applied:** G-16, G-17, G-18.

**Tests (`phase5_tr_lead_test.dart`):** mapper (relative time, price block, address-gating); accept/decline outcomes; quote payload equivalence; photo viewer swipe/close; each state; expired countdown disables actions; light/dark/200%.
**Run with `UI_V2=tr_lead`:** `offer_response_test`, `tradie_dashboard_test`, any `job_request_test` segment that opens a request.

---

### 5.3 `tr_job` — Tradie job detail (flag `tr_job`, route `/tradie/jobs/:jobId`)

**Source:** stub `tr_job_screen.dart` (135). **Old:** `tradie_job_detail_screen.dart` (1,796). **This is the risky one — do not port 1:1.** Build `TrJobRouter` (like `ThJobDetailRouter`) that loads once and picks a small state widget. Preserve `Key('tradie_job_${jobId}')` on the route widget.

**Shared loader (`tr_job_providers.dart`, auto-dispose family on `jobId`):** `Job` (`jobsRepositoryProvider`), `JobContact?` (only for contactable statuses: Booked, InProgress, AwaitingConfirmation, Completed, Disputed), `List<JobAdjustment>`, `hasReview` (from `reviewsRepositoryProvider`, v1 `_rateHomeowner` lines ~374–400), commission % from `localeConfigProvider`. SignalR: `onJobStatusChanged` and `onAdjustmentChanged` filtered by `jobId` → reload. Cancel in `dispose`/`ref.onDispose`.

**Selector (`tr_job_state.dart`, total function over `status`):**

| Status | Widget | Primary action (v1) | Key |
|---|---|---|---|
| `Booked` | `TrJobBookedScreen` (stub layout: progress 5 steps, "Ready to start?", homeowner card, details, timeline) | Check in | `check_in_button` |
| `InProgress` | `TrJobInProgressScreen` | Check out → `tr_complete` | `check_out_button` |
| `AwaitingConfirmation` | in-progress layout + "waiting for homeowner approval" notice, no primary action | — | — |
| `Completed` | review state | Rate homeowner (hidden if `hasReview`; needs `homeownerId`) | `rate_homeowner_button` |
| `Cancelled`, `Disputed` (or `disputeStatus` Open/UnderReview) | notice states | Open dispute where allowed | — |
| anything else / unknown | fallback "job detail" with status badge (never blank) | — | — |

**Actions to port (all existing repository calls):**
- `_navigate([MapApp])` + `_NavigateButton` map picker (`network/external_launcher.dart`, same as `ho_booked_screen.dart` already imports) — only when `canNavigate` (status ≥ Booked **and** coordinates); address masked before Booked (`_isBookedOrLater`)
- `_call(phone)`; chat → `/chat/:jobId`
- `_checkIn()` → `repo.checkIn(jobId)` → reload; `_checkOut()` → see 5.5
- Overflow menu: **Dispute** (`canDispute = status != Requested && != Cancelled`) → `/jobs/:id/dispute`; **Report no-show** (`Booked` and ≥ 15 min past `scheduledStartUtc`, exact rule in v1 line ~37) → `repo.reportNoShow` + `loadTradieJobs()`; **Cancel** (`Booked | InProgress | AwaitingConfirmation`, not while `_busy`) → sheet with the five tradie reason codes (`tradie_unavailable`, `emergency`, `scope_change_declined`, `tradie_issue`, `homeowner_no_show`) → `repo.cancelJobWithReason`. Reuse the Phase 4 `TH*` cancel sheet composition from `ho_booked_*` if it is parameterised; otherwise duplicate into `tr_job_parts.dart` (do not import `ho_*` private pieces).
- Request extra cost (`request_extra_cost_button`) → 5.4; adjustments card with withdraw (`adjustment_withdraw_<id>`, `repo.withdrawAdjustment`)
- Money block: gross/total, commission %, "You earn" **only when** net and commission are both known (v1 `net != null && commissionPercent != null`)
- Urgency badge, notices for AwaitingConfirmation / Completed / Cancelled / Disputed (copy from `_buildNotices`)

**PR slicing (recommended):** **A** loader + selector + fallback state (every selector result still injects the v1 screen — behaviour-neutral, exactly how Phase 4.2 PR A shipped); **B** Booked + actions (check-in, contact, navigate, cancel, no-show, dispute); **C** InProgress / Awaiting / Completed / Cancelled / Disputed + adjustments card.

**Gaps applied:** G-19, G-23. **Keys:** `check_in_button`, `check_out_button`, `navigate_button`, `call_homeowner_button`, `message_homeowner_button`, `rate_homeowner_button`, `request_extra_cost_button`, `adjustment_withdraw_<id>`, `status_strip_job_code` (see §2.2 note).
**Tests:** `phase5_tr_job_state_test.dart` (selector total over every status string incl. unknown), per-state widget tests, no-show timing rule with injected clock, cancel reason list equality, contactable-status gating, address masking. **Run with `UI_V2=tr_job`:** `tradie_job_detail_test`, `job_lifecycle_test` (device), `cancellation_test`, `dispute_test`.

---

### 5.4 `tr_extra_cost` — Request extra cost (flag `tr_extra_cost`)

**Source:** stub `tr_extra_cost_screen.dart` (82). **Old:** `_RequestExtraCostSheet` (lines ~1653–end) + `_showRequestExtraCostSheet`/`_withdrawAdjustment`. **File:** `tr_extra_cost_page.dart`.

- Launch per D-P5-2: `pushTrExtraCost(context, job, homeownerFirstName)` → returns the same payload/result the v1 sheet returns; caller (job detail) performs the existing repository call and reload, so the page is a pure form.
- Layout: `THAppBar` ("Request extra cost", subtitle with homeowner first name when known), type `ThChoicePills` (Materials / Extra work / Travel — verify v1 `kind` strings, G-22), amount `THTextField` (`extra_cost_amount_field`, GST wording as v1), description `THTextField` multi-line (`extra_cost_description_field`), receipt/photo attach tile (`THDashBox` pattern) using the same picker and evidence upload as v1, expiry/commission info `THCard`, `THStickyBar` **Send request** (`extra_cost_submit_button`).
- Validation, limits, and double-submit guard = v1. Decimal parsing via the same helper v1 uses.
- Tests: validation matrix (empty / zero / negative / too long), payload equals v1 payload for same inputs, light/dark, keyboard with sticky bar (`THScaffold.bottomClearance`).
- Job detail launches v2 page only if `isV2Screen('tr_extra_cost')`, else the v1 sheet.

### 5.5 `tr_complete` — Check-out / complete job (flag `tr_complete`)

**Source:** stub `tr_complete_screen.dart` (131). **Old:** `_checkOut()` (line ~207), `_CheckOutSheet`, `_showCheckOutSummary`. **File:** `tr_complete_page.dart`.

- Page returns the hours the tradie confirms; job detail then calls `repo.checkOut(jobId, finalHours: …)` exactly as v1 and shows the **summary** (`CheckOutSummary`: labour, adjustments, final amount, `exceedsTolerance` + `toleranceNote`, `completionSubmittedAtUtc`) in the v2 style (`THKeyValue` card, tolerance note as `THNotice`/`THCard(tone: accent)`).
- Hours stepper with `final_hours_field` (editable), ± `THIconButton`s with semantics labels `minus`/`plus` (stub), step/min/max and initial value **exactly as v1** (`_CheckOutSheet.initState`).
- Money rows: labour (hours × rate), approved extras (only `approved` adjustments — copy v1 filter), homeowner pays, commission %, **You receive** (G-21). Hide commission/net rows if config is missing.
- **Omit the on-site-times card (G-20).**
- Sticky **Send for approval** (`check_out_submit_button`), disabled while submitting; success → v1 navigation after summary.
- Tests: stepper bounds, totals math with `Decimal`, tolerance note shown iff `exceedsTolerance`, missing commission hides rows, payload equals v1.

### 5.6 `tr_earnings` — Earnings (flag `tr_earnings`, route per D-P5-1)

**Source:** stub `tr_earnings_screen.dart` (82). **Old:** earnings section of the dashboard hero + `TradieEarningsState`.
- `ConsumerStatefulWidget`: `earnings.load()` on init and pull-to-refresh; states from `TradieEarningsState` (loading → skeleton, error → `ThStateView.error` with retry, loaded). Distinguish **0.00 loaded** vs **null = "No figure yet"** (never show a fabricated zero).
- Hero: "Net this week" = `earnedNet` with period label from `periodStartUtc`–`periodEndUtc` in the **DTO's `timeZone`** (default `Pacific/Auckland`) and "as of" from `asOfUtc`. Cards: processed, pending (label "Outstanding (all time)" — never summed with weekly), failed (only if > 0, with a retry/contact hint copy from v1 if present).
- **No `THBars`** (G-15). Recent-payouts list only from jobs data if amounts exist; else omit the section entirely.
- Tests: all four amount states, timezone formatting around a week boundary, pending not added to weekly, route contract snapshot update.

### 5.7 `tr_onboarding` — Setup wizard (flag `tr_onboarding`, route `/tradie/onboarding`)

**Source:** stub `tr_onboarding_screen.dart` (97). **Old:** `tradie_onboarding_wizard.dart` (1,677) + untouched `tradie_onboarding_viewmodel.dart` (708) — **do not edit the viewmodel**.
**Split:** `tr_onboarding_screen.dart` (PageView, app bar, progress, footer, back handling), `tr_onboarding_steps.dart` → one class per step (`TrWorkStep`, `TrTradesStep`, `TrVerificationStep`, `TrPayoutStep`), `tr_onboarding_mapper.dart` (step titles, per-step validity labels, day/time formatting).

**Wiring:** `ref.watch(tradieOnboardingProvider)`; `load()` on entry; `_hydrate(state)` into controllers (create/dispose controllers in a small `_Controllers` holder like v1 `_WizardControllers`); `saveStepAndAdvance()` for Next; `goBack()`; `goToStep` on page change; `finishSetup()` for the last step; `uploadCredential(...)` + `refreshCredentials()`.

**Parity checklist:**
- [ ] App bar "Tradie setup" + "Step N of `TradieOnboardingState.stepCount` — <step title>"; back arrow except on step 1; step 1 shows a close button (`_CloseWizardButton` behaviour)
- [ ] `PopScope(canPop: state.isFirstStep)` → back goes to previous step
- [ ] **Work step:** first/last name, phone, address (+ coordinates card, lat/long), trade selector (`_TradeSelector` picker), service radius
- [ ] **Trades step:** services from `localeConfigProvider`; toggle service, per-service rate input (`setRateInput`), GST wording; the v1 rate validation/error messages
- [ ] **Schedule:** 7 day rows (`Key('day:<weekday>')`), enable switch (`setDayEnabled`), start/end time pickers (`setDayTimes`), "invalid range" handling — keep wherever v1 puts it (Trades or a separate step; **verify** which step v1 uses)
- [ ] **Verification step:** credential list with status badges (Verified / Under review / Pending) from `state` credentials, `upload_document_button`, `_askCredentialKind(fileName)` sheet, file picker + upload error from `step3Error` via `THNotice`
- [ ] **Payout step:** bank account name/number (`setBankAccountName/Number`), masking and validation as v1
- [ ] Per-step error text from the viewmodel (`step1Error…`), disabled Next while saving, `FixoNotice` → `THNotice`
- [ ] Finish → same navigation as v1 (verify target) and verification-pending messaging
- Stub line "No call-out fee is charged by TradieHunter…" → keep only if v1/SPECS contains the same statement; otherwise drop.

**Undrawn steps (D-P5-4):** ship interim compositions now; when the owner requests the design, extend `ast/screens.mjs` with the missing step frames, run `node docs/design/tools/build.mjs`, compare with the interim screens and restyle. No data or viewmodel change is involved.

**Tests:** extend from `tradie_onboarding_wizard_test.dart` patterns (446 lines): step navigation, validation per step, `day:2` toggle, credential upload outcomes with a fake repo, back/PopScope, controller disposal (no leaks), light/dark, 200% text with keyboard open (`viewInsets`).
**Run with `UI_V2=tr_onboarding`:** `tradie_onboarding_wizard_test`, `tradie_onboarding_test`, `auth_test` (role select → onboarding).

### 5.8 `tr_jobs` — Tradie Jobs tab (new non-gallery id, route `/jobs` for role 1) — *needs-design*

Compose from `TH*` (`THPills`/`ThChoicePills` filters, `THCard`/`THListRow`/`THBadge` cards, `ThStateView`). Reuse `TrJobCard` from 5.1.
- Port: filters **Today / Upcoming / Awaiting payment / Disputed / All** (confirm exact set from `_TradieJobFilter`; keep `Key('tradie_filter_row')`), local-day grouping via `tradieDayGroups` (moved in 5.0), pull-to-refresh, loading/error/empty per filter, **status-aware navigation** (`Requested` → `/tradie/requests/:id`, else `/tradie/jobs/:id`; v1 `jobs_list_screen.dart` lines ~128–141), wide-screen master-detail left as D-P5-5 (push navigation only).
- Wiring: replace `tradieFallback: const JobsListScreen()` in the `/jobs` route with `_pick('tr_jobs', const JobsListScreen(), const TrJobsScreen())` passed to `ThJobsRoute`.
- Tests: grouping/filters (move existing `tradie_dashboard_test` group tests to the mapper), navigation targets, empty states.

### 5.10 (on demand) Wide-screen navigation and job master-detail — *design + backend check on request*

**Trigger:** owner asks for the wide-screen design. **Not started by default.**
1. **Design first (gate):** add wide frames (rail at ≥ 1024 px; list + detail at ≥ 744 pt, matching the v1 breakpoint in `jobs_list_screen.dart`) to `ast/screens.mjs`; regenerate mockups; owner approves. No code before this.
2. **Backend/integration check (G-24):** no API change is expected — the layout reuses the same job list/detail data. Confirm in the PR; only if a new element needs data not returned, follow parent §4.1 (derive → omit → additive optional field + backend test + `docs/SPECS.md` note).
3. **Build:** `ThShell` rail (today's `_FixoNavRail` behaviour kept) restyled with tokens matching `THDock`; `TrJobsScreen` and `ThJobsRoute` embed the v2 detail widgets (`TrJobRouter`, `ThJobDetailRouter`) in the right pane using the same providers; narrow layouts unchanged. Flag id `wide_layout` (non-gallery, add to `nonGalleryV2Screens`).
4. **Tests:** width matrix (360, 744, 1024+), selection persistence on resize, deep link into a selected job, rail badges (`chatUnreadProvider`).

### 5.11 (on demand) Homeowner public profile `/users/:id` — *design + backend integration on request*

**Trigger:** owner asks for the design. **Not started by default.** Old: `views/profile/public_profile_screen.dart` (1,283 lines, shared with the tradie profile; Phase 4 already ported the homeowner-viewing-tradie case as `ho_tradie_profile`).
1. **Design first (gate):** generate the homeowner-profile frame (avatar, name, rating, reviews list, jobs-posted count only if the API provides it) as an AST screen; owner approves.
2. **Backend integration (G-25):** list exactly what the frame needs and check `GET /api/profile/:id` and `GET /api/users/:id/reviews`. Per parent §4.1: (1) derive client-side, (2) omit, (3) additive **optional** field only if the owner wants the element — with a backend test, the DTO change documented in `docs/SPECS.md`, and the mobile model tolerating `null` so older servers never break the app. Candidate: "jobs posted" and homeowner rating on `tr_lead` (G-17) — if an additive homeowner-stats field is approved, G-17 closes on `tr_lead` too.
3. **Build:** `lib/ui/shared/user_profile_screen.dart` + mapper; route unchanged (`/users/:id`); flag id `user_profile` (non-gallery). Reviews pagination, report/block actions and the rating sheet kept as in Phase 4's profile port.
4. **Tests:** mapper, reviews pagination, null-field tolerance, report/block calls, light/dark.

### 5.9 Cross-cutting wrap-up (parent tasks 5.3, 5.4)

- **5.3 dock check:** assert in a widget test that the tradie shell dock has no centre action (`onNewRequest == null`) — already built in Phase 3; this is only a regression test.
- **5.4 offer/countdown behaviour tests with v2 on:** run `offer_response_test` and the countdown tests with `--dart-define=UI_V2=tr_home,tr_lead` and again with `all`.
- **Notifications:** tradie notification-to-destination mapping (`routeNotification…`) must still land on `/tradie`, `/tradie/requests/:id`, `/tradie/jobs/:id`. Add cases to the existing destination test (no mapping change).
- **Screenshots/integration:** update `screenshots_*` only in Phase 6 (parent 6.6); do not touch here.

---

## 5. Test and QA matrix

| Layer | What | Where |
|---|---|---|
| Unit | mappers (groups, sorting, money, earnings states, status table parity) | `test/ui/phase5_*_mapper_test.dart` |
| Widget | each screen/state, light + dark, 200% text, narrow (360×640) and large phone | `test/ui/phase5_tr_*_test.dart` using `loadPhase3Fixtures()` |
| Contract | payload equivalence v1 vs v2 for quote, extra cost, check-out, cancel | same files |
| Route | path snapshot incl. `/tradie/earnings` if approved; extras unchanged | `test/ui/route_contract_test.dart` |
| Flow (headless) | existing tradie tests with `--dart-define=UI_V2=<id>` then `all` | `test/` |
| Device | `job_request_test`, `job_lifecycle_test`, `cancellation_test`, `dispute_test`, `payment_test` against the dev backend | **owner** (skipped in Phase 4; keep skipped unless asked) |
| Visual QA | compare with `docs/design/mockups/index.html`, light + dark | **owner**; tick the checklist below |

**Per-id activation checklist (copy into each PR):**
- [ ] parity checklist complete · [ ] Keys preserved · [ ] analyze `--fatal-infos` clean · [ ] boundary guard green · [ ] design gate green · [ ] widget + mapper tests green · [ ] v1 flow tests green with the id on · [ ] full suite green with `UI_V2=all` · [ ] light/dark + 200% text checked · [ ] gaps G-13…G-25 handled as listed · [ ] **id NOT yet in `v2Screens`** · [ ] owner visual QA → then add id to `v2Screens`

---

## 6. Parent-plan bookkeeping after each package

1. Tick the matching box in `docs/design_system_migration_plan.md` Phase 5 and add a dated progress note in the same style as Phase 4 (what was ported, parity kept, deviations, verification commands and results, "not added to `v2Screens`").
2. Append rows G-13…G-25 (§3.2) to parent §4.1; record D-P5-1…5 (resolved 2026-11-18, §3.1) in parent §5; add 5.8, 5.10 and 5.11 as sub-tasks under parent Phase 5; mark the D-4 backlog rows for the wide layout and `/users/:id` as "design on demand".
3. When 5.1–5.8 are done, set Phase 5 ✅ with the same wording as Phase 4 ("excluding visual and device QA").
4. Use the `docs-sync` skill after any behaviour/scope change.

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Duplicate accept/decline when dashboard and detail race | always go through `offerResponderProvider`; test `alreadyInFlight` |
| SignalR subscription leaks (dashboard, lead, job detail) | one subscription helper per screen, cancelled in `dispose`; test that disposing cancels |
| Timer fires after dispose (countdown) | `mounted` guard + cancel; test with injected clock |
| Silent data fabrication (response rate, on-site times, payouts, 7-day bars) | gap register is binding; reviewer checks every number traces to a field |
| `/tradie/earnings` shadowed by `/tradie/:id` | declare earnings route **before** `/tradie/:id`; covered by route snapshot test |
| `THSwitch` lacks `onChanged` | additive change in `th_widgets.dart` with pixel-neutral default; re-run gallery goldens (note: baselines were last blessed on Flutter 3.47.9; local 3.47.5 shows 60 diffs — compare on the same version) |
| On-demand packages start without an approved design | 5.10/5.11 step 1 is a gate: no code until the frame is generated and approved |
| 2,000-line files recreated as 2,000-line files | file-size budget: screen ≤ 250 lines, part files ≤ 300, `build()` ≤ 80 lines |
| Tests assert v1 text | keep v1 assertions for flag-off; add v2 twins; never delete v1 tests before Phase 6 |

## 8. Out of scope (stays as-is)

Backend/API changes unless the owner opts in (G-1 `DailyNet[]`, G-25 homeowner stats — only through the parent §4.1 additive-optional policy), v1 deletion and renames (Phase 6), screenshot/device suites, homeowner screens, web admin. Wide-screen layout and `/users/:id` are **on-demand** packages 5.10 and 5.11, started only when the owner requests their design.
