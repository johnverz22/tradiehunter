# TradieHunter — Functional QA Guide

Manual release pass, organised by actor. Automated harnesses ([TESTING.md](TESTING.md)) cover happy paths only and do not replace this. Run flow-v1 jobs against the legacy rules and flow-v2 jobs against §6; both must pass until `JobFlow:Version` flips.

## 0. Conventions

- **Severity:** `[BLOCKER]` cannot ship · `[MAJOR]` feature broken · `[MINOR]` cosmetic.
- **Money:** exact 2-dp decimals; any `150.0001` is a bug. **Time:** UTC on the wire, local on screen.
- **Roles:** Homeowner, Tradie, Staff, Superadmin (no `Admin`).
- **Brand:** user-facing surfaces say **TradieHunter** ("Hunter" amber in the wordmark). `fixo` package, `Fixo*` namespaces and `nz.co.fixo.fixo` are intentional, not bugs.
- **State-change triple (assert on every transition):** SignalR `JobStatusChanged` received · `JobStatusHistory` row with `ActorRole` (+ reason code) · correct new status. A missing leg is a bug even if the UI looks right.
- **Commission** visible to tradies only. **Address privacy:** assigned tradie sees suburb/city only until `Booked`; any earlier leak is a `[BLOCKER]`.
- **Homeowner UI shows 4 stages** (v2 stepper: Requested → Booked → In progress → Review & approve → Pay → Completed), a presentation of the 10 server states.

## 1. Environment and accounts

| # | Check | Expected |
|---|---|---|
| ENV-01 | `docker compose up` | API, Postgres+PostGIS, Azurite, Redis, Hangfire healthy; `/hangfire` reachable (Superadmin) |
| ENV-02 | `GET /api/config/locale` | brand = TradieHunter, commission %, payment instructions, offer timeout, auto-complete window, legal URLs, materials disclaimer |
| ENV-03 | Register a user | OTP email within ~30 s in MailHog, TradieHunter subject |
| ENV-04 | Upload credential, receipt, evidence | Private containers created; reads only via SAS |
| ENV-05 | `GET /api/addresses/search?query=…` | Ranked suggestions with coordinates; rate limit engages on rapid calls |
| ENV-06 | Two devices logged in as different roles | Both connect to the same API; SignalR connected |
| ENV-07 | v2 only: `JobFlow:Version=2`, migration `P12JobFlowV17` applied on a DB copy | No orphaned payments/refunds/payouts; `scripts/p12-smoke.sh` passes |

Accounts (create fresh per run): HOMEOWNER-A (verified), HOMEOWNER-B (unverified, OTP gate), TRADIE-VERIFIED (credential, schedule, rates, bank details), TRADIE-UNVERIFIED, TRADIE-2 (second verified, sequential offers), TRADIE-PAUSED (`isAvailable=false`), STAFF, SUPERADMIN. Devices: **HO** (homeowner app), **TR** (tradie app), **ADMIN** (web).

## 2. Shared and auth

- Register → OTP (wrong, expired, resend timer, paste of full code) → login; Google login → role select with one-time registration token (missing/expired/reused → 400).
- `register` with role Staff or Superadmin → 400. Six bad logins → 429 lockout.
- Staff invite (Superadmin only) with a 24 h token; Staff cannot invite.
- Refresh rotation and logout revoke; web admin uses cookie auth (no token in `localStorage`); `GET /hangfire` unauthenticated → 401/redirect.
- Settings, block and report from chat and public profile; blocked user never appears in matching.

## 3. Homeowner

1. **Post a job:** address search (no lat/long fields; editing the address clears coordinates and rates), description, photos (max 5 × 10 MB), timing, urgency. No edit once an offer exists.
2. **Matching:** v1/Quick match: one pending offer, countdown from server expiry, decline/timeout → next, broadened stage, `no_tradie_found` terminal with retry.
3. **Payment (v1 before booking / v2 after approval):** unique reference code, copyable bank details, receipt upload, "under review" vs "verified" copy, rejection → re-upload, no placeholder bank account.
4. **Execution:** `Booked` shows named tradie, schedule, Open chat; v1 confirm completion / v2 itemised approval.
5. **Communication:** chat unlocks at `Booked`; messages list shows avatar, preview, time, unread; quick replies.
6. **Cancel/dispute/review:** cancellation disclosure matches flow; dispute with evidence disables confirm; blind review (hidden until both submit or 7 days).

## 4. Tradie

1. **Onboarding:** wizard sections (profile, address/radius, trades + rates, schedule, credentials, bank details), save/retry preserved; licence mandatory for regulated services; insurance earns a badge.
2. **Leads:** price, distance, time, countdown; direct Accept and Decline share one command; expired/already-handled/duplicate tap handled; paused tradie gets no offers.
3. **Execution:** Navigate / Message / Call ≥ 48 dp; check-in, check-out; cancel behind overflow with confirmation sheet.
4. **Money:** earnings tiles (earned net vs processed vs pending vs failed); platform fee shown after completion; bank details owner-only.

## 5. Admin (web)

Access and RBAC (Staff vs Superadmin) · dashboard (pending verifications equals credential queue; missing metrics "—") · users and flags (warn, suspend, resolve) · credentials (approve; reject needs a reason) · payments (expected amount beside receipt, SLA amber > 15 min, red > 30 min, duplicate receipt rejected) · refunds (editable penalty and hours, proof upload, homeowner pushed) · payouts and batches (bank details masked except last 4, Process disabled without bank details) · disputes (chat + evidence visible, outcome recorded) · audit log, settings.

## 6. v1.7 flow (flow version 2)

