# v1.6 — Findings log (V16-01 baseline)

**Date:** 2026-10-29
**Build snapshot:** flutter analyze 9 infos / 0 warnings / 0 errors; 511/511 Flutter tests pass; backend 0 errors / 2 warnings (pre-existing NU1903 crypto advisory, not new).

---

## Baseline metrics

| Metric | Value |
|---|---|
| `flutter analyze` | 9 infos, 0 warnings, 0 errors |
| Flutter test count | 511 / 511 pass |
| Backend build | 0 errors, 2 warnings (NU1903 pre-existing) |

---

## Audit finding disposition

Each finding from the v1.6 audit is mapped to its current code state.

### §3.1 Container language — CONFIRMED PRESENT
- `StatusBadge` uses `BorderRadius.circular(100)` — pill only, no border, no shadow. ✓ pill shape OK.
- `ModernJobCard`, info tiles, role cards: need inspection — no unified `FixoCard` wrapper exists. Heavy outline evidence: `fixo_cards.dart` does not define a shared card container widget with shadow + 1px border; cards likely use `DesignTokens` shadow inline.
- **Assigned:** V16-05

### §3.2 Status pill system — CONFIRMED PRESENT (partial fix needed)
- `FixoBadgeKind` has 5 kinds: `verified`, `live`, `hold`, `urgent`, `neutral`.
- Ambiguity confirmed in `job_status_presentation.dart`:
  - `Requested`, `AwaitingPayment`, `PaymentReview`, `AwaitingConfirmation` → all `FixoBadgeKind.hold` (amber/orange fill)
  - `Booked` → `FixoBadgeKind.neutral` (same surface as cancelled/expired)
  - `Completed`, `Cancelled`, `Expired` → `FixoBadgeKind.neutral` (all identical — confirmed bug)
  - `Disputed` → `FixoBadgeKind.urgent` (red — correct)
  - `InProgress` → `FixoBadgeKind.live` (green tint)
- Pills lack icons — confirmed in `fixo_cards.dart` L36 (`Text` only, no leading `Icon`).
- **Assigned:** V16-03

### §3.3 Tracker → progress bar — CONFIRMED PRESENT
- `job_progress.dart` L30–61: renders `Icons.radio_button_checked` / `Icons.radio_button_unchecked` / `Icons.check_circle_outline` in a vertical or horizontal list — the radio-button stepper.
- Used in: `modern_job_card.dart`, `homeowner_job_detail_screen.dart`, `chat_screen.dart`.
- **Assigned:** V16-04

### §3.4 Typography enforcement — PARTIALLY PRESENT
- `job_status_presentation.dart` confirmed: `JobProgress` renders `bodyMedium` for step labels (likely 14px) — acceptable.
- Full audit of all font-size usages across screens needed during V16-06.
- `FittedBox` already used on tradie dashboard stat tile (v1.5 fix) — confirmed in task history.
- **Assigned:** V16-06

### §3.5 Action button enlargement — CONFIRMED PRESENT
- `homeowner_job_detail_screen.dart` and `tradie_job_detail_screen.dart`: Navigate, Message, Call are rendered as `TextButton`/`OutlinedButton` in a row — not 48px tonal buttons.
- **Assigned:** V16-07

### §4.1 Forgot password position — CONFIRMED PRESENT
- `login_screen.dart` L144–154: `Wrap` with `TextButton('Forgot password?')` is placed **between** the email field (above) and the password field (below, L156). Reads as belonging to email. Confirmed bug.
- **Assigned:** V16-14

### §4.2 Dashboard card hierarchy — NEEDS INSPECTION
- `modern_job_card.dart` and `homeowner_dashboard_view.dart` need full reading during V16-09.
- **Assigned:** V16-09

### §4.5 Dispute banner contradictory states — RESOLVED (V16-02)
- `homeowner_job_detail_screen.dart` and `tradie_job_detail_screen.dart`: Terminal statuses (`Completed`, `Cancelled`) now strictly show terminal status guidance and never an active dispute banner, even if stale `disputeStatus` exists.
- Active dispute banner now only displays on active non-terminal jobs (`status == 'Disputed'` or open dispute during active stages).
- `homeowner_job_detail_screen.dart`: "Confirm Completion" button is semantically disabled (`onPressed: null`) with explanatory error text ("Completion cannot be confirmed while a dispute is open.") whenever an active dispute is open on an `AwaitingConfirmation` job. Verified with unit tests.
- **Status:** RESOLVED (V16-02)

### §4.5 Dead-end "Job not found" — RESOLVED (V16-02)
- `homeowner_job_detail_screen.dart`: Replaced bare text with `_JobNotFoundBody` ("We couldn't find this job", "Back to my jobs" primary, "Contact support" secondary).
- `tradie_job_detail_screen.dart`: Replaced bare text with `_TradieJobNotFoundBody` ("This job is no longer available", "Back to dashboard" primary, "Contact support" secondary).
- `request_detail_screen.dart`: Replaced bare text with `_RequestNotFoundBody` ("This request expired", "View open leads" primary).
- All 3 recovery views tested and verified.
- **Status:** RESOLVED (V16-02)

### §4.9 Messages list — PARTIALLY FIXED (v1.5), GAP REMAINS
- `ConversationTile` in `chat_widgets.dart`: already has `lastMessage`, `lastMessageAtUtc`, `unreadCount` from the model (`marketplace.dart` L397–424).
- The data is there; need to verify the visual rendering (avatar size, row height, truncation, unread dot) during V16-12.
- **Assigned:** V16-12

### §4.11 Dark mode — NEEDS INSPECTION DURING V16-17
- Code inspection during V16-17; visual verification during V16-19.

### §4.12 iPad — CONFIRMED PRESENT
- No `LayoutBuilder` / `MediaQuery` width breakpoints for master-detail found in quick grep.
- **Assigned:** V16-18

---

## Items already fixed in v1.5 (not re-opening)

| Finding | Status |
|---|---|
| FittedBox on tradie dashboard stat tiles | Fixed v1.5 |
| SignalR IUserIdProvider null-identity | Fixed v1.5 |
| JobDto.DisputeStatus missing from contract | Fixed v1.5 (but banner logic has the conditional-state bug above) |
| Navigate as url_launcher with map picker | Fixed v1.5 (T22); need to verify T21 request detail |
| Chat quick replies | Fixed v1.5 |
| `matchedTradieName` identity on job cards | Fixed v1.5 |
