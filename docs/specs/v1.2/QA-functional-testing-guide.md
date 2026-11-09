# Fixo v1.2 — Functional QA Test Guide

Derived from `docs/specs/v1.2/P0`–`P9` (+ implementation notes in each spec).
Use this as the manual pass before any release; automated smoke scripts
(`scripts/p3-smoke.sh`, `scripts/p4-smoke.sh`, `scripts/web/render-probe.py`,
`scripts/e2e-credentials.py`) cover the happy paths but do not replace this list.

## 0. Conventions used in this guide

- **Money** is always `decimal`. Assert exact 2-dp values (`$150.00`, never
  `$150.0001`). Any float-style rounding is a bug.
- **Time** is UTC in the DB/API, localised on the client. When checking
  timestamps, compare the UTC wire value AND the rendered local value.
- **State transitions** must go through `IJobStatusService`, emit SignalR
  `JobStatusChanged` (`JobId`, `Status`, `PreviousStatus`, `ReasonCode`,
  `Reason`), and append a `JobStatusHistory` row with `ActorRole` populated.
  If any of the three is missing, file a bug.
- **Severity tags:** `[BLOCKER]` (cannot ship), `[MAJOR]` (feature broken),
  `[MINOR]` (cosmetic/edge).
- **Job lifecycle (v1.2):**
  `Requested → AwaitingPayment → PaymentReview → Booked → InProgress →
  AwaitingConfirmation → Completed`, with side states `Cancelled`, `Expired`,
  `Disputed`.
- **ReasonCodes:** `homeowner_changed_mind`, `tradie_unavailable`,
  `tradie_no_show`, `homeowner_no_show`, `scope_change_declined`,
  `homeowner_issue`, `tradie_issue`, `emergency`, `no_tradie_found`,
  `no_payment`, `system_failure`, `dispute_outcome`.
- **Roles:** `Homeowner`, `Tradie`, `Staff`, `Superadmin`
  (legacy `Admin` no longer exists — any reference to it is a bug).

## 1. Test environment setup

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| ENV-01 | Stack boots | `docker compose up` (OrbStack); API, postgres+PostGIS, Azurite, redis, Hangfire all healthy | No container crash-loops; Hangfire dashboard reachable |
| ENV-02 | Config present | `GET /api/config/locale`; inspect `PaymentInstructions` (AccountName, AccountNumber, ReferenceFormat `FIXO-{JobId}`, WindowHours, PaymentsContainer), `OfferTimeoutMinutes`, `AutoCompleteWindowHours` | All keys present, no hardcoded bank details in UI |
| ENV-03 | MailHog receives mail | Register a user; check MailHog/Papercut inbox | OTP email arrives within ~30s |
| ENV-04 | Azurite containers | Upload a credential + a receipt + dispute evidence | `fixo-credentials`, `fixo-payments` containers created lazily; blobs private (no anonymous read) |

### Test accounts (create fresh per run)

- HOMEOWNER-A (verified, with payment-capable job)
- HOMEOWNER-B (unverified — for OTP tests)
- TRADIE-VERIFIED (≥1 approved credential, schedule + rates set)
- TRADIE-UNVERIFIED (no approved credential)
- TRADIE-2 (second verified tradie, for sequential-offer tests)
- STAFF (credential/payment/refund/dispute reviewer)
- SUPERADMIN (staff invites, Hangfire dashboard)

## 2. P0 — Foundation, roles, state machine [BLOCKER]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P0-01 | Config binding | Set bogus `PaymentInstructions:WindowHours`, restart API | API picks up typed value; invalid shape fails fast with clear error, not silent default |
| P0-02 | Role gating | As Homeowner/Tradie, call `POST /api/admin/staff/invite`, `GET /api/admin/credentials/pending`, `GET /api/admin/payments/pending`, `GET /api/admin/refunds/pending` | 403 on all; Staff succeeds on queues; only Superadmin succeeds on staff-invite |
| P0-03 | Legacy `Admin` role gone | Search API + mobile + web for `Admin` (non-compound) enum/string | No matches; only `Staff`/`Superadmin` |
| P0-04 | AuthProvider + EmailVerified tracked | Register password user vs Google user; inspect user record | Password: `AuthProvider=password`, `EmailVerified=false`; Google: `AuthProvider=google`, `EmailVerified=true` |
| P0-05 | JobStatus enum = 10 values | Create/inspect jobs across lifecycle; check mobile `job.dart` + web `job.ts` | Exactly `Requested, AwaitingPayment, PaymentReview, Booked, InProgress, AwaitingConfirmation, Completed, Cancelled, Expired, Disputed` — no `Draft/Matching/Matched/Confirmed/Complete` |
| P0-06 | History enrichment | Perform any transition (e.g. accept offer); read `JobStatusHistory` | Row has `FromStatus`, `ToStatus`, `ActorRole`, `ReasonCode` (nullable), `CancelledBy` (nullable), UTC timestamp |
| P0-07 | Invalid transition rejected | `POST /api/jobs/{id}/confirm` on a `Requested` job; `POST /api/jobs/{id}/check-in` as homeowner | 4xx with guard message; no state change, no history row |
| P0-08 | Legacy status migration | Seed DB with old `Matching`/`Matched`/`Confirmed`/`Complete` rows (or inspect migration) | `Matching,Matched→Requested`; `Confirmed→Booked`; `Complete→Completed`; new required fields backfilled, no nulls |
| P0-09 | Mobile stepper | Walk a job Requested → Payment → Booked → InProgress → Confirmation → Completed on Flutter | Stepper advances linearly; `Disputed`/`Cancelled` render alert/failure visual, not a normal step |
| P0-10 | Web StatusBadge | Open admin job list with one job per status | All 10 statuses render with distinct label/colour (`Disputed` amber/warning, `Booked` blue, etc.) |

