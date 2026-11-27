# TradieHunter — Specifications (current state, through v1.7)

> The single functional and technical spec. It describes what the system **does now**, with the v1.7 flow marked where it differs from flow version 1 (legacy). Stack and infrastructure are in [ARCHITECTURE.md](ARCHITECTURE.md); scope in [MVP.md](MVP.md).
>
> **Development rules (all code):** money is `decimal(18,2)`, never float · timestamps are UTC in storage and on the wire, localised on the client · spatial queries use EF Core LINQ + NetTopologySuite, never raw PostGIS SQL · every job status change goes through `IJobStatusService` (history + SignalR) · backend `dotnet` runs inside the `api` container · enums are stored as strings via `HasConversion`.

## 1. Roles and authentication

| Role | Notes |
|---|---|
| Homeowner, Tradie | Self-registration. `RegisterRequestValidator` accepts only these two. |
| Staff, Superadmin | Created only via invite (`POST /api/admin/staff/invite`, Superadmin only; 24 h token). There is no `Admin` role. |

- **Registration:** email + password → 6-digit OTP email → verified. Google login returns `RequiresRegistration` + a one-time `registrationToken` that `completeRegistration` must present (expired/reused → 400).
- **Tokens:** short-lived JWT (HS256 pinned, `alg:none` rejected, 30 s clock skew, `MapInboundClaims=false`), refresh tokens stored hashed (SHA-256), 30-day expiry, rotation endpoint and `DELETE /api/auth/refresh` on logout. Secret comes from config and the API refuses to start without it.
- **Lockout:** Identity lockout enabled; locked accounts get HTTP 429.
- **Web admin:** httpOnly `AdminCookie` scheme (`admin-login`, `admin-logout`, `admin-me`), SameSite=Strict, custom-header CSRF check, CSP, credentialed CORS for admin origins only. No tokens in `localStorage`.
- **Hangfire dashboard** (`/hangfire`) requires an authenticated Superadmin in every environment.
- **Android:** cleartext traffic allowed only in the debug network-security config.

## 2. Data model

Core tables (decimal columns are `(18,2)`):

| Table | Key fields |
|---|---|
| `users` (Identity) | email, phone, role, OTP verified, `IsActive`, `EmailBouncedAtUtc` |
| `tradie_profiles` | base address + geo point (GiST index), service radius, verification status, cancel/no-show counters, `IsVerified`, `IsAvailable`, `HasInsurance`, `IsGstRegistered`, bank account name/number (encrypted) + `BankAccountVerified` |
| `tradie_credentials` | type (Licence, Insurance, …), file key, status, reviewer, `LicenceBoard` |
| `tradie_schedules` | weekday, start, end |
| `services` | name, category, `RequiresLicence`, `LicenceBoard` (EWRB / PGDB / LBP) |
| `tradie_rates` | tradie, service, hourly rate, currency (one per service) |
| `jobs` | homeowner, service, title, description, photos, urgency, location, status, assigned tradie, `ReferenceCode`, `StartedAtUtc/EndedAtUtc`; **v1.7:** `JobType` (Hourly/Project), `TimingPreference`, `ScheduledStartUtc?`, `ScheduledEndUtc?`, `EstimatedHours?`, `EstimatedTotal?`, `HourlyRate` (snapshot at request), `FinalHours?`, `LabourAmount`, `AdjustmentsTotal`, `FinalAmount`, `CompletionSubmittedAtUtc`, flow version, project fields (`BudgetMin/Max`, `MaterialsBy`, `SiteVisitWelcome`, `ScopeNotes`), agreed `PricingModel`. **Job DTO quote progress (plan 10):** `QuotesRequested?` / `QuotesReceived?`, set only for the homeowner of a Project job in `Requested` (requested = QuoteRequest offers `Pending`/`Accepted`; received = `Accepted` quote + `Submitted` quotes not past `ValidUntilUtc`), otherwise null. **Open board (plan 10 Q7):** `OpenToBoard` (bool, default false = invite-only) and `QuotesCloseAtUtc?` stamped at posting from the admin setting `Quotes.BoardWindowHours` (later changes never alter existing jobs); the create request takes `openToBoard?` (project only; absent = false) |
| `PlatformSettings` (plan 10 Q7.1) | key (PK, e.g. `Quotes.BoardWindowHours`, `Quotes.ValidityHours`), value (string), `UpdatedAtUtc`, `UpdatedByUserId`. Admin-editable; a missing or unusable row falls back to `JobFlow:QuoteBoardWindowHours` / `JobFlow:QuoteWindowHours` (both 72). Hours are 1-720. `GET /api/admin/settings/quotes` (staff), `PUT` (Superadmin, audited as `settings.quotes.update`); web: Settings > Quotes |
| `job_offers` | job, tradie, offered/expires, response (Pending/Accepted/Declined/TimedOut), stage (Auto/Broadened), Hangfire id; **v1.7:** `HourlyRateSnapshot`, `Message?`, `Kind` (Instant/QuoteRequest) |
| `quotes` (v1.7) | offer, pricing model (Fixed/EstimateRange/HourlyWithCap), amount or min/max, cap, inclusions/exclusions, materials/GST flags, proposed start, duration, valid-until, status |
| `job_price_adjustments` (v1.7) | job, proposing tradie, kind (Materials/ExtraLabour/Travel/Other), description ≤500, amount > 0, evidence key, status (Pending/Approved/Declined/Withdrawn/Expired), response note |
| `job_status_history` | from, to, actor id + role, reason code, note, timestamp |
| `payments` | job, amount, provider, provider reference, status (pending/submitted/verified/rejected), receipt key, **unique** receipt SHA-256, verifier, reject reason |
| `refunds` | job, payment, amount, penalty, hours-worked amount, status (none/pending/processed), processor, transfer reference, proof key |
| `tradie_payouts` / `payout_batches` | gross, commission %, commission, net, status (Pending/Scheduled/Processed/Failed), batch, transfer reference; **unique index on JobId** |
| `disputes`, `dispute_evidence` | opener, status, outcome, decider, note; evidence file or text |
| `reviews` | job, from, to, stars 1–5, comment, status, `VisibleAfterUtc` |
| `account_flags` | user, type (RepeatCanceller, RepeatNoShow, Abuse, Manual, LowRating, **OverduePayment** v1.7), counter, threshold hit, resolved, note |
| `user_blocks`, `audit_logs`, `messages`, `device_tokens`, `refresh_tokens` | as named; audit log stores old/new JSON and IP |

