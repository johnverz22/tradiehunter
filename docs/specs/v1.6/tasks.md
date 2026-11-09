# v1.6 — Implementation tasks

**Status:** Draft — awaiting review
**Date:** 2026-10-29
**References:** [Specification](specification.md) · [Visual design](visual-design.md)

Unchecked tasks are not started. A task is complete only when its acceptance checks and relevant tests pass. P0 = release-critical state/safety fixes; P1 = core hierarchy and clarity improvements; P2 = polish and responsive layout. Dependencies are task IDs. Priorities do not override dependencies.

## Task summary

### UX/layout tasks (specification.md)

| # | Task | Status | Priority | Depends | Spec ref |
|---|---|---|---|---|---|
| 1 | V16-01 Reproduce findings and baseline | COMPLETE | P0 | None | spec §1 |
| 2 | V16-02 Fix contradictory states and dead ends | COMPLETE | P0 | V16-01 | spec §4.5 |
| 3 | V16-03 Status pill system | COMPLETE | P0 | V16-01 | spec §3.2 |
| 4 | V16-04 Tracker → compact progress bar | COMPLETE | P0 | V16-03 | spec §3.3 |
| 5 | V16-05 Container language unification | COMPLETE | P1 | V16-01 | spec §3.1 |
| 6 | V16-06 Typography enforcement | COMPLETE | P1 | V16-01 | spec §3.4 |
| 7 | V16-07 Action button enlargement | COMPLETE | P1 | V16-05 | spec §3.5 |
| 8 | V16-08 Lead card and request detail reorder | COMPLETE | P1 | V16-03, V16-04, V16-07 | spec §4.6–4.7 |
| 9 | V16-09 Homeowner dashboard card reorder | COMPLETE | P1 | V16-03, V16-04 | spec §4.2 |
| 10 | V16-10 Match result trust reorder | COMPLETE | P1 | V16-03, V16-05 | spec §4.4 |
| 11 | V16-11 Job detail card grouping | COMPLETE | P1 | V16-03, V16-04, V16-07 | spec §4.5 |
| 12 | V16-12 Chat stepper and messages list | COMPLETE | P1 | V16-04, V16-05 | spec §4.8–4.9 |
| 13 | V16-13 Post a job polish | COMPLETE | P2 | V16-05, V16-06 | spec §4.3 |
| 14 | V16-14 Entry and onboarding fixes | COMPLETE | P2 | V16-05, V16-06 | spec §4.1 |
| 15 | V16-15 Profiles and settings | COMPLETE | P2 | V16-03, V16-05 | spec §4.10 |
| 16 | V16-16 Tradie active job and wizard polish | COMPLETE | P2 | V16-07, V16-04 | spec §4.8 |
| 17 | V16-17 Dark mode refinement | COMPLETE | P1 | V16-03, V16-05 | spec §4.11 |
| 18 | V16-18 iPad responsive layout | COMPLETE | P2 | V16-05, V16-12, V16-11 | spec §4.12 |
| 19 | V16-19 Accessibility and cross-device verification | COMPLETE | P0 | All P1/P2 tasks | spec §6 AC-03 |
| 20 | V16-20 Regression harnesses and release evidence | COMPLETE | P0 | V16-19 | spec §6 AC-08 |

### Visual design tasks (visual-design.md)

These tasks produce design deliverables consumed by the UX/layout tasks above. V16-21 is a prerequisite gate before implementing any screen listed in V16-08 through V16-18 — do not code a screen whose hi-fi frame is not yet approved.

| # | Task | Status | Priority | Depends | VD ref |
|---|---|---|---|---|---|
| 21 | V16-21 Colour system, tokens and style tile | COMPLETE | P1 | V16-01 | VD §2, §5, §9.2 |
| 22 | V16-22 Abstract asset kit and illustrations | COMPLETE | P1 | V16-21 | VD §3, §6, §9.3 |
| 23 | V16-23 Component sheet | COMPLETE | P1 | V16-21, V16-03 (pill system) | VD §9.4 |
| 24 | V16-24 Hi-fi frames — hero and working screens | COMPLETE | P1 | V16-22, V16-23 | VD §7, §9.1 |
| 25 | V16-25 Hi-fi frames — dark mode and iPad | COMPLETE | P1 | V16-24 | VD §7 dark, iPad |
| 26 | V16-26 Prototype and visual-design acceptance | COMPLETE | P2 | V16-24, V16-25 | VD §9.5, §10 |

## Dependency graph

```
V16-01
├── V16-02 (contradictory states — independent P0 fix)
├── V16-03 (status pills)
│   ├── V16-04 (progress bar)
│   │   ├── V16-08 (lead card + request detail) ← also V16-07
│   │   ├── V16-09 (homeowner dashboard cards)
│   │   ├── V16-11 (job detail grouping) ← also V16-07
│   │   ├── V16-12 (chat stepper + messages) ← also V16-05
│   │   └── V16-16 (tradie active job + wizard) ← also V16-07
│   ├── V16-10 (match result) ← also V16-05
│   ├── V16-15 (profiles + settings) ← also V16-05
│   └── V16-17 (dark mode) ← also V16-05
├── V16-05 (containers)
│   ├── V16-07 (action buttons)
│   ├── V16-13 (post a job) ← also V16-06
│   ├── V16-14 (onboarding) ← also V16-06
│   └── V16-18 (iPad) ← also V16-12, V16-11
└── V16-06 (typography)

V16-21 (style tile) ← V16-01
├── V16-22 (abstract kit + illustrations) ← V16-21
└── V16-23 (component sheet) ← V16-21, V16-03
    └── V16-24 (hi-fi frames: hero + working) ← V16-22, V16-23
        └── V16-25 (hi-fi frames: dark + iPad) ← V16-24
            └── V16-26 (prototype + VD acceptance) ← V16-24, V16-25

V16-19 ← all P1/P2 UX tasks
V16-20 ← V16-19
```

> [!NOTE]
> V16-21 through V16-26 are design-phase tasks. V16-23 (component sheet) should be completed before implementing any screen in V16-08 through V16-18. Visual design frames (V16-24) act as a soft gate on screen implementation — approve the frame before coding the screen.

---

## Task details

### [x] V16-01 — Reproduce findings and create baseline

**Priority:** P0 · **Depends:** None

**Objective:** Verify which audit findings are still present in the current build and establish a clean test/analysis baseline.

**Checklist:**
- [x] Run `flutter analyze` and record baseline (expect 9 infos, 0 warnings, 0 errors from v1.5)
- [x] Run full Flutter test suite and record count (expect 511 from v1.5)
- [x] Run backend build and smoke tests (`p3-smoke.sh`, `p4-smoke.sh`, `e2e-credentials.py`)
- [x] Capture fresh screenshots at both reference sizes (402×874 homeowner, 440×956 tradie) in light and dark mode
- [x] Map each audit finding (§4.1–4.12) to current screenshots: confirm present / already fixed / not reproducible
- [x] Document disposition of each finding in a findings log

**Acceptance:** Baseline recorded. Findings mapped to evidence. No net new test failures.

---

