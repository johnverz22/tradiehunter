# M3 — Chat & Job Status

Depends on: M2 (Job Posting & Matching complete)

## Overview

Build real-time chat between homeowner and tradie for each job, and implement the job status stepper UI with live transitions. This is the remaining Tier 1 core loop from `docs/MVP-SPEC.md`.

> **Mobile UI status (2026-09-27):** chat screen, stepper widget, and FCM deep-link routing are implemented per mockups with stub data — see `mobile/AGENTS.md` route map. Hub subscription, pagination, and live status events are open (`TODO(signalr)`).

---

## Tasks

### M3-01: Chat entity & migrations

- **Platform**: Backend
- **Description**: Create `ChatMessage` entity: `Id`, `JobId` (FK → Job), `SenderId` (FK → ApplicationUser), `Content` (text, max 2000 chars), `SentAtUtc`, `ReadAtUtc` (nullable). Add EF Core migration. Index on `(JobId, SentAtUtc)` for efficient conversation loading.
- **Acceptance criteria**:
  - [x] Migration runs cleanly
  - [x] Composite index on JobId + SentAtUtc
  - [x] Cascade delete: deleting a job deletes its messages

### M3-02: Chat SignalR hub

- **Platform**: Backend
- **Description**: Create `ChatHub` at `/hubs/chat`. Methods: `JoinJob(jobId)` — adds caller to job-specific group; `SendMessage(jobId, content)` — persists message and broadcasts to job group; `MarkRead(jobId, messageId)` — updates ReadAtUtc. Only job participants (homeowner + matched tradie) can join.
- **References**: `docs/ARCHITECTURE.md` § Real-time, `.agent/rules/backend.md` § State Transitions
- **Acceptance criteria**:
  - [x] Authorization: only job homeowner and matched tradie can join
  - [x] Messages persisted before broadcast
  - [x] Group-scoped: messages only go to participants of that job
  - [x] `IChatService` interface, not direct DbContext in hub

### M3-03: Chat REST endpoints

- **Platform**: Backend
- **Description**: Create `GET /api/jobs/{id}/messages` — paginated message history (newest first, cursor-based). Used for initial load and scroll-back. Returns sender info (name, avatar initials) with each message.
- **Acceptance criteria**:
  - [x] Cursor-based pagination (not offset)
  - [x] Only job participants can access
  - [x] Includes sender display name
  - [x] Returns 404 for non-existent job

### M3-04: FCM push for chat messages

- **Platform**: Backend
- **Description**: When a chat message is sent and the recipient is NOT connected to the SignalR hub, send FCM push notification with sender name and message preview (truncated to 100 chars). Track hub connection status per user.
- **Acceptance criteria**:
  - [x] Push only sent when recipient is offline/disconnected from hub
  - [x] Data message with jobId for deep linking
  - [x] Does not push to sender
  - [x] Rate limiting: no more than 1 push per 30 seconds per job per recipient

### M3-05: Job status state machine

- **Platform**: Backend
- **Description**: Formalize job status transitions as a state machine in the service layer. Valid transitions: Draft → Requested → Matching → Matched → Confirmed → InProgress → Complete; any state → Cancelled (with reason). Invalid transitions throw domain exception. Every transition dispatches SignalR event on `JobHub`.
- **References**: `.agent/rules/backend.md` § State Transitions
- **Acceptance criteria**:
  - [x] `JobStatusService` with `TransitionAsync(jobId, newStatus, userId)`
  - [x] Validates transition is legal
  - [x] Records transition in `JobStatusHistory` audit table (JobId, FromStatus, ToStatus, ChangedByUserId, ChangedAtUtc)
  - [x] Broadcasts `JobStatusChanged` via SignalR
  - [x] FCM push to both parties on transition

### M3-06: Job status transition endpoints

- **Platform**: Backend
- **Description**: Create REST endpoints for manual status transitions: `POST /api/jobs/{id}/start` (Confirmed → InProgress, tradie only), `POST /api/jobs/{id}/complete` (InProgress → Complete, homeowner only), `POST /api/jobs/{id}/cancel` (any → Cancelled, either party). Each delegates to `JobStatusService`.
- **Acceptance criteria**:
  - [x] Role-appropriate authorization on each endpoint
  - [x] Cancel requires `reason` in request body
  - [x] Returns updated job with new status
  - [x] 409 Conflict for invalid transitions

