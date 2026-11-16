# Phase 12: Job Flow Revision — Flexible Timing, Pay-on-Completion, Price Adjustments, Tradie Browse, Project Jobs

**Status:** v1.7 specification — owner sign-off received 2026-11-16; open decisions D1–D8 resolved 2026-11-16 (§11); implementation not started (tracked in [tasks.md](tasks.md)). Originally written 2026-11-16 against `main` @ `c45a2d6`; adopted into `docs/specs/v1.7/` on `dev`.

> **Scope flag (AGENTS.md rule).** This plan changes decisions recorded in `docs/MVP-SPEC-v1.3.md`:
> **A5** (hourly-only), **B1** (materials off-platform), and the **P4** upfront-payment model.
> It needs explicit sign-off before any build — **received 2026-11-16**. It does **not** add in-app card payments / BNZ
> integration (still out of scope); payment stays manual bank-transfer + receipt + admin verification.

---

## 1. Requested changes

1. Timeframe is **optional** for the homeowner.
2. **Total price is determined at job completion**, not at request. The tradie's rate is still shown. Payment moves to the **end** of the flow, not at booking.
3. Support **on-demand price changes** during the job (materials bought by the tradie, extra work, etc.).
4. **Tradie selection leaves the Post Job screen.** It becomes its own tradie-list screen where homeowners can open a tradie's profile before proceeding or contacting.
5. Plan **project-based jobs** on the *same* Post Job screen.

---

## 2. Research: how NZ job posting works today

Findings are from a limited set of public sources (listed in §13). Where a source did not confirm a detail, it is marked.

| Theme | What NZ practice / guidance says | Source |
|---|---|---|
| Posting | Posting is free; homeowner describes the job, photos are optional but help. Matching sends the job to suitable local tradies. | Builderscrack |
| Choosing | Homeowners review profiles, licences, galleries and verified reviews, and can connect with **up to three** tradies. | Builderscrack |
| Paying | Homeowner **pays the tradie directly when the job is finished**, then reviews. Tradies (not homeowners) fund the platform. | Builderscrack |
| Escrow alternative | Airtasker holds payment at assignment and releases it when the customer approves completion. Price changes are agreed directly with the worker. | Airtasker |
| Timing | Good NZ builders are often booked months ahead; homeowners should decide whether they need a fixed start/finish or can wait for their preferred tradie. Flexible timing is normal. | Consumer NZ |
| Quote vs estimate | An **estimate** is a best guess (final price should generally land within 10–15%). A **quote** is a fixed offer; the provider can't charge more once accepted **unless the homeowner agrees to extra work**. | Consumer Protection NZ |
| Extra costs | Homeowner should not have to pay an unagreed difference. Variations should be **recorded in writing and agreed before** the extra work. Agree in writing that the tradie will contact the owner **before** the price exceeds the estimate. | business.govt.nz, Master Plumbers |
| Charge-up jobs | Where work is charged by actual labour + materials, you pay for what was actually used. | Consumer NZ |
| Larger work | Residential building work of **$30,000+ (incl. GST)** must have a written contract (Building Act s362F). Default progress payments are **monthly**; progress claims must be paid within 20 working days of a written demand. | building.govt.nz |
| Disputes | Fast-track adjudication under the Construction Contracts Act; Disputes Tribunal for smaller claims. | building.govt.nz, Consumer Protection NZ |

**Takeaways that drive this plan**

- Pay-at-the-end matches the NZ norm (Builderscrack) and the owner's requirement. The platform trade-off: escrow platforms (Airtasker) protect tradies from non-payment; pay-at-end moves that risk to the tradie, so §7 (P12-12) and §11 (D1) add safeguards.
- A price that can move must move **with the homeowner's explicit, recorded approval** — this is both good UX and the NZ legal expectation.
- Hourly-only is fine for small jobs but is the wrong tool for projects. The repo already says so (`MVP-SPEC-v1.3.md` §1 risk note: NZ homeowners resist open-ended hourly billing for larger work; quote pricing "should be fast-tracked").
- *Not confirmed by sources fetched:* whether Builderscrack's form asks for a timeframe or budget. Treat "optional timing" as a product decision, not a copied competitor feature.

---

## 3. Cross-check: what's implemented vs what's needed

