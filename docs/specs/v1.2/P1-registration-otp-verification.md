# Phase 1: Registration, Email OTP, Tradie Verification

This document details the implementation specifications for Phase 1 of v1.2, focusing on secure registration, email OTP verification, staff invitations, and comprehensive tradie onboarding with credential verification.

## P1-01: Backend - Database Models & Migrations
**Platform:** Backend
**Description:** Create new EF Core entities for OTPs, tradie onboarding data (schedules, rates, credentials), and services. Update `ApplicationUser` to track email verification status. Apply EF Core HasConversion for enum statuses. Money fields must use `decimal`.
**References:**
- `Models/ApplicationUser.cs`
- `Models/TradieProfile.cs`
- `Models/Enums.cs` (or equivalent)
**Acceptance Criteria:**
- [x] Add `bool EmailVerified = false` to `ApplicationUser`.
- [x] Create `EmailOtp` model: `UserId`, `CodeHash` (string), `ExpiresAt` (UTC), `Attempts` (int), `ConsumedAt` (nullable UTC).
- [x] Create `TradieCredential` model: `TradieProfileId`, `Type` (enum/string), `FileKey`, `OriginalFileName`, `Status` (Pending/Approved/Rejected, stored as string), `ReviewedById` (nullable), `ReviewedAt` (nullable UTC), `RejectReason` (string).
- [x] Create `TradieSchedule` model: `TradieProfileId`, `Weekday` (0-6), `StartTime` (TimeSpan), `EndTime` (TimeSpan).
- [x] Create `Service` model: `Name`, `Category` (enum).
- [x] Create `TradieRate` model: `TradieProfileId`, `ServiceId`, `HourlyRate` (decimal, configure precision in OnModelCreating).
- [x] Generate and apply EF Core migration (run inside Docker container).
**Revises:**
- `Models/ApplicationUser.cs`
- `Data/ApplicationDbContext.cs`

## P1-02: Backend - Email Infrastructure
**Platform:** Backend
**Description:** Implement an email sending service abstraction to send OTP codes and staff invitations. Setup MailHog or Papercut for local development.
**References:** None (New Feature)
**Acceptance Criteria:**
- [x] Create `IEmailSender` interface with methods for sending OTPs and invites.
- [x] Implement `SmtpEmailSender` service.
- [x] Register `IEmailSender` in dependency injection.
- [x] Provide configuration block in `appsettings.Development.json` for local MailHog/Papercut.

## P1-03: Backend - Registration & OTP Endpoints
**Platform:** Backend
**Description:** Revise the registration endpoint to generate and send an OTP, storing its hash. Implement verification and resend endpoints with rate limiting and attempt caps.
**References:**
- `Controllers/AuthController.cs`
- `Services/TokenService.cs` (or `AuthService`)
**Acceptance Criteria:**
- [x] `POST /auth/register` creates user with `EmailVerified = false`, generates a random 6-digit code, hashes it, stores in `email_otps` (expires in 10 mins), and sends via `IEmailSender`.
- [x] `POST /auth/verify-email` accepts code, verifies hash, handles attempts limits (max 5 tries before invalidation), sets `EmailVerified = true`, and returns JWT.
- [x] `POST /auth/resend-otp` checks rate limits (60s cooldown, hourly cap), generates new code, voids old pending OTPs, and sends email.
- [x] Update Login logic: If `EmailVerified == false`, return a distinct response code (e.g., 403 or custom DTO status) directing to OTP screen instead of issuing a full JWT.
**Revises:**
- `Controllers/AuthController.cs`
- `DTOs/Auth/` (Request/Response models)

## P1-04: Backend - Google Login Updates
**Platform:** Backend
**Description:** Adapt the Google SSO endpoint to mark accounts as email verified automatically, and handle account linking rules safely.
**References:**
- `Controllers/AuthController.cs`
**Acceptance Criteria:**
- [x] `POST /auth/google` (or equivalent) sets `EmailVerified = true` for new accounts.
- [x] Skips OTP flow, returning standard JWT with role selection required if no role exists.
- [x] If Google email matches an existing password-based account, link them ONLY if the password account has `EmailVerified = true`. If unverified, block linking and return error.
**Revises:**
- `Controllers/AuthController.cs`

## P1-05: Backend - Staff & Admin Invites
**Platform:** Backend
**Description:** Superadmins need to invite staff members (admins) via email, allowing them to set a password to activate their account.
**References:**
- `Controllers/AdminController.cs` (or `StaffController.cs`)
**Acceptance Criteria:**
- [x] `POST /admin/staff/invite` (Superadmin only) creates an unverified admin user and sends a set-password link with a secure token.
- [x] `POST /admin/staff/set-password` consumes the invite token, sets password, sets `EmailVerified = true`, and activates the account.

