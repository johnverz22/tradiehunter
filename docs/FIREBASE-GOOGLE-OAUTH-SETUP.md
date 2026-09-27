# Fixo — Firebase & Google OAuth Setup Guide

Development brand: **Fixo** (white-label ready). Stack: .NET 10 API + Flutter (single app, role-based) + React admin.
Auth: ASP.NET Identity + Google OAuth, JWT for clients. Push: Firebase Cloud Messaging via Firebase Admin SDK.
See `docs/ARCHITECTURE.md`, `docs/MVP-SPEC.md`.

Firebase project: `fixo-dev-75df4` (display `fixo-dev`).
Flutter package / Bundle ID: `nz.co.fixo.fixo`.

---

## 1. Manual console steps (done)

### 1.1 Firebase project
1. `console.firebase.google.com` → project `fixo-dev` exists.
2. `console.cloud.google.com` → `APIs & Services > Library`: enabled `Identity Toolkit API` + `Cloud Messaging API (V1)`.
3. `APIs & Services > OAuth consent screen`: External, app `Fixo`, scopes `email profile openid`, test users added.

### 1.2 Mobile apps (do in Firebase, NOT manual Cloud Console clients)
- Android `nz.co.fixo.fixo` + debug SHA-1 from:
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
  ```
  Added under Firebase `Project Settings > Android app > Fingerprints`. Firebase auto-creates the
  `Android client (auto created by Google Service)` OAuth client — leave it alone.
- iOS Bundle ID `nz.co.fixo.fixo` registered in Firebase. Do NOT create a manual iOS OAuth client.
- If you manually created an Android/iOS OAuth client in Cloud Console, delete the duplicate and keep
  the Firebase-managed one, otherwise Sign-In fails with `ApiException: 10`.

### 1.3 Web OAuth client (manual — still required)
`Cloud Console > Credentials > Create Credentials > OAuth client ID > Web application` (`fixo-api-dev`):
- Used by backend `POST /api/auth/google` to validate `idToken` audience.
- Authorized redirect: `http://localhost:5000/signin-google` (dev).
- Authorized JS origin for React admin: `http://localhost:3000`.
- Copy `ClientId` (+ `ClientSecret` if using code flow) into backend config (see §2.2).

### 1.4 Service account (backend FCM send)
Firebase `Project Settings > Service accounts > Generate new private key` → rename to
`backend/firebase-service-account.json`. Never commit. Host path `backend/...`, in-container path
`/app/...` (`WORKDIR /app`, compose mounts `./backend:/app`).

