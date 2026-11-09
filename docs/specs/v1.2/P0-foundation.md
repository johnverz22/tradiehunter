# Phase 0: Foundation (v1.2)

## Context
Phase 0 covers foundational structural changes required for v1.2, including deployment configuration, role extensions, authentication tracking, state machine (JobStatus) replacement, central transition service updates, and data migrations for existing records.

### What exists today:
- `UserRole` enum: Homeowner, Tradie, Admin
- `JobStatus` enum: Draft, Requested, Matching, Matched, Confirmed, InProgress, Complete, Cancelled
- `JobStatusService` with transition table: Draft→Requested/Cancelled, Requested→Matching/Cancelled, etc.
- `JobStatusHistory` with FromStatus, ToStatus, ChangedByUserId, Reason
- `ApplicationUser` has: FirstName, LastName, Role, CreatedAtUtc, IsActive (no auth_provider, no email_verified)
- `appsettings.json` has Locale section (currency, phone, timezone, distance)
- No `Staff` or `Superadmin` roles
- No `reason_code` or `cancelled_by` on history

## Tasks

### P0-01: Deployment Configuration Extensions
**Platform:** Backend
**Description:** 
Extend the `appsettings.json` and internal configuration models to support new v1.2 features, including payment instructions, matching rules, timeout configurations, and email sender settings.
**References:**
- `Models/Config/` (or similar config class location)
- `appsettings.json`
**Revises:**
- `appsettings.json`
- `appsettings.Development.json`
**Acceptance Criteria:**
- [x] Add `PaymentInstructions` section (AccountName, AccountNumber, ReferenceFormat).
- [x] Add `PaymentWindowHours`, `OfferTimeoutMinutes`, and `AutoCompleteWindowHours` fields.
- [x] Add `EmailSender` settings section.
- [x] Strongly typed configuration classes reflect the new fields.

### P0-02: Role Extension & Authorization Policies
**Platform:** Backend / Web
**Description:** 
Extend the `UserRole` enum to support administration tiers (`Staff` and `Superadmin`). Replace the `Admin` role or map it to `Staff` / `Superadmin`. Add role-gated authorization policies in the API controllers.
**References:**
- `Enums/UserRole.cs`
**Revises:**
- `Enums/UserRole.cs`
- `Controllers/AdminController.cs`
**Acceptance Criteria:**
- [x] `UserRole` enum includes `Homeowner`, `Tradie`, `Staff`, and `Superadmin`.
- [x] Authorization policies (e.g., `RequireStaffRole`, `RequireSuperadminRole`) are defined and applied appropriately.

### P0-03: User Entity Updates for Authentication
**Platform:** Backend
**Description:** 
Extend the `ApplicationUser` model to track the authentication provider and email verification status. Create and apply the EF Core migration.
**References:**
- `Models/ApplicationUser.cs`
**Revises:**
- `Models/ApplicationUser.cs`
**Acceptance Criteria:**
- [x] Add `AuthProvider` string field (e.g., "password", "google").
- [x] Add `EmailVerified` boolean field.
- [x] Add `EmailVerifiedAt` nullable DateTime field (stored as UTC).
- [x] EF Core migration generated and applied.

### P0-04: JobStatus & ReasonCode Enum Replacement
**Platform:** Backend
**Description:** 
Replace the existing `JobStatus` enum with the new 10-value lifecycle states. Add a new `ReasonCode` enum to standardize cancellation and dispute reasons.
**References:**
- `Enums/JobStatus.cs`
- `Enums/ReasonCode.cs`
**Revises:**
- `Enums/JobStatus.cs`
**Acceptance Criteria:**
- [x] `JobStatus` enum contains: `Requested`, `AwaitingPayment`, `PaymentReview`, `Booked`, `InProgress`, `AwaitingConfirmation`, `Completed`, `Cancelled`, `Expired`, `Disputed`.
- [x] `JobStatus` is configured in EF Core to be stored as a string via `HasConversion`.
- [x] `ReasonCode` enum contains: `homeowner_changed_mind`, `tradie_unavailable`, `tradie_no_show`, `homeowner_no_show`, `scope_change_declined`, `homeowner_issue`, `tradie_issue`, `emergency`, `no_tradie_found`, `no_payment`, `system_failure`, `dispute_outcome`.

