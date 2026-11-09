# Fixo v1.2 — Manual Test Items (index)

Companion to `../QA-functional-testing-guide.md`. Each file is one
printable checklist for a manual pass. Work top to bottom; phases depend
on earlier ones (you need a verified tradie from QA-02 before QA-04 works).

## Files

| File | Phase | # cases |
|------|-------|---------|
| [QA-00-environment.md](QA-00-environment.md) | Env setup + test accounts | 4 |
| [QA-01-p0-foundation.md](QA-01-p0-foundation.md) | P0 roles / state machine / migration | 10 |
| [QA-02-p1-registration-otp.md](QA-02-p1-registration-otp.md) | P1 OTP / Google / invites / onboarding / credential queue | 28 |
| [QA-03-p2-job-request.md](QA-03-p2-job-request.md) | P2 service search + job create | 10 |
| [QA-04-p3-matching-offers.md](QA-04-p3-matching-offers.md) | P3 sequential offers / timeouts | 12 |
| [QA-05-p4-payment.md](QA-05-p4-payment.md) | P4 manual payment / admin queue / expiry | 14 |
| [QA-06-p5-booked-completed.md](QA-06-p5-booked-completed.md) | P5 check-in/out / reminders / chat lock | 12 |
| [QA-07-p6-cancellations-refunds.md](QA-07-p6-cancellations-refunds.md) | P6 cancel flows / refund queue | 12 |
| [QA-08-p7-disputes-noshows-flags.md](QA-08-p7-disputes-noshows-flags.md) | P7 disputes / no-shows / flags | 13 |
| [QA-09-p8-hardening-gaps.md](QA-09-p8-hardening-gaps.md) | P8 known gaps (assert absence) | 8 |
| [QA-10-p9-auth-security.md](QA-10-p9-auth-security.md) | P9 implemented vs open items | 16 |
| [QA-11-crosscutting-regression.md](QA-11-crosscutting-regression.md) | Cross-cutting + 15-min smoke | 17 |

## How to run

1. Boot the stack (`docker compose up`), seed the 7 accounts in QA-00.
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
- Statuses: `Requested → AwaitingPayment → PaymentReview → Booked →
  InProgress → AwaitingConfirmation → Completed`, plus `Cancelled`,
  `Expired`, `Disputed`.
