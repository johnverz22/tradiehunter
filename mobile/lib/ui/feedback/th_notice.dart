// THNotice: in-app notices (toasts) in the v2 Trust Navy + Gold skin.
//
// Usage:
//   1. Wrap MaterialApp.router's builder child with [THNoticeHost].
//   2. At any call site: `THNotice.success(context, NoticeCopy.profileUpdated);`
//
// State lives in `thNoticeProvider` (th_notice_controller.dart); copy lives in
// `NoticeCopy` (notice_copy.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'th_notice_controller.dart'
    show THNoticeState, THNoticeTone, THNoticeToneX, thNoticeProvider;
import '../design/th_tokens.dart';

export 'notice_copy.dart' show NoticeCopy;

/// Static façade that dispatches a notice via [THNoticeController].
///
/// `THNotice.success(context, NoticeCopy.profileUpdated);`
abstract class THNotice {
  THNotice._();

  static void info(BuildContext context, String message) =>
      _show(context, THNoticeTone.info, message);

  static void success(BuildContext context, String message) =>
      _show(context, THNoticeTone.success, message);

  static void warning(BuildContext context, String message) =>
      _show(context, THNoticeTone.warning, message);

  static void error(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) => _show(
    context,
    THNoticeTone.error,
    message,
    action: onRetry,
    actionLabel: onRetry != null ? 'Retry' : null,
  );

  /// Foreground push notification with an optional "View" action.
  static void push(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onView,
  }) => _show(
    context,
    THNoticeTone.push,
    body,
    title: title,
    action: onView,
    actionLabel: onView != null ? 'View' : null,
  );

  /// Error from a dynamic message (DioException, payment API, ...).
  static void errorDynamic(BuildContext context, String message) =>
      error(context, message);

  static void _show(
    BuildContext context,
    THNoticeTone tone,
    String message, {
    String? title,
    VoidCallback? action,
    String? actionLabel,
  }) {
    final notice = THNoticeState(
      message: message,
      tone: tone,
      title: title,
      action: action,
      actionLabel: actionLabel,
    );
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(thNoticeProvider.notifier).show(notice);
    } catch (_) {
      // No ProviderScope above this context: nothing can show the notice.
    }
  }
}

/// Overlay host drawing the active notice with [THNoticeBanner].
/// Place around `MaterialApp.router`'s builder child.
class THNoticeHost extends ConsumerStatefulWidget {
  const THNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<THNoticeHost> createState() => _THNoticeHostState();
}

class _THNoticeHostState extends ConsumerState<THNoticeHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: THDurations.base,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeIn,
  );

  THNoticeState? _current;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onChanged(THNoticeState? notice) {
    if (notice == null) {
      _anim.reverse().then((_) {
        if (mounted) setState(() => _current = null);
      });
    } else {
      setState(() => _current = notice);
      _anim.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<THNoticeState?>(thNoticeProvider, (_, next) {
      if (mounted) _onChanged(next);
    });
    final notice = _current;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        widget.child,
        if (notice != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: THNoticeBanner(
                  notice: notice,
                  onDismiss: () =>
                      ref.read(thNoticeProvider.notifier).dismiss(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The v2 banner. Picks light/dark `THColors` from the ambient brightness, so it
/// renders correctly even when mounted above any `ThScope` (e.g. at the app root).
class THNoticeBanner extends StatefulWidget {
  const THNoticeBanner({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final THNoticeState notice;
  final VoidCallback onDismiss;

  @override
  State<THNoticeBanner> createState() => _THNoticeBannerState();
}

class _THNoticeBannerState extends State<THNoticeBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant THNoticeBanner old) {
    super.didUpdateWidget(old);
    if (old.notice != widget.notice) _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.notice.tone.autoDismiss, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static IconData _icon(THNoticeTone tone) => switch (tone) {
    THNoticeTone.info => Icons.info_outline_rounded,
    THNoticeTone.success => Icons.check_circle_outline_rounded,
    THNoticeTone.warning => Icons.warning_amber_rounded,
    THNoticeTone.error => Icons.error_outline_rounded,
    THNoticeTone.push => Icons.notifications_outlined,
  };

  /// (background, border, accent) per tone, all from v2 tokens.
  static (Color, Color, Color) _palette(THNoticeTone tone, THColors c) =>
      switch (tone) {
        THNoticeTone.info => (c.surface, c.line, c.textSoft),
        THNoticeTone.success => (c.successTint, c.success, c.success),
        THNoticeTone.warning => (c.accentTint, c.accent, c.accentText),
        THNoticeTone.error => (c.dangerTint, c.danger, c.danger),
        THNoticeTone.push => (c.tintBrand, c.brand, c.textBrand),
      };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = dark ? THColors.dark : THColors.light;
    final notice = widget.notice;
    final (bg, border, accent) = _palette(notice.tone, c);
    final live =
        notice.tone == THNoticeTone.error ||
        notice.tone == THNoticeTone.warning;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.s4,
          Space.s2,
          Space.s4,
          Space.s1,
        ),
        child: Semantics(
          container: true,
          liveRegion: live,
          child: Material(
            color: Colors.transparent,
            child: Container(
              key: const Key('th-notice-banner'),
              constraints: const BoxConstraints(minHeight: Sizes.tapMin),
              // No vertical padding here: the 48px dismiss target sets the
              // single-line height, and the text column pads itself so
              // multi-line notices still breathe.
              padding: const EdgeInsets.only(left: Space.s3_5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(Radii.tile),
                border: Border.all(color: border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: Space.s3),
                    child: Icon(
                      _icon(notice.tone),
                      size: Sizes.icon,
                      color: accent,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.s2_5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (notice.title != null)
                            Text(
                              notice.title!,
                              style: THType.title.copyWith(color: c.text),
                            ),
                          Text(
                            notice.message,
                            style: THType.body.copyWith(color: c.text),
                          ),
                          if (notice.action != null &&
                              notice.actionLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.s1_5),
                              child: InkWell(
                                onTap: () {
                                  notice.action!();
                                  widget.onDismiss();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Space.s1,
                                  ),
                                  child: Text(
                                    notice.actionLabel!,
                                    style: THType.button.copyWith(
                                      color: accent,
                                      decoration: TextDecoration.underline,
                                      decorationColor: accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Dismiss',
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onDismiss();
                      },
                      child: SizedBox(
                        width: Sizes.tapMin,
                        height: Sizes.tapMin,
                        child: Center(
                          child: Icon(
                            Icons.close_rounded,
                            size: Sizes.iconSm,
                            color: c.textSoft,
                          ),
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
}
