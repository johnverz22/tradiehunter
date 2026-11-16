# Fixo Mobile UI Sprint — Task & Execution Status

**Document Created:** 2026-11-09  
**Branch / Target:** `main`  
**Mobile Directory:** `mobile/`  
**Execution Mode:** Review-driven development. One task group at a time. No parallel subagents.  
**Design Reference:** `docs/design/v1.6/html/frames-homeowner.html`, `docs/design/v1.6/html/frames-tradie.html`, `docs/design/v1.6/docs/HANDOFF.md`, `html/kit.css`. Mockups excluded.

---

## 1. Sprint Overview & Status Summary

| Work Stream | Task ID | Name / Description | Target File(s) | Status | Commit SHA |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Homeowner UI** | **Task 0** | Type Scale & Design Tokens | `mobile/lib/theme/design_tokens.dart` | **Completed** ✅ | `abbc0d1` |
| **Homeowner UI** | **Task 1** | Homeowner Dashboard (H07) | `mobile/lib/views/homeowner/homeowner_dashboard_view.dart` | **Completed** ✅ | `0615d96` |
| **Homeowner UI** | **Task 2** | Matching Screen (H10) | `mobile/lib/views/matching/matching_screen.dart` | **Completed** ✅ | `46b5d1d` |
| **Homeowner UI** | **Task 3** | Match Result Screen (H11) | `mobile/lib/views/matching/match_result_screen.dart` | **Completed** ✅ | `c67fae7` |
| **Homeowner UI** | **Task 4** | Chat `sentByMe` User ID Resolution & Tokens | `mobile/lib/viewmodels/chat_viewmodel.dart`, `mobile/lib/views/chat/chat_screen.dart`, `mobile/lib/views/widgets/chat_widgets.dart` | **Completed** ✅ | `82d44ae` |
| **Homeowner UI** | **Task 5** | Job Detail Progress Banner & On-Dark Badge | `mobile/lib/widgets/fixo_cards.dart`, `mobile/lib/views/widgets/status_strip.dart`, `mobile/lib/views/homeowner/homeowner_job_detail_screen.dart` | **Completed** ✅ | `bc2540e` |
| **Tradie UI** | **Task 6** | Tradie Request Detail Screen | `mobile/lib/views/tradie/request_detail_screen.dart` | **Completed** ✅ | `02662b6` |
| **Tradie UI** | **Task 7** | Tradie Active Job Screen | `mobile/lib/views/tradie/tradie_job_detail_screen.dart` | **Completed** ✅ | `02662b6` |
| **Notice System** | **Task 8** | FixoNotice Feedback System (48 SnackBar replacements) | `mobile/lib/feedback/*`, call sites | **Completed** ✅ | Pending |
| **Tradie UI** | **Task A** | Tradie Home Hero & Sliding Availability Switch | `mobile/lib/views/tradie/tradie_dashboard_view.dart`, `mobile/lib/views/widgets/sliding_availability_switch.dart` | **Completed** ✅ | Pending |
| **Tradie UI** | **Task B** | Shared Job Card for Home and Jobs (`TradieJobCard`) | `mobile/lib/views/widgets/tradie_job_card.dart`, `mobile/lib/views/tradie/tradie_dashboard_view.dart`, `mobile/lib/views/jobs/jobs_list_screen.dart` | **Completed** ✅ | Pending |
| **Global UI** | **Task C** | Filter Pill Contrast & Consistency (`FixoFilterPill`) | `mobile/lib/views/widgets/fixo_filter_pill.dart`, `mobile/lib/views/widgets/fixo_filter_bar.dart`, `mobile/lib/theme/fixo_theme.dart` | **Completed** ✅ | Pending |
| **Web Admin** | **Task D** | Web Admin Job Progress Stepper | `web/src/utils/jobProgress.ts`, `web/src/components/JobProgressStepper.tsx`, `web/src/features/jobs/hooks/useJobs.ts`, `web/src/features/jobs/pages/JobDetailPage.tsx`, `web/src/theme/components.css`, `web/e2e/job-progress.spec.ts` | **Completed** ✅ | Pending |

---

## 2. Detailed Task Breakdown & Implementation Details