Reason codes: `homeowner_changed_mind`, `tradie_unavailable`, `tradie_no_show`, `homeowner_no_show`, `scope_change_declined` (no penalty, v1.7), `homeowner_issue`, `tradie_issue`, `emergency`, `no_tradie_found`, `no_payment`, `system_failure`, `dispute_outcome`. Cancellations store `cancelled_by` (homeowner / tradie / admin / system) plus a reason code. Flags attach to users, not jobs.

## 3. Matching and offers

1. Candidates: verified, available, not blocked, serving the service within radius (default 25 km, max 50), holding an Approved credential of the right licence board when the service `RequiresLicence`.
2. Score (spatial LINQ): distance, rating, schedule fit. With no scheduled time (v1.7) the schedule weight is redistributed to distance and rating.
3. **Quick match / legacy:** create a `JobOffer` for the top candidate, push (FCM) + SignalR, Hangfire `OfferTimeoutJob`; on decline/timeout offer the next; after the strict list is exhausted a **Broadened** stage widens the radius; when all are exhausted the job is `Cancelled` with `no_tradie_found`.
4. **Direct request (v1.7):** `POST /api/jobs/{id}/request {tradieId, message?}` creates an offer for exactly that tradie, snapshotting their rate. One pending request per hourly job (409 otherwise). Decline/timeout leaves the job `Requested` and returns the homeowner to the list (no auto-broaden). Expiry is urgency-aware and configurable (about 15–30 min for ASAP, 2–4 h for flexible). The optional message is the only contact before `Booked`.
5. Tradie list: `GET /api/jobs/{id}/matches` returns id, name, badges (verified, insured), rating + count, distance, availability, the **final consumer rate** for the job's service, completed jobs, `IsGstRegistered`; sort `best|rating|distance|rate`, filters `verified|insured|availableNow`.
6. **Open project board (plan 10 Q7):** Project jobs only (`OpenToBoard = true` by default; `Hourly` stays off the board). `GET /api/tradie/available-jobs` returns paged open projects matching the tradie's offered services, radius, licence board, non-blocked, not yet quoted, and before `QuotesCloseAtUtc`. Full project details are shown (scope, notes, budget range, materials-by, site-visit-welcome, timing, photos, suburb, distance); **privacy rule:** exact street address and homeowner contact remain masked to suburb until `Booked`. Tradies submit quotes via `POST /api/jobs/{id}/quotes` without an offer (`OfferId = null`), valid for `Quotes.ValidityHours` (default 72 h, DB-backed in `PlatformSettings`). When `QuotesCloseAtUtc` passes with no valid quote remaining, `ExpirationWorker` transitions `(Requested, Expired)` and notifies the homeowner.