## 3. P1 — Registration, OTP, tradie verification [BLOCKER]

### 3.1 Registration & OTP

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-01 | Register sends OTP | `POST /api/auth/register` (Homeowner) → check DB + MailHog | User `EmailVerified=false`, no JWT issued, `email_otps` row (hash, not plaintext, 10-min expiry), email delivered |
| P1-02 | Verify happy path | `POST /api/auth/verify-email` with correct 6-digit code | `EmailVerified=true`, `EmailVerifiedAt` UTC set, JWT returned |
| P1-03 | Wrong-code attempt cap | Submit 5 wrong codes, then the correct one | Correct code rejected after 5 tries (OTP invalidated); must resend |
| P1-04 | Expired OTP | Wait >10 min (or set clock), submit correct code | Rejected as expired; resend required |
| P1-05 | Resend cooldown | `POST /api/auth/resend-otp` twice within 60s | Second call rejected (cooldown); old pending OTPs voided when new one issued |
| P1-06 | Login gating | Login with unverified account | No full JWT; 403 + `{ requiresVerification }`-style signal; mobile routes to `/verify-email`, not dashboard |
| P1-07 | OTP screen (mobile) | Register in app → OTP screen; test 60s resend countdown, submit, resend | 6-box `OtpCodeField` works; countdown mirrors backend; success leaves OTP screen; login-unverified also lands here |
| P1-08 | Google new account | Google SSO with new email | `EmailVerified=true`, JWT issued, routed to role-select (OTP skipped) |
| P1-09 | Google link — verified | Google SSO matching an existing verified password account | Accounts linked, login succeeds |
| P1-10 | Google link — unverified [MAJOR] | Google SSO matching an existing UNVERIFIED password account | Linking blocked with error; mobile routes to OTP screen (does not fail silently, does not create dupe) |

### 3.2 Staff invites (Superadmin only)

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-11 | Invite | `POST /api/admin/staff/invite` as Superadmin | Unverified staff user created; set-password email with secure token sent |
| P1-12 | Invite RBAC | Same endpoint as Staff/Homeowner/Tradie/unauthenticated | 403/401; no user created, no email sent |
| P1-13 | Set password | `POST /api/admin/staff/set-password` with valid token | Password set, `EmailVerified=true`, account active; token single-use (replay → 400) |

### 3.3 Tradie onboarding (mobile, 4-step wizard `/tradie/onboarding`)

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-14 | Step 1 — profile | Save name/phone/address, trade picker, radius (`Decimal`), optional lat+lng | `PUT /api/profile` provisions `TradieProfile`; validation per step blocks advance on bad input |
| P1-15 | Step 2 — rates | Pick services from catalog (grouped by `TradeCategory`), set hourly rates | Rates held as `Decimal` end-to-end (single `toDouble()` at JSON boundary); server 0–10000 range enforced client-side |
| P1-16 | Step 3 — schedule | Set Mon-first weekday rows, `TimeOfDay ↔ HH:mm:ss`, 8am–5pm quick-fill | Weekdays map to .NET `DayOfWeek` 0–6 correctly; saved via `GET/POST /tradie/schedule` |
| P1-17 | Step 4 — credentials | Upload jpg/jpeg/png/pdf ≤10MB via `file_picker` | Multipart `POST /api/tradie/credentials`; record `Pending`; private blob (`fixo-credentials`), `FileKey` returned |
| P1-18 | Pre-profile 403 = empty | Fresh tradie (no `TradieProfile` row) opens wizard; initial `GET /tradie/{rates,schedule,credentials}` | 403 treated as "nothing set yet", not an error; profile read happens first |
| P1-19 | Pending banner | Tradie with `isVerified==false` opens dashboard | Amber "pending verification" banner routing to wizard |
| P1-20 | Currency symbol | Change `GET /api/config/locale` currency | Rate field symbol follows locale (no hardcoded `$`) |