### ✅ Task 0: Type Scale (`abbc0d1`)
- Standardized typography scale in `mobile/lib/theme/design_tokens.dart`.
- Fixed token classes: `Space`, `Radii`, `Sizes`, `FW`, `Alpha`, `FixoDurations`, `Tracking`, `THColors`.

### ✅ Task 1: Homeowner Dashboard (`0615d96`)
- Rebuilt hero band: navy gradient, brand pattern dots, `GOOD MORNING` small-caps, 28px Display name, location pill, unread notification dot.
- Attention cards: headline 17px, secondary tradie name, hairline rule, 4×6px progress dot indicators + "Step X of 4".
- Booked section and empty state variants (light + dark) with trust stat row.

### ✅ Task 2: Matching Screen (`46b5d1d`)
- Centered 3-ring pulsing radar animation with reduced-motion support.
- Trade category indicator and tokenised layout.

### ✅ Task 3: Match Result Screen (`c67fae7`)
- Replaced stack overlap layout with clean Flex structure to prevent text clipping at 1.3× and 2.0× font scale.
- Verified avatar overlap, price/time layout, and truthful tradie data presentation.

### ✅ Task 4: Chat `sentByMe` User ID Resolution & Tokens (`82d44ae`)
- Added tokens: `Sizes.inboxTileMin = 72.0`, `Sizes.unreadBadgeMin = 20.0`, `Sizes.chatVerifiedBadge = 16.0`, `Sizes.chatVerifiedBadgeIco = 9.0`, `Sizes.borderWidthVerified = 1.5`, `Sizes.chatBubbleFullR = 20.0`, `Sizes.chatBubbleTailR = 4.0`, `Sizes.dotPatternSpacing = 20.0`, `Sizes.dotPatternRadius = 1.5`, `Sizes.fabSend = 48.0`, `Sizes.iconSend = 24.0`, `Sizes.inboxAvatarSm = 44.0`, `Sizes.inboxAvatarSmBadge = 16.0`, `DesignTokens.chatSendShadow`.
- Fixed GUID comparison in `chat_viewmodel.dart` (`_tag()`, `_onHubMessage()`, `_markIncomingRead()`) to be case-insensitive.
- Added `sub` claim fallback in `_decodeUserId()`.
- Tokenised all raw literals in `chat_screen.dart` and `chat_widgets.dart`.
- Added 3 unit tests for case-insensitive GUID matching in `test/chat_screens_test.dart` (27/27 passed).

### ✅ Task 5: Job Detail Progress Banner (`bc2540e`)
- Added tokens: `Sizes.iconLg = 24.0`, `Sizes.statusBadgeH = 28.0`, `Sizes.stepNode = 24.0`, `Sizes.stepNodeCol = 28.0`, `Sizes.iconInfo = 16.0`, `Sizes.chipIconGap = 5.0`.
- Added `onDark: true` parameter and `resolveVisualsOnDark()` to `StatusBadge` in `fixo_cards.dart` per `kit.css` `.status-strip .pill` rules (`rgba(255,255,255,0.16)` fill + white text; surface/white fill + danger text for `problem`).
- Updated `mobile/lib/views/widgets/status_strip.dart` to pass `onDark: true` to `StatusBadge` and tokenised all step nodes and lines.
- Tokenised hardcoded numeric literals in `mobile/lib/views/homeowner/homeowner_job_detail_screen.dart`.
- Added widget test coverage for `StatusBadge` `onDark` variant in `mobile/test/status_badge_test.dart`.

