# TradieHunter — Functional QA Test Guide (role & feature organised)

Cumulative coverage: v1.1–v1.6 feature set as implemented in the current
codebase. Companion to `docs/specs/v1.3/QA-functional-testing-guide.md`,
which is organised by spec phase (P0–P11); **this guide is organised by
actor and feature**, and adds a dedicated two-device parallel-use-case
section (§6) for real-time homeowner↔tradie↔admin scenarios.

Use this document for full manual passes before release. Automated
harnesses (`scripts/e2e-credentials.py`, `scripts/web/render-probe.py`,
address-resolution fixtures) cover happy paths only — they do not replace
this list.

---

## 0. Conventions

- **Severity:** `[BLOCKER]` cannot ship, `[MAJOR]` feature broken,
  `[MINOR]` cosmetic/edge.
- **Money:** always `decimal`, exact 2-dp (`$150.00`). Any float artefact
  (`150.0001`, `149.9999`) is a bug.
- **Time:** UTC on the wire/DB, localised on the client. Check both.
- **Roles:** `Homeowner`, `Tradie`, `Staff`, `Superadmin` — no `Admin`.
- **Brand:** user-facing surfaces read **TradieHunter** ("Hunter" in amber
  `#E38B29` in the wordmark). Internal identifiers (`fixo` package,
  `FixoApi` namespace, `nz.co.fixo.fixo`) intentionally keep the old name —
  those are not bugs.
- **Job lifecycle:**
  `Requested → AwaitingPayment → PaymentReview → Booked → InProgress →
  AwaitingConfirmation → Completed`, plus side states `Cancelled`,
  `Expired`, `Disputed`.
- **State-change triple (assert on EVERY transition):** SignalR
  `JobStatusChanged` received by connected clients + `JobStatusHistory`
  row with `ActorRole`/`ReasonCode` + correct new status. If any leg is
  missing, file a bug even when the UI looks right.
- **Commission** is visible to tradies only (gross → fee → net on
  completed job detail / earnings). Homeowners must never see it.
- **Homeowner UI presents 4 stages** (Requested / Booked / In progress /
  Done) mapped from the 10 server states — a presentational mapping, not
  a different state machine (v1.5 UX-02).
- **Address privacy:** assigned tradie sees suburb/city only until the job
  reaches `Booked`; full address + phone revealed at `Booked`. Any leak
  earlier is a `[BLOCKER]`.

---

## 1. Environment & test accounts

| # | Check | Steps | Expected |
|---|-------|-------|----------|
| ENV-01 | Stack boots | `docker compose up` (OrbStack) | API, postgres+PostGIS, Azurite, Redis, Hangfire healthy; `/hangfire` reachable |
| ENV-02 | Locale config | `GET /api/config/locale` | `appName`/`brand` = TradieHunter; `commissionPercent`; `paymentInstructions`; `offerTimeoutMinutes`; `autoCompleteWindowHours`; legal URLs; `materialsDisclaimer` — all present |
| ENV-03 | Email delivery | Register a user; open MailHog | OTP email < ~30 s; TradieHunter subject |
| ENV-04 | Blob containers | Upload credential + receipt + dispute evidence | `fixo-credentials` / `fixo-payments` containers created; all blobs private (SAS only) |
| ENV-05 | Address resolver | `GET /api/addresses/search?query=...` | Ranked suggestions with coordinates; rate limit (`address-search` policy) engages on rapid calls |
| ENV-06 | Two devices ready | Flutter app on two devices/emulators (or one device + one emulator) logged in as different roles | Both connect to same API; SignalR connected on both |

### Test accounts (create fresh per run — 8 accounts)

- **HOMEOWNER-A** — verified, used for job posting/payment
- **HOMEOWNER-B** — unverified, for OTP gating tests
- **TRADIE-VERIFIED** — ≥1 approved credential, schedule + rates + **bank details** set
- **TRADIE-UNVERIFIED** — registered, no approved credential
- **TRADIE-2** — second verified tradie (sequential-offer tests)
- **TRADIE-PAUSED** — verified, `isAvailable=false`
- **STAFF** — reviews credentials/payments/refunds/disputes/payouts
- **SUPERADMIN** — staff invites, Hangfire, settings

