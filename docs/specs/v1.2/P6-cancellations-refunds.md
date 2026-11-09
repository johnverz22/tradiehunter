# Phase 6: Cancellations and Refunds

## P6-01: Refund Data Model & DB Migration
**Platform:** Backend

**Description:**
Create the entity model and database configuration for `Refund`.
This tracks the calculation of refund amounts and the manual processing of refunds by admins.

**References:**
- `Models/Job.cs`
- `Models/Payment.cs` (or similar)
- `Data/ApplicationDbContext.cs`

**Acceptance Criteria:**
- [x] Create `Models/Refund.cs` with properties: `Id` (Guid), `JobId`, `PaymentId`, `SuggestedAmount` (decimal), `FinalAmount` (decimal), `Penalty` (decimal), `HoursWorked` (decimal), `HoursWorkedAmount` (decimal), `Status` (enum: None, Pending, Processed), `ProcessedBy` (Guid?), `TransferReference` (string), `ProofFileKey` (string), `CreatedAtUtc` (DateTime), `ProcessedAtUtc` (DateTime?). — Done 2026-09-29: `Models/Refund.cs`.
- [x] Define `RefundStatus` enum. — Done 2026-09-29: `Enums/RefundStatus.cs` (None, Pending, Processed).
- [x] Configure EF Core in `ApplicationDbContext` (HasColumnType("decimal(18,2)") for amounts). — Done 2026-09-29: `Data/FixoDbContext.cs`, all five decimal columns typed, unique index on `JobId`, index on `Status`.
- [x] Add navigation properties from `Job` to `Refund` (1-to-0..1). — Done 2026-09-29: `Job.Refund` nav property + EF `WithOne`/`HasForeignKey` config.
- [x] Generate and apply EF Core migration `AddRefundsTable`. — Done 2026-09-29: migration `20260929002901_AddRefundsTable` applied; `TradieProfiles.CancellationCount` added in `20260929003445_P6_TradieCancellationCount`.

## P6-02: Cancellation Logic & Service Updates
**Platform:** Backend

**Description:**
Update the state machine in `JobStatusService` to handle cancellations and generate pending refunds.

**References:**
- `Services/JobStatusService.cs`
- `Services/MatchingService.cs`
- `DTOs/Jobs/CancelJobRequest.cs`

**Acceptance Criteria:**
- [x] Create `CancelJobRequest` DTO including required `ReasonCode` and optional `Notes`. — Done 2026-09-29: `DTOs/JobDTOs.cs`.
- [x] Add cancellation logic in `JobStatusService`: if Homeowner cancels before work, calculate penalty and set job status to Cancelled, create `Refund` in `Pending`. — Done 2026-09-29: `HandleHomeownerCancellationAsync` — 10% flat penalty on Booked, `Refund` created when `totalPaid > 0`.
- [x] If Homeowner cancels during work (or after check-in), calculate `SuggestedAmount` based on rate x hours worked and penalty. — Done 2026-09-29: elapsed hours from `StartedAtUtc`, `hoursWorkedAmount = hoursWorked × HourlyRate`, penalty = hours-worked-amount + 10%.
- [x] If Tradie cancels, record it, increment Tradie cancel counter, revert Job status to `Requested`. — Done 2026-09-29: `HandleTradieCancellationAsync` — status → `Requested`, `TradieProfile.CancellationCount++`.
- [x] For Tradie cancellation, call `MatchingService` to re-match the job, ensuring the canceling Tradie is excluded. Keep existing payment hold attached. — Done 2026-09-29: `SendOfferJob` enqueued via Hangfire; cancelling tradie has no Pending offer so `SendNextOfferAsync` naturally skips them; payment record untouched.

## P6-03: Cancellation Mobile UI
**Platform:** Mobile

**Description:**
Implement the cancellation flows for both Homeowner and Tradie on mobile.

**References:**
- `lib/features/jobs/screens/request_detail_screen.dart`
- `lib/features/jobs/providers/job_provider.dart`

**Acceptance Criteria:**
- [x] Add "Cancel Job" button to job details. — Done 2026-09-29: cancel app-bar icon on both `homeowner_job_detail_screen.dart` and `tradie_job_detail_screen.dart`, gated on cancellable statuses; `flutter analyze` clean.
- [x] Display a bottom sheet or dialog to select a reason code and enter optional notes. — Done 2026-09-29: shared `mobile/lib/views/widgets/cancel_job_sheet.dart` (`CancelJobSheet`) with reason radio group + optional notes field.
- [x] Show warnings based on role: Homeowner warned about potential cancellation fees; Tradie warned about account flags for repeated cancellations. — Done 2026-09-29: role-specific warning banner inside `CancelJobSheet` (`isTradie` flag) plus fee-warning banner on the homeowner detail screen for Booked/InProgress statuses.
- [x] Call cancellation endpoint and refresh job details/status. — Done 2026-09-29: `JobsRepository.cancelJobWithReason` → `POST /api/jobs/{id}/cancel`; status synced via `jobsViewModelProvider.applyStatusUpdate` + screen reload.