## 4. Job state machine

Statuses (unchanged enum): `Requested`, `AwaitingPayment`, `PaymentReview`, `Booked`, `InProgress`, `AwaitingConfirmation`, `Completed`, `Cancelled`, `Expired`, `Disputed`.

### Flow version 2 (v1.7, pay at completion)

| From → To | Actor | Guard |
|---|---|---|
| Requested → Booked | Tradie | Accepts before offer expiry; rate snapshot copied to job; ≥ NZD 30k quote requires contract confirmation |
| Booked → InProgress | Tradie | Check-in (any time when no start time exists) |
| InProgress → AwaitingConfirmation | Tradie | Check-out with `finalHours`; server computes labour + approved adjustments |
| AwaitingConfirmation → AwaitingPayment | Homeowner | **Approve & pay**; blocked while any adjustment is Pending. Or system auto-approve after 48 h only if no pending adjustments and within tolerance |
| AwaitingConfirmation → Disputed | Homeowner | Disputes the amount |
| AwaitingPayment → PaymentReview | Homeowner | Receipt uploaded |
| PaymentReview → Completed | Staff/Superadmin | Receipt verified; payout created `Pending` |
| PaymentReview → AwaitingPayment | Staff/Superadmin | Receipt rejected with reason |
| Any pre-Completed → Cancelled | Homeowner / Tradie / Admin / System | Reason code; no refund (nothing paid) |
| Any active → Disputed | Either party | Evidence opens |
| Disputed → Completed / Cancelled | Admin | Outcome recorded |

Removed in v2: `Requested→AwaitingPayment`, `PaymentReview→Booked`, `AwaitingConfirmation→Completed`, and expiry of `AwaitingPayment`/`PaymentReview`. `Completed` now means *work approved and paid*.

### Flow version 1 (legacy, in-flight jobs only)

`Requested → AwaitingPayment (tradie accepts) → PaymentReview (receipt) → Booked (verified) → InProgress → AwaitingConfirmation → Completed (confirm or auto-complete)`. Unpaid jobs expire after the payment window (`Expired`, tradie released). The flow version is **stamped on the job at creation**, so flipping the flag never changes in-flight jobs.

Every transition writes `JobStatusHistory` and publishes SignalR `JobStatusChanged`; all three must happen or it is a bug.

## 5. Money

```
LabourAmount  = FinalHours × HourlyRate (snapshot at request)
FinalAmount   = LabourAmount + Σ APPROVED adjustments        ← what the homeowner pays
Payment.Amount = FinalAmount;  Payout.Gross = FinalAmount
Commission    = CommissionPercent × (LabourAmount | LabourAmount + adjustments)  // PayoutOptions:CommissionAppliesTo, default LabourOnly
Net           = Gross − Commission
```

- Fixed quotes: final = agreed price + approved adjustments. EstimateRange / HourlyWithCap are validated against range/cap; above-cap needs an approved adjustment.
- "Higher than estimate" banner when `FinalAmount > EstimatedTotal × (1 + tolerance)` (default 15%).
- Legacy refund suggestion: `paid − penalty − (rate × hours worked)`, editable by admin. Legacy homeowner pre-work cancellation carries a 10% flat penalty. v2 has no pre-completion refunds; a refund exists only for a post-payment dispute resolved for the homeowner.
- Commission is visible to tradies only. Historical payout snapshots take precedence over current config.

## 6. Payments, payouts, refunds

