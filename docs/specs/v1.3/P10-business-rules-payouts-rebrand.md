# Phase 10: Business Rules, Payouts & Rebrand

This phase resolves the gaps identified in the Client Clarification Questionnaire. It adds the commission/payout system, service catalog enhancements, blind reviews, tradie availability toggle, business rule enforcement, and the TradieFixo rebrand.

**Prerequisites:** All v1.2 phases (P0–P9) complete.

---

## P10-01: Backend — Commission & Payout Data Models

**Platform:** Backend
**Description:** Create EF Core entities for tradie payouts, payout batches, and commission configuration. Add bank details to tradie profiles.

**References:**
- `Models/TradieProfile.cs`
- `Data/FixoDbContext.cs`

**Acceptance Criteria:**
 - [x] Create `Models/TradiePayout.cs`: `Id` (Guid), `TradieId` (Guid FK→users), `JobId` (Guid FK→jobs), `GrossAmount` (decimal), `CommissionPercent` (decimal), `CommissionAmount` (decimal), `NetAmount` (decimal), `Status` (string: Pending, Scheduled, Processed, Failed), `PayoutBatchId` (Guid? FK→payout_batches), `BankAccountName` (string), `BankAccountNumber` (string), `TransferReference` (string?), `ProcessedBy` (Guid?), `ProcessedAtUtc` (DateTime?), `CreatedAtUtc` (DateTime).
 - [x] Create `Models/PayoutBatch.cs`: `Id` (Guid), `PeriodStartUtc` (DateTime), `PeriodEndUtc` (DateTime), `TotalAmount` (decimal), `PayoutCount` (int), `Status` (string: Open, Processing, Completed), `CreatedAtUtc` (DateTime), `CompletedAtUtc` (DateTime?).
 - [x] Create `Enums/PayoutStatus.cs` and `Enums/PayoutBatchStatus.cs`.
 - [x] Add to `TradieProfile`: `BankAccountName` (string?), `BankAccountNumber` (string?), `BankAccountVerified` (bool, default false), `IsAvailable` (bool, default true).
 - [x] Configure EF Core: decimal precision (18,2) for all money columns, unique index on `TradiePayout(JobId)`, index on `TradiePayout(Status)`, index on `PayoutBatch(Status)`.
 - [x] Generate and apply migration `AddPayoutsAndTradieAvailability`.

**Revises:**
- `Models/TradieProfile.cs`
- `Data/FixoDbContext.cs`

---

## P10-02: Backend — Payout Configuration

**Platform:** Backend
**Description:** Add `PayoutOptions` configuration section and bind it to a strongly-typed options class.

**References:**
- `appsettings.json`
- `Program.cs`

**Acceptance Criteria:**
 - [x] Add `PayoutOptions` section to `appsettings.json`: `CommissionPercent` (decimal, default 12.5), `PayoutDay` (string, default "Monday"), `MinimumPayoutAmount` (decimal, default 0), `PayoutBatchCron` (string, default "0 2 * * 1").
 - [x] Create `Options/PayoutOptions.cs` with matching properties.
 - [x] Bind via `services.Configure<PayoutOptions>(configuration.GetSection("PayoutOptions"))`.
 - [x] Expose `CommissionPercent` via `GET /api/config/locale` response (new field `commissionPercent`).

---

## P10-03: Backend — Payout Service

**Platform:** Backend
**Description:** Create `IPayoutService` to handle payout creation on job completion, weekly batch creation, and admin processing.

**References:**
- `Services/Payout/IPayoutService.cs` (new)
- `Services/Payout/PayoutService.cs` (new)

