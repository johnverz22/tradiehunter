import 'dart:async';
// FixoNotice — public static façade + FixoNoticeHost overlay widget.
//
// Usage:
//   1. Wrap MaterialApp.router content with FixoNoticeHost.
//   2. At any call site:  FixoNotice.success(context, NoticeCopy.profileUpdated);
//
// See: docs/design/feedback-guidelines.md

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/design_tokens.dart';
import 'fixo_notice_controller.dart';

export 'fixo_notice_controller.dart'
    show
        FixoNoticeTone,
        FixoNoticeState,
        FixoNoticeController,
        fixoNoticeProvider;
export 'notice_copy.dart';

// ── Public façade ────────────────────────────────────────────────────────────

/// Static helpers that dispatch a notice via [FixoNoticeController].
///
/// Every method looks up the nearest [ProviderScope] from [context], so it
/// works from any widget in the tree — including inside GoRouter pages.
abstract class FixoNotice {
  FixoNotice._();

  /// Neutral confirmation or informational message (3 s).
  static void info(BuildContext context, String message) =>
      _show(context, FixoNoticeTone.info, message);

  /// Successful operation feedback (3 s).
  static void success(BuildContext context, String message) =>
      _show(context, FixoNoticeTone.success, message);

  /// Non-blocking warning (4 s).
  static void warning(BuildContext context, String message) =>
      _show(context, FixoNoticeTone.warning, message);

  /// Failed-operation feedback, ask user to retry (5 s).
  static void error(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) =>
      _show(
        context,
        FixoNoticeTone.error,
        message,
        action: onRetry,
        actionLabel: onRetry != null ? 'Retry' : null,
      );

  /// In-app FCM foreground push notification with optional "View" action (5 s).
  ///
  /// [title] renders in bold above [body]. Pass [onView] for a "View" button.
  static void push(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onView,
  }) {
    _show(
      context,
      FixoNoticeTone.push,
      body,
      title: title,
      action: onView,
      actionLabel: onView != null ? 'View' : null,
    );
  }

  /// Error from a dynamic message (e.g. from DioException, payment API).
  static void errorDynamic(BuildContext context, String message) =>
      error(context, message);

  static OverlayEntry? _fallbackEntry;
  static Timer? _fallbackTimer;

  static void _show(
    BuildContext context,
    FixoNoticeTone tone,
    String message, {
    String? title,
    VoidCallback? action,
    String? actionLabel,
  }) {
    final notice = FixoNoticeState(
      message: message,
      tone: tone,
      title: title,
      action: action,
      actionLabel: actionLabel,
    );

    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(fixoNoticeProvider.notifier).show(notice);
    } catch (_) {}

    // If FixoNoticeHost is not an ancestor (e.g. isolated widget tests),
    // fall back to inserting an OverlayEntry into the nearest Overlay.
    if (context.findAncestorStateOfType<_FixoNoticeHostState>() == null) {
      _showOverlayFallback(context, notice);
    }
  }

  static void _cancelFallback() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _fallbackEntry?.remove();
    _fallbackEntry = null;
  }

  static void _showOverlayFallback(
    BuildContext context,
    FixoNoticeState notice,
  ) {
    _cancelFallback();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _fallbackEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _FixoNoticeBanner(
          notice: notice,
          onDismiss: _cancelFallback,
        ),
      ),
    );

    overlay.insert(_fallbackEntry!);
  }
}

// ── Host widget ──────────────────────────────────────────────────────────────

/// Wraps [child] and renders an in-app notice banner in an [Overlay] entry
/// whenever a notice is active.
///
/// Place this directly around `MaterialApp.router`'s `builder` or as the
/// top-level child inside the builder so it has access to the [Overlay]:
///
/// ```dart
/// MaterialApp.router(
///   builder: (context, child) => FixoNoticeHost(child: child ?? const SizedBox()),
///   ...
/// )
/// ```
class FixoNoticeHost extends ConsumerStatefulWidget {
  const FixoNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FixoNoticeHost> createState() => _FixoNoticeHostState();
}

class _FixoNoticeHostState extends ConsumerState<FixoNoticeHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  FixoNoticeState? _current;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: FixoDurations.noticeAnimate,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animController.dispose();
    FixoNotice._cancelFallback();
    super.dispose();
  }

  void _onNoticeChanged(FixoNoticeState? notice) {
    if (notice == null) {
      _animController.reverse().then((_) {
        if (mounted) setState(() => _current = null);
      });
    } else {
      setState(() => _current = notice);
      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FixoNoticeState?>(fixoNoticeProvider, (_, next) {
      if (mounted) _onNoticeChanged(next);
    });

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildBanner(),
          ),
      ],
    );
  }

  Widget _buildBanner() {
    final notice = _current;
    if (notice == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: child,
        ),
      ),
      child: _FixoNoticeBanner(
        notice: notice,
        onDismiss: () =>
            ref.read(fixoNoticeProvider.notifier).dismiss(),
      ),
    );
  }
}

