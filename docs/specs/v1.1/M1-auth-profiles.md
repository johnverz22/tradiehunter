# M1 — Auth & Profiles

Depends on: M0 (Docker & Scaffold — partially complete; unfinished items carried into this milestone)

## Overview

Stand up authentication (email + Google OAuth), role-based access (homeowner/tradie/admin), profile CRUD, and locale configuration. Also completes the remaining M0 scaffolding: Flutter navigation shell, web admin shell, design token wiring, Firebase initialization, and CI.

---

## Carry-over from M0 (unfinished)

### M1-00a: Flutter navigation shell & project structure

- **Platform**: Mobile
- **Description**: Replace the default counter app with the Fixo navigation shell. Set up folder structure per `.agent/rules/mobile.md` MVVM pattern: `lib/models/`, `lib/repositories/`, `lib/viewmodels/`, `lib/views/`, `lib/theme/`, `lib/router/`. Create `GoRouter` configuration with initial routes (splash, auth, homeowner home, tradie home). Bottom navigation bar for authenticated users (Home, Jobs, Chat, Profile). Role-based route redirects.
- **References**: `docs/design/mockup/mobile/01-splash.html`, `.agent/rules/mobile.md` § MVVM, `mobile/pubspec.yaml` (go_router already added)
- **Implemented**: `mobile/lib/router/app_router.dart` (root routes + `ShellRoute`), `mobile/lib/views/main_layout.dart` (role-aware bottom nav), `mobile/AGENTS.md` (route map). MVVM folders: `lib/models/`, `lib/repositories/`, `lib/viewmodels/`, `lib/views/`, `lib/theme/`, `lib/router/`, plus `lib/widgets/` for shared design-system pieces.
- **Acceptance criteria**:
  - [x] Counter app removed
  - [x] GoRouter with named routes
  - [x] Role-aware bottom nav — homeowner: Home/Messages/Profile; tradie: Dashboard/Jobs/Messages/Profile (hidden on auth + flow screens like post-job, chat)
  - [x] Redirect logic: unauthenticated → auth, authenticated → role-based home
  - [x] Folder structure matches MVVM rules

### M1-00b: Wire Flutter theme with design tokens

- **Platform**: Mobile
- **Description**: Wire `mobile/lib/theme/design_tokens.dart` into a complete `ThemeData` for both light and dark modes. Create `FixoTheme` class that builds `ThemeData` from the design tokens (colors, typography, radii). Register both themes in `MaterialApp` via `theme:` and `darkTheme:`. Include Google Fonts setup for Space Grotesk, IBM Plex Sans, IBM Plex Mono (add `google_fonts` package or bundle font assets).
- **References**: `docs/design/design-system.html`, `mobile/lib/theme/design_tokens.dart`
- **Acceptance criteria**:
  - [x] `FixoTheme.light()` and `FixoTheme.dark()` return complete `ThemeData`
  - [x] ColorScheme derived from design tokens
  - [x] Typography mapped: Display → Space Grotesk 700, H2 → Space Grotesk 600, H3 → IBM Plex Sans 600, Body → IBM Plex Sans 400, Mono → IBM Plex Mono 400
  - [x] Button themes match design system (primary, accent, ghost)
  - [x] Input field theme matches design system
  - [x] App renders correctly in both light and dark mode

### M1-00c: React admin shell

- **Platform**: Web
- **Description**: Replace the Vite boilerplate with the Fixo admin shell. Set up folder structure per `.agent/rules/frontend.md`: `src/components/`, `src/features/`, `src/services/`, `src/theme/`. Import `design-tokens.css`. Create app layout with sidebar navigation (Dashboard, Users, Jobs, Disputes, Settings), top bar with logout, and main content area. Set up React Router with route structure.
- **References**: `docs/design/mockup/web/02-admin-dashboard.html`, `.agent/rules/frontend.md` § Directory Structure, `web/src/theme/design-tokens.css`
- **Acceptance criteria**:
  - [x] Vite boilerplate removed
  - [x] Sidebar navigation component
  - [x] React Router with `/login`, `/dashboard`, `/users`, `/jobs`, `/disputes`, `/settings` routes
  - [x] Layout uses design tokens (no hardcoded colors)
  - [x] Placeholder pages for each route
  - [x] Both light and dark theme (system-preference + toggle)

### M1-00d: Firebase initialization (Flutter)

- **Platform**: Mobile
- **Description**: Initialize Firebase in the Flutter app. Add `firebase_options.dart` via FlutterFire CLI (or manual config). Call `Firebase.initializeApp()` in `main()`. Set up `FirebaseMessaging` to request notification permissions and obtain device token. Store device token locally for later registration with backend.
- **References**: `mobile/pubspec.yaml` (firebase_core, firebase_messaging already added)
- **Acceptance criteria**:
  - [x] App initializes Firebase before `runApp`
  - [x] Notification permission requested on first launch
  - [x] Device token obtained and logged (registration with backend deferred to M1-08)
  - [x] Handles permission denied gracefully

