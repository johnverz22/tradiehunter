# v1.6 — Implementation plan

**Status:** Ready for execution  
**Date:** 2026-11-02  
**Depends on:** [Specification](specification.md), [Visual design](visual-design.md), [Tasks](tasks.md)  
**Baseline:** V16-01 findings-log.md — flutter analyze 9 infos / 0 warnings / 0 errors; 511/511 tests pass

---

## 1. Approach

Deliver v1.6 as a sequence of small, independently reviewable Flutter changes targeting visual hierarchy, status clarity, touch targets, and iPad layout. The design phase (V16-21–V16-26) is complete. The implementation phase (V16-03 through V16-18) executes against the approved component sheet, style tile, and hi-fi frames in `docs/design/v1.6/`.

All changes are visual-layer work within the existing Riverpod/GoRouter/repository architecture. No API contract changes, no new third-party packages, no new navigation routes, and no functional-behavior changes are required. Every screen edit preserves existing ViewModel providers, SignalR subscriptions, and payment/dispute gates.

### What the v1.5 work already shipped

The following foundations are already in the working tree and **must not be re-created**:

| Component | File | What exists |
|---|---|---|
| `THColors` ThemeExtension | `mobile/lib/theme/design_tokens.dart` | Three named instances: `light`, `dark`, `outdoor`; `Space`, `Radii`, `Sizes`, `TypeTokens` |
| `StatusBadge` / `FixoBadgeKind` | `mobile/lib/widgets/fixo_cards.dart` | Six semantic variants with icon+fill logic; deprecated aliases retained for migration |
| `FixoCard` | `mobile/lib/widgets/fixo_cards.dart` | 20px radius, `line` border, `cardShadow`, dark-mode elevated surface |
| `CompactProgressBar` | `mobile/lib/views/widgets/compact_progress_bar.dart` | 4-segment, ~24px height, terminal-state muting |
| `JobTimeline` | `mobile/lib/views/widgets/job_timeline.dart` | Collapsible with `initialExpanded` flag |
| `JobStatusPresentation` | `mobile/lib/views/widgets/job_status_presentation.dart` | Maps `JobStatus` strings to label/kind/action/progressStage |
| `ModernJobCard` | `mobile/lib/views/widgets/modern_job_card.dart` | 5-part layout per v1.6 spec (docstring) |
| `FixoAppBar` | `mobile/lib/widgets/fixo_buttons.dart` | Adaptive appbar with subtitle/leading/actions |
| Adaptive nav shell | `mobile/lib/views/main_layout.dart` | Bottom nav ↔ left rail at `kBreakpointLeftRail` (1024pt) |
| Dead-end recovery screens | `homeowner_job_detail_screen.dart`, `tradie_job_detail_screen.dart`, `request_detail_screen.dart` | `_JobNotFoundBody`, `_TradieJobNotFoundBody`, `_RequestNotFoundBody` |
| Dispute banner gate | `homeowner_job_detail_screen.dart` | Banner only on disputed jobs; confirm-completion disabled mid-dispute |

### Naming and structure conventions

- Follow existing class and file names. No new files unless a widget is genuinely shared across three or more screens.
- New shared widgets belong beside existing ones in `mobile/lib/widgets/` (if role-agnostic) or `mobile/lib/views/widgets/` (if view-tier specific).
- Re-read target files before editing. Do not touch unrelated in-flight state.
- Token access pattern: `Theme.of(context).extension<THColors>()!` for colours; `Space.*`, `Radii.*`, `Sizes.*` for layout constants.
- Both light and dark themes verified after every change. Outdoor variant checked for screens that render a hero band.

### Test baseline and regression gate

| Metric | Required at exit |
|---|---|
| `flutter analyze` | ≤ 9 infos, 0 warnings, 0 errors (no regressions from baseline) |
| `flutter test` | All 511+ tests pass; new tests added per-task bring the count up |
| Backend build | 0 errors (no backend changes expected) |
| `p3-smoke.sh` / `p4-smoke.sh` | All scenarios green (no functional changes touch these paths) |

---

## 2. Implementation anchors

> Read each target file before editing. The column "Confirmed state" reflects the V16-01 baseline inspection; spot-check before writing to ensure no interim changes.