### ✅ Task 6: Tradie Request Detail Screen
- **Target File:** `mobile/lib/views/tradie/request_detail_screen.dart`, `mobile/lib/views/widgets/offer_countdown.dart`
- **Tokens Added:** `Sizes.iconAction = 20.0`, `Sizes.photoThumb = 90.0`, `Sizes.photoThumbW = 120.0`, `Sizes.expiryBarHeight = 48.0`, `Sizes.expiryProgressH = 8.0`, `Sizes.iconEmpty = 72.0`, `Sizes.photoMinScale = 1.0`, `Sizes.photoMaxScale = 4.0`.
- **Implemented:**
  1. Redesigned layout hierarchy per T21 frame: prominent display price, live offer countdown, title + category badge, estimated rate breakdown, address card with truthful privacy notice, schedule card, description, photo gallery, and sticky action bar.
  2. Implemented expiry colour thresholds in `OfferCountdown`: `> 2 min` neutral/brand (`colors.brand`), `≤ 2 min` amber/urgent (`colors.accent`), `≤ 30s` danger (`DesignTokens.inkDanger(isDark)`).
  3. Photo horizontal scroll with full-screen `InteractiveViewer` image inspection and accessible close button (zero new 3rd-party dependencies).
  4. Sticky bottom action bar: Decline (1/3 width, flex: 1, `FixoGhostButton`) | Accept Job (2/3 width, flex: 2, `FixoPrimaryButton`, amber primary).
  5. 100% tokenised numeric literals across `request_detail_screen.dart` and `offer_countdown.dart`.
  6. Verified with 23/23 tests passing in `offer_response_test.dart` and 0 `flutter analyze` errors.

### ✅ Task 7: Tradie Active Job Screen
- **Target Files:** `mobile/lib/views/tradie/tradie_job_detail_screen.dart`, `mobile/lib/views/widgets/status_strip.dart`, `mobile/lib/views/widgets/compact_progress_bar.dart`
- **Tokens Added:** `Sizes.handleW = 40.0`, `Sizes.handleH = 4.0`, `Sizes.avatarRadius = 24.0`.
- **Implemented:**
  1. Removed duplicate `FixoCard` containing `JobTimeline` from `ListView` body — status and expandable timeline are natively hosted in `StatusStrip`.
  2. Extracted notices stack (`_buildNotices`): urgency, awaiting confirmation, completed, cancelled, and dispute notices render directly at the top of the body with semantic spacing.
  3. Polished `StatusStrip`:
     - Caption tap target guaranteed ≥ 48dp (`Sizes.tapMin`).
     - Deduplicated status caption when matching `StatusBadge` (e.g. `Step 2 of 4` without repeating `· Booked`).
     - Verified status icons wired from `JobStatusPresentation.chipIcon`.
     - Right-aligned monospace job code (`DesignTokens.fontSizeMono`, `DesignTokens.fontMono`) copyable to clipboard on long-press with confirmation feedback.
  4. 100% tokenised numeric literals across `tradie_job_detail_screen.dart` and `status_strip.dart`.
  5. Added comprehensive widget tests in `mobile/test/tradie_job_detail_test.dart` (28/28 passed).

---

### ✅ Task 8: FixoNotice Feedback System
- **Target Files:**
  - `mobile/lib/feedback/fixo_notice.dart` (public façade + `FixoNoticeHost` component)
  - `mobile/lib/feedback/fixo_notice_controller.dart` (Riverpod `StateNotifier`)
  - `mobile/lib/feedback/notice_copy.dart` (centralised copy strings)
  - `mobile/lib/feedback/notice_gallery.dart` (debug-only gallery route `/debug/notice-gallery`)
  - `mobile/lib/theme/design_tokens.dart` (notice dimensions & auto-dismiss durations)
  - `mobile/test/fixo_notice_test.dart` (unit tests + static lint check for zero SnackBar usages)
  - 14 call-site files migrated across mobile app
