# Phase 4: Manual Payment and Admin Queue

This phase introduces the payment flow to the application. Since there is currently no payment system, we will implement a manual payment process where the homeowner uploads a receipt of a bank transfer, which is then manually verified by the admin team via an admin queue.

## P4-01: Payment Database Migration and Entities
**Platform:** Backend  
**Description:** 
Create the `Payment` entity and corresponding database migration. The `payments` table should track payment details, receipt references, and verification status. The `Amount` must be a decimal. `Status` will be a string via EF Core HasConversion.
- Create `Payment` entity in `Models/Payment.cs`.
- Add `DbSet<Payment>` to `FixoDbContext`.
- Add EF Core configuration for `Payment`.
- Generate migration.

**References:**
- `Models/Job.cs`
- `Data/FixoDbContext.cs`

**Revises:**
- `Data/FixoDbContext.cs`

**Acceptance Criteria:**
- [x] `Payment` entity has properties: Id, JobId, Amount (decimal), Currency, Method, Provider, ProviderReference, Status (string), ReceiptFileKey, ReceiptHash, VerifiedBy (nullable string), VerifiedAtUtc (nullable DateTime), RejectReason, ReUploadCount, CreatedAtUtc.
- [x] Migration generated successfully and applied.
- [x] Unique index or constraint on `ReceiptHash` to catch receipt reuse.
- [x] Foreign keys configured for JobId and VerifiedBy (Admin user).

## P4-02: IPaymentProvider Interface and ManualReceiptProvider
**Platform:** Backend  
**Description:** 
Introduce the `IPaymentProvider` interface and implement the `ManualReceiptProvider` to handle receipt-based manual verification.
- Create `IPaymentProvider` with methods: `CreatePaymentAsync`, `GetPaymentStatusAsync`, `ProcessRefundAsync`.
- Implement `ManualReceiptProvider` inheriting from `IPaymentProvider`.

**References:**
- `Services/Payment/IPaymentProvider.cs` (New)
- `Services/Payment/ManualReceiptProvider.cs` (New)

**Acceptance Criteria:**
- [x] `IPaymentProvider` is defined with the required methods.
- [x] `ManualReceiptProvider` implements the interface (even if refund throws `NotImplementedException` for manual).
- [x] Services registered in dependency injection (`Program.cs` or extensions).

## P4-03: PaymentService Implementation
**Platform:** Backend  
**Description:** 
Create `PaymentService` to orchestrate the payment flow, including receipt upload (via `BlobStorageService`), hashing, duplicate detection, and status updates.
- Verify job status allows payment (e.g., currently `Matched`).
- Hash receipt image file to generate `ReceiptHash`. Check for duplicates.
- Call `JobStatusService` to transition job to `AwaitingPayment` if rejected, or `Booked` if verified.

**References:**
- `Services/Payment/PaymentService.cs` (New)
- `Services/Payment/IPaymentService.cs` (New)
- `Services/BlobStorageService.cs`

**Acceptance Criteria:**
- [x] `UploadReceiptAsync` method checks if the job can receive payments.
- [x] Throws error if receipt hash already exists in another payment.
- [x] Saves uploaded file via `BlobStorageService` and records the file key.
- [x] Transitions payment state (Pending -> Submitted).

## P4-04: Payment Endpoints
**Platform:** Backend  
**Description:** 
Add endpoints for homeowners to fetch payment instructions, upload receipts, and check payment status.
- `GET /api/jobs/{id}/payment`: Return current payment status and instructions (bank details, expected amount, unique reference code).
- `POST /api/jobs/{id}/payment/upload-receipt`: Accepts multipart/form-data for receipt upload.

**References:**
- `Controllers/PaymentController.cs` (New)
- `DTOs/PaymentDTOs.cs` (New)

**Acceptance Criteria:**
- [x] GET endpoint returns accurate payment details (expected amount, job specific reference, status).
- [x] POST endpoint correctly processes file upload and associates it with the job via `PaymentService`.
- [x] Endpoints are protected with proper authorization (only job owner).

## P4-05: Admin Payment Queue Endpoints
**Platform:** Backend  
**Description:** 
Add admin endpoints to view pending payments, verify, or reject them.
- `GET /admin/payments/pending`: List payments with status `Submitted`. Include associated Job ID, Amount, Reference, Receipt File Url.
- `POST /admin/payments/{id}/verify`: Verify a payment, transition Job to `Booked`.
- `POST /admin/payments/{id}/reject`: Reject a payment, providing a `Reason`. Transition Job back to `AwaitingPayment`. Increment `ReUploadCount`.