| Area | Target files | Confirmed state (V16-01) | v1.6 work |
|---|---|---|---|
| Shared primitives | `widgets/fixo_cards.dart`, `fixo_buttons.dart`, `fixo_states.dart` | `StatusBadge`/`FixoCard` present; old `FixoBadgeKind.hold`/`neutral` calls remain in screens | Add `FixoTonalButton`; migrate deprecated badge calls |
| Status mapping | `views/widgets/job_status_presentation.dart` | Six-variant mapping exists and correct | No changes needed; callers need migration |
| Progress display | `views/widgets/job_progress.dart` | Old radio-button stepper still exists | Retire: delete or stub once all callers migrated |
| Screen shell | `views/main_layout.dart` | Left rail at ≥1024pt implemented | Add 744pt master-detail panel switching for jobs/messages |
| Homeowner dashboard | `views/homeowner/homeowner_dashboard_view.dart` | Uses `ModernJobCard`; greeting is generic | Reorder card content, first-name greeting, filter chips |
| Homeowner job detail | `views/homeowner/homeowner_job_detail_screen.dart` | Dispute gate fixed (V16-02); Navigate/Message/Call are text links | Reorganise into 3-card layout; convert action links to tonal buttons |
| Tradie dashboard | `views/tradie/tradie_dashboard_view.dart` | Lead cards present; price hierarchy unclear | Reorder lead cards; add countdown bar; Today grouping |
| Tradie request detail | `views/tradie/request_detail_screen.dart` | Dead-end screen fixed (V16-02) | Reorder content; price prominent; countdown bar; sticky actions |
| Tradie job detail | `views/tradie/tradie_job_detail_screen.dart` | Dead-end screen fixed (V16-02) | 3-card layout; "You earn" label; Navigate tonal button |
| Tradie onboarding wizard | `views/tradie/tradie_onboarding_wizard.dart` | All 4 steps present | Step 1 padding; step 2 per-trade services; step 3 upload cards |
| Match result | `views/jobs/match_result_screen.dart` | Price section visible | Tradie hero first, then price card; remove duplicate heading |
| Post a job | `views/jobs/post_job_screen.dart` | Form present | Character counters, estimate card, disabled post button with helper |
| Jobs list | `views/jobs/jobs_list_screen.dart` | Cards present | Use `CompactProgressBar`; apply filter chips |
| Chat screen | `views/chat/chat_screen.dart` | 4-row stepper in header area | Replace with one-line status pill using `CompactProgressBar.inline` |
| Messages list | `views/chat/messages_list_screen.dart` | `ConversationTile` exists with correct data | 72px rows; 40px avatar; name/job/preview/time/unread dot |
| Sign-up screen | `views/signup_screen.dart` | Forgot-password between email+password fields (confirmed bug) | Scroll fix; forgot-password reposition; icon consistency |
| Public profile | `views/profile/public_profile_screen.dart` | Multiple "No reviews yet" instances | Consolidate to single trust row |
| Profile / settings | `views/profile_screen.dart`, `views/settings_screen.dart` | Settings cards exist | Field editability cues; 20px card groups; 56px rows |
| Typography-wide | All screens | Some sub-12px labels suspected | `FittedBox`/size audit; chip/tab/caption minimums |
| Dark mode borders | All screens | Light-grey 1.5px outlines exist in some screens | Replace with `line` token border (1px); verify contrast |
| iPad master-detail | `views/main_layout.dart`, jobs/messages screens | No master-detail at 744pt | `LayoutBuilder` panel split; `ResponsiveContainer` wrapper |

---

## 3. Ordered implementation slices

Dependencies match the tasks.md build order. Complete each slice before starting the next one that depends on it. P0 tasks must ship clean before any P1 work merges.

---

### Phase A — Foundation components (V16-03, V16-04, V16-05, V16-06, V16-07)

These build the shared widgets consumed by all screen changes. Phases B–E cannot start until these pass their tests.

#### V16-03 — StatusBadge screen migration

**Existing baseline:** `StatusBadge` widget and `FixoBadgeKind` enum are correct. The deprecated `hold`/`neutral`/`live`/`urgent` values remain in screen callers.

**Work:**
1. Grep for all `FixoBadgeKind.hold`, `.neutral`, `.live`, `.urgent` call sites across the codebase.
2. Replace each with the correct semantic variant using `JobStatusPresentation.forStatus()` as the single mapping source.
3. Remove any inline status-to-label/kind mapping logic in individual screens in favour of `JobStatusPresentation`.
4. Verify `StatusBadge` pill never stretches full-width: check every call site wraps with `Align(widthFactor: 1.0, ...)` or equivalent.
5. Add/extend `status_badge_test.dart` if any new screen-level paths are untested.

**Key files:** `widgets/fixo_cards.dart`, `views/widgets/job_status_presentation.dart`, and all callers  
**Exit:** No `FixoBadgeKind.hold/neutral/live/urgent` calls outside of the deprecated stubs themselves. `flutter analyze` 0 warnings.

---

#### V16-04 — Compact progress bar rollout

**Existing baseline:** `CompactProgressBar` and `JobTimeline` are complete and tested. `job_progress.dart` contains the old radio-button stepper still used in some screens.