**Acceptance Criteria:**
 - [x] `CreatePayoutAsync(Job job)`: Called when job status transitions to `Completed`. Creates a `TradiePayout` with status `Pending`, calculating commission from `PayoutOptions.CommissionPercent × job.TotalAmount`. Copies tradie's current bank details from profile. Returns error if tradie has no bank details set.
 - [x] `CreateBatchAsync()`: Collects all `Pending` payouts, creates a `PayoutBatch` for the current period, sets payouts to `Scheduled` and links to batch. Returns batch summary.
 - [x] `ProcessPayoutAsync(Guid payoutId, string transferReference, Guid adminId)`: Sets payout to `Processed`, records `TransferReference`, `ProcessedBy`, `ProcessedAtUtc`. Sends push notification to tradie.
 - [x] `GetPendingPayoutsAsync(int page, int pageSize)`: Paginated list for admin queue.
 - [x] `GetBatchAsync(Guid batchId)`: Batch detail with associated payouts.
 - [x] Register in DI.

---

## P10-04: Backend — Payout Creation on Job Completion

**Platform:** Backend
**Description:** Hook payout creation into the job completion flow.

**References:**
- `Services/Jobs/JobStatusService.cs`
- `Services/Payout/PayoutService.cs`

**Revises:**
- `Services/Jobs/JobStatusService.cs`

**Acceptance Criteria:**
 - [x] When `JobStatusService` transitions a job to `Completed` (manual confirm or auto-complete), call `PayoutService.CreatePayoutAsync(job)`.
 - [x] If tradie has no bank details, log a warning and create the payout with status `Pending` (admin can process manually after tradie provides details).
 - [x] Include `CommissionAmount` and `NetAmount` in the push notification to the tradie on job completion (e.g., "Job completed! You'll receive $X.XX (after $Y.YY platform fee) in the next payout cycle.").

---

## P10-05: Backend — Weekly Payout Batch Hangfire Job

**Platform:** Backend
**Description:** Hangfire recurring job to create weekly payout batches.

**References:**
- `Jobs/PayoutBatchJob.cs` (new)

**Acceptance Criteria:**
 - [x] Register Hangfire recurring job using `PayoutOptions.PayoutBatchCron`.
 - [x] Job calls `PayoutService.CreateBatchAsync()`.
 - [x] If no pending payouts exist, job completes as no-op (no empty batch created).
 - [x] Send push notification to admin/staff when a new batch is created.

---

## P10-06: Backend — Admin Payout Endpoints

**Platform:** Backend
**Description:** Admin endpoints for managing payouts and batches.

**References:**
- `Controllers/AdminController.cs`

**Revises:**
- `Controllers/AdminController.cs`

**Acceptance Criteria:**
 - [x] `GET /api/admin/payouts/pending`: Paginated list of pending/scheduled payouts. Includes tradie name, job reference, gross, commission, net, bank details (last 4 digits only), status, age.
 - [x] `GET /api/admin/payouts/batches`: Paginated list of batches with summary stats.
 - [x] `GET /api/admin/payouts/batches/{id}`: Batch detail with individual payouts.
 - [x] `POST /api/admin/payouts/{id}/process`: Process a single payout. Requires `transferReference` (string). Sets status to `Processed`. Triggers push to tradie.
 - [x] `POST /api/admin/payouts/batches/{id}/complete`: Mark batch as `Completed` when all payouts are processed.
 - [x] All endpoints require Staff or Superadmin role.

---

## P10-07: Backend — Service Catalog Enhancement

**Platform:** Backend
**Description:** Add licence-gating fields to the `Service` model and seed the initial NZ catalog.

**References:**
- `Models/Service.cs`
- `Data/FixoDbContext.cs`

**Revises:**
- `Models/Service.cs`
- `Data/FixoDbContext.cs`

**Acceptance Criteria:**
 - [x] Add to `Service`: `RequiresLicence` (bool, default false), `LicenceBoard` (string?, e.g., "EWRB", "PGDB", "LBP").
 - [x] Generate migration `AddServiceLicenceFields`.
 - [x] Create seed data migration or `IHostedService` seeder with initial NZ catalog:
  - Plumbing: General plumbing, Hot water systems, Drain unblocking → `RequiresLicence=true, LicenceBoard="PGDB"`
  - Electrical: General electrical, Lighting, Switchboard → `RequiresLicence=true, LicenceBoard="EWRB"`
  - Building: Carpentry, Decking, Fencing, Minor renovations → `RequiresLicence=true, LicenceBoard="LBP"`
  - Handyman: General repairs, Furniture assembly, Shelving, Odd jobs → `RequiresLicence=false`
  - Cleaning: House cleaning, End-of-tenancy, Window cleaning → `RequiresLicence=false`
  - Painting: Interior painting, Exterior painting, Wallpapering → `RequiresLicence=false`