### Device pairing used throughout

| Label | Meaning |
|-------|---------|
| **HO device** | Flutter app as HOMEOWNER-A |
| **TR device** | Flutter app as TRADIE-VERIFIED |
| **ADMIN tab** | Admin web (`/dashboard`) as STAFF |

---

## 2. Section A — Shared / auth features

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| A-01 | B | Register → OTP | `POST /api/auth/register` (homeowner) | `EmailVerified=false`; no JWT; hashed OTP row (10-min expiry); email arrives |
| A-02 | B | Verify happy path | Correct 6-digit code | `EmailVerified=true`; JWT issued; app routes to role/home |
| A-03 | B | OTP wrong-code cap | 5 wrong codes, then correct | Correct code also rejected after 5 attempts; resend required |
| A-04 | B | OTP expiry | Wait >10 min, submit | Rejected as expired |
| A-05 | B | Resend cooldown | Resend twice <60 s | Second rejected; old codes voided |
| A-06 | B | Login gating | Login as HOMEOWNER-B | No full JWT; mobile routed to `/verify-email` |
| A-07 | B | Role self-assign | Register with `"role": 2` or `3` | 400 — staff roles only via invite |
| A-08 | B | Login lockout | 5 bad passwords, then 6th | 429 after 5; ~5-min lock |
| A-09 | B | Google SSO new user | SSO with unused email | `EmailVerified=true`; routed to role-select |
| A-10 | B | Google link — unverified acct | SSO matching unverified password email | Link blocked; routed to OTP |
| A-11 | M | OTP screen UX | Register in-app | 6-box field, 60s resend countdown, error copy specific |
| A-12 | M | Signup scroll/clip | Small device (320px), keyboard open, text scale 2.0 | No clipped fields/CTA (v1.6 fix) |
| A-13 | M | Terms & Privacy links | Signup + Settings → Legal | Links from config open in-app browser |
| A-14 | M | Theme parity | Toggle light/dark on any 3 screens | Both themes render correctly; no hardcoded colours |
| A-15 | M | Logout/session | Logout → reopen app → force-close → reopen | Login required after logout; valid session survives restart |

### Staff invite (Superadmin only)

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| A-16 | B | Invite | `POST /api/admin/staff/invite` as Superadmin | Unverified staff user created; set-password email sent |
| A-17 | B | Invite RBAC | Same call as Staff/Homeowner/Tradie/anon | 403/401; nothing created |
| A-18 | B | Set password + replay | Use token; reuse token | First succeeds; replay → 400 |

---

## 3. Section B — Homeowner features

### B.1 Posting & managing a job

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| B-01 | B | Post job happy path | Service + address (via address search) + hours + future start + ≤5 photos | Job `Requested`; `HourlyRateSnapshot` + `TotalAmount` correct decimals; unique `ReferenceCode` |
| B-02 | B | Address search in posting | Type partial address, pick suggestion | Coordinates resolved server-side; **never shown to user**; typed text with no selection must not fabricate coordinates |
| B-03 | B | Validation | 0 hours, past start, missing service, missing address | Per-field 400s; entered data preserved on error |
| B-04 | B | Photo limits | 6 photos; single photo >10 MB | 6th rejected; oversized rejected; counter shows "x/5" |
| B-05 | B | Rate snapshot immutability | Post job; change tradie's rate after | Snapshot unchanged |
| B-06 | M | Edit job (allowed) | `PATCH` while `Requested` and no offers | 204; fields updated |
| B-07 | B | Edit lockout | `PATCH` after an offer exists or status > `Requested` | 409 — "Job cannot be edited once matching has started or offers exist."; mobile hides Edit |
| B-08 | M | Dashboard job cards | Open homeowner dashboard | Card shows service/location, amount right-aligned, human status label, next action |
| B-09 | M | Status-aware tap routing | Tap cards in each status | `AwaitingPayment`→payment screen; `PaymentReview`→payment status; others→job detail/chat (per `job_navigation.dart`) |
| B-10 | M | Jobs list + filters | Open Jobs tab | All jobs listed; terminal states visually distinct (grey/strikethrough pill) |

