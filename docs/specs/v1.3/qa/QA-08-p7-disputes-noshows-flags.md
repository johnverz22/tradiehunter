# QA-08 — P7 Disputes, no-shows, flags

Spec: `../../v1.2/P7-disputes-noshows-flags.md`. Inherited from v1.2.

**v1.3 addendum:** Blind reviews must NOT be revealed for disputed jobs
until the dispute is resolved (P10-11 implementation note). See QA-12 for
that edge case.

Precon: active + completed jobs with both parties; Staff + Superadmin logins.

- [ ] **P7-01 — Open dispute → Disputed**
  Priority: BLOCKER
  1. `POST /api/disputes` (homeowner, then a second job as tradie).
  Expected: `Dispute` row (`OpenedBy`, `OpenedAtUtc`, `Status=Open`);
  job → `Disputed`.

- [ ] **P7-02 — Text evidence**
  Priority: MAJOR · Precon: P7-01
  1. `POST /api/disputes/{id}/evidence` with text.
  Expected: `DisputeEvidence(Type=Text)` saved, attributed to submitter.

- [ ] **P7-03 — File evidence via private blob**
  Priority: MAJOR · Precon: P7-01
  1. Same endpoint, multipart photo/document.
  Expected: stored via `BlobStorageService` with `FileKey`; retrievable via
  signed/SAS URL, never public.

- [ ] **P7-04 — Mobile dispute UI**
  Priority: MAJOR
  1. "Open Dispute" from job details → reason + details + camera/gallery
     / text attach → submit → re-open job screen.
  Expected: submits to API; job screen shows dispute status + existing evidence.

- [ ] **P7-05 — No-show, tradie accused (reassign OR full refund)**
  Priority: BLOCKER
  1. Homeowner `POST /api/jobs/{id}/no-show` (tradie absent).
  Expected: flag against tradie; homeowner offered REASSIGN (→ `Requested`
  + rematch) or CANCEL + full refund; accused tradie notified.

- [ ] **P7-06 — No-show, homeowner accused (penalty cancel)**
  Priority: BLOCKER
  1. Tradie `POST /api/jobs/{id}/no-show` after the grace period.
  Expected: flag against homeowner; job cancelled with partial refund
  (homeowner penalty); homeowner notified.

- [ ] **P7-07 — No-show button visibility + dialogs**
  Priority: MINOR
  1. Check "Report No-Show" before scheduled time + grace (expect hidden),
     after (expect shown), on both roles.
  Expected: homeowner dialog = Reassign vs Cancel&Refund; tradie dialog
  warns the job will be cancelled.

- [ ] **P7-08 — Admin dispute list**
  Priority: MAJOR · Precon: open disputes exist
  1. Open Disputes page (default `Open` filter; try All/Open/Resolved/Escalated).
  Expected: all open disputes listed under the right tabs.

- [ ] **P7-09 — Admin dispute detail**
  Priority: MAJOR · Precon: P7-01–03
  1. Open one dispute.
  Expected: job context, both parties, chat history, check-in/out time
  logs, ALL evidence visible.

- [ ] **P7-10 — Resolve with Full/Partial refund**
  Priority: BLOCKER
  1. Resolve with `FullRefund` (or `PartialRefund`) + `DecisionNote`.
  Expected: `Dispute → Resolved` (`DecidedBy`, `DecidedAtUtc`, `Outcome`,
  note); refund generated when applicable.

- [ ] **P7-11 — Resolve with NoRefund**
  Priority: MAJOR
  1. Resolve another dispute `NoRefund`.
  Expected: `Resolved`, NO refund row; parties notified.

- [ ] **P7-12 — Flag counters + threshold**
  Priority: MAJOR
  1. Trigger `RepeatCanceller`/`RepeatNoShow` events to the threshold.
  Expected: `AccountFlag.Counter` increments per type; `ThresholdHit=true`
  at threshold.

- [ ] **P7-13 — Flagged-account actions (warn/suspend/resolve)**
  Priority: MAJOR · Precon: P7-12
  1. Admin users view: filter `ThresholdHit==true`; open profile; Warn,
     Suspend, Resolve.
  Expected: filter works; history visible; each action persists (`Resolved`
  + `ResolvedAtUtc` on resolve); suspended user blocked from login/matching.