| # | Requirement | Current implementation (evidence) | Gap |
|---|---|---|---|
| 1 | Optional timeframe | `Job.ScheduledStartUtc` is non-nullable; validator requires it (`Validators/JobValidators.cs:27`); post screen blocks submit until chosen (`post_job_screen.dart` `_getMissingFieldHelper`). Also consumed by matching score (`MatchingService.cs`, 15% weight), pre-job reminder (P5-03), check-in window (P5-06). | **Full gap.** Needs nullable + a timing preference, and every consumer must handle null. |
| 2 | Total at completion | `Job.TotalAmount = HourlyRate × Hours` is fixed at creation (`JobService.cs:83`). `Hours > 0` and a rate are required. | **Full gap.** Needs estimate vs final amounts. |
| 2b | Pay at completion | Flow is `Requested → AwaitingPayment → PaymentReview → Booked → InProgress → AwaitingConfirmation → Completed`. Receipt upload is gated on `AwaitingPayment` (`PaymentService.cs:76`); expiry job **cancels** unpaid jobs (`PaymentExpiryJob`). | **Inverted.** Payment must be the last step. |
| 2c | Rate still visible | `TradieRate.HourlyRate` shown in inline picker and snapshotted on the job. | ✅ Keep; snapshot must move to request time. |
| 3 | On-demand price changes | None. MVP-SPEC **B1** says materials are billed off-platform; **B2** (in-app materials + approval) and **B3** (chat guidance only) are deferred. `Payment.Amount` is frozen to `Job.TotalAmount`. | **Full gap.** |
| 4 | Tradie list + profile screen | Tradie choice is an inline checkbox list inside Post Job (`post_job_screen.dart:274`). A `PublicProfileScreen` (`/tradie/:id`) and a design frame **H19 Browse Tradies** (`docs/design/v1.6/html/frames-homeowner.html:883`) already exist but aren't in the job flow. | Partial. Screens exist; flow doesn't use them. |
| 4b | **Latent bug:** chosen tradie is ignored | Mobile sends only `hourlyRate` (`jobs_viewmodel.dart:584`); backend only checks *some* verified tradie has that rate (`JobService.cs:54-60`). The `tradieId` is never sent. Matching then **auto-ranks** and offers sequentially. | The homeowner thinks they picked a tradie; the system picks for them. Fixed by §4 flow. |
| 4c | Contact before booking | Chat is gated to Booked/InProgress (P5-08). | Resolved (D3): request + optional message only; chat stays gated to `Booked`+ (P5-08 unchanged). |
| 5 | Project jobs | Not supported. Only `Hourly`. Photos capped at 5 (P10-14). No quotes, no milestones. PRD lists "milestone payments" and "job board" as goals (`PRD.md` §features) but neither is built. | **Full gap.** |
| — | Reviews, disputes, payouts, admin payment queue, SLA | ✅ All exist and are reusable. | Rewire triggers only. |

**Blast radius of moving payment to the end** (found by grep, non-migration):
`TotalAmount` is read in 9 backend files (`PayoutService` ×6, `PaymentService`, `JobStatusService`, `JobService`, `FixoDbContext`, `PayoutBatch`, DTOs); `ScheduledStartUtc` in 6; and 12 mobile files reference `totalAmount`/`scheduledStart`.
Cancellation/no-show refund logic (`JobStatusService.cs` ~299–410, ~684–729) is built on a payment that already exists — with pay-at-end there is nothing to refund, so that logic must be redesigned (P12-14).

---

## 4. Target flow

### 4.1 Screen flow (homeowner)

```
Post a Job  (describe only — no tradie, no rate picking)
  ├─ Quick job (hourly)  ──┐
  └─ Project               ├─► submit → creates Job (Requested)
                           ┘
Choose a Tradie   /jobs/:id/tradies        ← NEW screen (use design frame H19)
  list: photo/initials, name, verified + insured badges, rating (n reviews),
        distance, availability, "$XX/hr" rate for this service
  filter/sort: rating · distance · rate · availability
  ├─ tap card ─► Tradie Profile  /tradie/:id?jobId=…    (existing screen, extended)
  │                about · services & rates · licences/insurance · reviews · (gallery later)
  │                sticky CTA: [Request this tradie]  [Back to list]
  └─ "Quick match for me"  → existing auto-match (ranked sequential offers) as fallback
Request sent / waiting   /jobs/:id/request     ← reworked MatchingScreen
  Hourly: one pending request with countdown; on decline/timeout → back to list
  Project: up to 3 quote requests, quotes arrive over time (see §9)
Booked  → job detail with tradie, rate, timing, chat
InProgress → (price adjustment requests can arrive here)
Approve & Pay   ← NEW position of payment
  review final hours + adjustments → approve final amount → bank transfer instructions → upload receipt
Completed → review prompt
```

### 4.2 Status flow

```
Requested ─(tradie accepts)──────────────► Booked
Booked ───(check-in)─────────────────────► InProgress
InProgress ─(check-out + completion summary)► AwaitingConfirmation
AwaitingConfirmation ─(homeowner approves final amount)► AwaitingPayment
AwaitingConfirmation ─(homeowner disputes amount)──────► Disputed        (edge already exists)
AwaitingPayment ─(receipt uploaded)──────► PaymentReview
PaymentReview ─(staff verifies)──────────► Completed   ← payout created here
PaymentReview ─(staff rejects)───────────► AwaitingPayment
Any pre-Completed ─(cancel)──────────────► Cancelled
```

No new enum values are required: the same eight statuses are **re-ordered**, not added. `Completed` now means *work approved and paid*.

### 4.3 Money model

```
EstimatedHours      optional (homeowner's guess; blank = "total confirmed on completion")
HourlyRate          snapshot of the tradie's rate at REQUEST time (shown everywhere)
EstimatedTotal      optional = rate × estimated hours (display only, labelled "est.")
FinalHours          entered by tradie at completion (check-in/out duration shown as reference)
LabourAmount        FinalHours × HourlyRate
AdjustmentsTotal    Σ APPROVED price adjustments (materials, extra work, travel…)
FinalAmount         LabourAmount + AdjustmentsTotal      ← what the homeowner pays
```
All `decimal(18,2)`, never float (AGENTS.md).