- **Manual payment:** `IPaymentProvider` (`ManualReceiptProvider` only; `ProcessRefundAsync` throws because a human reverses a bank transfer). `IPaymentService` handles instructions, receipt hashing/storage, duplicate detection, the staff queue and status transitions.
- Bank details, account name and reference format come from `PaymentOptions`, never hard-coded. Missing or sentinel details show a "contact support" state, not a transferable placeholder. A unique reference code per job goes in the transfer reference.
- One `Payment` row per job, reused across re-uploads; receipt SHA-256 is unique-indexed so one bank confirmation cannot back two payments.
- **Staff queue:** shows expected amount beside the receipt and age since submission: amber over 15 min, red over 30 min, Hangfire escalation after 30 min (`PaymentSlaJob`).
- **Overdue payment (v2):** `PaymentExpiryJob` no longer cancels. Reminders at 24 h and 72 h, then the homeowner gets an `OverduePayment` flag and staff are notified. A flagged homeowner cannot post or request jobs until the payment is verified.
- **Payouts:** created when a job reaches `Completed` (v2: on verify). Weekly `PayoutBatchJob` (default Monday 02:00 UTC, `0 2 * * 1`) groups `Pending` payouts into a batch (`Scheduled`); admin transfers manually and marks each `Processed` with a reference; the tradie is pushed. Processing is disabled when bank details are missing. Financial records are never purged.
- **Refunds (legacy and disputes):** admin queue `GET /api/admin/refunds/pending`, `POST /api/admin/refunds/{id}/process` (multipart proof); homeowner is pushed the amount and reference.
- **Tradie earnings** (`GET /api/tradie/earnings`): server-computed decimals for the Pacific/Auckland Monday-start week: earned net, processed net, pending, failed. Gross bookings are never labelled as paid.

## 7. Job execution

- **Address privacy:** the assigned tradie sees suburb/city only until `Booked`; exact address and phone appear from `Booked`.
- **Chat:** job-scoped, unlocked at `Booked` and after; readable by staff during disputes. Quick replies for tradies ("On my way", "Running late").
- **Check-in/out:** tradie only; timestamps recorded for hours worked. Check-out in v2 includes final hours and notes; a reference duration is shown.
- **Reminders:** Hangfire pre-job reminder only when a start time exists.
- **Auto-approve (v2):** 48 h after check-out, only with no pending adjustments and amount within tolerance (or under a configured cap when no estimate was given); otherwise escalate to staff. Legacy auto-complete uses `AutoCompleteWindowHours`.
- **Editing:** no `PUT /api/jobs/{id}` once an offer exists.

## 8. Reviews, disputes, flags, safety

- **Reviews:** both parties, 1–5 stars + optional comment. Hidden until both submit or 7 days after completion (`RevealReviewsJob` flips visibility and notifies). Homeowner aggregate is visible to tradies on job detail only. Zero reviews renders "New to TradieHunter", never 0.0.
- **Low rating:** average below 3.0 after at least 3 reviews creates a `LowRating` flag; admins decide.
- **Disputes:** either party opens with reason, details and evidence (private blobs). Admin sees chat and evidence, resolves to Completed or Cancelled with outcome (full / partial / none). No automated resolution.
- **No-shows:** homeowner reporting a tradie no-show may reassign or cancel (legacy: full refund); tradie reporting a homeowner no-show after the grace period cancels the job (legacy: partial refund). Both log flags.
- **Flags:** `AccountFlagService` increments counters and sets `ThresholdHit`; admin can warn, suspend or resolve. v2 replaces monetary penalties with counters, flags, suspension and a visible reliability score.
- **Report/block:** blocked users are excluded from matching; reports create `Abuse` flags.
- **Audit log:** admin actions (credential decisions, refunds, status overrides, suspensions) store old/new JSON.
- **Private storage:** credentials, receipts, evidence and proofs are never public; reads use short-lived SAS URLs (15 min).
- **Push with email fallback:** critical notifications always email; non-critical status/offer/quote/adjustment/receipt notifications fall back to email when push is unavailable or fails; time-sensitive reminders and review events are push-only. Staff alerts persist as `StaffNotification` rows (polled in the admin bell) and always email. Source of truth: `backend/Services/Notifications/NotificationPolicy.cs`.
  - **Accepted non-goals (MVP):** account deactivation is email-only (user is locked out); chat messages are push + SignalR only with no email fallback.

## 9. Admin web (React, Staff + Superadmin)

Dashboard (credential queue count, timing metrics shown as "—" when unavailable), users + flags, credential queue (approve/reject with reason), payment queue (SLA colours; v2 rows show itemised amount and completion date, plus overdue view), refund queue, payout queue + batch detail (masked bank details, process modal), disputes, audit/settings, job detail with progress stepper. Superadmin-only: staff invites, Hangfire.

## 10. Mobile UX contract (v1.5 → v1.6)

Single Flutter app, role-based. Source of visual truth is [DESIGN.md](DESIGN.md).

