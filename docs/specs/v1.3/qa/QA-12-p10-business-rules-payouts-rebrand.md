# QA-12 — P10 Business Rules, Payouts & Rebrand

Spec: `../../v1.3/P10-business-rules-payouts-rebrand.md`.

Precon: QA-00 complete (all 8 accounts including TRADIE-PAUSED and
TRADIE-VERIFIED with bank details). TRADIE-VERIFIED has
`BankAccountName` + `BankAccountNumber` set via the onboarding wizard.

---

## Commission & Payout data model (P10-01 / P10-02)

- [ ] **P10-01 — Payout created on job completion**
  Priority: BLOCKER · Precon: TRADIE-VERIFIED completes a job
  1. Complete a job (manual confirm or auto-complete).
  2. Inspect `tradie_payouts` table.
  Expected: one `TradiePayout` row, `Status=Pending`;
  `CommissionAmount = TotalAmount × PayoutOptions.CommissionPercent / 100`;
  `NetAmount = GrossAmount − CommissionAmount`; bank details copied from
  tradie profile at time of completion; `(18,2)` precision on all money
  columns.

- [ ] **P10-02 — No bank details → Pending + warning**
  Priority: MAJOR · Precon: a tradie with NO bank account on file
  1. Complete a job for that tradie.
  2. Inspect payout row + server logs.
  Expected: payout created with `Status=Pending`; warning logged (not an
  error); `hasBankDetails=false` visible in admin queue; row excluded from
  weekly batch until tradie supplies details.

- [ ] **P10-03 — CommissionPercent in config endpoint**
  Priority: MAJOR
  1. `GET /api/config/locale`.
  Expected: `commissionPercent` field present with the configured value
  (default 12.5).

---

## Payout admin queue (P10-06)

- [ ] **P10-04 — Pending queue shape**
  Priority: BLOCKER · Precon: P10-01
  1. `GET /api/admin/payouts/pending` as Staff.
  Expected: paginated; row includes tradie name, job reference, gross,
  commission, net, bank (last 4 digits only — never full number), status, age.

- [ ] **P10-05 — Process payout**
  Priority: BLOCKER · Precon: P10-04
  1. `POST /api/admin/payouts/{id}/process` with `transferReference`.
  Expected: payout → `Processed`; `TransferReference`, `ProcessedBy`,
  `ProcessedAtUtc` set; tradie receives push notification with net amount +
  reference; row removed from pending queue.

- [ ] **P10-06 — Process requires transferReference**
  Priority: MAJOR
  1. `POST /api/admin/payouts/{id}/process` with no `transferReference`.
  Expected: 400; payout stays `Pending`.

- [ ] **P10-07 — Web payout queue (`/payouts`)**
  Priority: MAJOR
  1. Open `/payouts` in admin; process one row via modal; check empty state.
  Expected: table shows all required columns; Process modal shows gross /
  fee / net / bank before confirming; processed row removed via cache
  invalidation; sidebar nav has "Payouts" link.

---

## Payout batches (P10-05 / P10-06)

- [ ] **P10-08 — Weekly batch creation (Hangfire)**
  Priority: MAJOR · Precon: P10-01 (pending payouts exist)
  1. Trigger `PayoutBatchJob` manually via Hangfire or advance the cron.
  Expected: `PayoutBatch` row created with `Status=Open`; all `Pending`
  payouts move to `Scheduled` and gain `PayoutBatchId`; no batch created
  when no pending payouts exist.

- [ ] **P10-09 — Batch detail + complete**
  Priority: MAJOR · Precon: P10-08
  1. `GET /api/admin/payouts/batches/{id}`.
  2. Process all payouts in the batch.
  3. `POST /api/admin/payouts/batches/{id}/complete`.
  Expected: batch detail includes individual payouts; "Mark Batch Complete"
  blocked while unprocessed payouts remain; on complete → `Status=Completed`,
  `CompletedAtUtc` set.

