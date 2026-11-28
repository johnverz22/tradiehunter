import 'package:flutter/material.dart';

import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_tradie_loader.dart';
import '../design/th_widgets.dart';

/// The offer-progress dots stop growing after this many contacted tradies.
const int _kMaxOfferDots = 5;

/// v2 presentation of the quick-match waiting screen (N-03, `ho_radar`).
///
/// **Interim design.** There is no mockup frame for this screen yet (fix plan
/// N-03, `needs-design`); it is composed from `TH*` widgets and tokens, and
/// the frames are due in the Fix-4 design pass.
///
/// Stateless on purpose: `ThMatchingScreen` owns the SignalR
/// subscriptions, dispatch, stall watchdog and cancel, and hands this widget
/// the state to draw. `ThScope` is provided here so it can be mounted alone.
class ThRadarScreen extends StatelessWidget {
  const ThRadarScreen({
    super.key,
    required this.progress,
    required this.reconnecting,
    required this.stalled,
    required this.dispatchFailed,
    required this.busy,
    required this.onTryAgain,
    required this.onCancel,
    this.themeMode = ThemeMode.system,
  });

  /// Where the server-owned matching run has got to (P3-09).
  final MatchingProgressState progress;

  /// SignalR is reconnecting (truthful notice, no fake progress).
  final bool reconnecting;

  /// No offer event arrived within the stall window.
  final bool stalled;

  /// POST /api/jobs/:id/match was rejected and nothing is in flight.
  final bool dispatchFailed;

  /// A dispatch is in flight; "Try again" is disabled meanwhile.
  final bool busy;

  final VoidCallback onTryAgain;

  /// "Cancel", or "Go Back" once the run has ended without a match.
  final VoidCallback onCancel;

  /// The app's theme preference; the caller passes it so `lib/ui/**` never
  /// reads `views/**`.
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return ThScope(
      themeMode: themeMode,
      child: Builder(
        builder: (context) {
          final phase = progress.phase;
          final noTradie = phase == MatchingPhase.noTradieFound;
          final matched = phase == MatchingPhase.matched;
          // Retrying only makes sense while the run is still being started.
          final canRetry = (dispatchFailed || stalled) && !noTradie && !matched;

          final Widget content;
          if (noTradie) {
            content = _StatusPanel(
              icon: Icons.search_off_rounded,
              tone: _StatusTone.neutral,
              title: progress.headline,
              message: progress.subhead,
            );
          } else if (matched) {
            content = _StatusPanel(
              icon: Icons.check_rounded,
              tone: _StatusTone.success,
              title: progress.headline,
              message: progress.subhead,
            );
          } else if (dispatchFailed) {
            content = const _StatusPanel(
              icon: Icons.error_outline_rounded,
              tone: _StatusTone.problem,
              title: 'Could not start matching for this job.',
              message: 'Try again in a moment.',
            );
          } else {
            content = _Searching(
              progress: progress,
              reconnecting: reconnecting,
              stalled: stalled,
            );
          }

          return THScaffold(
            scrollable: false,
            stickyBar: THStickyBar(
              children: [
                if (canRetry)
                  THButton(
                    key: const Key('radar_try_again_button'),
                    label: 'Try again',
                    kind: THButtonKind.accent,
                    onPressed: busy ? null : onTryAgain,
                  ),
                THButton(
                  key: const Key('radar_cancel_button'),
                  label: noTradie ? 'Go Back' : 'Cancel',
                  kind: noTradie ? THButtonKind.secondary : THButtonKind.ghost,
                  onPressed: onCancel,
                ),
              ],
            ),
            // Centred, and scrollable so 200% text never overflows.
            body: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: content),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Radar + sequential offer progress while the run is starting or an offer is
/// out with a tradie.
class _Searching extends StatelessWidget {
  const _Searching({
    required this.progress,
    required this.reconnecting,
    required this.stalled,
  });

  final MatchingProgressState progress;
  final bool reconnecting;
  final bool stalled;

  @override
  Widget build(BuildContext context) {
    final contacting =
        progress.phase == MatchingPhase.contactingTradie &&
        progress.offerIndex > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ThTradieLoader(key: ValueKey('matching-radar'), isLoading: true),
        const SizedBox(height: Space.s7),
        // Sequential offer progress — "Contacting Tradie 2…" (P3-09).
        Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.radarTextBlock),
            child: AnimatedSwitcher(
              duration: THMotion.duration(context, THDurations.base),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey(progress.headline),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    THText(
                      progress.headline,
                      style: THTextStyle.h1,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: Space.s2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                      child: THText(
                        progress.subhead,
                        style: THTextStyle.body,
                        tone: THTone.soft,
                        align: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.s4),
        // The slot is always reserved so the headline does not jump when the
        // first offer goes out.
        SizedBox(
          height: Space.s2_5,
          child: contacting
              ? Semantics(
                  label: 'Contacting tradie ${progress.offerIndex}',
                  child: _OfferDots(count: progress.offerIndex),
                )
              : null,
        ),
        if (reconnecting) ...[
          const SizedBox(height: Space.s4),
          const THText(
            'Connection lost — reconnecting…',
            style: THTextStyle.meta,
            tone: THTone.soft,
            align: TextAlign.center,
          ),
        ],
        if (stalled) ...[
          const SizedBox(height: Space.s4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.s4),
            child: THText(
              'This is taking longer than usual.',
              style: THTextStyle.meta,
              tone: THTone.soft,
              align: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

/// Three expanding rings around a static core, one cycle per animation loop.

/// One dot per offer the server has dispatched in this run; the latest is
/// emphasised.
class _OfferDots extends StatelessWidget {
  const _OfferDots({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final shown = count.clamp(1, _kMaxOfferDots).toInt();
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s2,
      children: [
        for (var i = 0; i < shown; i++)
          Container(
            width: Space.s2_5,
            height: Space.s2_5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == shown - 1 ? c.brand : c.track,
            ),
          ),
      ],
    );
  }
}

enum _StatusTone { neutral, success, problem }

/// Terminal and error states: a core-sized icon tile, a title and one line.
/// Red is reserved for a real problem (the dispatch failure); "no tradies" is
/// neutral and "found" is green.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final _StatusTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final (tint, iconTone) = switch (tone) {
      _StatusTone.neutral => (c.tintBrand, THTone.brand),
      _StatusTone.success => (c.successTint, THTone.ok),
      _StatusTone.problem => (c.dangerTint, THTone.danger),
    };
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Sizes.radarCore,
            height: Sizes.radarCore,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
            child: THIcon(icon, size: Sizes.radarCoreIcon, tone: iconTone),
          ),
          const SizedBox(height: Space.s6),
          THText(title, style: THTextStyle.h1, align: TextAlign.center),
          const SizedBox(height: Space.s2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: THText(
              message,
              style: THTextStyle.body,
              tone: THTone.soft,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
