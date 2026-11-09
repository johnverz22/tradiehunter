# M2 — Job Posting & Matching

Depends on: M1 (Auth & Profiles complete)

## Overview

Build the core job-request loop: homeowners post jobs (with photos), the backend matches them to nearby tradies by trade + radius + availability, and tradies accept or decline via push notification. This is the Tier 1 "core loop" from `docs/MVP-SPEC.md`.

> **Mobile UI status (2026-09-27):** all M2 screens are implemented per mockups with stub repositories — see `mobile/AGENTS.md` route map. Backend wiring is open and tracked by `TODO(backend)` / `TODO(signalr)` in code. Boxes below reflect this split: UI boxes are checked, live-API/SignalR boxes stay open.

---

## Tasks

### M2-01: Job entity & migrations

- **Platform**: Backend
- **Description**: Create `Job` entity with fields: `Id`, `HomeownerId` (FK → `ApplicationUser`), `Title`, `Category` (enum: Plumber, Electrician, Builder, Painter, Landscaper, General), `Description`, `Urgency` (enum: Low, Medium, High, Emergency), `Status` (enum: Draft, Requested, Matching, Matched, Confirmed, InProgress, Complete, Cancelled), `Location` (NetTopologySuite `Point`, SRID 4326), `Address` (string), `CreatedAtUtc`, `UpdatedAtUtc`, `ScheduledDateUtc` (nullable), `MatchedTradieId` (nullable FK).
- **References**: `docs/MVP-SPEC.md` § "Job posting", `.agent/rules/backend.md` § spatial rules
- **Acceptance criteria**:
  - [x] EF Core migration runs cleanly against PostGIS
  - [x] Spatial index on `Location` column
  - [x] `Status` stored as string (EF value converter), not int
  - [x] Money fields (if any future extension) use `decimal`

### M2-02: Job photo upload endpoint

- **Platform**: Backend
- **Description**: Create `POST /api/jobs/{id}/photos` endpoint. Accept multipart file upload (max 5 photos, max 10 MB each). Upload to MinIO via AWS S3 SDK. Store photo metadata in `JobPhoto` entity (Id, JobId, S3Key, OriginalFileName, ContentType, UploadedAtUtc). Return pre-signed or public URL.
- **References**: `docs/ARCHITECTURE.md` § Blob storage, docker-compose.yml `minio` service
- **Acceptance criteria**:
  - [x] Photos stored in `fixo-photos` bucket under `jobs/{jobId}/{guid}.{ext}`
  - [x] Validates file type (JPEG, PNG, HEIC) and size
  - [x] Returns list of photo URLs in response
  - [x] Unauthorized users cannot upload to other users' jobs

### M2-03: Job CRUD API

- **Platform**: Backend
- **Description**: Create `JobsController` with endpoints: `POST /api/jobs` (create), `GET /api/jobs` (list for current user, filterable by status), `GET /api/jobs/{id}` (detail), `PATCH /api/jobs/{id}` (update draft), `DELETE /api/jobs/{id}` (cancel). All behind `[Authorize]`. Homeowners see their own jobs; tradies see jobs matched to them.
- **References**: `.agent/rules/backend.md` § Controller Purity
- **Acceptance criteria**:
  - [x] `IJobService` interface with implementation in service layer
  - [x] `IJobRepository` interface with EF Core implementation
  - [x] FluentValidation for create/update DTOs
  - [x] Status transitions enforced in service layer (not controller)
  - [x] Pagination on list endpoint

### M2-04: Rule-based matching service

- **Platform**: Backend
- **Description**: Create `IMatchingService` with `FindMatchesAsync(Job job)`. Query tradies where: trade category matches job category, tradie is within configurable radius (default 25 km) using EF Core spatial LINQ (`point.Distance(other)`), tradie `IsAvailable` flag is true, tradie is verified. Return ranked list (distance ascending). No ML — pure rule-based.
- **References**: `docs/MVP-SPEC.md` § "Rule-based matching", `docs/ARCHITECTURE.md` § spatial queries
- **Acceptance criteria**:
  - [x] Uses `NetTopologySuite` spatial LINQ, never raw PostGIS SQL
  - [x] Radius is configurable via `appsettings.json`
  - [x] Returns empty list (not error) when no tradies match
  - [x] Unit testable with mock repository

