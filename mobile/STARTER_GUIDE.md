# Mobile starter guide (Flutter)

Run these yourself — not pre-generated.

```bash
cd mobile
flutter create --org nz.co.fixo app
cd app

# Core packages
flutter pub add signalr_netcore
flutter pub add dio               # REST client
flutter pub add flutter_riverpod  # or your preferred state management
flutter pub add go_router         # role-based routing
```

## Suggested project split (once scaffolded)
```
app/lib/
├── features/
│   ├── homeowner/     # Post a Job, Matches/Requests, Chat + Status, Profile
│   ├── tradie/        # Incoming Requests, Dashboard, Profile
│   └── auth/          # Login/register, role detection from JWT
├── core/
│   ├── api_client.dart    # Dio client against the .NET REST API
│   └── signalr_client.dart # Shared SignalR connection
├── theme/             # Port design-system.html tokens (colors, type scale, spacing)
└── main.dart          # go_router setup, role-based redirect post-auth
```

## First things to wire up
1. Auth flow against the same .NET Identity/JWT endpoints as the web app; decode the role claim to route into homeowner or tradie views.
2. One shared SignalR client for chat, job-status, and match notifications — mirror the web app's single-connection approach.
3. Push notifications (FCM/APNs) for job-status changes and reminders, since the app won't always be foregrounded.
4. Port the design tokens from `../docs/design/design-system.html` into a Flutter `ThemeData`/color scheme before building screens.

Read `../docs/MVP-SPEC.md` for the screen list and `../docs/ARCHITECTURE.md` for the API/hub contracts.

## Environment variables (dart-define)

Flutter apps can't read `.env` files at runtime, but secrets can be injected at **build / run time** using
`--dart-define-from-file`.

1. Copy the template and fill in your values:
   ```bash
   cp mobile/.env.json.example mobile/.env.json
   # edit .env.json — never commit it (.gitignore already excludes it)
   ```

2. Pass the file on every run or build:
   ```bash
   # dev
   flutter run --dart-define-from-file=.env.json

   # release build
   flutter build apk --dart-define-from-file=.env.json
   flutter build ipa --dart-define-from-file=.env.json
   ```

3. In code, read values with:
   ```dart
   const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
   ```

4. VS Code: add to `.vscode/launch.json`:
   ```json
   {
     "configurations": [{
       "name": "Fixo (dev)",
       "request": "launch",
       "type": "dart",
       "toolArgs": ["--dart-define-from-file=.env.json"]
     }]
   }
   ```

   Android Studio / IntelliJ: Run > Edit Configurations > Additional run args:
   `--dart-define-from-file=.env.json`

Currently defined keys (see `.env.json.example`):

| Key | Used in | Description |
|-----|---------|-------------|
| `GOOGLE_CLIENT_ID` | `auth_repository.dart`, `main.dart` | Web OAuth client ID — must match `Authentication:Google:ClientId` on the backend |
| `API_BASE_URL` | `auth_viewmodel.dart` (Dio baseUrl) | Backend URL. Android emulator: `http://10.0.2.2:5000`. iOS simulator / macOS: `http://localhost:5000`. Physical device: `http://<LAN-IP>:5000` |
