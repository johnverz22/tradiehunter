# Mobile Rules (Flutter)

Rules and architectural conventions for the Fixo Flutter application.

## Architectural Pattern: Strict MVVM

All mobile client code must strictly adhere to the Model-View-ViewModel (MVVM) architecture with strict Separation of Concerns (SoC).

| Layer | Responsibility | Allowed Dependencies | Prohibitions |
| :--- | :--- | :--- | :--- |
| **Models** | Pure data classes, JSON serialization/deserialization, immutable value objects. | Foundation libraries, JSON serialization helpers (e.g., `freezed`, `json_serializable`). | **NO** business logic, UI code, network access, or repository references. |
| **Repositories** | Data abstraction layer managing REST API (`Dio`/`http`), SignalR real-time client, Firebase Cloud Messaging (FCM), and local secure storage. Exposes clean domain streams and future-based methods. | Models, network clients, storage drivers, SignalR/FCM SDKs. | **NO** UI logic, `BuildContext`, or widget state management. |
| **ViewModels** | Encapsulates screen state, presentation logic, and business workflows. Coordinates with Repositories. Recommended: Riverpod (`AsyncNotifier` / `NotifierProvider`) or standard `ChangeNotifier`/`Provider`. | Repositories, Domain Models, State utilities. | **NO** `BuildContext`, UI widgets, `dart:ui` imports, or direct HTTP/SignalR transport calls. |
| **Views (UI)** | Dumb presentation widgets. Listens to ViewModel state and triggers ViewModel actions via callbacks. Maps design system tokens to atomic UI elements. | ViewModels (as state listeners/dispatchers), Design System tokens/widgets. | **NO** direct API/network calls, NO SignalR hub subscriptions, NO database/storage access, NO domain validation or business logic. |

## Separation of Concerns (SoC) Guidelines

1. **Dumb Views**:
   - Views consume ViewModel state and render widgets accordingly.
   - User interactions (button taps, form submissions) strictly delegate to ViewModel methods.
   - Reusable UI elements (buttons, inputs, cards, status badges) must be built as standalone stateless widgets.
2. **ViewModel Abstraction**:
   - ViewModels expose immutable UI state objects (e.g., `AsyncValue<JobDetailsState>`).
   - All network, real-time events, and storage access must be injected via abstract Repository interfaces.
   - ViewModels are fully unit-testable without Flutter UI bindings.
3. **Repository Encapsulation**:
   - Encapsulates authentication headers, token refresh flows, local caching, and socket reconnects.
   - Normalizes remote DTOs into pure domain Models before emitting to ViewModels.

## Design System & Branding

