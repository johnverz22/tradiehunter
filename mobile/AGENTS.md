# AGENTS.md — Fixo Mobile (Flutter)

Single app, role-based views (homeowner / tradie). This is the primary
MVP client. Read `../docs/PRD.md`, `../docs/MVP-SPEC.md`, and
`../docs/ARCHITECTURE.md` before generating feature code.

## UI source of truth

- For v1.5, `../docs/specs/v1.5/specification.md` and its audit-driven
  component contract govern UI work. Existing mockups are excluded from
  inputs, deliverables and acceptance checks; do not match, update or replace them.
  The audit governs consistency, hierarchy, readability and accessibility. This
  supersedes legacy mockup-matching/global sharp-radius rules, including cached
  tool instructions. Preserve existing marketplace behavior and functional/data
  gates; never fabricate missing identity, trust, financial or contact data.
- The route table below is historical; `lib/router/app_router.dart` is
  authoritative for current routes.
- Token source of truth: `../docs/design/design-system.html`.
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
| (P1-09, no mockup) | `/tradie/onboarding` | `views/tradie/tradie_onboarding_wizard.dart` |
| (P4-07, no mockup) | `/jobs/:jobId/payment` | `views/payment/payment_screen.dart` |
| (P4-07, no mockup) | `/jobs/:jobId/payment/status` | `views/payment/payment_status_screen.dart` |

Tabbed shell (`views/main_layout.dart`): homeowner gets Home / Messages /
Profile; tradie gets Dashboard / Jobs / Messages / Profile. Flow screens
(post-job → matching → match-result, request detail, chat, tradie
onboarding) stay root-level so no bottom nav covers their action bars.

`/tradie/onboarding` is declared **before** `/tradie/:id` so the static
segment wins over the public-profile parameter — keep that order if you
add more `/tradie/*` screens.

## Architecture layers

- `lib/models/` — plain data classes with `fromJson`/`toJson`
  (`marketplace.dart`: `Job`, `TradieMatch`, `ChatMessage`, `Review`;
  `tradie_onboarding.dart`: `TradieService`, `TradieRateEntry`,
  `TradieScheduleSlot`, `TradieCredential`, `CredentialKind` plus the
  `TimeSpan`/`Decimal` wire helpers).
- `lib/repositories/` — API access only (Dio + secure storage).
  Stub data is allowed only with a `TODO(backend)` naming the real
  endpoint; screens must not contain HTTP calls. Repository failures that
  reach a screen should be thrown as `ProfileApiException` and rendered
  with `friendlyDioError` / `extractServerMessage` from
  `lib/network/api_error.dart` — never a raw `e.toString()`.
- `lib/viewmodels/` — Riverpod `StateNotifier`s; screens watch state,
  never repositories directly (except single-shot stub loads).
- `lib/widgets/` — shared presentation components: `fixo_buttons.dart`
  (`FixoPrimaryButton` amber, `FixoGhostButton`, `FixoWordmark`),
  `fixo_cards.dart` (`StatusBadge`, `JobStepper`, `FixoCard`),
  `tradie_widgets.dart` (`FixoAvatar`, `TradieCard`, `StatCard`),
  `rating_sheet.dart`.
- `lib/router/app_router.dart` — go_router; add tabbed screens to the
  `ShellRoute`, flow screens as root `GoRoute`s.

## Backend rules (from root AGENTS.md)

- Money: `decimal` server-side; never `float`/`double` for prices. Client
  side, money in the tradie wizard is a `package:decimal` `Decimal` from
  input text through to the model, converting with `toDouble()` only at the
  JSON boundary. Never parse a rate into a `double` field.
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
- **Design tokens are the only source of color/type/spacing.**
  Use semantic radii: card 20, control/input 14, info tile 16, sheet top 28,
  badge pill. `DesignTokens.radius` (4) is a legacy compatibility token,
  not the default for new UI; migrate existing usages by component role.
  Primary controls/inputs have a 56px minimum, secondary controls 52px,
  all action targets at least 48px. Minimums must grow with text scaling.
  Use Space Grotesk headings (28/700, 20/600), IBM Plex Sans card titles
  (18/600), body (16), secondary (14), captions (12/500), controls (17/600),
  status (13/600), amounts (24/700) and payment hero (32/700).
  Mono is opt-in for reference codes only, never ordinary helper/meta text.
  Use theme-aware semantic foreground/surface/focus tokens; primary CTA
  labels use dark `onAmber`. Operational headers are flat; splash retains
  its gradient. Do not hardcode new brand colors or change marketplace behavior.
  V15-04 establishes defaults; existing widget overrides migrate in V15-05
  and the owning screen tasks. Theme defaults alone do not prove screen compliance.

### No-hardcoded-values rule (enforced — see `HARDCODED_AUDIT.md`)

