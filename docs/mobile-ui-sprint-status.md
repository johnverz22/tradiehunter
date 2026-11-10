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
| **Tradie UI** | **Task 7** | Tradie Active Job Screen | `mobile/lib/views/tradie/tradie_job_detail_screen.dart` | **Next Up** ⏳ | Pending |
| **Notice System** | **Task 8** | FixoNotice Feedback System (48 SnackBar replacements) | `mobile/lib/feedback/*`, call sites | Pending ⏳ | Pending |

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

## 3. Pending Tasks

### ⏳ Task 8: FixoNotice Feedback System (48 SnackBar replacements)
- **Sub-tasks:**
  - **8-A:** Write `docs/design/feedback-guidelines.md` classification table.
  - **8-B:** Add notice tokens to `design_tokens.dart`.
  - **8-C:** Build `FixoNoticeController` (Riverpod `StateNotifier`).
  - **8-D:** Build `FixoNoticeHost` widget (Overlay above Navigator).
  - **8-E:** `FixoNotice` public static API + `NoticeCopy` strings class.
  - **8-F:** Debug gallery route (`kDebugMode` only).
  - **8-G:** Migrate all 48 call sites across 8 file groups.
    - *Exception:* `chat_screen.dart:191` clipboard copy → `FixoNotice.info(NoticeCopy.copied)` (NOT deleted).
  - **8-H:** Remove legacy SnackBar usages, add lint/static test.
  - **8-I:** Full test suite verification & goldens.

---

## 4. Quality & Compliance Checklist

- [x] **No hardcoded values:** All colors, spacing, font sizes, radii, shadows, and dimensions come from `design_tokens.dart`.
- [x] **Both light and dark themes:** Supported and tested for all modified screens.
- [x] **Text scaling:** Resilient at 1.3× scale without layout overflow or clipped text.
- [x] **Touch targets:** Interactive controls satisfy ≥ 48dp (`Sizes.tapMin`).
- [x] **Truthful presentation:** Never fabricate missing tradie data or status fields.
- [x] **Backend safety:** `dotnet` commands run only inside the API Docker container.
- [x] **Analysis clean:** `flutter analyze` passes with 0 errors.
