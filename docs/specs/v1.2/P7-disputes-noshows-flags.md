# Phase 7: Disputes, No-Shows, Flags

## P7-01: Dispute and Account Flag Data Models & Migration
**Platform:** Backend

**Description:**
Create the tables necessary for handling disputes, evidence, and account flagging thresholds.

**References:**
- `Models/Job.cs`
- `Models/ApplicationUser.cs`
- `Data/ApplicationDbContext.cs`

**Acceptance Criteria:**
- [x] Create `Models/Dispute.cs`: `Id`, `JobId`, `OpenedBy`, `OpenedAtUtc`, `Status` (Open, UnderReview, Resolved), `Outcome` (FullRefund, PartialRefund, NoRefund, Null), `DecidedBy`, `DecidedAtUtc`, `DecisionNote`.
- [x] Create `Models/DisputeEvidence.cs`: `Id`, `DisputeId`, `SubmittedBy`, `Type` (Photo, Text, Document), `FileKey`, `TextContent`, `CreatedAtUtc`.
- [x] Create `Models/AccountFlag.cs`: `Id`, `UserId`, `Type` (RepeatCanceller, RepeatNoShow, Abuse, Manual), `Counter` (int), `ThresholdHit` (bool), `CreatedBy`, `CreatedAtUtc`, `Note`, `Resolved` (bool), `ResolvedAtUtc`.
- [x] Generate and apply migration `AddDisputesAndFlags`.

## P7-02: Dispute Service and Opening Flow
**Platform:** Backend

**Description:**
Service logic to open a dispute, upload evidence, and update job status.

**References:**
- `Services/DisputeService.cs` (new)
- `Controllers/DisputesController.cs` (new)

**Acceptance Criteria:**
- [x] Endpoint `POST /api/disputes` to create a new dispute linked to a Job.
- [x] Update Job status to `Disputed`. (Using `DisputeStatus` as per spec model)
- [x] Endpoint `POST /api/disputes/{id}/evidence` handling multipart form data (photos/documents) or text.
- [x] Store files via `BlobStorageService` and save `DisputeEvidence` records.

## P7-03: Dispute Mobile UI & Evidence Upload
**Platform:** Mobile

**Description:**
Allow users to initiate a dispute from a job and upload photos/text as evidence.

**References:**
- `lib/features/jobs/screens/dispute_screen.dart` (new)

**Acceptance Criteria:**
- [x] Add "Open Dispute" action on Job details if applicable.
- [x] Form to select dispute reason and provide details.
- [x] UI to attach photos from camera/gallery or add text notes.
- [x] Display dispute status and existing evidence on the job details screen once open.

## P7-04: No-Show Reporting Service
**Platform:** Backend

**Description:**
Logic to handle reports of no-shows from either party.

**References:**
- `Services/JobStatusService.cs`
- `Services/AccountFlagService.cs` (new)

**Acceptance Criteria:**
- [x] Add `POST /api/jobs/{id}/no-show` endpoint.
- [x] If homeowner reports tradie no-show: log flag against tradie, give homeowner choice to reassign or cancel for full refund.
- [x] If tradie reports homeowner no-show (after grace period): log flag against homeowner, process job as cancelled with partial refund (penalty applied to homeowner).
- [x] Notify the accused party.

## P7-05: No-Show Mobile UI
**Platform:** Mobile

**Description:**
UI for reporting a no-show.

**References:**
- `lib/features/jobs/screens/request_detail_screen.dart`

**Acceptance Criteria:**
- [x] Show "Report No-Show" button based on scheduled time and current time.
- [x] For homeowner, show dialog to choose "Reassign" or "Cancel & Refund".
- [x] For tradie, show warning that they are claiming homeowner is absent and job will be cancelled.

## P7-06: Admin Dispute Resolution UI
**Platform:** Web

**Description:**
Admin interface to review disputes and determine outcomes.

**References:**
- `src/features/disputes/DisputesList.tsx`
- `src/features/disputes/DisputeDetail.tsx`

**Acceptance Criteria:**
- [x] List all open disputes. — Done (against simplified model): `web/src/features/disputes/pages/DisputesPage.tsx` + `hooks/useDisputes.ts`, defaults to `Open` filter with All/Open/Resolved/Escalated tabs.
- [x] Detail view shows job context, both parties, chat history, time logs (check-in/out), and all `DisputeEvidence`.
- [x] Form to resolve dispute: select outcome (Full/Partial/No Refund), input `DecisionNote`.
- [x] On submit, update `Dispute` status to Resolved, and trigger refund generation if applicable.

## P7-07: Account Flagging Background/Service Logic
**Platform:** Backend

**Description:**
Monitor flags and apply thresholds.

**References:**
- `Services/AccountFlagService.cs`

**Acceptance Criteria:**
- [x] Logic to increment flag counters for specific types (e.g., `RepeatCanceller`).
- [x] If counter reaches threshold, set `ThresholdHit = true`.
- [x] Optionally trigger automatic actions (e.g., temporary suspension) or notify admin to review.

## P7-08: Admin Account Flags UI
**Platform:** Web

**Description:**
Admin interface to view flagged accounts and take action.

**References:**
- `src/features/users/UsersList.tsx`

**Acceptance Criteria:**
- [x] Add filter/view for users with `ThresholdHit == true`.
- [x] View flag history on user profile.
- [x] Allow admin to warn user, suspend account, or mark flags as resolved.
