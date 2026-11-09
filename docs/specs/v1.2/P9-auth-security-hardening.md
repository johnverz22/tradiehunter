# Phase 9: Auth & Mobile Security Hardening

Security audit findings from 2026-09-28, covering the backend API, React web
admin, and Flutter mobile app. Findings are ranked by severity and grouped into
tasks. All items here must be resolved before a public production release.

Audit methodology: static code review of all auth paths + research against
OWASP API Security Top 10 (2023), OWASP Mobile Top 10 (2024), and current CVE
landscape (September 2026).

---

## P9-01: Block Privilege Escalation via Registration Endpoint
**Platform:** Backend  
**Severity:** CRITICAL  
**Description:**  
`POST /api/auth/register` accepts a user-supplied `Role` field in the request
body. The `RegisterRequestValidator` passes `IsInEnum()`, which accepts
`Staff` (2) and `Superadmin` (3). An unauthenticated attacker can self-assign
admin privileges at registration time — the same class of flaw as
CVE-2026-31070 and CVE-2026-31071 (both issued June 2026, OWASP API3:2023
Mass Assignment / Broken Object Property Level Authorization).

**References:**
- `Controllers/AuthController.cs` — `Register` action
- `Validators/AuthValidators.cs` — `RegisterRequestValidator`
- `DTOs/AuthDTOs.cs` — `RegisterRequest`

**Revises:**
- `Validators/AuthValidators.cs`

**Acceptance Criteria:**
- [x] `RegisterRequestValidator` constrains `Role` to `Homeowner` or `Tradie` only:
  ```csharp
  RuleFor(x => x.Role)
      .Must(r => r == UserRole.Homeowner || r == UserRole.Tradie)
      .WithMessage("Role must be Homeowner or Tradie.");
  ```
- [x] Attempting `POST /api/auth/register` with `"role": 2` (Staff) returns HTTP 400.
- [x] Attempting `POST /api/auth/register` with `"role": 3` (Superadmin) returns HTTP 400.
- [x] Staff and Superadmin accounts can only be created via the existing staff-invite flow (`POST /api/admin/staff/invite`), which is protected by `RequireSuperadminRole`.

---

## P9-02: Bind `completeRegistration` to the Google Session
**Platform:** Backend  
**Severity:** MEDIUM  
**Description:**  
`PATCH /api/auth/complete-registration?userId=<guid>` is unauthenticated and
applies to any userId in the query string. An attacker who guesses or enumerates
a user GUID can change that user's role. This endpoint exists to support the
Google SSO "new user picks role" flow where no JWT exists yet, but there is
currently no binding between the Google session that created the account and the
caller of this endpoint.

**References:**
- `Controllers/AuthController.cs` — `CompleteRegistration` action
- `Controllers/AuthController.cs` — `GoogleLogin` action

**Revises:**
- `Controllers/AuthController.cs`
- `Data/FixoDbContext.cs` (new column or table)

**Acceptance Criteria:**
- [x] When `GoogleLogin` creates a new stub user (`RequiresRegistration: true`), it
  issues a short-lived (10-minute) one-time registration token and stores its
  SHA-256 hash against the user record (new nullable column
  `RegistrationToken` + `RegistrationTokenExpiresAtUtc` on `ApplicationUser`,
  or a separate `RegistrationTokens` table).
- [x] The `RequiresRegistration` response includes `registrationToken` alongside
  `userId`.
- [x] `CompleteRegistration` requires a matching, non-expired, unconsumed
  `registrationToken` query parameter. On success the token is immediately
  consumed (nulled/deleted) so it cannot be replayed.
- [x] Missing, expired, or already-used tokens return HTTP 400.
- [x] Mobile `RoleSelectScreen` passes the token received from `GoogleLogin`
  through to `completeRegistration`.
- [x] Migration generated and applied.

---

## P9-03: Enable Login Account Lockout
**Platform:** Backend  
**Severity:** HIGH  
**Description:**  
`CheckPasswordSignInAsync(user, password, lockoutOnFailure: false)` explicitly
disables ASP.NET Identity's built-in lockout. Combined with no rate limiting on
`POST /api/auth/login`, an attacker can run unlimited password guesses
(credential stuffing / brute force). 81% of hacking-related breaches in the
Verizon 2025 DBIR involved compromised or weak credentials.