### 3.4 Admin credential queue (`/credentials`)

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-21 | Pending list | `GET /api/admin/credentials/pending` as Staff | Paginated, oldest-first; rows show tradie name/email/trade + 15-min SAS `DownloadUrl` |
| P1-22 | SAS download | Open `DownloadUrl` in new tab; wait 15+ min, retry | File renders/downloads; expired URL fails (not silently public) |
| P1-23 | Approve verifies | Approve a tradie's only pending credential | `ReviewedById`/`ReviewedAt` UTC set; tradie `IsVerified=true` (rule: verified while holding ≥1 approval); banner reports outcome |
| P1-24 | Reject requires reason | Reject with empty reason → then with 500+ char reason → then valid | Empty rejected; over-cap rejected (500 max, mirrors validator); valid sets `RejectReason`, clears on later approve |
| P1-25 | Reject last approval un-verifies | Reject the sole approved credential of a verified tradie | `IsVerified` flips to false; tradie disappears from matching |
| P1-26 | Re-review allowed | Approve then reject (or reverse) the same credential | Status changes; audit fields overwritten; no duplicate rows |
| P1-27 | Web queue UX | Approve/reject from `CredentialQueue.tsx`; reject modal; double-click approve | Row removed from all cached pages, counts resync; row actions disabled in-flight (no double submit); failure surfaces backend `{message}`; empty trade/business shows `—` |
| P1-28 | Only verified matchable | `GET /api/services/search` near an unverified tradie | Unverified tradie never returned (see also P2) |

## 4. P2 — Job request revision [BLOCKER]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P2-01 | Service search happy path | `GET /api/services/search?lat=&lng=&serviceId=` near TRADIE-VERIFIED | Returns verified tradies with their `decimal` rate for that service |
| P2-02 | Search validation | Omit `lat`/`lng`/`serviceId`; pass non-numeric | 400 with field errors |
| P2-03 | Radius enforced (~25km) | Place tradie 30km+ away; search | Excluded (bounding-box + haversine; no raw SQL path) |
| P2-04 | Create job validation | `POST /api/jobs` with `Hours=0`, negative `HourlyRate`, past `ScheduledStartUtc`, missing `ServiceId` | 400 per-field; nothing created |
| P2-05 | Snapshot + total | Create job `HourlyRate=85.50 × Hours=2` → read job | `HourlyRateSnapshot=85.50`, `TotalAmount=171.00` (decimal); later rate changes do NOT mutate the job |
| P2-06 | Reference code | Create 2+ jobs | Each has unique 6–8 char uppercase alphanumeric `ReferenceCode`, persisted |
| P2-07 | JobDto shape | `GET /api/jobs/{id}` + list endpoints | Include `ServiceId`, `ScheduledStartUtc` (UTC), `Hours`, `HourlyRate`, `TotalAmount`, `ReferenceCode` |
| P2-08 | PostJobScreen (mobile) | Post a job in app: service select → rate list from search → hours → scheduled start | Local time converted to UTC on submit; validation mirrors server |
| P2-09 | Job cards | Open homeowner dashboard | Cards show formatted total (`$150.00` / locale symbol) + local `scheduled_start` + hours |
| P2-10 | Geo gap (known) | Enter address string with no lat/lng | Documents as free-text lat/lng (no geocoding endpoint exists — do not file as regression) |

## 5. P3 — Matching: sequential offers & timeouts [BLOCKER]