- **Implemented:**
  1. **8-A:** Created `docs/design/feedback-guidelines.md` classification table covering tones (info, success, warning, error, push), auto-dismiss durations, placement, sentence casing, and rules.
  2. **8-B:** Added notice tokens to `design_tokens.dart`: `Sizes.noticeIconSize = 20.0`, `Sizes.noticeCloseSize = 20.0`, `Sizes.noticeMinH = 52.0`, `Sizes.noticeHPad = 16.0`, `Sizes.noticeVPad = 10.0`, `Sizes.noticeBorderW = 1.0`, and durations `FixoDurations.noticeInfo`, `noticeSuccess`, `noticeWarning`, `noticeError`, `noticePush`, `noticeAnimate`.
  3. **8-C:** Built `FixoNoticeController` (`StateNotifier<FixoNoticeState?>`) and `fixoNoticeProvider`.
  4. **8-D:** Built `FixoNoticeHost` widget attached above root router builder with smooth slide & fade animation, plus zero-overhead fallback overlay support for isolated widget test trees.
  5. **8-E:** Built `FixoNotice` public static API (`info`, `success`, `warning`, `error` with optional `onRetry`, `push` with optional `onView`) and `NoticeCopy` string dictionary.
  6. **8-F:** Added debug gallery route `/debug/notice-gallery` registered only in `kDebugMode`.
  7. **8-G:** Migrated all 48 SnackBar call sites across all views and interceptors (preserved clipboard copy feedback via `FixoNotice.info`).
  8. **8-H:** Static lint check in `fixo_notice_test.dart` asserting 0 occurrences of `ScaffoldMessenger.of`, `showSnackBar`, or `SnackBar(` across `lib/`.
  9. **8-I:** Full mobile test suite passes with 696/696 tests passing and 0 `flutter analyze` errors.

---

### ✅ Task A: Tradie Home Hero & Sliding Availability Switch
- **Target Files:** `mobile/lib/views/tradie/tradie_dashboard_view.dart`, `mobile/lib/views/widgets/sliding_availability_switch.dart`, `mobile/lib/theme/design_tokens.dart`
- **Tokens Added:** `Sizes.availabilityTrackW = 112.0`, `Sizes.availabilityTrackH = 44.0`, `Sizes.availabilityThumb = 36.0`, `Sizes.availabilityThumbPad = 4.0`, `Sizes.availabilityGlowSpread = 2.0`, `Sizes.availabilityGlowBlur = 8.0`, `FixoDurations.availabilitySwitch = 280ms`, `FixoDurations.switchShake = 300ms`.
- **Implemented:**
  1. Rebuilt hero structure (`_TradieHero`) with clean vertical rhythm:
     - Net block: caption "Net this week", large net figure, decorative background sparkline.
     - Two stat tiles (Pending, Rating) side-by-side with identical equal-width & equal-height layout, shared money formatting, and truthful review counts / zero-state captions.
     - Full-width translucent availability strip at the bottom with title, subtitle, and sliding switch.
  2. Implemented `SlidingAvailabilitySwitch` (112×44dp pill track with sliding thumb):
     - Online: green track, thumb right with check/signal icon, soft glow ring.
     - Offline: neutral track, thumb left with power/signal-off icon.
     - Drag past 50% commits toggle; tap toggles immediately; light haptic on commit.
     - Optimistic loading spinner inside thumb; shake rollback animation on API error.
     - Offline confirm sheet preserved when active jobs/leads exist; cancels rollback cleanly.
     - Accessible semantics with `isButton`, `isToggled`, value, and double-tap hint.
  3. Verified with `mobile/test/sliding_availability_switch_test.dart` (9/9 passed) and `mobile/test/tradie_dashboard_redesign_test.dart` (38/38 passed).

---

### ✅ Task B: Shared Job Card for Home and Jobs (`TradieJobCard`)
- **Target Files:** `mobile/lib/views/widgets/tradie_job_card.dart`, `mobile/lib/views/tradie/tradie_dashboard_view.dart`, `mobile/lib/views/jobs/jobs_list_screen.dart`
- **Implemented:**
  1. Promoted `_TodayJobCard` into a single shared widget `TradieJobCard` used across Tradie Home (Today, scheduled/expansion sections) and Jobs screen (Today, Upcoming, Awaiting payment, Done, All).
  2. Card anatomy:
     - Title (max 2 lines) with trailing `StatusChip` from `job_status_presentation.dart`.
     - Single muted line for trade and suburb (`${job.category} · ${job.suburb}`).
     - Monospace job code reference.
     - Price on left, schedule right-aligned ("Wed 4 Nov" over "3:45 PM", relative Today/Tomorrow).
     - `CompactProgressBar` segmented step indicator with "Step X of 4" caption.
     - Single primary action CTA only when tradie must act now (Accept, Check in, Check out, Mark complete); otherwise subtle chevron. Full card tappable.
     - Overdue warning styling (amber border and warning badge) for booked jobs past their scheduled time.
  3. Replaced all tradie usages of `ModernJobCard`.
     > [!NOTE]
     > `ModernJobCard` remains used only by homeowner views (`mobile/lib/views/widgets/homeowner_job_summary.dart` and `mobile/lib/views/homeowner/homeowner_dashboard_view.dart`) pending homeowner job card unification.
  4. Verified with `mobile/test/tradie_job_card_test.dart` (40/40 passed) covering all statuses, light/dark themes, 1.0× and 1.3× text scale.