---

## P10-08: Backend — Licence-Gated Matching

**Platform:** Backend
**Description:** Update matching service to enforce licence requirements. For services with `RequiresLicence == true`, only match tradies with an `Approved` credential matching the `LicenceBoard`.

**References:**
- `Services/MatchingService.cs`
- `Models/TradieCredential.cs`

**Revises:**
- `Services/MatchingService.cs`

**Acceptance Criteria:**
 - [x] In `RankAvailableTradiesAsync`, if the job's service has `RequiresLicence == true`, add a filter: tradie must have at least one `TradieCredential` with `Status == Approved` and `Type` matching the service's `LicenceBoard`.
 - [x] Also filter out tradies where `IsAvailable == false` (vacation mode).
 - [x] Credential type enum extended with licence-board-specific values (or matching uses the existing free-form `Type` string).

---

## P10-09: Backend — Insurance Badge

**Platform:** Backend
**Description:** Add insurance credential type and profile badge.

**References:**
- `Models/TradieProfile.cs`
- `Models/TradieCredential.cs`

**Revises:**
- `Models/TradieProfile.cs`

**Acceptance Criteria:**
- [x] Add `HasInsurance` (bool, default false) to `TradieProfile`.
 - [x] When admin approves a credential of type `Insurance`, set `HasInsurance = true`. When the last insurance credential is rejected/removed, set `HasInsurance = false` (same pattern as `IsVerified`).
- [x] Include `hasInsurance` in `TradieProfileDto` / `JobDto` tradie card data.
 - [x] Migration `AddInsuranceBadge`.

---

## P10-10: Backend — Tradie Availability Toggle

**Platform:** Backend
**Description:** Endpoint for tradies to toggle their availability (vacation/pause mode).

**References:**
- `Controllers/ProfileController.cs`

**Revises:**
- `Controllers/ProfileController.cs`

**Acceptance Criteria:**
 - [x] `POST /api/profile/availability` accepts `{ "available": true/false }`. Updates `TradieProfile.IsAvailable`.
 - [x] Returns updated profile.
 - [x] `GET /api/profile` includes `isAvailable` field.
 - [x] Matching service already gates on `IsAvailable` per P10-08.

---

## P10-11: Backend — Blind Review Logic

**Platform:** Backend
**Description:** Implement blind review window. Reviews are hidden until both parties submit or 7 days elapse.

**References:**
- `Models/Review.cs`
- `Controllers/ReviewsController.cs`
- `Services/ReviewService.cs` (new or existing)

**Revises:**
- `Models/Review.cs`
- `Controllers/ReviewsController.cs`

**Acceptance Criteria:**
 - [x] Add to `Review`: `RevealAfterUtc` (DateTime?, computed on creation).
 - [x] On review creation, calculate `RevealAfterUtc`:
  - If both reviews for the job now exist → set both to `UtcNow` (immediately visible).
  - If only one review → set to `job.CompletedAtUtc + 7 days`.
 - [x] `GET /api/jobs/{id}/reviews` returns reviews with `isRevealed` flag. If `!isRevealed`, redact `stars` and `comment` from the response (return `null`/placeholder).
- [x] Schedule Hangfire `RevealReviewsJob` 7 days after job completion. Job checks if reviews are still unrevealed and flips them. Sends push notification to both parties.
 - [x] When the second review is submitted, cancel or no-op the scheduled reveal job (already revealed).
 - [x] Migration `AddReviewRevealAfter`.

