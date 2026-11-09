# QA-11 — Cross-cutting checks + regression + sign-off

Run every full pass, regardless of which phase changed.

## Cross-cutting (every state change)

- [ ] **X-01 — SignalR parity (never REST-only)**
  1. With Flutter + React admin connected, perform each transition in QA-04–07.
  Expected: BOTH clients receive `JobStatusChanged`; no stale screens.

- [ ] **X-02 — Push parity**
  1. Trigger: offer, verify/reject, cancel, refund-processed, reminders,
     auto-complete, dispute, no-show.
  Expected: FCM reaches backgrounded devices; foreground shows in-app too.

- [ ] **X-03 — RBAC matrix**
  1. Replay each endpoint as HOMEOWNER-A vs HOMEOWNER-B vs Tradie vs Staff
     vs Superadmin vs anon.
  Expected: owner-only stays owner-only (404 for non-owner reads);
  admin-only stays admin-only (403); anon → 401.

- [ ] **X-04 — UTC invariant**
  Priority: MAJOR
  1. Create jobs/OTPs/offers/payments/check-ins across an NZST/NZDT boundary.
  Expected: DB stores UTC; mobile renders local via configured
  `DefaultTimezone` (no hardcoded zone in client).

- [ ] **X-05 — Decimal invariant**
  Priority: MAJOR
  1. Grep payloads for `150.0000001`-style artefacts; process penny refunds.
  Expected: exact cents everywhere; locale-driven display.

- [ ] **X-06 — SAS expiry closes access**
  1. Capture any credential/receipt/evidence SAS URL; reuse after expiry.
  Expected: fails closed; no fallback public path.

- [ ] **X-07 — Double-submit safety**
  1. Double-tap Approve / Verify / Process Refund / Accept offer.
  Expected: second attempt 409 or idempotent no-op; exactly one state change.

- [ ] **X-08 — Cancel-during-review**
  1. Cancel a job while `PaymentReview` pending.
  Expected: defined outcome — no orphan `Payment`, no stuck offer, admin
  queue consistent.

## 15-minute regression smoke

- [ ] **R-01** Register homeowner → verify OTP → login. [QA-02]
- [ ] **R-02** Tradie onboarding → credential → Staff approves → verified. [QA-02]
- [ ] **R-03** Homeowner posts job (service + rate + hours + future start). [QA-03]
- [ ] **R-04** Match → tradie accepts → `AwaitingPayment`. [QA-04]
- [ ] **R-05** Upload receipt → Staff verifies → `Booked`. [QA-05]
- [ ] **R-06** Check-in → check-out → confirm → `Completed` → review. [QA-06]
- [ ] **R-07** Second job: homeowner cancels `Booked` → refund `Pending` →
      Staff processes → homeowner notified. [QA-07]
- [ ] **R-08** `register` with `"role": 2` → 400; 6 bad logins → 429. [QA-10]
- [ ] **R-09** Green-board check: `docker compose ps` clean, no error spam in
      api logs, Hangfire dashboard shows succeeded (not enqueued-stuck) jobs.

## Bug report template

```md
ID: FIXO-QA-###
Spec ref: (file + task, e.g. P4-manual-payment-admin-queue.md P4-05)
Case: (e.g. P4-06)
Severity: BLOCKER / MAJOR / MINOR
Env: commit SHA, image tags, device/emulator + OS
Accounts: roles used (never paste passwords/tokens)
Steps: 1. … 2. … 3. …
Expected: (from this file)
Actual: (status codes + SignalR received? Y/N)
Evidence: API response, history row, Hangfire state, screenshots
Workaround: (if any)
```

## Sign-off

| Area | Tester | Date (UTC) | Pass/Fail | Notes |
|------|--------|------------|-----------|-------|
| QA-00 Env | | | | |
| QA-01 P0 | | | | |
| QA-02 P1 | | | | |
| QA-03 P2 | | | | |
| QA-04 P3 | | | | |
| QA-05 P4 | | | | |
| QA-06 P5 | | | | |
| QA-07 P6 | | | | |
| QA-08 P7 | | | | |
| QA-09 P8 gaps accepted | | | | |
| QA-10 P9 (open items owned) | | | | |
| QA-11 Cross-cutting + smoke | | | | |

Release rule: all BLOCKER cases green; no open MAJOR without a tracked
workaround; QA-09/QA-10-open items accepted with owner + date, never
silently skipped.
