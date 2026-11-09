# QA-07 — P6 Cancellations & refunds

Spec: `../../v1.2/P6-cancellations-refunds.md`. Inherited from v1.2 — no changes for v1.3.

Precon: jobs in `Booked` and `InProgress` with payments verified.

## Cancellation flows

- [ ] **P6-01 — Cancel requires ReasonCode**
  Priority: BLOCKER
  1. `POST /api/jobs/{id}/cancel` with no `ReasonCode`, then an invalid enum.
  Expected: 400 both times; no state change.

- [ ] **P6-02 — Homeowner cancel pre-work (10% flat)**
  Priority: BLOCKER · Precon: `Booked` job, no check-in
  1. Homeowner cancels with `homeowner_changed_mind`.
  Expected: job → `Cancelled`; 10% flat penalty suggested; `Refund` row
  `Pending` (only when `totalPaid > 0`); tradie pushed
  (`job_cancelled_by_homeowner`).

- [ ] **P6-03 — Homeowner cancel in-work (elapsed × rate + 10%)**
  Priority: BLOCKER · Precon: `InProgress` job (checked in)
  1. Homeowner cancels.
  Expected: `SuggestedAmount` = elapsed (`StartedAtUtc`→now) `× HourlyRate`;
  penalty = hours-worked-amount + 10%; `Refund` `Pending`.

- [ ] **P6-04 — Tradie cancel → Requested + rematch, payment held**
  Priority: BLOCKER · Precon: `Booked` job with assigned tradie
  1. Assigned tradie cancels.
  Expected: job → `Requested` (NOT `Cancelled`);
  `TradieProfile.CancellationCount++`; homeowner pushed
  (`job_cancelled_by_tradie`, "being reassigned"); rematch enqueued
  (canceller naturally skipped); payment record untouched.

- [ ] **P6-05 — Repeat-canceller flag**
  Priority: MAJOR · Precon: tradie near threshold
  1. Cancel enough times to hit the threshold.
  Expected: `AccountFlag(RepeatCanceller)` counter increments;
  `ThresholdHit=true` at threshold.

- [ ] **P6-06 — Mobile cancel UI (both roles)**
  Priority: MAJOR
  1. Tap cancel icon on homeowner + tradie detail screens (cancellable vs
     non-cancellable statuses).
  2. Submit via the shared reason sheet (reason radio + optional notes).
  Expected: affordance only on cancellable statuses; homeowner sees fee
  warning (esp. `Booked`/`InProgress` banner); tradie sees account-flag
  warning; submit → status syncs.

- [ ] **P6-07 — Cancel notifications reach the other party**
  Priority: MAJOR · Precon: P6-02 and P6-04
  Expected: correct party pushed each way. (Refund-Pending homeowner notice
  is OPTIONAL — its absence is not a bug.)

## Admin refund queue (`/refunds`)

- [ ] **P6-08 — Pending list shape**
  Priority: BLOCKER · Precon: `Refund` rows `Pending`
  1. `GET /api/admin/refunds/pending`.
  Expected: only `Pending`; row = job title/ID, homeowner, suggested
  amount, penalty, cancel `ReasonCode`, age.

- [ ] **P6-09 — Process happy path**
  Priority: BLOCKER · Precon: P6-08
  1. `POST /api/admin/refunds/{id}/process` (multipart: `FinalAmount`,
     `Penalty`, `HoursWorked`, REQUIRED `TransferReference`, optional
     proof ≤10MB).
  Expected: `Refund → Processed`, `ProcessedBy` = admin, `ProcessedAtUtc`
  set; proof in `fixo-credentials` with key on row; homeowner FCM with
  final amount + reference; row leaves queue.

- [ ] **P6-10 — Process validation**
  Priority: MAJOR
  1. Submit without `TransferReference`; oversize proof; bad amounts.
  Expected: 400 per case; refund stays `Pending`.

- [ ] **P6-11 — Web process modal**
  Priority: MAJOR
  1. Open `ProcessRefundModal`: edit `finalAmount`/`penalty`/`hoursWorked`
     (pre-filled), attach proof, submit.
  Expected: multipart POST; success removes row from cache; failure
  surfaces the message.

- [ ] **P6-12 — Penny precision**
  Priority: MINOR
  1. Process a refund with cents (e.g. `87.55`); re-read the row.
  Expected: exact cents (`decimal(18,2)` × 5 columns); no float drift.