Setup: job in `Requested`; TRADIE-VERIFIED + TRADIE-2 nearby with schedule fit.
Keep `OfferTimeoutMinutes` small (e.g. 2 min) for timeout tests, restore after.

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P3-01 | Dispatch creates offer | `POST /api/jobs/{id}/match` | `JobOffer` row (top-ranked tradie): `OfferedAtUtc`, `ExpiresAtUtc`, `Response=Pending`, `Stage=Auto`, `HangfireJobId` set; FCM + SignalR event fired; status transition via `IJobStatusService` |
| P3-02 | Ranking | Tradie A (close, high rating, schedule fit) vs Tradie B (far, low rating) | Offer goes to A first |
| P3-03 | Tradie countdown | Open tradie request screen with pending offer | Countdown = `ExpiresAtUtc` localised; `GET /api/jobs/{id}/offers/pending` returns it (204 when none); accept disabled after expiry |
| P3-04 | Accept → AwaitingPayment | `POST /api/jobs/{id}/offers/{offerId}/respond {Accepted}` as offered tradie | Offer `Accepted`, Hangfire timeout cancelled, job → `AwaitingPayment` (NOT a `Matched` status — v1.2 has none), `MatchedTradieId` set, `JobStatusChanged` payload (`JobId/Status/PreviousStatus/ReasonCode/Reason`) reaches homeowner + tradie |
| P3-05 | Double-respond | Accept the same offer twice | Second call 409; single history row |
| P3-06 | Decline → next offer | Offered tradie declines | Offer `Declined`, next ranked tradie offered sequentially (never broadcast in parallel) |
| P3-07 | Timeout → next offer | Let offer expire without responding | Hangfire marks `TimedOut`, next tradie offered automatically |
| P3-08 | Broadened stage | Decline/timeout ALL strict-list tradies | `Stage` flips to `Broadened`; radius expands; offers continue |
| P3-09 | Exhaustion → Cancelled | Decline/timeout ALL broadened offers | Job → `Cancelled` with `no_tradie_found`; homeowner notified |
| P3-10 | One offer per tradie | Inspect `JobOffers` for a job | Unique `(JobId, TradieId)` — no tradie offered twice |
| P3-11 | Homeowner progress UI | Watch homeowner matching screen during P3-06–P3-08 | Sequential progress copy ("Contacting Tradie 1…"), updates live via SignalR |
| P3-12 | Cross-tradie isolation | TRADIE-2 tries to respond to TRADIE-1's offer | 403/404; no state change |

## 6. P4 — Manual payment & admin queue [BLOCKER]

Setup: job in `AwaitingPayment` with known `TotalAmount` + `ReferenceCode`.
`PaymentInstructions.ReferenceFormat` = `FIXO-{JobId}`.

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P6-00 | — | *(numbering reserves P6 for cancellations below)* | — |
| P4-01 | Instructions | `GET /api/jobs/{id}/payment` as owner | Bank `AccountName`/`AccountNumber` (from config, never hardcoded), exact amount, job reference; correct `Status` |
| P4-02 | Instructions RBAC | Same GET as non-owner / other homeowner | 404 (not 403 — no existence leak); homeowner hitting `/admin/payments/*` → 403 |
| P4-03 | Upload happy path | `POST /api/jobs/{id}/payment/upload-receipt` (multipart image) | Job `AwaitingPayment → PaymentReview`; one `Payment` row per job (reused on re-upload); blob in private `fixo-payments`; receipt served by expiring SAS URL, not a public URL |
| P4-04 | Upload gating | Upload against `Booked`/`Expired`/other-owner job | 409 (wrong state) / 404 (not owner) |
| P4-05 | Duplicate receipt — cross-job | Upload the SAME file bytes to a second job | Refused with cross-job reuse copy (`ReceiptHash` unique index) |
| P4-06 | Duplicate receipt — same job | After rejection, re-upload the EXACT rejected file | Refused with already-rejected copy (hash is single-use evidence both ways) |
| P4-07 | Verify → Booked | `POST /api/admin/payments/{id}/verify` as Staff | `Payment=Verified`, job `PaymentReview → Booked`; homeowner push/email; queue row removed |
| P4-08 | Reject → AwaitingPayment | `POST /api/admin/payments/{id}/reject` without reason → with reason | Reason required; valid reject → `Payment=Rejected`, job → `AwaitingPayment`, `RejectReason` set, `ReUploadCount` +1 (on reject, not on re-upload), window restarted, homeowner notified |
| P4-09 | Re-upload after reject | Upload a DIFFERENT file after P4-08 | Same `Payment` row mutated (no second row); `ReUploadCount` stays (assert 1 across re-upload); old blob deleted (no leaked private doc) |
| P4-10 | Expiry without payment | Set `WindowHours: 0`, create job, let Hangfire fire | Job → `Expired`/`Cancelled` with `no_payment`; tradie released; fires exactly once |
| P4-11 | Expiry with unreviewed receipt | Upload receipt, then let window lapse with no admin action | `PaymentReview → Expired` edge (Staff/Superadmin) fires; no stuck "under review" job |
| P4-12 | Reject restarts window | Reject near deadline, let ORIGINAL deadline pass | Job does NOT expire early (job re-reads `Job.PaymentDueAtUtc`, reschedules for remaining time) |
| P4-13 | Mobile payment UI | `/jobs/:jobId/payment` + `/status` in app | Bank details/amount/reference correct; image pick + upload works; rejected state shows reason + re-upload; status screen accurate; job-card tap routes: `AwaitingPayment→payment`, `PaymentReview→status`, else chat |
| P4-14 | Web payment queue | `/payments` in admin: populated + empty states; open `PaymentReviewModal` | Row = job/amount/reference; full-size receipt via SAS; Verify removes row; Reject requires reason text; `ConfirmModal size="lg"` only affects this viewer |

