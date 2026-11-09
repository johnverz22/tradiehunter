# Phase 3: Matching with Offers and Timeouts

## P3-01: job_offers Entity and Migration
- **Platform**: Backend
- **Description**: Create the `JobOffer` entity to track individual offers sent to tradies, replacing the broadcast mechanism. Add EF Core migration.
- **References**: `Models/JobOffer.cs` (new)
- **Revises**: 
  - `Data/ApplicationDbContext.cs`
- **Acceptance Criteria**:
  - [x] `JobOffer` model with `Id`, `JobId`, `TradieId`, `OfferedAtUtc`, `ExpiresAtUtc`, `Response`, `Stage`, `HangfireJobId`.
  - [x] Enums created for `OfferResponse` (Pending, Accepted, Declined, TimedOut) and `OfferStage` (Auto, Broadened). Store as strings via EF `HasConversion`.
  - [x] Migration created and applied.

## P3-02: Recommender Ranking Algorithm
- **Platform**: Backend
- **Description**: Implement a ranking algorithm in `MatchingService` considering trade, radius, schedule fit, rating, and distance.
- **References**: `Services/MatchingService.cs`
- **Revises**: 
  - `Services/MatchingService.cs`
- **Acceptance Criteria**:
  - [x] Method to score and rank available tradies (using EF Core spatial LINQ).
  - [x] Higher score given to closer distance, high rating, and matching schedule.

## P3-03: Sequential Offer Service
- **Platform**: Backend
- **Description**: Replace broadcast matching with sequential offers. Generate an offer for the top-ranked tradie, push notification via FCM and emit a SignalR event. Uses `IJobStatusService` for state transitions.
- **References**: `Services/MatchingService.cs`, `Services/PushNotificationService.cs`, `Services/JobStatusService.cs`
- **Revises**: 
  - `Controllers/JobsController.cs` (Match endpoint)
  - `Services/MatchingService.cs`
- **Acceptance Criteria**:
  - [x] Creates `JobOffer` in DB for the top tradie.
  - [x] Job status transitioned via `IJobStatusService`.
  - [x] Sends push notification and SignalR event.

## P3-04: Hangfire Offer-Timeout Job
- **Platform**: Backend
- **Description**: Create a Hangfire background job to handle offer timeouts. If a tradie doesn't respond before `ExpiresAtUtc`, mark offer as `TimedOut` and trigger the next offer.
- **References**: `Jobs/OfferTimeoutJob.cs` (new)
- **Revises**: 
  - `Program.cs` (Hangfire config)
- **Acceptance Criteria**:
  - [x] Hangfire job scheduled when an offer is created, capturing the `HangfireJobId`.
  - [x] Job executes at expiration: if offer is `Pending`, updates to `TimedOut`.
  - [x] Triggers sequential offer to next ranked tradie.

## P3-05: Broadened Stage Logic
- **Platform**: Backend
- **Description**: If strict criteria matching fails (all top tradies decline/timeout), broaden the criteria (e.g., larger radius) and offer again sequentially.
- **References**: `Services/MatchingService.cs`
- **Revises**: 
  - `Services/MatchingService.cs`
- **Acceptance Criteria**:
  - [x] `Stage` changes to `OfferStage.Broadened` after initial strict list exhausted.
  - [x] Expands search radius using EF Core spatial query.

## P3-06: Terminal Path (No Tradie Found)
- **Platform**: Backend
- **Description**: If all matches are exhausted (including broadened), transition the job to `Cancelled` using `IJobStatusService`.
- **References**: `Services/JobStatusService.cs`, `Services/MatchingService.cs`
- **Revises**: 
  - `Services/MatchingService.cs`
- **Acceptance Criteria**:
  - [x] Job transitions to `Cancelled` via `IJobStatusService`.
  - [x] Status reason/metadata indicates `no_tradie_found`.

## P3-07: Tradie Offer Accept/Decline Endpoint
- **Platform**: Backend
- **Description**: Endpoint for tradies to respond to pending offers.
- **References**: `Controllers/OffersController.cs` (new)
- **Revises**: New controller/endpoint.
- **Acceptance Criteria**:
  - [x] `POST /api/jobs/{id}/offers/{offerId}/respond` accepts response payload (Accepted or Declined).
  - [x] Updates offer state and cancels associated Hangfire job using `HangfireJobId`.
  - [x] If Accepted, transitions job to `Matched` via `IJobStatusService`.
  - [x] If Declined, triggers next sequential offer.

