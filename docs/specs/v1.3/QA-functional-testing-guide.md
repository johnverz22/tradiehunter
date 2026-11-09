# TradieFixo v1.3 — Functional QA Test Guide

Derived from `docs/specs/v1.2/P0`–`P9` and `docs/specs/v1.3/P10`–`P11`.
Use this as the single consolidated manual pass before any release; automated
smoke scripts (`scripts/p3-smoke.sh`, `scripts/p4-smoke.sh`,
`scripts/web/render-probe.py`, `scripts/e2e-credentials.py`) cover happy
paths but do not replace this list.

The individual checklist files in `qa/` are the printable per-phase versions
of this guide. Use this document for full-run reference and sign-off.

---

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
- **Job lifecycle (v1.3):**
  `Requested → AwaitingPayment → PaymentReview → Booked → InProgress →
  AwaitingConfirmation → Completed`, with side states `Cancelled`, `Expired`,
  `Disputed`.
- **ReasonCodes:** `homeowner_changed_mind`, `tradie_unavailable`,
  `tradie_no_show`, `homeowner_no_show`, `scope_change_declined`,
  `homeowner_issue`, `tradie_issue`, `emergency`, `no_tradie_found`,
  `no_payment`, `system_failure`, `dispute_outcome`.
- **Roles:** `Homeowner`, `Tradie`, `Staff`, `Superadmin`
  (legacy `Admin` no longer exists — any reference is a bug).
- **Brand:** App name is **TradieFixo** on all user-facing surfaces.
  Push notification titles must read "TradieFixo: …". Any residual "Fixo"
  visible to end users is a bug.
- **Commission** is visible to tradies on completed job detail (gross → fee →
  net). Homeowners never see the commission breakdown.

---

## 1. Test environment setup

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| ENV-01 | Stack boots | `docker compose up` (OrbStack); API, postgres+PostGIS, Azurite, redis, Hangfire all healthy | No container crash-loops; Hangfire dashboard reachable |
| ENV-02 | Config present (v1.3 shape) | `GET /api/config/locale`; inspect `PaymentInstructions`, `OfferTimeoutMinutes`, `AutoCompleteWindowHours`, **`commissionPercent`**, **`brand.appName`**, **`brand.supportEmail`**, **`brand.supportHoursDisplay`**, **`locale.legalEntityName`**, **`locale.termsOfServiceUrl`**, **`locale.privacyPolicyUrl`**, **`locale.materialsDisclaimer`** | All keys present, typed; no hardcoded bank details or brand strings in UI |
| ENV-03 | MailHog receives mail + brand | Register a user; check MailHog; check push notification title | OTP email arrives within ~30s; push titles read "TradieFixo: …" |
| ENV-04 | Azurite containers | Upload a credential + a receipt + dispute evidence | `fixo-credentials`, `fixo-payments` containers created lazily; blobs private |
| ENV-05 | Commission config | Read `commissionPercent` from locale endpoint; compare to `PayoutOptions` config | Value consistent; default 12.5 |

### Test accounts (create fresh per run — 8 accounts for v1.3)

- HOMEOWNER-A (verified, with payment-capable job)
- HOMEOWNER-B (unverified — for OTP tests)
- TRADIE-VERIFIED (≥1 approved credential, schedule + rates set, **bank details set**)
- TRADIE-UNVERIFIED (no approved credential)
- TRADIE-2 (second verified tradie, for sequential-offer tests)
- **TRADIE-PAUSED** (verified but `IsAvailable=false` — new in v1.3)
- STAFF (credential/payment/refund/dispute/payout reviewer)
- SUPERADMIN (staff invites, Hangfire dashboard, data retention)

---