**References:**
- `Controllers/AuthController.cs` — `Login` action
- `Program.cs` — Identity options

**Revises:**
- `Controllers/AuthController.cs`
- `Program.cs`

**Acceptance Criteria:**
- [x] `CheckPasswordSignInAsync` called with `lockoutOnFailure: true`.
- [x] `result.IsLockedOut` is checked; returns HTTP 429 with
  `{ "message": "Account temporarily locked. Please try again later." }`.
- [x] Identity lockout configured in `Program.cs`:
  ```csharp
  options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
  options.Lockout.MaxFailedAccessAttempts = 5;
  options.Lockout.AllowedForNewUsers = true;
  ```
- [x] Seeded admin and demo accounts are not locked out during seed (seed runs
  `userManager.UpdateAsync` rather than attempting login, so no impact).

---

## P9-04: Externalize JWT Secret and Rotate It
**Platform:** Backend  
**Severity:** HIGH  
**Description:**  
The JWT signing secret is committed in plaintext to `appsettings.json` and
`appsettings.Development.json` and is identical in both files. If the
repository is shared or becomes public, any holder of the secret can forge JWTs
for any role. The current secret is also 38 characters; NIST recommends at
least 32 bytes (256-bit) with 64 bytes preferred for HS256.

**References:**
- `appsettings.json` — `Jwt:Secret`
- `appsettings.Development.json` — `Jwt:Secret`
- `Services/TokenService.cs`

**Revises:**
- `appsettings.json` (remove secret value)
- `appsettings.Development.json` (remove secret value)

**Acceptance Criteria:**
- [x] `appsettings.json` and `appsettings.Development.json` have `Jwt:Secret`
  set to an empty string or placeholder (e.g. `""`). The real value is
  supplied via environment variable `Jwt__Secret` at runtime (Docker Compose
  `env_file`, Azure Key Vault, or `dotnet user-secrets` for local dev).
- [x] A new 64-byte random secret is generated:
  ```bash
  openssl rand -base64 64
  ```
  and stored in the environment/secrets store — not in any committed file.
- [x] `appsettings.Development.json` is added to the root `.gitignore` (or the
  existing entry is verified to cover it), and `dotnet user-secrets` is
  documented in `backend/STARTER_GUIDE.md` for local dev setup.
- [x] The backend fails fast at startup with a clear message if `Jwt:Secret` is
  empty (already guarded by `?? throw new ArgumentNullException` in
  `Program.cs` — verify this path is hit and the message is clear).
- [x] Google Client ID in `appsettings.Development.json` is also moved to
  user-secrets / env vars following the same pattern.

---

## P9-05: Enforce HTTPS Metadata Check by Environment
**Platform:** Backend  
**Severity:** HIGH  
**Description:**  
`options.RequireHttpsMetadata = false` is hardcoded with a comment saying
"true in prod". This is a manual step that can be forgotten. If left false
in production, JWTs are accepted over plain HTTP.

**References:**
- `Program.cs` — JWT Bearer options

**Revises:**
- `Program.cs`

**Acceptance Criteria:**
- [x] Replace the hardcoded `false` with an environment-driven value:
  ```csharp
  options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
  ```
- [x] No manual step is required between dev and production — the flag
  derives from `ASPNETCORE_ENVIRONMENT` automatically.

---

## P9-06: Implement Real Refresh Token Rotation
**Platform:** Backend + Mobile  
**Severity:** CRITICAL (deferred stub — must be resolved before production)  
**Description:**  
`POST /api/auth/refresh` returns hardcoded fake tokens (`"new-stub-token"`).
There is no refresh token validation, rotation, or revocation. A stolen refresh
token is permanently valid. The mobile `AuthInterceptor` calls this on 401,
stores the garbage response as the new JWT, retries, gets another 401, and
silently kicks the user to `/auth` after 60 minutes with no explanation.

