# QA-01 — P0 Foundation, roles, state machine

Spec: `../P0-foundation.md`.

- [ ] **P0-01 — Config binding**
  Priority: MAJOR · Precon: QA-00
  1. Set bogus `PaymentInstructions:WindowHours`, restart api.
  2. Restore valid value, restart.
  Expected: typed value picked up; invalid shape fails fast with a clear
  error, not a silent default.

- [ ] **P0-02 — Role gating (queues + invite)**
  Priority: BLOCKER
  1. As Homeowner, Tradie, anon: call `POST /api/admin/staff/invite`,
     `GET /api/admin/credentials/pending`,
     `GET /api/admin/payments/pending`, `GET /api/admin/refunds/pending`.
  2. Repeat as Staff, then Superadmin.
  Expected: non-staff → 401/403, nothing created; Staff succeeds on queues
  but NOT staff-invite; only Superadmin succeeds on staff-invite.

- [ ] **P0-03 — Legacy `Admin` role gone**
  Priority: MAJOR
  1. Search api + mobile + web for standalone `Admin` enum/string.
  Expected: no matches — only `Staff`/`Superadmin` (compound names like
  `AdminLayout`/`AdminLogin` are fine).

- [ ] **P0-04 — AuthProvider + EmailVerified tracked**
  Priority: MAJOR
  1. Register a password user; inspect record.
  2. Register/login a Google user; inspect record.
  Expected: password → `AuthProvider=password`, `EmailVerified=false`;
  Google → `AuthProvider=google`, `EmailVerified=true`.

- [ ] **P0-05 — JobStatus = 10 values**
  Priority: BLOCKER
  1. Walk jobs across the lifecycle; check mobile `job.dart` + web `job.ts`.
  Expected: exactly `Requested, AwaitingPayment, PaymentReview, Booked,
  InProgress, AwaitingConfirmation, Completed, Cancelled, Expired, Disputed`.
  Any `Draft/Matching/Matched/Confirmed/Complete` is a bug.

- [ ] **P0-06 — History enrichment**
  Priority: BLOCKER
  1. Accept an offer (any job).
  2. Read its `JobStatusHistory`.
  Expected: row has `FromStatus`, `ToStatus`, `ActorRole`, UTC timestamp;
  `ReasonCode`/`CancelledBy` nullable but present as columns.

- [ ] **P0-07 — Invalid transition rejected**
  Priority: BLOCKER
  1. `POST /api/jobs/{id}/confirm` on a `Requested` job.
  2. `POST /api/jobs/{id}/check-in` as the homeowner.
  Expected: 4xx with guard message; no state change, no history row,
  no SignalR event.

- [ ] **P0-08 — Legacy status migration**
  Priority: MAJOR
  1. Inspect the migration mapping (or seed old rows on a scratch DB).
  Expected: `Matching,Matched→Requested`; `Confirmed→Booked`;
  `Complete→Completed`; new required fields backfilled, no nulls.

- [ ] **P0-09 — Mobile stepper**
  Priority: MAJOR · Precon: a job walkable end-to-end
  1. Advance Requested → Payment → Booked → InProgress → Confirmation →
     Completed in Flutter.
  2. Open a `Disputed` and a `Cancelled` job.
  Expected: linear stepper advances; Disputed/Cancelled render alert/failure
  visuals, not a normal step.

- [ ] **P0-10 — Web StatusBadge**
  Priority: MINOR
  1. Open admin job list with one job per status.
  Expected: all 10 render with distinct label/colour (`Disputed`
  amber/warning, `Booked` blue, etc.).