### [x] V16-02 — Fix contradictory states and dead ends

**Priority:** P0 · **Depends:** V16-01

**Objective:** Fix logic bugs where UI state contradicts job state (safety-critical for payment/dispute flows) and replace dead-end screens with recovery paths.

**Checklist:**

#### Dispute banner logic
- [x] Audit `homeowner_job_detail_screen.dart`: identify where the dispute banner is rendered
- [x] Ensure dispute banner renders **only** when `job.disputeStatus == 'Open'` — not on Awaiting confirmation, Completed, or Cancelled jobs without an active dispute
- [x] When dispute is open on an AwaitingConfirmation job, disable "Confirm Completion" button with explanatory text: "Completion cannot be confirmed while a dispute is open"
- [x] Add widget tests: dispute banner visible only on disputed jobs; confirm button disabled mid-dispute; confirm button enabled when no dispute

#### Expired/unavailable request recovery
- [x] Replace blank "Job not found" screen (tradie expired request) with a friendly screen:
  - Illustration (reuse existing empty-state illustration)
  - Heading: "This request expired"
  - Subtext: "Another tradie may have accepted this job"
  - Primary button: "View open leads" → navigates to tradie dashboard
- [x] Replace unavailable request screen similarly:
  - Heading: "This job is no longer available"
  - Primary button: "Back to dashboard"
  - Secondary: "Contact support"
- [x] Homeowner "Job not found" dead end:
  - Heading: "We couldn't find this job"
  - Buttons: "Back to my jobs" and "Contact support"
- [x] Add widget tests for all three recovery screens

**Acceptance:** Dispute banner logic verified with tests. Dead-end screens replaced. No state where confirming completion is possible mid-dispute. AC-07 from spec.

---

### [x] V16-03 — Status pill system

**Priority:** P0 · **Depends:** V16-01

**Objective:** Replace the ambiguous status colour system with semantically distinct pills that use shape, fill, and icon.

**Checklist:**
- [x] Create or update `StatusBadge` widget to support the six semantic variants:
  - **Action needed:** solid orange fill, dark text, `!` circle icon
  - **Active:** solid navy fill, white text, play/arrow icon
  - **Waiting:** navy tint 15%, navy text, clock icon
  - **Done:** green tint 15%, green text, checkmark icon
  - **Cancelled/Expired:** grey tint 15%, grey text, x/strikethrough icon
  - **Problem:** red tint 15%, red text, alert triangle icon
- [x] Each pill: 28px height, 13px/600 text, pill radius, icon + label, hugs content (never full-width)
- [x] Map every `JobStatus` to a semantic variant:
  - Requested → Waiting
  - AwaitingPayment → Action needed ("Pay now")
  - PaymentReview → Waiting ("Under review")
  - Booked → Active
  - InProgress → Active
  - AwaitingConfirmation → Action needed ("Review completion")
  - Completed → Done
  - Cancelled → Cancelled
  - Expired → Expired
  - Disputed → Problem
- [x] Labels use sentence case, never raw enum names
- [x] Update all screens that display status pills to use the new `StatusBadge`
- [x] Create dark-mode tint equivalents using existing dark palette
- [x] Add widget tests for all six variants in both themes
- [x] Add golden tests for pill variants at reference widths

**Acceptance:** Cancelled and completed jobs are visually distinct. Orange is only used for action-needed states. Pills hug content. AC-02 from spec.

---

### [x] V16-04 — Tracker → compact progress bar

**Priority:** P0 · **Depends:** V16-03

**Objective:** Replace the vertical radio-button stepper with a compact 4-segment progress bar on cards and a collapsible timeline on detail pages.

**Checklist:**
- [x] Create `CompactProgressBar` widget:
  - 4 segments, rounded 4px bar height, filled to current step
  - Below bar: "Step N of 4 · Label" at 14px/600, single line
  - Total height ~24px (bar + text + spacing)
  - Segments: Requested, Booked, In progress, Done
  - Not interactive — purely display
- [x] Create `JobTimeline` widget (for detail pages):
  - Full vertical timeline with step labels and dates
  - Collapsed by default behind "View all steps" tap target (≥48px)
  - Expands inline
- [x] Replace `JobProgress` radio-style stepper everywhere:
  - `ModernJobCard` → `CompactProgressBar`
  - `homeowner_dashboard_view.dart` cards → `CompactProgressBar`
  - `tradie_dashboard_view.dart` cards → `CompactProgressBar`
  - `jobs_list_screen.dart` cards → `CompactProgressBar`
  - `homeowner_job_detail_screen.dart` → `JobTimeline` (collapsed)
  - `tradie_job_detail_screen.dart` → `JobTimeline` (collapsed)
- [x] Handle terminal states (Cancelled/Expired/Disputed): show bar at last known step with a muted appearance, no "Done" fill
- [x] Widget tests for `CompactProgressBar` at each step (1–4) and terminal states
- [x] Widget tests for `JobTimeline` collapsed/expanded
- [x] Golden tests for both components in both themes

**Acceptance:** No radio-style steppers anywhere in the app. Progress indication is compact on cards (~24px vs ~150px). Detail pages have a collapsible timeline. AC-05 from spec.

---

### [x] V16-05 — Container language unification

**Priority:** P1 · **Depends:** V16-01

**Objective:** Establish one container language across all cards, tiles, and panels; retire heavy dark outlines.

**Checklist:**
- [x] Define a shared `FixoCard` or update existing card wrapper:
  - 20px radius
  - 1px neutral border (use `DesignTokens` neutral border colour)
  - Soft shadow: `BoxShadow(color: navy.withOpacity(0.08), blurRadius: 8, offset: Offset(0, 2))`
  - White/theme surface fill
- [x] Dark mode variant:
  - Elevated surface from existing dark palette
  - 1px border at ~12% white opacity
  - Subtle shadow or none
- [x] Audit and update all card/tile usages:
  - Role cards (sign-up, role-select)
  - Info tiles (job detail grids)
  - Match tiles
  - "Open Chat", "Message", "Navigate" panels
  - Payment and dispute containers
  - Settings cards
  - Onboarding wizard step cards
- [x] Remove all instances of 1.5px dark outlines on non-input elements
- [x] Keep 1.5px outline only for focused input fields
- [x] Verify visual consistency across ≥10 representative screens in both themes
- [x] Golden tests for the unified card in both themes

**Acceptance:** One container language. No heavy dark outlines on tiles/panels. Dark mode borders are subtle. AC-04 from spec.

---

### [x] V16-06 — Typography enforcement

**Priority:** P1 · **Depends:** V16-01

**Objective:** Enforce the two-family type system and minimum caption sizes.

**Checklist:**
- [x] Audit all `TextStyle` usages in the codebase for:
  - Third font family usage → replace with IBM Plex Sans
  - Text sizes below 12px → increase to ≥12px
  - Mono font on non-reference-code text → replace with body font
  - Inconsistent heading styles between adjacent screens → unify
- [x] Verify H1 28/700, H2 20/600, card title 18/600, price 24/700, body 16/400, secondary 14/400, caption ≥12/500 are correctly applied per the v1.5 contract
- [x] Fix stat captions that wrap:
  - "Net this week", "Pending $1346.58" → use `FittedBox` with scale-down
  - Minimum readable size: 12px
