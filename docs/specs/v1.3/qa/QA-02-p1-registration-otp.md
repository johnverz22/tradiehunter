# QA-02 — P1 Registration, OTP, tradie verification

Spec: `../../v1.2/P1-registration-otp-verification.md`. Inherited from v1.2 — no changes for v1.3.

## Registration & OTP

- [ ] **P1-01 — Register sends OTP, no JWT**
  Priority: BLOCKER · Precon: QA-00
  1. `POST /api/auth/register` as a new homeowner.
  2. Check `email_otps` row + MailHog.
  Expected: `EmailVerified=false`, NO token issued, OTP stored as hash
  (never plaintext) with ~10-min expiry, email delivered.

- [ ] **P1-02 — Verify happy path**
  Priority: BLOCKER · Precon: P1-01
  1. `POST /api/auth/verify-email` with the correct 6-digit code.
  Expected: `EmailVerified=true`, `EmailVerifiedAt` UTC set, JWT returned.

- [ ] **P1-03 — Wrong-code attempt cap (5)**
  Priority: BLOCKER · Precon: fresh OTP
  1. Submit 5 wrong codes.
  2. Submit the correct code.
  Expected: correct code rejected after 5 tries (OTP invalidated); resend required.

- [ ] **P1-04 — Expired OTP**
  Priority: MAJOR · Precon: fresh OTP
  1. Wait >10 min (or shrink expiry on a test env).
  2. Submit the correct code.
  Expected: rejected as expired; resend required.

- [ ] **P1-05 — Resend cooldown (60s) + voiding**
  Priority: MAJOR
  1. `POST /api/auth/resend-otp`, then again within 60s.
  Expected: second call rejected (cooldown); when a new code IS issued,
  old pending OTPs are voided (old code no longer verifies).

- [ ] **P1-06 — Login gating (unverified)**
  Priority: BLOCKER · Precon: HOMEOWNER-B unverified
  1. Login with the unverified account.
  Expected: no full JWT; 403-style `requiresVerification` signal; mobile
  routes to `/verify-email`, never the dashboard.

- [ ] **P1-07 — OTP screen (mobile)**
  Priority: BLOCKER
  1. Register in-app → OTP screen.
  2. Observe 60s resend countdown; submit; resend.
  Expected: 6-box input works; countdown mirrors backend; success leaves
  OTP screen; login-unverified also lands here.

- [ ] **P1-08 — Google new account skips OTP**
  Priority: BLOCKER
  1. Google SSO with a new email.
  Expected: `EmailVerified=true`, JWT issued, routed to role-select.

- [ ] **P1-09 — Google link, verified password account**
  Priority: MAJOR
  1. Google SSO with an email matching a VERIFIED password account.
  Expected: linked, login succeeds, no duplicate user.

- [ ] **P1-10 — Google link, UNVERIFIED password account**
  Priority: MAJOR
  1. Google SSO with an email matching an UNVERIFIED password account.
  Expected: linking BLOCKED with an error; mobile routes to OTP screen
  (not silent failure, no dupe account).

## Staff invites

- [ ] **P1-11 — Invite (Superadmin)**
  Priority: BLOCKER
  1. `POST /api/admin/staff/invite` as Superadmin.
  Expected: unverified staff user created; set-password email with secure
  token sent.

- [ ] **P1-12 — Invite RBAC**
  Priority: BLOCKER
  1. Same endpoint as Staff / Homeowner / Tradie / anon.
  Expected: 403/401 across the board; no user created, no email sent.

- [ ] **P1-13 — Set password consumes token**
  Priority: BLOCKER · Precon: P1-11
  1. `POST /api/admin/staff/set-password` with the valid token.
  2. Replay the same token.
  Expected: first → password set, `EmailVerified=true`, active; replay → 400.

## Tradie onboarding wizard (`/tradie/onboarding`)

- [ ] **P1-14 — Step 1 profile provisions TradieProfile**
  Priority: BLOCKER
  1. Save name/phone/address, trade picker, radius, optional lat+lng.
  Expected: `PUT /api/profile` creates the `TradieProfile` row; per-step
  validation blocks advancing on bad input.

