// THNotice — Riverpod-backed in-app notice (toast) system.
//
// Architecture:
//   THNoticeController   StateNotifier<THNoticeState?> that holds the
//                          currently-visible notice and schedules auto-dismiss.
//   thNoticeProvider     Global Riverpod provider for the controller.
//
// See: docs/design/feedback-guidelines.md

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/th_tokens.dart';

// ── Notice tone ──────────────────────────────────────────────────────────────

/// Semantic tone for a [THNoticeState].
enum THNoticeTone { info, success, warning, error, push }

extension THNoticeToneX on THNoticeTone {
  Duration get autoDismiss => switch (this) {
    THNoticeTone.info => THDurations.noticeInfo,
    THNoticeTone.success => THDurations.noticeSuccess,
    THNoticeTone.warning => THDurations.noticeWarning,
    THNoticeTone.error => THDurations.noticeError,
    THNoticeTone.push => THDurations.noticePush,
  };
}

// ── Notice data ──────────────────────────────────────────────────────────────

@immutable
class THNoticeState {
  const THNoticeState({
    required this.message,
    required this.tone,
    this.title,
    this.action,
    this.actionLabel,
  });

  final String message;
  final THNoticeTone tone;

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
/// replaced. The notice auto-dismisses after [THNoticeTone.autoDismiss].
class THNoticeController extends StateNotifier<THNoticeState?> {
  THNoticeController() : super(null);

  /// Display [notice]. Any previous notice is immediately replaced.
  void show(THNoticeState notice) {
    state = notice;
  }

  /// Remove the current notice immediately (e.g. user pressed ×).
  void dismiss() {
    state = null;
  }
}

/// Global provider.  Kept alive for the app lifetime (autoDispose omitted).
final thNoticeProvider =
    StateNotifierProvider<THNoticeController, THNoticeState?>(
      (ref) => THNoticeController(),
    );