---

## 5. Workstream A — Data model & contracts

### P12-01: Job pricing & timing migration
- **Platform:** Backend
- **References:** `Models/Job.cs`, `Data/FixoDbContext.cs`
- **Acceptance Criteria:**
  - [ ] `ScheduledStartUtc` → `DateTimeOffset?`.
  - [ ] Add `TimingPreference` enum (`Flexible`, `Asap`, `SpecificDate`, `DateRange`) stored as string; default `Flexible`. Add optional `ScheduledEndUtc` for ranges.
  - [ ] `Hours` → `EstimatedHours int?`; `TotalAmount` → `EstimatedTotal decimal?`.
  - [ ] Add `FinalHours decimal?`, `LabourAmount`, `AdjustmentsTotal`, `FinalAmount`, `CompletionSubmittedAtUtc`.
  - [ ] Migration back-fills existing rows: `EstimatedTotal = TotalAmount`, `FinalAmount = TotalAmount` for already-`Completed` jobs so payouts/history stay intact.
  - [ ] `JobOffer` gains `HourlyRateSnapshot decimal` and `Message string?`.

### P12-02: CreateJobRequest, validators, DTOs
- **Platform:** Backend
- **References:** `DTOs/JobDTOs.cs`, `Validators/JobValidators.cs`, `Services/JobService.cs`
- **Acceptance Criteria:**
  - [ ] `CreateJobRequest` drops `HourlyRate`; `Hours` becomes optional `EstimatedHours`; `ScheduledStartUtc` optional; adds `TimingPreference`.
  - [ ] Validator: if `SpecificDate`/`DateRange` then dates required and in the future; otherwise must be null.
  - [ ] Remove the "some tradie has this rate" check in `CreateJobAsync` (rate is now chosen at request time).
  - [ ] `JobDto` exposes the new money/timing fields; legacy `TotalAmount` kept as a deprecated alias of `FinalAmount ?? EstimatedTotal` for one release.

### P12-03: Null-safe schedule consumers
- **Platform:** Backend + Mobile
- **References:** `MatchingService.cs` (schedule bonus), `JobStatusService.cs` (P5-03 reminder), `tradie_job_detail_screen.dart` (check-in window)
- **Acceptance Criteria:**
  - [ ] Matching: no schedule → schedule weight redistributed to distance/rating (not a free 0 that penalises flexible jobs).
  - [ ] Reminder job only scheduled when a start time exists.
  - [ ] Check-in button is available any time once `Booked` when no start time exists; "date TBC" shown on cards.

---

## 6. Workstream B — Post Job, tradie browse, request

### P12-04: Simplify Post Job screen
- **Platform:** Mobile
- **References:** `views/jobs/post_job_screen.dart`, `viewmodels/jobs_viewmodel.dart` (`PostJobState`/`PostJobNotifier`)
- **Acceptance Criteria:**
  - [ ] Remove the rate checkbox list, "Search nearby rates", and the live-estimate dependence on a selected rate.
  - [ ] "When do you need help?" becomes a timing selector: **Flexible (default)**, ASAP, Pick a date, Date range. Urgency control stays.
  - [ ] "Estimated hours" is optional with helper text "Skip if unsure — total is confirmed when the job is done."
  - [ ] Submit → create job → navigate to `/jobs/:id/tradies` (not `/matching`).
  - [ ] Only tokens from `design_tokens.dart`; no hardcoded values (AGENTS.md).

### P12-05: Tradie list API
- **Platform:** Backend (+ small mobile: GST registration toggle)
- **References:** `Services/MatchingService.cs`, `DTOs/JobDTOs.cs` (`TradieMatchDto`, `ServiceSearchResultDto`), `GET /api/jobs/{id}/matches`
- **Acceptance Criteria:**
  - [ ] One endpoint returns, per tradie: id, name/business, initials/avatar, verified, insured, rating, review count, distance, availability, **`HourlyRate` for the job's service**, completed-jobs count.
  - [ ] `TradieProfile` gains `IsGstRegistered` (migration + profile DTOs; onboarding wizard & profile-edit toggle) — introduced here as the first consumer (D8).
  - [ ] Each row carries `IsGstRegistered`; the listed `HourlyRate` is the final consumer price (GST-inclusive when registered) for "Incl. GST" / "No GST charged" labels (D8 — NZ Fair Trading Act consumer pricing).
  - [ ] Supports `sort` (`best`, `rating`, `distance`, `rate`) and filters (`verified`, `insured`, `availableNow`).
  - [ ] Reuses EF Core spatial LINQ + `Geo` helpers (no raw PostGIS). Licence-gating (P10-08) still applies.
  - [ ] Server owns ranking; "best" = existing score.