- [ ] **P1-15 — Step 2 rates are Decimal end-to-end**
  Priority: MAJOR
  1. Pick catalog services (grouped by category), set hourly rates.
  2. Try out-of-range (e.g. negative, >10000).
  Expected: stored exact; client mirrors server 0–10000 validation.

- [ ] **P1-16 — Step 3 schedule maps DayOfWeek 0–6**
  Priority: MAJOR
  1. Set Mon-first rows, `TimeOfDay ↔ HH:mm:ss`; try 8am–5pm quick-fill.
  Expected: weekdays persist as .NET `DayOfWeek` 0–6 via
  `GET/POST /tradie/schedule`.

- [ ] **P1-17 — Step 4 credential upload ≤10MB**
  Priority: BLOCKER
  1. Upload jpg/jpeg/png/pdf (valid + one >10MB).
  Expected: valid → multipart `POST /api/tradie/credentials`, `Pending`,
  private blob (`fixo-credentials`) with `FileKey`; oversize rejected.

- [ ] **P1-18 — Pre-profile 403 means empty**
  Priority: MAJOR · Precon: fresh tradie, no TradieProfile row
  1. Open the wizard (profile read first).
  Expected: initial `GET /tradie/{rates,schedule,credentials}` 403 treated
  as "nothing set yet", not an error.

- [ ] **P1-19 — Pending banner**
  Priority: MINOR · Precon: TRADIE-UNVERIFIED
  1. Open tradie dashboard.
  Expected: amber pending-verification banner routing to the wizard.

- [ ] **P1-20 — Currency symbol follows locale**
  Priority: MINOR
  1. Change `GET /api/config/locale` currency.
  Expected: rate field symbol follows locale (no hardcoded `$`).

## Admin credential queue (`/credentials`)

- [ ] **P1-21 — Pending list shape**
  Priority: BLOCKER · Precon: pending credential exists
  1. `GET /api/admin/credentials/pending` as Staff.
  Expected: paginated, oldest-first; rows show tradie name/email/trade +
  15-min SAS `DownloadUrl`.

- [ ] **P1-22 — SAS download + expiry**
  Priority: MAJOR · Precon: P1-21
  1. Open `DownloadUrl` in a new tab.
  2. Retry after 15+ min.
  Expected: renders/downloads first; expired URL fails (never silently public).

- [ ] **P1-23 — Approve verifies tradie**
  Priority: BLOCKER
  1. Approve a tradie's only pending credential.
  Expected: `ReviewedById`/`ReviewedAt` UTC set; `IsVerified=true`
  (rule: verified while holding ≥1 approval); banner reports outcome.

- [ ] **P1-24 — Reject requires reason (≤500 chars)**
  Priority: BLOCKER
  1. Reject empty → reject 500+ chars → reject valid.
  Expected: empty rejected; over-cap rejected; valid sets `RejectReason`
  (cleared on later approve).

- [ ] **P1-25 — Rejecting last approval un-verifies**
  Priority: BLOCKER · Precon: verified tradie with one approval
  1. Reject that sole approved credential.
  Expected: `IsVerified=false`; tradie disappears from `services/search`.

- [ ] **P1-26 — Re-review allowed**
  Priority: MAJOR
  1. Approve then reject (or reverse) the same credential.
  Expected: status flips; audit fields overwritten; no duplicate rows.

- [ ] **P1-27 — Web queue UX**
  Priority: MAJOR
  1. Approve/reject from `CredentialQueue.tsx`; double-click approve;
     submit an over-long reject reason.
  Expected: reviewed row removed from all cached pages, counts resync;
  row actions disabled in-flight (no double submit); failure surfaces
  backend message; empty trade/business shows `—`.

- [ ] **P1-28 — Only verified matchable**
  Priority: BLOCKER · Precon: TRADIE-UNVERIFIED nearby
  1. `GET /api/services/search` at their location.
  Expected: unverified tradie never returned.