## 2. P0 — Foundation, roles, state machine [BLOCKER]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P0-01 | Config binding | Set bogus `PaymentInstructions:WindowHours`, restart API | Typed value picked up; invalid shape fails fast with clear error, not silent default |
| P0-02 | Role gating | As Homeowner/Tradie, call `POST /api/admin/staff/invite`, `GET /api/admin/credentials/pending`, `GET /api/admin/payments/pending`, `GET /api/admin/refunds/pending` | 403 on all; Staff succeeds on queues; only Superadmin on staff-invite |
| P0-03 | Legacy `Admin` role gone | Search API + mobile + web for `Admin` (non-compound) enum/string | No matches; only `Staff`/`Superadmin` |
| P0-04 | AuthProvider + EmailVerified tracked | Register password user vs Google user; inspect user record | Password: `AuthProvider=password`, `EmailVerified=false`; Google: `AuthProvider=google`, `EmailVerified=true` |
| P0-05 | JobStatus enum = 10 values | Create/inspect jobs across lifecycle; check mobile `job.dart` + web `job.ts` | Exactly `Requested, AwaitingPayment, PaymentReview, Booked, InProgress, AwaitingConfirmation, Completed, Cancelled, Expired, Disputed` — no `Draft/Matching/Matched/Confirmed/Complete` |
| P0-06 | History enrichment | Perform any transition; read `JobStatusHistory` | Row has `FromStatus`, `ToStatus`, `ActorRole`, `ReasonCode` (nullable), `CancelledBy` (nullable), UTC timestamp |
| P0-07 | Invalid transition rejected | `POST /api/jobs/{id}/confirm` on `Requested`; `POST check-in` as homeowner | 4xx with guard message; no state change, no history row |
| P0-08 | Legacy status migration | Inspect migration for old statuses | `Matching,Matched→Requested`; `Confirmed→Booked`; `Complete→Completed`; required fields backfilled |
| P0-09 | Mobile stepper | Walk job Requested → Completed; open Disputed + Cancelled | Stepper advances linearly; Disputed/Cancelled render alert/failure visual |
| P0-10 | Web StatusBadge | Open admin job list with one job per status | All 10 statuses render with distinct label/colour |

---

## 3. P1 — Registration, OTP, tradie verification [BLOCKER]

### 3.1 Registration & OTP

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-01 | Register sends OTP | `POST /api/auth/register` (Homeowner) | `EmailVerified=false`, no JWT, `email_otps` row (hash, 10-min expiry), email delivered |
| P1-02 | Verify happy path | `POST /api/auth/verify-email` with correct 6-digit code | `EmailVerified=true`, `EmailVerifiedAt` UTC set, JWT returned |
| P1-03 | Wrong-code cap (5) | Submit 5 wrong codes, then correct | Correct code rejected after 5 tries; resend required |
| P1-04 | Expired OTP | Wait >10 min; submit correct code | Rejected as expired; resend required |
| P1-05 | Resend cooldown + voiding | `POST /api/auth/resend-otp` twice within 60s | Second rejected; old OTPs voided when new issued |
| P1-06 | Login gating unverified | Login with HOMEOWNER-B | No full JWT; 403 + `requiresVerification`; mobile routes to `/verify-email` |
| P1-07 | OTP screen (mobile) | Register in-app | 6-box input + 60s countdown; success leaves OTP screen |
| P1-08 | Google new account | Google SSO with new email | `EmailVerified=true`, JWT, routed to role-select |
| P1-09 | Google link — verified | Google SSO matching verified password account | Linked, login succeeds |
| P1-10 | Google link — unverified | Google SSO matching unverified password account | Linking blocked; mobile routes to OTP screen |

### 3.2 Staff invites

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-11 | Invite (Superadmin) | `POST /api/admin/staff/invite` | Unverified staff user created; set-password email sent |
| P1-12 | Invite RBAC | Same as Staff/Homeowner/Tradie/anon | 403/401; nothing created |
| P1-13 | Set password | `POST /api/admin/staff/set-password` with token; replay | First → password set, active; replay → 400 |

### 3.3 Tradie onboarding

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-14 | Step 1 profile | Save name/phone/address/trade/radius | `PUT /api/profile` provisions `TradieProfile`; per-step validation |
| P1-15 | Step 2 rates | Pick catalog services, set hourly rates | Decimal end-to-end; 0–10000 range enforced |
| P1-16 | Step 3 schedule | Set weekday rows + quick-fill | DayOfWeek 0–6 correct |
| P1-17 | Step 4 credentials | Upload jpg/jpeg/png/pdf ≤10MB | Private blob; `FileKey` returned; oversize rejected |
| P1-18 | Pre-profile 403 = empty | Fresh tradie; open wizard | 403 treated as "nothing set yet", not error |
| P1-19 | Pending banner | TRADIE-UNVERIFIED dashboard | Amber banner routing to wizard |
| P1-20 | Currency symbol | Change locale currency | Rate field symbol follows locale (no hardcoded `$`) |