### P12-06: Choose-a-Tradie screen
- **Platform:** Mobile
- **References:** `docs/design/v1.6/html/frames-homeowner.html` (H19), `router/app_router.dart`, new `views/jobs/tradie_list_screen.dart`
- **Acceptance Criteria:**
  - [ ] Route `/jobs/:jobId/tradies`; shows list per §4.1 with sort/filter bar (reuse `fixo_filter_bar`/`fixo_filter_pill`).
  - [ ] Rate display carries the GST label (D8): "Incl. GST" / "No GST charged".
  - [ ] Card tap opens profile; "Quick match for me" starts the existing auto-match.
  - [ ] Empty / loading / error states via `fixo_states`.
  - [ ] Light and dark themes (AGENTS.md).

### P12-07: Profile in job context
- **Platform:** Mobile (+ small backend)
- **References:** `views/profile/public_profile_screen.dart`, `/tradie/:id` route
- **Acceptance Criteria:**
  - [ ] Route accepts optional `jobId`; when present shows the **rate for this job's service** and a sticky **Request this tradie** CTA.
  - [ ] Shows verified/insured badges, services & rates, rating + paginated reviews (already built).
  - [ ] Profile API returns the tradie's rate for the service (add to existing profile DTO).
  - [ ] The rate displays as a final consumer price with the GST label — "Incl. GST" / "No GST charged" (D8; `IsGstRegistered` surfaced via the profile DTO).
  - [ ] Without `jobId` the screen behaves exactly as today.

### P12-08: Direct request (offer) with rate snapshot
- **Platform:** Backend
- **References:** `Controllers/OffersController.cs`, `Services/JobService.cs` (`RequestTradieAsync`), `Jobs/SendOfferJob.cs`, `Jobs/OfferTimeoutJob.cs`
- **Acceptance Criteria:**
  - [ ] `POST /api/jobs/{id}/request` `{ tradieId, message? }` creates a `JobOffer` for **that** tradie (replaces the unused `tradieId`), snapshotting `HourlyRateSnapshot`.
  - [ ] Tradie accept → job `Requested → Booked`, `MatchedTradieId` + `Job.HourlyRate` copied from the snapshot.
  - [ ] Decline / timeout → job stays `Requested`; homeowner is returned to the list (no auto-broaden unless they chose Quick match).
  - [ ] Hourly jobs: one pending request at a time (existing invariant). Quick match path unchanged.
  - [ ] The optional `message` is the only pre-acceptance contact channel — no chat thread before `Booked` (D3; P5-08 gating unchanged).
  - [ ] Offer expiry is urgency-aware and configurable (D7): ~15–30 minutes for ASAP, ~2–4 hours for flexible.
  - [ ] Status changes go through `IJobStatusService` and the SignalR hub (AGENTS.md).

### P12-09: Request-sent screen
- **Platform:** Mobile
- **References:** `views/jobs/matching_screen.dart`, `views/jobs/match_result_screen.dart`
- **Acceptance Criteria:**
  - [ ] Shows who was asked, their rate, countdown to `ExpiresAtUtc`, "Cancel request" and "Pick someone else".
  - [ ] Accept → navigates to booked job detail; decline/timeout → back to list with a notice.
  - [ ] `match_result_screen.dart` is retired or folded in (it currently auto-selects `matches[0]`).

---

## 7. Workstream C — Payment at completion

### P12-10: State-machine rewiring
- **Platform:** Backend
- **References:** `Services/JobStatusService.cs` `ValidateTransition` (lines ~177–204)
- **Acceptance Criteria:**
  - [ ] Replace `Requested→AwaitingPayment` with `Requested→Booked` (actor: Tradie). Remove `PaymentReview→Booked`.
  - [ ] Add `AwaitingConfirmation→AwaitingPayment` (Homeowner), `PaymentReview→Completed` (Staff/Superadmin), keep `PaymentReview→AwaitingPayment` (reject).
  - [ ] `PaymentDueAtUtc` set on entry to `AwaitingPayment` (existing logic reused).
  - [ ] Address-privacy rule (P5-01) unchanged: exact address revealed from `Booked`.
  - [ ] Transition table has a unit test per edge.

### P12-11: Completion summary + approval
- **Platform:** Backend + Mobile
- **References:** `JobsController.cs` (`check-out`, `confirm`), `tradie_job_detail_screen.dart`, `homeowner_job_detail_screen.dart`
- **Acceptance Criteria:**
  - [ ] `check-out` accepts `{ finalHours, notes }`; server computes `LabourAmount`/`FinalAmount` from the rate snapshot + approved adjustments and shows tradie the total before submit.
  - [ ] Homeowner sees an itemised summary (labour, each approved adjustment, total vs estimate) and chooses **Approve & pay** or **Dispute amount** (→ existing dispute flow).
  - [ ] Cannot approve while any adjustment is `Pending`.
  - [ ] If `FinalAmount` exceeds `EstimatedTotal` by more than a configurable tolerance (default 15%, per Consumer NZ estimate guidance) the homeowner sees a clear "higher than estimate" banner with the reason.