- **Four-stage homeowner presentation** mapped from server states (display only, never used for permissions): Requested (1/4), Booked (2/4), In progress (3/4), Done (4/4). Under v2 the stepper reads Requested → Booked → In progress → Review & approve → Pay → Completed. Cancelled/Expired/Disputed never appear as Done; unknown states show "Status unavailable".
- **Truthful trust and money:** badges only with server evidence; real name and photo or initials; amounts from snapshotted rate; no invented surcharge, estimate range, net/paid claim or escrow guarantee; "Receipt uploaded" is not "Payment verified"; materials/extras copy comes from config.
- **Leads:** price, distance, schedule and a countdown driven by server `expiresAtUtc` (never extended client-side); direct Accept/Decline share one command; stale/expired offers refresh with a clear outcome.
- **Components and rules:** control 16 px, card 20 px, sheet 32 px radii; 44 dp minimum tap targets, 54 dp buttons; one gold (`accent`) CTA per screen, sticky bottom action bar respecting safe area and keyboard, 1.0–2.0 text scale and 320 px width without clipping, light/dark themes by token swap, iPad master-detail ≥ 744 pt and rail ≥ 1024 pt.
- **Feedback:** all transient messages use `THNotice` (info/success/warning/error/push); no raw `SnackBar`. See [DESIGN.md](DESIGN.md#7-feedback-notices).
- **Address:** service → address search → coordinates hidden; editing the address invalidates prior coordinates and rate results.

## 11. v1.7 job-flow revision (Phase 12)

### Requested changes
Optional timing · total price decided at completion · on-demand price adjustments · tradie selection moves to its own screen · project jobs on the same Post Job screen · GST-inclusive consumer pricing.

### Decisions of record (owner, 2026-11-16)

| ID | Decision |
|---|---|
| D1 | Pay-at-end stays, platform-mediated; **no deposits** (manual deposits would double admin verification). Safeguards: payout withheld until verified, overdue flags, posting block. Revisit when a gateway exists. |
| D2 | Milestone payments **deferred** (P12-26 not in Phase 12). |
| D3 | Request + optional message only; **no pre-booking chat**. |
| D4 | Non-monetary cancellation consequences only. |
| D5 | Commission on labour only by default; `LabourAndAdjustments` toggle retained. |
| D6 | Pre-approved materials allowance **cut**; one-tap approve/decline only. |
| D7 | Single pending hourly request with urgency-aware expiry. |
| D8 | GST-inclusive final prices; `IsGstRegistered` flag; labels "Incl. GST" / "No GST charged" (NZ Fair Trading Act; sub-$60k businesses can't charge GST). |
| R1 | Risk: state-machine change touches payments, payouts, refunds, reminders, stepper → feature flag + staged rollout. |
| R2 | Risk: NZ-law summaries are from government guidance → legal review before projects go live. |

### What shipped (P12-01 … P12-28 except P12-26)

| Area | Behaviour |
|---|---|
| Data (01–03) | Migration `P12JobFlowV17` back-fills existing rows (`EstimatedTotal = TotalAmount`, `FinalAmount` for completed jobs). `CreateJobRequest` drops rate; hours and dates optional; `SpecificDate`/`DateRange` require future dates, `Flexible`/`Asap` must have none. Legacy `TotalAmount` is a deprecated alias of `FinalAmount ?? EstimatedTotal` for one release. All schedule consumers are null-safe ("date TBC"). |
| Post → browse → request (04–09) | Post Job drops the rate picker; submit goes to `/jobs/:id/tradies`. Profile route accepts `jobId` for in-context rate and sticky "Request this tradie". Request-sent screen shows who was asked, rate, countdown, Cancel, Pick someone else. The old behaviour where the chosen tradie was ignored (mobile sent only a rate) is fixed. |
| Payment at completion (10–16) | State machine rewired (§4); completion summary and approval; auto-approve and overdue policy; payment/payout on `FinalAmount`; cancellation rework; stepper/copy; admin web. |
| Adjustments (17–20) | Tradie `POST /api/jobs/{id}/adjustments` during Booked/InProgress/AwaitingConfirmation; owning homeowner `…/{adjId}/respond {approve, note?}`; tradie may `…/withdraw` while Pending; `GET` lists. Only Approved count. Every proposal/decision is audited ("in writing"). SignalR `JobAdjustmentChanged` + push; Pending expire after 48 h (reminder at 24 h); caps on pending count and per-adjustment amount trigger staff review. Declined → tradie continues original scope or cancels with `scope_change_declined`. |
| Projects (21–25) | `JobType` segmented control on the same Post Job screen; project fields; up to 10 attachments (config) vs 5 photos for hourly. Up to **3 concurrent quote requests**; quote window 72 h; accepting one declines the rest atomically and books with the pricing model snapshotted. GST rule enforced on quotes. Accepted quote ≥ NZD 30,000 incl. GST (config) shows the written-contract notice (Building Act s362F) and blocks booking until the homeowner confirms or attaches one. **Homeowner quote entry points (plan 10):** a Project job in `Requested` with at least one quote request sent shows a `Quotes` badge and "N of M quotes in" on the jobs list and home cards and opens `/jobs/:id/quotes` (no request sent yet: `/jobs/:id/tradies`); a received quote lifts the job into home "needs your attention" ("Review quotes" / Compare); the `quote_submitted` push (data `jobId`) opens that job's quotes screen, and a foreground one refreshes the jobs list and quotes. Counts absent (older server) fall back to the "Requested" copy. The quotes screen lists compact cards (`View quote` opens a detail sheet, `Accept` runs the same accept and written-contract path). The tradie quote builder is a bottom sheet (GST switch locked to the profile, hourly cap must be ≥ rate). |
| Rollout (27–28) | `JobFlow:Version = 1 | 2` (default 1), stamped per job. Tests: `JobFlowTransitionTests`, `JobMoneyTests`, `JobValidatorTests`; `scripts/p12-smoke.sh`; QA-14 ([QA.md](QA.md)). |

### NZ regulatory context used
Quote vs estimate (estimate should land within 10–15%; a quote can't rise without agreement), variations recorded and agreed before extra work, charge-up jobs pay for actual use, written contract for residential building work of NZD 30,000+, default monthly progress payments, Construction Contracts Act adjudication and Disputes Tribunal for disputes. Sources: Builderscrack, Airtasker, Consumer Protection NZ, business.govt.nz, building.govt.nz, Consumer NZ, Master Plumbers NZ. Not legal advice.

## 12. Configuration reference

| Section / key | Purpose |
|---|---|
| `Jwt:Secret` | Required; app fails fast if missing |
| `PaymentOptions` | `AccountName`, `AccountNumber`, `ReferenceFormat`, `WindowHours` (v2 overdue window 72 h), `PaymentsContainer` |
| `PayoutOptions` | `CommissionPercent` (12.5), `PayoutDay`, `MinimumPayoutAmount`, `PayoutBatchCron`, `CommissionAppliesTo` |
| `OfferTimeoutMinutes`, `AutoCompleteWindowHours` | Legacy offer and confirm windows (v2 adds urgency-aware offer expiry, 48 h auto-approve, 15% tolerance, contract threshold 30,000, quote window 72 h, adjustment expiry 48 h) |
| `JobFlow:Version` | 1 or 2 for newly created jobs |
| `Locale` | `DefaultCurrency`, `CurrencySymbol`, `PhoneCountryCode`, `DefaultTimezone`, `DistanceUnit`, `PilotRegion`, `Max/DefaultSearchRadiusKm`, `LegalEntityName/Country`, Terms/Privacy URLs, `materialsDisclaimer` (served by `GET /api/config/locale`) |
| `Brand` | `AppName`, `SupportEmail`, `SupportHoursDisplay`, `FrontendBaseUrl`, `EmailLogoUrl`, `PostalAddress` |
| `AzureBlob` | `ServiceUrl`, `ExternalServiceUrl`, account, containers `fixo-photos` / `fixo-credentials` / `fixo-payments` |
| `AddressResolution` | Provider, LINZ key (server only), layer id |
| `EmailSender` | See [OPERATIONS.md](OPERATIONS.md) |
| `RetentionPolicy` | Specified (financial 7 yrs, chat/photos 2 yrs, device tokens, inactive accounts) but **not implemented** |

## 13. Address resolution (LINZ)

`IAddressResolver` is the provider seam; `LinzAddressResolver` queries the LINZ WFS (new NZ Addresses layer, not the deprecated one). `GET /api/addresses/search?query=…` is authenticated, accepts 3–160 characters, returns up to 8 addresses with source attribution (CC BY 4.0, displayed with results), rate-limited to 30/min per user, 10 s upstream timeout, 1 MB limit, safe 503s. The LINZ key is server-only (`AddressResolution__Linz__ApiKey`), request logging is disabled because the key sits in the URL, redirects are off, and search text is sent to LINZ so the Privacy Policy must say so. Flutter talks only to the application API.

## 14. Deferred

See [MVP §5](MVP.md#5-explicitly-out-of-scope). Spec'd but unbuilt: **P11 data lifecycle** (purge jobs for chat, photos, stale device tokens; anonymise inactive accounts; log purges; ToS/Privacy links in app).
