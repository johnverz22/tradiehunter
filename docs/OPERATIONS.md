# TradieHunter — Operations

Runbooks for email delivery and Firebase/Google sign-in. Secrets never go in the repo: `.env`, `appsettings.Development.json` and `backend/firebase-service-account.json` stay gitignored.

## 1. Email

### What the code does
| Concern | Behaviour |
|---|---|
| Rendering | RazorLight compiles embedded `.cshtml` templates (`backend/Email/Templates/`, one layout + 4 partials, 8 email types) to HTML, with a plain-text twin composed from the same model |
| Transport | MailKit SMTP, TLS from config, `multipart/alternative` with the text part first |
| Senders | OTP and staff invite → `security@` (no Reply-To); payment/refund → `billing@`; everything else → `hello@` (Reply-To `support@`). One domain |
| Feature flag | `EmailSender:UseTemplates` (false in base config, true in dev canary); remove after the production flip |
| Sandbox | `EmailSender:SandboxMode=true` prefixes subjects with `[SANDBOX]` |
| Bounces | Permanent (5xx) failures set `ApplicationUser.EmailBouncedAtUtc` and later sends are skipped; `EmailBounceReportJob` logs bounces + per-template counters Mondays 06:00 UTC |
| Preview | Staff-only `GET /api/admin/email-preview/{template}` (`?frontend=true` CTA variant, `?text=true` plain-text twin) |
| Deep links | CTAs are built from `Brand:FrontendBaseUrl`; empty (default) omits every CTA |
| Formatting | Deadlines in Pacific/Auckland via `NzTime`; money via invariant `Money.Format` |
| Invite tokens | 24 h lifetime, matching the email copy |

### Configuration (`EmailSender` section)
| Key | Dev | Production |
|---|---|---|
| `Host` / `Port` | `mailhog` / `1025` | relay host |
| `Username` / `Password` | empty | relay credentials |
| `TlsMode` | `None` | `StartTls` |
| `SandboxMode` | `true` | `false` |
| `UseTemplates` | `true` | `true` after the client matrix passes |
| `MailDomain`, `BounceAddress` | `tradiehunter.nz`, `bounces@…` | authenticated domain; relay Return-Path |

### Going live (open items)
1. Choose a relay. Recommendation: Amazon SES `ap-southeast-2` (no NZ region) or Postmark. The code is provider-agnostic SMTP.
2. DNS: SPF including the relay, 2048-bit DKIM, DMARC at `p=none` for two weeks (watch `rua=`), then `p=quarantine`; Return-Path set to the bounce address.
3. ~~Host the header logo on the CDN~~ — no longer needed: the v2 header renders a text wordmark (Lexend, white + hero-gold accent). `Brand:EmailLogoUrl` is deprecated.
4. Set `Brand:FrontendBaseUrl` once deep links resolve; supply the registered office in `Brand:PostalAddress`.
5. Manual client matrix before the flip: Gmail (web/iOS/Android), Outlook 2016 + web, Apple Mail (light/dark), Yahoo.
6. Confirm the sending domain (`tradiehunter.nz` vs `.co.nz` in older config samples).

### Tests
`dotnet test backend/FixoApi.Tests` runs renderer tests for all 8 templates, copy invariants (subjects, currency, NZT deadlines, text twin, preheaders) and golden snapshots under `Goldens/email/` (regenerate with the `UPDATE_` env var documented in the test). Metrics are in-memory counters (`IEmailMetrics`); expose them via a `/metrics` endpoint when infra adds one.

## 2. Firebase and Google sign-in

Project `fixo-dev-75df4`; Flutter package / bundle ID `nz.co.fixo.fixo` (identifiers intentionally unchanged by the rebrand).

1. **Firebase / Google Cloud:** enable Identity Toolkit API and Cloud Messaging API (V1); OAuth consent screen (External, scopes `email profile openid`, test users).
2. **Mobile apps:** register Android (with debug SHA-1) and iOS apps **in Firebase**, not manual Cloud Console clients. Manually created Android/iOS OAuth clients cause `ApiException: 10`; delete them and keep the Firebase-managed one.
3. **Web OAuth client** (manual): used by `POST /api/auth/google` to validate the `idToken` audience; authorised JS origin `http://localhost:3000`, redirect `http://localhost:5000/signin-google` for dev.
4. **Service account:** generate a private key, save as `backend/firebase-service-account.json` (container path `/app/...`), never commit; set `FIREBASE_PROJECT_ID` and `GOOGLE_APPLICATION_CREDENTIALS`.
5. **FlutterFire:** `flutterfire configure --project=fixo-dev` generates `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`.
6. **iOS push:** Xcode → Signing & Capabilities → Push Notifications + Background Modes (Remote notifications); real-device push needs an APNs `.p8` key uploaded to Firebase (paid Apple Developer Program). Android works without it.
7. **Verify:** `POST /api/auth/google` with a real `idToken` → 200 + JWT; Flutter Google login stores the token and registers an FCM token (`POST /api/profile/device-token`); a Firebase test message reaches a backgrounded Android device.

Checks worth re-confirming in code (the old guide listed them as to-do while the features ship): `GoogleSignIn` uses the web `serverClientId`; iOS `Info.plist` has the `REVERSED_CLIENT_ID` URL scheme; Google token validation sets the audience, requires `EmailVerified` and rejects inactive users.