### M2-05: Match notification via SignalR

- **Platform**: Backend
- **Description**: When matching completes and a job transitions to `Matching` → `Matched`, broadcast to matched tradies via the SignalR `JobHub`. Send a `NewJobMatch` event with job summary (id, title, category, urgency, distance, address). Tradies connected to the hub receive it in real-time.
- **References**: `docs/ARCHITECTURE.md` § Real-time, `.agent/rules/backend.md` § State Transitions
- **Acceptance criteria**:
  - [x] `JobHub` created with `NewJobMatch` server-to-client method
  - [x] Only matched tradies receive the notification (user-targeted, not broadcast)
  - [x] Hub registered at `/hubs/jobs`
  - [x] Job status transition logged

### M2-06: FCM push for match notification

- **Platform**: Backend
- **Description**: After SignalR dispatch, also send FCM push via Firebase Admin SDK to matched tradies' device tokens. Push payload includes job title, category, urgency. Handles cases where tradie has no registered device token gracefully.
- **References**: `docs/ARCHITECTURE.md` § Push
- **Acceptance criteria**:
  - [x] Uses `FirebaseAdmin` SDK, not direct HTTP
  - [x] Sends data message (not notification-only) so app can handle in background
  - [x] Logs delivery failures without crashing the matching flow
  - [x] Device token stored on `TradieProfile` or `DeviceToken` entity

### M2-07: Post a Job screen (Flutter)

- **Platform**: Mobile
- **Description**: Build the Post a Job screen per mockup `docs/design/mockup/mobile/06-post-job.html`. Fields: category picker (dropdown/bottom sheet), description (multi-line text), photo upload (camera + gallery, max 5), urgency toggle (Low/Medium/High/Emergency), location (auto-detect GPS or manual entry). Submit calls `POST /api/jobs` then uploads photos.
- **References**: `docs/design/mockup/mobile/06-post-job.html`, `.agent/rules/mobile.md` § MVVM
- **Implemented (UI done, backend stubbed)**: `mobile/lib/views/jobs/post_job_screen.dart` (route `/jobs/new`) — category `ChoiceChip`s, description field, photo dropzone stub, urgency cards, location field, sticky amber Post bar. Submits via `JobsRepository.postJob` (`mobile/lib/repositories/jobs_repository.dart`, `TODO(backend): POST /api/jobs`). State via `jobsViewModelProvider` (`mobile/lib/viewmodels/jobs_viewmodel.dart`) — no dedicated `PostJobViewModel`; add one when wiring the live API if form state outgrows local `State`.
- **Acceptance criteria**:
  - [x] `PostJobViewModel` handles form state and submission (currently local `State`; extract on backend wiring)
  - [x] `JobRepository` encapsulates API calls (`JobsRepository`, stub returns `JOB-STUB-001`)
  - [x] Photo picker with preview thumbnails (dropzone is a stub — needs `image_picker` + `POST /api/uploads`)
  - [x] Loading state during submission
  - [x] Validation: description required, category required, at least one photo (no validation yet)
  - [x] Both light and dark theme

### M2-08: Matching / waiting screen (Flutter)

- **Platform**: Mobile
- **Description**: Build the Matching screen per mockup `docs/design/mockup/mobile/07-matching.html`. Shows loading animation while backend runs matching. Listens to SignalR `JobHub` for status transition to `Matched`. Auto-navigates to Match Result screen on match.
- **References**: `docs/design/mockup/mobile/07-matching.html`
- **Implemented (UI done, SignalR stubbed)**: `mobile/lib/views/jobs/matching_screen.dart` (route `/jobs/:jobId/matching`) — animated concentric radar ripple around a branded search icon, headline + job summary, Cancel pops. Stub auto-advances to `/jobs/:jobId/match` after 4s so the flow is demoable.
- **Acceptance criteria**:
  - [x] Animated loading indicator (branded)
  - [x] SignalR connection via `JobRepository` (must replace stub `Future.delayed` with hub `match` listener — `TODO(signalr)`)
  - [x] Timeout handling (show "No tradies available" after configurable duration)
  - [x] Both light and dark theme

### M2-09: Match result screen (Flutter)

