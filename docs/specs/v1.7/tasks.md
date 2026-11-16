# v1.7 — Implementation tasks

**Status:** Not started — awaiting owner go signal
**Date:** 2026-11-16
**References:** [Specification](specification.md) · [README](README.md)

Unchecked tasks are not started. A task is complete only when its acceptance criteria in [specification.md](specification.md) and the relevant tests pass. Priorities follow the specification's build order (§12): **P0** = foundation and pay-at-completion rewiring (highest risk, ships behind the `JobFlow:Version` feature flag); **P1** = tradie browse/request and price adjustments; **P2** = project jobs; **P3** = stretch (deferred — D2 resolved, not in Phase 12). Dependencies are task IDs; priorities do not override dependencies. Status values: `NOT STARTED` → `IN PROGRESS` → `COMPLETE`.

## Task summary

### Workstream A — Data model & contracts (spec §5)

| # | Task | Status | Priority | Depends | Spec ref |
|---|---|---|---|---|---|
| 1 | P12-01 Job pricing & timing migration | NOT STARTED | P0 | — | §5 |
| 2 | P12-02 CreateJobRequest, validators, DTOs | NOT STARTED | P0 | P12-01 | §5 |
| 3 | P12-03 Null-safe schedule consumers | NOT STARTED | P0 | P12-01 | §5 |

### Workstream B — Post Job, tradie browse, request (spec §6)

| # | Task | Status | Priority | Depends | Spec ref |
|---|---|---|---|---|---|
| 4 | P12-04 Simplify Post Job screen | NOT STARTED | P1 | P12-02 | §6 |
| 5 | P12-05 Tradie list API | NOT STARTED | P1 | P12-02 | §6 |
| 6 | P12-06 Choose-a-Tradie screen | NOT STARTED | P1 | P12-05 | §6 |
| 7 | P12-07 Profile in job context | NOT STARTED | P1 | P12-05 | §6 |
| 8 | P12-08 Direct request (offer) with rate snapshot | NOT STARTED | P1 | P12-01, P12-02 | §6 |
| 9 | P12-09 Request-sent screen | NOT STARTED | P1 | P12-08 | §6 |

### Workstream C — Payment at completion (spec §7)

| # | Task | Status | Priority | Depends | Spec ref |
|---|---|---|---|---|---|
| 10 | P12-10 State-machine rewiring | NOT STARTED | P0 | P12-01 | §7 |
| 11 | P12-11 Completion summary + approval | NOT STARTED | P0 | P12-10 | §7 |
| 12 | P12-12 Auto-approve & overdue-payment policy | NOT STARTED | P0 | P12-10, P12-11 | §7 |
| 13 | P12-13 Payment & payout on FinalAmount | NOT STARTED | P0 | P12-10, P12-11 | §7 |
| 14 | P12-14 Cancellation, no-show & refund rework | NOT STARTED | P0 | P12-10, P12-13 | §7 |
| 15 | P12-15 Mobile status/stepper/copy | NOT STARTED | P0 | P12-10, P12-11, P12-13 | §7 |
| 16 | P12-16 Admin web | NOT STARTED | P0 | P12-10, P12-13 | §7 |

### Workstream D — On-demand price adjustments (spec §8)

| # | Task | Status | Priority | Depends | Spec ref |
|---|---|---|---|---|---|
| 17 | P12-17 `JobPriceAdjustment` entity & endpoints | NOT STARTED | P1 | P12-01, P12-02 | §8 |
| 18 | P12-18 Realtime, push & expiry | NOT STARTED | P1 | P12-17 | §8 |
| 19 | P12-19 Tradie UI — "Request extra cost" | NOT STARTED | P1 | P12-17 | §8 |
| 20 | P12-20 Homeowner UI — approve / decline | NOT STARTED | P1 | P12-17, P12-18 | §8 |

### Workstream E — Project-based jobs (spec §9)

| # | Task | Status | Priority | Depends | Spec ref |
|---|---|---|---|---|---|
| 21 | P12-21 Job type + project fields (backend) | NOT STARTED | P2 | P12-01, P12-02 | §9 |
| 22 | P12-22 Post Job — project section | NOT STARTED | P2 | P12-04, P12-21 | §9 |
| 23 | P12-23 Quote requests & `Quote` entity | NOT STARTED | P2 | P12-21, P12-08 | §9 |
| 24 | P12-24 Quote UIs | NOT STARTED | P2 | P12-23, P12-06 | §9 |
| 25 | P12-25 Large-job guardrails (NZ context) | NOT STARTED | P2 | P12-23 | §9 |
| 26 | P12-26 Milestone payments (deferred / Phase C2) | NOT STARTED | P3 | P12-23 | §9 |

### Workstream F — Rollout & quality (spec §10)

| # | Task | Status | Priority | Depends | Spec ref |
|---|---|---|---|---|---|
| 27 | P12-27 Back-compat for in-flight jobs & feature flag | NOT STARTED | P0 | P12-10 (cross-cutting) | §10 |
| 28 | P12-28 Tests & docs | NOT STARTED | P0 | All (cross-cutting) | §10 |

