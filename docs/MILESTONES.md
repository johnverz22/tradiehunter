# Fixo — Milestones

Phased around the tiered MVP scope in `docs/MVP-SPEC.md`. Each milestone ships independently testable and demoable.

## M0 — Docker & Scaffold
- Docker Compose: PostgreSQL + PostGIS, MinIO, Redis, .NET API, React (admin)
- Scaffold backend (.NET Web API) with EF Core + Npgsql
- Scaffold mobile (Flutter) with project structure and navigation shell
- Scaffold web (React) admin shell
- Apply design tokens from `docs/design/design-system.html` to Flutter theme
- Firebase project setup + FCM integration in Flutter
- CI: build + test for backend and mobile

## M1 — Auth & Profiles
- Registration/login (email + Google) on Flutter
- ASP.NET Identity + JWT, role claim (homeowner/tradie/admin)
- Admin login on React web
- Profile CRUD (name, phone, address, trade type for tradies)
- Locale configuration (currency, phone format) wired into API config

## M2 — Job Posting & Matching
- Job posting flow in Flutter (category, description, photo upload to MinIO, urgency, location)
- S3-compatible photo upload endpoint
- Rule-based matching service (trade + PostGIS radius + availability)
- SignalR match notification to eligible tradies
- FCM push for match notification (background)
- Accept/decline flow in Flutter (tradie side)

## M3 — Chat & Job Status
- SignalR chat between homeowner and tradie (Flutter)
- Job status stepper UI (Requested → Matched → Confirmed → Complete)
- Real-time status transitions via SignalR
- FCM push for status changes and chat messages

## M4 — Reviews & Scheduling
- Post-job rating/review flow (both directions, Flutter)
- Scheduling confirmation (date/time picker in Flutter)
- Hangfire reminder notifications (API) + FCM push
- Tradie profile page with aggregated ratings

## M5 — Admin & Beta
- Admin dashboard (React web): user list, job list + status, flagged disputes, verify/deactivate
- Success metrics instrumentation (activation rate, match-to-confirmation time, tradie response rate, review completion rate)
- End-to-end happy path tested on Flutter
- Closed beta with a small cohort in one NZ region

## Post-MVP (V1.1)
In-app payments (BNZ API), transparent pricing engine, job board/browse-and-apply, favorites, calendar sync, automated cancellation/refund rules — see `docs/MVP-SPEC.md`.