## P6-04: Admin Refund Queue UI
**Platform:** Web

**Description:**
Build an admin dashboard view to list pending refunds and process them.

**References:**
- `src/features/jobs/api/jobsApi.ts`
- `src/features/dashboard/Dashboard.tsx`

**Acceptance Criteria:**
- [x] Create new page `RefundQueue` to list all refunds with `Status == Pending`. — Done 2026-09-29: `web/src/features/refunds/pages/RefundQueue.tsx`; route `/refunds` in `App.tsx`; "Refunds" nav item in `AdminLayout`.
- [x] Show job details, amounts, and reasons for cancellation. — Done 2026-09-29: table shows job title/ID, homeowner, suggested amount, penalty, cancel reason code, and age.
- [x] Provide an action to "Process Refund". — Done 2026-09-29: "Process" button per row opens `ProcessRefundModal`.
- [x] Processing modal should allow admin to edit `Penalty` and `HoursWorked`. — Done 2026-09-29: `ProcessRefundModal.tsx` exposes editable `finalAmount`, `penalty`, and `hoursWorked` inputs pre-filled from the server suggestion.
- [x] Input fields for `TransferReference` and file upload for `ProofFileKey`. — Done 2026-09-29: required `TransferReference` text field + optional proof-file attachment (`Paperclip` upload, 10 MB limit).
- [x] On submit, call the backend processing endpoint. — Done 2026-09-29: `processRefund` in `adminApi.ts` → `POST /api/admin/refunds/{id}/process` (multipart); `useProcessRefund` mutation removes processed row from cache.

## P6-05: Admin Refund Processing Service
**Platform:** Backend

**Description:**
Implement the backend endpoint for admins to process and finalize a refund.

**References:**
- `Controllers/AdminController.cs`
- `Services/AdminService.cs`
- `Services/BlobStorageService.cs`

**Acceptance Criteria:**
- [x] Add `POST /api/admin/refunds/{id}/process` endpoint. — Done 2026-09-29: `AdminController.ProcessRefund` at `POST /api/admin/refunds/{id:guid}/process`; also added `GET /api/admin/refunds/pending`.
- [x] Take `ProcessRefundRequest` (FinalAmount, Penalty, HoursWorked, TransferReference). — Done 2026-09-29: `ProcessRefundRequest` DTO + `ProcessRefundForm` for multipart binding.
- [x] Upload proof file using `BlobStorageService`. — Done 2026-09-29: `AdminService.ProcessRefundAsync` uploads to `fixo-credentials` container, stores key in `Refund.ProofFileKey`.
- [x] Update `Refund` status to `Processed`, set `ProcessedBy`, `ProcessedAtUtc`, and amounts. — Done 2026-09-29: `refund.Status = Processed`, `ProcessedAtUtc = UtcNow`, `ProcessedBy` set from admin user ID.
- [x] Save to database and trigger push notifications to the user about their refund. — Done 2026-09-29: `SaveChangesAsync` then FCM push to all homeowner device tokens.

## P6-06: Notifications for Cancellations and Refunds
**Platform:** Backend

**Description:**
Ensure all parties are appropriately notified of cancellation events and refund statuses.

**References:**
- `Services/PushNotificationService.cs`

**Acceptance Criteria:**
- [x] When homeowner cancels, notify tradie (if one was matched/confirmed). — Done 2026-09-29: `JobStatusService.HandleHomeownerCancellationAsync` → `SendPushToUserAsync(job.MatchedTradieId, …)` with type `job_cancelled_by_homeowner`.
- [x] When tradie cancels, notify homeowner (job is being reassigned). — Done 2026-09-29: `HandleTradieCancellationAsync` → `SendPushToUserAsync(job.HomeownerId, …)` with type `job_cancelled_by_tradie`.
- [ ] When a refund is generated (Pending), optionally notify homeowner. — Not implemented; spec marks this as optional ("optionally notify").
- [x] When a refund is Processed, notify homeowner with final amount and transfer reference. — Done 2026-09-29: `AdminService.ProcessRefundAsync` → FCM push to all homeowner tokens with final amount and `TransferReference`; type `refund_processed`.