## Dependency graph

```
P12-01 (data model)
├── P12-02 (request contract, DTOs)
│   ├── P12-04 (Post Job screen)            ┐
│   ├── P12-05 (tradie list API)            │ Workstream B
│   │   ├── P12-06 (Choose-a-Tradie screen) │
│   │   └── P12-07 (profile in job context) │
│   └── P12-17 (adjustments entity/API)     ┐
│       ├── P12-18 (realtime, push, expiry) │ Workstream D
│       ├── P12-19 (tradie UI)              │
│       └── P12-20 (homeowner UI) ← P12-18  ┘
├── P12-03 (null-safe schedule consumers)
├── P12-08 (direct request + rate snapshot) ← P12-02
│   └── P12-09 (request-sent screen)
├── P12-10 (state-machine rewiring)
│   ├── P12-11 (completion summary + approval)
│   │   ├── P12-12 (auto-approve / overdue policy)
│   │   └── P12-13 (payment & payout on FinalAmount)
│   │       ├── P12-14 (cancellation / no-show rework)
│   │       ├── P12-15 (mobile status / stepper / copy)
│   │       └── P12-16 (admin web)
│   └── P12-27 (feature flag / back-compat — starts here, runs throughout)
└── P12-21 (job type + project fields)
    └── P12-22 (Post Job project section) ← P12-04

P12-23 (quotes) ← P12-21, P12-08
├── P12-24 (quote UIs) ← P12-06
├── P12-25 (large-job guardrails)
└── P12-26 (milestones — deferred, D2 resolved)

P12-28 (tests & docs) — runs across all workstreams
```

## Build order (spec §12)

1. **P12-01 → P12-03** — data model, null-safe schedule. Foundation, no UX change yet.
2. **P12-10 → P12-16** — pay-at-completion, behind the flag. Highest risk; build and test first end-to-end.
3. **P12-04 → P12-09** — Post Job simplification, tradie list, profile, direct request. Fixes the "chosen tradie is ignored" bug (spec §3, row 4b).
4. **P12-17 → P12-20** — price adjustments.
5. **P12-21 → P12-25** — project jobs (**P12-26** milestones deferred — D2 resolved, not in Phase 12).
6. **P12-27 → P12-28** — throughout; flip the `JobFlow:Version` flag after QA.

---

## Task details

### [ ] P12-01 — Job pricing & timing migration

**Priority:** P0 · **Depends:** — · **Platform:** Backend
**References:** `Models/Job.cs`, `Data/FixoDbContext.cs`
**Objective:** Make timing optional and defer price determination to completion on the `Job` model, with a migration that keeps existing payout/history amounts intact.

**Checklist:**
- [ ] `ScheduledStartUtc` → `DateTimeOffset?`.
- [ ] Add `TimingPreference` enum (`Flexible`, `Asap`, `SpecificDate`, `DateRange`) stored as string; default `Flexible`. Add optional `ScheduledEndUtc` for ranges.
- [ ] `Hours` → `EstimatedHours int?`; `TotalAmount` → `EstimatedTotal decimal?`.
- [ ] Add `FinalHours decimal?`, `LabourAmount`, `AdjustmentsTotal`, `FinalAmount`, `CompletionSubmittedAtUtc`.
- [ ] Migration back-fills existing rows: `EstimatedTotal = TotalAmount`, `FinalAmount = TotalAmount` for already-`Completed` jobs so payouts/history stay intact.
- [ ] `JobOffer` gains `HourlyRateSnapshot decimal` and `Message string?`.

**Acceptance:** Migration applies cleanly on a copy of the dev DB; all money fields are `decimal(18,2)` (never float, per AGENTS.md); no existing `Completed` job changes its historical amounts.

---

### [ ] P12-02 — CreateJobRequest, validators, DTOs

**Priority:** P0 · **Depends:** P12-01 · **Platform:** Backend
**References:** `DTOs/JobDTOs.cs`, `Validators/JobValidators.cs`, `Services/JobService.cs`
**Objective:** Update the create-job contract so rate, hours and schedule are optional at posting (rate is chosen at request time), and expose the new fields to clients.

**Checklist:**
- [ ] `CreateJobRequest` drops `HourlyRate`; `Hours` becomes optional `EstimatedHours`; `ScheduledStartUtc` optional; adds `TimingPreference`.
- [ ] Validator: if `SpecificDate`/`DateRange` then dates required and in the future; otherwise must be null.
- [ ] Remove the "some tradie has this rate" check in `CreateJobAsync` (rate is now chosen at request time).
- [ ] `JobDto` exposes the new money/timing fields; legacy `TotalAmount` kept as a deprecated alias of `FinalAmount ?? EstimatedTotal` for one release.

**Acceptance:** A job can be posted with no rate, no hours and no schedule; invalid timing combinations are rejected with clear errors; existing clients keep working through the deprecated alias.

---

### [ ] P12-03 — Null-safe schedule consumers