- [ ] **P10-10 — Web batch pages (`/payouts/batches`)**
  Priority: MAJOR
  1. Open `/payouts/batches`; open a batch detail page.
  Expected: list shows period, payouts count, processed count, total, status;
  detail page matches individual payouts; "Mark Batch Complete" disabled
  while unprocessed > 0.

---

## Service catalog & licence-gated matching (P10-07 / P10-08)

- [ ] **P10-11 — Licence-gated services seeded**
  Priority: MAJOR
  1. Inspect `services` table (or `GET /api/services`).
  Expected: plumbing/electrical/building services have `RequiresLicence=true`
  with correct `LicenceBoard` (PGDB/EWRB/LBP); handyman/cleaning/painting
  have `RequiresLicence=false`.

- [ ] **P10-12 — Licence filter in matching**
  Priority: BLOCKER · Precon: a regulated service job (e.g. Plumbing);
  TRADIE-VERIFIED with no PGDB credential; TRADIE-2 with approved PGDB
  1. `POST /api/jobs/{id}/match`.
  Expected: TRADIE-VERIFIED (no matching licence) excluded from offers;
  TRADIE-2 (has approved PGDB) offered.

- [ ] **P10-13 — IsAvailable=false excluded from matching**
  Priority: BLOCKER · Precon: TRADIE-PAUSED is in range and schedule-fit
  1. `POST /api/jobs/{id}/match`.
  Expected: TRADIE-PAUSED never offered; other available tradies offered normally.

---

## Insurance badge (P10-09)

- [ ] **P10-14 — Insurance credential → badge**
  Priority: MAJOR
  1. Admin approves an `Insurance` credential for TRADIE-VERIFIED.
  2. `GET /api/profile` for that tradie; check tradie card in search results.
  Expected: `hasInsurance=true`; "Insured" badge/shield shown on tradie card
  in search results, job detail, and tradie profile. Revoking the last
  insurance credential sets `hasInsurance=false`.

---

## Tradie availability toggle (P10-10 / P10-18)

- [ ] **P10-15 — Toggle endpoint**
  Priority: BLOCKER
  1. `POST /api/profile/availability { "available": false }` as TRADIE-VERIFIED.
  2. `GET /api/profile`.
  Expected: `isAvailable=false` in profile; tradie excluded from matching
  (see P10-13). Toggle back → `isAvailable=true`, matching resumes.

- [ ] **P10-16 — Mobile toggle UI**
  Priority: MAJOR · Precon: tradie logged in
  1. Toggle the "Available for jobs" switch off on tradie dashboard.
  Expected: switch updates; amber banner "You're currently paused. Toggle
  back on to receive new job offers." shown; active existing jobs
  unaffected; toggle on removes banner.

---

## Blind reviews (P10-11)

- [ ] **P10-17 — First review hidden**
  Priority: BLOCKER · Precon: `Completed` job, only ONE review submitted
  1. Homeowner submits a review.
  2. `GET /api/jobs/{id}/reviews`.
  Expected: review `isRevealed=false`; `stars` and `comment` redacted
  (null/placeholder) in response; `RevealAfterUtc = job.CompletedAtUtc + 7d`.

- [ ] **P10-18 — Both reviews reveal immediately**
  Priority: BLOCKER · Precon: P10-17
  1. Tradie also submits a review for the same job.
  Expected: both reviews `isRevealed=true` immediately; `RevealAfterUtc`
  set to `UtcNow` for both; both parties can see stars + comments.

- [ ] **P10-19 — 7-day reveal (Hangfire)**
  Priority: MAJOR · Precon: one review submitted, second NOT submitted
  1. Advance time past `RevealAfterUtc` (or trigger `RevealReviewsJob` manually).
  Expected: review flips to `isRevealed=true`; push notification to both
  parties; already-revealed reviews unaffected.

- [ ] **P10-20 — Disputed job blocks reveal**
  Priority: MAJOR · Precon: `Disputed` job with one review submitted
  1. `GET /api/jobs/{id}/reviews` while job is `Disputed`.
  Expected: review remains `isRevealed=false` even if 7 days elapsed;
  only revealed after dispute outcome recorded.