## 7. P5 — Booked → Completed lifecycle [BLOCKER]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P5-01 | Address privacy — pre-Booked | As assigned tradie, `GET /api/jobs/{id}` while `Requested/AwaitingPayment/PaymentReview` | Exact address + homeowner phone masked (city/suburb only) |
| P5-02 | Address reveal — Booked | Same GET after payment verified (`Booked`) | Full address + contact visible to assigned tradie; other tradies still masked; homeowner always sees full |
| P5-03 | Check-in | `POST /api/jobs/{id}/check-in` as assigned tradie | `Booked → InProgress`, `StartedAtUtc` (UTC now); homeowner as caller → 403 |
| P5-04 | Check-out | `POST /api/jobs/{id}/check-out` as assigned tradie | `InProgress → AwaitingConfirmation`, `EndedAtUtc` set; auto-complete Hangfire scheduled (+N hrs, e.g. 48) |
| P5-05 | Confirm | `POST /api/jobs/{id}/confirm` as homeowner | `AwaitingConfirmation → Completed`; scheduled auto-complete becomes no-op/cancelled |
| P5-06 | Confirm RBAC | Confirm as tradie; check-in as homeowner | Both 403; no state change |
| P5-07 | Pre-job reminder | Book a job with `ScheduledStart` ~65 min out | ~1h before: push to BOTH parties; cancel before fire → scheduled task deleted, no push |
| P5-08 | Auto-complete | Check out, wait N hours (or shrink `AutoCompleteWindowHours` for test) | Job → `Completed` automatically if still `AwaitingConfirmation`; completion review prompt pushed to both parties |
| P5-09 | Review model | After `Completed`: create review; inspect record | Default `Status=Visible` (`Visible/Disputed/Removed` enum); review prompt notification sent |
| P5-10 | Tradie execution UI | Tradie job screen at `Booked` (near start) → `InProgress` | "Check In" only when `Booked` (+ near time); "Check Out" only when `InProgress`; API calls update UI; address hidden until `Booked` |
| P5-11 | Homeowner execution UI | Homeowner job screen at `AwaitingConfirmation` → `Completed` | "Confirm Completion" present; "Leave Review" appears when `Completed` + no review; stepper tracks full lifecycle |
| P5-12 | Chat window | Send chat at each status: `Booked/InProgress` vs `Completed/Cancelled` | Active phases accept; `Completed`/`Cancelled` rejected server-side (`ChatHub`/`ChatService`); mobile input disabled with "Chat is closed" banner |

## 8. P6 — Cancellations & refunds [BLOCKER]

### 8.1 Cancellation flows

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P6-01 | Request validation | `POST /api/jobs/{id}/cancel` without `ReasonCode` / with invalid enum | 400; no state change |
| P6-02 | Homeowner cancel — pre-work | Homeowner cancels `Booked` job (no check-in) | Job → `Cancelled`; 10% flat penalty suggested; `Refund` row `Pending` (only when `totalPaid > 0`); tradie notified (`job_cancelled_by_homeowner`) |
| P6-03 | Homeowner cancel — in-work | Homeowner cancels after check-in (`InProgress`) | `SuggestedAmount` = elapsed(`StartedAtUtc`→now) `× HourlyRate`; penalty = hours-worked-amount + 10%; `Refund` `Pending` |
| P6-04 | Tradie cancel | Assigned tradie cancels `Booked` job | Job → `Requested` (NOT `Cancelled`); `TradieProfile.CancellationCount++`; homeowner notified (`job_cancelled_by_tradie`, "being reassigned"); rematch enqueued (`SendOfferJob`); cancelling tradie naturally skipped (no pending offer); payment hold untouched |
| P6-05 | Repeat canceller flag | Tradie cancels N times (hit threshold) | `AccountFlag(RepeatCanceller)` counter increments; `ThresholdHit=true` at threshold (see P7) |
| P6-06 | Mobile cancel UI | Tap cancel icon on homeowner + tradie detail screens | Cancel affordance only on cancellable statuses; shared `CancelJobSheet`: reason radio + optional notes; homeowner sees fee warning (esp. `Booked`/`InProgress` banner); tradie sees account-flag warning; submit → `POST /api/jobs/{id}/cancel`, status syncs |
| P6-07 | Cancel notifications | Each of P6-02/P6-04 | Correct party pushed; refund-Pending homeowner notice is OPTIONAL (absence is not a bug) |