**Priority:** P0 · **Depends:** P12-01 · **Platform:** Backend + Mobile
**References:** `MatchingService.cs` (schedule bonus), `JobStatusService.cs` (P5-03 reminder), `tradie_job_detail_screen.dart` (check-in window)
**Objective:** Every consumer of the (now nullable) schedule handles the null case without penalising flexible jobs.

**Checklist:**
- [ ] Matching: no schedule → schedule weight redistributed to distance/rating (not a free 0 that penalises flexible jobs).
- [ ] Reminder job only scheduled when a start time exists.
- [ ] Check-in button is available any time once `Booked` when no start time exists; "date TBC" shown on cards.

**Acceptance:** Flexible-timing jobs match and progress identically to dated jobs (no silent score penalty); no reminder/check-in crashes or dead buttons on null schedules.

---

### [ ] P12-04 — Simplify Post Job screen

**Priority:** P1 · **Depends:** P12-02 · **Platform:** Mobile
**References:** `views/jobs/post_job_screen.dart`, `viewmodels/jobs_viewmodel.dart` (`PostJobState`/`PostJobNotifier`)
**Objective:** Post Job collects the description only — no tradie or rate picking — with an optional timing selector and optional estimated hours.

**Checklist:**
- [ ] Remove the rate checkbox list, "Search nearby rates", and the live-estimate dependence on a selected rate.
- [ ] "When do you need help?" becomes a timing selector: **Flexible (default)**, ASAP, Pick a date, Date range. Urgency control stays.
- [ ] "Estimated hours" is optional with helper text "Skip if unsure — total is confirmed when the job is done."
- [ ] Submit → create job → navigate to `/jobs/:id/tradies` (not `/matching`).
- [ ] Only tokens from `design_tokens.dart`; no hardcoded values (AGENTS.md).

**Acceptance:** A homeowner can post a job without selecting a rate, hours or date; submit lands on the Choose-a-Tradie screen; `flutter analyze` clean; light + dark themes verified.

---

### [ ] P12-05 — Tradie list API

**Priority:** P1 · **Depends:** P12-02 · **Platform:** Backend + Mobile (small)
**References:** `Services/MatchingService.cs`, `DTOs/JobDTOs.cs` (`TradieMatchDto`, `ServiceSearchResultDto`), `GET /api/jobs/{id}/matches`
**Objective:** One endpoint feeds the Choose-a-Tradie screen: everything needed to compare tradies for this job, server-ranked — including GST status for final-price display (D8).

**Checklist:**
- [ ] One endpoint returns, per tradie: id, name/business, initials/avatar, verified, insured, rating, review count, distance, availability, **`HourlyRate` for the job's service**, completed-jobs count.
- [ ] `TradieProfile` gains `IsGstRegistered` (migration + profile DTOs; onboarding wizard & profile-edit toggle) — introduced here as the first consumer (D8).
- [ ] Each row carries `IsGstRegistered`; the listed `HourlyRate` is the final consumer price (GST-inclusive when registered) for "Incl. GST" / "No GST charged" labels (D8).
- [ ] Supports `sort` (`best`, `rating`, `distance`, `rate`) and filters (`verified`, `insured`, `availableNow`).
- [ ] Reuses EF Core spatial LINQ + `Geo` helpers (no raw PostGIS). Licence-gating (P10-08) still applies.
- [ ] Server owns ranking; "best" = existing score.

**Acceptance:** Sorted/filtered results are correct and stable; licence-gated tradies never appear for regulated services; no raw SQL introduced. Rates shown to homeowners are final consumer prices with correct GST labels (D8).

---

### [ ] P12-06 — Choose-a-Tradie screen

**Priority:** P1 · **Depends:** P12-05 · **Platform:** Mobile
**References:** `docs/design/v1.6/html/frames-homeowner.html` (H19), `router/app_router.dart`, new `views/jobs/tradie_list_screen.dart`
**Objective:** A dedicated tradie-list screen (design frame H19) where the homeowner browses, opens profiles, requests a specific tradie, or falls back to Quick match.

**Checklist:**
- [ ] Route `/jobs/:jobId/tradies`; shows list per spec §4.1 with sort/filter bar (reuse `fixo_filter_bar`/`fixo_filter_pill`).
- [ ] Rate display carries the GST label (D8): "Incl. GST" / "No GST charged".
- [ ] Card tap opens profile; "Quick match for me" starts the existing auto-match.
- [ ] Empty / loading / error states via `fixo_states`.
- [ ] Light and dark themes (AGENTS.md).

**Acceptance:** Screen matches H19 frame and design tokens; sort/filter wired to P12-05 params; Quick match path unchanged from today's behavior.

---

### [ ] P12-07 — Profile in job context

**Priority:** P1 · **Depends:** P12-05 · **Platform:** Mobile (+ small backend)
**References:** `views/profile/public_profile_screen.dart`, `/tradie/:id` route
**Objective:** The existing public profile doubles as the in-flow tradie detail view when opened with a `jobId`.

