# QA-03 — P2 Job request revision

Spec: `../../v1.2/P2-job-request-revision.md`. Inherited from v1.2.

**v1.3 addendum:** Job editing is now locked once matching starts (P10-13).
See also QA-12 P10-13 / P10-14 for the edit lockout and photo-limit cases.

Precon: TRADIE-VERIFIED with rates + schedule near HOMEOWNER-A.

- [ ] **P2-01 — Service search happy path**
  Priority: BLOCKER
  1. `GET /api/services/search?lat=&lng=&serviceId=` near TRADIE-VERIFIED.
  Expected: verified tradies returned with their `decimal` rate for that service.

- [ ] **P2-02 — Search validation**
  Priority: MAJOR
  1. Omit `lat` / `lng` / `serviceId`; send non-numeric values.
  Expected: 400 with per-field errors; nothing half-returned.

- [ ] **P2-03 — Radius enforced (~25km)**
  Priority: MAJOR
  1. Search 30km+ from the tradie.
  Expected: distant tradie excluded (bounding-box + haversine; no raw SQL).

- [ ] **P2-04 — Create-job validation**
  Priority: BLOCKER
  1. `POST /api/jobs` with `Hours=0`, negative `HourlyRate`, past
     `ScheduledStartUtc`, missing `ServiceId` (one at a time).
  Expected: 400 per case; nothing created.

- [ ] **P2-05 — Rate snapshot + total**
  Priority: BLOCKER
  1. Create job `HourlyRate=85.50 × Hours=2`.
  2. Change the tradie's catalog rate; re-read the job.
  Expected: `HourlyRateSnapshot=85.50`, `TotalAmount=171.00` (decimal);
  later rate changes do NOT mutate the job.

- [ ] **P2-06 — Reference code unique**
  Priority: BLOCKER
  1. Create 2+ jobs.
  Expected: each has a unique 6–8 char uppercase alphanumeric
  `ReferenceCode`, persisted.

- [ ] **P2-07 — JobDto shape**
  Priority: MAJOR · Precon: P2-05
  1. `GET /api/jobs/{id}` + list endpoints.
  Expected: include `ServiceId`, `ScheduledStartUtc` (UTC), `Hours`,
  `HourlyRate`, `TotalAmount`, `ReferenceCode`.

- [ ] **P2-08 — PostJobScreen (mobile)**
  Priority: BLOCKER
  1. Post in-app: service select → rate list from search → hours →
     scheduled start (local time).
  Expected: converts local → UTC on submit; validation mirrors server.

- [ ] **P2-09 — Job cards show price + local time**
  Priority: MINOR
  1. Open homeowner dashboard.
  Expected: cards show formatted total (`$150.00` / locale symbol) + local
  `scheduled_start` + hours.

- [ ] **P2-10 — Parallel-create uniqueness**
  Priority: MAJOR
  1. Create ~50 jobs rapidly (parallel).
  Expected: no duplicate `ReferenceCode`; no 500s.