### M1-00e: CI pipeline — build & test

- **Platform**: All
- **Description**: Set up CI (GitHub Actions or equivalent) with: (1) Backend: `dotnet build` + `dotnet test`, (2) Mobile: `flutter analyze` + `flutter test`, (3) Web: `npm run build` + `npm run lint`. Triggered on push to main and PRs.
- **Acceptance criteria**:
  - [x] CI config file committed (`.github/workflows/ci.yml` or similar)
  - [x] Backend builds and placeholder test passes
  - [x] Flutter analyze passes with no errors
  - [x] Web builds without errors
  - [ ] Badge in README (optional)

---

## M1 Core Tasks

### M1-01: ApplicationUser entity & Identity setup

- **Platform**: Backend
- **Description**: Configure ASP.NET Identity with a custom `ApplicationUser` entity extending `IdentityUser`. Add fields: `FirstName`, `LastName`, `PhoneNumber` (already on IdentityUser), `Role` (enum: Homeowner, Tradie, Admin), `CreatedAtUtc`, `IsActive` (bool, default true). Create `FixoDbContext` extending `IdentityDbContext<ApplicationUser>`. Configure EF Core with Npgsql + NetTopologySuite. Run initial migration.
- **References**: `docs/ARCHITECTURE.md` § Auth, `.agent/rules/backend.md` § Data rules
- **Acceptance criteria**:
  - [x] `FixoDbContext` registered with Npgsql provider
  - [x] NetTopologySuite configured for spatial support
  - [x] Initial migration creates Identity tables + custom fields
  - [x] `ApplicationUser.Role` stored as string (value converter)
  - [x] Connection string reads from `ConnectionStrings__DefaultConnection`

### M1-02: TradieProfile entity

- **Platform**: Backend
- **Description**: Create `TradieProfile` entity with one-to-one FK to `ApplicationUser` (only for users with Role=Tradie). Fields: `Id`, `UserId` (FK), `TradeType` (enum: Plumber, Electrician, Builder, Painter, Landscaper, General), `BusinessName` (nullable), `IsVerified` (bool, default false), `IsAvailable` (bool, default true), `Location` (NetTopologySuite `Point`, SRID 4326), `Address`, `ServiceRadiusKm` (decimal, default 25), `DeviceToken` (string, nullable — for FCM). Add EF Core migration.
- **Acceptance criteria**:
  - [x] Migration runs cleanly
  - [x] Spatial index on `Location` column
  - [x] One-to-one with `ApplicationUser` via `UserId`
  - [x] `TradeType` stored as string

### M1-03: JWT authentication configuration

- **Platform**: Backend
- **Description**: Configure JWT Bearer authentication in `Program.cs`. Settings in `appsettings.json`: `Jwt:Secret`, `Jwt:Issuer`, `Jwt:Audience`, `Jwt:ExpiryMinutes`. Token includes claims: `sub` (user ID), `email`, `role`, `name`. Configure `AddAuthentication().AddJwtBearer()`. Add `app.UseAuthentication()` and `app.UseAuthorization()`.
- **References**: `docs/ARCHITECTURE.md` § Auth
- **Acceptance criteria**:
  - [x] JWT token issued with correct claims
  - [x] Token validated on protected endpoints
  - [x] Secret read from config (not hardcoded)
  - [x] Expiry configurable
  - [x] Remove default weather forecast endpoint

### M1-04: Registration & login endpoints

- **Platform**: Backend
- **Description**: Create `AuthController` with: `POST /api/auth/register` (email, password, firstName, lastName, role), `POST /api/auth/login` (email, password → JWT), `POST /api/auth/refresh` (refresh token → new JWT). Registration creates `ApplicationUser` via Identity. If role is Tradie, also create stub `TradieProfile`. Use FluentValidation for input.
- **References**: `.agent/rules/backend.md` § Controller Purity
- **Acceptance criteria**:
  - [x] Registration validates email format, password strength (Identity defaults)
  - [x] Login returns JWT + refresh token
  - [x] Refresh token stored securely (database or secure cookie)
  - [x] Registration returns 409 if email already exists
  - [x] Role claim included in JWT
  - [x] Tradie registration creates `TradieProfile` stub

### M1-05: Google OAuth endpoint