---

## P10-12: Backend — Low-Rating Flag

**Platform:** Backend
**Description:** Auto-flag users whose average rating drops below 3.0 after at least 3 reviews.

**References:**
- `Services/AccountFlagService.cs`

**Revises:**
- `Services/AccountFlagService.cs`

**Acceptance Criteria:**
- [x] Add `LowRating` to `AccountFlagType` enum.
 - [x] After each review is revealed, recalculate the reviewed user's average. If avg < 3.0 and review count ≥ 3, call `AccountFlagService.CreateOrUpdateFlagAsync(userId, AccountFlagType.LowRating, ...)`.
 - [x] No auto-suspension — flag is for admin review only.

---

## P10-13: Backend — Job Editing Lockout

**Platform:** Backend
**Description:** Prevent editing jobs once matching has started.

**References:**
- `Controllers/JobsController.cs`

**Revises:**
- `Controllers/JobsController.cs`

**Acceptance Criteria:**
 - [x] `PUT /api/jobs/{id}` returns 409 Conflict if `Job.Status != Draft` or if any `JobOffer` exists for the job.
 - [x] Response body: `{ "message": "Job cannot be edited after matching has started. Cancel and repost to change details." }`

---

## P10-14: Backend — Photo Limit Enforcement

**Platform:** Backend
**Description:** Enforce maximum 5 photos, 10 MB each on job creation.

**References:**
- `Validators/Jobs/CreateJobRequestValidator.cs`
- `Controllers/JobsController.cs`

**Revises:**
- `Validators/Jobs/CreateJobRequestValidator.cs`

**Acceptance Criteria:**
 - [x] `CreateJobRequestValidator`: max 5 files in photos array.
 - [x] Each file max 10 MB (10,485,760 bytes). Validate in controller before blob upload.
 - [x] Return 400 with descriptive message on violation.

---

## P10-15: Backend — Brand & Legal Entity Configuration

**Platform:** Backend
**Description:** Add `Brand` and extended `Locale` config sections for white-label support and rebrand.

**References:**
- `appsettings.json`
- `Controllers/ConfigController.cs`

**Revises:**
- `appsettings.json`
- `Controllers/ConfigController.cs`

**Acceptance Criteria:**
- [x] Add `Brand` section: `AppName` ("TradieFixo"), `SupportEmail`, `SupportHoursDisplay` ("8am – 6pm NZT, Mon–Fri").
- [x] Add to `Locale`: `LegalEntityName`, `LegalEntityCountry`, `TermsOfServiceUrl`, `PrivacyPolicyUrl`, `PilotRegion`, `MaxSearchRadiusKm`, `DefaultSearchRadiusKm`, `MaterialsDisclaimer` ("Materials are not included in the quoted price and are settled directly between you and the tradie.").
- [x] `GET /api/config/locale` returns all new fields.
- [x] Create `Options/BrandOptions.cs`, bind in DI.
- [x] Push notification titles use `BrandOptions.AppName` instead of hardcoded "Fixo".

---

## P10-16: Backend — Payment Queue SLA Indicators

**Platform:** Backend
**Description:** Add time-based urgency to the payment queue.

**References:**
- `Controllers/AdminController.cs`
- `DTOs/PaymentDTOs.cs`

**Revises:**
- `Controllers/AdminController.cs`

**Acceptance Criteria:**
 - [x] `GET /api/admin/payments/pending` response includes `minutesSinceSubmission` (int) per payment.
 - [x] Schedule Hangfire job: 30 minutes after a payment enters `PaymentReview`, if still unverified, send push notification to all staff users ("Payment for job {ReferenceCode} has been waiting {minutes} minutes for verification").

---

## P10-17: Mobile — Tradie Bank Details in Onboarding

**Platform:** Mobile
**Description:** Add bank account fields to the tradie onboarding wizard.

**References:**
- `lib/views/tradie/tradie_onboarding_wizard.dart`
- `lib/repositories/profile_repository.dart`