### 3.4 Admin credential queue

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P1-21 | Pending list shape | `GET /api/admin/credentials/pending` as Staff | Paginated, oldest-first; 15-min SAS `DownloadUrl` |
| P1-22 | SAS download + expiry | Open URL; retry after 15+ min | Renders first; expired URL fails |
| P1-23 | Approve verifies | Approve only pending credential | `IsVerified=true`; rule: ≥1 approval |
| P1-24 | Reject requires reason | Empty → 500+ chars → valid | Each case handled correctly |
| P1-25 | Last rejection un-verifies | Reject sole approval | `IsVerified=false`; excluded from search |
| P1-26 | Re-review | Approve then reject same credential | Status flips; no duplicate rows |
| P1-27 | Web queue UX | Approve/reject from UI; double-click | Row removed from cache; double-submit blocked |
| P1-28 | Only verified matchable | `GET /api/services/search` near TRADIE-UNVERIFIED | Never returned |

---

## 4. P2 — Job request revision [BLOCKER]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P2-01 | Service search happy path | `GET /api/services/search?lat=&lng=&serviceId=` | Verified tradies with `decimal` rate |
| P2-02 | Search validation | Omit required params; non-numeric | 400 with field errors |
| P2-03 | Radius enforced | Place tradie 30km+ away | Excluded |
| P2-04 | Create-job validation | Zero hours, negative rate, past start, no service | 400 per-field |
| P2-05 | Rate snapshot + total | `HourlyRate=85.50 × Hours=2`; change tradie rate | `HourlyRateSnapshot=85.50`, `TotalAmount=171.00`; immutable |
| P2-06 | Reference code unique | Create 2+ jobs | Unique 6–8 char uppercase alphanumeric |
| P2-07 | JobDto shape | `GET /api/jobs/{id}` | Includes `ServiceId`, `ScheduledStartUtc`, `Hours`, `HourlyRate`, `TotalAmount`, `ReferenceCode` |
| P2-08 | PostJobScreen (mobile) | Post a job in-app | Local time → UTC; validation mirrors server |
| P2-09 | Job cards | Homeowner dashboard | Formatted total + local start + hours |
| P2-10 | Parallel-create | ~50 jobs rapidly | No duplicate `ReferenceCode`; no 500s |

---

## 5. P3 — Matching: sequential offers & timeouts [BLOCKER]

Setup: job in `Requested`; TRADIE-VERIFIED + TRADIE-2 nearby (both `IsAvailable=true`).
Keep `OfferTimeoutMinutes` small (e.g. 2 min) for timeout tests, restore after.

> **v1.3 note:** Matching also filters out `IsAvailable=false` tradies and requires
> approved licence credentials for regulated services. Core P3 cases below; see §14 for
> those filters.

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P3-01 | Dispatch creates offer | `POST /api/jobs/{id}/match` | `JobOffer` row; `Response=Pending`, `Stage=Auto`, `HangfireJobId` set; FCM + SignalR |
| P3-02 | Ranking | Tradie A (close, high rating) vs B (far, low) | A offered first |
| P3-03 | Tradie countdown | Open tradie request screen | Countdown = `ExpiresAtUtc` local; 204 for non-offered tradie |
| P3-04 | Accept → AwaitingPayment | `respond {Accepted}` as offered tradie | `MatchedTradieId` set; `JobStatusChanged` to both |
| P3-05 | Double-respond | Accept same offer again | 409; single history row |
| P3-06 | Decline → next offer | Offered tradie declines | Next ranked tradie offered (never parallel) |
| P3-07 | Timeout → next offer | Let offer expire | Hangfire marks `TimedOut`; next offered |
| P3-08 | Broadened stage | Exhaust strict list | `Stage=Broadened`; radius expands |
| P3-09 | Exhaustion | Exhaust broadened list | Job → `Cancelled`, `no_tradie_found` |
| P3-10 | One offer per tradie | Inspect `JobOffers` | Unique `(JobId, TradieId)` |
| P3-11 | Homeowner progress UI | Watch matching screen during P3-06–08 | Sequential copy; live via SignalR |
| P3-12 | Cross-tradie isolation | TRADIE-2 responds to TRADIE-1's offer | 403/404; no state change |

