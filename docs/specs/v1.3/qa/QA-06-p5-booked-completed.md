# QA-06 — P5 Booked → Completed lifecycle

Spec: `../../v1.2/P5-booked-to-completed.md`. Inherited from v1.2.

**v1.3 addendum:** Job completion now triggers payout creation (P10-04)
and blind review logic (P10-11). See QA-12 for payout and review cases.
The cases below test the core P5 lifecycle unchanged.

Precon: job `Booked` (via QA-05).

- [ ] **P5-01 — Address masked pre-Booked**
  Priority: BLOCKER · Precon: job `Requested/AwaitingPayment/PaymentReview`
  1. `GET /api/jobs/{id}` as the assigned/offered tradie.
  Expected: exact address + homeowner phone masked (city/suburb only).

- [ ] **P5-02 — Address revealed at Booked**
  Priority: BLOCKER · Precon: same job now `Booked`
  1. Same GET as assigned tradie, as ANOTHER tradie, as homeowner.
  Expected: assigned tradie sees full address + contact; others still
  masked; homeowner always sees full.

- [ ] **P5-03 — Check-in → InProgress + StartedAt**
  Priority: BLOCKER
  1. `POST /api/jobs/{id}/check-in` as assigned tradie.
  2. Same as homeowner.
  Expected: tradie → `Booked → InProgress`, `StartedAtUtc` set;
  homeowner → 403, no change.

- [ ] **P5-04 — Check-out → AwaitingConfirmation + EndedAt**
  Priority: BLOCKER · Precon: `InProgress`
  1. `POST /api/jobs/{id}/check-out` as assigned tradie.
  Expected: → `AwaitingConfirmation`, `EndedAtUtc` set; auto-complete
  Hangfire scheduled (+N hrs).

- [ ] **P5-05 — Confirm → Completed, auto-complete cancelled**
  Priority: BLOCKER · Precon: `AwaitingConfirmation`
  1. `POST /api/jobs/{id}/confirm` as homeowner.
  Expected: → `Completed`; scheduled auto-complete becomes no-op.

- [ ] **P5-06 — Confirm/check-in RBAC**
  Priority: MAJOR
  1. Confirm as tradie; check-in as homeowner.
  Expected: both 403; no state change.

- [ ] **P5-07 — Pre-job reminder (T-1h, both parties)**
  Priority: MAJOR · Precon: job `Booked` with start ~65 min out
  1. Wait for fire.
  2. On a second job, cancel before fire.
  Expected: push to BOTH parties on the first; no push on the cancelled one
  (task deleted).

- [ ] **P5-08 — Auto-complete after N hours**
  Priority: MAJOR · Precon: checked-out job (shrink `AutoCompleteWindowHours`
  on test env if needed)
  1. Take no action; wait for fire.
  Expected: → `Completed` automatically; review prompt pushed to both.

- [ ] **P5-09 — Review model + payout created on completion**
  Priority: MAJOR · Precon: `Completed` job, TRADIE-VERIFIED with bank details
  1. After completion, inspect `tradie_payouts` table.
  2. Create a review; inspect record.
  Expected: `TradiePayout` row with `Status=Pending`,
  `CommissionAmount = TotalAmount × commissionPercent`, correct `NetAmount`;
  review `Status=Visible` (v1.2 default — blind review behaviour tested in
  QA-12 P10-11).

- [ ] **P5-10 — Tradie execution UI**
  Priority: MAJOR
  1. Tradie job screen at `Booked` (near start) → `InProgress`.
  Expected: "Check In" only when `Booked` (+ near time); "Check Out" only
  when `InProgress`; calls update UI; address hidden until `Booked`.

- [ ] **P5-11 — Homeowner execution UI**
  Priority: MAJOR
  1. Homeowner screen at `AwaitingConfirmation` → `Completed`.
  Expected: "Confirm Completion" present; "Leave Review" appears when
  `Completed` + no review; stepper tracks full lifecycle.

- [ ] **P5-12 — Chat locked when Completed/Cancelled**
  Priority: BLOCKER
  1. Send chat at `Booked`/`InProgress` (expect accepted).
  2. Send at `Completed`/`Cancelled` (expect server rejection).
  3. Open mobile chat on a closed job.
  Expected: active phases accept; closed rejected server-side; mobile input
  disabled with "Chat is closed" banner.