**Revises:**
- `lib/views/tradie/tradie_onboarding_wizard.dart`

**Acceptance Criteria:**
- [x] Add bank account name and number fields to Step 1 (profile). Fields are optional during onboarding but required before first job completion.
- [x] Show info text: "Your bank details are required to receive payouts for completed jobs."
- [x] Bank account number input: formatted as XX-XXXX-XXXXXXX-XX (NZ bank account format).
- [x] Save via existing `PUT /api/profile`.

---

## P10-18: Mobile — Tradie Availability Toggle

**Platform:** Mobile
**Description:** Add availability toggle to tradie dashboard.

**References:**
- `lib/views/tradie/tradie_dashboard_view.dart`

**Revises:**
- `lib/views/tradie/tradie_dashboard_view.dart`

**Acceptance Criteria:**
- [x] Toggle switch in dashboard header: "Available for jobs" / "Unavailable (paused)".
- [x] Calls `POST /api/profile/availability`.
- [x] When unavailable, show amber banner: "You're currently paused. Toggle back on to receive new job offers."
- [x] Does not affect existing active jobs.

---

## P10-19: Mobile — Blind Review UI

**Platform:** Mobile
**Description:** Update review submission and display to support blind reviews.

**References:**
- `lib/views/reviews/` (existing review screens)

**Revises:**
- Review creation and display screens

**Acceptance Criteria:**
- [x] After submitting a review, show confirmation: "Your review has been submitted. It will be visible once the other party also reviews, or after 7 days."
- [x] On job detail, if review exists but `isRevealed == false`, show placeholder: "Review submitted — waiting for the other party."
- [x] Once revealed, show both reviews with stars and comments.

---

## P10-20: Mobile — Tradie Review of Homeowner

**Platform:** Mobile
**Description:** Add tradie-side review flow for rating homeowners after job completion.

**References:**
- `lib/views/tradie/tradie_job_detail_screen.dart`

**Revises:**
- `lib/views/tradie/tradie_job_detail_screen.dart`

