# Notification Coverage: close the audit gaps across push, email, SignalR and web admin

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Close the gaps found in the notification coverage audit (2026-11-27). Today staff are never told when something needs them, several user-facing events fire no push or email, and a handful of code paths bypass `IJobStatusService` so their changes are never broadcast.
> **Status:** Not started · **Prepared:** 2026-11-27
> **Naming rule:** code identifiers stay `Fixo`; user-facing text is TradieHunter. Do not rename.
> **Convention:** `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S <= 1h, M <= half a day, L >= 1 day.
> **Relationship to other plans:** independent of `08_e2e_persona_fabric_plan.md`, but N8 reuses its fabric (manifest, `e2e-journey.py` scenarios, `web/e2e/`) to prove the new notifications. Email template work follows the existing `EmailTemplateRenderer` + `EmailPreviewSamples` pattern.

---

## 0. Read first

`docs/SPECS.md` (job state machine, payments, disputes, "staff are notified" lines), `docs/MVP.md` (web admin scope; do not invent admin features beyond it), `docs/TESTING.md`, `AGENTS.md` (ask before adding dependencies).

Code: `backend/Services/NotificationService.cs`, `PushNotificationService.cs`, `IEmailSender.cs` / `SmtpEmailSender.cs`, `JobStatusService.cs`, `DisputeService.cs`, `AdminService.cs`, `ProfileService.cs`, `AccountFlagService.cs`, `OfferService.cs`, `QuoteService.cs`, `AdjustmentService.cs`, `JobService.cs`, `Services/Payment/*`, `Services/Payout/*`, `Jobs/*` (`PaymentSlaJob`, `PaymentExpiryJob`, `AutoCompleteJob`, `PayoutBatchJob`, `OfferTimeoutJob`), `web/src/hooks/useDashboard.ts`, `web/package.json`.

## 1. Audit summary (what is broken today)

**Channels.** Email (`IEmailSender`): OTP, staff invite, payment verified/rejected, suspension, refund, job cancelled, `SendCritical*` fallbacks. Push (`PushNotificationService`, FCM): most callers hand-roll `DeviceTokens` loops (~10 copies, no email fallback, stale-token cleanup missing in several). `INotificationService` is the only push-first + email-fallback fan-out. SignalR: `JobHub`, `ChatHub`. Web admin: **no SignalR client** (`@microsoft/signalr` is installed, zero imports in `web/src`), no bell/notification centre, polling only (dashboard 60s, job detail 15s, payment/credential/dispute queues no `refetchInterval`).

**High severity (nothing fires).**

| # | Trigger | Gap |
|---|---|---|
| H1 | `POST /api/disputes`, `/disputes/{id}/evidence/*`, `POST /jobs/{id}/flag` | `DisputeService.OpenDisputeAsync` and `FlagJob` set fields directly, skip `IJobStatusService`; no counterparty/staff alert, no `JobStatusChanged` |
| H2 | `POST /api/admin/disputes/{jobId}/resolve` | Sets `Cancelled` directly, writes history, broadcasts nothing; neither party told |
| H3 | `POST /api/admin/credentials/{id}/review` | Tradie never learns approve/reject or reason; no template |
| H4 | `POST /api/admin/users/{id}/verify` | Verification flip notifies nobody |
| H5 | `POST /api/tradie/credentials` | Upload is silent to staff; no confirmation to tradie |
| H6 | `POST /jobs/{id}/payment/upload-receipt` | `PaymentReview` via SignalR group only; `PaymentSlaJob` just logs ("Future: Alert admins") |
| H7 | Account flags (report, no-show, `LowRating`, `OverduePayment`) | `AccountFlag` doc says admin is notified; `LogFlagAsync` only writes the row |
| H8 | `PaymentExpiryJob.HandleOverdueAsync` | Spec says staff notified; code logs and pushes the two parties |
| H9 | `AutoCompleteJob` staff-review escalation | Flags job, pushes parties, staff never told |
| H10 | `PayoutBatchJob` / `CreateBatchAsync` / `CompleteBatchAsync` | Comment admits no staff notification |

**Medium.** M1 offer accepted/declined/expired is SignalR-only (no "your tradie said yes" push). M2 `IJobStatusService` transitions `Booked`, `InProgress`, `AwaitingConfirmation`, `AwaitingPayment`, `PaymentReview`, `Expired` have no counterparty push/email. M3 legacy `JobService.TransitionStatusAsync` (accept/decline/start-era routes, `DELETE /jobs/{id}`, v1 `RunMatchingAsync`) bypasses `IJobStatusService`: no history, payout, review prompt or notification. M4 push-only events that the critical-notification spec wants emailed (homeowner-cancel to tradie, no-shows, reminders, quote accepted, payout processed, review received/revealed). M5 adjustment withdraw never tells the homeowner. M6 accepting a quote silently declines the rest; no quote-expiry job despite `ValidUntilUtc`. M7 no receipt-received confirmation to homeowner. M8 `AdminService` refund hand-rolls push + email-only-if-no-push, contradicting `refund_processed` being critical. M9 account deactivation is email-only (acceptable, document it). M10 chat has no email fallback (fine for MVP, document it).

## 2. Safety rules (apply to every task)

- Notification failures **never** fail the business operation (same contract as `NotificationService` today): catch, log, continue.
- Every job status change goes through `IJobStatusService`. No direct `job.Status =` writes; this is the rule H1/H2/M3 violate.
- Notification sends happen **after** the DB transaction commits, never inside it.
- Copy is user-facing TradieHunter text; no PII beyond what the existing templates already carry; no tokens/URLs with secrets in push payloads.
- Money in notification copy uses the existing `JobMoney` formatting; never floats.
- No new third-party dependencies without asking (AGENTS.md). `@microsoft/signalr` already exists, so using it is not new.
- Do not invent admin features beyond `docs/MVP.md`. N6 (web surface) must be confirmed against MVP scope before building more than a badge.
- Behaviour changes that alter `SPECS.md` get a `SPECS.md` update in the same PR.

## 3. Design decisions (resolve in N0)

1. **One fan-out.** Everything goes through `INotificationService`; delete the hand-rolled `DeviceTokens` loops. Extend it rather than adding a parallel service.
2. **Staff recipients.** Add `IStaffRecipientResolver` (role `Staff` + `Superadmin`, active, non-suspended) so callers say "notify staff" without querying roles. Default fan-out for staff is email + web admin surface; push to staff only if staff have device tokens (they use web, so usually none).
3. **Policy table, not scattered calls.** A single `NotificationPolicy` map `(event) -> {recipients, push, email, critical, template}` so channel decisions live in one reviewable place and are unit-testable.
4. **Web admin channel.** Recommended: persisted `StaffNotification` rows + `GET /api/admin/notifications` + unread badge/bell, polled (30s) and window-focus refetch; add the SignalR staff group only as a second step (N6.4) to make it instant. Persisting means staff who were offline still see it, which pure SignalR would not give.
5. **Dedup/throttle for staff.** Flag and SLA alerts must be idempotent per `(type, entityId)` so a Hangfire retry or a repeating job does not spam.

## Phase N0 — Recon and decisions (no code)

- [ ] **N0.1** Read the files in §0; confirm each audit row (H1-H10, M1-M10) against current `main` line numbers, since the audit cites ranges that may have drifted (S)
- [ ] **N0.2** Confirm `SPECS.md` wording for every "staff are notified" / "admin is notified" line and list which transitions the spec says should notify the counterparty (S)
- [ ] **N0.3** Decide the web admin channel (§3.4) and confirm it fits `docs/MVP.md`; record the decision in *Decisions and parked items* (S)
- [ ] **N0.4** Inventory every hand-rolled `DeviceTokens` push loop (grep `DeviceTokens`) with file and notification type, to drive N1.5 (S)
- [ ] **N0.5** Decide which M4 push-only events become email-fallback vs stay push-only, and which are `critical` (S)

## Phase N1 — Notification foundation (backend)

- [ ] **N1.1** `IStaffRecipientResolver` + implementation (active Staff/Superadmin user ids and emails), with tests (S)
- [ ] **N1.2** Extend `INotificationService`: `SendToStaffAsync(event, title, body, data, ct)`; non-critical variant with optional template so callers stop choosing between two overloads (M)
- [ ] **N1.3** `NotificationPolicy` map (§3.3) covering every event in Phases N2-N5; unit tests assert channel/critical per event (M)
- [ ] **N1.4** Fix stale-token cleanup in one place (`PushNotificationService`) so every caller gets it (S)
- [ ] **N1.5** Replace the hand-rolled push loops from N0.4 with `INotificationService` calls, one service per commit, no behaviour change except email fallback now applying (L)
- [ ] **N1.6** Fix M8: `AdminService` refund uses `INotificationService` with `critical: true` so the email always sends (S)
- [ ] **N1.7** Idempotency key for staff alerts `(type, entityId)` with a short window; tests for Hangfire-retry duplicates (M)

## Phase N2 — Route bypasses through `IJobStatusService` (fixes H1, H2, M3)

- [ ] **N2.1** `DisputeService.OpenDisputeAsync` and `JobsController.FlagJob` transition via `IJobStatusService` (history row, `JobStatusChanged`); notify counterparty + staff (M)
- [ ] **N2.2** Dispute evidence upload notifies the other party and staff (S)
- [ ] **N2.3** `AdminService.ResolveDisputeAsync`: `Completed`/`Cancelled` via `IJobStatusService`; push + critical email to both parties with the outcome (M)
- [ ] **N2.4** Legacy `JobService.TransitionStatusAsync` paths (accept/decline/start-era, `DELETE /jobs/{id}`, v1 `RunMatchingAsync`): route through `IJobStatusService` or, if a path is dead under `JobFlow:Version=2`, delete it and record why. `DELETE /jobs/{id}` must notify the counterparty (L)
- [ ] **N2.5** Tests: each path writes a `JobStatusHistory` row, emits `JobStatusChanged`, and triggers the policy's notifications (M)

## Phase N3 — Per-transition notification policy (fixes M1, M2, M4, M7)

- [ ] **N3.1** Add the policy hook inside `IJobStatusService.TransitionAsync` after commit: `Booked`, `InProgress`, `AwaitingConfirmation`, `AwaitingPayment`, `PaymentReview`, `Expired` notify the counterparty per N0.5 (L)
- [ ] **N3.2** Offer lifecycle: homeowner push when a tradie accepts; decline/expire notify as the policy says (`OfferService`, `OfferTimeoutJob`) (M)
- [ ] **N3.3** Receipt uploaded: confirmation push to homeowner ("we received your receipt") (S)
- [ ] **N3.4** M4 events moved to the decided channel (email fallback where chosen): homeowner-cancel to tradie, no-shows, reminders, quote accepted, payout processed, review received/revealed (M)
- [ ] **N3.5** Adjustment withdraw notifies the homeowner (M5) (S)
- [ ] **N3.6** Quote accept notifies losing tradies (M6); add a quote-expiry Hangfire job honouring `ValidUntilUtc` with notification, or park with reason (M)

## Phase N4 — Credential and verification flows (H3, H4, H5)

- [ ] **N4.1** Email template(s) `CredentialDecision` (approved/rejected + reason) in `EmailTemplateRenderer`, plus `EmailPreviewSamples` entry (M)
- [ ] **N4.2** `AdminService` credential review: push + email to the tradie with outcome and reject reason (M)
- [ ] **N4.3** `AdminService` user verify: tradie notified (S)
- [ ] **N4.4** `ProfileService` credential upload: confirmation to the tradie, `StaffNotification`/email to staff (M)

## Phase N5 — Staff alerts from jobs and flags (H6-H10)

- [ ] **N5.1** `PaymentService.UploadReceiptAsync`: staff alert "receipt awaiting verification" (S)
- [ ] **N5.2** `PaymentSlaJob`: replace the log with a staff alert at the 30-minute SLA breach, idempotent per payment (S)
- [ ] **N5.3** `PaymentExpiryJob.HandleOverdueAsync`: staff alert per `SPECS.md` (S)
- [ ] **N5.4** `AutoCompleteJob` escalation: staff alert that a job needs review (S)
- [ ] **N5.5** `PayoutService.CreateBatchAsync` / `CompleteBatchAsync` and `PayoutBatchJob`: staff alert when a batch is ready/completed; remove the "would normally broadcast" comment (S)
- [ ] **N5.6** `AccountFlagService.LogFlagAsync`: alert staff when the threshold the `AccountFlag` doc describes is crossed (confirm the threshold in N0.2); covers report, no-show, `LowRating`, `OverduePayment` (M)
- [ ] **N5.7** Email templates for dispute opened/resolved, payout batch ready, flag threshold, staff digest (M)

## Phase N6 — Web admin surface (staff awareness)

- [ ] **N6.1** Backend: `StaffNotification` entity + migration (`type`, `entityType`, `entityId`, `title`, `body`, `createdUtc`, `readUtc`), `GET /api/admin/notifications`, `POST .../read`, `POST .../read-all`; migration follows the existing EF process (M)
- [ ] **N6.2** `SendToStaffAsync` persists a row per staff user (or one shared row with per-user read state; decide in N0.3) (M)
- [ ] **N6.3** Web: bell + unread badge in the layout, dropdown list linking to the entity (`/payments`, `/credentials`, `/disputes/{id}`, `/users/{id}`), polled 30s + refetch on focus, built from existing components (`Badge`, `Modal`, `EmptyState`), design tokens only (L)
- [ ] **N6.4** Add `refetchInterval` to the payment, credential and dispute queues so lists update without navigation (S)
- [ ] **N6.5** Optional: staff SignalR group + `@microsoft/signalr` client to push `StaffNotificationCreated` for instant badge updates. **Park if polling is accepted in N0.3** (M)

## Phase N7 — Docs

- [ ] **N7.1** Update `docs/SPECS.md`: notification matrix (event -> recipients -> channels -> critical) generated from `NotificationPolicy` (M)
- [ ] **N7.2** Update `docs/MVP.md` if the admin notification surface adds scope (S)
- [ ] **N7.3** Document accepted non-goals: chat email fallback (M10), account-deactivation email-only (M9) (S)

## Phase N8 — Verification

- [ ] **N8.1** Backend unit tests: policy map, staff resolver, dedup, each new call site with fake `INotificationService`/`IEmailSender` (L)
- [ ] **N8.2** Extend `scripts/e2e-journey.py` scenarios (`dispute-attachments-reviews`, `receipt-reject-resubmit`, credentials) to assert the resulting MailHog messages and `GET /admin/notifications` rows via real API routes (M)
- [ ] **N8.3** `web/e2e/persona-fabric.spec.ts`: staff sees the bell badge after a receipt upload and a credential upload (M)
- [ ] **N8.4** Mobile: `flutter analyze --fatal-infos` + `flutter test` if payload/route handling for new push types changes (S)
- [ ] **N8.5** `dotnet test`, `npm run lint`, `npm run build`, `python3 -m py_compile` on touched scripts, `bash -n scripts/run-e2e.sh` (S)
- [ ] **N8.6** Run `bash scripts/run-e2e.sh FABRIC --fail-fast` against the local stack and paste per-tier results in the Results log (M)

---

## Suggested order and PR slicing

1. N0 -> N1 (foundation, no user-visible change except fallback emails).
2. N2 (correctness first: removes the rule violations, smallest blast radius with highest value).
3. N5 + N6 (staff finally get alerts; needs N1.1/N1.2).
4. N4, then N3 (user-facing copy; N3.1 is the largest change, keep it behind per-transition policy entries so it can ship incrementally).
5. N7, N8 alongside each PR rather than at the end.

## Definition of done

Every row in the audit (H1-H10, M1-M10) is either fixed and covered by a test, or explicitly parked/accepted below with a reason. No direct `job.Status` writes remain outside `IJobStatusService`. No hand-rolled `DeviceTokens` push loops remain outside `PushNotificationService`. Staff have a visible, persisted notification surface. Docs are updated and the FABRIC run passes.

## Results log

_Empty. Append dated entries as phases land._

## Decisions and parked items

_Empty. Record N0 decisions (web channel, staff recipient model, M4 channel choices, quote-expiry job) here._