**Checklist:**
- [ ] Route accepts optional `jobId`; when present shows the **rate for this job's service** and a sticky **Request this tradie** CTA.
- [ ] Shows verified/insured badges, services & rates, rating + paginated reviews (already built).
- [ ] Profile API returns the tradie's rate for the service (add to existing profile DTO).
- [ ] The rate displays as a final consumer price with the GST label — "Incl. GST" / "No GST charged" (D8; `IsGstRegistered` surfaced via the profile DTO).
- [ ] Without `jobId` the screen behaves exactly as today.

**Acceptance:** Opening `/tradie/:id?jobId=…` shows the service rate + CTA; opening `/tradie/:id` is byte-for-byte the current behavior; no PII or unauthorised fields added to the DTO. GST label correct for registered and unregistered tradies (D8).

---

### [ ] P12-08 — Direct request (offer) with rate snapshot

**Priority:** P1 · **Depends:** P12-01, P12-02 · **Platform:** Backend
**References:** `Controllers/OffersController.cs`, `Services/JobService.cs` (`RequestTradieAsync`), `Jobs/SendOfferJob.cs`, `Jobs/OfferTimeoutJob.cs`
**Objective:** The homeowner's chosen tradie is actually the one asked — a `JobOffer` for that specific tradie with the rate snapshotted at request time. Fixes the latent bug (spec §3, row 4b) where the chosen tradie was ignored.

**Checklist:**
- [ ] `POST /api/jobs/{id}/request` `{ tradieId, message? }` creates a `JobOffer` for **that** tradie (replaces the unused `tradieId`), snapshotting `HourlyRateSnapshot`.
- [ ] Tradie accept → job `Requested → Booked`, `MatchedTradieId` + `Job.HourlyRate` copied from the snapshot.
- [ ] Decline / timeout → job stays `Requested`; homeowner is returned to the list (no auto-broaden unless they chose Quick match).
- [ ] Hourly jobs: one pending request at a time (existing invariant). Quick match path unchanged.
- [ ] The optional `message` is the only pre-acceptance contact channel — no chat thread before `Booked` (D3; P5-08 gating unchanged).
- [ ] Offer expiry is urgency-aware and configurable (D7): ~15–30 minutes for ASAP, ~2–4 hours for flexible.
- [ ] Status changes go through `IJobStatusService` and the SignalR hub (AGENTS.md).

**Acceptance:** Requesting a specific tradie produces an offer to exactly that tradie with the correct rate snapshot; decline/timeout returns the job to requestable state; all transitions emit SignalR events. No pre-booking chat path exists (D3).

---

### [ ] P12-09 — Request-sent screen

**Priority:** P1 · **Depends:** P12-08 · **Platform:** Mobile
**References:** `views/jobs/matching_screen.dart`, `views/jobs/match_result_screen.dart`
**Objective:** A waiting screen for the direct request: who was asked, at what rate, with countdown and recovery actions.

**Checklist:**
- [ ] Shows who was asked, their rate, countdown to `ExpiresAtUtc`, "Cancel request" and "Pick someone else".
- [ ] Accept → navigates to booked job detail; decline/timeout → back to list with a notice.
- [ ] `match_result_screen.dart` is retired or folded in (it currently auto-selects `matches[0]`).

**Acceptance:** The auto-select `matches[0]` behavior is gone; all three outcomes (accept/decline/timeout) land the homeowner in the right place with the right copy.

---

### [ ] P12-10 — State-machine rewiring

**Priority:** P0 · **Depends:** P12-01 · **Platform:** Backend
**References:** `Services/JobStatusService.cs` `ValidateTransition` (lines ~177–204)
**Objective:** Re-order the existing eight statuses so payment is the last step: accept → `Booked`, approval → `AwaitingPayment`, staff verify → `Completed`.

**Checklist:**
- [ ] Replace `Requested→AwaitingPayment` with `Requested→Booked` (actor: Tradie). Remove `PaymentReview→Booked`.
- [ ] Add `AwaitingConfirmation→AwaitingPayment` (Homeowner), `PaymentReview→Completed` (Staff/Superadmin), keep `PaymentReview→AwaitingPayment` (reject).
- [ ] `PaymentDueAtUtc` set on entry to `AwaitingPayment` (existing logic reused).
- [ ] Address-privacy rule (P5-01) unchanged: exact address revealed from `Booked`.
- [ ] Transition table has a unit test per edge.

**Acceptance:** The full §4.2 status flow passes edge-by-edge unit tests (one test per allowed edge, plus rejection tests for removed edges); address privacy unchanged.

---

### [ ] P12-11 — Completion summary + approval

**Priority:** P0 · **Depends:** P12-10 · **Platform:** Backend + Mobile
**References:** `JobsController.cs` (`check-out`, `confirm`), `tradie_job_detail_screen.dart`, `homeowner_job_detail_screen.dart`
**Objective:** The tradie submits final hours; the homeowner reviews an itemised summary and approves the amount (or disputes it) before paying.