### P0-05: JobStatusHistory Extensions
**Platform:** Backend
**Description:** 
Extend the `JobStatusHistory` model to capture more details about status changes, including the reason code, who canceled the job, and the role of the actor performing the transition.
**References:**
- `Models/JobStatusHistory.cs`
**Revises:**
- `Models/JobStatusHistory.cs`
**Acceptance Criteria:**
- [x] Add `ReasonCode` nullable enum field.
- [x] Add `CancelledBy` nullable string (User ID).
- [x] Add `ActorRole` nullable enum field (`UserRole`).
- [x] EF Core migration generated and applied.

### P0-06: Central Transition Service State Machine
**Platform:** Backend
**Description:** 
Refactor the `IJobStatusService` and `JobStatusService` to replace the simple dictionary mapping with a robust transition table (From, To, ActorRole, Guard). The service must enforce guard conditions before transitioning and write enriched rows to `JobStatusHistory`.
**References:**
- `Services/JobStatusService.cs`
- `Services/IJobStatusService.cs`
**Revises:**
- `Services/JobStatusService.cs`
- `Services/IJobStatusService.cs`
**Acceptance Criteria:**
- [x] Transition table implements all rules from MVP-SPEC-v1.2.md.
- [x] Guard conditions (e.g., Accepts before offer timeout, Receipt uploaded, Receipt verified) are evaluated during transitions.
- [x] Exceptions are thrown for invalid transitions or failed guards.
- [x] `JobStatusHistory` records are fully populated with new fields (`ActorRole`, `ReasonCode`).

### P0-07: Job Entity Fields Expansion
**Platform:** Backend
**Description:** 
Expand the `Job` model to support scheduling, precise financial tracking, and cancellation details. Replace `ScheduledDateUtc` with `ScheduledStart`. Ensure money fields are `decimal`. EF Core spatial LINQ should be maintained; no raw PostGIS SQL.
**References:**
- `Models/Job.cs`
**Revises:**
- `Models/Job.cs`
**Acceptance Criteria:**
- [x] Add `ScheduledStart` (DateTime, replacing `ScheduledDateUtc`).
- [x] Add `Hours` (decimal).
- [x] Add `HourlyRateSnapshot` (decimal).
- [x] Add `TotalAmount` (decimal).
- [x] Add `ReferenceCode` (string) for payment tracking.
- [x] Add `StartedAt` and `EndedAt` (nullable DateTime).
- [x] Add `CancelledBy` (string User ID) and `ReasonCode` (nullable enum).
- [x] EF Core migration generated and applied.

### P0-08: Data Migration for Existing Records
**Platform:** Backend
**Description:** 
Write a one-off data migration (via EF Core Migration `Up` method raw SQL or a hosted service) to map existing legacy statuses to the new enum values, and set defaults for new fields to prevent data corruption.
**References:**
- Migrations folder
**Revises:**
- New EF Core Migration file
**Acceptance Criteria:**
- [x] Map `Matching` and `Matched` to `Requested`.
- [x] Map `Confirmed` to `Booked`.
- [x] Map `Complete` to `Completed`.
- [x] Leave `Draft`, `Requested`, `InProgress`, and `Cancelled` as is (or mapped to identical strings).
- [x] Existing jobs have valid defaults for new required fields.

DONE_P009: Mobile JobStepper Update
**Platform:** Mobile
**Description:** 
Update the Flutter `JobStepper` widget to reflect the new state flow and stage mapping. Use the existing Riverpod MVVM patterns.
**References:**
- Flutter UI widgets
- `lib/models/job.dart`
**Revises:**
- `lib/ui/widgets/job_stepper.dart` (or equivalent)
- `lib/models/job.dart`
**Acceptance Criteria:**
- [x] UI reflects the new linear flow: Requested -> Payment -> Booked -> InProgress -> Confirmation -> Completed.
- [x] Disputed and Cancelled states show appropriate failure/alert visuals.
- [x] `JobStatus` enum in Dart updated to match backend.

DONE_P010: Web Admin StatusBadge Update
**Platform:** Web
**Description:** 
Update the React admin interface to handle the new `JobStatus` values, rendering appropriate colors and labels for the new statuses like `AwaitingPayment`, `PaymentReview`, `Disputed`, etc.
**References:**
- React components
- `src/types/job.ts`
**Revises:**
- `src/components/StatusBadge.tsx` (or equivalent)
- `src/types/job.ts` (or equivalent)
**Acceptance Criteria:**
- [x] All 10 new statuses are styled correctly (e.g., Warning/Yellow for `Disputed`, Blue for `Booked`).
- [x] TypeScript types are updated to reflect the new API enum values.
