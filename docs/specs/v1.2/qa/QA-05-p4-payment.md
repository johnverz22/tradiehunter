# QA-05 — P4 Manual payment & admin queue

Spec: `../P4-manual-payment-admin-queue.md`. Precon: job in
`AwaitingPayment` with known `TotalAmount` + `ReferenceCode`
(`FIXO-{JobId}` format).

- [ ] **P4-01 — Instructions (owner)**
  Priority: BLOCKER
  1. `GET /api/jobs/{id}/payment` as the owner.
  Expected: bank `AccountName`/`AccountNumber` (from config, never
  hardcoded), exact amount, job reference, correct `Status`.

- [ ] **P4-02 — Instructions RBAC**
  Priority: BLOCKER
  1. Same GET as another homeowner; as anon.
  2. `GET /api/admin/payments/pending` as a homeowner.
  Expected: non-owner GET → 404 (no existence leak); homeowner on admin
  queue → 403.

- [ ] **P4-03 — Upload → PaymentReview, one row, private blob**
  Priority: BLOCKER
  1. `POST /api/jobs/{id}/payment/upload-receipt` (multipart image).
  Expected: job `AwaitingPayment → PaymentReview`; exactly one `Payment`
  row per job (reused on re-upload); blob lands in private
  `fixo-payments`; receipt served by expiring SAS URL, never a public URL.

- [ ] **P4-04 — Upload gating**
  Priority: MAJOR
  1. Upload against a `Booked` job, an `Expired` job, another owner's job.
  Expected: wrong-state → 409; not-owner → 404.

- [ ] **P4-05 — Duplicate receipt across jobs refused**
  Priority: BLOCKER · Precon: receipt used on job A
  1. Upload the SAME file bytes to job B.
  Expected: refused with cross-job reuse copy (`ReceiptHash` unique index).

- [ ] **P4-06 — Re-uploading the rejected file refused**
  Priority: MAJOR · Precon: receipt rejected on this job
  1. Re-upload the EXACT rejected file.
  Expected: refused with already-rejected copy (hash is single-use both ways).

- [ ] **P4-07 — Verify → Booked**
  Priority: BLOCKER · Precon: P4-03
  1. `POST /api/admin/payments/{id}/verify` as Staff.
  Expected: `Payment=Verified`, job `PaymentReview → Booked`; homeowner
  push/email; queue row removed.

- [ ] **P4-08 — Reject needs reason → AwaitingPayment + count**
  Priority: BLOCKER · Precon: fresh `PaymentReview`
  1. Reject with no reason (expect 400).
  2. Reject with reason.
  Expected: `Payment=Rejected`, job → `AwaitingPayment`, `RejectReason`
  set, `ReUploadCount` +1 (incremented ON REJECT, not on re-upload),
  payment window restarted, homeowner notified.

- [ ] **P4-09 — Re-upload mutates row, deletes old blob**
  Priority: MAJOR · Precon: P4-08
  1. Upload a DIFFERENT file.
  2. Count `Payment` rows for the job; check old blob.
  Expected: same row mutated (no second row); `ReUploadCount` unchanged
  (assert stays 1); superseded blob deleted.

- [ ] **P4-10 — Expiry without payment**
  Priority: BLOCKER
  1. Set `WindowHours: 0`, create job, let Hangfire fire (no upload).
  Expected: job → `Expired`/`Cancelled` with `no_payment`; tradie
  released; fires exactly once. Restore `WindowHours` after.

- [ ] **P4-11 — Expiry with unreviewed receipt**
  Priority: MAJOR · Precon: receipt uploaded, no admin action
  1. Let the window lapse (`WindowHours: 0` env).
  Expected: `PaymentReview → Expired` edge fires; no stuck "under review" job.

- [ ] **P4-12 — Reject restarts window (no early expiry)**
  Priority: MAJOR · Precon: P4-08 near deadline
  1. Let the ORIGINAL deadline pass.
  Expected: job does NOT expire early (job re-reads `Job.PaymentDueAtUtc`,
  reschedules for remaining time).

- [ ] **P4-13 — Mobile payment UI + routing**
  Priority: BLOCKER
  1. Open `/jobs/:jobId/payment` and `/status` in-app; upload; force a reject.
  2. Tap job cards in each payment state.
  Expected: bank details/amount/reference correct; pick + upload works;
  rejected shows reason + re-upload; card taps route
  `AwaitingPayment→payment`, `PaymentReview→status`, else chat.

- [ ] **P4-14 — Web payment queue (`/payments`)**
  Priority: MAJOR
  1. Open queue populated + empty; open `PaymentReviewModal`.
  Expected: row = job/amount/reference; full-size receipt via SAS; Verify
  removes row; Reject requires reason text.