**Checklist:**
- [ ] `check-out` accepts `{ finalHours, notes }`; server computes `LabourAmount`/`FinalAmount` from the rate snapshot + approved adjustments and shows tradie the total before submit.
- [ ] Homeowner sees an itemised summary (labour, each approved adjustment, total vs estimate) and chooses **Approve & pay** or **Dispute amount** (→ existing dispute flow).
- [ ] Cannot approve while any adjustment is `Pending`.
- [ ] If `FinalAmount` exceeds `EstimatedTotal` by more than a configurable tolerance (default 15%, per Consumer NZ estimate guidance) the homeowner sees a clear "higher than estimate" banner with the reason.

**Acceptance:** Money math server-side only (decimal), tolerance is configuration not code; approve is blocked by pending adjustments; over-estimate banner appears exactly when tolerance is exceeded.

---

### [ ] P12-12 — Auto-approve & overdue-payment policy

**Priority:** P0 · **Depends:** P12-10, P12-11 · **Platform:** Backend
**References:** `Jobs/AutoCompleteJob.cs`, `Jobs/PaymentExpiryJob.cs`, `Jobs/PaymentSlaJob.cs`, `Services/AccountFlagService.cs`
**Objective:** Auto-approve only safe completions; never auto-cancel finished work — chase overdue payment instead.

**Checklist:**
- [ ] The 48h auto-complete becomes **auto-approve**, and only when there are no pending adjustments **and** `FinalAmount ≤ EstimatedTotal × (1 + tolerance)` (or no estimate was given and amount ≤ a configured cap). Otherwise it escalates to staff instead of silently approving a higher bill.
- [ ] `PaymentExpiryJob` **no longer cancels** (work is done). Overdue payment sends reminders (24h/72h), then flags the homeowner account and notifies staff. Window reuses `PaymentOptions.WindowHours` (default 72h).
- [ ] Add `OverduePayment` to `Enums/AccountFlagType.cs` (current values: `RepeatCanceller`, `RepeatNoShow`, `Abuse`, `Manual`, `LowRating`) and raise it via `AccountFlagService`. A homeowner with this flag cannot post or request new jobs until the payment is verified.

**Acceptance:** High bills escalate to staff, never silently approve; overdue flow reminds → flags → blocks posting; the pending-adjustment guard is wired when P12-17 lands (it ships later in build order — until then the no-adjustments condition is vacuously true).

> **D1 (resolved):** no deposit/hold mechanism in Phase 12 — manual bank-transfer deposits would double admin verification; revisit only once an automated payment gateway (BNZ/Stripe) exists.

---

### [ ] P12-13 — Payment & payout on FinalAmount

**Priority:** P0 · **Depends:** P12-10, P12-11 · **Platform:** Backend
**References:** `Services/Payment/PaymentService.cs` (lines ~304, ~317), `Services/Payout/PayoutService.cs`
**Objective:** Payment and payout amounts follow `FinalAmount`, with the payout hook on the new `PaymentReview→Completed` transition and a configurable commission base.

**Checklist:**
- [ ] `Payment.Amount` = `Job.FinalAmount`; instructions/ref code unchanged.
- [ ] `PaymentReview→Completed` triggers `CreatePayoutAsync` (hook moves from the old confirm path); `GrossAmount = FinalAmount`.
- [ ] Commission base is configurable: `PayoutOptions:CommissionAppliesTo = LabourOnly | LabourAndAdjustments` (D5 resolved: **`LabourOnly`** default; toggle retained in config).
- [ ] Receipt hash / re-upload / SLA behaviour (P4, P10-16) unchanged.

**Acceptance:** Verify→Completed creates exactly one payout with `GrossAmount = FinalAmount`; commission computed on the configured base only; receipt verification flows unchanged.

---

### [ ] P12-14 — Cancellation, no-show & refund rework

**Priority:** P0 · **Depends:** P12-10, P12-13 · **Platform:** Backend
**References:** `JobStatusService.cs` (~299–410, ~441, ~665–735), `Models/Refund`, `docs/specs/v1.2/P6-*`, `P7-*`
**Objective:** With no upfront payment there is nothing to refund pre-completion — replace monetary penalties with non-monetary consequences; keep refunds only for post-payment dispute outcomes.

**Checklist:**
- [ ] Pre-completion cancellations create **no refund** (nothing was paid).
- [ ] Existing monetary penalties/partial refunds (e.g. 50% on tradie no-show) are replaced by non-monetary consequences only: strike/cancellation counters, `RepeatCanceller`/`RepeatNoShow` account flags, temporary suspension, visible reliability score (D4 resolved: invoiced cancellation fees are ruled out for Phase 12 — no enforcement without a card on file).
- [ ] Refund path remains only for post-payment disputes resolved in the homeowner's favour.
- [ ] No orphaned `Refund` rows for in-flight legacy jobs (see P12-27).

**Acceptance:** No cancellation path can create a refund for an unpaid job; no-show consequences still apply via flags/counters; legacy in-flight jobs verified refund-clean after migration dry-run.

---

### [ ] P12-15 — Mobile status/stepper/copy

