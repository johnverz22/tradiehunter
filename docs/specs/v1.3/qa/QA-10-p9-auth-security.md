# QA-10 — P9 Auth & security hardening

Spec: `../../v1.2/P9-auth-security-hardening.md`. Inherited from v1.2.

**v1.3 note:** P9-10 (web httpOnly cookie auth) is now RESOLVED in v1.3 —
the admin dashboard moved to `AdminCookie`/`admin-me` pattern. Update the
open-item table accordingly.

Split into IMPLEMENTED (must be green before prod) and OPEN (confirm still
open, track owner + date).

## Implemented — verify

- [ ] **P9-01 — No self-assign Staff/Superadmin [CRITICAL]**
  1. `POST /api/auth/register` with `"role": 2`, then `"role": 3`.
  Expected: both 400 (`Role must be Homeowner or Tradie`); Staff/Superadmin
  only via staff-invite (`RequireSuperadminRole`).

- [ ] **P9-02 — complete-registration bound to token [MEDIUM]**
  1. Google SSO new user → note `RequiresRegistration` response.
  2. `PATCH /api/auth/complete-registration?userId=` with no token, expired
     token, then valid token twice.
  Expected: response includes 10-min one-time `registrationToken` (hash
  stored); missing/expired/replayed → 400; mobile `RoleSelectScreen` passes
  the token through.

- [ ] **P9-03 — Login lockout 5-in-5 [HIGH]**
  1. 5 bad passwords, then the correct one; 6th attempt.
  Expected: `lockoutOnFailure: true`; after 5 fails → 429
  (`Account temporarily locked…`) for 5 min; seed/demo accounts unaffected.

- [ ] **P9-04 — JWT secret externalised [HIGH]**
  1. Inspect `appsettings.json` + `appsettings.Development.json`.
  2. Boot api without `Jwt__Secret`.
  Expected: files hold empty/placeholder secrets; real 64-byte value via
  env/user-secrets; missing secret → fail-fast with clear message; Google
  Client ID likewise uncommitted; `STARTER_GUIDE.md` documents user-secrets.

- [ ] **P9-05 — HTTPS metadata by env [HIGH]**
  1. Inspect JWT Bearer options; run dev vs prod profile.
  Expected: `RequireHttpsMetadata = !IsDevelopment()` — no manual prod step.

- [ ] **P9-07 — Android cleartext scoped [CRITICAL, partial]**
  1. Inspect `AndroidManifest.xml` + main/debug `network_security_config.xml`.
  Expected: main manifest has NO global `usesCleartextTraffic="true"`;
  main config denies cleartext; debug allows only `10.0.2.2`/`localhost`;
  both manifests reference the config. Release-build HTTPS assertion
  (`flutter build apk --release` + logcat, no cleartext warnings) is STILL
  UNVERIFIED — do it before prod.

- [ ] **P9-09 — Hangfire behind Superadmin auth [HIGH]**
  1. `GET /hangfire` unauthenticated, as Homeowner/Staff, as Superadmin.
  Expected: unauth → 401/redirect (never dashboard HTML); Staff denied;
  Superadmin allowed — in ALL environments, not dev-only.

- [ ] **P9-10 — Web httpOnly cookie auth [HIGH] (v1.3 resolved)**
  1. Inspect admin login flow: POST /api/auth/admin-login.
  2. Check response: `__Host-fixo-admin` cookie set with `HttpOnly`,
     `SameSite=Strict`; no `localStorage` JWT write.
  3. `GET /api/auth/admin-me` — confirm cookie-only auth, no Bearer header.
  Expected (v1.3): httpOnly cookie in use; `withCredentials` on all admin API
  calls; no XSS-exfiltratable JWT in browser storage. If still localStorage,
  treat as regression.

- [ ] **P9-13 — JWT algorithm pinned HS256 [HIGH]**
  1. Inspect `TokenValidationParameters` + `TokenService.CreateToken`.
  Expected: `ValidAlgorithms = [HmacSha256]`, explicit HS256 signing;
  comments cover RS256/ES256-via-JWKS migration + `jwk/jku/x5u`
  non-honouring for the current lib version.

- [ ] **P9-15 — TokenValidation hardening [MEDIUM]**
  1. Inspect parameters.
  Expected: `RequireSignedTokens=true`, `RequireExpirationTime=true`,
  `ClockSkew=30s` (OTP 10-min flow unaffected), `MapInboundClaims=false`.

## Open — confirm still open (do NOT mark pass)

- [ ] **P9-06 — Real refresh rotation [CRITICAL, OPEN]**
  Confirm: `/refresh` still returns stub tokens; no `RefreshTokens` table;
  stolen refresh = eternal; mobile drops to `/auth` after ~60 min.
  Owner: ___ Date: ___

- [ ] **P9-08 — Release-safe logging [MEDIUM, OPEN]**
  Confirm: token/user-data/exception-body `debugPrint` NOT `kDebugMode`-guarded.
  `flutter run --release` may leak auth material. Owner: ___ Date: ___

- [ ] **P9-11 — FCM routing comment [LOW, OPEN]**
  Confirm: no SECURITY comment above `_routeFromMessage`; `default:`
  behaviour undocumented. Owner: ___ Date: ___

- [ ] **P9-12 — Interceptor queue reject [LOW, OPEN, blocked on P9-06]**
  Confirm: queued 401s are `.clear()`ed, never `handler.reject(err)`.
  Owner: ___ Date: ___

- [ ] **P9-14 — Token-in-memory pattern [HIGH, OPEN, blocked on P9-06]**
  Confirm: both tokens still in `flutter_secure_storage`; cold start reads
  JWT from storage instead of refreshing. Owner: ___ Date: ___

- [ ] **P9-REL — Release-build security sweep**
  Priority: BLOCKER · Precon: release backend + `flutter build apk --release`
  1. HTTPS-only traffic (no logcat cleartext warnings).
  2. `flutter run --release` shows no auth/token output in device log.
  Expected: both clean. (Covers the unverified halves of P9-07/P9-08.)