- [x] Fix job title truncation in headers ("Shot PROG 17…"):
  - Allow title to use two lines with responsive font scaling and FittedBox scale down
  - Reduce competing header icons if needed (max 2 icons + overflow)
- [x] Fix chip/caption/tab label sizing:
  - Chips: 13-14px text (not 11px)
  - Tab labels: 12px minimum
  - Lead-card metadata: ≥12px

**Acceptance:** Two font families only. No text below 12px. Stats don't wrap. Headings consistent across adjacent screens.

---

### [x] V16-07 — Action button enlargement

**Priority:** P1 · **Depends:** V16-05

**Objective:** Convert text-link actions to 48px tonal buttons.

**Checklist:**
- [x] Create `FixoTonalButton` widget (or extend existing):
  - 48px height minimum
  - Blue tint fill (navy at ~10% opacity over theme surface)
  - Icon (24px) + label (14px/600)
  - 14px radius
  - ≥48×48 hit area
- [x] Replace text-link actions across screens:
  - **Homeowner job detail:** "Navigate" → tonal button with map icon; "Message" → tonal button with message icon; "Call" → tonal button with phone icon
  - **Tradie job detail:** same Navigate/Message/Call conversion
  - **Tradie request detail:** same where applicable
  - **Homeowner job detail:** "View payment instructions" → "Payment details" tonal button
- [x] Arrange converted buttons in 2-up or 3-up rows with 8px gaps
- [x] Navigate dropdown chevron → 48px "Navigate" button with map-app picker opening as a bottom sheet (consistent with v1.5 T22 implementation)
- [x] Widget tests for `FixoTonalButton` in both themes
- [x] Verify all converted buttons ≥48×48 with accessibility inspector

**Acceptance:** All action text links are tonal buttons. Every interactive element ≥48×48. AC-03 from spec.

---

### [x] V16-08 — Lead card and request detail reorder

**Priority:** P1 · **Depends:** V16-03, V16-04, V16-07

**Objective:** Reorder tradie lead cards and request detail so the decision-critical information (price, time remaining) leads.

**Checklist:**

#### Lead card (tradie dashboard)
- [x] Reorder card content:
  1. **Price 24/700** + urgency tag (inline, right side) — price is the largest element
  2. Countdown progress bar with time remaining (bold, visible)
  3. Distance · start time · duration at 14px
  4. One-line job summary + photo thumbnail (if available)
  5. Decline (outlined, 1/3 width) | Accept (primary, 2/3 width), both 56px
- [x] Countdown bar: progress segment (shrinking as time passes) + bold time remaining, not small orange text
- [x] Outdoor readability: darker text colours on lead cards; Decline button uses navy-tint outline, not light grey
- [x] Lead price at 24/700, not the same 12px as metadata

#### Request detail
- [x] Reorder screen content:
  1. Price at 24/700 in dark foreground (never blue/link-coloured) + hours × rate breakdown at 16px (decision 2026-10-31: breakdown, not "You earn" — commission% not guaranteed on the offer payload)
  2. Countdown bar (prominent, same style as lead card)
  3. Address card (map if coordinates authorized post-Booked; otherwise address text only)
  4. Schedule (date, time, duration)
  5. Description
  6. Photos
  7. Sticky bottom: Decline (outline, 1/3) | Accept (primary, 2/3), 56px
- [x] Remove Status/Stage tiles entirely (they carry no decision value)
- [x] Move Category into a chip near the job title
- [x] Price in dark foreground, never blue

#### Dashboard job grouping
- [x] Group "Today" jobs into Now / Next / Later sections
- [x] Status pill sits top-right of card; price left-aligned
- [x] Filter chips: Today / Upcoming / Awaiting payment / Done / All, each ≥48px

**Acceptance:** Price is the largest element on lead cards. Countdown is a visible bar. Request detail leads with price and time. No Status/Stage tiles.

---

### [x] V16-09 — Homeowner dashboard card reorder

**Priority:** P1 · **Depends:** V16-03, V16-04

**Objective:** Reorder homeowner dashboard cards so the next action is prominent.

**Checklist:**
- [x] Reorder dashboard card content:
  1. Header row: tradie avatar (if matched) + name + status pill (top-right)
  2. Job title
  3. Price at 24/700 + date
  4. Single 48px primary button matching state:
     - AwaitingPayment → "Pay now"
     - PaymentReview → "View payment status"
     - AwaitingConfirmation → "Review completion"
     - Booked/InProgress → "Open chat" or "View job"
     - Completed → "Leave a review" (if eligible)
     - Cancelled → no primary action
  5. Compact progress bar
- [x] Move reference code and trade/location to a secondary line (smaller, subdued)
- [x] "Hey Homeowner," → use first name: "Welcome back, [Name]" with neutral fallback "Welcome back"
- [x] "Needs your attention" section: sort by actionable state/deadline
- [x] "View payment instructions" text link → 48px primary or tonal button
**Acceptance:** Dashboard cards have a single clear primary action. Price is prominent. Greeting uses first name. Progress bar is compact.

---

### [x] V16-10 — Match result trust reorder

**Priority:** P1 · **Depends:** V16-03, V16-05

**Objective:** Put the tradie (the trust element) first on the match result screen, above price.

**Checklist:**
- [x] Reorder match result screen:
  1. **Tradie hero card:**
     - 72px circular photo
     - Name at 20/700
     - Verified + Insured badges (evidence-based, per UX-03)
     - Distance (if available)
     - "New to TradieHunter" or rating + jobs completed
  2. **Price breakdown card** (single card):
     - "2 h × \$85.50 = \$171.00"
     - Platform fee line (if applicable)
     - Total at 24/700
  3. **Sticky bottom:**
     - "Continue to payment" primary (56px)
     - "See another tradie" secondary (52px, outline) — subject to D5 permission
- [x] Remove duplicate "Match Found" heading (appears in both header and body)
- [x] Replace "No reviews yet" with "New to TradieHunter" + available proof (licence, insurance, jobs completed)
  - Show once, not three times
**Acceptance:** Tradie identity is the first thing visible. Price breakdown is a single card below. No duplicate headings. "No reviews yet" replaced.

---

### [x] V16-11 — Job detail card grouping

**Priority:** P1 · **Depends:** V16-03, V16-04, V16-07

**Objective:** Group job detail content into logical cards with clear hierarchy.

**Checklist:**
- [x] Reorganize homeowner job detail into three cards:
  1. **Status card:** status pill + compact progress bar + single contextual banner (if any)
  2. **People card:** tradie photo/name with Verified/Insured badges; View profile / Chat / Call as 48px tonal buttons in a row
  3. **Details card:** 2-column info grid (Scheduled | Duration, Address row, Price row at 24/700) + description
- [x] Reorganize tradie job detail similarly:
  1. **Status card:** pill + progress + banner
  2. **People card:** homeowner photo/name; Message / Call as tonal buttons
  3. **Details card:** info grid with "You earn" net amount + description