---

## 6. P4 — Manual payment & admin queue [BLOCKER]

Setup: job in `AwaitingPayment`. `ReferenceFormat = FIXO-{JobId}`.

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P4-01 | Instructions | `GET /api/jobs/{id}/payment` as owner | Bank from config (never hardcoded); correct amount/reference/status |
| P4-02 | Instructions RBAC | Non-owner GET; homeowner on admin queue | 404 / 403 |
| P4-03 | Upload → PaymentReview | `POST upload-receipt` (multipart) | Job `→ PaymentReview`; one `Payment` row; private blob; SAS URL |
| P4-04 | Upload gating | Wrong state; other owner | 409 / 404 |
| P4-05 | Duplicate across jobs | Same bytes on job B | Refused (`ReceiptHash` unique) |
| P4-06 | Re-upload rejected file | Re-upload exact rejected file | Refused (single-use hash) |
| P4-07 | Verify → Booked | `POST /admin/payments/{id}/verify` | `Payment=Verified`; job `→ Booked`; homeowner notified; row removed |
| P4-08 | Reject → AwaitingPayment | No reason → with reason | Reason required; `ReUploadCount` +1 on reject (not on re-upload); window restarted |
| P4-09 | Re-upload mutates row | Upload different file | Same row; old blob deleted |
| P4-10 | Expiry without payment | `WindowHours: 0`; no upload | Job `→ Expired/Cancelled`, `no_payment`; fires once |
| P4-11 | Expiry with unreviewed | Upload, no admin action; lapse | `PaymentReview → Expired` edge |
| P4-12 | Reject restarts window | Reject near deadline; original deadline passes | No early expiry |
| P4-13 | Mobile payment UI | All states in-app | Correct routing per status |
| P4-14 | Web payment queue | `/payments`; `PaymentReviewModal` | Full-size SAS receipt; Verify removes; Reject requires reason |

---

## 7. P5 — Booked → Completed lifecycle [BLOCKER]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P5-01 | Address masked pre-Booked | `GET /api/jobs/{id}` as assigned tradie pre-Booked | City/suburb only; phone masked |
| P5-02 | Address revealed Booked | Same GET post-Booked | Full address to assigned tradie; others still masked |
| P5-03 | Check-in → InProgress | `POST check-in` as tradie; try as homeowner | Tradie: `→ InProgress`, `StartedAtUtc`; homeowner: 403 |
| P5-04 | Check-out → AwaitingConfirmation | `POST check-out` | `EndedAtUtc`; auto-complete Hangfire scheduled |
| P5-05 | Confirm → Completed | `POST confirm` as homeowner | `→ Completed`; auto-complete no-op |
| P5-06 | RBAC | Confirm as tradie; check-in as homeowner | Both 403 |
| P5-07 | Pre-job reminder | Job `Booked` ~65 min out | Push to BOTH parties; cancelled job gets no push |
| P5-08 | Auto-complete | Check out, wait N hours | `→ Completed` automatically; review prompt pushed |
| P5-09 | Payout created on completion | Inspect `tradie_payouts` after completion | `Status=Pending`; commission/net correct; bank details copied |
| P5-10 | Tradie execution UI | Tradie screen `Booked→InProgress` | Check In/Out buttons gated correctly; address hidden until Booked |
| P5-11 | Homeowner execution UI | Homeowner screen `AwaitingConfirmation→Completed` | Confirm Completion + Leave Review appear at right states |
| P5-12 | Chat locked | Send at active vs terminal statuses | Active: accepted; `Completed`/`Cancelled`: rejected server-side; mobile input disabled |

---