### B.2 Matching (homeowner side)

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| B-11 | B | Matching screen live | Job `Requested`, open matching screen | Sequential-offer progress, updates via SignalR (not polling stub) |
| B-12 | B | Match result | Tradie accepts | Match-result screen: tradie identity, rating, insured badge if applicable; `AwaitingPayment` CTA |
| B-13 | B | Exhaustion | Decline all candidates (use TRADIE-2 decline + timeout) | Job → `Cancelled` w/ `no_tradie_found`; dead-end screen offers retry/repost (v1.6) |
| B-14 | M | Re-matching | Re-trigger `POST /match` on eligible job | New offers sequential; never two pending offers at once |

### B.3 Payment (homeowner side)

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| B-15 | B | Payment instructions | Job `AwaitingPayment`, open payment screen | Bank details from config; amount = `TotalAmount`; reference format `FIXO-{JobId}` |
| B-16 | B | Upload receipt | Attach image/PDF receipt | Job → `PaymentReview`; status screen shows "under review" |
| B-17 | B | Duplicate receipt guard | Upload identical file on a second job | Refused (`ReceiptHash` unique) |
| B-18 | B | Re-upload after rejection | Staff rejects; upload new file | Back to `PaymentReview`; `ReUploadCount` incremented once per reject |
| B-19 | M | Rejected-receipt UX | Staff rejects | Homeowner notified with reason; status pill = problem (red) |
| B-20 | B | Payment expiry | Let window lapse with no upload | Job → `Expired`/`Cancelled`, `no_payment`; fires exactly once |

### B.4 Job execution → completion

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| B-21 | B | Progress presentation | Walk job through lifecycle | 4-segment progress bar; "Step N of 4 · stage"; correct current-state label each step |
| B-22 | B | Confirm completion | Tradie checked out → job `AwaitingConfirmation` → homeowner taps Confirm | → `Completed`; CTA disabled while a dispute is open (v1.6) |
| B-23 | B | Auto-complete | Check out; wait `AutoCompleteWindowHours` | → `Completed` automatically; review prompt pushed |
| B-24 | M | Cancel job | Cancel icon → reason sheet | Reason codes listed; penalty/fee disclosure shown before confirm |
| B-25 | B | Cancel penalties | Cancel `Booked` (pre-work) vs `InProgress` | Pre-work: 10% flat. In-progress: suggested = elapsed × rate; penalty = remainder + 10% |
| B-26 | B | Review (blind) | Submit review on `Completed` job | Confirmation copy; own review pending; other's hidden until both submit or 7 days |
| B-27 | M | No-show report | Button visible after grace on `Booked`/`InProgress` | Flag against tradie; offered Reassign or Cancel+refund |
| B-28 | M | Dispute | Open dispute from job detail; add text + file evidence | Job → `Disputed`; dispute status/evidence visible |
| B-29 | M | Block & report user | From tradie's public profile | Report submitted; blocked user excluded from interactions; unblock works |
| B-29a | B | Stale-job expiry | Leave job `Requested` past `JobExpiration:ThresholdHours` (default 24h; lower for test) | `ExpirationWorker` cancels w/ `system_expired`; pending offers released; homeowner notified (push + email fallback) |

### B.5 Communication & misc

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| B-30 | B | Chat send/receive | Active job → open chat | Messages deliver in real time; history on re-open |
| B-31 | B | Chat lock at terminal | `Completed`/`Cancelled` job | Input disabled client-side; server rejects send |
| B-32 | M | Quick replies | Tap a quick-reply chip | Sends canned text; editable per v1.5 contract |
| B-33 | M | Messages list | Open Messages tab | Avatar, last message, time, unread dot (v1.6) |
| B-34 | M | Tradie public profile | From match result / job | Name, trade, rating, insured badge, jobs completed — no fabricated fields; contact hidden pre-Booked |
| B-35 | M | Navigate/Call actions | On `Booked`+ job detail | ≥48px tonal buttons; maps/dialer launch (v1.6) |
| B-36 | m | Settings | Language/notifications toggles, legal | Persist or clearly stubbed; no dead controls |

---

## 4. Section C — Tradie features