## P3-08: Revise Tradie RequestDetailScreen
- **Platform**: Mobile
- **Description**: Update the tradie's incoming request screen to show a countdown timer for the offer expiry based on `ExpiresAtUtc` (localized for UI).
- **References**: `lib/features/jobs/presentation/request_detail_screen.dart`
- **Revises**: 
  - `lib/features/jobs/presentation/request_detail_screen.dart`
- **Acceptance Criteria**:
  - [x] Screen displays a countdown timer based on local time vs `ExpiresAtUtc`.
  - [x] Auto-closes or disables the accept button when the timer expires.

## P3-09: Revise Homeowner MatchingScreen
- **Platform**: Mobile
- **Description**: Show offer progress states to the homeowner while the sequential matching runs.
- **References**: `lib/features/jobs/presentation/matching_screen.dart`
- **Revises**: 
  - `lib/features/jobs/presentation/matching_screen.dart`
- **Acceptance Criteria**:
  - [x] UI reflects sequential offer progress (e.g., "Contacting Tradie 1...").

## P3-10: SignalR Events for Offer Lifecycle
- **Platform**: Backend / Mobile
- **Description**: Emit SignalR events for offer updates (created, expired, accepted, declined) and handle them on the Flutter client.
- **References**: `Hubs/JobHub.cs`, `lib/core/network/signalr_client.dart`
- **Revises**: 
  - `Hubs/JobHub.cs`
  - `lib/core/network/signalr_client.dart`
  - `lib/features/jobs/providers/job_hub_provider.dart`
- **Acceptance Criteria**:
  - [x] Backend emits lifecycle events to homeowner and relevant tradies.
  - [x] Mobile app listens and updates UI state accordingly (MVVM providers).

## Implementation notes

Delivered 2026-09-28. Deviations and defects found while building:

- **Mobile layout differs from the paths named above.** The app uses a flat
  layer-based structure (`lib/views`, `lib/viewmodels`, `lib/repositories`),
  not `lib/features/...`. SignalR client is
  `lib/repositories/job_hub_client.dart`; the offer-progress ViewModel
  (`MatchingProgressNotifier`) lives in `lib/viewmodels/jobs_viewmodel.dart`.
- **P3-07 "Matched" is `AwaitingPayment` here.** The v1.2 `JobStatus` enum
  has no `Matched` member; the state's "tradie matched" edge is
  `Requested → AwaitingPayment` (actor `Tradie`), which is what the accept
  path performs. `Job.MatchedTradieId` is set alongside it.
- **Radius filtering was inert and is now fixed (P3-02, P3-05).** PostGIS
  `ST_Distance` on `geometry(Point,4326)` returns *degrees*, so the old
  `Location.Distance(job) <= radiusMetres` predicate always passed. Radius
  is now applied as an EF Core spatial LINQ bounding-box prefilter
  (`Intersects`) plus an exact haversine radius test in `Services/Geo.cs`.
  No raw PostGIS SQL — the SQL Server swap path stays open.
- **`POST /api/jobs/{id}/match` now enqueues `SendOfferJob` via Hangfire.**
  It previously used a bare `Task.Run`, whose scoped `DbContext` was
  disposed when the request completed, so no offer was ever created.
- **`JobStatusChanged` payload shape corrected.** The server sent a
  `NewJobMatchPayload` (no status field) while the Flutter client parsed two
  positional args, so status updates were silently empty. It now sends
  `JobStatusChangedPayload` (`JobId`, `Status`, `PreviousStatus`,
  `ReasonCode`, `Reason`).
- **New:** `GET /api/jobs/{id}/offers/pending` (tradie's own pending offer,
  204 when none) — the tradie screen needs `ExpiresAtUtc` for the countdown.
- **New:** unique index on `JobOffers (JobId, TradieId)` backstopping the
  "one offer per tradie per job" rule in the ranking engine.

Verified end to end by `scripts/p3-smoke.sh` against the running stack:
dispatch → accept (job → `AwaitingPayment`, `MatchedTradieId` set, 409 on
double-respond), dispatch → decline → next offer at the `Broadened` stage,
and Hangfire timeouts → `Cancelled` with `no_tradie_found`.