## 8. P6 — Cancellations & refunds [BLOCKER]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P6-01 | Validation | Cancel without/invalid `ReasonCode` | 400 both times |
| P6-02 | Homeowner cancel pre-work | Homeowner cancels `Booked` | 10% flat penalty; `Refund Pending`; tradie notified |
| P6-03 | Homeowner cancel in-work | Homeowner cancels `InProgress` | `SuggestedAmount` = elapsed × rate; penalty = hours-amount + 10% |
| P6-04 | Tradie cancel | Assigned tradie cancels | Job `→ Requested`; `CancellationCount++`; rematch; payment held |
| P6-05 | Repeat-canceller flag | Cancel N times | `AccountFlag(RepeatCanceller)`; `ThresholdHit=true` |
| P6-06 | Mobile cancel UI | Cancel icon on both roles | Reason sheet; fee/flag warning per role |
| P6-07 | Notifications | P6-02 and P6-04 | Correct party notified |
| P6-08 | Refund queue shape | `GET /admin/refunds/pending` | Only `Pending`; correct fields |
| P6-09 | Process refund | `POST /admin/refunds/{id}/process` (multipart) | `→ Processed`; homeowner FCM; row leaves queue |
| P6-10 | Process validation | Missing `TransferReference`; oversize proof | 400 per case |
| P6-11 | Web refund modal | `ProcessRefundModal` | Pre-filled; multipart POST; success clears cache |
| P6-12 | Penny precision | Process with cents (e.g. `87.55`) | `decimal(18,2)`; no float drift |

---

## 9. P7 — Disputes, no-shows, flags [MAJOR]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P7-01 | Open dispute | `POST /api/disputes` | `Dispute` row; job `→ Disputed` |
| P7-02 | Text evidence | `POST /api/disputes/{id}/evidence {Text}` | `DisputeEvidence(Type=Text)` attributed to submitter |
| P7-03 | File evidence | Same endpoint, multipart | Private blob; `FileKey`; SAS URL |
| P7-04 | Mobile dispute UI | "Open Dispute" from job details | Submits to API; shows status + evidence |
| P7-05 | No-show — tradie accused | Homeowner `POST no-show` | Flag against tradie; homeowner offered Reassign or Cancel+refund |
| P7-06 | No-show — homeowner accused | Tradie `POST no-show` after grace | Flag against homeowner; job cancelled with penalty |
| P7-07 | No-show mobile UI | Button visibility (time-gated) | Hidden early; homeowner/tradie correct dialogs |
| P7-08 | Admin dispute list | Disputes page | All open disputes; All/Open/Resolved/Escalated tabs |
| P7-09 | Admin dispute detail | Open one dispute | Job context, parties, chat, timelogs, all evidence |
| P7-10 | Resolve full/partial | `FullRefund`/`PartialRefund` + note | `→ Resolved`; refund generated |
| P7-11 | Resolve no refund | `NoRefund` | `→ Resolved`; no refund; parties notified |
| P7-12 | Flag counters | Trigger events | `Counter` increments; `ThresholdHit=true` |
| P7-13 | Flagged-account actions | Filter + Warn/Suspend/Resolve | Each action persists; suspended user blocked |

---

## 10. P8 — Hardening [BLOCKER for partial P8-03; MAJOR for gaps]

> v1.3 resolved: P8-01 (audit log table), P8-04 (admin audit integration),
> P8-07 (audit log UI), P8-08 (metrics dashboard). Assert these are present.
> P8-02, P8-05, P8-06 remain known gaps — accept explicitly, never silently skip.

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P8-01 | Audit log table (resolved) | Check `AuditLogs` table; do an admin action | Present; structured rows written |
| P8-02 | Report & block (ABSENT, gap) | Look for `UserBlock` entity | Absent — accepted known gap |
| P8-03 | Signed URLs (PRESENT) | Open credential/receipt/dispute/refund-proof URLs | 15-min SAS; no anonymous reads; any public URL is a bug |
| P8-04 | Admin audit (resolved) | Verify/refund/suspend; inspect DB | Old/new JSON captured |
| P8-05 | Expiration worker (ABSENT, gap) | Leave `Requested` job 24h+ | No auto-cancel — accepted known gap |
| P8-06 | Email fallback (ABSENT, gap) | Remove device tokens; trigger notifications | No fallback — accepted known gap |
| P8-07 | Audit log UI (resolved) | Admin nav `/audit-logs` | Present |
| P8-08 | Metrics dashboard (resolved) | `GET /admin/metrics`; dashboard charts | Activation-rate etc. present |

---

## 11. P9 — Auth & security hardening [BLOCKER for prod]