### P12-12: Auto-approve & overdue-payment policy
- **Platform:** Backend
- **References:** `Jobs/AutoCompleteJob.cs`, `Jobs/PaymentExpiryJob.cs`, `Jobs/PaymentSlaJob.cs`, `Services/AccountFlagService.cs`
- **Acceptance Criteria:**
  - [ ] The 48h auto-complete becomes **auto-approve**, and only when there are no pending adjustments **and** `FinalAmount ≤ EstimatedTotal × (1 + tolerance)` (or no estimate was given and amount ≤ a configured cap). Otherwise it escalates to staff instead of silently approving a higher bill.
  - [ ] `PaymentExpiryJob` **no longer cancels** (work is done). Overdue payment sends reminders (24h/72h), then flags the homeowner account and notifies staff. Window reuses `PaymentOptions.WindowHours` (default 72h).
  - [ ] Add `OverduePayment` to `Enums/AccountFlagType.cs` (current values: `RepeatCanceller`, `RepeatNoShow`, `Abuse`, `Manual`, `LowRating`) and raise it via `AccountFlagService`. A homeowner with this flag cannot post or request new jobs until the payment is verified.

> **D1 (resolved 2026-11-16):** no deposit/hold mechanism in Phase 12 — manual bank-transfer deposits would double admin verification per job; revisit only once an automated payment gateway (BNZ/Stripe) exists.

### P12-13: Payment & payout on FinalAmount
- **Platform:** Backend
- **References:** `Services/Payment/PaymentService.cs` (lines ~304, ~317), `Services/Payout/PayoutService.cs`
- **Acceptance Criteria:**
  - [ ] `Payment.Amount` = `Job.FinalAmount`; instructions/ref code unchanged.
  - [ ] `PaymentReview→Completed` triggers `CreatePayoutAsync` (hook moves from the old confirm path); `GrossAmount = FinalAmount`.
  - [ ] Commission base is configurable: `PayoutOptions:CommissionAppliesTo = LabourOnly | LabourAndAdjustments` (D5 resolved: **`LabourOnly`** is the default; the toggle stays in config).
  - [ ] Receipt hash / re-upload / SLA behaviour (P4, P10-16) unchanged.

### P12-14: Cancellation, no-show & refund rework
- **Platform:** Backend
- **References:** `JobStatusService.cs` (~299–410, ~441, ~665–735), `Models/Refund`, `docs/specs/v1.2/P6-*`, `P7-*`
- **Acceptance Criteria:**
  - [ ] Pre-completion cancellations create **no refund** (nothing was paid).
  - [ ] Existing monetary penalties/partial refunds (e.g. 50% on tradie no-show) are replaced by non-monetary consequences only: strike/cancellation counters, `RepeatCanceller`/`RepeatNoShow` account flags, temporary suspension, visible reliability score (D4 resolved: invoiced cancellation fees are ruled out for Phase 12 — no enforcement without a card on file).
  - [ ] Refund path remains only for post-payment disputes resolved in the homeowner's favour.
  - [ ] No orphaned `Refund` rows for in-flight legacy jobs (see P12-27).

### P12-15: Mobile status/stepper/copy
- **Platform:** Mobile
- **References:** `views/widgets/job_progress.dart`, `job_progress_dots.dart`, `job_status_presentation.dart`, `job_timeline.dart`, `views/payment/payment_screen.dart`, `payment_status_screen.dart`, `models/marketplace.dart` (`stage` 0..5)
- **Acceptance Criteria:**
  - [ ] Stepper order: Requested → Booked → In progress → Review & approve → Pay → Completed.
  - [ ] Job cards show "$XX/hr · total confirmed on completion" (or "est. $YYY") instead of a fixed total.
  - [ ] Payment screen is reached from "Approve & pay", not from a job card in the first state (`job_navigation.dart` `openHomeownerJob` rewired).
  - [ ] Disclaimer copy (P10-22) updated: materials are added in-app and need your approval.

### P12-16: Admin web
- **Platform:** Web
- **References:** `web/src/features/payments/*`, payout queue
- **Acceptance Criteria:**
  - [ ] Payment queue row shows job title, itemised amount and "work completed on <date>".
  - [ ] Verify action → job `Completed` + payout `Pending` (copy updated; no longer "Booked").
  - [ ] Overdue-payment view (jobs in `AwaitingPayment` past due) for staff follow-up.

---

## 8. Workstream D — On-demand price adjustments

### P12-17: `JobPriceAdjustment` entity & endpoints
- **Platform:** Backend
- **References:** new `Models/JobPriceAdjustment.cs`, `Controllers/JobsController.cs` (or new `AdjustmentsController`), `Validators/`
- **Acceptance Criteria:**
  - [ ] Fields: `Id, JobId, ProposedByTradieId, Kind (Materials | ExtraLabour | Travel | Other), Description (≤500), Amount decimal(18,2) > 0, EvidenceFileKey?, Status (Pending | Approved | Declined | Withdrawn | Expired), CreatedAtUtc, RespondedAtUtc?, ResponseNote?`.
  - [ ] `POST /api/jobs/{id}/adjustments` (Tradie, job `Booked`/`InProgress`/`AwaitingConfirmation`).
  - [ ] `POST /api/jobs/{id}/adjustments/{adjId}/respond` `{ approve, note? }` (owning homeowner).
  - [ ] `POST …/withdraw` (proposing tradie while `Pending`). `GET /api/jobs/{id}/adjustments`.
  - [ ] Only **Approved** adjustments count toward `AdjustmentsTotal`. A tradie cannot invoice an unapproved extra (aligns with business.govt.nz/Consumer Protection guidance).
  - [ ] Evidence (receipt/photo) stored in a private blob container like `fixo-payments`; encouraged (not required) for `Materials`.
  - [ ] Every proposal/decision recorded in `JobStatusHistory`/audit log (this is the "in writing" record).