- **Platform**: Backend
- **Description**: Create `POST /api/auth/google` endpoint. Accepts Google ID token from Flutter client. Validates token with Google, creates or links `ApplicationUser`. If new user, requires role selection in a follow-up step (`PATCH /api/auth/complete-registration`). Returns JWT.
- **References**: `docs/MVP-SPEC.md` § Tier 1 "Registration/login (email + Google)"
- **Acceptance criteria**:
  - [x] Google token validated server-side
  - [x] New users created with Google email + name
  - [x] Existing users linked by email
  - [x] Role selection required for new users before full JWT is issued
  - [x] Works with Flutter's `google_sign_in` package

### M1-06: Profile CRUD endpoints

- **Platform**: Backend
- **Description**: Create `ProfileController`: `GET /api/profile` (current user), `GET /api/profile/{id}` (public view), `PUT /api/profile` (update own profile). For tradies, include `TradieProfile` fields (trade type, business name, location, availability, service radius). Update validates via FluentValidation.
- **Acceptance criteria**:
  - [x] `IProfileService` interface with implementation
  - [x] Current user profile includes all fields
  - [x] Public profile hides sensitive fields (email, phone)
  - [x] Tradie profile update validates location as valid coordinates
  - [x] Returns 404 for non-existent user

### M1-07: Locale configuration endpoint

- **Platform**: Backend
- **Description**: Create `GET /api/config/locale` endpoint (public, no auth required). Returns the locale configuration from `appsettings.json` `Locale` section: `DefaultCurrency`, `CurrencySymbol`, `PhoneCountryCode`, `DefaultTimezone`, `DistanceUnit`. Bind config section to a `LocaleOptions` class.
- **References**: `docs/ARCHITECTURE.md` § Locale configuration
- **Acceptance criteria**:
  - [x] Config read from `Locale` section in appsettings
  - [x] Strongly typed `LocaleOptions` class
  - [x] Returns JSON matching the schema in ARCHITECTURE.md
  - [x] Values overridable via environment variables (already works via docker-compose)

### M1-08: Device token registration endpoint

- **Platform**: Backend
- **Description**: Create `POST /api/profile/device-token` endpoint. Accepts `{ "token": "...", "platform": "ios|android" }`. Stores/updates FCM device token on the user's record (or a separate `DeviceToken` entity supporting multiple devices). Used later for FCM push.
- **Acceptance criteria**:
  - [x] Authenticated endpoint
  - [x] Upserts device token (replaces old token for same device)
  - [x] Supports multiple devices per user
  - [x] Token validation (non-empty string)

### M1-09: Splash & onboarding screens (Flutter)

- **Platform**: Mobile
- **Description**: Build Splash and Onboarding screens per mockups `docs/design/mockup/mobile/01-splash.html` and `docs/design/mockup/mobile/02-onboarding.html`. Splash shows Fixo logo/branding for 2 seconds, then navigates to onboarding (if first launch) or home (if authenticated). Onboarding: 2–3 swipeable value prop slides with "Get Started" button.
- **References**: `docs/design/mockup/mobile/01-splash.html`, `docs/design/mockup/mobile/02-onboarding.html`
- **Implemented**: `mobile/lib/views/splash_screen.dart` (brand gradient, 2s boot → onboarding/home), `mobile/lib/views/onboarding_screen.dart` (3 slides, amber dots, Next/Skip).
- **Acceptance criteria**:
  - [x] Splash uses design tokens (brand colors, typography)
  - [x] Onboarding slides with page indicator
  - [x] "Get Started" navigates to auth screen
  - [x] First-launch flag stored locally
  - [x] Both light and dark theme

### M1-10: Login screen (Flutter)

- **Platform**: Mobile
- **Description**: Build Login screen per mockup `docs/design/mockup/mobile/03-login.html`. Email + password fields, "Log in" button, "Sign up" link, "Continue with Google" button. Calls `POST /api/auth/login` or `POST /api/auth/google`. Stores JWT in `flutter_secure_storage`. On success, navigates to role-based home.
- **References**: `docs/design/mockup/mobile/03-login.html`, `.agent/rules/mobile.md` § MVVM
- **Implemented**: `mobile/lib/views/login_screen.dart` + `mobile/lib/viewmodels/auth_viewmodel.dart` (`authViewModelProvider`) + `mobile/lib/repositories/auth_repository.dart`; Google flow with `GoogleLoginRequiresRegistration` → `/role-select` (`mobile/lib/views/auth/role_select_screen.dart`).
- **Acceptance criteria**:
  - [x] `AuthViewModel` handles login state
  - [x] `AuthRepository` encapsulates API calls + token storage
  - [x] Email validation (client-side)
  - [x] Loading state on button
  - [x] Error display for wrong credentials
  - [x] Google Sign-In integration
  - [x] JWT stored in flutter_secure_storage
  - [x] Both light and dark theme

