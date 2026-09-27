# Fixo — E2E Happy Path Test Script (M5-09)

**Version**: 1.0  
**Date**: 2026-09-27  
**Environment**: Local dev stack (`docker compose up` + Flutter emulator + React admin on `localhost:5173`)  
**Scope**: Full happy path from registration → job post → match → accept → chat → schedule → start → complete → review, observed from both mobile (Flutter) and admin web.

---

## Prerequisites

1. `docker compose up` running (DB, Redis, MinIO, API).  
2. `cd mobile && flutter run` on Android emulator or iOS simulator.  
3. `cd web && npm run dev` for admin dashboard at `http://localhost:5173`.  
4. API reachable at `http://localhost:5000`.  
5. Admin seed user exists (see M5-10 seed migration). Default: `admin@fixo.nz` / `Admin1!`.

---

## Test Accounts

| Role | Name | Email | Password |
|------|------|-------|----------|
| Homeowner | Sarah Test | `sarah@test.nz` | `Test1234!` |
| Tradie | James Test | `james@test.nz` | `Test1234!` |
| Admin | Fixo Admin | `admin@fixo.nz` | `Admin1!` |

Create Sarah and James via the app signup flow (steps 1–2), or use the seed script.

---

## Step 1 — Homeowner Registration (Mobile: Sarah)

**Actor**: Sarah (homeowner)  
**Screen**: Splash → Onboarding → Signup (`/signup`)

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 1.1 | Launch app | Splash screen renders with Fixo wordmark | | |
| 1.2 | Tap "Get Started" on onboarding | Sign-up screen appears | | |
| 1.3 | Enter name: "Sarah Test", email: `sarah@test.nz`, password: `Test1234!` | Form accepts input | | |
| 1.4 | Select role: Homeowner | Role chip highlights | | |
| 1.5 | Tap "Create account" | `POST /api/auth/register` 201 → JWT stored → Home screen loads | | |
| 1.6 | Home screen shows "Post a Job" FAB | Job list empty | | |

**Backend state**: `ApplicationUser` created with `Role=Homeowner`, `IsActive=true`.

---

## Step 2 — Tradie Registration (Mobile: James)

**Actor**: James (tradie)  
**Screen**: Signup (`/signup`) — use a second emulator/device or sign out of Sarah's session temporarily.

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 2.1 | Register `james@test.nz` with role Tradie | `POST /api/auth/register` 201 | | |
| 2.2 | Complete tradie profile: trade type "Plumber", address (Auckland), service radius 25km | `PUT /api/profile` 200 | | |
| 2.3 | Note: James is **not yet verified** (admin verifies in Step 3) | IsVerified = false on TradieProfile | | |

**Backend state**: `ApplicationUser` (Tradie) + `TradieProfile` (IsVerified=false, IsAvailable=true).

---

## Step 3 — Admin Verifies Tradie (Web: Admin)

**Actor**: Admin  
**Screen**: Admin dashboard → Users → James Test → Verify

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 3.1 | Open `http://localhost:5173/login` | Admin login page renders | | |
| 3.2 | Sign in as `admin@fixo.nz` / `Admin1!` | JWT stored, redirect to `/dashboard` | | |
| 3.3 | Navigate to Users | UserListPage shows Sarah and James | | |
| 3.4 | Find James → click "Verify" | Confirmation modal appears | | |
| 3.5 | Confirm verification | `POST /api/admin/users/{id}/verify` 204 → badge changes to Verified | | |

**Backend state**: `TradieProfile.IsVerified = true`.

---

## Step 4 — Homeowner Posts a Job (Mobile: Sarah)

**Actor**: Sarah  
**Screen**: Home → Post a Job (`/jobs/new`)

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 4.1 | Tap "Post a Job" FAB on home screen | Post Job screen opens | | |
| 4.2 | Select category: Plumbing | Category chip highlights | | |
| 4.3 | Enter description: "Leaking pipe under kitchen sink, need fix ASAP" | Input accepted | | |
| 4.4 | Set urgency: High | Urgency toggle active | | |
| 4.5 | Set location: Auckland (enter suburb or allow location) | Address populated | | |
| 4.6 | (Optional) attach a photo | Photo thumbnail previewed | | |
| 4.7 | Tap "Post Job" | `POST /api/jobs` 201 → job created with `Status=Requested` → matching screen auto-advances (`/jobs/:jobId/matching`) | | |

**Backend state**: `Job` with Status=Requested, Category=Plumbing.

---

## Step 5 — Matching Runs (Backend + Mobile: Sarah)

**Actor**: System + Sarah  
**Screen**: Matching screen (`/jobs/:jobId/matching`) — spinner while match resolves

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 5.1 | Matching screen shows progress animation | UI responsive | | |
| 5.2 | Backend runs matching: `GET /api/jobs/{id}/matches` | James (plumber, Auckland, verified, available) returned | | |
| 5.3 | Screen advances to match result (`/jobs/:jobId/match`) | James's tradie card shown (name, trade, rating, distance) | | |
| 5.4 | Verify `Job.Status = Matched` in admin | Admin → Jobs → find the job → Status badge = Matched | | |

**Backend state**: `Job.MatchedTradieId = James.Id`, `Job.Status = Matched`.

---

## Step 6 — Homeowner Sends Request (Mobile: Sarah)

**Actor**: Sarah  
**Screen**: Match result (`/jobs/:jobId/match`)

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 6.1 | Review James's card | Rating, distance, trade displayed | | |
| 6.2 | Tap "Request James" | `POST /api/jobs/{id}/requests` 200 → FCM push sent to James's device | | |
| 6.3 | Job status advances to `Confirmed` stage pending James's accept | Status = Confirmed in job stepper | | |

---

## Step 7 — Tradie Accepts (Mobile: James)

