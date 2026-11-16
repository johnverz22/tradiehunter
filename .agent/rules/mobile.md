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

- **Source of truth:** `docs/design/DESIGN_GUIDE.md` and `docs/design/tokens/tokens.json`. Visual reference: `docs/design/mockups/index.html` (30 screens, light + dark). Full design contract: `docs/DESIGN.md`.
- **Functional preservation**: Preserve hourly pricing, manual bank-transfer review, disputes, booking transitions, permissions, role views, existing routes/callbacks, shared ViewModels/repositories, Decimal money, UTC timestamps and SignalR synchronization. Never fabricate identity, ratings, badges, metrics, distances, contact or financial data. Unapproved provider/data/functional decisions remain gated.
- **Token Usage**:
  - Colour via `context.th.<name>` (the `THTheme` extension). Never `Theme.of(context).extension<THColors>()!` with a raw class name in view files.
  - **No-hardcoded-values rule** (enforced — see `mobile/HARDCODED_AUDIT.md`):
    - **Spacing/padding**: Use `Space.s1`…`Space.s9`, `Space.gutter`. Never raw numbers in `EdgeInsets` or `SizedBox` spacers.
    - **Border radius**: Use `Radii.card` (20), `Radii.control` (16), `Radii.tile` (18), `Radii.hero` (28), `Radii.sheet` (32), `Radii.pill` (999). Never `BorderRadius.circular(N)` with a raw number.
    - **Font sizes / type**: Use `THType.*` styles (display, h1, h2, title, button, money, moneyLg, label, body, meta). Never `fontSize: N` raw.
    - **Font weights**: Use `FW.regular`/`.medium`/`.semibold`/`.bold`/`.extrabold`. Never `FontWeight.wXXX` inline.
    - **Colors**: Use `context.th.<name>` or `THColors.*` statics. Never `Color(0x...)` in view/widget files. `Colors.transparent` is acceptable for overlays.
    - **Alpha/opacity**: Use `Alpha.*` tokens. Never `.withValues(alpha: 0.12)` with a raw number.
    - **Durations**: Use `THDurations.fast` (150 ms) / `.base` (220 ms) / `.slow` (320 ms). Never `Duration(milliseconds: N)` raw.
    - **Letter spacing**: Use `Tracking.*` tokens. Never `letterSpacing: N` raw.
    - **Component sizes**: Use `Sizes.button` (54), `Sizes.buttonSm` (44), `Sizes.input` (56), `Sizes.dock` (68), `Sizes.fab` (56), `Sizes.tapMin` (44). Never raw heights/widths for buttons, inputs, dock.
    - If a needed token doesn't exist, **add it to `design_tokens.dart` and `docs/design/tokens/tokens.json`** rather than inlining the value.
  - **Reusable widgets**: Use `TH*` family before creating anything new. Existing library: `THAppBar`, `THButton` (kinds: accent/primary/secondary/ghost/inverse/danger), `THCard`, `THHero`, `THDock`, `THStickyBar`, `THBadge`, `THProgress`, `THAvatar`, `THNotice`, `THText`, `THIcon`, `THField`, `THPills`, `THKeyValue`, `THTimeline`, `THDashBox`, `THRing`, `THSwitch`, `THBubble`, `THListRow`, `THDivider`, `THWordmark`. Do not re-inline patterns these already cover.
  - v1 → v2 widget mapping: `FixoPrimaryButton` → `THButton(kind: accent or primary)`, `FixoAppBar` → `THAppBar`, `FixoCard` → `THCard`, `FixoNotice` → `THNotice`, `StickyActionBar` → `THStickyBar`, `CustomBottomNavBar` + FAB → `THDock`.
- **Theme Support**: Both light and dark themes are required. No outdoor variant (removed in v2). Use `THTheme.light` / `THTheme.dark`. Never an `if (isDark)` branch in a view — dark is a token swap.
- **Brand budget**: One gold (`accent`) CTA per screen. `brand` (navy) for secondary filled actions. Green = verified/done, red = problem/dispute.

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
  - Deliver Tier 1 and Tier 2 screens defined in `docs/MVP.md` (Splash, Onboarding, Auth, Homeowner Home, Post a Job, Matching, Match Result, Tradie Home, Incoming Request, Chat + Job Status, Profile, Rating/Review, Settings).
  - Out of scope for MVP: In-app payments, automated dispute resolution, ML matching.