## P1-06: Backend - Tradie Onboarding Endpoints
**Platform:** Backend
**Description:** Create endpoints for tradies to manage their schedules, rates, and upload verification credentials to blob storage (private Azure Blob container via Azurite locally).
**References:**
- `Controllers/ProfileController.cs`
- `Services/BlobStorageService.cs`
**Acceptance Criteria:**
- [x] `GET/POST /tradie/schedule` to retrieve and update `TradieSchedule` records.
- [x] `GET/POST /tradie/rates` to retrieve and update `TradieRate` records (HourlyRate must be decimal).
- [x] `GET/POST /tradie/credentials` to fetch user's credentials and upload new ones.
- [x] `BlobStorageService` integration to upload credentials to a private bucket, generating a `FileKey`.
- [x] Set newly uploaded credentials `Status` to `Pending`.

## P1-07: Backend - Admin Credential Verification Endpoints
**Platform:** Backend
**Description:** Endpoints for admins to query the queue of pending tradie credentials and approve/reject them.
**References:**
- `Controllers/AdminController.cs`
- `Services/AdminService.cs`
**Acceptance Criteria:**
- [x] `GET /admin/credentials/pending` returns paginated list of pending credentials. (Includes tradie name/email/trade + 15-min SAS `DownloadUrl`; oldest-first; staff policy.)
- [x] `POST /admin/credentials/{id}/review` accepts status (Approved/Rejected) and an optional `RejectReason`. (Status parsed case-insensitively; RejectReason required on reject, cleared on approve; re-review allowed.)
- [x] Updates the credential record, sets `ReviewedById` and `ReviewedAt` (UTC).
- [x] If Approved, and it fulfills requirements, update `TradieProfile.IsVerified = true` (or trigger IJobStatusService logic if state-dependent). Only verified tradies can be matched. (MVP rule: verified while holding ≥1 approved credential — approving verifies, rejecting the last approval un-verifies.)
**Revises:**
- `Controllers/AdminController.cs`