This is OWASP API2:2023 (Broken Authentication) — improper token lifecycle
management.

**References:**
- `Controllers/AuthController.cs` — `Refresh` action
- `Services/TokenService.cs`
- `mobile/lib/network/auth_interceptor.dart`

**Revises:**
- `Controllers/AuthController.cs`
- `Services/TokenService.cs`
- `Data/FixoDbContext.cs` (new table)
- `mobile/lib/network/auth_interceptor.dart`
- `mobile/lib/repositories/auth_repository.dart`

**Acceptance Criteria:**
- [x] New `RefreshToken` entity: `Id`, `UserId`, `TokenHash` (SHA-256 of the
  opaque token), `ExpiresAtUtc`, `ConsumedAtUtc` (nullable), `ReplacedByTokenHash`
  (nullable), `CreatedAtUtc`. Migration generated and applied.
- [x] `TokenService.CreateToken` additionally generates a cryptographically random
  96-byte refresh token (opaque, stored as its hash), returns it alongside the
  JWT.
- [x] `POST /api/auth/refresh` validates the presented token against the hash in
  the DB, checks it is unconsumed and unexpired, marks it consumed, issues a
  new JWT + new refresh token (rotation-on-use), and stores the new hash.
  Returns 401 on any failure (not found, expired, already consumed).
- [x] Refresh tokens expire after 30 days.
- [x] `AuthRepository.logout` calls `DELETE /api/auth/refresh` (new endpoint) to
  revoke the current refresh token server-side.
- [x] On the mobile side, `AuthInterceptor` correctly handles a 401 from the
  refresh endpoint by clearing tokens and routing to `/auth` with a
  user-visible error snackbar ("Session expired — please sign in again").
- [x] Queued requests during a refresh that ultimately fails are rejected via
  `handler.reject(err)` rather than silently dropped.

---

## P9-07: Fix Android Cleartext Traffic Scope
**Platform:** Mobile (Android)  
**Severity:** CRITICAL  
**Description:**  
`android:usesCleartextTraffic="true"` is set globally on the `<application>`
element in `AndroidManifest.xml` with only a comment to remove it for release
builds. There is no separate release manifest overriding this. All builds —
including production APKs — permit unencrypted HTTP, exposing JWTs, OTP codes,
chat content, and payment references to MITM interception on any hostile
network (CVE-2025-45080 class; CWE-319; OWASP Mobile M5:2024 Insecure
Communication).

**References:**
- `android/app/src/main/AndroidManifest.xml`

**Revises:**
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/network_security_config.xml` (new)
- `android/app/src/debug/res/xml/network_security_config.xml` (new)

**Acceptance Criteria:**
- [x] `android:usesCleartextTraffic="true"` removed from the main
  `AndroidManifest.xml`.
- [x] Main (production) network security config created at
  `android/app/src/main/res/xml/network_security_config.xml`:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <network-security-config>
      <base-config cleartextTrafficPermitted="false" />
  </network-security-config>
  ```