### M1-11: Sign-up screen (Flutter)

- **Platform**: Mobile
- **Description**: Build Sign-up screen per mockup `docs/design/mockup/mobile/04-signup.html`. Fields: first name, last name, email, password, confirm password, role selector (Homeowner / Tradie). Calls `POST /api/auth/register`. On success, auto-login and navigate to home. Tradie role shows additional fields after registration (trade type, location — can be deferred to profile edit).
- **References**: `docs/design/mockup/mobile/04-signup.html`
- **Implemented**: `mobile/lib/views/signup_screen.dart` (amber-selected role cards, first/last/email/password, Google stub → auth screen).
- **Acceptance criteria**:
  - [x] Form validation (matching passwords, email format, required fields)
  - [x] Role selector (toggle or segmented control)
  - [x] Loading state during registration
  - [x] Error display for duplicate email (409)
  - [x] Auto-login after successful registration
  - [x] Both light and dark theme

### M1-12: Profile screen (Flutter)

- **Platform**: Mobile
- **Description**: Build Profile screen per mockup `docs/design/mockup/mobile/12-profile.html` (tradie) and `docs/design/mockup/mobile/15-homeowner-profile.html` (homeowner). Shows user info, role badge, edit button. Edit mode: update name, phone, address. Tradies additionally: trade type, business name, availability toggle, location. Calls `PUT /api/profile`.
- **References**: `docs/design/mockup/mobile/12-profile.html`, `docs/design/mockup/mobile/15-homeowner-profile.html`
- **Implemented**: own profile `mobile/lib/views/profile_screen.dart` (view/edit, `profileViewModelProvider` + `ProfileRepository`, live `PUT /api/profile`); public profiles `mobile/lib/views/profile/public_profile_screen.dart` (`isTradie` flag).
- **Acceptance criteria**:
  - [x] `ProfileViewModel` manages profile state
  - [x] `ProfileRepository` handles API calls
  - [x] View mode and edit mode
  - [x] Avatar with initials (no photo upload for MVP)
  - [x] Tradie-specific fields conditionally shown
  - [x] Both light and dark theme

### M1-13: Settings screen (Flutter)

- **Platform**: Mobile
- **Description**: Build Settings screen per mockup `docs/design/mockup/mobile/14-settings.html`. Options: dark mode toggle (system/light/dark), notification preferences, locale display, logout button, app version. Logout clears JWT from secure storage and navigates to auth screen.
- **References**: `docs/design/mockup/mobile/14-settings.html`
- **Implemented**: `mobile/lib/views/settings_screen.dart` (grouped Account/Preferences/Support rows, notification toggle, theme selector persisted via `themeModeProvider`, red Log Out). Locale display row is a stub (`TODO(backend): GET /api/config/locale` options).
- **Acceptance criteria**:
  - [x] Theme mode persisted locally
  - [x] Logout clears tokens and resets navigation
  - [x] Locale read from `GET /api/config/locale`
  - [x] Both light and dark theme

### M1-14: Admin login screen (React)

- **Platform**: Web
- **Description**: Build admin login screen per mockup `docs/design/mockup/web/01-admin-login.html`. Email + password form, calls `POST /api/auth/login`, checks JWT `role` claim is `admin`. Stores JWT. Redirects to dashboard on success.
- **References**: `docs/design/mockup/web/01-admin-login.html`, `.agent/rules/frontend.md` § Scope & Access Control
- **Acceptance criteria**:
  - [x] Login form component in `src/features/auth/`
  - [x] JWT parsed, role checked client-side
  - [x] Non-admin login shows error
  - [x] Uses design tokens
  - [x] Both light and dark theme

### M1-15: Auth token refresh & interceptors

- **Platform**: Mobile + Web
- **Description**: Implement JWT refresh logic. Flutter: Dio interceptor that catches 401, calls `POST /api/auth/refresh`, retries the original request. Web: Axios/fetch interceptor doing the same. Both platforms: on refresh failure, redirect to login.
- **Acceptance criteria**:
  - [x] Transparent refresh (user doesn't see re-login)
  - [x] Concurrent requests during refresh are queued
  - [x] Refresh failure clears auth state and redirects to login
  - [x] Refresh token rotation (old refresh token invalidated)

---

## Dependencies

- Docker Compose stack running (M0 — complete)
- Backend NuGet packages installed (M0 — complete)
- Flutter packages in pubspec (M0 — complete)

## Key risks

- Google OAuth setup requires Firebase project + Google Cloud Console config
- JWT secret management for production
- flutter_secure_storage on iOS requires Keychain entitlements
- Google Fonts loading on first launch (consider bundling font assets)