## P1-08: Mobile - Auth Flow & OTP Screen
**Platform:** Mobile
**Description:** Implement the OTP entry screen in Flutter and integrate it into the registration and login flows using Riverpod.
**References:**
- `lib/views/signup_screen.dart`
- `lib/views/login_screen.dart`
- `lib/repositories/auth_repository.dart`
**Acceptance Criteria:**
- [x] Create `otp_verification_screen.dart` with a 6-digit input field, submit button, and a countdown timer for "Resend OTP". (Route `/verify-email`, reached via `context.go('/verify-email', extra: email)`; 60s countdown mirrors the backend `ResendCooldown`. The 6-box input is a reusable `OtpCodeField` in `lib/views/widgets/otp_code_field.dart`.)
- [x] Update `auth_repository.dart` to handle the new OTP endpoints. (`verifyEmail` → `POST /api/auth/verify-email`, `resendOtp` → `POST /api/auth/resend-otp`, plus 403 `{ requiresVerification }` detection on login/Google.)
- [x] On successful email signup, route to OTP screen. (`register()` returns `AuthNeedsEmailVerification` — the backend issues no tokens until verification.)
- [x] On login, if backend indicates unverified, route to OTP screen. (`login()` returns `AuthNeedsEmailVerification` on HTTP 403.)
- [x] On Google signup, bypass OTP and route directly to `role_select_screen.dart`. (Unchanged for new accounts; P1-04's blocked-link case routes to the OTP screen instead of failing silently.)
**Revises:**
- `lib/views/signup_screen.dart`
- `lib/views/login_screen.dart`
- `lib/repositories/auth_repository.dart`
- `lib/viewmodels/auth_viewmodel.dart`
- `lib/router/app_router.dart`

## P1-09: Mobile - Tradie Onboarding Wizard
**Platform:** Mobile
**Description:** Create a multi-step onboarding wizard for tradies to set up their profile, schedule, rates, and upload credentials.
**References:**
- `lib/screens/role_select_screen.dart`
- `lib/repositories/profile_repository.dart`
**Acceptance Criteria:**
- [x] Create `tradie_onboarding_wizard.dart` containing multiple steps. (`lib/views/tradie/tradie_onboarding_wizard.dart` — 4-step PageView with progress dots, per-step validation + save; route `/tradie/onboarding`, root-level so no bottom nav covers the form.)
- [x] Step 1: Base profile (address, geo point, service radius, unverified phone). (Name/phone/address/trade picker from catalog categories/radius as `Decimal`/optional lat+lng card; saves via `PUT /api/profile`, which also provisions the `TradieProfile` row.)
- [x] Step 2: Select services and set hourly rates (using `decimal` handling in Dart). (Catalog grouped by `TradeCategory`; rates held as `Decimal` end-to-end, single `toDouble()` at the JSON boundary; mirrors server 0–10000 validation.)
- [x] Step 3: Set weekly schedule (weekday + hours). (Mon-first rows map to .NET `DayOfWeek` 0–6; `TimeOfDay` ↔ `HH:mm:ss` TimeSpan; weekday 8am–5pm quick-fill.)
- [x] Step 4: Credential upload (file picker for images/PDFs). (`file_picker` jpg/jpeg/png/pdf ≤10MB, kind picker bottom sheet; uploads via multipart `POST /api/tradie/credentials`, recorded `Pending`.)
- [x] Submit all data to backend via `profile_repository.dart`. (Each step saves through `ProfileRepository` before advancing; `TradieOnboardingNotifier` is wizard-scoped, separate from the shared profile provider.)
- [x] Show pending verification state on Tradie Dashboard if `IsVerified == false`. (`TradieDashboardView` reads `profile['isVerified']` from `GET /api/profile` and shows an amber banner routing to the wizard.)

**Notes:**
- Adds two dependencies not previously in `mobile/pubspec.yaml`, both named by this spec's acceptance criteria: `decimal` (money) and `file_picker` (PDF selection — `image_picker` cannot pick documents).
- `GET /api/tradie/{rates,schedule,credentials}` answer 403 until a `TradieProfile` row exists, which `PUT /api/profile` creates. The wizard's initial load therefore reads 403 as "nothing set yet" rather than an error, and the profile read happens first.
- `viewmodels/locale_viewmodel.dart` was extracted from `views/settings_screen.dart` so the rate field reads its currency symbol from `GET /api/config/locale` rather than hardcoding `$`.
- `network/api_error.dart` was extracted from `AuthRepository` so the wizard reports HTTP failures with the same copy as the rest of the app.
- The geo point is free-text latitude/longitude: the stack has no geocoding endpoint or maps package yet, so there is nothing to resolve an address string. `post_job_screen.dart` has the same gap.
- Wire format (`TimeSpan`, `Decimal`, PascalCase enums) is covered by `mobile/test/tradie_onboarding_test.dart`.

## P1-10: Web Admin - Credential Verification Queue
**Platform:** Web
**Description:** Create a new page in the React admin dashboard to review pending tradie credentials.
**References:**
- `src/features/dashboard/` (or similar feature folder)
**Acceptance Criteria:**
- [x] Create `CredentialQueue.tsx` fetching from `/admin/credentials/pending`. (`web/src/features/credentials/pages/CredentialQueue.tsx`, served at route `/credentials` and in the sidebar; typed API calls live in `services/adminApi.ts`, React Query hooks in `features/credentials/hooks/useCredentials.ts`.)
- [x] Display table/list of tradies and their uploaded credentials with links to securely view the files (using presigned URLs from backend if needed). (One row per credential: tradie name/email linked to `/users/{id}`, trade + business, credential type, and the file name linked to the backend's 15-min SAS `DownloadUrl` via `target="_blank" rel="noopener noreferrer"`. Empty trade/business render as `—`; the list is paginated 20 per page with the shared `Pagination` component.)
- [x] Provide "Approve" and "Reject" buttons. (Per-row actions; both are disabled while that row's review is in flight to prevent double submits.)
- [x] If Reject is clicked, show a modal to enter `RejectReason`. (Reuses the shared `ConfirmModal`, which gained optional `children`/`confirmDisabled` props instead of duplicating modal chrome; the reason is required and capped at 500 chars to mirror `ReviewCredentialRequestValidator`.)
- [x] Call `POST /admin/credentials/{id}/review` and update the local list state on success. (The reviewed row is removed from every cached queue page via `setQueryData`, then the queue + users caches are invalidated so counts and paging resync; a banner reports the returned `tradieIsVerified` outcome. Failures surface the backend `{ message }` or the first FluentValidation `errorMessage`.)
**Revises:**
- `web/src/App.tsx`
- `web/src/layout/AdminLayout.tsx`
- `web/src/components/ConfirmModal.tsx`
- `web/src/services/adminApi.ts`