### 11.1 Implemented — must verify

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P9-01 | No self-assign Staff/Superadmin | `POST /api/auth/register` `"role": 2` and `"role": 3` | Both 400; only staff-invite creates those roles |
| P9-02 | Registration-token binding | Google SSO → `RequiresRegistration`; replay token | 10-min one-time token; missing/expired/replayed → 400 |
| P9-03 | Login lockout | 5 bad passwords then correct; 6th attempt | 429 after 5 fails; 5-min lock |
| P9-04 | JWT secret externalised | Inspect appsettings; boot without secret | Files empty/placeholder; real value via env/user-secrets; missing → fail-fast |
| P9-05 | HTTPS metadata by env | Inspect JWT Bearer options | `RequireHttpsMetadata = !IsDevelopment()` |
| P9-07 | Android cleartext [partial] | Inspect manifests + network_security_config | Main manifest: no global cleartext; debug: only 10.0.2.2/localhost |
| P9-09 | Hangfire auth | `GET /hangfire` as anon/Staff/Superadmin | 401 for anon/Staff; Superadmin allowed in ALL envs |
| P9-10 | Web httpOnly cookie (resolved) | Admin login flow; inspect cookies | `__Host-fixo-admin` httpOnly cookie; no localStorage JWT; `withCredentials` on all admin calls |
| P9-13 | JWT algorithm pinned | Inspect `TokenValidationParameters` | `ValidAlgorithms = [HmacSha256]`, explicit HS256 |
| P9-15 | TokenValidation hardening | Inspect parameters | `RequireSignedTokens=true`, `RequireExpirationTime=true`, `ClockSkew=30s`, `MapInboundClaims=false` |

### 11.2 Open — confirm still open (do NOT mark pass)

| # | Status |
|---|--------|
| P9-06 | Real refresh-token rotation — OPEN |
| P9-08 | Release-safe logging — OPEN |
| P9-11 | FCM routing safety comment — OPEN |
| P9-12 | Interceptor queue reject — OPEN (blocked on P9-06) |
| P9-14 | Token-in-memory pattern — OPEN (blocked on P9-06) |
| P9-REL | Release-build security sweep — do before prod |

---

## 12. Cross-cutting checks (every run)

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| X-01 | SignalR parity | Every status change with Flutter + React connected | Both clients receive `JobStatusChanged` |
| X-02 | Push parity | Offer/verify/cancel/refund/reminders/complete/dispute/no-show | FCM to background; in-app for foreground; "TradieFixo: …" title |
| X-03 | RBAC matrix | Each endpoint as each role | Owner-only: 404; admin-only: 403; anon: 401 |
| X-04 | UTC invariant | Create across NZST/NZDT boundary | DB UTC; client localised |
| X-05 | Decimal invariant | Grep payloads for float artefacts; penny refunds + penny payouts | Exact cents everywhere |
| X-06 | SAS expiry | Capture any SAS URL; reuse after expiry | Fails closed |
| X-07 | Double-submit | Double-tap Approve / Verify / Process Refund / Accept / Process Payout | 409 or idempotent; one state change |
| X-08 | Cancel-during-review | Cancel a `PaymentReview` job | No orphan `Payment`; queue consistent |
| X-09 | Brand consistency | Splash, app bar, onboarding, push titles, admin sidebar, tab title, login page | "TradieFixo" consistently; no user-visible "Fixo" |

---

## 13. Regression pass (15-minute smoke)

1. Register homeowner → verify OTP → login. [P1]
2. Tradie onboarding → upload credential → Staff approves → `IsVerified=true`. [P1]
3. Homeowner posts job (service + rate + hours + future start). [P2]
4. `POST /match` → tradie accepts → `AwaitingPayment`. [P3]
5. Upload receipt → Staff verifies → `Booked`. [P4]
6. Tradie check-in → check-out → homeowner confirm → `Completed` → review. [P5]
   Verify `TradiePayout(Status=Pending)` row created. [P10-04]
7. Second job: homeowner cancels `Booked` → refund `Pending` → Staff processes → homeowner notified. [P6]
8. Attempt `register` with `"role": 2` → 400; 6 bad logins → 429. [P9]
9. Green-board check: `docker compose ps` clean; no error spam in api logs; Hangfire dashboard shows succeeded jobs.