**Posting**
- [ ] Hourly job posts with no rate, hours or date (Flexible default). Specific date / range require future dates; Flexible/ASAP with dates → 400.
- [ ] Hourly | Project control; switching keeps shared input; hourly never shows project fields; project extras (budget range, materials, site visit, notes, up to 10 attachments).
- [ ] Submit lands on `/jobs/:id/tradies`.

**Browse and request**
- [ ] List shows the service rate with "Incl. GST" / "No GST charged"; sort and filters hit the server; unlicensed tradies never listed for regulated services.
- [ ] Profile with `jobId` shows rate + "Request this tradie"; without `jobId` unchanged.
- [ ] Request creates an offer for **exactly** the chosen tradie with the rate snapshot; optional message delivered; no chat before Booked.
- [ ] Second pending hourly request → 409; 4th concurrent quote request → 409.
- [ ] Offer expiry: ASAP 15–30 min, flexible 2–4 h. Decline/timeout returns to the list without auto-broaden. `match_result_screen` no longer auto-selects `matches[0]`.

**Pay at completion**
- [ ] Accept → Booked → check-in → check-out `{finalHours}` → Approve → AwaitingPayment → receipt → PaymentReview → staff verify → **Completed** + payout `Pending`. Every edge covered by `JobFlowTransitionTests`.
- [ ] Rejected edges: `Requested→AwaitingPayment`, `PaymentReview→Booked`, `AwaitingConfirmation→Completed`, expiry of AwaitingPayment/PaymentReview.
- [ ] Legacy v1 in-flight jobs finish on the old rules (verify → Booked, expiry → Expired, confirm → Completed).
- [ ] Summary itemised; approve blocked (409) while an adjustment is Pending; "higher than estimate" banner exactly when above estimate + 15%; 48 h auto-approve only inside tolerance, otherwise escalates to staff.
- [ ] Overdue: after 72 h reminders, `OverduePayment` flag, posting blocked, job stays payable (no cancellation).
- [ ] Payout gross = `FinalAmount`; commission on labour only by default; toggling `CommissionAppliesTo` changes it.
- [ ] Stepper and card copy ("$XX/hr · total confirmed on completion" / "est. $YYY", "date TBC"); admin queue row itemised with completion date; overdue view lists only past-due v2 jobs.

**Price adjustments**
- [ ] Tradie proposes during Booked/InProgress/AwaitingConfirmation; homeowner gets push + `JobAdjustmentChanged`.
- [ ] Only Approved count; declined/withdrawn/expired never bill; decisions audited; Pending expires at 48 h (reminder 24 h); caps enforced server-side; no auto-approval path; `scope_change_declined` has no penalty.

**Projects and quotes**
- [ ] QuoteRequest → "Submit quote" form (Fixed / EstimateRange / HourlyWithCap); GST-registered tradies must send `gstIncluded: true`, unregistered `false`.
- [ ] Comparison shows price + GST label, inclusions/exclusions, start date, rating; accepting one declines the rest atomically and books with the pricing model snapshotted.
- [ ] Quote ≥ NZD 30,000: contract gate blocks booking until confirmed/attached. Fixed final = agreed + approved adjustments; range/cap validated at completion.
- [ ] Legal review recorded before enabling projects in production.

## 7. Parallel two-device checks

Every state change must update both devices and the admin tab without refresh. Cover: offer arrives and counts down on TR while HO waits · accept moves both to `Booked` · adjustment proposal pushes to HO and decision pushes to TR · check-out appears on HO · receipt upload appears in the admin queue within seconds · verify completes the job on both · adverse races: two Accept taps, accept at expiry, cancel while the other side acts, double-tap Verify/Process/Confirm → one transition.

## 8. Cross-cutting invariants (every run)

SignalR parity · UTC vs local across the NZST/NZDT boundary · exact cents in totals, refunds, payouts, commission · SAS URLs (15 min, no anonymous read) · RBAC (owner-only 404, admin-only 403, anonymous 401) · double-submit safe · "TradieHunter" on splash, app bar, push titles, admin sidebar/tab · every transition writes history with `ActorRole` · address privacy · accessibility spot-check at text-scale 2.0 and 320 px width (targets ≥ 48 px, no clipped CTAs).

## 9. Known gaps (do not file as new bugs)

| Item | Status |
|---|---|
| P9 leftovers (release logging, FCM routing comment, interceptor queue, in-memory access token) | Open: track, don't mark pass. P9-06 rotation: confirm in code |
| Data retention / purge / anonymisation (P11) | Specified, **not built**: flag to PM |
| In-app payments, deposits, milestones, automated disputes, ML matching, referrals | Out of scope |
| Materials billing | v1 off-platform disclaimer; v2 uses price adjustments |

## 10. 15-minute smoke (v2)

1. Register homeowner → OTP → login. 2. Tradie wizard → credential → Staff approves. 3. Post job (address search, Flexible). 4. Choose tradie → request → TR accepts → both `Booked`. 5. Check-in → propose adjustment → HO approves → check-out. 6. HO approves & pays → receipt → Staff verifies → `Completed`, payout `Pending`. 7. Second job: HO cancels `Booked` → no refund, flags updated. 8. `register` with role 2 → 400; 6 bad logins → 429. 9. `docker compose ps` clean, no error spam, Hangfire jobs succeeded.

## 11. Bug report and sign-off

```md
ID: TH-QA-###        Severity: BLOCKER / MAJOR / MINOR
Env: commit SHA, image tags, device + OS, API URL, JobFlow version
Accounts: roles used (never paste passwords or tokens)
Steps: 1. … 2. …
Expected / Actual: (+ status codes; SignalR received? Y/N; history row? Y/N)
Evidence: response body, screenshots, Hangfire state
```

| Section | Tester | Date (UTC) | Pass/Fail | Notes |
|---|---|---|---|---|