### 8.2 Admin refund queue (`/refunds`)

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P6-08 | Pending list | `GET /api/admin/refunds/pending` | Only `Status==Pending`; row = job title/ID, homeowner, suggested amount, penalty, cancel `ReasonCode`, age |
| P6-09 | Process happy path | `POST /api/admin/refunds/{id}/process` (multipart: `FinalAmount`, `Penalty`, `HoursWorked`, required `TransferReference`, optional proof ≤10MB) | `Refund → Processed`, `ProcessedBy` = admin ID, `ProcessedAtUtc` set; proof in `fixo-credentials`, key on row; homeowner FCM with final amount + reference; row leaves queue |
| P6-10 | Process validation | Submit without `TransferReference`; oversize proof; bad amounts | 400 per-field; refund stays `Pending` |
| P6-11 | Web modal | `ProcessRefundModal`: edit `finalAmount`/`penalty`/`hoursWorked` pre-filled from suggestion; attach proof; submit | Multipart `POST /api/admin/refunds/{id}/process`; success removes row from cache; failure surfaces message |
| P6-12 | Amount precision | Process refund with cents (e.g. `87.55`) | All five decimal columns `decimal(18,2)`; no float drift |

## 9. P7 — Disputes, no-shows, flags [MAJOR]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P7-01 | Open dispute | `POST /api/disputes` (homeowner or tradie) on an active/completed job | `Dispute` row (`OpenedBy`, `OpenedAtUtc`, `Status=Open`); job → `Disputed` |
| P7-02 | Evidence — text | `POST /api/disputes/{id}/evidence {Text}` | `DisputeEvidence(Type=Text)` saved, attributed to submitter |
| P7-03 | Evidence — file | Same endpoint, multipart photo/document | Stored via `BlobStorageService`; `FileKey` saved; retrievable via signed/SAS URL (not public) |
| P7-04 | Mobile dispute UI | "Open Dispute" from job details → reason + details + camera/gallery/text attach | Submits to API; job screen shows dispute status + existing evidence once open |
| P7-05 | No-show — tradie accused | Homeowner `POST /api/jobs/{id}/no-show` (tradie absent) | Flag logged against tradie; homeowner offered **Reassign** (→ `Requested` + rematch) or **Cancel & full refund**; accused tradie notified |
| P7-06 | No-show — homeowner accused | Tradie `POST /api/jobs/{id}/no-show` after grace period | Flag against homeowner; job cancelled with partial refund (homeowner penalty); homeowner notified |
| P7-07 | No-show mobile UI | "Report No-Show" button visibility (before vs after scheduled time + grace) | Hidden early, shown late; homeowner dialog = Reassign vs Cancel&Refund; tradie dialog warns job will be cancelled |
| P7-08 | Admin dispute list | Open Disputes page (default `Open` filter; All/Open/Resolved/Escalated tabs) | All open disputes listed |
| P7-09 | Admin dispute detail | Open one dispute | Shows job context, both parties, chat history, check-in/out time logs, all evidence |
| P7-10 | Resolve — full/partial | Resolve with `FullRefund`/`PartialRefund` + `DecisionNote` | `Dispute → Resolved` (`DecidedBy`, `DecidedAtUtc`, `Outcome`, note); refund generated when applicable |
| P7-11 | Resolve — no refund | Resolve `NoRefund` | `Resolved`, no refund row; parties notified |
| P7-12 | Flag counters | Trigger `RepeatCanceller`/`RepeatNoShow` events repeatedly | `AccountFlag.Counter` increments per type; `ThresholdHit=true` at threshold |
| P7-13 | Flagged-account UI | Admin users view: filter `ThresholdHit==true`; open profile; Warn / Suspend / Resolve | Filter works; history visible; each action persists (`Resolved` + `ResolvedAtUtc` on resolve); suspended user blocked from login/matching |

## 10. P8 — Hardening (mostly NOT IMPLEMENTED — test for absence + partials)

> All P8 checkboxes are `[ ]` in the spec. Do NOT pass P8 as "tested OK"
> without checking implementation status first. The sub-list below tells you
> what to assert today.