---

## 14. P10 — Business rules, payouts & rebrand [v1.3 NEW]

### 14.1 Commission & Payout data model

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-01 | Payout on completion | Complete a job; inspect `tradie_payouts` | `Status=Pending`; `CommissionAmount = Total × rate / 100`; `NetAmount = Gross − Commission`; `decimal(18,2)` |
| P10-02 | No bank details | Complete job for tradie without bank | Payout `Pending`; warning logged; `hasBankDetails=false`; excluded from batch |
| P10-03 | CommissionPercent in locale | `GET /api/config/locale` | `commissionPercent` field present |

### 14.2 Payout admin queue

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-04 | Queue shape | `GET /api/admin/payouts/pending` | Tradie name, job ref, gross, commission, net, bank last-4, status, age |
| P10-05 | Process payout | `POST /admin/payouts/{id}/process {transferReference}` | `→ Processed`; tradie FCM with net + reference; row leaves queue |
| P10-06 | Process requires reference | POST without `transferReference` | 400; payout stays Pending |
| P10-07 | Web payout queue (`/payouts`) | Open queue; process row; empty state; sidebar "Payouts" | Table + modal correct; processed row cleared via cache |

### 14.3 Payout batches

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-08 | Weekly batch | Trigger `PayoutBatchJob` | `PayoutBatch` row `Open`; pending payouts → `Scheduled` + `PayoutBatchId`; no batch if no payouts |
| P10-09 | Batch detail + complete | GET batch; process all; POST complete | "Mark Batch Complete" blocked while unprocessed > 0; on complete: `Completed` |
| P10-10 | Web batch pages (`/payouts/batches`) | List + detail | Period / count / total / status; individual payouts in detail |

### 14.4 Service catalog & matching filters

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-11 | Catalogue seeded | Inspect `services` table | Plumbing/elec/building: `RequiresLicence=true`, correct `LicenceBoard`; others: false |
| P10-12 | Licence filter | Match job for regulated service; tradie without vs with approved licence | Without: excluded; with: offered |
| P10-13 | IsAvailable=false excluded | Match with TRADIE-PAUSED in range | TRADIE-PAUSED never offered |

### 14.5 Insurance badge

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-14 | Insurance → badge | Approve Insurance credential; read profile + search | `hasInsurance=true`; "Insured" badge on tradie card; revoke → `false` |

### 14.6 Tradie availability toggle

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-15 | Toggle endpoint | `POST /api/profile/availability { "available": false }` | `isAvailable=false`; excluded from matching; `GET /api/profile` reflects it |
| P10-16 | Mobile toggle UI | Toggle switch off on tradie dashboard | Amber "paused" banner; active jobs unaffected; toggle on removes banner |

### 14.7 Blind reviews

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-17 | First review hidden | One review submitted; `GET /api/jobs/{id}/reviews` | `isRevealed=false`; stars/comment redacted; `RevealAfterUtc = CompletedAt + 7d` |
| P10-18 | Both reviews reveal | Second review submitted | Both `isRevealed=true` immediately |
| P10-19 | 7-day reveal | One review; trigger `RevealReviewsJob` | Review flips; push to both |
| P10-20 | Disputed job blocks reveal | Review on disputed job; 7 days pass | Remains hidden until dispute resolved |
| P10-21 | Mobile blind review UX | Submit review in-app | Confirmation copy; placeholder while waiting; stars/comment when revealed |
| P10-22 | Tradie reviews homeowner | "Rate Homeowner" after `Completed` | `POST /api/reviews` `fromUser=tradieId`; blind window applies |

### 14.8 Low-rating flag

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-23 | Auto-flag | User reaches avg < 3.0 with ≥3 reviews | `AccountFlag(LowRating)` created; no auto-suspension |

### 14.9 Job editing lockout

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-24 | Edit locked (offer exists) | `PUT /api/jobs/{id}` when `JobOffer` exists | 409; `"Job cannot be edited after matching has started. Cancel and repost to change details."` |
| P10-25 | Edit locked (non-Draft) | `PUT /api/jobs/{id}` in `AwaitingPayment`+ | 409 |
| P10-26 | Mobile edit button hidden | Job detail in `Requested`+ | Edit button not visible; 409 handled gracefully |