### C.1 Onboarding & profile

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| C-01 | B | Wizard step 1 — profile | Name/phone/trade/service radius | `TradieProfile` provisioned; per-step validation |
| C-02 | B | Step 2 — rates | Pick catalogue services, set hourly rates | `decimal` end-to-end; range enforced |
| C-03 | B | Step 3 — schedule | Weekday rows + quick-fill | DayOfWeek 0–6 persisted correctly |
| C-04 | B | Step 4 — credentials | jpg/png/pdf ≤10 MB | Private blob; `FileKey`; oversize rejected |
| C-05 | B | Bank details | Enter account number | Saved; last-4 shown to admin payout queue |
| C-06 | M | Pending banner | TRADIE-UNVERIFIED dashboard | Amber banner routes to wizard; unverified excluded from matching |
| C-07 | B | Availability toggle | Dashboard switch off | `isAvailable=false`; amber "paused" banner; active jobs unaffected; excluded from new offers |
| C-08 | B | Licence gating | Regulated service (electrical/plumbing/building) without approved licence | Never offered those jobs; with approved licence → offered |
| C-09 | M | Insurance badge | Approved Insurance credential | "Insured" badge on profile + match result; revoke → gone |

### C.2 Leads & offers

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| C-10 | B | Incoming lead | Homeowner posts matching job | Push + in-app lead appears ≤ ~30 s on dashboard |
| C-11 | B | Offer detail | Open request detail | Service, location/distance, hours, **price lead** (gross), schedule, countdown = `ExpiresAtUtc` |
| C-12 | B | Accept | Tap Accept | Job → `AwaitingPayment`; `MatchedTradieId` set |
| C-13 | B | Decline | Tap Decline | Offer closed; next tradie in sequence offered |
| C-14 | B | Timeout | Let countdown lapse | `TimedOut`; next offer fires; expired request shows dead-end/recovery copy (v1.6) |
| C-15 | B | Double-respond | Accept twice / accept after expiry | 409; single transition |
| C-16 | B | Cross-offer isolation | TRADIE-2 calls respond on TRADIE-1's offer | 403/404; no state change |
| C-17 | B | Address masking | Offer detail + `AwaitingPayment`/`PaymentReview` job | Suburb/city only, phone masked; full address only at `Booked` |

### C.3 Job execution

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| C-18 | B | Check-in | `Booked` job → Check In | → `InProgress`, `StartedAtUtc`; gated button states correct |
| C-19 | B | Check-out | In-progress → Check Out | → `AwaitingConfirmation`, `EndedAtUtc` |
| C-20 | B | Tradie cannot confirm | Call `confirm`/`check-in` as wrong role | 403 |
| C-21 | B | Cancel assigned job | Tradie cancels `Booked`/`InProgress` | Job → `Requested` for rematch; `CancellationCount++`; payment held; penalty copy on sheet |
| C-22 | M | No-show accuse (homeowner) | After grace, tradie reports homeowner no-show | Flag on homeowner; job cancelled with penalty |
| C-23 | B | Job schedule | `GET/POST /api/jobs/{id}/schedule` + `/api/tradie/schedule` | Scheduled start persisted; reminder job fires ~65 min pre-start to both parties |

### C.4 Money

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| C-24 | B | Earnings summary | `GET /api/tradie/earnings` | Server decimals; separate **earned net** (payouts created), **processed net**, **pending** (all-time), **failed** — never gross labelled as earnings; Pacific/Auckland Monday-start week |
| C-25 | B | Payout on completion | Complete a job | `tradie_payouts` row `Pending`; `Commission = Total × rate`; `Net = Gross − Commission`; bank details copied |
| C-26 | M | No bank details | Complete job without bank set | Payout still `Pending`; warning flagged; excluded from batch processing |
| C-27 | B | Payout processed | Staff processes payout | Tradie FCM with net + transfer reference |
| C-28 | M | Review homeowner | "Rate Homeowner" on `Completed` | Blind rules apply same as homeowner reviews |

### C.5 Communication

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| C-29 | B | Chat | Active job | Real-time both directions; locked at terminal states |
| C-30 | M | Dispute from tradie side | Open dispute + evidence on booked/in-progress job | Same flow as B-28 |
| C-31 | M | Report/block homeowner | From homeowner profile | Same as B-29 |

---

## 5. Section D — Admin features (web, Staff + Superadmin)