| # | Check | Steps | Expected TODAY |
|---|-------|-------|----------------|
| P8-01 | Audit log table | Check for `AuditLogs` table / `AddAuditLogs` migration | ABSENT (pending) — admin verify/refund/suspend leaves no structured audit row; file finding if release requires it |
| P8-02 | Report & block | Look for `UserBlock` entity, block/report endpoints, chat "Report/Block" menu | ABSENT — matching does NOT exclude blocked users; no `Abuse` flag path from chat |
| P8-03 | Signed URLs [PARTIAL] | Open credential / receipt / dispute-evidence / refund-proof URLs | PRESENT pattern: 15-min SAS via `GetReadSasUriAsync`, no public container reads — assert per-doc-type; any public/public-proxy URL is a bug |
| P8-04 | Admin audit integration | Verify credential, process refund, suspend user; inspect logs | NO old/new JSON audit capture (pending) |
| P8-05 | Request expiration worker | Leave job `Requested` 24h+ with no offers | NO automatic `Cancelled` (no `ExpirationWorker`); stale `Requested` jobs persist — known gap |
| P8-06 | Email fallback | Disable push (remove device tokens); trigger refund-processed / cancel / suspension | NO fallback email (pending) — user gets nothing |
| P8-07 | Audit log UI | Admin nav for Audit Logs | ABSENT |
| P8-08 | Metrics dashboard | `GET /api/admin/metrics`; dashboard charts | ABSENT — no activation-rate / match-to-payment / verification-time / response-rate aggregates |

## 11. P9 — Auth & security hardening [BLOCKER for prod]

### 11.1 Implemented — must verify

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P9-01 | No self-assign Staff/Superadmin | `POST /api/auth/register` with `"role": 2` and `"role": 3` | Both 400 (`Role must be Homeowner or Tradie`); only staff-invite (`RequireSuperadminRole`) creates Staff/Superadmin |
| P9-02 | Registration-token binding | Google SSO new user → `RequiresRegistration` response; `PATCH /api/auth/complete-registration?userId=` without/with token | Response includes short-lived (10-min) one-time `registrationToken` (hash stored); missing/expired/replayed token → 400; success consumes token; mobile `RoleSelectScreen` passes token through |
| P9-03 | Login lockout | 5 bad passwords, then correct one; 6th attempt | `lockoutOnFailure: true`; after 5 fails → 429 `{ "message": "Account temporarily locked…" }` for 5 min; seed/demo accounts unaffected |
| P9-04 | JWT secret externalised | Inspect `appsettings.json` + `appsettings.Development.json`; boot API without `Jwt__Secret` | Files contain empty/placeholder secret; real 64-byte (`openssl rand -base64 64`) value via env/user-secrets; missing secret → fail-fast with clear message; Google Client ID also out of committed files; `STARTER_GUIDE.md` documents user-secrets |
| P9-05 | HTTPS metadata by env | Inspect JWT Bearer options; run dev vs prod profile | `RequireHttpsMetadata = !IsDevelopment()` — no manual prod step |
| P9-07 | Android cleartext [PARTIAL] | Inspect `AndroidManifest.xml` + `res/xml/network_security_config.xml` (main + debug) | Main manifest has NO global `usesCleartextTraffic="true"`; main config denies cleartext; debug config allows only `10.0.2.2`/`localhost`; both manifests reference config. Release-build HTTPS assertion is UNVERIFIED — test before prod (`flutter build apk --release` + logcat) |
| P9-09 | Hangfire auth | `GET /hangfire` unauthenticated; as Homeowner/Staff; as Superadmin | Unauth → 401/redirect (never dashboard HTML); Staff denied; Superadmin allowed (filter in ALL environments, not dev-only) |
| P9-13 | JWT algorithm pinning | Inspect `TokenValidationParameters` + `TokenService.CreateToken` | `ValidAlgorithms = [HmacSha256]`, explicit HS256 signing (no string literal drift); comments cover RS256/ES256-via-JWKS migration + `jwk/jku/x5u` non-honouring for current lib version |
| P9-15 | TokenValidation hardening | Inspect parameters | `RequireSignedTokens=true`, `RequireExpirationTime=true`, `ClockSkew=30s` (verify OTP 10-min flow unaffected), `MapInboundClaims=false` |

### 11.2 NOT implemented — confirm still open before prod

| # | Check | Status |
|---|-------|--------|
| P9-06 | Real refresh-token rotation (`RefreshToken` table, 96-byte opaque, rotation-on-use, 30-day expiry, `DELETE /api/auth/refresh` on logout, interceptor 401→snackbar+`handler.reject`) | OPEN — `/refresh` still returns stub tokens; stolen refresh = eternal; mobile silently drops to `/auth` after ~60 min |
| P9-08 | Release-safe logging (`kDebugMode` guards on token/user-data/exception-body `debugPrint`) | OPEN — tokens may hit logcat/syslog in release |
| P9-10 | Web httpOnly cookie auth (`AdminCookie` `__Host-fixo-admin`, `admin-login`/`admin-logout`/`admin-me`, `withCredentials`, CSP header, no `localStorage` JWT, SignalR `withCredentials`, `dangerouslySetInnerHTML` audit) | OPEN — web still uses `localStorage` JWT (XSS-exfiltratable) |
| P9-11 | FCM routing safety comment + explicit `default:` → `/messages` | OPEN |
| P9-12 | Interceptor queued-request reject on refresh failure | OPEN (blocked on P9-06) — queued 401s stall forever |
| P9-14 | Mobile access-token-in-memory, refresh-only in Keystore/Keychain (RFC 8252 §8.5), cold-start refresh in `SplashScreen` | OPEN (blocked on P9-06) |