**References:**
- `Controllers/AdminController.cs`
- `Services/Payment/PaymentService.cs`

**Revises:**
- `Controllers/AdminController.cs`

**Acceptance Criteria:**
- [x] GET endpoint supports pagination and returns necessary data for the admin queue.
- [x] Verify endpoint transitions Payment to `Verified` and Job to `Booked`. Notifies homeowner (Push/Email).
- [x] Reject endpoint transitions Payment to `Rejected` and Job to `AwaitingPayment`, setting `RejectReason`. Notifies homeowner.

## P4-06: Hangfire Payment Expiry Job
**Platform:** Backend  
**Description:** 
Schedule a background task when a job moves to a state requiring payment. If payment isn't verified within the required window, automatically cancel/expire the job, releasing the tradie.
- Create a Hangfire job to check payment status.
- If payment is not `Verified`, transition Job to `Cancelled` or `Expired`.

**References:**
- `Services/JobStatusService.cs`
- `Jobs/PaymentExpiryJob.cs` (New)

**Revises:**
- `Services/JobStatusService.cs`

**Acceptance Criteria:**
- [x] Hangfire task is scheduled when payment starts.
- [x] When task runs, it checks if payment is successfully completed.
- [x] If payment is incomplete, the job is cancelled and the tradie is freed.

## P4-07: Homeowner Payment UI
**Platform:** Mobile  
**Description:** 
Create screens in the Flutter app for the homeowner to view payment instructions, upload a receipt, and check the payment status.
- `PaymentScreen`: Shows bank transfer instructions, unique reference code, exact amount, and an image picker for the receipt.
- `PaymentStatusScreen`: Shows the current state (Pending, Submitted, Verified, Rejected with reason).

**References:**
- `lib/views/payment/payment_screen.dart` (New)
- `lib/views/payment/payment_status_screen.dart` (New)
- `lib/repositories/payments_repository.dart` (New)

**Revises:**
- `lib/viewmodels/payment_viewmodel.dart` (New — Riverpod `StateNotifier` per job)
- `lib/router/app_router.dart` (routes `/jobs/:jobId/payment` and `/jobs/:jobId/payment/status`)
- `lib/views/widgets/job_navigation.dart` (New — job card tap target)

**Acceptance Criteria:**
- [x] Screen displays correct bank details, amount, and reference code.
- [x] User can pick an image and upload it successfully.
- [x] If rejected, user can see the reason and re-upload.
- [x] UI reflects the current status of the payment accurately.

## P4-08: Admin Web Payment Queue UI
**Platform:** Web  
**Description:** 
Add a Payment Queue page to the React admin panel to review and verify/reject receipts.
- New page `PaymentQueue` listing submitted payments.
- Clicking a row opens a modal (`PaymentReviewModal`) showing expected amount, reference code, and the uploaded receipt image.
- Actions: "Verify" and "Reject" (prompts for a reason).

**References:**
- `src/features/payments/pages/PaymentQueue.tsx` (New)
- `src/features/payments/components/PaymentReviewModal.tsx` (New)
- `src/features/payments/hooks/usePayments.ts` (New)
- `src/App.tsx`

**Revises:**
- `src/App.tsx` (Add routing)
- `src/layout/AdminLayout.tsx` (Add navigation link)
- `src/services/adminApi.ts` (Add payment types + endpoints)
- `src/components/ConfirmModal.tsx` (opt-in `size="lg"` for the receipt viewer)

**Acceptance Criteria:**
- [x] Table lists all pending payments with relevant summary info.
- [x] Admin can view the full-size receipt image in the modal.
- [x] Verify action succeeds and removes the item from the queue.
- [x] Reject action requires a text reason and removes the item from the queue on success.

## Implementation notes

Delivered 2026-09-28. Deviations and decisions found while building:

- **The state machine already had a `PaymentReview` state, and it is the
  missing piece the spec assumed away.** P4-03/05 describe the upload as
  `AwaitingPayment → Booked`/rejected. The real `JobStatus` enum routes it
  through `PaymentReview` (receipt is with staff), and every edge already
  existed except `PaymentReview → Expired`. This phase uses those edges, so
  the homeowner sees "under review" rather than a job that jumps from unpaid
  to booked. Added one edge: `PaymentReview → Expired` (Staff/Superadmin),
  because a receipt can sit un-reviewed past the payment window.