### P12-18: Realtime, push & expiry
- **Platform:** Backend
- **References:** `Hubs/JobHub.cs`, `Services/PushNotificationService.cs`, Hangfire
- **Acceptance Criteria:**
  - [ ] SignalR event `JobAdjustmentChanged` + FCM push to the homeowner on new proposal, and to the tradie on decision.
  - [ ] Pending adjustments `Expire` after a configurable window (default 48h) with a reminder at 24h.
  - [ ] Config guard: max N pending adjustments per job; per-adjustment cap triggers staff review above a threshold.

### P12-19: Tradie UI — "Request extra cost"
- **Platform:** Mobile
- **References:** `views/tradie/tradie_job_detail_screen.dart`
- **Acceptance Criteria:**
  - [ ] Action visible during `Booked`/`InProgress`/`AwaitingConfirmation`: pick kind, amount, description, attach receipt/photo.
  - [ ] Shows status of each request (pending/approved/declined) and running total.
  - [ ] If declined: tradie may continue original scope or cancel with a new no-penalty reason `scope_change_declined`.

### P12-20: Homeowner UI — approve / decline
- **Platform:** Mobile
- **References:** `views/homeowner/homeowner_job_detail_screen.dart`, new bottom sheet
- **Acceptance Criteria:**
  - [ ] Push deep-links to a sheet: what, how much, receipt, running total vs estimate, **Approve / Decline (+ note)**.
  - [ ] Job detail shows an "Adjustments" section with history.
  - Pre-approved materials allowance ("pre-approve up to $___") is **cut from Phase 12** (D6): explicit one-tap Approve/Decline is the only path — auto-approval caps invite disputes over receipt validity.

---

## 9. Workstream E — Project-based jobs (same Post Job screen)

**Principle:** one Post Job screen, one `Job` table, one lifecycle. A **Job type** control at the top (`Quick job (hourly)` | `Project`) reveals extra sections. Hourly jobs never see project fields.

### P12-21: Job type + project fields (backend)
- **Platform:** Backend
- **References:** `Models/Job.cs`, DTOs, validators
- **Acceptance Criteria:**
  - [ ] `JobType` enum (`Hourly`, `Project`), default `Hourly`.
  - [ ] Project-only optional fields: `BudgetMin/BudgetMax decimal?`, `MaterialsBy (Tradie | Homeowner | Undecided)`, `SiteVisitWelcome bool`, `DesiredStartBy/FinishBy` (reuses timing fields from P12-01), `ScopeNotes`.
  - [ ] Attachment limit for projects raised (config, default 10 files incl. PDFs) without changing the 5-photo cap for hourly jobs (P10-14).
  - [ ] Hourly validators unchanged; project validators don't require hours or rate.

### P12-22: Post Job — project section
- **Platform:** Mobile
- **References:** `post_job_screen.dart`, `PostJobState`
- **Acceptance Criteria:**
  - [ ] Segmented control at the top; shared sections (service, address, title, description, photos, timing) are identical for both types.
  - [ ] Project adds: budget range (optional), materials responsibility, "site visit welcome", extra attachments. Timing defaults to **Flexible**.
  - [ ] Helper copy explains the difference ("Quick job = hourly rate, pay when done. Project = tradies send you a quote").
  - [ ] Submit goes to the same Choose-a-Tradie screen.