**Priority:** P0 · **Depends:** P12-10, P12-11, P12-13 · **Platform:** Mobile
**References:** `views/widgets/job_progress.dart`, `job_progress_dots.dart`, `job_status_presentation.dart`, `job_timeline.dart`, `views/payment/payment_screen.dart`, `payment_status_screen.dart`, `models/marketplace.dart` (`stage` 0..5)
**Objective:** Mobile reflects the new order: work first, review & approve, then pay.

**Checklist:**
- [ ] Stepper order: Requested → Booked → In progress → Review & approve → Pay → Completed.
- [ ] Job cards show "$XX/hr · total confirmed on completion" (or "est. $YYY") instead of a fixed total.
- [ ] Payment screen is reached from "Approve & pay", not from a job card in the first state (`job_navigation.dart` `openHomeownerJob` rewired).
- [ ] Disclaimer copy (P10-22) updated: materials are added in-app and need your approval.

**Acceptance:** Stepper renders correctly for every status in both themes; no card state deep-links into payment before approval; stage mapping (`stage` 0..5) updated with tests.

---

### [ ] P12-16 — Admin web

**Priority:** P0 · **Depends:** P12-10, P12-13 · **Platform:** Web
**References:** `web/src/features/payments/*`, payout queue
**Objective:** The admin payment queue matches the new flow: verify completed work, plus a view for overdue payments.

**Checklist:**
- [ ] Payment queue row shows job title, itemised amount and "work completed on \<date\>".
- [ ] Verify action → job `Completed` + payout `Pending` (copy updated; no longer "Booked").
- [ ] Overdue-payment view (jobs in `AwaitingPayment` past due) for staff follow-up.

**Acceptance:** Verify produces `Completed` + pending payout (asserted by e2e); overdue view lists only past-due `AwaitingPayment` jobs; copy reviewed.

---

### [ ] P12-17 — `JobPriceAdjustment` entity & endpoints

**Priority:** P1 · **Depends:** P12-01, P12-02 · **Platform:** Backend
**References:** new `Models/JobPriceAdjustment.cs`, `Controllers/JobsController.cs` (or new `AdjustmentsController`), `Validators/`
**Objective:** On-demand price changes during a job, each requiring the homeowner's recorded approval before it can be billed — the "in writing" record NZ guidance expects.

**Checklist:**
- [ ] Fields: `Id, JobId, ProposedByTradieId, Kind (Materials | ExtraLabour | Travel | Other), Description (≤500), Amount decimal(18,2) > 0, EvidenceFileKey?, Status (Pending | Approved | Declined | Withdrawn | Expired), CreatedAtUtc, RespondedAtUtc?, ResponseNote?`.
- [ ] `POST /api/jobs/{id}/adjustments` (Tradie, job `Booked`/`InProgress`/`AwaitingConfirmation`).
- [ ] `POST /api/jobs/{id}/adjustments/{adjId}/respond` `{ approve, note? }` (owning homeowner).
- [ ] `POST …/withdraw` (proposing tradie while `Pending`). `GET /api/jobs/{id}/adjustments`.
- [ ] Only **Approved** adjustments count toward `AdjustmentsTotal`. A tradie cannot invoice an unapproved extra (aligns with business.govt.nz/Consumer Protection guidance).
- [ ] Evidence (receipt/photo) stored in a private blob container like `fixo-payments`; encouraged (not required) for `Materials`.
- [ ] Every proposal/decision recorded in `JobStatusHistory`/audit log (this is the "in writing" record).

**Acceptance:** Unapproved extras can never reach `FinalAmount`; every state change auditable; evidence blobs private (no public URLs); validators enforce amounts > 0 and description length.

---

### [ ] P12-18 — Realtime, push & expiry

**Priority:** P1 · **Depends:** P12-17 · **Platform:** Backend
**References:** `Hubs/JobHub.cs`, `Services/PushNotificationService.cs`, Hangfire
**Objective:** Both sides hear about adjustment proposals/decisions instantly, and stale proposals expire instead of lingering.

**Checklist:**
- [ ] SignalR event `JobAdjustmentChanged` + FCM push to the homeowner on new proposal, and to the tradie on decision.
- [ ] Pending adjustments `Expire` after a configurable window (default 48h) with a reminder at 24h.
- [ ] Config guard: max N pending adjustments per job; per-adjustment cap triggers staff review above a threshold.

**Acceptance:** Push + SignalR fire on proposal and decision; expiry job flips status and notifies; guards enforced server-side with config-driven limits.

---

### [ ] P12-19 — Tradie UI — "Request extra cost"

**Priority:** P1 · **Depends:** P12-17 · **Platform:** Mobile
**References:** `views/tradie/tradie_job_detail_screen.dart`
**Objective:** Tradies can request extra costs (materials, extra labour, travel) with evidence, and track each request's status.

**Checklist:**
- [ ] Action visible during `Booked`/`InProgress`/`AwaitingConfirmation`: pick kind, amount, description, attach receipt/photo.
- [ ] Shows status of each request (pending/approved/declined) and running total.
- [ ] If declined: tradie may continue original scope or cancel with a new no-penalty reason `scope_change_declined`.

**Acceptance:** Full propose→respond→running-total loop works in both themes; `scope_change_declined` cancellation carries no penalty.