**Actor**: James  
**Screen**: Tradie home → Incoming request (`/tradie/requests/:requestId`)

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 7.1 | James receives FCM push notification | "New job request: Plumbing" notification arrives | | Requires real device or emulator with FCM configured |
| 7.2 | Tap notification → Request detail screen | Job info, homeowner name, distance displayed | | |
| 7.3 | Tap "Accept" | `POST /api/jobs/{id}/accept` 200 → SignalR broadcasts `JobStatusChanged` | | |
| 7.4 | Both Sarah and James see status update via SignalR | Chat opens automatically on both sides | | |

**Backend state**: `Job.Status = Confirmed`.

---

## Step 8 — In-App Chat (Mobile: Both)

**Actor**: Sarah + James  
**Screen**: Chat (`/chat/:jobId`)

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 8.1 | Sarah sends message: "Hi James, can you come tomorrow morning?" | Message delivered via SignalR, appears in James's chat | | |
| 8.2 | James replies: "Sure, I can be there by 9am" | Message appears in Sarah's chat | | |
| 8.3 | Admin views chat transcript | Admin → Jobs → [the job] → Chat tab shows full transcript | | |

---

## Step 9 — Schedule Confirmed (Mobile: Either party)

**Actor**: James (or Sarah)  
**Screen**: Chat / Schedule  

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 9.1 | James proposes schedule: tomorrow 9:00 AM | `POST /api/jobs/{id}/schedule` → `ScheduleStatus=Proposed` | | |
| 9.2 | Sarah confirms schedule | `POST /api/jobs/{id}/schedule` confirm → `ScheduleStatus=Confirmed` | | |
| 9.3 | Hangfire schedules reminder jobs (24h + 1h before) | Check Hangfire dashboard at `http://localhost:5000/hangfire` | | |

---

## Step 10 — Job Started (Mobile: James)

**Actor**: James  

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 10.1 | James marks job as started | `POST /api/jobs/{id}/start` → `Job.Status = InProgress` → SignalR broadcast | | |
| 10.2 | Sarah sees status update | Job stepper advances to InProgress | | |

**Backend state**: `Job.Status = InProgress`.

---

## Step 11 — Job Completed (Mobile: Sarah)

**Actor**: Sarah  

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 11.1 | Sarah marks job complete | `POST /api/jobs/{id}/complete` → `Job.Status = Complete` → SignalR broadcast | | |
| 11.2 | Rating modal appears for both parties | `RatingSheet.show()` on both devices | | |
| 11.3 | Sarah rates James: 5 stars, "Fast and professional" | `POST /api/jobs/{id}/reviews` 201 | | |
| 11.4 | James rates Sarah: 5 stars | `POST /api/jobs/{id}/reviews` 201 | | |

**Backend state**: `Job.Status = Complete`, 2 `Review` records.

---

## Step 12 — Admin Views Completed Job (Web: Admin)

**Actor**: Admin  

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 12.1 | Admin → Jobs → filter by "Complete" | Job appears in list | | |
| 12.2 | Click job → Info tab | Status=Complete, participants shown, scheduled date | | |
| 12.3 | Chat tab | Full transcript (Steps 8.1–8.2) visible | | |
| 12.4 | Timeline tab | All status transitions listed in order: Draft→Requested→Matching→Matched→Confirmed→InProgress→Complete | | |
| 12.5 | Dashboard → Metrics section | Review completion rate > 0% | | |

---

## Step 13 — Dispute Flow (Optional smoke test)

| # | Action | Expected Result | Pass/Fail | Notes |
|---|--------|-----------------|-----------|-------|
| 13.1 | Create a second job, leave it in Confirmed state | Job exists | | |
| 13.2 | Homeowner flags job via `POST /api/jobs/{id}/flag` with reason "Tradie no-show" | `Job.IsFlagged=true`, `DisputeStatus=Open` | | |
| 13.3 | Admin → Disputes → Open tab | Flagged job appears | | |
| 13.4 | Admin clicks Review → sees flag reason, chat, parties | Detail page renders | | |
| 13.5 | Admin marks Resolved with a note | `POST /api/admin/disputes/{jobId}/resolve` → status changes | | |

---

## Expected State at Completion

| Entity | Expected State |
|--------|---------------|
| Sarah (user) | Role=Homeowner, IsActive=true, 1+ jobs |
| James (user) | Role=Tradie, IsActive=true, IsVerified=true |
| Job | Status=Complete, ScheduleStatus=Confirmed, IsFlagged=false |
| Reviews | 2 reviews for the job (one each direction) |
| StatusHistory | 7 entries: Draft→Requested→Matching→Matched→Confirmed→InProgress→Complete |
| Dashboard metrics | ActivationRate > 0%, ReviewCompletionRate = 100% for window containing this job |

---

## Known Limitations / Bugs Found

Document any failures here during execution:

| Step | Issue | Severity | Workaround |
|------|-------|----------|-----------|
| 7.1 | FCM push requires real device or Firebase emulator; simulator may not receive push | Medium | Use Hangfire dashboard to trigger manually, or test accept via HTTP client |
| 5.2 | Matching stub data used in `/jobs/:jobId/matching` auto-advance (see `mobile/AGENTS.md` TODO(signalr)) | Low | Demo flow works; production wiring is backend-ready |
| — | — | — | — |

---

## Running as Automated Integration Test

A future automated version would use:
- **Backend**: `WebApplicationFactory<Program>` (.NET integration tests) against an in-memory Npgsql test database.
- **API client**: `HttpClient` for REST steps; `TestServer` + SignalR client for hub events.
- **Mobile**: Flutter integration test (`flutter drive`) against a stub backend that replays fixture responses.

The manual script above is the MVP-acceptable deliverable. Automated tests are scoped for V1.1 when CI is established.