- [x] Debug-only config created at
  `android/app/src/debug/res/xml/network_security_config.xml` allowing
  cleartext to the emulator host only:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <network-security-config>
      <domain-config cleartextTrafficPermitted="true">
          <domain includeSubdomains="true">10.0.2.2</domain>
          <domain includeSubdomains="true">localhost</domain>
      </domain-config>
  </network-security-config>
  ```
- [x] Both manifests reference the config via
  `android:networkSecurityConfig="@xml/network_security_config"`.
- [ ] A release build (`flutter build apk --release`) connects successfully to
  an HTTPS backend and produces no cleartext-traffic warnings in logcat.

---

## P9-08: Replace `debugPrint` with Release-Safe Logging
**Platform:** Mobile  
**Severity:** MEDIUM  
**Description:**  
`debugPrint` in Flutter does not suppress output in release builds — it calls
`print` which writes to logcat (Android) and the system log (iOS). Crash
reporting tools (Sentry, Crashlytics) often capture log output and transmit it
to third-party servers. Several log sites emit potentially sensitive values:
`DioException` stringification can include response bodies containing tokens;
`auth_repository.dart` logs full error objects; `auth_interceptor.dart` logs
during token refresh.

**References:**
- `mobile/lib/repositories/auth_repository.dart`
- `mobile/lib/network/auth_interceptor.dart`
- `mobile/lib/viewmodels/auth_viewmodel.dart`
- `mobile/lib/main.dart`

**Revises:**
- All files listed above

**Acceptance Criteria:**
- [ ] All `debugPrint` calls that may include auth tokens, user data, or
  exception bodies containing response payloads are wrapped in `kDebugMode`
  guards:
  ```dart
  if (kDebugMode) {
    debugPrint('[AuthRepository] login error: $e');
  }
  ```
- [ ] Non-sensitive structural logs (e.g. `[Dio] baseUrl: $baseUrl`,
  `FCM permission: ...`) may remain as `debugPrint` since they contain no
  PII or credential material.
- [ ] Verified in a release build: `flutter run --release` produces no auth or
  token-related output in the device log.

---

## P9-09: Gate Hangfire Dashboard Behind Auth in All Environments
**Platform:** Backend  
**Severity:** HIGH  
**Description:**  
The Hangfire dashboard is exposed at `/hangfire` with
`Authorization = []` (no auth) even in development. If the dev environment is
ever port-forwarded, shared, or deployed to a staging server, the dashboard
is accessible to anyone, exposing all background job arguments (user IDs,
emails, payment references, job IDs) and allowing manual re-queue of any job.

**References:**
- `Program.cs` — Hangfire dashboard registration

**Revises:**
- `Program.cs`

**Acceptance Criteria:**
- [x] A `HangfireDashboardAuthorizationFilter` is implemented:
  ```csharp
  public class HangfireDashboardAuthorizationFilter : IDashboardAuthorizationFilter
  {
      public bool Authorize(DashboardContext context)
      {
          var httpContext = context.GetHttpContext();
          return httpContext.User.Identity?.IsAuthenticated == true
              && httpContext.User.IsInRole("Superadmin");
      }
  }
  ```
- [x] Dashboard registered with the filter in all environments (remove the
  `IsDevelopment()` scope restriction):
  ```csharp
  app.UseHangfireDashboard("/hangfire", new DashboardOptions
  {
      Authorization = [new HangfireDashboardAuthorizationFilter()]
  });
  ```
- [x] An unauthenticated `GET /hangfire` returns a redirect or 401, not the
  dashboard HTML.
- [x] A Superadmin-authenticated session can access `/hangfire` normally.

---

## P9-10: Replace Web Admin localStorage with httpOnly Cookie Auth
**Platform:** Web + Backend  
**Severity:** HIGH  
**Description:**  
The web admin stores JWTs in `localStorage` (`AdminLogin.tsx`, `App.tsx`,
`api.ts`). Any XSS in the admin — a single unsanitized user-controlled string
in any table cell, modal, or rendered field — allows a script to exfiltrate the
admin JWT via `localStorage.getItem('jwt_token')`. Worse, an attacker with XSS
can silently trigger a new login flow in a hidden iframe and obtain a fresh
token even if the original has expired.

RFC 10017 (OAuth 2.0 for Browser-Based Applications, published August 2026 as
BCP) classifies admin dashboards as sensitive applications and states that
browser-only token storage is not recommended for them. The recommended
pattern is `httpOnly` cookies so the browser never holds tokens in
JavaScript-accessible storage.

This stack does not need a separate BFF service. ASP.NET Core cookie auth is
used as the session layer for the web admin only. The JWT Bearer scheme is
kept intact for the mobile app and SignalR — no mobile changes required.

**Architecture:**
```
React admin  ──(credentials)──▶  POST /api/auth/admin-login
                                      │ sets __Host-fixo-admin cookie (httpOnly, Secure, SameSite=Strict)
                                      │ no token in response body
