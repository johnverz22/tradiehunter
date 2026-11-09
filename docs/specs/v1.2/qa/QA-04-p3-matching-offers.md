# QA-04 — P3 Matching: sequential offers & timeouts

Spec: `../P3-matching-offers-timeouts.md`. Precon: job in `Requested`;
TRADIE-VERIFIED + TRADIE-2 nearby with schedule fit. Shrink
`OfferTimeoutMinutes` (e.g. 2 min) for timeout cases, restore after.
Note: v1.2 has NO `Matched` status — accept lands on `AwaitingPayment`.

- [ ] **P3-01 — Dispatch creates one Pending offer**
  Priority: BLOCKER
  1. `POST /api/jobs/{id}/match`.
  Expected: `JobOffer` row for the top-ranked tradie (`OfferedAtUtc`,
  `ExpiresAtUtc`, `Response=Pending`, `Stage=Auto`, `HangfireJobId` set);
  FCM + SignalR fired; transition via `IJobStatusService`.

- [ ] **P3-02 — Ranking prefers close / rated / schedule-fit**
  Priority: MAJOR · Precon: tradie A (close, high rating, fit) vs B (far, low)
  1. Dispatch.
  Expected: offer goes to A first.

- [ ] **P3-03 — Tradie countdown + pending endpoint**
  Priority: MAJOR · Precon: pending offer
  1. Open tradie request screen.
  2. `GET /api/jobs/{id}/offers/pending` (expect 200); other tradie (expect 204).
  Expected: countdown = `ExpiresAtUtc` localised; accept disables at expiry.

- [ ] **P3-04 — Accept → AwaitingPayment + MatchedTradieId**
  Priority: BLOCKER
  1. `POST /api/jobs/{id}/offers/{offerId}/respond {Accepted}` as offered tradie.
  Expected: offer `Accepted`, Hangfire timeout cancelled, job →
  `AwaitingPayment`, `MatchedTradieId` set; homeowner + tradie receive
  `JobStatusChanged` (`JobId/Status/PreviousStatus/ReasonCode/Reason`).

- [ ] **P3-05 — Double-respond → 409**
  Priority: MAJOR · Precon: P3-04
  1. Accept the same offer again.
  Expected: 409; exactly one history row.

- [ ] **P3-06 — Decline → next offer (sequential, never parallel)**
  Priority: BLOCKER · Precon: fresh job, 2+ candidates
  1. Offered tradie declines.
  Expected: offer `Declined`; exactly one next-ranked tradie offered.

- [ ] **P3-07 — Timeout → next offer**
  Priority: BLOCKER
  1. Let an offer expire unanswered.
  Expected: Hangfire marks `TimedOut`; next tradie offered automatically.

- [ ] **P3-08 — Broadened stage after strict exhausted**
  Priority: MAJOR
  1. Decline/timeout ALL strict-list tradies.
  Expected: `Stage` flips to `Broadened`; radius expands; offers continue.

- [ ] **P3-09 — Exhaustion → Cancelled/no_tradie_found**
  Priority: BLOCKER
  1. Decline/timeout ALL broadened offers.
  Expected: job → `Cancelled` with `no_tradie_found`; homeowner notified.

- [ ] **P3-10 — One offer per tradie per job**
  Priority: MAJOR
  1. Inspect `JobOffers` for the job.
  Expected: unique `(JobId, TradieId)` — nobody offered twice.

- [ ] **P3-11 — Homeowner progress UI**
  Priority: MINOR · Precon: P3-06 running
  1. Watch homeowner matching screen.
  Expected: sequential copy ("Contacting Tradie 1…"), updates live via SignalR.

- [ ] **P3-12 — Cross-tradie isolation**
  Priority: MAJOR · Precon: pending offer for TRADIE-1
  1. TRADIE-2 attempts to respond to it.
  Expected: 403/404; no state change.