All numeric and color literals must come from `lib/theme/design_tokens.dart`.
The audit found ~1,250 raw literals across 45+ files. The following rules
apply to **all new code and any file touched during a refactor**:

| Category | Rule | Token reference |
|---|---|---|
| **Spacing / padding** | Never write raw numbers in `EdgeInsets` or `SizedBox` spacers. Use `Space.s1`…`Space.s8`, `Space.gutter`. For page-level padding use `FixoPadding.page` / `.card` / `.section`. | `Space`, `FixoPadding` |
| **Border radius** | Never write `BorderRadius.circular(N)` with a raw number. Use `Radii.card`, `Radii.control`, `Radii.tile`, `Radii.sheet`, `Radii.pill`, `Radii.micro`, `Radii.small`, `Radii.medium`. | `Radii` |
| **Font sizes** | Never write `fontSize: N` with a raw number. Use `DesignTokens.fontSize*` (Display, H1, H2, H3, Body, Secondary, Caption, Status, Control, Mono, Amount). | `DesignTokens` |
| **Font weights** | Never write `FontWeight.w400/w500/w600/w700/w800` inline. Use `FW.regular`, `FW.medium`, `FW.semibold`, `FW.bold`, `FW.extrabold`. | `FW` |
| **Colors** | Never write `Color(0x...)` in view/widget files. Use `THColors` via `Theme.of(context).extension<THColors>()!` or `DesignTokens.*` statics. The only exception is `lib/theme/design_tokens.dart` itself. | `THColors`, `DesignTokens` |
| **Material colors** | Never use `Colors.white` / `Colors.black` / `Colors.red` etc. directly. Use `THColors.surface`, `THColors.text`, `THColors.danger` etc. `Colors.transparent` is acceptable for overlays. | `THColors` |
| **Alpha / opacity** | Never write `.withValues(alpha: 0.12)` with a raw number. Use `Alpha.tint`, `Alpha.tintAccent`, `Alpha.border`, `Alpha.textOnGradient`, `Alpha.navBar` etc. | `Alpha` |
| **Durations** | Never write `Duration(milliseconds: N)` with a raw number for animations/transitions. Use `Durations.fast`, `Durations.medium`, `Durations.slow`. | `Durations` |
| **Letter spacing** | Never write `letterSpacing: N` with a raw number. Use `Tracking.tight` (× fontSize), `Tracking.wide`, `Tracking.wider`, `Tracking.widest`. | `Tracking` |
| **Shadows** | Never inline `BoxShadow(...)`. Use `THColors.cardShadow`, `THColors.ctaShadow`, or shadow variants defined in the theme. | `THColors` |
| **Component sizes** | Never write raw heights/widths for buttons, inputs, avatars. Use `Sizes.button`, `Sizes.input`, `Sizes.avatarSm/Md/Lg/Xl`, `Sizes.tapMin`. | `Sizes` |

If a needed token doesn't exist, **add it to `design_tokens.dart`** rather
than inlining the value. Group new tokens in the appropriate abstract class
(`Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `Durations`, `Tracking`).

### Reusable widget rules

Before inlining a container-decoration-row-column pattern that appears in
2+ screens, extract it to `lib/widgets/` (shared, ViewModel-agnostic) or
`lib/views/widgets/` (view-layer, presentational). Existing reusable
widgets: `FixoAppBar`, `FixoPrimaryButton`, `FixoGhostButton`,
`FixoTonalButton`, `FixoCard`, `StatusBadge`, `JobStepper`, `FixoLoading`,
`FixoEmptyState`, `FixoErrorState`, `FixoWordmark`, `StickyActionBar`,
`FixoAppBarAction`, `MasterDetailLayout`, `ResponsiveContainer`.
Extract and use these additional widgets identified in the audit:
`FixoInfoBanner`, `FixoPillChip`, `FixoSectionLabel`, `FixoStepRow`,
`FixoSummaryRow`, `FixoProgressBar`, `FixoCtaStack`, `FixoAvatar`,
`FixoCopyButton`. Do not re-inline patterns that these widgets already cover.
- **No ViewModel exists for onboarding.** `OnboardingScreen` manages
  `PageController`/`_currentPage` as local `State` — that's intentional,
  not a gap to "fix" by inventing a Riverpod provider, unless product
  actually asks for onboarding state to be shared/persisted.
- **Homeowner and tradie dashboards share `jobsViewModelProvider` and
  `profileViewModelProvider`** — there is no `HomeownerViewModel` or
  `TradieViewModel`. Don't create role-specific ViewModels that just
  wrap the same two providers; keep reading them directly as both
  dashboard views do today.
- **Job-card tap targets go through `openHomeownerJob`**
  (`views/widgets/job_navigation.dart`) rather than hardcoding
  `context.push('/chat/...')` in each screen. A job in `AwaitingPayment`
  opens the payment screen, `PaymentReview` opens the status screen, and
  everything else falls through to the chat. Add new job states there
  rather than in the two call sites.