---

### ✅ Task C: Filter Pill Contrast & Consistency (`FixoFilterPill`)
- **Target Files:** `mobile/lib/views/widgets/fixo_filter_pill.dart`, `mobile/lib/views/widgets/fixo_filter_bar.dart`, `mobile/lib/theme/fixo_theme.dart`, `mobile/lib/views/jobs/jobs_list_screen.dart`, `mobile/lib/views/jobs/post_job_screen.dart`
- **Tokens Added:** `Sizes.filterPillMinH = 48.0`, `Sizes.filterPillH = 38.0`.
- **Implemented:**
  1. Created `FixoFilterPill`:
     - Selected: solid navy (`brand900`) fill in light, raised brand tone (`brand700`) in dark, white text, white checkmark icon. No peach/amber.
     - Unselected: surface fill, hairline border token, ink text.
     - Guaranteed ≥ 48dp tap target.
  2. Created `FixoFilterBar`:
     - Single horizontally scrollable row for both tradie and homeowner filter lists (replacing multi-line Wrap).
     - Fading edge shader hints at scroll bounds.
     - Auto-scrolls selected pill into view on change.
  3. Fixed global `chipTheme` in `mobile/lib/theme/fixo_theme.dart` as a system-wide safety net:
     - Sets `selectedColor`, `secondaryLabelStyle`, `checkmarkColor`, `side`, and disabled colors from design tokens.
  4. Migrated all 3 `ChoiceChip` call sites: `jobs_list_screen.dart` (homeowner & tradie) and `post_job_screen.dart` (urgency grid).
  5. Verified with `mobile/test/filter_pill_contrast_test.dart` (11/11 passed) asserting WCAG contrast ratio ≥ 4.5:1 across light and dark for selected, unselected, and disabled states.

---

### ✅ Task D: Web Admin Job Progress Stepper
- **Target Files:** `web/src/utils/jobProgress.ts`, `web/src/components/JobProgressStepper.tsx`, `web/src/features/jobs/hooks/useJobs.ts`, `web/src/features/jobs/pages/JobDetailPage.tsx`, `web/src/theme/components.css`, `web/e2e/job-progress.spec.ts`
- **Root Causes Fixed:**
  1. `STEP_INDEX` mapped non-existent statuses (`Draft`, `Matching`, `Matched`, `Confirmed`, `Complete`). `Booked`, `AwaitingConfirmation`, and `Completed` all fell to step 0.
  2. `isComplete` compared to `'Complete'` (never matched the actual `'Completed'` value).
  3. Cancelled/Expired/Disputed always showed step 0 instead of the last reached step.
  4. No polling — stepper was stale while the page was open.
  5. Labels differed from mobile (`Matched`, `Confirmed`, `Complete` vs. `Booked`, `In progress`, `Done`).
  6. `step-line` was drawn on every step including the last, causing overflow.