**Acceptance Criteria:**
- [x] After job `Completed`, show "Rate Homeowner" button on tradie job detail (same as homeowner's "Leave Review").
- [x] Review modal: 1–5 stars, optional comment.
- [x] Calls `POST /api/reviews` with `fromUser = tradieId`, `toUser = homeownerId`.
- [x] Show pending/revealed state per P10-19.

---

## P10-21: Mobile — Insurance Badge Display

**Platform:** Mobile
**Description:** Display "Insured" badge on tradie cards where applicable.

**References:**
- `lib/views/widgets/tradie_card.dart` (or equivalent)

**Revises:**
- Tradie card widget

**Acceptance Criteria:**
- [x] If `hasInsurance == true` in tradie data, show a shield/badge icon with "Insured" label.
- [x] Displayed on search results, job detail (matched tradie card), and tradie profile.

---

## P10-22: Mobile — Materials Disclaimer

**Platform:** Mobile
**Description:** Show materials disclaimer on job detail and payment screens.

**References:**
- `lib/views/payment/payment_screen.dart`
- `lib/views/jobs/` (job detail screens)

**Revises:**
- Payment and job detail screens

**Acceptance Criteria:**
- [x] Read `materialsDisclaimer` from `GET /api/config/locale`.
- [x] Display as info banner on payment screen (below amount).
- [x] Display as info text on job detail for homeowner.

---

## P10-23: Mobile — Job Editing Lockout

**Platform:** Mobile
**Description:** Disable edit functionality once matching starts.

**References:**
- `lib/views/jobs/` (homeowner job detail/edit)

**Revises:**
- Job detail screens

**Acceptance Criteria:**
- [x] Hide "Edit" button when job status is `Requested` or beyond, or when offers exist.
- [x] If user somehow triggers edit, backend returns 409 (handled gracefully with dialog).

---

## P10-24: Mobile — TradieFixo Rebrand

**Platform:** Mobile
**Description:** Replace all user-facing "Fixo" references with "TradieFixo". Read brand name from config.

**References:**
- `lib/views/onboarding/` (splash, onboarding slides)
- `lib/views/widgets/` (app bar, drawer)

**Revises:**
- All screens displaying the app name

**Acceptance Criteria:**
- [x] Splash screen: "TradieFixo" text/logo.
- [x] Onboarding slides: "TradieFixo" in copy.
- [x] App bar titles read from `BrandOptions.AppName` via locale config provider.
- [x] Push notification titles: "TradieFixo: ..." (read from brand config in backend).
- [x] About/settings screen: "TradieFixo" with version.

---

## P10-25: Mobile — Photo Upload Limits

**Platform:** Mobile
**Description:** Enforce 5-photo, 10MB limit in the job posting UI.

**References:**
- `lib/views/jobs/post_job_screen.dart`

**Revises:**
- `lib/views/jobs/post_job_screen.dart`

**Acceptance Criteria:**
- [x] Photo picker allows max 5 selections.
- [x] Each photo validated for size (≤ 10 MB) before upload. Show error if exceeded.
- [x] Counter shows "X/5 photos added".

---

## P10-26: Web Admin — Payout Queue

**Platform:** Web
**Description:** Admin pages for managing tradie payouts and batches.

**References:**
- `src/features/payouts/` (new)

**Acceptance Criteria:**
- [x] Create `PayoutQueue.tsx` at route `/payouts`. Table of pending/scheduled payouts with: tradie name, job reference, gross amount, commission, net amount, bank (last 4), status, age.
- [x] "Process" button per row → modal with `TransferReference` input → calls `POST /api/admin/payouts/{id}/process`.
- [x] Create `PayoutBatches.tsx` at route `/payouts/batches`. Lists batches with period, total, count, status.
- [x] Batch detail page with individual payouts and "Mark Batch Complete" action.
- [x] Add "Payouts" to sidebar navigation.
- [x] Processed rows removed from queue via cache invalidation.

---

## P10-27: Web Admin — Payment Queue SLA Indicators

**Platform:** Web
**Description:** Add time-based urgency indicators to the existing payment queue.

**References:**
- `src/features/payments/pages/PaymentQueue.tsx`

**Revises:**
- `src/features/payments/pages/PaymentQueue.tsx`

**Acceptance Criteria:**
- [x] Add "Waiting" column showing time since submission.
- [x] Items waiting > 15 min: amber background.
- [x] Items waiting > 30 min: red background + "URGENT" badge.
- [x] Sort by oldest first (already implemented, confirm).

---

## P10-28: Web Admin — TradieFixo Rebrand

**Platform:** Web
**Description:** Replace "Fixo" with "TradieFixo" in admin dashboard UI.

**References:**
- `src/layout/AdminLayout.tsx`
- `src/components/` (header, sidebar)

**Revises:**
- `src/layout/AdminLayout.tsx`

**Acceptance Criteria:**
- [x] Header: "TradieFixo Admin".
- [x] Browser tab title: "TradieFixo Admin".
- [x] Login page: "TradieFixo Admin Portal".
- [x] Read from `GET /api/config/locale` brand config where possible; fallback hardcoded for login screen.

---

## Implementation Notes

- **Bank account encryption:** `BankAccountNumber` should be encrypted at rest. Use ASP.NET Core Data Protection or a value converter in EF Core that encrypts/decrypts. This is sensitive PII.
- **Commission visibility:** Tradies see commission breakdown on completed job detail (gross, fee, net). Homeowners do not see commission — their view shows only the total they paid.
- **Payout batch timing:** The Hangfire cron `0 2 * * 1` fires at 2:00 AM UTC on Monday. For NZ (UTC+12/13), this is Monday afternoon — fine for admin processing during the week.
- **Blind review edge case:** If a job is disputed, reviews may be submitted but should remain hidden until the dispute is resolved. Add guard: reviews for disputed jobs are not revealed until dispute outcome is recorded.
