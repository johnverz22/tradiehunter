// ThStateView: interim v2 loading / empty / error views (migration plan 2.9).
//
// Composed only from v2 widgets and tokens. Copy for the preset empty/error
// variants is carried over from `views/states/designed_empty_state.dart` and
// `widgets/fixo_states.dart`. The dedicated error/empty/skeleton design pass is
// D-4 and separate; this is the stand-in until it lands.
//
// Navigation is the caller's job: pass [onAction]/[onSecondary] (the v1 widget
// called `context.go` itself; the v2 view stays routing-agnostic so it is
// trivially testable).
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

/// Preset empty / error situations, mirroring v1 `DesignedStateVariant`.
enum ThStatePreset { noMessages, emptyLeads, jobNotFound, jobUnavailable, requestExpired }

class ThStateView extends StatelessWidget {
  const ThStateView._({
    super.key,
    required this.kind,
    this.icon,
    this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.rows = 3,
  });

  /// Skeleton placeholder while data loads. [label] is read by screen readers.
  const ThStateView.loading({Key? key, String? label, int rows = 3})
      : this._(key: key, kind: _Kind.loading, title: label, rows: rows);

  /// Generic empty state.
  const ThStateView.empty({
    Key? key,
    required IconData icon,
    required String title,
    String? body,
    String? actionLabel,
    VoidCallback? onAction,
  }) : this._(
          key: key,
          kind: _Kind.empty,
          icon: icon,
          title: title,
          body: body,
          actionLabel: actionLabel,
          onAction: onAction,
        );

  /// Generic error state with an optional retry.
  const ThStateView.error({Key? key, required String message, VoidCallback? onRetry})
      : this._(
          key: key,
          kind: _Kind.error,
          icon: Icons.error_outline_rounded,
          title: message,
          actionLabel: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        );

  /// One of the designed states from the v1 mockups. [area] personalises
  /// [ThStatePreset.emptyLeads]. [actionLabel] overrides the default CTA label.
  factory ThStateView.preset(
    ThStatePreset preset, {
    Key? key,
    String? area,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onSecondary,
  }) {
    final (icon, title, body, cta, secondary) = switch (preset) {
      ThStatePreset.noMessages => (
          Icons.chat_bubble_outline_rounded,
          'No messages yet',
          "When you're matched with a tradie, your chat will show up here.",
          null,
          null,
        ),
      ThStatePreset.emptyLeads => (
          Icons.travel_explore_rounded,
          'No new leads right now',
          "We'll ping you when a job near ${area ?? 'you'} matches your services.",
          null,
          null,
        ),
      ThStatePreset.jobNotFound => (
          Icons.search_off_rounded,
          "We couldn't find this job",
          'It may have been removed or the link is old.',
          'Back to my jobs',
          'Contact support',
        ),
      ThStatePreset.jobUnavailable => (
          Icons.block_rounded,
          'This job is no longer available',
          'The homeowner cancelled it or it was filled by someone else.',
          'Back to my jobs',
          null,
        ),
      ThStatePreset.requestExpired => (
          Icons.hourglass_disabled_rounded,
          'This request expired',
          'Another tradie may have accepted this job. New leads arrive all the time.',
          'Back to leads',
          null,
        ),
    };
    return ThStateView._(
      key: key,
      kind: _Kind.empty,
      icon: icon,
      title: title,
      body: body,
      actionLabel: cta == null ? null : (actionLabel ?? cta),
      onAction: onAction,
      secondaryLabel: secondary,
      onSecondary: onSecondary,
    );
  }

  final _Kind kind;
  final IconData? icon;
  final String? title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final int rows;

  @override
  Widget build(BuildContext context) {
    if (kind == _Kind.loading) return _Loading(label: title, rows: rows);
    final c = context.th;
    final isError = kind == _Kind.error;
    final tone = isError ? c.danger : c.textBrand;
    final tile = isError ? c.dangerTint : c.tintBrand;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        primary: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Sizes.gutter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Semantics(
                  container: true,
                  liveRegion: isError,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: Sizes.avatarLg + Space.s4,
                        height: Sizes.avatarLg + Space.s4,
                        decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(Radii.hero)),
                        child: Icon(icon, size: Sizes.iconLg + Space.s4, color: tone),
                      ),
                      const SizedBox(height: Space.s5),
                      THText(title ?? '', style: THTextStyle.h2, align: TextAlign.center),
                      if (body != null) ...[
                        const SizedBox(height: Space.s2),
                        THText(body!, tone: THTone.soft, align: TextAlign.center),
                      ],
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: Space.s6),
                        THButton(
                          label: actionLabel!,
                          kind: isError ? THButtonKind.secondary : THButtonKind.primary,
                          onPressed: onAction,
                        ),
                      ],
                      if (secondaryLabel != null && onSecondary != null) ...[
                        const SizedBox(height: Space.s3),
                        THButton(label: secondaryLabel!, kind: THButtonKind.ghost, onPressed: onSecondary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Kind { loading, empty, error }

class _Loading extends StatefulWidget {
  const _Loading({this.label, required this.rows});

  final String? label;
  final int rows;

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: THDurations.slow * 4);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting: static placeholders, no pulse.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Semantics(
      label: widget.label ?? 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final opacity = 1.0 - 0.45 * Curves.easeInOut.transform(_pulse.value);
            return Opacity(
              opacity: opacity,
              child: ListView(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(Sizes.gutter),
                children: [
                  for (var i = 0; i < widget.rows; i++) ...[
                    _SkeletonCard(color: c.track, surface: c.surface, line: c.line),
                    const SizedBox(height: Space.s3),
                  ],
                  if (widget.label != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s2),
                      child: THText(widget.label!, style: THTextStyle.meta, tone: THTone.soft, align: TextAlign.center),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.color, required this.surface, required this.line});

  final Color color;
  final Color surface;
  final Color line;

  Widget _bar(double height, {double? width}) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.small)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Container(width: Sizes.avatar, height: Sizes.avatar, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(Space.s3_5),
                const SizedBox(height: Space.s2),
                _bar(Space.s3, width: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