**Work:**
1. Grep for `JobProgress` usages and `job_progress.dart` imports.
2. Replace each `JobProgress` with `CompactProgressBar(status: ...)` using the existing `JobStatusPresentation.progressStage` for the `currentStep`.
3. On `homeowner_job_detail_screen.dart` and `tradie_job_detail_screen.dart`, add a `JobTimeline` widget (collapsed by default) below the status card.
4. Once all callers are migrated, delete (or reduce to a stub with a deprecation comment) `job_progress.dart` to prevent future use.
5. Verify `chat_screen.dart` no longer has the 4-row stepper (that is V16-12's specific work, but if it uses `JobProgress`, migrate here).

**Key files:** `views/widgets/job_progress.dart`, `views/widgets/modern_job_card.dart`, `views/homeowner/homeowner_job_detail_screen.dart`, `views/tradie/tradie_job_detail_screen.dart`, `views/jobs/jobs_list_screen.dart`  
**Exit:** No `job_progress.dart` imports remain in screen files. `compact_progress_bar_test.dart` and `job_timeline_test.dart` pass.

---

#### V16-05 — Container language full rollout

**Existing baseline:** `FixoCard` widget exists with correct tokens. Not all card/tile usages across screens use it — some screens still use inline `Container`/`Card` with custom border/shadow values.

**Work:**
1. Audit each screen for `Container` or `Card` widgets that render as a card-like tile but don't use `FixoCard`.
2. Wrap them with `FixoCard` (or replace `Card` with `FixoCard`).
3. Remove any `1.5px` or heavier `Border` on non-input elements (`BorderSide(width: 1.5, ...)`).
4. Confirm input fields retain their own 1.5px focused-border treatment (do not change input decoration).
5. In dark mode, confirm cards use the elevated surface + `line` token border — no light-grey outlines.

Priority screens to inspect: `homeowner_job_detail_screen.dart`, `tradie_job_detail_screen.dart`, `match_result_screen.dart`, `payment_screen.dart`, `signup_screen.dart`, `tradie_onboarding_wizard.dart`, `settings_screen.dart`, `public_profile_screen.dart`.

**Key files:** `widgets/fixo_cards.dart`, `theme/design_tokens.dart` (for border token), all screen files above  
**Exit:** Grep finds no `BorderSide(width: 1.5)` outside of `InputDecoration`/focused-state. Visual consistency across ≥10 screens in both themes.

---

#### V16-06 — Typography enforcement

**Existing baseline:** Two-font-family system (Space Grotesk display, IBM Plex Sans body) exists in `design_tokens.dart`. Some suspected sub-12px labels and heading inconsistencies remain.

**Work:**
1. Grep for literal `fontSize:` values below `12` in `lib/views/` and `lib/widgets/`.
2. Increase any below-12px text to ≥12px.
3. Grep for any `fontFamily:` that is neither `TypeTokens.fontDisplay` nor `TypeTokens.fontBody` nor `TypeTokens.fontMono`.
4. Replace with the correct family token.
5. For stat captions that may wrap ("Net this week", earnings amounts): wrap with `FittedBox(fit: BoxFit.scaleDown, child: ...)` and ensure a minimum `fontSize` of 12.
6. For job title in headers that truncate awkwardly: allow two lines with `maxLines: 2` and `overflow: TextOverflow.ellipsis`, or use `FittedBox` with scale-down.
7. Verify chip labels ≥13px, tab labels ≥12px, lead-card metadata ≥12px.

**Key files:** All `lib/views/` screens, `lib/widgets/`  
**Exit:** No `fontSize` below 12 in view code. Two font families only. Stats don't wrap or clip.

---

#### V16-07 — FixoTonalButton and action link conversion

**Existing baseline:** `fixo_buttons.dart` has primary and secondary buttons but no tonal variant. Navigate/Message/Call in detail screens are `TextButton` or `OutlinedButton` instances, not 48px tonal buttons.

**Work:**
1. Add `FixoTonalButton` to `mobile/lib/widgets/fixo_buttons.dart`:
   - 48px height minimum; `Sizes.tapMin = 48` constraint
   - `tintBrand` fill (`THColors.tintBrand` from theme)
   - Leading `Icon` (24px) + label (`TextStyle(fontSize: 14, fontWeight: FontWeight.w600)`)
   - `Radii.control` (14px) border radius
   - Dark mode: same fill token resolves correctly (tintBrand is theme-aware)
2. In `homeowner_job_detail_screen.dart`, replace Navigate/Message/Call text links with a 2-up or 3-up row of `FixoTonalButton` widgets.
3. In `tradie_job_detail_screen.dart`, same conversion for Navigate/Message/Call.
4. In `tradie_job_detail_screen.dart` and `request_detail_screen.dart`, replace "View payment instructions" text with a tonal button.
5. Arrange tonal buttons in a `Row` with `mainAxisAlignment: MainAxisAlignment.spaceEvenly` and 8px gaps, all constrained to ≥48×48 hit area (`SizedBox(height: 48, child: FixoTonalButton(...))`).
6. Add `fixo_tonal_button_test.dart` widget tests for both themes.

**Key files:** `widgets/fixo_buttons.dart`, `views/homeowner/homeowner_job_detail_screen.dart`, `views/tradie/tradie_job_detail_screen.dart`, `views/tradie/request_detail_screen.dart`  
**Exit:** Navigate/Message/Call are ≥48px tonal buttons everywhere. No `TextButton`/plain text for these actions.

---

### Phase B — Tradie flow (V16-08, V16-16)

Depends on Phase A completing first.

#### V16-08 — Lead card and request detail reorder

**Existing baseline:** Lead cards in `tradie_dashboard_view.dart` have price but it is not the visual lead. `request_detail_screen.dart` has a dead-end recovery screen (done) but content order hasn't been restructured.

**Work — lead cards:**
1. Read `tradie_dashboard_view.dart` fully before editing.
2. Within the lead card widget (or a new `_LeadCard` private widget): reorder content so price (`24/700`) leads, followed by urgency tag inline on the same row, then countdown progress bar, then distance/start/duration at 14px, then one-line job summary + photo thumbnail.
3. Countdown bar: use `CompactProgressBar` in a linear-progress style showing time remaining. Source the expiry from `JobOffer.expiresAtUtc` via the existing offer payload; derive remaining fraction at render time. Do not invent a duration.
4. Decline/Accept button row: Decline takes 1/3 width (outlined), Accept takes 2/3 width (primary, 56px). Both at 56px height.
5. Price in `TextStyle(fontSize: 24, fontWeight: FontWeight.w700)`, dark foreground (`THColors.text`), never blue.
6. "Today" grouping: section headers "Now", "Next", "Later" using the existing scheduled time on jobs. If no time available, collapse to ungrouped "Today".
7. Filter chips at ≥48px: Today / Upcoming / Awaiting payment / Done / All.

**Work — request detail:**
1. Read `request_detail_screen.dart` fully.
2. Reorder screen body: price 24/700 → countdown bar → address card → schedule → description → photos → sticky bottom (Decline 1/3 | Accept 2/3).
3. Remove Status/Stage tiles from the screen.
4. Move category into a chip near the job title.
5. Sticky bottom bar: use `StickyActionBar` widget or equivalent bottom-pinned row.
6. Price must use `THColors.text`, not any blue or link colour.

**Key files:** `views/tradie/tradie_dashboard_view.dart`, `views/tradie/request_detail_screen.dart`, `views/widgets/offer_countdown.dart`  
**Exit:** Price is the largest element on lead cards. Countdown is a visible bar. Request detail leads with price.

---

#### V16-16 — Tradie active job and wizard polish

**Existing baseline:** `tradie_job_detail_screen.dart` has a Navigate dropdown chevron (text or button). `tradie_onboarding_wizard.dart` has all 4 steps. Step 2 may show all trade categories, not just selected-trade services.

**Work — active job:**
1. Replace Navigate dropdown/chevron with a `FixoTonalButton(icon: Icons.navigation_outlined, label: 'Navigate')` that opens the existing map-app picker bottom sheet (`ExternalLauncher`).
2. Find any "gross" label (e.g., "Job total (gross)") and replace with "You earn \$X" using the net amount from the existing earnings calculation.
3. Confirm Cancel is in the `⋮` overflow menu, not a visible button. If not, move it.
4. Confirm the cancel sheet (already in `cancel_job_sheet.dart`) shows the ranking warning in red tint styling.

**Work — onboarding wizard:**
1. Step 1: add `SafeArea` + bottom padding equal to CTA height + 32px so "Continue" doesn't clip scrollable content.
2. Step 2: read `tradie_onboarding_viewmodel.dart` to find the selected-trade state. Show only services/specialties for the selected trade(s), not the full category list. If multiple trades selected, show services in labelled sections per trade. Inline hourly-rate field appears when a service is ticked.
3. Step 3: replace any awkward upload placement with document cards (`FixoCard`) + a `FixoTonalButton(label: 'Upload document')` below each card group.
4. Step 4: verify payout fields have lock/privacy note; "Finish setup" as sticky CTA.

**Key files:** `views/tradie/tradie_job_detail_screen.dart`, `views/tradie/tradie_onboarding_wizard.dart`, `viewmodels/tradie_onboarding_viewmodel.dart`, `network/external_launcher.dart`  
**Exit:** Navigate is a proper button. "Gross" removed. Wizard content never clipped. Step 2 shows only relevant services.

---

### Phase C — Homeowner flow (V16-09, V16-10, V16-11)

Depends on Phase A completing first.

#### V16-09 — Homeowner dashboard card reorder

**Existing baseline:** `homeowner_dashboard_view.dart` uses `ModernJobCard` which has the 5-part layout in its docstring but may not yet implement all parts. Greeting is generic ("Hey Homeowner,").

**Work:**
1. Read `homeowner_dashboard_view.dart` and `views/widgets/modern_job_card.dart` in full.
2. **Hero band** (see `H07-light`/`H07-dark` in `frames-homeowner.html`): replace the plain `h1`-style greeting with a navy gradient hero band containing: a small-caps time-of-day label ("GOOD MORNING"), 28px Display first name, frosted suburb/location pill, and a bell icon with an amber unread dot when there are notifications. Use `THColors.brand` as the gradient base; add the `bpdots` texture asset as a faint background if available in `assets/`.
3. **Attention cards**: job title as headline (`TextStyle(fontFamily: TypeTokens.fontDisplay, fontSize: 17, fontWeight: FontWeight.w700)`), tradie name secondary, price and time separated by a hairline `Divider`, progress shown as 4 × 6px circular dot indicators + "Step X of 4" label. Use this compact dot row — not the full `CompactProgressBar` widget — on attention cards. Attention card background gradient: `LinearGradient` from `THColors.brand.withOpacity(0.18)` to `THColors.brand.withOpacity(0.06)` to transparent, top-to-bottom. No left-border accent stripe.
4. **Booked section**: compact list row inside a single `FixoCard` (44px avatar + job title + dot progress + price), "Open chat" `FixoTonalButton` below a hairline.
5. Primary button label per state (on expandable detail, not on the compact booked row): AwaitingPayment → "Pay now", PaymentReview → "View payment status", AwaitingConfirmation → "Review completion", Completed → "Leave a review" (if eligible), Cancelled → omit.
6. Move reference code and trade/location to a subdued secondary line (`THColors.textSoft`).
7. Change greeting to "Welcome back, [firstName]" using the first name from the profile provider. Fallback: "Welcome back".
8. "Needs your attention" section: sort by actionable state (ActionNeeded before Waiting before Active).
9. **Empty state** (see `H07-empty-light`/`H07-empty-dark`): hero band + spot illustration (`il-01-light/dark.svg`) with drop shadow + "Find a tradie you can trust" headline + 3-stat row (`< 5 min`, `100%`, `Fixed price`) + full-width "Post a job" primary CTA.

**Key files:** `views/homeowner/homeowner_dashboard_view.dart`, `views/widgets/modern_job_card.dart`, `viewmodels/profile_viewmodel.dart`  
**Exit:** Dashboard has a hero band with first name. Attention cards use compact dot progress. Booked row is a compact card. Empty state shows illustration and stats.

---

#### V16-10 — Match result trust reorder

**Existing baseline:** `match_result_screen.dart` shows match information but price may appear before tradie identity. "No reviews yet" shown without alternative trust proof.

**Work:**
1. Read `match_result_screen.dart` in full.
2. Reorder screen: (1) Tradie hero card — 72px `Sizes.avatarLg` circular photo, name 20/700, Verified + Insured badges, distance if available, "New to TradieHunter" or rating + jobs completed; (2) Price breakdown card — hours × rate = total at 24/700, platform fee line if applicable; (3) Sticky bottom — "Continue to payment" primary 56px, "See another tradie" secondary 52px outline.
3. Remove duplicate "Match Found" heading if it appears in both app bar and body.
4. Replace any "No reviews yet" copy with "New to TradieHunter" where the tradie has no reviews, shown once only.
5. Verified/Insured badges: use `StatusBadge(kind: FixoBadgeKind.done, ...)` — show only when the credential is actually confirmed in the profile data.

**Key files:** `views/jobs/match_result_screen.dart`, `models/marketplace.dart` (TradieMatch fields)  
**Exit:** Tradie identity is the first visible element. Price breakdown is a single card below. No duplicate headings.

---

#### V16-11 — Job detail card grouping

**Existing baseline:** `homeowner_job_detail_screen.dart` and `tradie_job_detail_screen.dart` have all the data but likely as a single long scroll without 3-card grouping. Dispute gate is already correct (V16-02).

**Work — homeowner job detail:**
1. Read the file in full.
2. Restructure body into three `FixoCard` widgets:
   - **Status card:** `StatusBadge` (top-aligned, `widthFactor: 1`) + `CompactProgressBar` + single contextual banner (dispute warning or payment notice — never both at once).
   - **People card:** tradie 44px avatar + name + Verified/Insured badges; `FixoTonalButton` row for View profile, Chat, Call (use existing profile and chat routes; Call only if `phoneNumber` disclosed per D5/D6 rules).
   - **Details card:** 2-column info tile grid (Scheduled | Duration, full-width Address, full-width Price at 24/700) + description text.
3. Sticky action bar (bottom pinned) varies by state: Booked/InProgress → "Open chat"; AwaitingConfirmation → "Confirm completion" (disabled if dispute open — already correct); Completed → "Leave a review" (if eligible); Cancelled → none.
4. Move Cancel and Dispute actions to `⋮` overflow menu or a "Need help?" row at bottom.
5. Info tiles must use equal heights — wrap each pair in `IntrinsicHeight` + `Row` with two `Expanded` children.

**Work — tradie job detail:**
1. Same 3-card structure.
2. People card shows homeowner photo/name; Message and Call as tonal buttons.
3. Details card shows "You earn" net amount (not gross) at 24/700.
4. Sticky action: same state-based logic as homeowner side.

**Key files:** `views/homeowner/homeowner_job_detail_screen.dart`, `views/tradie/tradie_job_detail_screen.dart`  
**Exit:** Job details are in 3 clear cards. Actions are tonal buttons. Cancel/dispute in overflow.

---

### Phase D — Secondary screens (V16-12, V16-13, V16-14, V16-15, V16-17)

Depends on Phase A completing first. Can run in parallel with Phases B and C where there are no shared-file conflicts.

#### V16-12 — Chat stepper and messages list

**Existing baseline:** `chat_screen.dart` has a 4-row stepper block. `messages_list_screen.dart` has `ConversationTile` which already has the right data fields.

**Work — chat screen:**
1. Read `chat_screen.dart` in full.
2. Remove the 4-row stepper block from the header area.
3. Replace with a single `CompactProgressBar(status: ..., inline: true)` or a `StatusBadge` line below the chat header — single line, ~24px.
4. Chat header retains: avatar, name, job subtitle, call icon (48px), ⋮ overflow.
5. Chat input: ensure 56px height, camera 48px hit area, send 48px hit area.
6. Quick replies: confirm they scroll horizontally with a fade edge at 40px height.

**Work — messages list:**
1. Read `messages_list_screen.dart` in full.
2. Update `ConversationTile` (or rebuild it inline) to render at 72px row height:
   - 40px circular avatar (`Sizes.avatarMd`)
   - Tradie/homeowner name at 16/600
   - Job title at 14/400 in `THColors.textSoft`
   - Last message preview at 14/400, single-line truncated
   - Time at 12/500, right-aligned
   - Unread dot: 8px circle in `THColors.accent`, right side, visible when `unreadCount > 0`
   - Status as a small icon, not a chip
3. Empty state: confirm `FixoEmptyState` (from `fixo_states.dart`) is shown with the "No messages yet" illustration.

**Key files:** `views/chat/chat_screen.dart`, `views/chat/messages_list_screen.dart`, `views/widgets/chat_widgets.dart`  
**Exit:** Chat has one-line status (not 4-row stepper). Messages list shows 72px rows with avatar/preview/time/unread dot.

---

#### V16-13 — Post a job polish

**Existing baseline:** `post_job_screen.dart` is a large form file. Character counters, estimate card, and button validation state need implementation.

**Work:**
1. Read `post_job_screen.dart` in full.
2. Character counters: use `TextField`'s `maxLength` property but suppress the built-in counter. Instead, show a custom counter widget only when `text.length / maxLength >= 0.8`. Show as subdued secondary text below the field.
3. Estimate card: add a `FixoCard` section that updates in real time as `hourlyRate` and `estimatedHours` fields are filled. Show "X h × \$Y = \$Z" or "Choose a rate to see your estimate" when not yet filled. Subscribe to the relevant form controllers.
4. "Search nearby rates" row: if it's non-functional, remove it. If it has a future stub, replace with a `FixoTonalButton` placeholder that shows a "coming soon" snackbar.
5. Date field: ensure it renders as a 56px tappable input with 14px radius, not a chip.
6. Move Photos section above the When/Urgency section in the form order.
7. Post button: disable when required fields (title, category, address, hourly rate, estimated hours) are not valid. Show helper text below: "Add a [field] to post your job" naming the first missing field. Use `ElevatedButton`'s `onPressed: null` for semantic disable.
8. Urgency: use a segmented control (48px height) with a short meaning below each option.

**Key files:** `views/jobs/post_job_screen.dart`, relevant ViewModel for form state  
**Exit:** Counters appear only near limits. Estimate card updates live. Post button disabled with helper text. Photos above scheduling.

---

#### V16-14 — Entry and onboarding fixes

**Existing baseline:** `signup_screen.dart` — forgot-password between email and password fields (confirmed bug). Role selector may use full-width tiles. `onboarding_view.dart` — slide 2 copy and icon inconsistency.

**Work:**
1. Read `signup_screen.dart` and `login_screen.dart` in full.
2. Sign-up scroll fix: shrink role selector to a 2-segment `SegmentedButton` or equivalent (72px height, house icon for Homeowner, tools icon for Tradie). Ensure scrollable `SingleChildScrollView` content has bottom padding equal to sticky CTA height + 32px so no field is clipped at 320px width.
3. Forgot-password: in `login_screen.dart`, move the "Forgot password?" `TextButton` from between Email and Password fields to right-aligned immediately below the Password field. Verify by reading the current widget tree order.
4. Icon consistency: unify Homeowner icon to `Icons.home_outlined` (or the same icon used on the role-select screen) on both sign-up segmented control and role-select screen.
5. Copy fixes: update slide 2 body to "See credentials and reviews before you hire". Update any "Verification applies to the evidence shown" copy to "We verify the documents your tradie provides". These are string literal changes only.

**Key files:** `views/signup_screen.dart`, `views/login_screen.dart`, `views/onboarding/onboarding_view.dart`, `views/auth/role_select_screen.dart`  
**Exit:** Sign-up CTA never covers a field at 320px. Forgot-password is below Password. Icons consistent.

---

#### V16-15 — Profiles and settings

**Existing baseline:** `public_profile_screen.dart` has "No reviews yet" in multiple places. `profile_screen.dart` and `settings_screen.dart` need editability cues and grouping.

**Work — public profile:**
1. Read `public_profile_screen.dart` in full.
2. Find all "No reviews yet" text instances. Replace all with a single trust row:
   - If `reviewCount == 0`: show "New to TradieHunter" + jobs completed count + verified badge (if applicable)
   - If `reviewCount > 0`: show star rating + jobs completed count + verified badge
   - Show this row once, near the name/avatar area.
3. Remove the separate rating tile and review count tile that duplicate this information.
4. Tradie verification copy: replace any legalistic language with direct friendly copy ("Documents verified ✓", "Licensed electrician").

**Work — own profile / settings:**
1. Read `profile_screen.dart` in full.
2. Editable fields: ensure `InputDecoration.filled = true` with white/surface fill, 56px height. Non-editable fields: `filled = true` with a subtle grey fill (`THColors.paper` or similar subdued surface) to indicate read-only.
3. Phone field style must match other editable fields.
4. Add a pencil icon (`Icons.edit_outlined`) to toggle edit mode on own profile.
5. Read `settings_screen.dart`. Group settings into `FixoCard` sections with 56px rows. Log out button at the bottom in a destructive style (red text, no fill).

**Key files:** `views/profile/public_profile_screen.dart`, `views/profile_screen.dart`, `views/settings_screen.dart`  
**Exit:** "No reviews yet" appears at most once as "New to TradieHunter". Editable fields look editable. Settings are grouped.

---

#### V16-17 — Dark mode refinement

**Existing baseline:** Dark mode works but may have light-grey 1.5px container outlines and unverified contrast on some text pairs.

**Work:**
1. Grep for `BorderSide(color:` in widget files. For any border in a dark-mode branch that uses a hardcoded light-grey color (e.g., `Colors.white12`, `Color(0xFFE0E0E0)`), replace with `THColors.line` token access.
2. Orange CTAs: verify `THColors.accent` (amber `#E38B29`) against `THColors.paper` dark (`#14181B`). The ratio must be ≥4.5:1. If the contrast check reveals a failure, adjust the CTA text colour — not the brand amber — to `THColors.onBrand` or white.
3. **Waiting pill in dark mode (confirmed fix):** Update `StatusBadge.resolveVisuals` in `fixo_cards.dart` for `FixoBadgeKind.waiting` in dark mode: fill must be `brand300.withOpacity(0.28)` (not the 12% light-mode value) and text colour must be `Colors.white`. This was confirmed in the HANDOFF.md design session.
4. Spot-check all 6 pill variants in dark mode for ≥4.5:1 contrast between pill text and tinted fill.
5. Progress bar segments: in dark mode, filled segment uses `THColors.brand` (`blue300 #89AFD2`) and track uses `THColors.track`. Verify they are visually distinct.
6. Tonal buttons in dark mode: `THColors.tintBrand` at 20% opacity over dark surface. Verify the button label is readable.
7. Screenshot comparison at reference sizes in both themes for ≥10 screens before/after to document the change.

**Key files:** All widget/view files that contain dark-mode branches, `widgets/fixo_cards.dart`, `theme/design_tokens.dart`  
**Exit:** No hardcoded grey borders in dark mode. All text pairs ≥4.5:1 contrast. Waiting pill uses 28% tint + white text in dark.

---

### Phase E — iPad layout (V16-18)

Depends on Phase A, Phase C/D (jobs and messages screens must be stable before the panel split is added).

#### V16-18 — iPad responsive layout

**Existing baseline:** `main_layout.dart` has a left rail at ≥1024pt (`kBreakpointLeftRail`). No master-detail panel split at 744pt exists. No `ResponsiveContainer` max-width wrapper.

**Work:**
1. Add a `ResponsiveContainer` widget to `mobile/lib/widgets/fixo_states.dart` (or a new `responsive_container.dart` beside it):
   ```dart
   class ResponsiveContainer extends StatelessWidget {
     final Widget child;
     const ResponsiveContainer({super.key, required this.child});
     @override
     Widget build(BuildContext context) {
       return Center(
         child: ConstrainedBox(
           constraints: const BoxConstraints(maxWidth: 640),
           child: child,
         ),
       );
     }
   }
   ```
   Wrap form and list screens (post a job, jobs list, messages list, settings) with this container.

2. Jobs master-detail at ≥744pt:
   - Add a breakpoint constant `kBreakpointMasterDetail = 744.0` to `fixo_states.dart`.
   - In `views/jobs/jobs_list_screen.dart`, wrap the screen body with a `LayoutBuilder`. At ≥744pt, render a `Row`: left 360px fixed-width panel with the jobs list, right panel expands to fill remaining width and shows the selected job detail (reusing `homeowner_job_detail_screen.dart`'s detail body as a widget, not a full route push).
   - Selection state: maintain a `selectedJobId` local state. When a job is tapped in the left panel, update `selectedJobId` instead of pushing a route. If null, show a "Select a job to view details" placeholder in `FixoEmptyState` style.
   - Below 744pt: same full-screen push behaviour as today.

3. Messages master-detail at ≥744pt:
   - Same pattern in `views/chat/messages_list_screen.dart`: 360px left panel (conversation list), right panel shows `chat_screen.dart`'s chat body.
   - Selection state: `selectedJobId`.

4. Left rail (≥1024pt): already implemented in `main_layout.dart`. Verify the rail is 64px wide, icons + labels, active state highlighted, and that it does not conflict with the master-detail panel structure.

5. Chat at any width: message column max-width 640px, centred.

6. All existing <744pt behaviour must be unchanged.

**Key files:** `widgets/fixo_states.dart`, `views/main_layout.dart`, `views/jobs/jobs_list_screen.dart`, `views/chat/messages_list_screen.dart`, `views/chat/chat_screen.dart`  
**Exit:** No stretched phone layout on iPad. Master-detail at ≥744pt. Left rail at ≥1024pt. Content max-width 640px.

---

### Phase F — Verification (V16-19, V16-20)

Run after all implementation phases are complete. These were recorded as passing in the tasks.md against the spec/design phase; re-run them against the implemented code.

#### V16-19 — Accessibility and cross-device verification

1. `flutter analyze` — expect 0 warnings, 0 errors, ≤9 infos.
2. `flutter test` — all tests pass including new tests added in V16-03–V16-18.
3. Run `accessibility_audit_test.dart` specifically — all 567 assertions pass (or higher if new tests were added).
4. Verify all interactive elements ≥48×48 using Flutter's accessibility inspector or the test harness `SemanticsChecker`.
5. Verify all text pairs ≥4.5:1 contrast in both themes using the `theme_test.dart` contrast checks.
6. Test at text scales 1.0, 1.3, 2.0 on 320px width — no clipped or overlapping controls.
7. Capture fresh screenshots at reference sizes (402×874 homeowner, 440×956 tradie) in light and dark.
8. Compare captures to AC-01–AC-08 in `specification.md §6`.

---

#### V16-20 — Regression harnesses and release evidence

1. `flutter test` — full suite passes with updated golden files for intentional visual changes.
2. Backend build — 0 errors (no backend changes in this spec; confirm no accidental drift).
3. `p3-smoke.sh` — all P3 scenarios green.
4. `p4-smoke.sh` — all P4 scenarios green.
5. `e2e-credentials.py` — all checks pass.
6. `AddressResolutionTests.csproj` — all assertions pass.
7. `EarningsTests.csproj` — all assertions pass.
8. Mobile address resolution tests — all pass.
9. Update golden files only for intentional v1.6 visual changes (border styles, pill shapes, button styles). Do not auto-update all goldens blindly — review each diff before accepting.
10. Record known issues and approved deviations.

---

## 4. What is not in scope

Carry-forward from v1.5 — do not implement without explicit sign-off:

- New API endpoints or backend contract changes
- New third-party packages beyond those already in `pubspec.yaml`
- Animated transitions (radar pulse, shared-element avatar/price) — those are prototype-layer design artefacts; static layout is the deliverable
- In-app payments, BNZ integration, automated dispute resolution, ML matching, loyalty/referrals
- Any new navigation routes — all screens covered by existing routes

---

## 5. Handoff gates per task

Visual design frames are hand-authored HTML files in `docs/design/v1.6/html/`. Open them directly in a browser — no build step, no sprite sheet required (all icons are inline SVG since the v1.7 design session). Token source of truth: `docs/design/v1.6/html/kit.css`, `docs/design/v1.6/tokens/tokens.json`, and `docs/design/v1.6/tokens/design_tokens.dart`.

Inspect the relevant frame before implementing each screen. If a frame contradicts this plan, flag the discrepancy — do not resolve silently.

| Implementation task | Reference frame file | Frame IDs |
|---|---|---|
| V16-03 (status pills) | `component-sheet.html` or `frames-components.html` | `cmp-status-pills-light/dark` |
| V16-04 (progress bar) | `component-sheet.html` or `frames-components.html` | `cmp-progress-bar-light/dark` |
| V16-05 (containers) | `component-sheet.html`; any screen file | `cmp-card-light/dark` |
| V16-06 (typography) | `style-tile.html` | Type specimen section |
| V16-07 (tonal buttons) | `frames-components.html` | `cmp-buttons-light/dark` |
| V16-08 (lead card + request detail) | `frames-tradie.html` | `T19-light`, `T19-dark`, `T21-light` |
| V16-09 (homeowner dashboard) | `frames-homeowner.html` | `H07-light`, `H07-dark`, `H07-empty-light`, `H07-empty-dark` |
| V16-10 (match result) | `frames-homeowner.html` | `H11-light` |
| V16-11 (job detail grouping) | `frames-homeowner.html`, `frames-tradie.html` | `H12-inprogress-light/dark`, `H12-dispute-light`, `T22-booked-light`, `T22-inprogress-light` |
| V16-12 (chat + messages list) | `frames-homeowner.html`, `frames-tradie.html` | `H13-light/dark`, `T23-light`, `H18-messages-light` |
| V16-13 (post a job) | `frames-homeowner.html` | `H09-light` |
| V16-14 (entry + onboarding) | `frames-entry.html` | `S02–S04`, `S06` |
| V16-15 (profiles + settings) | `frames-homeowner.html`, `frames-tradie.html` | `H17-rated-light`, `H17-new-light`, `H18-profile-light`, `H18-settings-light`, `T24-light`, `T26-light` |
| V16-16 (tradie wizard + active job) | `frames-tradie.html` | `T22-booked-light`, `T22-inprogress-light`, `T25-step1..4-light` |
| V16-17 (dark mode) | `frames-homeowner.html`, `frames-tradie.html` | All `*-dark` frames |
| V16-18 (iPad) | `frames-ipad.html` | `IPAD-dashboard-light/dark`, `IPAD-rail-light/dark`, `IPAD-messages-light/dark` |

### Confirmed design decisions from HANDOFF.md

These are now settled — implement them directly, no further sign-off needed:

**Icons — inline SVG only.** All button and pill icons are inline SVG paths, not sprite references. In Flutter use `Icon(Icons.*)` or a local `SvgPicture.asset` — do not depend on any external icon sprite sheet. Specific icon assignments from the handoff:
- Pill icons: exclamation (`Icons.error_outline`), play (`Icons.play_arrow_rounded`), alert (`Icons.warning_amber_rounded`), clock (`Icons.schedule_rounded`), check (`Icons.check_rounded`)
- `FixoTonalButton` icons: Navigate → compass (`Icons.navigation_outlined`), Message → chat bubble (`Icons.chat_bubble_outline`), Call → phone (`Icons.phone_outlined`), Check In → pin (`Icons.place_outlined`), Check Out → check (`Icons.check_circle_outline`)
- FAB `+` → `Icons.add`
- Nav tabs (Home, Jobs, Messages, Profile) → existing icon assignments, unchanged

**Sticky CTA bar pattern.** Every screen's primary/secondary/ghost actions are in a bottom-pinned sticky bar. Content above uses `Expanded`/`Flexible` to push the sticky bar to the bottom. Screens to verify: H15 payment status variants (review, rejected, expired, success) all need a sticky CTA — add `StickyActionBar` if missing.

**Send button.** Chat composer send button icon: right-facing paper plane — `Icons.send` (flat, no tilt). Already correct if using Material icons.

**Homeowner dashboard H07 redesign.** The frame shows a substantial header redesign:
- **Hero band**: navy gradient background with `bpdots` texture and rings watermark, small-caps "GOOD MORNING" label, 28px Display name, frosted location pill, bell icon with amber unread dot.
- **Attention cards**: job title as headline (17px Space Grotesk Display font), tradie name secondary, price/time separated by a hairline divider, progress shown as 4 dot indicators (6px each) + "Step X of 4" label — *not* the full `CompactProgressBar` widget on attention cards.
- **Booked section**: compact list row inside a single `FixoCard` (avatar + job title + dot indicators + price), "Open chat" tonal button below a hairline.
- **Attention card gradient**: `background: LinearGradient` from `brand.withOpacity(0.18)` at top to `brand.withOpacity(0.06)` at 40% to transparent — no left-border accent stripe.
- **Empty states**: hero band + illustration with drop shadow, "Find a tradie you can trust" headline, 3-stat row (`< 5 min`, `100%`, `Fixed price`), full-width "Post a job" primary CTA.

**Dark mode pill tweak.** `.pill-waiting` in dark mode uses a brighter tint and pure white text for contrast. In Flutter: `StatusBadge` in dark mode for `FixoBadgeKind.waiting` — verify the tint fill uses `brand300.withOpacity(0.28)` (not the 12% used in light mode) and text colour is `Colors.white`.

**Token rules (confirmed).** These are the settled values from `kit.css` — verify Flutter tokens match:
- Spacing: 4pt scale, gutter 20pt (`Space.gutter`)
- Radii: card 20 (`Radii.card`), control 14 (`Radii.control`), tile 16 (`Radii.tile`), sheet 28 (`Radii.sheet`)
- Tap targets: 48dp minimum (`Sizes.tapMin`); chips draw 40dp but hit area padded to 48dp
- Button heights: primary 56dp (`Sizes.button`), secondary 52dp (`Sizes.buttonSecondary`), tonal/ghost 48dp (`Sizes.tapMin`)
- One amber primary CTA per screen only
- Selection state: 2dp brand border + tint fill + check — **amber never means selected**
- Green = verified/done; Red = problem/dispute; Orange = CTA and one urgency element only
- Nav bar: 68dp height (`Sizes.nav`), equal slots, 56dp FAB inside centre slot (homeowner only), 4 tabs for tradie (no FAB)
- Dark mode: token swaps only. Outdoor mode: light tokens + flat surfaces, no blur, outlines for elevation

---

## 6. Open items requiring product sign-off before implementation

The following items are listed in `docs/design/v1.6/docs/HANDOFF.md` as unresolved. Until sign-off is received, use the stated interim behaviour.

| Item | Interim behaviour |
|---|---|
| **FAB colour** — navy vs amber | Use amber (`THColors.accent`) — existing behaviour |
| **First lead Accept button** — first lead amber, later ones navy | Use amber for all Accept buttons — existing behaviour |
| **Awaiting-payment progress** — navy or amber progress fill | Use `actionNeeded` amber tint — consistent with pill colour |
| **HIGH urgency tag** — solid navy or solid amber | Use solid navy (`THColors.brand`) — matches the handoff note |
| **Pill/CTA copy split** — pills show status label, CTAs show action verb | Apply this rule: pills display state ("In progress"), buttons display action ("Open chat") — this is already the `JobStatusPresentation` contract |

None of these block Phase A foundation work. Items 1–3 must be resolved before V16-08 (tradie dashboard lead cards) and V16-09 (homeowner dashboard) are considered complete. Item 5 (pill/CTA split) is straightforward to implement now without waiting for sign-off.
