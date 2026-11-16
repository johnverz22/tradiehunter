// THNotice: v2 (Trust Navy + Gold) skin for in-app notices (migration plan 2.8, D-3).
//
// Reuses the UI-independent logic of the v1 notice system: the same
// `fixoNoticeProvider` / `FixoNoticeController` / `FixoNoticeState` and the same
// copy in `NoticeCopy`. Only the presentation is new. The class rename of the
// old widgets (`FixoNotice*` -> `THNotice*`) happens at cutover (Phase 6.3).
//
// Coexistence: until cutover the app root still mounts the v1 `FixoNoticeHost`,
// which listens to the same provider. v2 screens can call `THNotice.*` today and
// the notice appears through that host. Phase 6 swaps the root host for
// [THNoticeHost]. Do not mount both at once or each notice is drawn twice.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feedback/fixo_notice_controller.dart'
    show FixoNoticeState, FixoNoticeTone, FixoNoticeToneX, fixoNoticeProvider;
import '../design/th_tokens.dart';

export '../../feedback/notice_copy.dart' show NoticeCopy;

/// Static façade, same call shape as the v1 `FixoNotice`.
///
/// `THNotice.success(context, NoticeCopy.profileUpdated);`
abstract class THNotice {
  THNotice._();

  static void info(BuildContext context, String message) =>
      _show(context, FixoNoticeTone.info, message);

  static void success(BuildContext context, String message) =>
      _show(context, FixoNoticeTone.success, message);

  static void warning(BuildContext context, String message) =>
      _show(context, FixoNoticeTone.warning, message);

  static void error(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) => _show(
    context,
    FixoNoticeTone.error,
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
    FixoNoticeTone.push,
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
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(fixoNoticeProvider.notifier).show(notice);
    } catch (_) {
      // No ProviderScope above this context: nothing can show the notice.
    }
  }
}

/// Overlay host drawing the active notice with [THNoticeBanner].
/// Place around `MaterialApp.router`'s builder child (Phase 6.1).
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

  FixoNoticeState? _current;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onChanged(FixoNoticeState? notice) {
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
    ref.listen<FixoNoticeState?>(fixoNoticeProvider, (_, next) {
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
                      ref.read(fixoNoticeProvider.notifier).dismiss(),
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

  final FixoNoticeState notice;
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

  static IconData _icon(FixoNoticeTone tone) => switch (tone) {
    FixoNoticeTone.info => Icons.info_outline_rounded,
    FixoNoticeTone.success => Icons.check_circle_outline_rounded,
    FixoNoticeTone.warning => Icons.warning_amber_rounded,
    FixoNoticeTone.error => Icons.error_outline_rounded,
    FixoNoticeTone.push => Icons.notifications_outlined,
  };

  /// (background, border, accent) per tone, all from v2 tokens.
  static (Color, Color, Color) _palette(FixoNoticeTone tone, THColors c) =>
      switch (tone) {
        FixoNoticeTone.info => (c.surface, c.line, c.textSoft),
        FixoNoticeTone.success => (c.successTint, c.success, c.success),
        FixoNoticeTone.warning => (c.accentTint, c.accent, c.accentText),
        FixoNoticeTone.error => (c.dangerTint, c.danger, c.danger),
        FixoNoticeTone.push => (c.tintBrand, c.brand, c.textBrand),
      };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = dark ? THColors.dark : THColors.light;
    final notice = widget.notice;
    final (bg, border, accent) = _palette(notice.tone, c);
    final live =
        notice.tone == FixoNoticeTone.error ||
        notice.tone == FixoNoticeTone.warning;

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
              padding: const EdgeInsets.only(
                left: Space.s3_5,
                top: Space.s2_5,
                bottom: Space.s2_5,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(Radii.tile),
                border: Border.all(color: border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Space.s1,
                      right: Space.s3,
                    ),
                    child: Icon(
                      _icon(notice.tone),
                      size: Sizes.icon,
                      color: accent,
                    ),
                  ),
                  Expanded(
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
                        if (notice.action != null && notice.actionLabel != null)
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