---

### [ ] P12-20 — Homeowner UI — approve / decline

**Priority:** P1 · **Depends:** P12-17, P12-18 · **Platform:** Mobile
**References:** `views/homeowner/homeowner_job_detail_screen.dart`, new bottom sheet
**Objective:** Homeowners get a clear approve/decline sheet for each extra cost, deep-linked from push, plus an adjustments history on the job.

**Checklist:**
- [ ] Push deep-links to a sheet: what, how much, receipt, running total vs estimate, **Approve / Decline (+ note)**.
- [ ] Job detail shows an "Adjustments" section with history.
- Pre-approved materials allowance is **cut from Phase 12** (D6): explicit one-tap Approve/Decline is the only path — auto-approval caps invite disputes over receipt validity.

**Acceptance:** Approve/decline updates the running total immediately (SignalR); history section shows all adjustments with statuses; no pre-approval/auto-approval path ships (D6 — cut).

---

### [ ] P12-21 — Job type + project fields (backend)

**Priority:** P2 · **Depends:** P12-01, P12-02 · **Platform:** Backend
**References:** `Models/Job.cs`, DTOs, validators
**Objective:** One `Job` table with a `JobType` control (`Hourly` | `Project`) and project-only optional fields; hourly behavior unchanged.

**Checklist:**
- [ ] `JobType` enum (`Hourly`, `Project`), default `Hourly`.
- [ ] Project-only optional fields: `BudgetMin/BudgetMax decimal?`, `MaterialsBy (Tradie | Homeowner | Undecided)`, `SiteVisitWelcome bool`, `DesiredStartBy/FinishBy` (reuses timing fields from P12-01), `ScopeNotes`.
- [ ] Attachment limit for projects raised (config, default 10 files incl. PDFs) without changing the 5-photo cap for hourly jobs (P10-14).
- [ ] Hourly validators unchanged; project validators don't require hours or rate.

**Acceptance:** Hourly posting is byte-identical to before; project posting accepts the new fields; attachment caps enforced per job type from configuration.

---

### [ ] P12-22 — Post Job — project section

**Priority:** P2 · **Depends:** P12-04, P12-21 · **Platform:** Mobile
**References:** `post_job_screen.dart`, `PostJobState`
**Objective:** The same Post Job screen serves both job types via a segmented control; project extras are optional and clearly explained.

**Checklist:**
- [ ] Segmented control at the top; shared sections (service, address, title, description, photos, timing) are identical for both types.
- [ ] Project adds: budget range (optional), materials responsibility, "site visit welcome", extra attachments. Timing defaults to **Flexible**.
- [ ] Helper copy explains the difference ("Quick job = hourly rate, pay when done. Project = tradies send you a quote").
- [ ] Submit goes to the same Choose-a-Tradie screen.

**Acceptance:** Switching types never loses shared input; hourly jobs never see project fields; copy reviewed; both themes.

---

### [ ] P12-23 — Quote requests & `Quote` entity

**Priority:** P2 · **Depends:** P12-21, P12-08 · **Platform:** Backend
**References:** `Models/JobOffer.cs`, `OffersController.cs`, new `Models/Quote.cs`
**Objective:** For projects, homeowners request quotes from up to 3 tradies concurrently; quotes carry their own pricing model and lifecycle.

