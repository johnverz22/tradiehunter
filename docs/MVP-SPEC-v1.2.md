# Merged state machine and data model (manual receipt payments)

**One consequence first:** admin verification is now on the critical path to "Booked." Since a human verifies every receipt, the admin web app moves from a "before real users" item to a Tier 1 dependency. A slow admin queue directly hurts your "minutes, not days" goal.

## 1. Payment timing

Spec 2 is inconsistent here: its happy path pays after the tradie accepts, while Scenarios 2-3 pay first. With manual verification, **pay after acceptance** is the better choice. If the homeowner must pay and wait for an admin before matching even starts, the Aha moment dies.

The flow becomes: **match → tradie accepts → homeowner pays via transfer and uploads a receipt → admin verifies → Booked.**

The tradie holds the slot during a configurable payment window (say 2 hours). If the homeowner doesn't pay in time, the job expires and the tradie is released.

## 2. Job statuses

| Status | Meaning |
|---|---|
| Requested | Matching in progress (auto, then broadened, then exhausted) |
| Awaiting Payment | Tradie accepted, homeowner must pay and upload a receipt |
| Payment Review | Receipt submitted, in the admin queue |
| Booked | Payment verified, time locked, reminders scheduled |
| In Progress | Tradie checked in |
| Awaiting Confirmation | Tradie marked done, homeowner must confirm |
| Completed | Confirmed, or auto-confirmed after a window |
| Cancelled | Terminal, always with a reason code and actor |
| Expired | Terminal (no payment, no response) |
| Disputed | Open dispute, resolves back to Completed or Cancelled with an outcome record |

## 3. Transitions

| From → To | Actor | Guard / note |
|---|---|---|
| Requested → Awaiting Payment | Tradie | Accepts before offer timeout; else system offers to next tradie |
| Requested → Cancelled | System | Matching exhausted (`no_tradie_found`) |
| Awaiting Payment → Payment Review | Homeowner | Receipt uploaded |
| Awaiting Payment → Expired | System | Payment window elapsed (`no_payment`) |
| Payment Review → Booked | Admin/Staff | Receipt verified against the bank statement |
| Payment Review → Awaiting Payment | Admin/Staff | Receipt rejected with reason (limit re-uploads) |
| Booked → In Progress | Tradie | Check-in at or after start time |
| Booked → Requested | System | Tradie cancels or is unavailable; re-match excluding that tradie, payment stays attached |
| Booked → Cancelled | Homeowner / Tradie / Admin | Reason code, refund flagged if paid |
| In Progress → Awaiting Confirmation | Tradie | Marks done, `ended_at` recorded |
| In Progress → Cancelled | Homeowner / Tradie / Admin | Partial work, hours worked recorded |
| Awaiting Confirmation → Completed | Homeowner or System | Auto-complete after N hours of no response |
| Awaiting Confirmation → Disputed | Homeowner | Refuses acceptance |
| Any active → Disputed | Either party | Evidence upload opens |
| Disputed → Completed / Cancelled | Admin | Outcome: full refund, partial, none |

## 4. Reason codes and actors

Instead of the 17 tags in Spec 2, store `cancelled_by` (homeowner, tradie, admin, system) plus a `reason_code`:

- `homeowner_changed_mind`
- `tradie_unavailable`
- `tradie_no_show`
- `homeowner_no_show`
- `scope_change_declined`
- `homeowner_issue` and `tradie_issue` (partial completion)
- `emergency`
- `no_tradie_found`
- `no_payment`
- `system_failure`
- `dispute_outcome`

**Account flags** (repeat canceller, repeat no-show tradie) are separate records tied to users, not to jobs. Scenario 22 was mixing the two.

## 5. Payment and refund

Payment has its own small state machine, separate from job status: `pending → submitted → verified` or `rejected`. Refunds are tracked separately: `none → pending → processed`.

Since money moves off-platform, refunds are also manual. The admin sends the transfer through their own bank, then records the reference and proof in the app. The system only suggests the amount:

**refund = paid − penalty − (rate × hours worked)**