- **Audit-driven UI**: Follow `docs/specs/v1.5/specification.md`, its component contract, implementation plan and tasks. Use `docs/design/design-system.html` for tokens. Existing mockups are excluded from inputs, deliverables and acceptance: do not match, update or replace them. Improve consistency, hierarchy, readability and accessibility against the audit, not legacy geometry.
- **Functional preservation**: Preserve hourly pricing, manual bank-transfer review, disputes, booking transitions, permissions, role views, existing routes/callbacks, shared ViewModels/repositories, Decimal money, UTC timestamps and SignalR synchronization. Never fabricate identity, ratings, badges, metrics, distances, contact or financial data. Unapproved provider/data/functional decisions remain gated.
- **Semantic components**: Use semantic card/control/input/tile/sheet radii (20/14/14/16/28), growing 56px primary and 52px secondary minimums, and at least 48px action targets. The legacy 4px radius is compatibility-only. Helpers use regular body type; monospace is reserved for reference codes. Flat operational headers; preserve splash gradient.
- **Token Usage**:
  - Dev brand is "Fixo" with primary hue `--hue: 209`.
  - Brand colors, secondary tones, surface neutrals, typography scale, border radii, and spacing tokens must be defined in `mobile/lib/theme/design_tokens.dart` and used via a centralized `ThemeData` / design token class.
  - Never hardcode raw hex values in individual view files.
  - **No-hardcoded-values rule** (enforced — see `mobile/HARDCODED_AUDIT.md`):
    - **Spacing/padding**: Use `Space.s1`…`Space.s8`, `Space.gutter`, `FixoPadding.page`/`.card`/`.section`. Never raw numbers in `EdgeInsets` or `SizedBox` spacers.
    - **Border radius**: Use `Radii.card`, `Radii.control`, `Radii.tile`, `Radii.sheet`, `Radii.pill`, `Radii.micro`, `Radii.small`, `Radii.medium`. Never `BorderRadius.circular(N)` with a raw number.
    - **Font sizes**: Use `DesignTokens.fontSize*` (Display, H1, H2, H3, Body, Secondary, Caption, Status, Control, Mono, Amount). Never `fontSize: N` raw.
    - **Font weights**: Use `FW.regular`/`.medium`/`.semibold`/`.bold`/`.extrabold`. Never `FontWeight.wXXX` inline.
    - **Colors**: Use `THColors` via `Theme.of(context).extension<THColors>()!` or `DesignTokens.*` statics. Never `Color(0x...)` in view/widget files (exception: `design_tokens.dart` itself). Never `Colors.white`/`Colors.red` etc. directly — use `THColors.surface`/`.danger` etc. (`Colors.transparent` is acceptable for overlays).
    - **Alpha/opacity**: Use `Alpha.tint`/`.tintAccent`/`.border`/`.textOnGradient`/`.navBar` etc. Never `.withValues(alpha: 0.12)` with a raw number.
    - **Durations**: Use `Durations.fast`/`.medium`/`.slow`. Never `Duration(milliseconds: N)` with a raw number for animations/transitions.
    - **Letter spacing**: Use `Tracking.tight` (× fontSize), `Tracking.wide`/`.wider`/`.widest`. Never `letterSpacing: N` raw.
    - **Shadows**: Use `THColors.cardShadow`/`.ctaShadow` or theme-defined shadow variants. Never inline `BoxShadow(...)`.
    - **Component sizes**: Use `Sizes.button`/`.input`/`.avatarSm`/`.avatarMd`/`.avatarLg`/`.avatarXl`/`.tapMin`. Never raw heights/widths for buttons, inputs, avatars.
    - If a needed token doesn't exist, **add it to `design_tokens.dart`** rather than inlining the value.
  - **Reusable widgets**: Before inlining a container-decoration-row-column pattern that appears in 2+ screens, extract it to `lib/widgets/` (shared) or `lib/views/widgets/` (view-layer). Existing: `FixoAppBar`, `FixoPrimaryButton`, `FixoGhostButton`, `FixoTonalButton`, `FixoCard`, `StatusBadge`, `JobStepper`, `FixoLoading`, `FixoEmptyState`, `FixoErrorState`, `FixoWordmark`, `StickyActionBar`, `FixoAppBarAction`. Audit-identified extraction candidates: `FixoInfoBanner`, `FixoPillChip`, `FixoSectionLabel`, `FixoStepRow`, `FixoSummaryRow`, `FixoProgressBar`, `FixoCtaStack`, `FixoAvatar`, `FixoCopyButton`. Do not re-inline patterns that these widgets already cover.
- **Theme Support**: Both light and dark themes are required. If only one theme is present, add the other. Use `DesignTokens.paperLight` / `DesignTokens.paperDark` etc.
- **Atomic Components**: Construct reusable design system widgets first (e.g., `FixoButton`, `FixoTextField`, `FixoStatusBadge`) before assembling feature screens.

## Platform, Runtime & Scope Rules

- **Single Codebase**: One Flutter application with role-based views (Homeowner and Tradie). Dynamic routing post-authentication based on the JWT `role` claim. Do not create two separate mobile apps.
- **Primary MVP Client**: Homeowners and tradies use Flutter exclusively (React web is admin-only).
- **SignalR Real-Time**: Use the Dart SignalR client to connect to backend hubs for chat, live job status changes, and match dispatch notifications.
- **Push Notifications (FCM)**: Integrate Firebase Cloud Messaging for background notifications (incoming job matches, status updates, scheduled reminders). Do not rely solely on active foreground sockets.
- **Photo & Document Uploads**: Media uploads go through the S3-compatible API (MinIO in local dev, S3/Blob storage in production).
- **Local Dev Environment**:
  - Flutter runs on the host development machine (physical device, iOS Simulator, or Android Emulator), **not** inside Docker.
  - Default API base URL: `http://localhost:5000` (macOS/iOS Simulator) or `http://10.0.2.2:5000` (Android Emulator).
- **MVP Scope Adherence**:
  - Deliver Tier 1 and Tier 2 screens defined in `docs/MVP-SPEC.md` (Splash, Onboarding, Auth, Homeowner Home, Post a Job, Matching, Match Result, Tradie Home, Incoming Request, Chat + Job Status, Profile, Rating/Review, Settings).
  - Out of scope for MVP: In-app payments, automated dispute resolution, ML matching.