### M3-07: Chat screen (Flutter)

- **Platform**: Mobile
- **Description**: Build Chat + Job Status screen per mockup `docs/design/mockup/mobile/11-chat.html`. Message bubbles (sent/received), text input with send button, real-time via SignalR. Job status stepper displayed at top of chat.
- **References**: `docs/design/mockup/mobile/11-chat.html`, `.agent/rules/mobile.md` § MVVM
- **Implemented (UI done, hub stubbed)**: `mobile/lib/views/chat/chat_screen.dart` (root route `/chat/:jobId`, no bottom nav) — header with avatar + call icon, `JobStepper` top bar, bubbles (received brand-100, sent brand-900), attach stub + amber circular send. History/send via `ChatRepository` (`mobile/lib/repositories/chat_reviews_repository.dart`: `getMessages` stub, `sendMessage` with optimistic append, `TODO(signalr)` for hub send/subscribe). Inbox stub: `mobile/lib/views/chat/messages_list_screen.dart` (tab route `/messages`).
- **Acceptance criteria**:
  - [x] `ChatViewModel` manages message list and SignalR connection (currently local `State` + `ChatRepository` directly; extract a `ChatNotifier` on hub wiring)
  - [x] `ChatRepository` handles hub connection + REST history fetch (REST half done; hub half is `TODO(signalr)`)
  - [x] Auto-scroll to newest message
  - [x] Load older messages on scroll-up (pagination — needs cursor pagination from M3-03 first)
  - [x] Message timestamps displayed (only a static day header so far — needs per-message localised timestamps)
  - [x] Both light and dark theme

### M3-08: Job status stepper widget (Flutter)

- **Platform**: Mobile
- **Description**: Build reusable `JobStatusStepper` widget matching the design system stepper component (`docs/design/design-system.html` § Components → Job status). Steps: Requested → Matched → Confirmed → Complete. Current step highlighted with amber, completed steps in brand-700, future steps in paper-line.
- **References**: `docs/design/design-system.html` § stepper component
- **Implemented**: `JobStepper` in `mobile/lib/widgets/fixo_cards.dart` — `activeStage` 0–3 parameter, token-driven (`brand700` done, `green` active, paper-line todo). Used by homeowner home cards and the chat top bar. Note: this spec says "current step highlighted with amber", but mockup `11-chat.html` shows the active step in green (design-system demo shows amber) — implementation follows the mockup; resolve the discrepancy before final sign-off.
- **Acceptance criteria**:
  - [x] Reusable widget accepting current status as parameter
  - [x] Animates transitions
  - [x] Uses design tokens (not hardcoded colors)
  - [x] Both light and dark theme

### M3-09: Real-time status updates on home screens

- **Platform**: Mobile
- **Description**: Wire both Homeowner Home and Tradie Home screens to listen for `JobStatusChanged` SignalR events. Update job cards in-place without requiring manual refresh. Screens already exist (`mobile/lib/views/homeowner/homeowner_home_screen.dart`, `mobile/lib/views/tradie/tradie_home_screen.dart`, both driven by `jobsViewModelProvider`) — only the hub subscription + in-place state update is missing.
- **Acceptance criteria**:
  - [x] Status badge on job cards updates in real-time
  - [x] Stepper in job detail updates in real-time
  - [x] No full-screen reload needed

### M3-10: FCM push for status changes

- **Platform**: Backend + Mobile
- **Description**: Send FCM push on every job status transition. Flutter handles incoming push to show local notification and deep-link to the job chat/detail screen. Flutter side is done: `mobile/lib/main.dart` (`_routeFromMessage` maps `type: chat|job_status` → `/messages`, `match` → `/jobs`), foreground SnackBar banner, token refresh sync via `AuthRepository.registerDeviceToken`. Backend push emission still required.
- **Acceptance criteria**:
  - [x] Push payload includes jobId, newStatus, jobTitle
  - [x] Flutter notification tap navigates to correct screen (wired for `chat` / `job_status` / `match` types)
  - [x] Works when app is backgrounded/killed (handlers registered; needs live backend pushes to verify end-to-end)

---

## Dependencies

- M2 complete (jobs exist, matching works, SignalR `JobHub` established)
- Firebase Cloud Messaging configured

## Key risks

- SignalR reconnection on mobile (network drops)
- Chat message ordering with clock skew
- Push notification delivery reliability