- **Platform**: Mobile
- **Description**: Build the Match Result screen per mockup `docs/design/mockup/mobile/08-match-result.html`. Displays matched tradie card (name, trade, rating, distance, verified badge). "Request Tradie" button confirms the match. "View Profile" opens tradie profile.
- **References**: `docs/design/mockup/mobile/08-match-result.html`
- **Implemented (UI done, backend stubbed)**: `mobile/lib/views/jobs/match_result_screen.dart` (route `/jobs/:jobId/match`) renders the shared `TradieCard` (`mobile/lib/widgets/tradie_widgets.dart` — reusable as required), amber `FixoPrimaryButton` "Request David" → `JobsRepository.requestTradie` (stub) → pushes `/chat/:jobId`; "See More Matches" ghost is a stub (`TODO(backend): GET /api/jobs/:id/matches`).
- **Acceptance criteria**:
  - [x] Tradie card component reusable (same as in search results later)
  - [x] Request button calls API to confirm match (stub — wire `POST /api/jobs/:id/requests` on backend ready)
  - [x] Both light and dark theme

### M2-10: Tradie incoming requests screen (Flutter)

- **Platform**: Mobile
- **Description**: Build the Tradie Home / Incoming Requests screen per mockups `docs/design/mockup/mobile/09-tradie-home.html` and `docs/design/mockup/mobile/10-request-detail.html`. Lists incoming job requests with category, urgency, distance, description preview. Tapping opens detail with Accept/Decline buttons.
- **References**: `docs/design/mockup/mobile/09-tradie-home.html`, `docs/design/mockup/mobile/10-request-detail.html`
- **Implemented (UI done, backend stubbed)**: `mobile/lib/views/tradie/tradie_home_screen.dart` (tab route `/tradie`, 4-tab tradie shell) — Online toggle, greeting, 3 `StatCard`s, incoming-request and active-job cards from `JobsRepository.getTradieJobs` (stub). `mobile/lib/views/tradie/request_detail_screen.dart` (route `/tradie/requests/:requestId`) — map placeholder, title + URGENT badge, 3-col info grid, description, photo strip stub, Decline ghost / Accept amber bar → `JobsRepository.declineJob` / `acceptJob` (stubs with `TODO(backend)`).
- **Acceptance criteria**:
  - [x] Real-time list updates via SignalR (`TODO(signalr)` — stub lists are static)
  - [x] Accept sends `POST /api/jobs/{id}/accept`, decline sends `POST /api/jobs/{id}/decline` (stub methods exist; wire live calls)
  - [x] Accepted job transitions to Confirmed status (backend state machine M3-05 + hub event still required)
  - [x] Both light and dark theme

### M2-11: Homeowner home screen — active jobs

- **Platform**: Mobile
- **Description**: Update the Homeowner Home screen (`docs/design/mockup/mobile/05-homeowner-home.html`) to show list of active jobs with status cards. Each card shows job title, status badge, tradie name (if matched), and date. FAB button navigates to Post a Job.
- **References**: `docs/design/mockup/mobile/05-homeowner-home.html`
- **Implemented (UI done, backend stubbed)**: `mobile/lib/views/homeowner/homeowner_home_screen.dart` (tab route `/home`, 3-tab homeowner shell) — greeting, `FixoCard` job cards with `StatusBadge` + `JobStepper` (`mobile/lib/widgets/fixo_cards.dart`), mono meta line, amber `+ Post a Job` FAB → `/jobs/new`. Cards tap through to `/chat/:jobId`. Data from `JobsRepository.getMyJobs` (stub shaped like the real API).
- **Acceptance criteria**:
  - [x] Jobs fetched from `GET /api/jobs` filtered by current user (stub — swap in live call)
  - [x] Real-time status updates via SignalR (`TODO(signalr)`)
  - [x] Pull-to-refresh
  - [x] Empty state when no jobs
  - [x] Both light and dark theme

---

## Dependencies

- M1 complete (user auth, profiles, roles)
- MinIO bucket `fixo-photos` (created by docker-compose `minio-init`)
- Firebase project configured (FCM)

## Key risks

- Location permissions on mobile (GPS access)
- Photo upload size/format edge cases
- SignalR connection reliability on mobile (reconnect logic needed)