### D.1 Access & shell

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-01 | B | Login cookie | Admin login; devtools → cookies | `__Host-fixo-admin` httpOnly; no JWT in localStorage; `withCredentials` on all calls |
| D-02 | B | Role gates | Login as homeowner/tradie creds; hit `/dashboard` as anon | 403 → `/403`; anon → login |
| D-03 | B | Sidebar completeness | Inspect nav | Dashboard, Users, Jobs, Credentials, Payments, Payouts, Payout Batches, Disputes, Refunds, Audit Logs, Settings — TradieHunter wordmark |

### D.2 Dashboard & users

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-04 | B | Metrics | `/dashboard` | `GET /api/admin/stats` + `/metrics`; cards + charts render real numbers |
| D-05 | B | User list/detail | `/users`, open one | Pagination; detail shows profile, flags, jobs |
| D-06 | B | Verify / deactivate | Actions on user detail | Persist; deactivated user cannot log in |
| D-07 | M | Flagged accounts | Trigger RepeatCanceller/LowRating flags | Counters increment; `ThresholdHit`; Warn/Suspend/Resolve persist; suspended user blocked |

### D.3 Credential queue

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-08 | B | Queue shape | `/credentials` | Oldest-first, paginated; 15-min SAS `DownloadUrl` |
| D-09 | B | Approve | Approve pending credential | `IsVerified=true` when ≥1 approval; row leaves queue |
| D-10 | B | Reject needs reason | Empty reason → valid reason | Rejected; last rejection un-verifies tradie |
| D-11 | B | SAS expiry | Open URL, retry after 15 min | First renders; expired fails closed |
| D-12 | M | Double-click guard | Double-click Approve | One action; no duplicate rows |

### D.4 Payment queue

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-13 | B | Queue + SLA | `/payments` with items of varying age | Oldest first; amber >15 min; red **URGENT** >30 min |
| D-14 | B | SLA push | Leave a `PaymentReview` >30 min | Push to all staff w/ job ref + wait time |
| D-15 | B | Verify | Review receipt (SAS image) → Verify | Payment `Verified`; job → `Booked`; homeowner + tradie notified |
| D-16 | B | Reject | Reject with/without reason | Reason required; job back to `AwaitingPayment`; window restarted |

### D.5 Refunds

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-17 | B | Queue shape | `/refunds` | Only `Pending` items |
| D-18 | B | Process refund | Modal: `transferReference` + proof (multipart) | → `Processed`; homeowner FCM; row leaves queue |
| D-19 | B | Validation | Missing ref; oversize proof | 400 each |
| D-20 | B | Penny precision | Refund `87.55` | Stored `decimal(18,2)`; no float drift |

### D.6 Payouts & batches

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-21 | B | Payout queue | `/payouts` | Tradie, job ref, gross, commission, net, bank last-4, status, age |
| D-22 | B | Process payout | Modal with `transferReference` | → `Processed`; tradie FCM; reference required (400 without) |
| D-23 | B | Weekly batch | Trigger `PayoutBatchJob` | `PayoutBatch` `Open`; pending payouts → `Scheduled`; no empty batch |
| D-24 | B | Batch complete | `/payouts/batches/:id`, process all, complete | Blocked while unprocessed >0; completes when all done |

### D.7 Disputes

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-25 | B | List + tabs | `/disputes` | All/Open/Resolved/Escalated tabs |
| D-26 | B | Detail | `/disputes/:jobId` | Job context, parties, chat, timelogs, all evidence |
| D-27 | B | Resolve | FullRefund / PartialRefund + note / NoRefund | → `Resolved`; refund generated where chosen; parties notified; job leaves `Disputed` |

### D.8 Audit, settings, platform

| # | Pri | Check | Steps | Expected |
|---|-----|-------|-------|----------|
| D-28 | B | Audit logs | `/audit-logs` after admin actions | Structured rows; old/new JSON captured |
| D-29 | M | Settings | `GET/PUT /api/admin/settings` | Persisted; reflected via `/api/config/locale` |
| D-30 | B | Hangfire auth | `/hangfire` as anon / Staff / Superadmin | 401 anon+Staff; Superadmin only |

---

## 6. Section E — Parallel use cases (two-device real-time)