- [ ] **P10-21 — Mobile blind review UX**
  Priority: MAJOR
  1. Submit review in-app; re-open job detail immediately.
  Expected: confirmation copy "Your review has been submitted. It will be
  visible once the other party also reviews, or after 7 days."; job detail
  shows "Review submitted — waiting for the other party." placeholder;
  once revealed, shows stars + comments.

- [ ] **P10-22 — Tradie can review homeowner**
  Priority: MAJOR · Precon: `Completed` job
  1. Open tradie job detail → "Rate Homeowner" button → 1–5 stars + optional comment.
  Expected: `POST /api/reviews` with `fromUser=tradieId`, `toUser=homeownerId`;
  blind window applies same as above.

---

## Low-rating flag (P10-12)

- [ ] **P10-23 — Auto-flag on low average**
  Priority: MAJOR · Precon: a user with ≥3 revealed reviews averaging <3.0
  1. Submit/reveal enough reviews to drop the average below 3.0.
  Expected: `AccountFlag(LowRating)` created; no auto-suspension; admin
  can see the flag in the user detail view.

---

## Job editing lockout (P10-13)

- [ ] **P10-24 — Edit blocked after matching starts**
  Priority: BLOCKER · Precon: job in `Requested` with at least one `JobOffer`
  1. `PUT /api/jobs/{id}` with any change.
  Expected: 409 Conflict; body:
  `{ "message": "Job cannot be edited after matching has started. Cancel and repost to change details." }`

- [ ] **P10-25 — Edit blocked on non-Draft status**
  Priority: BLOCKER · Precon: job in `AwaitingPayment` or beyond
  1. `PUT /api/jobs/{id}`.
  Expected: 409.

- [ ] **P10-26 — Mobile edit button hidden**
  Priority: MAJOR
  1. Open job detail in `Requested` (with offer) or `Booked`.
  Expected: Edit button not visible; if edit triggered anyway (e.g. deep
  link), backend 409 shows graceful dialog.

---

## Photo limits (P10-14 / P10-25)

- [ ] **P10-27 — Max 5 photos enforced**
  Priority: MAJOR
  1. `POST /api/jobs` with 6 photos in the array.
  Expected: 400 with descriptive message.

- [ ] **P10-28 — 10MB per photo enforced**
  Priority: MAJOR
  1. Include a photo >10 MB (10,485,760 bytes) in a job creation request.
  Expected: 400 with descriptive message; no partial upload.

- [ ] **P10-29 — Mobile photo picker respects limits**
  Priority: MAJOR
  1. Attempt to select 6 photos in the post-job screen.
  2. Attempt to select a >10 MB photo.
  Expected: picker capped at 5; oversized photo shows an error; counter
  shows "X/5 photos added".

---

## Brand & rebrand (P10-15 / P10-24 / P10-28)

- [ ] **P10-30 — TradieFixo on all user-facing surfaces**
  Priority: MAJOR
  1. Check: mobile splash screen, onboarding slides, app bar titles,
     settings/about screen.
  2. Check admin: sidebar wordmark, browser tab title ("TradieFixo Admin"),
     login page ("TradieFixo Admin Portal").
  3. Check push notification titles ("TradieFixo: …").
  4. `GET /api/config/locale` returns `brand.appName = "TradieFixo"`.
  Expected: "TradieFixo" consistently used; no end-user-visible "Fixo"
  remaining.

---

## Payment queue SLA indicators (P10-16 / P10-27)

- [ ] **P10-31 — Waiting column in payment queue**
  Priority: MAJOR
  1. Open `/payments` in admin with items of varying ages.
  Expected: "Waiting" column shown per row; items >15 min: amber row;
  items >30 min: red row + "URGENT" badge; queue sorted oldest first;
  `minutesSinceSubmission` sourced from server response.

- [ ] **P10-32 — SLA push notification (Hangfire)**
  Priority: MAJOR · Precon: a payment in `PaymentReview` for >30 min
  1. Trigger (or wait for) the SLA check job.
  Expected: push notification sent to all staff users with the job
  reference and minutes waited.