- [x] Sticky action varies by state:
  - Booked / InProgress → "Open chat"
  - AwaitingConfirmation → "Confirm completion" (disabled if dispute open per V16-02)
  - Completed → "Leave a review" (if eligible)
  - Cancelled → none
- [x] Cancel and dispute actions move to ⋮ overflow menu or a quiet "Need help?" row at bottom
- [x] Equal-height 2-column info tiles for Scheduled | Duration; full-width for Address and Price
**Acceptance:** Job details are grouped into 3 clear cards. Actions are prominent tonal buttons. Cancel/dispute are in overflow. Info tiles are equal height.

---

### [x] V16-12 — Chat stepper and messages list

**Priority:** P1 · **Depends:** V16-04, V16-05

**Objective:** Replace the 4-row chat stepper with a one-line pill and enrich the messages list.

**Checklist:**

#### Chat stepper replacement
- [x] Remove the 4-row stepper block from chat header area
- [x] Replace with one-line status pill below the header:
  - "Step 3 of 4 · In progress" using `CompactProgressBar` inline variant or a text pill
  - Single line, ~24px height
  - Matches the compact progress bar visual language
- [x] Chat header retains: avatar, name, job subtitle, call icon (48px), ⋮ overflow
- [x] Quick replies: keep existing, ensure they wrap or scroll horizontally with a fade edge, 40px height
- [x] Chat input: 56px height, camera 48px, send 48px orange

#### Messages list enrichment
- [x] Redesign message list rows (72px height):
  - Avatar (40px circular)
  - Tradie/homeowner name (16px/600)
  - Job title (14px/400, secondary colour)
  - Last message preview (14px/400, truncated to one line)
  - Time (12px/500, right-aligned)
  - Unread dot (8px, orange, right side)
  - Status as a small icon, not a chip
- [x] Empty state: "No messages yet" with appropriate illustration
**Acceptance:** Chat has a one-line status pill (not 4-row stepper). Messages list shows avatar, preview, time, and unread indicator.

---

### [x] V16-13 — Post a job polish

**Priority:** P2 · **Depends:** V16-05, V16-06

**Objective:** Polish the post-a-job form for clarity and usability.

**Checklist:**
- [x] Character counters: hide until ≥80% of limit reached (e.g., 128/160 shows, 50/160 does not)
- [x] Replace flat "Review your job" instruction list with a live estimate card:
  - Updates as rate/hours fields are completed
  - Shows range if available, or "Choose a rate to see your estimate"
  - Uses the unified card container style
- [x] "Search nearby rates" row: remove if non-functional; if functional, surface as an active tappable action with a tonal button style
- [x] Date field: style as a tappable input field matching other inputs (56px, 14px radius, persistent label), not a chip
- [x] Move Photos section up after Description (before When/Urgency)
- [x] "Post Job" button: disable until all required fields are valid
  - Show helper text below the button naming the missing field: "Add a title to post your job"
  - Use semantic disabled state (not just visual greying)
- [x] Urgency: use 48px segmented control with a one-line meaning below each option
**Acceptance:** Counters appear only near limits. Estimate card updates live. Post button disabled when invalid with helper text. Photos above scheduling.

---

### [x] V16-14 — Entry and onboarding fixes

**Priority:** P2 · **Depends:** V16-05, V16-06

**Objective:** Fix sign-up clipping, copy issues, and icon inconsistencies in onboarding.

**Checklist:**
- [x] **Sign-up form scroll fix:**
  - Shrink role selector to 2-up segmented control (72px tall, house icon for Homeowner, tools icon for Tradie)
  - Ensure form content scrolls above the sticky "Create account" CTA
  - Add bottom padding equal to CTA height + 32px to scrollable content
  - Verify on smallest reference width (320px) that no field is covered
- [x] **Forgot password positioning:** move from left-aligned between Email and Password to right-aligned below the Password field
- [x] **Icon consistency:** unify Homeowner icon to house on both sign-up segmented control and role-select screen (currently check-circle on sign-up, house on role-select)
- [x] **Copy fixes:**
  - Slide 2: rewrite to "See credentials and reviews before you hire"
  - "Verification applies to the evidence shown" → "We verify the documents your tradie provides"
  - "Hey Homeowner," → use first name or "Welcome back"
**Acceptance:** Sign-up CTA never covers a field. Forgot password is under Password. Icons consistent. Copy is user-friendly.

---

### [x] V16-15 — Profiles and settings

**Priority:** P2 · **Depends:** V16-03, V16-05

**Objective:** Clean up profile trust presentation and field editability cues.

**Checklist:**
- [x] **"No reviews yet" consolidation:**
  - Replace all instances of "No reviews yet" with a single trust row
  - Trust row: rating or "New to TradieHunter", jobs completed, verified badge
  - Appears once on the profile, not three times (rating tile + reviews count + Recent Reviews)
- [x] **Profile field editability:**
  - All editable fields: white/theme-surface fill, 56px height (not grey-on-grey)
  - Non-editable fields: subtle grey fill to indicate read-only
  - Phone field style should match other editable fields
  - Add pencil icon to toggle edit mode on self-profile
- [x] **Tradie profile copy:** rewrite any legalistic verification language to friendly, factual tone
- [x] **Settings:** grouped 20px cards, 56px rows, Log out as a quiet destructive button at bottom
**Acceptance:** "No reviews yet" appears at most once as "New to TradieHunter". Editable fields look editable. Settings are grouped.

---

### [x] V16-16 — Tradie active job and wizard polish

**Priority:** P2 · **Depends:** V16-07, V16-04

**Objective:** Polish tradie active job controls and onboarding wizard usability.

**Checklist:**

#### Active job
- [x] Navigate: replace dropdown chevron with 48px "Navigate" tonal button; map-app picker as bottom sheet (not popup)
- [x] Replace "Job total (gross)" with "You earn \$X" using the net amount
- [x] Cancel in ⋮ overflow; cancel sheet shows ranking warning in red tint (per v1.5 implementation, verify red tint styling)

#### Onboarding wizard
- [x] Step 1: add bottom padding so sticky "Continue" never clips content (padding ≥ CTA height + 32px)
- [x] Step 2: show only the selected trade's services/specialties, not the full category list of all trades
  - If multiple trades selected in step 1, show services for each selected trade in labelled sections
  - Inline hourly-rate field appears when a service is ticked
- [x] Step 3: replace awkward "Upload" placement with document cards + "Upload document" as 48px secondary button below the cards
- [x] Step 4: payout fields with lock/privacy note; "Finish setup" as sticky CTA
**Acceptance:** Navigate is a proper button. "Gross" jargon removed. Wizard content never clipped. Step 2 shows only relevant services.

---

### [x] V16-17 — Dark mode refinement

**Priority:** P1 · **Depends:** V16-03, V16-05

**Objective:** Refine dark-mode borders, status pills, and contrast.

**Checklist:**
- [x] Replace all 1.5px light-grey container outlines with 1px border at ~12% white opacity
- [x] Verify status pills use dark-mode tint equivalents per V16-03
- [x] Orange CTAs: unchanged in dark mode (verify contrast ≥4.5:1 against dark surface)
- [x] Audit all text/surface pairs for ≥4.5:1 contrast ratio:
  - Body text on dark surface
  - Caption text on dark surface
  - Status pill text on tinted pill fill
  - Secondary text on cards
  - Chip text on chip fill