### P12-23: Quote requests & `Quote` entity
- **Platform:** Backend
- **References:** `Models/JobOffer.cs`, `OffersController.cs`, new `Models/Quote.cs`
- **Acceptance Criteria:**
  - [ ] `JobOffer.Kind` (`Instant`, `QuoteRequest`). For projects the homeowner may request quotes from **up to 3 tradies concurrently** (mirrors Builderscrack's cap); instant jobs stay single-pending.
  - [ ] Quote fields: `PricingModel (Fixed | EstimateRange | HourlyWithCap)`, `Amount` or `Min/Max`, `Cap?`, `Inclusions`, `Exclusions`, `MaterialsIncluded bool`, `GstIncluded bool`, `ProposedStartUtc?`, `EstimatedDurationDays?`, `ValidUntilUtc`, `Status (Submitted | Accepted | Declined | Withdrawn | Expired)`.
  - [ ] D8: quote prices are final consumer prices — GST-inclusive when the tradie is `IsGstRegistered` (`GstIncluded` required `true` for registered tradies; unregistered tradies cannot charge GST).
  - [ ] Quote window configurable (default 72h). Accepting one quote declines the others and moves the job to `Booked` with the agreed `PricingModel` snapshotted on the job.
  - [ ] `FinalAmount` for `Fixed` = agreed price + approved adjustments; for `EstimateRange` / `HourlyWithCap` = actual, validated against the range/cap (above cap requires an approved adjustment).

### P12-24: Quote UIs
- **Platform:** Mobile
- **References:** `views/tradie/request_detail_screen.dart`, new `views/jobs/quotes_screen.dart`
- **Acceptance Criteria:**
  - [ ] Tradie: project request detail has a **Submit quote** form (fields above) instead of a one-tap accept.
  - [ ] Homeowner: `/jobs/:id/quotes` compares quotes side by side (price, inclusions, start date, rating) with profile links; **Accept quote**.
  - [ ] Quote prices display with the GST label (D8): "Incl. GST" / "No GST charged".
  - [ ] Payment still happens at completion (same flow as §4.2).

### P12-25: Large-job guardrails (NZ context)
- **Platform:** Backend + Mobile
- **Acceptance Criteria:**
  - [ ] When an accepted quote/estimate is **≥ NZD 30,000 incl. GST**, show a notice that a written contract is required for residential building work (Building Act s362F per building.govt.nz) and require the homeowner to confirm one exists (or attach it) before the job moves to `Booked`.
  - [ ] Threshold is configuration, not code.
  - [ ] **Legal review before enabling projects in production** — this plan's NZ-law references come from government guidance pages and are not legal advice.

### P12-26 (deferred / Phase C2): Milestone payments
- **Platform:** Backend + Mobile + Web
- **Rationale:** NZ implied terms default to monthly progress payments; large projects realistically need staged payment. `PRD.md` already lists milestone payments as a goal.
- **Acceptance Criteria:**
  - [ ] Quote may include milestones (`Title, Amount, DueOn`). Tradie marks a milestone done → homeowner approves → pays via the same receipt/verify flow → per-milestone payout.
  - [ ] Final milestone closes the job → `Completed`.
  - **Deferred (D2 resolved 2026-11-16) — not in Phase 12.** Projects ship with payment-at-completion only; interim staging via progress terms in the quote or sequential jobs.

---

## 10. Workstream F — Rollout & quality

### P12-27: Back-compat for in-flight jobs & feature flag
- **Platform:** Backend
- **Acceptance Criteria:**
  - [ ] Feature flag `JobFlow:Version = 1 | 2` (default 1 until QA passes).
  - [ ] Jobs already in `AwaitingPayment`/`PaymentReview`/`Booked` under the old model finish under the old rules (flag stored on the job, not just globally).
  - [ ] Migration dry-run on a copy of the dev DB; no orphaned payments/refunds/payouts.

### P12-28: Tests & docs
- **Acceptance Criteria:**
  - [ ] Backend: unit tests for every transition in §4.2; money-math tests (rounding, adjustments, cap/tolerance); auto-approve edge cases.
  - [ ] Mobile: widget tests for Post Job (hourly/project), tradie list, adjustment sheet; update `mobile/integration_test/job_request_test.dart`, `job_lifecycle_test.dart`, `payment_test.dart`.
  - [ ] New smoke script `scripts/p12-smoke.sh` (post → pick → accept → in-progress → adjust → complete → approve → pay → verify → payout).
  - [ ] Update `MVP-SPEC` (supersede A5, B1), P4/P5/P6 notes, QA guide (`QA-14-p12-*.md`), README.

---

## 11. Risks & decisions — D1–D8 resolved 2026-11-16

All eight open decisions were resolved by the owner on 2026-11-16 (recommendation set reviewed and adopted). The resolutions below are binding for Phase 12; R1–R2 remain tracked risks.

| ID | Decision / risk | Resolution (owner, 2026-11-16) |
|---|---|---|
| **D1** | **Non-payment risk.** Pay-at-end leaves tradies exposed (Airtasker avoids this with escrow at assignment). Also weakens the platform's control against off-platform deals, which the repo noted as why Builderscrack dropped success fees. | **Approve the plan's safeguards; defer deposits.** Pay-at-end stays, payment stays platform-mediated (transfer → verify → payout), payout withheld until verified, overdue flags + posting block (P12-12). No manual bank-transfer deposits — they would double admin verification per job. Revisit deposits/holds only once an automated gateway (BNZ/Stripe) exists. |
| **D2** | Milestone payments for projects now or later? | **Defer — P12-26 is not in Phase 12.** Ship projects with pay-at-completion first. |
| **D3** | Contacting a tradie **before** they accept. Chat is gated today (P5-08). | **Request + optional initial message only; no pre-booking chat.** The `JobOffer.Message` (P12-01/P12-08) is the only pre-acceptance channel; chat stays gated to `Booked`+ (P5-08 unchanged). *Supersedes the earlier "limited enquiry thread" recommendation.* A tightly-scoped, moderated Q&A thread for Project `QuoteRequest` offers may be revisited post-v1.7. |
| **D4** | With no upfront payment, cancellation/no-show penalties can't be netted from a refund. | **Non-monetary consequences only.** Strike/cancellation counters, `RepeatCanceller`/`RepeatNoShow` flags, temporary suspension, visible reliability score. Invoiced cancellation fees are ruled out — no enforcement mechanism without a card on file. |
| **D5** | Does the platform commission apply to materials/pass-through adjustments? | **`LabourOnly` by default**; keep the `LabourAndAdjustments` toggle in config. |
| **D6** | Pre-approved materials allowance at posting. | **Cut from Phase 12.** One-tap push approval (P12-18/P12-20) is fast enough; auto-approval caps invite disputes over receipt validity. |
| **D7** | Parallel requests for **hourly** jobs (shortlist 3, first to accept wins)? | **Keep single pending request.** Avoids accept-race frustration for tradies. Add a tight, urgency-aware offer expiry (configurable, e.g. 15–30 min ASAP, 2–4 h flexible). Revisit after launch data. |
| **D8** | GST: show prices incl. or excl. GST; tradies not GST-registered? | **Final consumer pricing + registration flag.** (1) `IsGstRegistered` bool on the tradie profile — introduced with P12-05, surfaced in P12-05/P12-07/P12-23, labelled in P12-06/P12-24. (2) All homeowner-facing prices are final — GST-inclusive where the tradie is registered (Fair Trading Act: no "$80/hr + GST" surprises at checkout). (3) Labels: "Incl. GST" (registered) / "No GST charged" (unregistered — NZ businesses under $60k turnover need not register and legally cannot charge GST). |
| **R1** | Large behavioural change to the state machine touches payments, payouts, refunds, reminders, jobs, stepper. | Mitigation (risk stands): feature flag + staged rollout (P12-27); do P12-10→P12-15 as one reviewed increment. |
| **R2** | Legal accuracy of NZ-law guidance. | Mitigation (risk stands): legal review before enabling projects; these are summaries of government pages. |

### Resolution rationale (owner review, 2026-11-16)

- **D1** — Deposits on a manual bank-transfer stack a second receipt-verification on staff for every job. Overdue flag + posting block is the right friction level until a gateway automates payments.
- **D2** — P12-10 already inverts the core state machine; partial payouts, partial disputes and multi-invoice tracking in the same release risks delaying the launch. Interim staging: progress terms in the quote, or split large work into sequential jobs.
- **D3** — Free-form pre-acceptance chat is the #1 contact-swap/leakage channel and an unmoderated spam surface; the optional request message covers clarification. Possible future exception, tightly scoped: a Q&A thread only on Project `QuoteRequest` offers, with moderation blocking phone numbers/emails.
- **D4** — An invoiced fee has no enforcement without a card on file or debt collection; chasing a $50 transfer from an angry user costs more in support time than it recovers.
- **D5** — Commission on a pass-through $400 hardware receipt makes the tradie lose money on materials and pushes them to "just pay me cash for the parts". Commission stays on labour (and quote base amounts).
- **D6** — A "$150 allowance" invites $149-no-scrutiny adjustments and post-job disputes. Tradies are on-site with their phones and homeowners get a push (P12-18); explicit one-tap approval is safer and cleaner.
- **D7** — Builderscrack's "up to 3" serves quotes gathered over days. Simultaneous hourly offers mean two tradies accept 10 seconds apart and one loses — bad UX on both sides.
- **D8** — NZ Fair Trading Act: consumer-facing prices must be GST-inclusive. Businesses earning under $60k/year need not register for GST and legally cannot charge it, so the `IsGstRegistered` flag (not a per-price choice) drives labelling and quote validation.

---

## 12. Suggested build order

1. **P12-01 → 03** (data model, null-safe schedule) — foundation, no UX change yet.
2. **P12-10 → 16** (pay-at-completion) behind the flag — highest risk, build and test first end-to-end.
3. **P12-04 → 09** (Post Job simplification, tradie list, profile, direct request) — fixes the "chosen tradie is ignored" bug.
4. **P12-17 → 20** (price adjustments).
5. **P12-21 → 25** (project jobs). **P12-26** (milestones) is deferred — not in Phase 12 (D2).
6. **P12-27 → 28** throughout; flip the flag after QA.

---

## 13. Sources

- Builderscrack — How it works: https://builderscrack.co.nz/how-it-works
- Airtasker — Pricing and payments: https://support.airtasker.com/hc/en-au/articles/360020792111-What-are-the-things-I-need-to-know-about-pricing-and-payments
- Consumer Protection NZ — Quotes and estimates: https://www.consumerprotection.govt.nz/general-help/guide-to-buying-smart/quotes-and-estimates
- business.govt.nz — Variations to contracts: https://business.govt.nz/risks-and-operations/tradies/variations-to-contracts
- building.govt.nz — Implied contract terms: https://building.govt.nz/projects-and-consents/why-contracts-are-valuable/implied-contract-terms
- building.govt.nz — Construction Contracts Act 2002 (other requirements): https://building.govt.nz/projects-and-consents/why-contracts-are-valuable/construction-contracts-act-2002/other-requirements
- Consumer NZ — Choosing tradies and builders: https://consumer.org.nz/home-and-living/building-and-renovation/renovation-guide-3-choosing-tradies
- Master Plumbers NZ — Set yourself up for success: https://www.masterplumbers.org.nz/homeowner-info/tips-and-advice/set-yourself-up-for-success/