## 12. Cross-cutting checks (every run)

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| X-01 | SignalR parity | Every status change above, with Flutter + React admin connected | Both clients receive `JobStatusChanged` over the hub (never REST-only side channel); no stale screens |
| X-02 | Push parity | Offer, verify/reject, cancel, refund-processed, reminders, auto-complete, dispute, no-show | FCM reaches backgrounded devices; foreground shows in-app update too |
| X-03 | RBAC matrix | Replay each endpoint as Homeowner-A vs Homeowner-B vs Tradie vs Staff vs Superadmin vs anon | Owner-only stays owner-only (404 for non-owner reads); admin-only stays admin-only (403); anon → 401 |
| X-04 | UTC invariant | Create jobs / OTPs / offers / payments / check-in/out across NZST/NZDT boundary | DB stores UTC; mobile renders local via configured `DefaultTimezone` (no hardcoded Pacific/Auckland in client) |
| X-05 | Decimal invariant | Grep payloads for `150.0000001`-style artefacts; process penny-amount refunds | Exact cents everywhere; display formatting locale-driven |
| X-06 | Reference uniqueness under load | Create 50 jobs rapidly (parallel) | No duplicate `ReferenceCode`; no 500s |
| X-07 | SAS expiry | Capture any SAS URL, use after expiry | Fails closed; no fallback public path |
| X-08 | Double-submit safety | Double-tap Approve / Verify / Process Refund / Accept offer | Second attempt 409 or idempotent no-op; exactly one state change |
| X-09 | Cancel-during-review | Cancel a job while `PaymentReview` pending | Defined outcome (no orphan `Payment` or stuck offer); admin queue consistent |

## 13. Regression pass (15-minute smoke)

1. Register homeowner → verify OTP → login. [P1]
2. Tradie onboarding → upload credential → Staff approves → `IsVerified=true`. [P1]
3. Homeowner posts job (service + rate + hours + future start). [P2]
4. `POST /match` → tradie accepts → `AwaitingPayment`. [P3]
5. Upload receipt → Staff verifies → `Booked`. [P4]
6. Tradie check-in → check-out → homeowner confirm → `Completed` → review. [P5]
7. Second job: homeowner cancels `Booked` → refund `Pending` → Staff processes → homeowner notified. [P6]
8. Attempt `register` with `"role": 2` → 400; 6 bad logins → 429. [P9]

## 14. Bug report template

```md
**ID:** FIXO-QA-###
**Spec ref:** P4-08 (spec file + task, e.g. P4-manual-payment-admin-queue.md P4-05)
**Severity:** BLOCKER / MAJOR / MINOR
**Env:** commit SHA, `docker compose` image tags, device/emulator + OS
**Account(s):** roles used (never paste passwords/tokens)
**Steps:** 1. … 2. … 3. …
**Expected:** (from Acceptance Criteria)
**Actual:** (what happened + status codes + SignalR received? Y/N)
**Evidence:** API response, history row, Hangfire state, screenshots
**Workaround:** (if any)
```

## 15. Sign-off

| Area | Tester | Date (UTC) | Pass/Fail | Notes |
|------|--------|------------|-----------|-------|
| P0 Foundation / roles / state machine | | | | |
| P1 Registration / OTP / onboarding / credential queue | | | | |
| P2 Job request | | | | |
| P3 Matching / offers / timeouts | | | | |
| P4 Payment / admin queue / expiry | | | | |
| P5 Booked → Completed / reminders / chat lock | | | | |
| P6 Cancellations / refunds | | | | |
| P7 Disputes / no-shows / flags | | | | |
| P8 Hardening gaps acknowledged | | | | |
| P9 Security (implemented items verified; open items tracked) | | | | |
| Cross-cutting (SignalR, push, RBAC, UTC, decimal) | | | | |

**Release rule:** all `[BLOCKER]` rows green; no open `[MAJOR]` without a
tracked workaround; P8/P9-open items explicitly accepted as known gaps with
owner + date, not silently skipped.