- **Implemented:**
  1. **`web/src/utils/jobProgress.ts`**: `getJobProgress(status, statusHistory)` utility:
     - Maps Requested/AwaitingPayment/PaymentReview → step 1 (index 0), Booked → step 2, InProgress/AwaitingConfirmation → step 3, Completed → step 4.
     - Step labels match mobile: Requested, Booked, In progress, Done.
     - Sublabels under the active step: "Awaiting payment", "Payment review", "Awaiting confirmation".
     - Terminal statuses derive reached step from `statusHistory` last non-terminal `toStatus`; falls back to step 1 if history is empty.
     - Unknown statuses fall back to step 1 with a `console.warn` in dev mode.
     - Returns `{ steps, currentIndex, state, label, sublabel, summary }`.
  2. **`web/src/components/JobProgressStepper.tsx`**: Extracted reusable stepper component:
     - ARIA semantics: `role="list"`, `role="listitem"`, `aria-current="step"`, `sr-only` summary.
     - Sublabel shown under active dot.
     - Accepts `updatedCaption` slot for "Updated X ago" + refresh button.
     - Responsive: `overflow-x-auto` down to 320px.
  3. **`web/src/features/jobs/hooks/useJobs.ts`**: Live query:
     - `refetchInterval: 15_000` for non-terminal jobs; `false` for Completed/Cancelled/Expired/Disputed.
     - `refetchOnWindowFocus: true`, `refetchIntervalInBackground: false`.
  4. **`web/src/features/disputes/hooks/useDisputes.ts`** / **`useRefunds.ts`**: Invalidate `['admin', 'jobs']` on dispute resolve and refund process so the detail stepper refreshes immediately.
  5. **`web/src/features/jobs/pages/JobDetailPage.tsx`**: Replaced inline broken stepper with `<JobProgressStepper />`, added "Updated X ago" caption with spinning refresh button.
  6. **`web/src/theme/components.css`**: Stepper CSS rewritten:
     - Connector for step i fills when step i+1 is reached (`.step-line--filled`).
     - Last step (Done) has no connector (`display: none` on `:last-child .step-line`).
     - Terminal states: `.step-dot--cancelled` (red), `.step-dot--expired` (amber), `.step-dot--disputed` (red/amber).
     - 200ms `transition` on all state changes; `prefers-reduced-motion: reduce` disables transitions.
  7. **`web/e2e/job-progress.spec.ts`**: Playwright tests:
     - 4-step label rendering; active step for Booked, InProgress, AwaitingConfirmation, Completed, Cancelled.
     - ARIA `role="list"` and `aria-current="step"` present; sr-only summary text matches "Step N of 4".
     - Refresh button visible, enabled, and triggers a network request.
     - Last step (Done) connector overflow check.
  8. **Build:** `npm run build` exits 0; `npm run lint` exits 0 (1 pre-existing warning in `App.tsx`, unrelated).

---

## 3. Sprint Summary & Next Steps

All sprint tasks (Tasks 0–8, A–D) are now **100% complete**:
- ✅ Task 0: Type Scale & Design Tokens
- ✅ Task 1: Homeowner Dashboard
- ✅ Task 2: Matching Screen
- ✅ Task 3: Match Result Screen
- ✅ Task 4: Chat `sentByMe` GUID Resolution & Tokens
- ✅ Task 5: Job Detail Progress Banner & On-Dark Badge
- ✅ Task 6: Tradie Request Detail Screen
- ✅ Task 7: Tradie Active Job Screen
- ✅ Task 8: FixoNotice Feedback System (complete SnackBar deprecation)
- ✅ Task A: Tradie Home Hero & Sliding Availability Switch
- ✅ Task B: Shared Job Card (`TradieJobCard`) for Home and Jobs
- ✅ Task C: Filter Pill Contrast & Consistency (`FixoFilterPill`)
- ✅ Task D: Web Admin Job Progress Stepper (correct mapping, live polling, CSS fix)

### Remaining Homeowner Card TODO
`ModernJobCard` is still used in homeowner views only:
- `mobile/lib/views/widgets/homeowner_job_summary.dart`
- `mobile/lib/views/homeowner/homeowner_dashboard_view.dart`

A future sprint should unify these into a shared `HomeownerJobCard` and remove `ModernJobCard`.

---

## 4. Quality & Compliance Checklist

- [x] **No hardcoded values:** All colors, spacing, font sizes, radii, shadows, and dimensions come from `design_tokens.dart`.
- [x] **Both light and dark themes:** Supported and tested for all modified screens.
- [x] **Text scaling:** Resilient at 1.3× scale without layout overflow or clipped text.
- [x] **Touch targets:** Interactive controls satisfy ≥ 48dp (`Sizes.tapMin`).
- [x] **Truthful presentation:** Never fabricate missing tradie data or status fields.
- [x] **Backend safety:** `dotnet` commands run only inside the API Docker container.
- [x] **Analysis clean:** `flutter analyze` passes with 0 errors.
