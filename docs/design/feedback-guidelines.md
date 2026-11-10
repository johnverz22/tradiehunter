# Fixo Mobile — Feedback & Notice Guidelines

> Source of truth for in-app user feedback messages.  
> Implements the `FixoNotice` system that replaces all `ScaffoldMessenger.showSnackBar` calls.

---

## 1. Classification Table

| Tone | `FixoNotice` method | When to use | Icon | Auto-dismiss |
|:--|:--|:--|:--|:--|
| **info** | `FixoNotice.info(ctx, msg)` | Neutral confirmations, copy actions, non-critical state changes (e.g. "Copied", "Code sent", "Feature not available") | `Icons.info_outline_rounded` | 3 s |
| **success** | `FixoNotice.success(ctx, msg)` | Completed user actions with positive outcomes (e.g. "Profile updated", "Job cancelled", "Offer accepted") | `Icons.check_circle_outline_rounded` | 3 s |
| **warning** | `FixoNotice.warning(ctx, msg)` | Non-blocking caution (e.g. "Could not refresh", "No connection", expiry near) | `Icons.warning_amber_rounded` | 4 s |
| **error** | `FixoNotice.error(ctx, msg)` | Failed operations the user should retry (e.g. "Check-in failed", "Could not send message") | `Icons.error_outline_rounded` | 5 s |
| **push** | `FixoNotice.push(ctx, title, body, onTap)` | In-app FCM foreground notification banner with an optional "View" action | `Icons.notifications_outlined` | 5 s |

---

## 2. Placement & Behaviour

- Notices appear at the **top** of the screen, below the status bar / AppBar, sliding down from behind the system chrome.
- At most **one notice** is visible at a time; a new call replaces the current one with a cross-fade.
- Notices **dismiss automatically** after their configured duration.
- Notices **do not block** tap-through to the page content (they sit in the Overlay, not inside the Scaffold body).
- Touch target for the entire notice row is ≥ 48 dp; a close button (×) with ≥ 48 dp target is on the trailing edge.

---

## 3. Content Rules

| Rule | Detail |
|:--|:--|
| **Sentence case** | "Profile updated successfully" — not "Profile Updated Successfully". |
| **Active voice** | "Job cancelled" — not "The job has been cancelled by the user". |
| **Max 80 chars** | A single line at the minimum supported screen width (375 pt). Multi-word action labels are allowed but rare. |
| **No duplicate confirmation** | Don't show a notice AND an inline error state for the same failure. |
| **Dynamic values** | Interpolate names, codes, emails using `NoticeCopy` string getters, never inline string literals in call sites. |
| **FCM push tone** | Reserved for `FixoApp._handleForegroundMessage` only. Regular screens use the other four tones. |

---

## 4. `NoticeCopy` String Reference

All user-facing notice strings live in `mobile/lib/feedback/notice_copy.dart`.  
Call sites reference `NoticeCopy.*` constants / getters — never inline string literals.

| Constant | Value |
|:--|:--|
| `NoticeCopy.copied` | `'Copied to clipboard'` |
| `NoticeCopy.noCallApp` | `'No app available to make the call.'` |
| `NoticeCopy.noOtherUser` | `'No other user on this job yet.'` |
| `NoticeCopy.userBlocked` | `'User blocked.'` |
| `NoticeCopy.reportSent` | `'Thanks — our team will review this report.'` |
| `NoticeCopy.photoUnavailable` | `'Photo attachments are not available in chat.'` |
| `NoticeCopy.jobCancelled` | `'Job cancelled.'` |
| `NoticeCopy.noShowReported` | `'No-show reported successfully.'` |
| `NoticeCopy.noShowFailed` | `'Could not report no-show.'` |
| `NoticeCopy.checkInFailed` | `'Check-in failed. Please try again.'` |
| `NoticeCopy.checkOutFailed` | `'Check-out failed. Please try again.'` |
| `NoticeCopy.offerDeclineFailed` | `'Could not decline — please try again.'` |
| `NoticeCopy.offerAcceptFailed` | `'Could not accept — please try again.'` |
| `NoticeCopy.profileUpdated` | `'Profile updated successfully.'` |
| `NoticeCopy.reviewsLocked` | `'Reviews unlock after a completed job.'` |
| `NoticeCopy.requestFailed` | `'Could not send the request. Try again.'` |
| `NoticeCopy.codeSent(email)` | `'New code sent to $email'` |
| `NoticeCopy.stubUnavailable(label)` | `'$label is not available in this app.'` |
| `NoticeCopy.newJobRequest(title)` | `'New Job Request: $title'` |
| `NoticeCopy.onlineStatusChanged(online)` | `'You are now ${online ? 'online' : 'offline'}'` |

---

## 5. Architecture

```
ProviderScope
  └── FixoNoticeHost        ← wraps MaterialApp.router content
        ├── _noticeController (FixoNoticeController)
        └── Overlay entry   ← AnimatedSwitcher slides in/out
              └── _FixoNoticeBanner  (tone-coloured pill)
```

- `FixoNoticeController` — `StateNotifier<FixoNoticeState?>` via Riverpod.
- `FixoNotice` — static façade; looks up `FixoNoticeController` from context using `ProviderScope`.
- `FixoNoticeHost` — `ConsumerWidget` that wraps the child and owns the `OverlayEntry`.
- Debug gallery route: `/debug/notice-gallery` (only registered in `kDebugMode`).