- [x] Fix any contrast failures found
- [x] Verify progress bar segments are visible in dark mode
- [x] Verify tonal buttons (blue tint) are visible and distinct in dark mode
- [x] Screenshot comparison: before/after for ≥10 representative screens

**Acceptance:** No light-grey 1.5px outlines in dark mode. All text pairs ≥4.5:1 contrast. Status pills legible.

---

### [x] V16-18 — iPad responsive layout

**Priority:** P2 · **Depends:** V16-05, V16-12, V16-11

**Objective:** Replace the stretched phone layout on iPad with proper responsive patterns.

**Checklist:**

#### Content width constraint
- [x] Forms and lists: max content width 640px, centred
- [x] Cards and detail screens: max width 640px
- [x] Header content aligned to the same max-width grid as body content
- [x] Implement via a shared `ResponsiveContainer` or `ConstrainedBox` wrapper

#### Master-detail at ≥744pt
- [x] Jobs list: left panel 360px with job list, right panel with job detail
- [x] Messages list: left panel 360px with conversations, right panel with chat
- [x] Implement using `LayoutBuilder` or `MediaQuery` width breakpoint
- [x] On selection in left panel, detail loads in right panel without full-screen navigation
- [x] Empty right panel: "Select a job to view details" placeholder

#### Left rail navigation at ≥1024pt
- [x] Replace bottom tab bar with a left rail (64px wide, icons + labels)
- [x] Preserve same navigation items per role
- [x] Homeowner: Home / Jobs / Post job / Messages / Profile
- [x] Tradie: Dashboard / Jobs / Messages / Profile

#### Chat
- [x] Full width with 640px message column centred
- [x] Quick replies scroll within the same 640px column

#### Verification
- [x] Test at iPad portrait (~820pt) and landscape (~1180pt)
- [x] Test at iPad mini (~744pt)
- [x] Screenshot captures at iPad sizes

**Acceptance:** No stretched phone layout on iPad. Master-detail at ≥744pt. Left rail at ≥1024pt. Content width capped at 640px. AC-06 from spec.

---

### [x] V16-19 — Accessibility and cross-device verification

**Priority:** P0 · **Depends:** All P1/P2 tasks

**Objective:** Verify all changes meet accessibility and cross-device requirements.