### 1.5 FlutterFire (done on host — Flutter runs on host, not in Docker)
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=fixo-dev
```
Generated: `mobile/lib/firebase_options.dart`, `mobile/android/app/google-services.json`,
`mobile/ios/Runner/GoogleService-Info.plist`.

### 1.6 iOS push capabilities (Xcode)
`open mobile/ios/Runner.xcworkspace` → `Runner` target → `Signing & Capabilities`:
- `+ Push Notifications` (creates `aps-environment` entitlement).
- `+ Background Modes` → tick `Remote notifications`.
- Real-device push needs APNs .p8 (`developer.apple.com > Keys`) uploaded to
  Firebase `Project Settings > Cloud Messaging`. Requires paid Apple Developer Program (US$99/yr).
  Without it: Android E2E works free; iOS only foreground `onMessage` in simulator.

---

## 2. Code steps yet to do

### Backend — all `dotnet` runs inside the API container (`dotnet` is NOT on host)

- [ ] **2.1 Init FirebaseApp in `backend/Program.cs`.** `FixoApi.csproj` already has
  `FirebaseAdmin 3.7.0` + `Google.Apis.Auth 1.76.0`, but `Program.cs` never calls
  `FirebaseApp.Create()`. Add init from `GOOGLE_APPLICATION_CREDENTIALS` /
  `FIREBASE_PROJECT_ID` + register a singleton FCM sender (e.g. `PushNotificationService`
  wrapping `FirebaseMessaging.DefaultInstance.SendAsync()`).
- [ ] **2.2 Config — `backend/appsettings.json` + `appsettings.Development.json`.** Add:
  ```json
  { "Authentication": { "Google": { "ClientId": "<WEB-client-id>.apps.googleusercontent.com" } },
    "Firebase": { "ProjectId": "fixo-dev-75df4" } }
  ```
  `Program.cs`/`AuthController.cs` currently have no `Authentication:Google` key to validate against.
- [ ] **2.3 Audience check in `backend/Controllers/AuthController.cs:111`.**
  `GoogleJsonWebSignature.ValidateAsync(idToken, new ValidationSettings())` has empty settings —
  set `Audience = new[]{ config["Authentication:Google:ClientId"] }`, check `payload.EmailVerified`,
  and reject `!user.IsActive` like password login does.
- [ ] **2.4 Wire compose + env.** `.env`: `FIREBASE_PROJECT_ID`, service-account path.
  `docker-compose.yml` `api.environment`: `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS: /app/firebase-service-account.json`.
  `volumes:` host→container mapping (`./backend/...:/app/...`). The whole `./backend:/app` mount
  already covers dev; the explicit `:ro` file mount is optional/explicitness.
- [ ] **2.5 Gitignore the secret.** `.gitignore` ignores `.env` but NOT the service-account JSON —
  add `backend/firebase-service-account.json`.
- [ ] **2.6 Apply migration.** `Migrations/20260927013935_AddDeviceTokens` exists (entity
  `Models/DeviceTokenEntity.cs` + `POST /api/profile/device-token` in `Controllers/ProfileController.cs:67`
  exist) but may not be applied: `docker compose run --rm --entrypoint /bin/bash api -c "dotnet ef database update"`.
- [ ] **2.7 Actually send push.** Nothing calls FCM yet — wire `PushNotificationService` into
  match-accept/decline, job-status transitions (must go via SignalR hub per `AGENTS.md`), reviews,
  and Hangfire reminders.

### Mobile (`mobile/`)

- [ ] **2.8 iOS URL scheme.** `ios/Runner/Info.plist` has no `REVERSED_CLIENT_ID` scheme —
  Google Sign-In redirect on iOS will fail. Copy `REVERSED_CLIENT_ID` from
  `ios/Runner/GoogleService-Info.plist` into `Info.plist > CFBundleURLTypes`.
- [ ] **2.9 `serverClientId`.** `lib/repositories/auth_repository.dart:11`
  `GoogleSignIn(scopes: ['email'])` needs `serverClientId: "<WEB-client-id>"` so the returned
  `idToken` audience matches what the backend validates (required on iOS, recommended Android).
- [ ] **2.10 FCM lifecycle in `lib/main.dart`.** `Firebase.initializeApp` + `requestPermission`
  exist, but the token is only `print`ed. Add: top-level `onBackgroundMessage` handler +
  `FirebaseMessaging.onBackgroundMessage(...)`, `onTokenRefresh` → `POST /api/profile/device-token`
  `{token, platform}`, and foreground `onMessage` listener (route to SignalR chat/status screen).
  Call the register endpoint after every login/registration (JWT in header).
- [ ] **2.11 Test on Android first** (SHA-1 debug registered, free). iOS background push waits on the
  paid APNs key (§1.6).

### Web (React admin)

- [ ] **2.12 Admin Google button** → same Web OAuth client (§1.3) → `POST /api/auth/google`,
  gate on `Admin` role (`[Authorize(Roles="Admin")]` endpoints).

### Verify
1. `docker compose up -d --build api` + `POST /api/auth/google` with a real `idToken` → 200 + Fixo JWT.
2. Flutter Google login → JWT in `flutter_secure_storage` + FCM token in `DeviceTokens` table.
3. Firebase `Messaging > Send test message` to that token → notification on backgrounded Android device.