React admin  ──(withCredentials)──▶  all /api/admin/* requests (cookie sent automatically)
                                      │ validated by "AdminCookie" auth scheme
Mobile app   ──(Bearer <jwt>)──▶  all /api/* requests (unchanged)
```

**References:**
- `backend/Program.cs` — auth schemes, cookie options, CORS
- `backend/Controllers/AuthController.cs` — new admin-login endpoint
- `web/src/features/auth/AdminLogin.tsx`
- `web/src/App.tsx`
- `web/src/services/api.ts`

**Revises:**
- `backend/Program.cs`
- `backend/Controllers/AuthController.cs`
- `web/src/features/auth/AdminLogin.tsx`
- `web/src/App.tsx`
- `web/src/services/api.ts`

**Acceptance Criteria:**

*Backend:*
- [x] A second auth scheme `"AdminCookie"` registered in `Program.cs`:
  ```csharp
  .AddCookie("AdminCookie", options =>
  {
      options.Cookie.Name        = "__Host-fixo-admin";
      options.Cookie.HttpOnly    = true;
      options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
      options.Cookie.SameSite    = SameSiteMode.Strict;
      // No Domain attribute — __Host- prefix enforces this
      options.ExpireTimeSpan     = TimeSpan.FromHours(8);
      options.SlidingExpiration  = true;
      options.Events.OnRedirectToLogin = ctx =>
      {
          ctx.Response.StatusCode = 401;
          return Task.CompletedTask;
      };
  });
  ```
- [x] `RequireStaffRole` and `RequireSuperadminRole` policies updated to accept
  `"AdminCookie"` scheme:
  ```csharp
  options.AddPolicy("RequireStaffRole", policy => policy
      .AddAuthenticationSchemes("AdminCookie")
      .RequireRole("Staff", "Superadmin"));
  ```
- [x] New endpoint `POST /api/auth/admin-login` (Staff/Superadmin only):
  validates email + password identically to the existing `/api/auth/login`,
  checks `EmailVerified`, checks `IsActive`, checks role is `Staff` or
  `Superadmin` (returns 403 otherwise — homeowners and tradies cannot use this
  endpoint), then calls `HttpContext.SignInAsync("AdminCookie", principal)`.
  Returns `200 OK` with `{ "name": "...", "role": "..." }` — **no token in the
  body**.
- [x] New endpoint `POST /api/auth/admin-logout`: calls
  `HttpContext.SignOutAsync("AdminCookie")`, returns 200.
- [x] New endpoint `GET /api/auth/admin-me`: protected by `RequireStaffRole`,
  returns `{ "name": "...", "role": "..." }`. Used by the React app to check
  session validity on page load — 200 means active session, 401 means redirect
  to login.
- [x] CORS policy in `Program.cs` updated to allow credentials for admin origins:
  ```csharp
  policy.WithOrigins(corsOrigins)
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials();   // required for cookies cross-origin in dev
  ```
- [x] CSRF: the `SameSite=Strict` cookie plus requiring a custom
  `X-Requested-With: XMLHttpRequest` header (Axios sets this by default) is
  sufficient for same-origin production. Document this explicitly — no
  additional anti-forgery token needed for strict same-site.
- [x] Content-Security-Policy response header added for all admin origin
  responses:
  ```
  default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';
  img-src 'self' blob: data:; connect-src 'self' wss:;
  ```

*Web:*
- [x] `api.ts` updated: remove the request interceptor that reads
  `localStorage.getItem('jwt_token')`. Add `withCredentials: true` to the
  Axios instance so the cookie is sent automatically on every request.
- [x] `AdminLogin.tsx` updated: POST to `/auth/admin-login` instead of
  `/auth/login`. On success store only the display name/role from the response
  body (e.g. in React state or a lightweight context) — no tokens written to
  `localStorage`.
- [x] `App.tsx` updated: `isAdminAuthenticated()` replaced by a call to
  `GET /api/auth/admin-me`. The `RequireAdmin` guard calls this on mount;
  401 redirects to `/login`.
- [x] All `localStorage.setItem/getItem/removeItem` calls for `jwt_token` and
  `refresh_token` removed from web admin code.
- [x] Logout calls `POST /api/auth/admin-logout` then redirects to `/login`.
- [x] SignalR `HubConnectionBuilder` in the web client includes
  `{ withCredentials: true }` so the cookie auth covers hub connections.
- [x] Audit `web/src/` for `dangerouslySetInnerHTML` — document any found
  instances and confirm each sanitizes its input (DOMPurify or equivalent).
- [x] Mobile `AuthInterceptor`, `AuthRepository`, and all mobile auth flows are
  unchanged — they continue using JWT Bearer headers.

---

## P9-11: Document and Comment FCM Routing Safety Constraint
**Platform:** Mobile  
**Severity:** LOW (preventive)  
**Description:**  
`main.dart`'s `_routeFromMessage()` reads `message.data['type']` and navigates
to static routes. The data payload in an FCM push is not cryptographically
authenticated at the app layer — anyone with the device's FCM token can
craft a message with an arbitrary `type` value. Currently the only reachable
routes are `/messages` and `/jobs`, both of which require a valid JWT. This is
safe today but will silently become exploitable if the switch is extended to
pass payload values as route path parameters.

**References:**
- `mobile/lib/main.dart` — `_routeFromMessage`

**Revises:**
- `mobile/lib/main.dart`

**Acceptance Criteria:**
- [ ] A prominent security comment is added above `_routeFromMessage`:
  ```dart
  // SECURITY: Only navigate to static, authenticated routes from notification
  // data. Never interpolate notification payload values into path parameters —
  // the FCM data field is not authenticated and could be crafted by anyone
  // holding this device's FCM registration token.
  ```
- [ ] The `default:` case in the switch logs the unknown type in debug mode
  and routes to `/messages` rather than silently doing nothing (current
  behaviour is the same, but explicit is safer against future refactors).
- [ ] No payload string values are passed into `appRouter.go()` path segments.

---

## P9-12: Fix Queued-Request Handling in AuthInterceptor
**Platform:** Mobile  
**Severity:** LOW  
**Description:**  
When `_isRefreshing` is `true` and subsequent 401s arrive, their
`RequestOptions` are queued in `_queuedRequests`. If the refresh ultimately
fails, `_queuedRequests.clear()` discards them with no response — callers
await forever or stall. The correct behaviour is to reject each queued request
with the original error so Dio callers can handle it.

**References:**
- `mobile/lib/network/auth_interceptor.dart`

**Revises:**
- `mobile/lib/network/auth_interceptor.dart`

**Acceptance Criteria:**
- [ ] On refresh failure, queued requests are rejected rather than dropped:
  ```dart
  for (final req in _queuedRequests) {
    req['handler'].reject(err);
  }
  _queuedRequests.clear();
  ```
- [ ] On refresh success, queued requests are retried with the new token as
  before.
- [ ] A comment explains the queue exists to handle concurrent 401s during a
  single refresh window.

---

## P9-13: JWT Algorithm Hardening — Pin Algorithm, Reject alg:none
**Platform:** Backend  
**Severity:** HIGH  
**Description:**  
The current `TokenService` signs JWTs with `HmacSha256Signature` (HS256) using
a symmetric secret shared by both issuer and validator. RFC 8725 (JWT Best
Current Practices) and the OWASP JWT Cheat Sheet identify two active attack
classes this creates:

1. **alg:none bypass** — if the validator does not explicitly reject the
   `alg: none` header, an attacker strips the signature and the token is
   accepted unsigned. Older versions of `System.IdentityModel.Tokens.Jwt`
   were vulnerable; newer versions reject it by default, but the
   `ValidAlgorithms` allowlist in `TokenValidationParameters` makes this
   explicit and immune to library regressions.

2. **Algorithm confusion (HMAC ↔ RSA)** — if the validator accepts both HMAC
   and public-key algorithms, an attacker can take the server's RSA public key
   (which is public), sign a token with it as an HMAC-SHA256 key, and the
   validator accepts it as if it were issued by the server. Pinning
   `ValidAlgorithms` to one family closes this entirely.

3. **HS256 key quality and shareability** — a symmetric secret means any
   service that can validate tokens can also forge them. For a single-API
   deployment this is low risk today, but as the system grows (separate
   admin service, microservices, third-party integrations) the blast radius of
   a leaked key expands. OWASP recommends RS256/PS256/ES256 (asymmetric) so
   validators hold only public keys.

This task pins the current HS256 implementation defensively via
`ValidAlgorithms` and sets up the migration path to RS256/ES256.

**References:**
- `Services/TokenService.cs`
- `Program.cs` — `TokenValidationParameters`

**Revises:**
- `Program.cs`
- `Services/TokenService.cs`

**Acceptance Criteria:**
- [x] `TokenValidationParameters` in `Program.cs` adds an explicit algorithm
  allowlist that matches the signing algorithm in `TokenService`:
  ```csharp
  ValidAlgorithms = new[] { SecurityAlgorithms.HmacSha256 },
  ```
  This rejects `alg:none` and any algorithm not on the list, regardless of
  library default behaviour.
- [x] `TokenService.CreateToken` explicitly names `SecurityAlgorithms.HmacSha256`
  (already does — verify it does not use a string literal that could drift).
- [x] A comment in `Program.cs` near `ValidAlgorithms` documents the migration
  path to RS256/ES256: when a dedicated auth server is adopted (P9 future
  work), switch `IssuerSigningKey` to a `JsonWebKeySet` fetched from the
  issuer's `jwks_uri` and update `ValidAlgorithms` to `new[] { "RS256" }` or
  `new[] { "ES256" }`. No code change is required on clients.
- [x] `jwk`, `jku`, and `x5u` header injection: verified that
  `Microsoft.IdentityModel.Tokens` does not honour these headers by default
  in the current version. Add a comment confirming the version and the
  default behaviour so a future library upgrade is audited for this
  regression.

---

## P9-14: Mobile — Access Token in Memory, Refresh Token in Keystore/Keychain
**Platform:** Mobile  
**Severity:** HIGH  
**Description:**  
The current mobile auth flow persists both the JWT access token and the refresh
token to `flutter_secure_storage` (Android Keystore / iOS Keychain). RFC 8252
(OAuth 2.0 for Native Apps) and current AppAuth guidance recommend keeping the
short-lived access token in memory only, and persisting only the long-lived
refresh token to secure storage. This limits the blast radius of a Keystore
extraction attack: the attacker gets a refresh token (revocable, server-side)
but not an immediately usable access token.

Currently both tokens are written to storage on every login/refresh
(`_storeTokens` in `auth_repository.dart`), and the JWT is read from storage on
every request (`onRequest` in `auth_interceptor.dart`).

**References:**
- `mobile/lib/repositories/auth_repository.dart` — `_storeTokens`
- `mobile/lib/network/auth_interceptor.dart` — `onRequest`
- `mobile/lib/viewmodels/auth_viewmodel.dart`

**Revises:**
- `mobile/lib/repositories/auth_repository.dart`
- `mobile/lib/network/auth_interceptor.dart`
- `mobile/lib/viewmodels/auth_viewmodel.dart`

**Acceptance Criteria:**
- [ ] `AuthRepository` holds the current access token in a private in-memory
  field (`String? _accessToken`) rather than writing it to
  `flutter_secure_storage`.
- [ ] Only the refresh token is written to `flutter_secure_storage` on
  login/OTP-verify/refresh:
  ```dart
  Future<void> _storeTokens(Map<String, dynamic> data) async {
    _accessToken = data['token'] as String;           // memory only
    await _storage.write(
      key: 'refresh_token',
      value: data['refreshToken'] as String,          // persisted
    );
  }
  ```
- [ ] `AuthInterceptor.onRequest` reads the access token from the
  `AuthRepository` in-memory field rather than from storage. The Dio provider
  and `AuthInterceptor` constructor receive the `AuthRepository` reference (or
  a token-provider callback) for this.
- [ ] On cold start, `SplashScreen` detects a stored refresh token and calls
  `POST /api/auth/refresh` to obtain a fresh access token before routing —
  rather than trying to read a JWT from storage (which will be absent). If the
  refresh fails the user is sent to `/auth`.
- [ ] `AuthRepository.logout` clears `_accessToken = null` and deletes only the
  refresh token from storage.
- [ ] `AuthRepository.getAccessToken()` public method returns `_accessToken` —
  used by `AuthInterceptor` and any place that currently reads `jwt_token` from
  storage.
- [ ] A comment in `auth_repository.dart` explains the in-memory access token
  pattern and cites RFC 8252 Section 8.5.

---

## P9-15: JWT TokenValidationParameters Hardening
**Platform:** Backend  
**Severity:** MEDIUM  
**Description:**  
The current `TokenValidationParameters` in `Program.cs` validates issuer,
audience, lifetime, and signing key — the four core checks. Several additional
RFC 8725 and OWASP JWT Cheat Sheet parameters are missing that harden against
clock-skew abuse, unsigned tokens, and token-type confusion.

**References:**
- `Program.cs` — `TokenValidationParameters`

**Revises:**
- `Program.cs`

**Acceptance Criteria:**
- [x] `TokenValidationParameters` updated to include:
  ```csharp
  new TokenValidationParameters
  {
      ValidateIssuer           = true,
      ValidateAudience         = true,
      ValidateLifetime         = true,
      ValidateIssuerSigningKey = true,
      ValidIssuer              = jwtConfig["Issuer"],
      ValidAudience            = jwtConfig["Audience"],
      IssuerSigningKey         = new SymmetricSecurityKey(
                                     Encoding.UTF8.GetBytes(secret)),
      // RFC 8725: explicitly require a signature — rejects alg:none
      RequireSignedTokens      = true,
      // RFC 8725: require exp claim — tokens without exp are treated as eternal
      RequireExpirationTime    = true,
      // RFC 8725 / OWASP: reduce clock-skew window from the 5-minute default
      // to 30 seconds. This limits replay of just-expired tokens.
      ClockSkew                = TimeSpan.FromSeconds(30),
      // P9-13: algorithm allowlist — set after that task is merged
      ValidAlgorithms          = new[] { SecurityAlgorithms.HmacSha256 },
  }
  ```
- [x] The `ClockSkew` reduction from 5 minutes to 30 seconds is verified to not
  break the OTP verification flow (OTP codes have a 10-minute lifetime,
  unrelated to JWT clock skew).
- [x] `MapInboundClaims = false` added to the JWT Bearer options block to
  prevent the middleware from remapping standard JWT claim names (e.g.
  `sub` → `nameidentifier`) which can cause unexpected behaviour when reading
  claims directly:
  ```csharp
  options.MapInboundClaims = false;
  ```

---

## Summary: severity and dependency order

| Task | Severity | Unblocks |
|------|----------|----------|
| P9-01 Register role escalation | CRITICAL | — |
| P9-06 Real refresh tokens | CRITICAL | P9-12, P9-14 |
| P9-07 Android cleartext traffic | CRITICAL | — |
| P9-03 Login lockout | HIGH | — |
| P9-04 Externalize JWT secret | HIGH | P9-13 |
| P9-05 HTTPS metadata by env | HIGH | — |
| P9-09 Hangfire auth | HIGH | — |
| P9-10 Web httpOnly cookie auth | HIGH | — |
| P9-13 JWT algorithm pinning | HIGH | P9-15 |
| P9-14 Mobile token memory pattern | HIGH | P9-06 |
| P9-02 completeRegistration binding | MEDIUM | — |
| P9-08 Release-safe logging | MEDIUM | — |
| P9-15 TokenValidationParameters | MEDIUM | — |
| P9-11 FCM routing comment | LOW | — |
| P9-12 Interceptor queue reject | LOW | P9-06 |

**Suggested implementation order:**

Sprint 1 — single-file or near-single-file fixes (1–2 days):
P9-01 → P9-03 → P9-05 → P9-07 → P9-09 → P9-13 → P9-15

Sprint 2 — cross-platform and structural changes (3–5 days):
P9-04 (secret rotation + secrets store) → P9-10 (cookie auth, new endpoints,
web client update) → P9-14 (mobile token memory pattern, requires P9-06
refresh stub to be real)

Sprint 3 — P9-06 (real refresh tokens, largest task) + P9-02 (registration
token binding) + remaining low items (P9-08, P9-11, P9-12)

