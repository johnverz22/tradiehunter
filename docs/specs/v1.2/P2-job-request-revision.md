# Phase 2: Job Request Revision

## P2-01: Service Search Endpoint
- **Platform**: Backend
- **Description**: Create an endpoint to search for verified tradies offering a specific service near the homeowner's location. This should return available rates for the specified service. The endpoint should use EF Core spatial LINQ (not raw PostGIS SQL) to find tradies within a default radius (e.g., 25km).
- **References**: `Controllers/ServicesController.cs` (to be created), `Services/MatchingService.cs`, `Models/TradieProfile.cs`, `Models/TradieRate.cs`
- **Revises**: New controller/endpoint.
- **Acceptance Criteria**:
  - [x] `GET /api/services/search` endpoint exists.
  - [x] Requires `lat`, `lng` (double), and `serviceId` (int).
  - [x] Uses EF Core spatial queries to find nearby verified tradies (`IsVerified == true`).
  - [x] Returns a list of available tradies with their specific rate for `serviceId`.
  - [x] Rates returned are of type `decimal`.

## P2-02: Revise CreateJobRequest DTO
- **Platform**: Backend
- **Description**: Update `CreateJobRequest` to include new fields required for the revised job creation flow: service selection, scheduled start, hours, and selected rate.
- **References**: `DTOs/Jobs/CreateJobRequest.cs`, `Validators/Jobs/CreateJobRequestValidator.cs`
- **Revises**: 
  - `DTOs/Jobs/CreateJobRequest.cs`
  - `Validators/Jobs/CreateJobRequestValidator.cs`
- **Acceptance Criteria**:
  - [x] Add `int ServiceId`.
  - [x] Add `DateTimeOffset ScheduledStartUtc` (Timestamps must be UTC).
  - [x] Add `int Hours` (must be > 0).
  - [x] Add `decimal HourlyRate` (Money fields always decimal).
  - [x] FluentValidation rules updated for new fields.

## P2-03: Rate Snapshot and Total Amount Computation
- **Platform**: Backend
- **Description**: When a job is created, snapshot the hourly rate and compute the total amount (`TotalAmount = HourlyRate * Hours`). These should be stored as decimals.
- **References**: `Services/JobService.cs`, `Models/Job.cs`
- **Revises**: 
  - `Services/JobService.cs`
  - `Models/Job.cs`
  - EF Migration
- **Acceptance Criteria**:
  - [x] `Job` model updated with `decimal HourlyRate`, `int Hours`, `decimal TotalAmount`.
  - [x] `JobService.CreateJobAsync` snapshots rate and calculates `TotalAmount`.
  - [x] Entity framework migration created for new job fields.

## P2-04: Reference Code Generation
- **Platform**: Backend
- **Description**: Generate a unique, human-readable reference code for each job, suitable for bank transfers (e.g., 6-8 alphanumeric characters, uppercase).
- **References**: `Services/JobService.cs`, `Models/Job.cs`
- **Revises**: 
  - `Services/JobService.cs`
  - `Models/Job.cs`
- **Acceptance Criteria**:
  - [x] `Job` model updated with `string ReferenceCode`.
  - [x] Generated code is unique and collision-resistant (check DB or use sufficient randomness).
  - [x] Saved with the job upon creation.

## P2-05: Revise PostJobScreen (Flutter)
- **Platform**: Mobile
- **Description**: Update the job posting flow to include service search, rate picking, hours input, and scheduled start. Localize the UTC schedule time for display.
- **References**: `lib/features/jobs/presentation/post_job_screen.dart`, `lib/features/jobs/providers/post_job_provider.dart`
- **Revises**: 
  - `lib/features/jobs/presentation/post_job_screen.dart`
  - `lib/features/jobs/providers/post_job_provider.dart`
- **Acceptance Criteria**:
  - [x] UI for service selection added.
  - [x] UI for rate selection based on `GET /api/services/search` results.
  - [x] Input field for estimated hours.
  - [x] Input for scheduled start time (converts user's local time to UTC for API request).

## P2-06: Update HomeownerDashboardView
- **Platform**: Mobile
- **Description**: Display price (`total_amount`) and schedule information (`scheduled_start`, `hours`) on job cards. Convert UTC timestamps to local time for display.
- **References**: `lib/features/home/presentation/homeowner_dashboard_screen.dart`, `lib/features/jobs/presentation/widgets/job_card.dart`
- **Revises**: 
  - `lib/features/jobs/presentation/widgets/job_card.dart`
- **Acceptance Criteria**:
  - [x] Job cards show formatted `total_amount` (e.g., $150.00).
  - [x] Job cards show local `scheduled_start` and `hours`.

## P2-07: Update JobDto and Endpoints
- **Platform**: Backend
- **Description**: Expose the new job fields in `JobDto` and update all job list and detail endpoints to return them.
- **References**: `DTOs/Jobs/JobDto.cs`, `Controllers/JobsController.cs`
- **Revises**: 
  - `DTOs/Jobs/JobDto.cs`
- **Acceptance Criteria**:
  - [x] `JobDto` includes `ServiceId`, `ScheduledStartUtc`, `Hours`, `HourlyRate`, `TotalAmount`, `ReferenceCode`.
  - [x] Endpoints serialize these new fields correctly.