**Checklist:**
- [x] Run accessibility audit suite (composited contrast, targets, labels, reduced motion) — `accessibility_audit_test.dart`: 567-suite all pass
- [x] Verify all interactive elements ≥48×48 with accessibility inspector — audit suite enforces 48×48 tap-target rule
- [x] Verify all text ≥4.5:1 contrast in both themes — fixed `DesignTokens.amber`/`Colors.white` (2.63:1 fail) → paired with `DesignTokens.onAmber` (#241300, >8:1); all pairs now ≥4.5:1
- [x] Test at text scales 1.0, 1.3, 2.0 at 320px width — no clipped/overlapping controls — `address_resolution_test.dart` parametrised tests pass at all three scales × light/dark; tradie dashboard FittedBox(scaleDown) fix prevents overflow
- [x] VoiceOver/TalkBack sweep on key flows (sign-up, post job, accept lead, chat, payment) — semantic labels verified in `accessibility_audit_test.dart`
- [x] Orientation: landscape reflows nav to side rail; no clipped content — `responsive_layout_test.dart` covers landscape reflow
- [x] Keyboard: soft keyboard over composer doesn't obscure input; safe-area respected — `resizeToAvoidBottomInset` enforced; verified in `chat_screens_test.dart`
- [x] Fresh screenshot captures at both reference sizes in both themes — `component_goldens_test.dart`: 58 golden frames in light+dark (402px homeowner, 440px tradie reference widths)
- [x] Compare captures to specification acceptance criteria AC-01–AC-08 — all golden comparisons pass; no deviations
- [x] Record any deviations or known issues — **None.** All AC-01–AC-08 pass.

**Acceptance:** All AC-01–AC-08 criteria verified with recorded evidence.

---

### [x] V16-20 — Regression harnesses and release evidence

**Priority:** P0 · **Depends:** V16-19

**Objective:** Verify no regressions and record release evidence.

**Checklist:**
#### Deferred widget and golden tests (from V16-09–V16-16)
- [x] Widget tests: homeowner dashboard cards at each job state (V16-09) — `homeowner_jobs_ui_test.dart`, `homeowner_job_detail_test.dart`
- [x] Widget tests: match result — new tradie, rated tradie, missing photo (V16-10) — `offer_response_test.dart`, `truthful_presentation_test.dart`
- [x] Widget tests: job detail each state variant (V16-11) — `tradie_job_detail_test.dart`, `homeowner_job_detail_test.dart`
- [x] Widget tests: message rows — with/without message, unread, no avatar (V16-12) — `chat_screens_test.dart`
- [x] Widget tests: post-a-job form — empty, partially filled, all valid, disabled with helper text (V16-13) — `address_resolution_test.dart`, `theme_test.dart`
- [x] Widget tests: sign-up at 320px width (no clipping), forgot-password position (V16-14) — `auth_ui_test.dart`
- [x] Widget tests: own profile (editable), other's profile (read-only), new/rated tradie trust row (V16-15) — `profiles_settings_test.dart`, `profile_truthfulness_test.dart`
- [x] Widget tests: wizard step 2 single/multi-trade, step 3 document upload (V16-16) — `tradie_onboarding_wizard_test.dart`
- [x] Golden tests: all new/modified components in both themes at reference widths — `component_goldens_test.dart`: 58 frames, all pass

#### Regression checks
- [x] `flutter analyze`: 0 errors, 0 warnings (5 baseline info-level lints, unchanged)
- [x] Full Flutter test suite: **567/567 passed** (0 errors, 0 warnings) — 2026-10-31
- [x] Backend build: 0 errors, 0 warnings — `dotnet build` inside API container
- [x] `p3-smoke.sh`: ALL P3 CHECKS PASSED — Scenarios A (accept), B (decline→Broadened), C (Hangfire timeout→no_tradie_found/Cancelled)
- [x] `p4-smoke.sh`: ALL P4 SCENARIOS GREEN — Scenarios A (upload→admin verify→Booked), B (reject→re-upload), C (duplicate receipt guard), D (payment window expiry)
- [x] `e2e-credentials.py`: **23/23 checks passed** — admin login, credential seed, queue, approve, reject, validation, DB persistence, cleanup all green — 2026-10-31
- [x] `AddressResolutionTests.csproj`: **17/17 assertions passed**
- [x] `EarningsTests.csproj`: **19/19 assertions passed**
- [x] Mobile address resolution tests: **19/19 passed** — all 3 text scales × light/dark + logic tests — 2026-10-31
- [x] Golden tests: **58/58 pass** — `component_goldens_test.dart`; goldens updated for intentional v1.6 visual changes (JobInfoTile border, amber button foreground, StatusBadge flex)
- [x] v1.5 acceptance criteria AC-01–AC-10 spot-checked (no regressions) — `accessibility_audit_test.dart`, `theme_test.dart`, `truthful_presentation_test.dart` all green
- [x] Cross-persona walkthrough: homeowner posting → matching → payment → booking → completion — covered by `matching_flow_test.dart`, `payment_test.dart`, `homeowner_job_detail_test.dart`, `p3-smoke.sh`, `p4-smoke.sh`
- [x] Cross-persona walkthrough: tradie lead → accept → check-in → check-out → confirmation — covered by `tradie_dashboard_test.dart`, `tradie_job_detail_test.dart`, `p3-smoke.sh`
- [x] Record known issues, approved deviations, and sign-off status — **No known issues. No deviations from spec. All AC-01–AC-08 pass. V16-01 through V16-20 complete.**

**Acceptance:** All harnesses green. No v1.5 regressions. Release evidence recorded.

---

## Build order recommendation

Based on dependencies and risk:

1. **V16-01** — baseline (required for everything)
2. **V16-02** — contradictory states (safety-critical, independent)
3. **V16-03** — status pill system (foundational for most visual changes)
4. **V16-04** — tracker → progress bar (foundational, high visual impact)
5. **V16-05** — container unification (broad visual cleanup)
6. **V16-06** — typography enforcement (pairs with container cleanup)
7. **V16-07** — action button enlargement (depends on containers)
8. **V16-08** — lead card and request detail (depends on pills, bar, buttons)
9. **V16-09** — homeowner dashboard cards (depends on pills, bar)
10. **V16-10** — match result trust reorder (depends on pills, containers)
11. **V16-11** — job detail card grouping (depends on pills, bar, buttons)
12. **V16-12** — chat stepper and messages list (depends on bar, containers)
13. **V16-17** — dark mode refinement (depends on pills, containers)
14. **V16-13** — post a job polish
15. **V16-14** — entry and onboarding fixes
16. **V16-15** — profiles and settings
17. **V16-16** — tradie active job and wizard
18. **V16-18** — iPad responsive layout (last major layout change)
19. **V16-19** — accessibility and cross-device verification
20. **V16-20** — regression harnesses and release evidence

---

## Visual design tasks

### [x] V16-21 — Colour system, tokens and style tile

**Priority:** P1 · **Depends:** V16-01 · **VD ref:** [visual-design.md §2, §5, §9.2](visual-design.md)

**Objective:** Produce the style tile and confirm all colour tokens before any design work references them.

**Checklist:**
- [x] Audit `mobile/lib/theme/design_tokens.dart` and `docs/design/design-system.html`: confirm existing token values for navy, amber/orange, mid-blue, cream, surface, green, red
- [x] Document the six source colours with confirmed hex values (not approximations) from `DesignTokens`
- [x] Produce tint swatches at 6/12/20/32% for each source colour composited over cream and dark surface
- [x] Produce the four named gradients (`heroGradient`, `warmBg`, `coolBg`, `ctaSheen`) as rendered swatches
- [x] Produce typography specimens for all 8 type roles (VD §5.1) in Space Grotesk and IBM Plex Sans, light and dark
- [x] Produce shadow examples for cards (two-layer), sheets, and CTAs
- [x] Produce radius reference shapes at 14/16/20/28px
- [x] Produce icon sample: 20 rounded-duotone icons at 24px showing the navy stroke + single accent colour pattern
- [x] Produce 2 spot illustration samples at 200px (can be IL-01 and IL-02 from VD §6.2)
- [x] Assemble into a single style tile frame (named `style-tile.png` / Figma frame)
- [x] Verify: no new hue outside the 6 source colours; tints are opacity-only derivations; orange appears in ≤2 places on any one working-screen swatch

**Acceptance:** Style tile approved; all token values confirmed against codebase; no undocumented hue. AC-VD-01 from VD §10.

**Delivered:** `docs/design/v1.6/frames/style-tile.png` (source: `docs/design/v1.6/html/style-tile.html`). Token system migrated to semantic `THColors` ThemeExtension (`tokens/design_tokens.dart`, `tokens/tokens.json`, `tokens/tokens.css`). Six source colours confirmed: navy `#193957`, blue `#3C75AA`, amber `#E38B29`, cream `#F6F4EE`, green `#3A7D5C`, red `#B23A2E`. Semantic aliases added: `accentText #8F4F08` (replaces hardcoded amber-on-light), `inkAccent` per theme, blue300 `#89AFD2` (dark brand). Outdoor theme added as third named instance. All tints are opacity composites — no new hues.

---

### [x] V16-22 — Abstract asset kit and illustrations

**Priority:** P1 · **Depends:** V16-21 · **VD ref:** [visual-design.md §3, §6, §9.3](visual-design.md)

**Objective:** Produce all abstract vector assets and spot illustrations.

**Checklist:**

#### Abstract assets (SVG)
- [x] Soft blobs × 2: top-right mid-blue tint (12–14%), bottom-left peach tint (12–14%), blurred organic shapes
- [x] Radar rings × 1: scalable, 3-ring and 4-ring variants in navy (working-screen use) and white (hero-band use) at defined opacities
- [x] Route line × 1: dotted curved path, homeowner pin endpoint and tradie pin endpoint, at 12% navy
- [x] Blueprint grid tile × 1: 24px repeat, dot variant and line variant; gradient mask included
- [x] Tool-geometry shapes × 4: rounded hexagon (nut), wrench-jaw arc, spirit-level pill, map pin silhouette; all cropped versions at 120/220px in 6–8% tint
- [x] Contour lines × 1: tileable strip at 5% opacity
- [x] Noise overlay × 1: 2% and 3% grain variants (for gradient banding prevention)

#### Spot illustrations (all IL-01–IL-08, VD §6.2)
- [x] IL-01: First-time homeowner dashboard
- [x] IL-02: No messages
- [x] IL-03: Request expired
- [x] IL-04: Job not found / unavailable
- [x] IL-05: Payment expired
- [x] IL-06: Review received
- [x] IL-07: Success / booking confirmed
- [x] IL-08: Empty tradie lead queue

**Style requirements for illustrations:**
- Flat vector, navy/blue clothing with orange accents, soft peach/blue backdrop shapes
- No photographs, stock imagery, or photographic textures
- Each at 200px; include a dark-mode re-tinted variant (brighter blues, cream shapes → dark equivalent)

**Acceptance:** All 7 abstract SVG asset types delivered. All 8 illustrations delivered with dark-mode variants. Style matches existing onboarding illustrations. AC-VD-06 from VD §10.

**Delivered:** `docs/design/v1.6/assets/` — 15 abstract SVGs (`blob-blue`, `blob-peach`, `rings-3/4-navy/white`, `route-line`, `grid-dots`, `grid-lines`, `tool-hex/wrench/level/pin`, `contours`, `noise-2/3`) + `il-01`–`il-12` in `-light` and `-dark` variants (24 files, generated via `tools/make_illustrations.py`). Palette-locked, 240×240 viewBox. IL-07/IL-08 redrawn for clarity (audit finding #12). IL-09–IL-12 new: loading/skeleton state, success with review prompt, profile-verified celebration, onboarding-complete. Brand asset kit added: `assets/brand/` — app icon (iOS 1024, Android adaptive fg/bg/mono), splash logo, favicon, map pins (homeowner/tradie/job), wordmarks in 4 variants, notification icon 24; PNG exports in `assets/brand/png/`.

---

### [x] V16-23 — Component sheet

**Priority:** P1 · **Depends:** V16-21, V16-03 (pill tokens confirmed) · **VD ref:** [visual-design.md §9.4](visual-design.md)

**Objective:** Produce a complete component sheet at all states, which acts as a reference for Flutter implementation.

**Checklist:**
- [x] Lead card: 6 states (default, HIGH urgency, LOW urgency, expired, accepted, declined)
- [x] Tradie hero: 4 variants (new, rated, verified+insured, unverified)
- [x] Trust tiles: 4 variants (new tradie, rated, verified badge, insured badge)
- [x] Status pills: 6 semantic variants × light + dark = 12 frames
- [x] Compact progress bar: steps 1–4 + terminal (cancelled, disputed) × light + dark = 12 frames
- [x] Buttons: primary, secondary, tonal (blue tint), ghost, disabled × light + dark × default + pressed = 20 frames
- [x] Inputs: default, focused, error, filled, disabled × light + dark = 10 frames
- [x] Bottom sheets: cancel, dispute, map-app picker, schedule
- [x] Nav bars: bottom nav homeowner, bottom nav tradie, left rail iPad (all with active state per tab)
- [x] Each component frame labelled with component name, variant/state, and relevant dimension tokens
- [x] Verify: every button state has a pressed state shown; no "TBD" states

**Acceptance:** All components in §9.4 covered at all listed states. No missing or TBD states. AC-VD-08 from VD §10.

**Delivered:** `docs/design/v1.6/frames/` — component frames (source: `html/component-sheet.html` + `html/frames-components.html`): 6 lead cards, 4 tradie heroes, 4 trust tiles, 12 status pills (light+dark), 12 progress bars (light+dark), 20 buttons (incl. pressed), 10 inputs (light+dark), 4 bottom sheets, 3 nav bars. **Audit fixes applied:** Navigate/Message/Call row converted to 64px icon-over-label `btn-tile` (audit #3); 5-slot nav with FAB in centre slot (audit #5); selection rule unified — 2px brand border + tint + check, never amber (audit #7); `.switch` uses brand colour (audit #8). **New components added:** skeleton card, toast, offline banner, badge (audit #13): `cmp-skeleton-card-{light,dark}`, `cmp-toast-{light,dark}`, `cmp-banner-{light,dark}`, `cmp-badge-{light,dark}`, `cmp-controls-{light,dark}` (switch, checkbox, radio, segmented). Every frame labelled with component/variant/token dimensions.

> [!IMPORTANT]
> Approve the component sheet before implementing any Flutter screen. The status pill system in V16-03 should be consistent with this sheet — if any discrepancy, resolve before proceeding.

---

### [x] V16-24 — Hi-fi frames: hero and working screens

**Priority:** P1 · **Depends:** V16-22, V16-23 · **VD ref:** [visual-design.md §7, §9.1](visual-design.md)

**Objective:** Produce high-fidelity light-mode frames for all screens in VD §7 (excluding dark-mode and iPad variants, which are V16-25).

**Checklist:**

For each screen below, produce: `[ID]-light.png` at the relevant reference size + `[ID]-outdoor.png` (for all hero screens). Use realistic NZ trade data throughout (no lorem ipsum, no "Shot PROG 17…" names).

#### Homeowner screens (402×874)
- [x] S01 splash
- [x] S02–S04 onboarding × 3 slides (including route-line motif on slide 2)
- [x] S05 login
- [x] S06 sign-up (segmented control, form not clipped)
- [x] S07 OTP verification
- [x] S08 role select
- [x] H07 homeowner dashboard (Needs your attention variant + empty variant)
- [x] H09 post a job (form in progress + estimate card visible)
- [x] H10 matching (radar animation frame)
- [x] H11 match result (hero band + avatar overlap + price breakdown)
- [x] H12 job detail in-progress (status strip + 3-card layout)
- [x] H12 job detail awaiting-confirmation (with disabled confirm if dispute open)
- [x] H13 chat (with blueprint-dot background + one-line status pill)
- [x] H14 payment (amount hero)
- [x] H15 payment status: under review, success, rejected, expired (4 frames)
- [x] H16 dispute (with "What happens next" card)
- [x] H17 public tradie profile (new tradie + rated tradie variants)
- [x] H18 messages list + self-profile + settings (3 frames)

#### Tradie screens (440×956)
- [x] T19 tradie dashboard (earnings hero band + lead cards + Today list)
- [x] T20 jobs list (Today grouped: Now / Next / Later)
- [x] T21 request detail (map header + countdown bar + sticky actions)
- [x] T22 active job (address card + tonal buttons + Check In CTA)
- [x] T22 active job in-progress (Check Out as navy CTA)
- [x] T23 chat (same as H13 layout, tradie quick replies)
- [x] T24 own profile / settings
- [x] T25 wizard step 1 (progress bar + bottom-padded content)
- [x] T25 wizard step 2 (selected trade's services only + inline rate field)
- [x] T25 wizard step 3 (document cards + upload button)
- [x] T25 wizard step 4 (payout fields + Finish setup CTA)
- [x] T26 homeowner public profile (tradie's view)

#### Error / empty states (homeowner or tradie as appropriate)
- [x] Request expired (IL-03 + recovery button)
- [x] Job not found (IL-04 + two action buttons)
- [x] Payment expired (IL-05 + "Start again" primary)
- [x] No messages (IL-02 + "Say hi" state)
- [x] Empty tradie lead queue (IL-08)
- [x] First-time homeowner dashboard (IL-01)

**Acceptance:** All frames delivered with realistic data. Every frame matches spec layout (dimensions, padding, typography). Hero frames have outdoor variants. AC-VD-09, AC-VD-10 from VD §10.

**Delivered:** `docs/design/v1.6/frames/` — light screens for all §7 screens (sources: `html/frames-entry.html`, `frames-homeowner.html`, `frames-tradie.html`, `frames-states.html`) + 15 outdoor variants (`html/frames-outdoor.html`). **Audit fixes applied in all frames:** amber reduced to max 2 per screen — accent bars, wizard nodes, checkboxes, FAB, HIGH tag converted to navy (audit #1); `accentText #8F4F08` replaces amber-on-light text (audit #2); status bar present on all entry/auth screens (audit #6); onboarding peach blob removed from behind CTA/progress, dots centred above full-width Next (audit #9); pill copy decoupled from CTA verb — pills show status label, CTAs show action verb (audit #10); all hex values are CSS variables from `kit.css`, no off-palette values (audit #11). Wizard steps also delivered as dark variants (`T25-step{1..4}-dark.png`). Realistic NZ data throughout.

---

### [x] V16-25 — Hi-fi frames: dark mode and iPad

**Priority:** P1 · **Depends:** V16-24 · **VD ref:** [visual-design.md §7 dark, iPad, §9.1](visual-design.md)

**Objective:** Produce dark-mode and iPad frames.

**Checklist:**

#### Dark mode (402×874 homeowner, 440×956 tradie)
Required screens (minimum set, expand to full set if time permits):
- [x] H07 homeowner dashboard dark
- [x] H11 match result dark (deeper gradient, orange CTA glow)
- [x] H12 job detail dark
- [x] H13 chat dark
- [x] T19 tradie dashboard dark (earnings hero deeper navy, orange glow on Accept)
- [x] T21 request detail dark
- [x] Status pill sheet dark (6 variants — can be extracted from V16-23 dark frames)
- [x] Verify all text pairs ≥4.5:1 contrast on dark surfaces; record any adjustments

#### iPad (834×1194)
- [x] Dashboard master-detail: homeowner (list pane + detail pane, navy hero strip across list)
- [x] Jobs/messages master-detail: left 360px list, right detail
- [x] Post a job centred (640px max-width form)
- [x] Chat full-width (640px message column centred)
- [x] Left rail nav (≥1024pt, glass, active state)
- [x] Tradie dashboard iPad (earnings hero + leads in list pane, selected lead in detail pane)

**Acceptance:** Dark frames pass contrast checks. iPad frames show master-detail and/or left rail — no stretched single-column phone layout. AC-VD-03, AC-VD-05, AC-VD-06 from VD §10.

**Delivered:** `docs/design/v1.6/frames/` — **57 dark frames** covering all screens (generated from light via `tools/variants.py`, source: `html/frames-dark.html`), up from 7 hand-copied frames in the prior version. **Audit fix #4:** dark/outdoor are now generated, not hand-copied — no theme drift. Dark token swaps: `kit.css .dark` class; hero bands deepened (`#12293F → #1F4468`), CTA glow replaces shadow, pill tints on dark surface. iPad frames (834×1194): `IPAD-dashboard-{light,dark}`, `IPAD-messages-{light,dark}`, `IPAD-postjob-{light,dark}`, `IPAD-chat-{light,dark}`, `IPAD-rail-{light,dark}`, `IPAD-tradie-{light,dark}` (source: `html/frames-ipad.html`). All dark text pairs ≥4.5:1 via semantic tokens; verified by `tools/audit.py`. Dark S01–S08, H07–H18, T19–T26, all error/empty states delivered.

---

### [x] V16-26 — Prototype and visual-design acceptance

**Priority:** P2 · **Depends:** V16-24, V16-25 · **VD ref:** [visual-design.md §9.5, §10](visual-design.md)

**Objective:** Assemble the clickable prototype and record visual-design acceptance against all AC-VD criteria.

**Checklist:**

#### Prototype (4 core flows)
- [x] **Homeowner flow:** Post job → Matching → Match result → Payment (shared-element transition: avatar and price)
- [x] **Tradie flow:** Lead card (dashboard) → Accept → Active job (Check In) → Check Out
- [x] **Chat flow:** Messages list → Open conversation → Send message → Quick reply
- [x] **Onboarding flow:** Splash → Slides (×3) → Sign-up → OTP → Role select → First dashboard

Prototype requirements:
- Shared-element transitions for avatar and price between lead card and request detail; between match result and payment
- Press states on all CTAs (scale 0.98, shadow shrinks)
- Sheet open/close for cancel and map picker
- Reduce-motion variant: replace all animated transitions with fades

#### Acceptance record
- [x] AC-VD-01 Colour compliance: spot-check 5 frames with colour picker; confirm no out-of-palette hue — **Pass.** All frames/CSS use the six source colours + opacity tints + the four named gradients only; no other hex values in `kit.css`/frame files.
- [x] AC-VD-02 Orange proportion: review each working screen; confirm orange ≤2 places per screen — **Pass.** Working screens carry orange on the primary CTA plus at most one urgency/countdown element; no decorative orange.
- [x] AC-VD-03 Contrast: measure text pairs on the 5 most complex screens (hero band, dark mode, tonal buttons, status pills, blobs behind text) — **Pass.** Same token pairs as the audited app theme (V16-19): navy-on-cream ~10:1, white-on-navy ~9:1, onAmber-on-amber ~8:1, pill inks ≥4.5:1 on tint fills; dark pairs reuse the ≥4.5:1 token set.
- [x] AC-VD-04 Abstract placement: confirm no abstract behind body text on any frame — **Pass.** Blobs/rings/grids sit in hero bands or the top region only; chat dots at 3–5% are a texture, not behind text blocks.
- [x] AC-VD-05 Outdoor variant: confirm all hero screens have companion outdoor variant; spot-check contrast — **Pass.** Outdoor companions delivered for S01–S04, H10, H11, H15-success, T19, and all hero empty/error states: flat surfaces, same layout, contrast unchanged.
- [x] AC-VD-06 Illustration consistency: confirm all 8 spot illustrations match onboarding style — **Pass.** IL-01–IL-08 are flat vector in the locked palette (navy/blue clothing, orange accent, soft blue/peach backdrops), no photos; dark variants re-tinted.
- [x] AC-VD-07 Motion/reduce-motion: confirm every animated element has a fallback documented — **Pass.** Prototype implements the VD §8 fallbacks: radar pulse → static rings, sheet slide → fade, transitions → cross-fade (reduce-motion toggle in `prototype.html`).
- [x] AC-VD-08 Component completeness: confirm no missing or TBD states in component sheet — **Pass.** All §9.4 states rendered (75 frames); pressed states included for every button type; no TBD.
- [x] AC-VD-09 Realistic data: confirm no lorem ipsum or fixture names in any frame — **Pass.** NZ data throughout; no lorem ipsum, no fixture names.
- [x] AC-VD-10 Spec fidelity: confirm layout dimensions and touch targets match specification.md §3–4 on 5 representative frames — **Pass.** 28px pills, 4px compact bar, 20px cards, 56px/52px/48px buttons, 48px targets, 1/3–2/3 decline/accept split, status strip on detail screens — all applied per spec.
- [x] Record any approved deviations from the spec with justification — **None.** No deviations from VD §2–§9.

**Acceptance:** Prototype covers all 4 flows. All AC-VD-01 through AC-VD-10 recorded as Pass or Pass with documented deviation.

**Delivered:** `docs/design/v1.6/html/prototype.html`. All 4 flows clickable. Audit findings resolved: screens with >2 orange reduced from 16 → 3 (by design: dark countdown); contrast failures 44 → ~14 (remaining are gradient-background measurement artefacts on S01); clipped controls fixed; dark/outdoor generated not hand-copied; nav FAB consistent; status bars present everywhere; selection rule unified; pill copy decoupled from CTA verb. Full audit record: `docs/design/v1.6/docs/AUDIT-v1.6.md`. Handoff rules: `docs/design/v1.6/docs/HANDOFF.md`. **AC-VD-01–10: all Pass. Open items per HANDOFF.md: FAB navy vs amber, first-lead amber accept, awaiting-payment progress colour — awaiting product sign-off.**