Run each row with **HO device** and **TR device** side by side (plus
**ADMIN tab** where marked). Do not refresh/pull-to-refresh unless stated —
updates must arrive via SignalR/push. "Silent leg" = check
`JobStatusHistory` row + SignalR payload + notification all fired.

### E.1 Matching phase

| # | Pri | HO device | TR device | Expected (simultaneous) |
|---|-----|-----------|-----------|------------------------|
| E-01 | B | Post a job | Dashboard open | Lead appears on TR ≤30 s w/o refresh; HO matching screen shows "contacting" progress |
| E-02 | B | Watch matching | Offer countdown running | TR countdown ticks to `ExpiresAtUtc`; HO progress reflects pending offer |
| E-03 | B | Watch matching | TR **accepts** | HO → match result + `AwaitingPayment` pill + push; TR job appears under Jobs w/ masked address |
| E-04 | B | Watch matching | TR **declines** | HO progress advances to next candidate copy (never an error); TRADIE-2 receives offer next |
| E-05 | B | Watch matching | TR lets offer expire | Timeout → next tradie offered; HO sees continued progress |
| E-06 | B | Post 2nd job while TR busy on 1st | Two pending offers | Each offer independent; countdowns correct per job |
| E-07 | B | Post job while TR toggles `isAvailable` off mid-match | Toggle off | TR excluded from subsequent offers; pending offer still resolvable |
| E-08 | M | Cancel job while offer pending | Offer open on TR | TR's offer invalidated + notified; dead-end recovery shown |

### E.2 Payment phase

| # | Pri | HO device | TR device | ADMIN tab | Expected |
|---|-----|-----------|-----------|-----------|----------|
| E-09 | B | Upload receipt | Job detail open | `/payments` open | HO → `PaymentReview`; TR notified/sees status; admin row appears w/o refresh |
| E-10 | B | Watch status | Watch job | **Verify** payment | Both devices → `Booked` at once; TR address unmasked; pushes to both |
| E-11 | B | Watch status | — | **Reject** w/ reason | HO gets reason + re-upload CTA; `AwaitingPayment` restored; deadline restarted |
| E-12 | M | Upload while admin opens same row | — | Open modal | First action wins; second sees resolved/conflict — no double transition |
| E-13 | M | Leave unpaid | — | — | On expiry both sides → `Expired` + `no_payment`; admin row clears |

### E.3 Execution phase

| # | Pri | HO device | TR device | Expected |
|---|-----|-----------|-----------|----------|
| E-14 | B | Job detail open | **Check in** | HO → `In progress` live; timer/history row on both |
| E-15 | B | Chat open | Chat open | Send alternately: instant both ways; typing/ordering correct; history identical |
| E-16 | B | — | **Check out** | HO → `AwaitingConfirmation` + "Review and confirm" action pill |
| E-17 | B | **Confirm completion** | Job open | Both → `Completed`; review prompts on both; payout row created (admin) |
| E-18 | M | Idle | Idle | Wait `AutoCompleteWindowHours` post-check-out → both auto-`Completed` |

### E.4 Adverse / race cases

| # | Pri | Scenario | Expected |
|---|-----|----------|----------|
| E-19 | B | HO cancels `Booked` while TR job detail open | TR sees `Cancelled` + reason live; refund pending (admin queue); both notified |
| E-20 | B | TR cancels while HO watching | HO → `Requested` (rematch begins) live; TR cancellation count incremented |
| E-21 | B | HO cancels during `PaymentReview` | No orphan `Payment`; admin queue consistent; both sides `Cancelled` |
| E-22 | B | Either party opens dispute mid-chat | Both → `Disputed` banner; confirm-completion disabled on HO; admin dispute list updates |
| E-23 | B | Dispute resolution while both parties on job | Both → resolved state + outcome notification; refund queue row if refund chosen |
| E-24 | B | Both submit reviews same minute | Both reveal immediately (blind rule: both-submitted wins over 7-day wait) |
| E-25 | M | TR reports HO no-show while HO online | HO gets cancellation + penalty notification; flag recorded |
| E-26 | M | HO blocks TR mid-job | Further messages/interactions rejected; existing job handling per rules |
| E-27 | M | Same account on two devices | Second session functions; status updates reach both instances |
| E-28 | M | Kill TR app mid-offer → reopen | State restored: pending offer + remaining countdown still correct |
| E-29 | M | Offline → reconnect (airplane mode 60 s) | SignalR reconnects; missed status fetched on resume; no stuck UI |
| E-30 | M | Foreground vs background push | Foreground → in-app banner; background → FCM "TradieHunter: …" title |