Penalty and hours worked are editable by admin. `hours_worked` comes from tradie check-in and check-out timestamps, and admin can override.

## 6. Payment abstraction (white-label, multi-country)

Isolate payments behind an interface so BNZ, Stripe, or a local provider later is a new implementation rather than a rewrite:

- **`IPaymentProvider`**: `CreatePayment`, `GetStatus`, `Refund`, plus webhook handling for future providers.
- **`ManualReceiptProvider`** (MVP): `CreatePayment` returns instructions, status changes are driven by admin actions, and `Refund` creates a pending refund for an admin to process manually.
- **Per-deployment config:** currency, payment instructions (account name and number, reference format), payment window, and enabled provider. This fits your existing locale config.
- **Store `provider` and `provider_reference` on the payment** from day one, so nothing changes structurally when an integration arrives.

Practical controls for manual verification:

- Generate a **unique reference code per job** that the homeowner puts in the transfer reference. Admin matches it against the bank statement, which is the real control since screenshots are easy to fake.
- Hash receipt images to catch the same receipt reused on another job.
- Show the expected amount next to the receipt in the admin queue.

## 7. Data model (core tables)

| Table | Key fields |
|---|---|
| `users` | id, email, phone, role (homeowner, tradie, staff, superadmin), otp_verified, status |
| `tradie_profiles` | user_id, base_address, geo point, service_radius, verification_status, cancel and no-show counters |
| `tradie_credentials` | tradie_id, type, file_key, status, reviewed_by, reviewed_at |
| `tradie_schedules` | tradie_id, weekday, start_time, end_time |
| `services` | id, name, category |
| `tradie_rates` | tradie_id, service_id, hourly_rate, currency |
| `jobs` | id, homeowner_id, service_id, description, photos, urgency, location, `scheduled_start`, `hours`, `hourly_rate_snapshot`, `total_amount`, status, assigned_tradie_id, `started_at`, `ended_at`, `reference_code` |
| `job_offers` | job_id, tradie_id, offered_at, expires_at, response (accepted, declined, timed_out), stage (auto, broadened) |
| `job_status_history` | job_id, from, to, actor_id, actor_role, reason_code, note, at |
| `payments` | job_id, amount, method, provider, provider_reference, status, receipt_file_key, receipt_hash, verified_by, verified_at, reject_reason |
| `refunds` | job_id, payment_id, amount, penalty, hours_worked_amount, status, processed_by, reference, proof_file_key |
| `disputes` | job_id, opened_by, status, outcome, decided_by, decision_note |
| `dispute_evidence` | dispute_id, submitted_by, type, file_key or text |
| `reviews` | job_id, from_user, to_user, stars, comment, status (visible, disputed, removed) |
| `account_flags` | user_id, type, created_by, note, resolved |
| `messages` | job_id, sender_id, body, at (readable by admin during disputes) |
| `device_tokens` | user_id, device_id, fcm_token, last_seen |

Store a **rate snapshot** on the job so later profile rate edits don't change existing bookings.

## 8. Changes to the original MVP spec

- **Tier 1 additions:** OTP, tradie credential upload, weekly schedule, hourly rate, hours and start time on the job, offer timeout with next-best re-offer, payment upload, and the admin payment queue.
- **Admin dashboard queues** (all in the React app): payment verification, credential verification, refunds pending, disputes with chat history visible. A SignalR or push alert to staff when a receipt lands will help keep verification fast.
- **Address privacy:** reveal the exact address and contact details only at Booked, not on acceptance. This resolves the conflict with Scenario 9.
- **New metric:** median payment verification time, since it now sits between match and Booked.
- **Match-to-confirmation** should be measured to Awaiting Payment (tradie committed) and to Booked (fully confirmed) separately.
- **Deferred:** BNZ and other integrations, cash pool, automated penalties, automated hours tracking, scope-change flows, and the "Interested" job board.
- **Compliance:** even with manual verification, Fixo is still receiving customer funds for a third party. Get local legal advice per country before launching, since the rules differ by jurisdiction.