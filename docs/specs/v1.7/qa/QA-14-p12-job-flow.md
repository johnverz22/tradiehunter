# QA-14 — P12 Job Flow Revision (v1.7)

**Status:** Ready for QA · **Scope:** Phase 12 tasks P12-01…P12-28 · **References:** [specification.md](../specification.md) · [tasks.md](../tasks.md)

This checklist covers the v1.7 job-flow revision. It inherits every v1.2/v1.3 case (QA-00–QA-13 under `docs/specs/v1.3/qa/`) — run those against flow-v1 jobs first, then this file against flow-v2 jobs. A flow version is stamped on the job at posting (`JobFlow:Version`); both flows must keep passing until the flag flips.

## 14.0 Environment

- [ ] Stack running via `docker compose up`; `JobFlow:Version = 2` in `backend/appsettings.Development.json`.
- [ ] Demo accounts seeded (homeowner / tradie / admin); `scripts/p12-smoke.sh` passes end-to-end.
- [ ] Migration `P12JobFlowV17` applies cleanly on a copy of the dev DB; no orphaned payments/refunds/payouts (P12-27 dry-run report recorded).

## 14.1 Posting (P12-02, P12-04, P12-21, P12-22)

- [ ] Hourly job can be posted with **no rate, no hours, no date** (Flexible default).
- [ ] Timing selector: Flexible / ASAP / Pick a date / Date range; SpecificDate+DateRange require future dates; Flexible/Asap reject dates (server 400 with clear message).
- [ ] "Estimated hours" optional; helper copy "Skip if unsure — total is confirmed when the job is done."
- [ ] Post Job screen has the Hourly | Project segmented control; switching never loses shared input; hourly never shows project fields.
- [ ] Project extras: budget range, materials responsibility, site-visit welcome, scope notes, PDF attachments (cap 10, config) vs hourly 5-photo cap (P10-14 unchanged).
- [ ] Submit lands on `/jobs/:id/tradies` (Choose-a-Tradie), not the matching screen.

## 14.2 Tradie browse & request (P12-05–P12-09)

- [ ] Tradie list shows rate for the job's service with **"Incl. GST"** (registered) / **"No GST charged"** (unregistered) labels (D8).
- [ ] Sort (best/rating/distance/rate) and filters (verified/insured/available) hit the server and return stable results; licence-gated services never list unlicensed tradies.
- [ ] Profile opened with `jobId` shows the service rate + sticky "Request this tradie"; without `jobId` behaves exactly as before.
- [ ] Direct request creates an offer for **exactly** the chosen tradie; `hourlyRateSnapshot` equals the listed rate; optional message delivered (D3 — no chat before Booked).
- [ ] Hourly job: second request while one is pending → 409. Project job: 4th concurrent quote request → 409 (cap 3).
- [ ] Urgency-aware expiry: ASAP/Emergency offers expire in the configured 15–30 min window; flexible in the 2–4 h window (D7).
- [ ] Decline/timeout → job stays Requested; homeowner returns to the list; no auto-broaden on direct requests. Quick match unchanged.
- [ ] `match_result_screen` auto-select of `matches[0]` is gone.

## 14.3 Pay-at-completion (P12-10–P12-15)

- [ ] State machine: accept → Booked; check-in; check-out `{finalHours}`; homeowner Approve → AwaitingPayment; receipt → PaymentReview; staff verify → **Completed** (+ pending payout). Every edge tested by `JobFlowTransitionTests`.
- [ ] Removed edges rejected: `Requested→AwaitingPayment`, `PaymentReview→Booked`, `AwaitingConfirmation→Completed` (v2), expiry of AwaitingPayment/PaymentReview (v2).
- [ ] Legacy (flow v1) in-flight jobs complete under the OLD rules (verify→Booked, expiry→Expired, confirm→Completed).
- [ ] Completion summary itemised (labour / each approved adjustment / total vs estimate); Approve blocked while any adjustment Pending (409).
- [ ] "Higher than estimate" banner shows exactly when FinalAmount > estimate + 15% (configurable); auto-approve (48h) only inside tolerance/no-pending-adjustments — otherwise escalates to staff (job flagged, no silent approval).
- [ ] Overdue payment: window (72h default) elapses → reminders, homeowner flagged `OverduePayment`, posting blocked; job stays payable. NO cancellation/expiry of finished work (D1/D4).
- [ ] Payout created on verify with GrossAmount = FinalAmount; commission on LabourOnly by default (config `PayoutOptions:CommissionAppliesTo`); toggle to LabourAndAdjustments changes commission accordingly.
- [ ] Mobile stepper: Requested → Booked → In progress → Review & approve → Pay → Completed; cards show "$XX/hr · total confirmed on completion" or "est. $YYY"; "date TBC" on flexible cards.
- [ ] Admin payment queue: itemised amount + "work completed on \<date\>"; verify copy says completed/payout pending; overdue view lists only past-due v2 AwaitingPayment jobs.

## 14.4 Price adjustments (P12-17–P12-20)

- [ ] Tradie proposes (kind/amount/description/evidence) during Booked/InProgress/AwaitingConfirmation; homeowner gets push + SignalR `JobAdjustmentChanged`.
- [ ] Only Approved adjustments change AdjustmentsTotal; declined/withdrawn/expired never bill. Approve/Decline with optional note recorded in audit log.
- [ ] Pending adjustments expire at 48h (24h reminder); max-pending-per-job and staff-review threshold enforced server-side.
- [ ] No pre-approval/auto-approval path exists (D6 cut). `scope_change_declined` cancellation carries no penalty (D4).

## 14.5 Projects & quotes (P12-23–P12-25; P12-26 deferred)

- [ ] QuoteRequest offers → tradie sees "Submit quote" form (Fixed / EstimateRange / HourlyWithCap with required fields).
- [ ] D8: GST-registered tradies must submit `gstIncluded: true`; unregistered `false` — server rejects mismatches.
- [ ] Homeowner quote comparison shows price + GST label, inclusions/exclusions, start date, rating; accept-one-declines-rest atomically; job books with agreed pricing model snapshotted.
- [ ] Quote ≥ NZD 30,000 (config): accept returns the written-contract gate (Building Act s362F notice); booking blocked until homeowner confirms/attaches.
- [ ] Fixed quotes: FinalAmount = agreed price + approved adjustments; EstimateRange/HourlyWithCap validated at completion (above cap/range needs an approved adjustment).

## 14.6 Regression inheritance

- [ ] All QA-00–QA-13 suites still pass for flow-v1 jobs.
- [ ] Address-resolution checks (`scripts/address-resolution-tests`, `flutter test test/address_resolution_test.dart`) unchanged and green.
- [ ] `backend` unit tests green: `JobFlowTransitionTests`, `JobMoneyTests`, `JobValidatorTests` + existing email suites.