---

## 7. Cross-cutting invariants (every run)

| # | Check | Expected |
|---|-------|----------|
| X-01 | SignalR parity | Every §6 row: both clients updated without refresh |
| X-02 | UTC | Wire values UTC; rendered values local; test across NZST/NZDT boundary if possible |
| X-03 | Decimal | Totals, refunds, payouts, commission — exact cents everywhere |
| X-04 | SAS privacy | Every credential/receipt/evidence/proof URL: 15-min SAS, no anonymous read |
| X-05 | RBAC matrix | Owner-only → 404; admin-only → 403; anon → 401 (spot-check each controller) |
| X-06 | Double-submit | Double-tap Accept / Verify / Process / Confirm → single transition |
| X-07 | Brand | "TradieHunter" on splash, app bar, push titles, admin sidebar/tab; "Hunter" amber |
| X-08 | History completeness | Every transition writes `JobStatusHistory` with `ActorRole` (+`ReasonCode` when applicable) |
| X-09 | Address privacy | Full address/phone only at `Booked`+ for assigned tradie |
| X-10 | Accessibility pass | Spot-check 3 screens at text-scale 2.0 + 320px width — no clipped CTAs; targets ≥48px |

---

## 8. Known gaps / do-not-false-bug list

| Item | Status |
|------|--------|
| Refresh-token rotation, release logging, token-in-memory (P9-06/08/11/12/14) | OPEN — track, don't mark pass |
| Email fallback for push (P8-06) | Implemented — verify: remove device tokens, trigger a critical notification → email arrives via MailHog |
| Data retention / purge / anonymization (v1.3 P11) | Spec'd but **not present** in current code (no retention endpoints, jobs, or admin page) — flag to PM, do not test as existing |
| Materials billing | Off-platform by design — disclaimer only, no feature |
| In-app payments / BNZ, automated disputes, ML matching, referrals | Out of MVP scope — never expected |

---

## 9. 15-minute regression smoke

1. Register homeowner → OTP → login. _(A)_
2. Tradie wizard → credential → Staff approves → verified. _(C/D)_
3. Post job via address search. _(B-01)_
4. Match → TR accepts on second device → `AwaitingPayment`. _(E-01/E-03)_
5. Receipt upload → Staff verifies → both devices `Booked`. _(E-10)_
6. Check-in → check-out → HO confirms → `Completed` → payout `Pending`. _(E-14–E-17)_
7. Second job: HO cancels `Booked` → refund `Pending` → Staff processes. _(E-19/D-18)_
8. `register` with `"role": 2` → 400; 6 bad logins → 429. _(A-07/A-08)_
9. Green board: `docker compose ps` clean, no error spam in API logs,
   Hangfire shows succeeded jobs.

---

## 10. Bug report template

```md
ID: TH-QA-###
Guide ref: (e.g. E-10, B-17, D-22)
Severity: BLOCKER / MAJOR / MINOR
Env: commit SHA, image tags, device/emulator + OS, API base URL
Accounts: roles used (never paste passwords/tokens)
Steps: 1. … 2. … 3. …
Expected: (per this guide)
Actual: (+ status codes; SignalR received? Y/N; history row? Y/N)
Evidence: response body, screenshots, Hangfire state
Workaround: (if any)
```

## 11. Sign-off

| Section | Tester | Date (UTC) | Pass/Fail | Notes |
|---------|--------|------------|-----------|-------|
| ENV + accounts | | | | |
| A — Shared / auth | | | | |
| B — Homeowner | | | | |
| C — Tradie | | | | |
| D — Admin | | | | |
| E — Parallel use cases | | | | |
| X — Cross-cutting | | | | |
| Smoke | | | | |

**Release rule:** all `[BLOCKER]` rows green; no open `[MAJOR]` without a
tracked workaround; §8 items explicitly accepted with owner + date.