// ── Banner widget ─────────────────────────────────────────────────────────────

class _FixoNoticeBanner extends StatefulWidget {
  const _FixoNoticeBanner({
    required this.notice,
    required this.onDismiss,
  });

  final FixoNoticeState notice;
  final VoidCallback onDismiss;

  @override
  State<_FixoNoticeBanner> createState() => _FixoNoticeBannerState();
}

class _FixoNoticeBannerState extends State<_FixoNoticeBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.notice.tone.autoDismiss, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void didUpdateWidget(covariant _FixoNoticeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice != widget.notice) {
      _timer?.cancel();
      _timer = Timer(widget.notice.tone.autoDismiss, () {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    FixoNotice._cancelFallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final onDismiss = widget.onDismiss;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).extension<THColors>()!;

    final (bg, border, iconColor, textColor) =
        _resolveColors(notice.tone, isDark, colors);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.s4,
          Space.s2,
          Space.s4,
          Space.s0_5,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(minHeight: Sizes.noticeMinH),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.tile),
              border: Border.all(color: border, width: Sizes.noticeBorderW),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: Alpha.subtle),
                  blurRadius: Space.s2,
                  offset: const Offset(0, Space.s0_5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sizes.noticeHPad,
                vertical: Sizes.noticeVPad,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leading icon
                  Padding(
                    padding:
                        const EdgeInsets.only(top: Space.s0_5, right: Space.s3),
                    child: Icon(
                      _iconFor(notice.tone),
                      size: Sizes.noticeIconSize,
                      color: iconColor,
                    ),
                  ),
                  // Message body
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (notice.title != null)
                          Text(
                            notice.title!,
                            style: TextStyle(
                              fontFamily: TypeTokens.fontBody,
                              fontSize: DesignTokens.fontSizeSm,
                              fontWeight: FW.semibold,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                        Text(
                          notice.message,
                          style: TextStyle(
                            fontFamily: TypeTokens.fontBody,
                            fontSize: DesignTokens.fontSizeSm,
                            fontWeight: FW.regular,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                        if (notice.action != null && notice.actionLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.s1_5),
                            child: GestureDetector(
                              onTap: () {
                                notice.action!();
                                onDismiss();
                              },
                              child: Text(
                                notice.actionLabel!,
                                style: TextStyle(
                                  fontFamily: TypeTokens.fontBody,
                                  fontSize: DesignTokens.fontSizeSm,
                                  fontWeight: FW.semibold,
                                  color: iconColor,
                                  decoration: TextDecoration.underline,
                                  decorationColor: iconColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onDismiss();
                    },
                    child: SizedBox(
                      width: Sizes.tapMin,
                      height: Sizes.tapMin,
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: Sizes.noticeCloseSize,
                          color: textColor.withValues(alpha: Alpha.ghost),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(FixoNoticeTone tone) => switch (tone) {
        FixoNoticeTone.info    => Icons.info_outline_rounded,
        FixoNoticeTone.success => Icons.check_circle_outline_rounded,
        FixoNoticeTone.warning => Icons.warning_amber_rounded,
        FixoNoticeTone.error   => Icons.error_outline_rounded,
        FixoNoticeTone.push    => Icons.notifications_outlined,
      };

  /// Returns (background, borderColor, iconColor, textColor).
  static (Color, Color, Color, Color) _resolveColors(
    FixoNoticeTone tone,
    bool isDark,
    THColors colors,
  ) {
    return switch (tone) {
      FixoNoticeTone.info => (
          colors.surface,
          colors.line,
          colors.textSoft,
          colors.text,
        ),
      FixoNoticeTone.success => (
          colors.success.withValues(alpha: Alpha.faint),
          colors.success.withValues(alpha: Alpha.tintStandard),
          colors.success,
          colors.text,
        ),
      FixoNoticeTone.warning => (
          colors.accent.withValues(alpha: Alpha.faint),
          colors.accent.withValues(alpha: Alpha.tintLight),
          colors.accentText,
          colors.text,
        ),
      FixoNoticeTone.error => (
          colors.danger.withValues(alpha: Alpha.faint),
          colors.danger.withValues(alpha: Alpha.tintStandard),
          colors.danger,
          colors.text,
        ),
      FixoNoticeTone.push => (
          colors.brand.withValues(alpha: Alpha.subtle),
          colors.brand.withValues(alpha: Alpha.tintStandard),
          colors.brand,
          colors.text,
        ),
    };
  }
}
