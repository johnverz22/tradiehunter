# Phase 5: Booked to Completed Lifecycle

This phase implements the job execution lifecycle, moving a job from `Booked` through `InProgress`, `AwaitingConfirmation`, to `Completed`. It includes privacy rules around location details, check-in/out logic for tradies, automated completion, and rating/review updates.

## P5-01: Address Privacy Logic
**Platform:** Backend  
**Description:** 
Ensure the exact job address and homeowner contact details are hidden until the job is explicitly `Booked`. Prior to that, only approximate location should be shared with tradies.
- Modify `JobDto` mapping so that exact address strings and phone numbers are conditionally returned.
- If `JobStatus` < `Booked` and the requesting user is a Tradie, mask exact address fields (return city/suburb only).

**References:**
- `DTOs/Jobs/JobDto.cs`
- `Controllers/JobsController.cs`

**Revises:**
- `Controllers/JobsController.cs` (Map method or automapper profile)

**Acceptance Criteria:**
- [x] Tradies requesting job details for a job not yet booked see masked/approximate location.
- [x] Once `Booked`, the full address and contact details become visible to the assigned tradie.
- [x] Homeowners always see their own full details.

## P5-02: Job Execution Fields and Status Transitions
**Platform:** Backend  
**Description:** 
Add temporal fields to track job execution and implement the required status transitions.
- Add `StartedAtUtc` and `EndedAtUtc` to `Job` entity. Update migration.
- Add `POST /api/jobs/{id}/check-in`: Transitions job to `InProgress`, sets `StartedAtUtc = DateTime.UtcNow`.
- Add `POST /api/jobs/{id}/check-out`: Transitions job to `AwaitingConfirmation`, sets `EndedAtUtc = DateTime.UtcNow`.
- Add `POST /api/jobs/{id}/confirm`: Transitions job to `Completed`.
- Update `IJobStatusService` to support these new valid transitions.

**References:**
- `Models/Job.cs`
- `Services/Jobs/JobStatusService.cs`
- `Controllers/JobsController.cs`

**Revises:**
- `Models/Job.cs`
- `Services/Jobs/JobStatusService.cs`
- `Controllers/JobsController.cs`
- `Data/ApplicationDbContext.cs`

**Acceptance Criteria:**
- [x] Migration applied for `StartedAtUtc` and `EndedAtUtc`.
- [x] `check-in` sets `InProgress` and records start time (Tradie only).
- [x] `check-out` sets `AwaitingConfirmation` and records end time (Tradie only).
- [x] `confirm` sets `Completed` (Homeowner only).

## P5-03: Pre-job Reminders via Hangfire
**Platform:** Backend  
**Description:** 
Schedule a reminder to be sent out one hour before the scheduled start time of the job.
- When a job becomes `Booked`, calculate `ScheduledDateUtc - 1 hour`.
- Schedule a Hangfire background job to trigger push notifications to both the Homeowner and Tradie.

**References:**
- `Services/Jobs/JobStatusService.cs`
- `Jobs/PreJobReminderJob.cs` (New)

**Revises:**
- `Services/Jobs/JobStatusService.cs`

**Acceptance Criteria:**
- [x] Job correctly schedules a Hangfire task for the reminder.
- [x] Task execution triggers a push notification to both parties.
- [x] If the job is cancelled before the reminder time, the scheduled task is aborted/deleted.

## P5-04: Auto-complete Background Job
**Platform:** Backend  
**Description:** 
If the homeowner forgets to manually confirm the job after the tradie checks out, the system should auto-complete the job after N hours (e.g., 48 hours).
- On check-out (transition to `AwaitingConfirmation`), schedule a Hangfire background task to fire in N hours.
- When task fires, check if the job is still `AwaitingConfirmation`. If yes, transition to `Completed`.

**References:**
- `Services/Jobs/JobStatusService.cs`
- `Jobs/AutoCompleteJob.cs` (New)

