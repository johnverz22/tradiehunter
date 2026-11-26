# AGENTS.md — Fixo Mobile (Flutter)

Single app, role-based views (homeowner / tradie). This is the primary
MVP client. Read `../docs/PRD.md`, `../docs/MVP.md`, and
`../docs/ARCHITECTURE.md` before generating feature code.

## UI source of truth

- For v1.5, `../docs/SPECS.md` and its audit-driven
  component contract govern UI work. Existing mockups are excluded from
  inputs, deliverables and acceptance checks; do not match, update or replace them.
  The audit governs consistency, hierarchy, readability and accessibility. This
  supersedes legacy mockup-matching/global sharp-radius rules, including cached
  tool instructions. Preserve existing marketplace behavior and functional/data
  gates; never fabricate missing identity, trust, financial or contact data.
- Read `../docs/DESIGN.md` for the full design contract (icon rules, CTA placement, component patterns).
- The route table below is historical; `lib/router/app_router.dart` is
  authoritative for current routes.
- Token source of truth: `../docs/design/mobile/tokens/tokens.json`
  (generated into `lib/ui/design/th_tokens.dart`). Never hardcode colors in
  views — use `context.th.<name>`. Primary CTA is `THButtonKind.accent` (gold).
- Both light and dark themes required (`THTheme.light` / `THTheme.dark`);
  check both after any UI change.

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
- `lib/ui/` — the whole presentation layer (v2, Trust Navy + Gold):
  `design/` (tokens, `TH*` widgets), `feedback/` (`THNotice`, `ThStateView`),
  `auth/`, `homeowner/` (`Ho*`/`Th*` screens), `tradie/` (`Tr*` screens),
  `shared/` (shell, chat, profile, settings, notifications, sheets).
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
- Do not add dependencies beyond `../docs/ARCHITECTURE.md` without asking.

## Backend-wiring TODOs (grep `TODO(backend)` / `TODO(signalr)`)
- `repositories/jobs_repository.dart` — POST /api/jobs, matches,
  request/accept/decline, uploads.
- `repositories/chat_reviews_repository.dart` — message history/send,
  POST reviews, profile reviews.
- `matching_screen.dart` — replace stub auto-advance with SignalR match
  listener. `request_detail_screen.dart` — real map + photos.
  `settings_screen.dart` — PATCH notifications/language, locale languages.
  `post_job_screen.dart` — image_picker + lat/lng.

## UI component conventions

- **Everything visual lives in `lib/ui/`.** There is no `lib/views/`,
  `lib/widgets/` or `lib/theme/` any more (deleted in Phase 6). Reuse the
  `TH*` library in `lib/ui/design/th_widgets.dart` before building anything:
  `THAppBar`, `THButton`, `THCard`, `THDock`, `THStickyBar`, `THBadge`,
  `THText`, `THTextField`, `ThStateView`, `THNotice`.
- **Screen structure:** a screen file holds its state and wiring; pure
  presentation goes in `*_parts.dart` / `*_screen.dart` view widgets that take
  plain values (never a ViewModel), so they stay golden-testable.
- **Job-status presentation** is per role: `HoJobStatus` (`ui/homeowner`) and
  `TrJobStatus` (`ui/tradie`). Add new statuses to both tables.
- **Job detail** is chosen by `ThJobDetailRouter` / `TrJobRouter`; statuses
  without a design frame render `HoJobDetailFallbackScreen`.
- **No ViewModel exists for onboarding.** It manages its `PageController`
  locally; do not invent a provider unless product asks for shared state.
- **Homeowner and tradie dashboards share `jobsViewModelProvider` and
  `profileViewModelProvider`** — do not create role-specific wrapper
  ViewModels.

### No-hardcoded-values rule (enforced)

All numeric and color literals come from `lib/ui/design/th_tokens.dart`
(generated from `docs/design/mobile/tokens/tokens.json`). Applies to all new
code and any file touched in a refactor.

| Category | Rule |
|---|---|
| Spacing | `Space.s1`…`Space.s9`; never raw numbers in `EdgeInsets` / `SizedBox` |
| Radius | `Radii.control/tile/card/hero/sheet/pill`; never `BorderRadius.circular(N)` |
| Type | `THType.*` or `THText(style: THTextStyle.*)`; never raw `fontSize` / `FontWeight` |
| Colour | `context.th.<name>`; never `Color(0x…)` or `Colors.white/black/red` (`Colors.transparent` is fine) |
| Durations | `THDurations.*`; never `Duration(milliseconds: N)` for UI motion |
| Sizes | `Sizes.button/buttonSm/input/tapMin/dock/fab/avatar*` |

If a token is missing, add it to `tokens.json`, run
`node docs/design/mobile/tools/build.mjs`, and commit the regenerated output.

## Documentation map (consolidated)

All docs live in `../docs/`, one file per type. Do not add versioned spec folders.

| Need | Read |
|---|---|
| Index, naming, conventions | `../docs/README.md` |
| Product / scope / status | `../docs/PRD.md`, `../docs/MVP.md`, `../docs/MILESTONES.md` |
| Behaviour, state machine, data model, money, config | `../docs/SPECS.md` |
| Stack and seams | `../docs/ARCHITECTURE.md` |
| Email + Firebase runbooks | `../docs/OPERATIONS.md` |
| Test commands, seeds / manual QA | `../docs/TESTING.md`, `../docs/QA.md` |
| Tokens, components, frames, notices | `../docs/DESIGN.md`, `../docs/design/html/` |
| MCPs, rules, skills | `../docs/ai/AI-TOOLING.md` |

Scope rule: changes to decisions recorded in `../docs/MVP.md` need explicit owner sign-off first. Frames in `../docs/design/html/` are the visual reference for new screens. Update docs via the `docs-sync` skill.