### 14.10 Photo limits

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-27 | Max 5 photos | 6 photos in create-job request | 400 |
| P10-28 | 10MB per photo | Photo >10,485,760 bytes | 400; no partial upload |
| P10-29 | Mobile photo picker | Select 6 / oversized photo | Capped at 5; error for oversized; "X/5 photos added" counter |

### 14.11 Brand & rebrand

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-30 | TradieFixo everywhere | Mobile splash/onboarding/app-bar/settings; admin sidebar/tab/login; push titles; locale endpoint | "TradieFixo" consistent; no user-visible "Fixo" |

### 14.12 Payment queue SLA indicators

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P10-31 | Waiting column | `/payments` with items of varying ages | Amber >15 min; red + URGENT >30 min; oldest first |
| P10-32 | SLA push notification | Payment in `PaymentReview` >30 min | Push to all staff with job reference + wait time |

---

## 15. P11 — Compliance & data lifecycle [v1.3 NEW]

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| P11-01 | RetentionPolicy config | Inspect `appsettings.json` | All keys present with correct defaults |
| P11-02 | Retention options bound | Type mismatch; restart | Fail-fast; no silent default |
| P11-03 | Chat purge | Trigger on completed job >24 months; check dispute guard | Chat rows deleted; disputed jobs skipped; financial data untouched |
| P11-04 | Photo purge | Trigger on completed job >24 months | Blob deleted; `photos` field cleared |
| P11-05 | Device token purge | Token with `LastSeen` >90 days | Old token deleted; recent untouched |
| P11-06 | Account anonymization | Inactive user >24 months, no active jobs | Name → "Deleted User"; email → hash; phone/address → null; row preserved; reviews intact |
| P11-07 | Financial records never purged | Run purge on old financial rows | `payments`, `refunds`, `tradie_payouts`, `payout_batches` all survive |
| P11-08 | Purge audit log | After purge run | Structured audit entry per category; superadmin notified |
| P11-09 | Legal fields in locale endpoint | `GET /api/config/locale` | `legalEntityName`, `legalEntityCountry`, `termsOfServiceUrl`, `privacyPolicyUrl` present |
| P11-10 | Mobile Terms & Privacy links | Registration screen + Settings → Legal | Links present; open in-app browser; sourced from config |
| P11-11 | Data Retention page (Superadmin) | `/admin/data-retention` as Superadmin; as Staff | Superadmin: policy values + last purge + Run Purge Now + warning; Staff: 403 |

---

## 16. Bug report template

```md
ID: TRADIEFIXO-QA-###
Spec ref: (file + task, e.g. P10-business-rules-payouts-rebrand.md P10-11)
Case: (e.g. P10-17)
Severity: BLOCKER / MAJOR / MINOR
Env: commit SHA, image tags, device/emulator + OS
Accounts: roles used (never paste passwords/tokens)
Steps: 1. … 2. … 3. …
Expected: (from Acceptance Criteria)
Actual: (what happened + status codes + SignalR received? Y/N)
Evidence: API response, history row, Hangfire state, screenshots
Workaround: (if any)
```

---

## 17. Sign-off

| Area | Tester | Date (UTC) | Pass/Fail | Notes |
|------|--------|------------|-----------|-------|
| P0 Foundation / roles / state machine | | | | |
| P1 Registration / OTP / onboarding / credential queue | | | | |
| P2 Job request | | | | |
| P3 Matching / offers / timeouts | | | | |
| P4 Payment / admin queue / expiry | | | | |
| P5 Booked → Completed / reminders / payout created | | | | |
| P6 Cancellations / refunds | | | | |
| P7 Disputes / no-shows / flags | | | | |
| P8 Hardening gaps acknowledged | | | | |
| P9 Security (implemented verified; open tracked) | | | | |
| Cross-cutting (SignalR, push, RBAC, UTC, decimal, brand) | | | | |
| P10 Payouts / matching rules / blind reviews / rebrand / SLA | | | | |
| P11 Data retention / purge / legal config | | | | |

**Release rule:** all `[BLOCKER]` rows green; no open `[MAJOR]` without a
tracked workaround; P8/P9-open items explicitly accepted as known gaps with
owner + date, not silently skipped.
