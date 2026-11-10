// FixoNotice — Riverpod-backed in-app notice (toast) system.
//
// Architecture:
//   FixoNoticeController   StateNotifier<FixoNoticeState?> that holds the
//                          currently-visible notice and schedules auto-dismiss.
//   fixoNoticeProvider     Global Riverpod provider for the controller.
//
// See: docs/design/feedback-guidelines.md

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/design_tokens.dart';

// ── Notice tone ──────────────────────────────────────────────────────────────

/// Semantic tone for a [FixoNoticeState].
enum FixoNoticeTone { info, success, warning, error, push }

extension FixoNoticeToneX on FixoNoticeTone {
  Duration get autoDismiss => switch (this) {
        FixoNoticeTone.info    => FixoDurations.noticeInfo,
        FixoNoticeTone.success => FixoDurations.noticeSuccess,
        FixoNoticeTone.warning => FixoDurations.noticeWarning,
        FixoNoticeTone.error   => FixoDurations.noticeError,
        FixoNoticeTone.push    => FixoDurations.noticePush,
      };
}

// ── Notice data ──────────────────────────────────────────────────────────────

@immutable
class FixoNoticeState {
  const FixoNoticeState({
    required this.message,
    required this.tone,
    this.title,
    this.action,
    this.actionLabel,
  });

  final String message;
  final FixoNoticeTone tone;

  /// Optional bold heading above [message] (used for push notifications).
  final String? title;

  /// Optional callback for the action button (e.g. "View" on push notices).
  final VoidCallback? action;

  /// Label for the action button. Required when [action] is set.
  final String? actionLabel;
}

// ── Controller ───────────────────────────────────────────────────────────────

/// Manages the single currently-visible notice.
///
/// Call [show] to display a notice. Any previous notice is immediately
/// replaced. The notice auto-dismisses after [FixoNoticeTone.autoDismiss].
class FixoNoticeController extends StateNotifier<FixoNoticeState?> {
  FixoNoticeController() : super(null);

  /// Display [notice]. Any previous notice is immediately replaced.
  void show(FixoNoticeState notice) {
    state = notice;
  }

  /// Remove the current notice immediately (e.g. user pressed ×).
  void dismiss() {
    state = null;
  }
}

/// Global provider.  Kept alive for the app lifetime (autoDispose omitted).
final fixoNoticeProvider =
    StateNotifierProvider<FixoNoticeController, FixoNoticeState?>(
  (ref) => FixoNoticeController(),
);