**Revises:**
- `Services/Jobs/JobStatusService.cs`

**Acceptance Criteria:**
- [x] Hangfire task is scheduled on `check-out`.
- [x] If homeowner confirms manually, the scheduled job becomes a no-op or is cancelled.
- [x] Task successfully transitions job to `Completed` if no action is taken.

## P5-05: Review Status Field Expansion
**Platform:** Backend  
**Description:** 
Update the existing `Review` model to add a `Status` field to handle moderation workflows.
- Add `Status` (string) to `Review` with EF HasConversion (e.g., Visible, Disputed, Removed).
- Create migration.
- Add a job completion hook: once `Completed`, push a notification encouraging both parties to leave a rating and review.

**References:**
- `Models/Review.cs`
- `Data/ApplicationDbContext.cs`
- `Controllers/ReviewsController.cs`

**Revises:**
- `Models/Review.cs`
- `Data/ApplicationDbContext.cs`
- `Controllers/ReviewsController.cs`

**Acceptance Criteria:**
- [x] Migration applied adding `Status` to `Reviews`.
- [x] Default status is `Visible`.
- [x] Prompts/Notifications to review are sent when job status is changed to `Completed`.

## P5-06: Mobile Execution UI (Tradie)
**Platform:** Mobile  
**Description:** 
Update the Tradie Dashboard and Job Detail screens to support check-in and check-out actions.
- Show "Check In" button when job is `Booked` and current time is close to `ScheduledDateUtc`.
- Show "Check Out" button when job is `InProgress`.
- Ensure exact address only displays if status >= `Booked`.

**References:**
- `lib/ui/screens/job_detail/tradie_job_detail_screen.dart`
- `lib/repositories/jobs_repository.dart`

**Revises:**
- `lib/ui/screens/job_detail/tradie_job_detail_screen.dart`
- `lib/repositories/jobs_repository.dart`

**Acceptance Criteria:**
- [x] Buttons are conditionally rendered based on job state.
- [x] Check-in and check-out API calls correctly update the UI.
- [x] Address remains hidden appropriately.

## P5-07: Mobile Execution UI (Homeowner)
**Platform:** Mobile  
**Description:** 
Update Homeowner Job Detail screens to support manual confirmation and review prompt.
- Show "Confirm Completion" button when job is `AwaitingConfirmation`.
- Show "Leave Review" button/modal when job is `Completed` and no review exists.

**References:**
- `lib/ui/screens/job_detail/homeowner_job_detail_screen.dart`
- `lib/ui/screens/reviews/create_review_screen.dart` (New or revise existing)

**Revises:**
- `lib/ui/screens/job_detail/homeowner_job_detail_screen.dart`

**Acceptance Criteria:**
- [x] User can click to confirm the job completion successfully.
- [x] UI prompts for a review once job transitions to `Completed`.
- [x] Stepper component updates accurately through the entire lifecycle.

## P5-08: Update Chat Access Constraints
**Platform:** Backend & Mobile  
**Description:** 
Refine chat logic. Ensure parties can only communicate if the job is `Matched`, `Booked`, or `InProgress`. Close the chat or mark as read-only once the job is `Completed` or `Cancelled`.
- Update `ChatHub.cs` and `ChatService.cs` to block new messages if the job status is beyond the active phases.
- Update mobile UI to disable the message input field when chat is locked.

**References:**
- `Services/Chat/ChatService.cs`
- `Hubs/ChatHub.cs`
- `lib/ui/screens/chat/chat_screen.dart`

**Revises:**
- `Services/Chat/ChatService.cs`
- `Hubs/ChatHub.cs`
- `lib/ui/screens/chat/chat_screen.dart`

**Acceptance Criteria:**
- [x] Backend returns an error or silently rejects messages if chat is locked for the job.
- [x] Mobile app hides/disables text input and shows a "Chat is closed" banner on completed/cancelled jobs.
