# AGENTS.md — Fixo Mobile (Flutter)

Single app, role-based views (homeowner / tradie). This is the primary
MVP client. Read `../../docs/PRD.md`, `../../docs/MVP-SPEC.md`, and
`../../docs/ARCHITECTURE.md` before generating feature code.

## Mockups are law for UI

- Screen source of truth: `../../docs/design/mockup/mobile/` (15 files,
  `01-splash` → `15-homeowner-profile`). Match layout, copy, and tokens
  before inventing anything.
- Token source of truth: `../../docs/design/design-system.html`.
  Never hardcode colors in views — use `lib/theme/design_tokens.dart`
  (`DesignTokens`). Brand color derives from the `hue` knob (209);
  primary CTA is always `DesignTokens.amber`, never brand blue.
- Both light and dark themes required (`FixoTheme.light()` /
  `FixoTheme.dark()`); check both after any UI change.

## Screen → route map

| Mockup | Route | Widget |
|---|---|---|
| 01-splash | `/` | `views/splash_screen.dart` |
| 02-onboarding | `/onboarding` | `views/onboarding/onboarding_view.dart` |
| 03-login | `/auth` | `views/login_screen.dart` |
| 04-signup | `/signup` | `views/signup_screen.dart` |
| 05-homeowner-home | `/home` | `views/homeowner/homeowner_dashboard_view.dart` |
| 06-post-job | `/jobs/new` | `views/jobs/post_job_screen.dart` |
| 07-matching | `/jobs/:jobId/matching` | `views/jobs/matching_screen.dart` |
| 08-match-result | `/jobs/:jobId/match` | `views/jobs/match_result_screen.dart` |
| 09-tradie-home | `/tradie` | `views/tradie/tradie_dashboard_view.dart` |
| 10-request-detail | `/tradie/requests/:requestId` | `views/tradie/request_detail_screen.dart` |
| 11-chat | `/chat/:jobId` | `views/chat/chat_screen.dart` |
| 12-profile (tradie) | `/tradie/:id` | `views/profile/public_profile_screen.dart` (`isTradie: true`) |
| 13-rating-modal | bottom sheet (`RatingSheet.show`) | `widgets/rating_sheet.dart` |
| 14-settings | `/settings` | `views/settings_screen.dart` |
| 15-homeowner-profile | `/users/:id` | `views/profile/public_profile_screen.dart` (`isTradie: false`) |

Tabbed shell (`views/main_layout.dart`): homeowner gets Home / Messages /
Profile; tradie gets Dashboard / Jobs / Messages / Profile. Flow screens
(post-job → matching → match-result, request detail, chat) stay
root-level so no bottom nav covers their action bars.

## Architecture layers

- `lib/models/` — plain data classes with `fromJson`/`toJson`
  (`marketplace.dart`: `Job`, `TradieMatch`, `ChatMessage`, `Review`).
- `lib/repositories/` — API access only (Dio + secure storage).
  Stub data is allowed only with a `TODO(backend)` naming the real
  endpoint; screens must not contain HTTP calls.
- `lib/viewmodels/` — Riverpod `StateNotifier`s; screens watch state,
  never repositories directly (except single-shot stub loads).
- `lib/widgets/` — shared mockup pieces: `fixo_buttons.dart`
  (`FixoPrimaryButton` amber, `FixoGhostButton`, `FixoWordmark`),
  `fixo_cards.dart` (`StatusBadge`, `JobStepper`, `FixoCard`),
  `tradie_widgets.dart` (`FixoAvatar`, `TradieCard`, `StatCard`),
  `rating_sheet.dart`.
- `lib/router/app_router.dart` — go_router; add tabbed screens to the
  `ShellRoute`, flow screens as root `GoRoute`s.

## Backend rules (from root AGENTS.md)

- Money: `decimal` server-side; never `float`/`double` for prices.
- Timestamps: UTC in DB / ISO-8601 on the wire; localize at the client.
- Every job-status transition goes through the SignalR hub, not REST-only
  (chat, status, match notifications share the hub contract).
- `dotnet` runs inside the API container only — irrelevant here; Flutter
  runs on the host. Verify with `flutter analyze`, not `dart analyze`.
- Do not add dependencies beyond `docs/ARCHITECTURE.md` without asking.

## Backend-wiring TODOs (grep `TODO(backend)` / `TODO(signalr)`)
- `repositories/jobs_repository.dart` — POST /api/jobs, matches,
  request/accept/decline, uploads.
- `repositories/chat_reviews_repository.dart` — message history/send,
  POST reviews, profile reviews.
- `matching_screen.dart` — replace stub auto-advance with SignalR match
  listener. `request_detail_screen.dart` — real map + photos.
  `settings_screen.dart` — PATCH notifications/language, locale languages.
  `post_job_screen.dart` — image_picker + lat/lng.

## UI component conventions (added after the glassmorphic-nav refactor)

- **View-only widgets live in `lib/views/widgets/`**, separate from the
  shared, ViewModel-agnostic component library in `lib/widgets/`
  (`fixo_cards.dart`, `fixo_buttons.dart`, `fixo_states.dart`,
  `tradie_widgets.dart`). Anything new that's purely presentational and
  reusable across 2+ screens goes in `lib/views/widgets/`, not inline in
  a screen file.
- **Job list rows use `ModernJobCard`** (`lib/views/widgets/modern_job_card.dart`),
  not a hand-rolled `InkWell(child: FixoCard(...))`. It takes plain
  values (`title`, `category`, `location`, `statusLabel`, `statusKind`,
  optional `stage`/`isUrgent`/`timestampLabel`), not a `Job` object —
  keep it that way so this widget never has to import the ViewModel
  layer.
- **Bottom nav is `CustomBottomNavBar`** (`lib/views/widgets/custom_bottom_nav_bar.dart`),
  wired the same way the old `NavigationBar` was: pass the existing
  `currentIndex` and `context.go(...)` switch, plus a separate
  `onFabPressed` for the centered "Post Job" action. Don't add navigation
  logic inside this widget — it stays presentation-only.
- **Onboarding backgrounds use `AbstractOnboardingBackground`**
  (`lib/views/widgets/abstract_onboarding_background.dart`) instead of a
  flat `Container` with a brand-100 fill. Pass the slide index as `seed`
  so consecutive slides don't look identical.
- **Design tokens are still the only source of color/type/spacing.**
  `DesignTokens.radius` (4.0) stays the global sharp-corner default for
  ordinary cards, buttons, inputs, and badges — it was **not** changed.
  The 20–28px rounding, backdrop blur, and glow used in the three widgets
  above are local, one-off exceptions for those specific "elevated"
  surfaces (nav dock, onboarding art, job cards), not a new global radius.
  Don't hardcode a new hex color anywhere; extend `design_tokens.dart` if
  a genuinely new token is needed and get it named/reviewed there first.
- **No ViewModel exists for onboarding.** `OnboardingScreen` manages
  `PageController`/`_currentPage` as local `State` — that's intentional,
  not a gap to "fix" by inventing a Riverpod provider, unless product
  actually asks for onboarding state to be shared/persisted.
- **Homeowner and tradie dashboards share `jobsViewModelProvider` and
  `profileViewModelProvider`** — there is no `HomeownerViewModel` or
  `TradieViewModel`. Don't create role-specific ViewModels that just
  wrap the same two providers; keep reading them directly as both
  dashboard views do today.