**Checklist:**
- [ ] `JobOffer.Kind` (`Instant`, `QuoteRequest`). For projects the homeowner may request quotes from **up to 3 tradies concurrently** (mirrors Builderscrack's cap); instant jobs stay single-pending.
- [ ] Quote fields: `PricingModel (Fixed | EstimateRange | HourlyWithCap)`, `Amount` or `Min/Max`, `Cap?`, `Inclusions`, `Exclusions`, `MaterialsIncluded bool`, `GstIncluded bool`, `ProposedStartUtc?`, `EstimatedDurationDays?`, `ValidUntilUtc`, `Status (Submitted | Accepted | Declined | Withdrawn | Expired)`.
- [ ] D8: quote prices are final consumer prices — GST-inclusive when the tradie is `IsGstRegistered` (`GstIncluded` required `true` for registered tradies; unregistered tradies cannot charge GST).
- [ ] Quote window configurable (default 72h). Accepting one quote declines the others and moves the job to `Booked` with the agreed `PricingModel` snapshotted on the job.
- [ ] `FinalAmount` for `Fixed` = agreed price + approved adjustments; for `EstimateRange` / `HourlyWithCap` = actual, validated against the range/cap (above cap requires an approved adjustment).

**Acceptance:** Concurrency cap enforced (4th request rejected); accept-one-declines-rest atomic; cap/range validation blocks unapproved overruns at completion.

---

### [ ] P12-24 — Quote UIs

**Priority:** P2 · **Depends:** P12-23, P12-06 · **Platform:** Mobile
**References:** `views/tradie/request_detail_screen.dart`, new `views/jobs/quotes_screen.dart`
**Objective:** Tradies submit structured quotes; homeowners compare them side by side and accept one.

**Checklist:**
- [ ] Tradie: project request detail has a **Submit quote** form (fields above) instead of a one-tap accept.
- [ ] Homeowner: `/jobs/:id/quotes` compares quotes side by side (price, inclusions, start date, rating) with profile links; **Accept quote**.
- [ ] Quote prices display with the GST label (D8): "Incl. GST" / "No GST charged".
- [ ] Payment still happens at completion (same flow as spec §4.2).

**Acceptance:** Full quote submit→compare→accept loop works; accepting books the job with the agreed pricing model; no payment UI before completion.

---

### [ ] P12-25 — Large-job guardrails (NZ context)

**Priority:** P2 · **Depends:** P12-23 · **Platform:** Backend + Mobile
**Objective:** NZD 30,000+ residential building work gets the written-contract notice the Building Act requires, before booking.

**Checklist:**
- [ ] When an accepted quote/estimate is **≥ NZD 30,000 incl. GST**, show a notice that a written contract is required for residential building work (Building Act s362F per building.govt.nz) and require the homeowner to confirm one exists (or attach it) before the job moves to `Booked`.
- [ ] Threshold is configuration, not code.
- [ ] **Legal review before enabling projects in production** — this plan's NZ-law references come from government guidance pages and are not legal advice.

**Acceptance:** Booking is blocked above threshold until contract confirmed/attached; threshold configurable; legal-review gate recorded before production flip.

---

### [ ] P12-26 — Milestone payments (deferred / Phase C2)

**Priority:** P3 · **Depends:** P12-23 · **Platform:** Backend + Mobile + Web
**Rationale:** NZ implied terms default to monthly progress payments; large projects realistically need staged payment. `PRD.md` already lists milestone payments as a goal.
**Deferred (D2 resolved 2026-11-16) — not in Phase 12.** Projects ship with payment-at-completion only; interim staging via progress terms in the quote or sequential jobs.

**Checklist:**
- [ ] Quote may include milestones (`Title, Amount, DueOn`). Tradie marks a milestone done → homeowner approves → pays via the same receipt/verify flow → per-milestone payout.
- [ ] Final milestone closes the job → `Completed`.

**Acceptance:** Per-milestone receipt/verify/payout reuses the P12-13 flow unchanged; job closes only on the final milestone.

---

### [ ] P12-27 — Back-compat for in-flight jobs & feature flag

**Priority:** P0 · **Depends:** P12-10 (cross-cutting — starts with the state-machine work) · **Platform:** Backend
**Objective:** Old-model jobs finish under the old rules; new flow ships dark behind a flag until QA passes.

**Checklist:**
- [ ] Feature flag `JobFlow:Version = 1 | 2` (default 1 until QA passes).
- [ ] Jobs already in `AwaitingPayment`/`PaymentReview`/`Booked` under the old model finish under the old rules (flag stored on the job, not just globally).
- [ ] Migration dry-run on a copy of the dev DB; no orphaned payments/refunds/payouts.

**Acceptance:** Flipping the flag changes only new-job behavior; in-flight legacy jobs complete on the old path with no orphaned rows; dry-run report recorded.

---

### [ ] P12-28 — Tests & docs

**Priority:** P0 · **Depends:** All (cross-cutting — runs throughout) · **Platform:** Backend + Mobile + Web
**Objective:** Every transition, every money path, and the docs stay true to the shipped flow.

**Checklist:**
- [ ] Backend: unit tests for every transition in spec §4.2; money-math tests (rounding, adjustments, cap/tolerance); auto-approve edge cases.
- [ ] Mobile: widget tests for Post Job (hourly/project), tradie list, adjustment sheet; update `mobile/integration_test/job_request_test.dart`, `job_lifecycle_test.dart`, `payment_test.dart`.
- [ ] New smoke script `scripts/p12-smoke.sh` (post → pick → accept → in-progress → adjust → complete → approve → pay → verify → payout).
- [ ] Update `MVP-SPEC` (supersede A5, B1), P4/P5/P6 notes, QA guide (`QA-14-p12-*.md`), README.

**Acceptance:** All listed suites green in CI; smoke script runs the full §4.2 flow end-to-end; superseded spec sections clearly marked; QA-14 checklist added under `qa/`.

---

## Resolved decisions (owner, 2026-11-16)

All eight decisions are resolved — resolutions and rationale in [specification.md](specification.md) §11. Outcomes wired into the tasks above: **D1** pay-at-end with platform safeguards, no deposits (P12-12) · **D2** milestones deferred — not in Phase 12 (P12-26) · **D3** request + optional message only, chat stays gated to `Booked`+ (P12-08) · **D4** non-monetary consequences only, no invoiced fees (P12-14) · **D5** commission `LabourOnly` by default, toggle retained (P12-13) · **D6** pre-approved materials allowance cut (P12-20) · **D7** single pending request with urgency-aware expiry — ~15–30 min ASAP / ~2–4 h flexible, configurable (P12-08) · **D8** GST-inclusive consumer pricing: `IsGstRegistered` on the tradie profile, introduced in P12-05, surfaced in P12-05/P12-07/P12-23, labels in P12-06/P12-24.
