# M4 — Reviews & Scheduling

Depends on: M3 (Chat & Job Status complete)

## Overview

Close the accountability loop with post-job reviews (both directions) and formalize scheduling with date/time confirmation and Hangfire-powered reminders. This is Tier 2 from `docs/MVP-SPEC.md`.

> **Mobile UI status (2026-09-27):** All M4 tasks complete. Rating sheet wired to live API with character counter. Profile reviews paginated from live endpoint. Scheduling UI (`ScheduleSheet`) added to chat screen. Aggregated rating pulled from M4-03 API. Hangfire reminders backed by Redis.

---

## Tasks

### M4-01: Review entity & migrations

- **Platform**: Backend
- **Description**: Create `Review` entity: `Id`, `JobId` (FK → Job), `ReviewerId` (FK → ApplicationUser), `RevieweeId` (FK → ApplicationUser), `Rating` (int, 1–5), `Comment` (text, max 1000 chars), `CreatedAtUtc`. Unique constraint: one review per reviewer per job. Add EF Core migration.
- **Acceptance criteria**:
  - [x] Migration runs cleanly — `20260927065131_AddReviewsAndScheduling` applied
  - [x] Unique constraint on (JobId, ReviewerId) — `IX_Reviews_JobId_ReviewerId` UNIQUE index
  - [x] Rating constrained to 1–5 — `CK_Review_Rating` CHECK constraint in DB
  - [x] Both homeowner and tradie can review each other for same job — RevieweeId is any participant

### M4-02: Review CRUD API

- **Platform**: Backend
- **Description**: Create endpoints: `POST /api/jobs/{id}/reviews` (submit review), `GET /api/jobs/{id}/reviews` (list reviews for a job), `GET /api/users/{id}/reviews` (list reviews received by a user, paginated). Only allow review submission for completed jobs, by participants only.
- **References**: `.agent/rules/backend.md` § Controller Purity
- **Acceptance criteria**:
  - [x] `IReviewService` with validation logic — `backend/Services/IReviewService.cs`
  - [x] Can only review completed jobs — enforced in `ReviewService.SubmitReviewAsync`
  - [x] Can only review once per job — DB unique constraint + service check
  - [x] 400 if reviewing yourself — `revieweeId == reviewerId` guard
  - [x] FluentValidation on input — `SubmitReviewRequestValidator`

### M4-03: Aggregated rating on user profile

- **Platform**: Backend
- **Description**: Add computed fields to user profile response: `AverageRating` (decimal), `ReviewCount` (int). Calculate from reviews where user is reviewee. Update `GET /api/profile/{id}` to include these.
- **Acceptance criteria**:
  - [x] Average calculated as decimal (not rounded int) — `Math.Round((decimal)avg, 1)`
  - [x] Returns 0 / 0 count for users with no reviews — default `0m` / `0`
  - [x] Included in tradie card responses for matching — `MatchingService` batch-fetches ratings

### M4-04: Review notification

- **Platform**: Backend
- **Description**: When a review is submitted, notify the reviewee via SignalR (`ReviewReceived` event on `JobHub`) and FCM push. Include reviewer name, rating, and job title.
- **Acceptance criteria**:
  - [x] SignalR event to reviewee only — `_hub.Clients.User(revieweeId).SendAsync("ReviewReceived", ...)`
  - [x] FCM push with deep link to profile/reviews — data `link: /profile/{id}/reviews`
  - [x] Does not reveal review comment in push — push body is "You received a review"

### M4-05: Rating/review screen (Flutter)

- **Platform**: Mobile
- **Acceptance criteria**:
  - [x] Star rating widget (custom, using design tokens)
  - [x] Comment field with character count — `maxLength: 1000`, custom `buildCounter` showing `n / 1000`
  - [x] Submit calls live `POST /api/jobs/{id}/reviews` via `ReviewsRepository.submitReview`
  - [x] Success state with confirmation — green check icon + "Review submitted!" then auto-dismiss
  - [x] Skip option (can dismiss without reviewing)
  - [x] Both light and dark theme

### M4-06: Profile screen — reviews tab (Flutter)

- **Platform**: Mobile
- **Acceptance criteria**:
  - [x] Section on profile screen
  - [x] Paginated review list — `_ReviewsNotifier` loads via `GET /api/users/{id}/reviews?page=&pageSize=10`, scroll-triggered load-more
  - [x] Star display widget (read-only) — 5-star row, filled with `amberDark`
  - [x] Both light and dark theme

### M4-07: Scheduling confirmation entity & API

- **Platform**: Backend
- **Acceptance criteria**:
  - [x] Only job participants can propose/confirm — `UnauthorizedAccessException` guard
  - [x] Scheduling only for Confirmed jobs — `JobStatus.Confirmed` check
  - [x] SignalR event `ScheduleProposed` / `ScheduleConfirmed` — via `_hub.Clients.Group(JobHub.GroupName(jobId))`
  - [x] FCM push on schedule proposal — `SendSchedulePushAsync` to other party

### M4-08: Scheduling UI (Flutter)

- **Platform**: Mobile
- **Acceptance criteria**:
  - [x] Date picker with minimum date = tomorrow — `firstDate: DateTime.now().add(Duration(days: 1))`
  - [x] Time slot selector (not free-text time) — Morning / Afternoon / Evening chip row with icons
  - [x] Shows current schedule status (proposed / confirmed) — `_StatusPill` widget
  - [x] Both light and dark theme
  - Schedule button visible in `ChatScreen` AppBar when job is Confirmed/InProgress

### M4-09: Hangfire reminder jobs

- **Platform**: Backend
- **Acceptance criteria**:
  - [x] Uses `BackgroundJob.Schedule`, not `Task.Delay` — `IBackgroundJobClient.Schedule<ScheduleReminderService>(...)`
  - [x] Hangfire backed by Redis — `UseRedisStorage(redis, ...)` in `Program.cs`
  - [x] Cancelled jobs have their reminders removed — `JobStatusService.TransitionAsync` cancels on `→ Cancelled`
  - [x] Reminder push includes job title and scheduled time — in `ScheduleReminderService.SendReminderAsync`
  - [x] Idempotent: rescheduling replaces old reminders — `CancelExistingReminders` before enqueue

### M4-10: Tradie profile page (Flutter)

- **Platform**: Mobile
- **Acceptance criteria**:
  - [x] Displays aggregated rating from M4-03 — `GET /api/profile/{id}` → `UserProfile.averageRating`
  - [x] Verification badge (static "✓ Verified" pill shown when `isVerified == true`)
  - [x] Edit mode for own profile (`profile_screen.dart`)
  - [x] Both light and dark theme

---

## Dependencies

- M3 complete (chat, job status transitions, SignalR hubs)
- Hangfire + Redis running (docker-compose)

## Key risks

- Timezone handling for scheduled reminders (all UTC server-side, localized in push copy) — handled
- Review gaming (addressed post-MVP with moderation tools)