- **"Currently `Matched`" does not exist in v1.2.** A tradie accepting moves
  the job to `AwaitingPayment` (see P3 notes), so that is the state
  `UploadReceiptAsync` gates on.
- **The expiry job re-reads `Job.PaymentDueAtUtc` rather than trusting its
  own fire time.** Rejecting a receipt restarts the homeowner's payment
  window, which re-arms the job; a request enqueued under the old deadline
  would otherwise expire the job early. It re-schedules itself for the
  remaining time. This is why the deadline is stored on the `Job` rather than
  tracked as a Hangfire job id that has to be found and cancelled.
- **`ReUploadCount` increments on reject, not on re-upload**, per the P4-05
  wording. It reads as "sent back N times"; the smoke test asserts it stays
  at 1 across a re-upload.
- **One `Payment` per job, reused across re-uploads** (unique index on
  `JobId`). Re-uploading mutates the row rather than appending, which is what
  makes `ReUploadCount` and `RejectReason` meaningful. The superseded receipt
  blob is deleted so rejections don't leak private documents.
- **A receipt image is single-use evidence, in both directions.** The unique
  index is on `ReceiptHash`, so the same bank confirmation cannot back a
  second payment — and re-sending the exact file after a rejection is refused
  too, since it is the evidence staff already rejected. Both cases get
  distinct error copy; `scripts/p4-smoke.sh` covers each.
- **New private blob container `fixo-payments` for receipts**, separate from
  `fixo-credentials`, so access to financial documents can be revoked
  independently of tradie credentials. Configured via
  `PaymentInstructions:PaymentsContainer`; the containers are still created
  lazily on first upload.
- **`PaymentInstructions` config was already present but unused**, along with
  a dead root-level `PaymentWindowHours`. Both are now bound to
  `PaymentOptions`: the section carries `AccountName`, `AccountNumber`,
  `ReferenceFormat`, `WindowHours` and `PaymentsContainer`, and the stray root
  key was removed. `ReferenceFormat` (`FIXO-{JobId}`) is what renders the
  transfer reference staff match against the bank statement.
- **The service layer takes a `ReceiptUpload` transport object, not
  `IFormFile`.** `PaymentController` unwraps the multipart upload; the service
  stays free of ASP.NET Core types per `.agent/rules/backend.md`.
- **Mobile and web paths differ from those named above.** The app uses a flat
  `lib/views`/`lib/viewmodels`/`lib/repositories` layout (not
  `lib/features/...`), and the web app is feature-sliced (not
  `src/pages/...` + `src/components/...`). Payment calls live in a new
  `payments_repository.dart` rather than growing `jobs_repository.dart`,
  matching the existing one-repository-per-domain split; the screens reach it
  through a Riverpod `StateNotifier` like every other screen.
- **Job-card taps route to payment.** `openHomeownerJob`
  (`lib/views/widgets/job_navigation.dart`) sends a homeowner's job to the
  payment screen when it is `AwaitingPayment` and to the status screen when it
  is `PaymentReview`; every other status still opens the chat. Without this
  the only way to reach the pay button is to know the route.
- **The receipt is served by SAS URL, not an `<img src="/api/...">`
  proxy** — same as tradie credentials, so the image needs no auth header and
  the URL simply expires. `ConfirmModal` gained an opt-in `size="lg"` for the
  receipt viewer; existing callers are unaffected.
- **New:** the admin queue is a separate `/payments` route, not a tab on the
  credentials queue, because the review semantics differ (amount + reference
  vs document type).

Verified end to end by `scripts/p4-smoke.sh` against the running stack:
instructions → upload → admin queue → verify → `Booked`; reject → reason
required → re-upload on the same row; cross-job and same-job receipt reuse
refused with distinct copy; non-owner `GET` is 404 and a homeowner hitting the
admin queue is 403; uploads against a `Booked`/`Expired` job are 409; and with
`WindowHours: 0` the Hangfire job expires a job both with and without a payment
row, records `no_payment`, and fires exactly once.

Rendered-markup coverage for the web queue is in
`scripts/web/fixtures/payments/` via `scripts/web/render-probe.py` (populated
queue and empty state). The mobile model has unit tests in
`mobile/test/payment_test.dart` covering the `PaymentStatus` wire format,
decimal money, and the server-owned `canUploadReceipt` rule.
