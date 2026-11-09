# TradieFixo v1.3 — Manual Test Items (index)

Companion to `../QA-functional-testing-guide.md`. Each file is one
printable checklist for a manual pass. Work top to bottom; phases depend
on earlier ones (you need a verified tradie from QA-02 before QA-04 works).

QA-01 through QA-11 are inherited unchanged from v1.2 (P0–P9 are additive).
QA-12 and QA-13 cover the new v1.3 phases.

## Files

| File | Phase | # cases |
|------|-------|---------|
| [QA-00-environment.md](QA-00-environment.md) | Env setup + test accounts (v1.3 shape) | 5 |
| [QA-01-p0-foundation.md](QA-01-p0-foundation.md) | P0 roles / state machine / migration | 10 |
| [QA-02-p1-registration-otp.md](QA-02-p1-registration-otp.md) | P1 OTP / Google / invites / onboarding / credential queue | 28 |
| [QA-03-p2-job-request.md](QA-03-p2-job-request.md) | P2 service search + job create | 10 |
| [QA-04-p3-matching-offers.md](QA-04-p3-matching-offers.md) | P3 sequential offers / timeouts | 12 |
| [QA-05-p4-payment.md](QA-05-p4-payment.md) | P4 manual payment / admin queue / expiry | 14 |
| [QA-06-p5-booked-completed.md](QA-06-p5-booked-completed.md) | P5 check-in/out / reminders / chat lock | 12 |
| [QA-07-p6-cancellations-refunds.md](QA-07-p6-cancellations-refunds.md) | P6 cancel flows / refund queue | 12 |
| [QA-08-p7-disputes-noshows-flags.md](QA-08-p7-disputes-noshows-flags.md) | P7 disputes / no-shows / flags | 13 |
| [QA-09-p8-hardening-gaps.md](QA-09-p8-hardening-gaps.md) | P8 known gaps (assert absence / partial) | 8 |
| [QA-10-p9-auth-security.md](QA-10-p9-auth-security.md) | P9 implemented vs open items | 16 |
| [QA-11-crosscutting-regression.md](QA-11-crosscutting-regression.md) | Cross-cutting + 15-min smoke | 17 |
| [QA-12-p10-business-rules-payouts-rebrand.md](QA-12-p10-business-rules-payouts-rebrand.md) | P10 payouts / blind reviews / availability / rebrand / SLA / matching | 30 |
| [QA-13-p11-compliance-data-lifecycle.md](QA-13-p11-compliance-data-lifecycle.md) | P11 data retention / purge / legal config | 10 |

## How to run

1. Boot the stack (`docker compose up`), seed the 8 accounts in QA-00
   (v1.3 adds TRADIE-PAUSED vs v1.2's 7 accounts).
2. Open one file at a time. Each case has: **Priority**, **Precon**,
   numbered **Steps**, and **Expected**. Tick `- [ ]` → `- [x]`.
3. Every state change must also satisfy the triple: SignalR
   `JobStatusChanged` received + `JobStatusHistory` row with `ActorRole` +
   correct new status. If any leg is missing, raise a bug even if the UI
   looks right.
4. Log failures with the template at the bottom of QA-11.

## Conventions

- `[BLOCKER]` cannot ship. `[MAJOR]` feature broken. `[MINOR]` cosmetic.
- Money: exact 2-dp `decimal`. Time: UTC on wire, local on screen.
- Roles: `Homeowner`, `Tradie`, `Staff`, `Superadmin` (no `Admin`).
- App name is **TradieFixo** on all user-facing surfaces (not "Fixo").
- Statuses: `Requested → AwaitingPayment → PaymentReview → Booked →
  InProgress → AwaitingConfirmation → Completed`, plus `Cancelled`,
  `Expired`, `Disputed`.
- Commission is visible to tradies on completed job detail (gross → fee →
  net). Homeowners never see the commission breakdown.

## Sign-off table

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
| QA-12 P10 | | | | |
| QA-13 P11 | | | | |

Release rule: all BLOCKER cases green; no open MAJOR without a tracked
workaround; QA-09/QA-10-open items accepted with owner + date, never
silently skipped.
