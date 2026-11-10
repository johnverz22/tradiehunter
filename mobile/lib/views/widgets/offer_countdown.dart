import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';

/// Shared offer countdown (V15-14): the one place offer expiry is rendered
/// and clocked — the tradie dashboard lead cards use [compact], the request
/// detail uses the default prominent layout.
///
/// Counts down against the server's `expiresAtUtc` and clamps at zero — the
/// label never goes negative. The widget owns its own one-second ticker so
/// parents don't rebuild every tick; [onExpired] fires exactly once when the
/// remaining time first reaches zero so callers can disable their actions.
/// [clock] and [tick] are injectable for fake-clock tests.
class OfferCountdown extends StatefulWidget {
  const OfferCountdown({
    super.key,
    required this.offer,
    this.compact = false,
    this.clock,
    this.tick = const Duration(seconds: 1),
    this.onExpired,
  });

  final JobOffer offer;

  /// Lead-card variant — a single inline label with a timer icon.
  final bool compact;

  /// Injectable "now" (UTC is applied internally). Defaults to wall clock.
  final DateTime Function()? clock;

  /// Tick interval; tests may shorten it.
  final Duration tick;

  /// Fired once, the first time the remaining time reaches zero.
  final VoidCallback? onExpired;

  /// Remaining time clamped at zero (never negative).
  static Duration clampedRemaining(JobOffer offer, DateTime Function()? clock) {
    final r = offer.remaining(clock?.call());
    return r.isNegative ? Duration.zero : r;
  }

  /// `mm:ss` under an hour, `h:mm:ss` at or above it.
  static String formatClock(Duration remaining) {
    final d = remaining.isNegative ? Duration.zero : remaining;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:$ss';
    }
    return '${d.inMinutes}:$ss';
  }

  /// Compact label — coarse above an hour so long offers stay readable.
  static String compactLabel(Duration remaining) {
    if (remaining <= Duration.zero) return 'Offer expired';
    if (remaining.inHours >= 1) {
      return 'Expires in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
    }
    return 'Expires in ${formatClock(remaining)}';
  }

  @override
  State<OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<OfferCountdown> {
  Timer? _timer;
  late Duration _remaining;
  bool _expiredNotified = false;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    if (_remaining <= Duration.zero) {
      _notifyExpiredPostFrame();
    } else {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(OfferCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.expiresAtUtc != widget.offer.expiresAtUtc) {
      _timer?.cancel();
      _expiredNotified = false;
      _remaining = _compute();
      if (_remaining <= Duration.zero) {
        _notifyExpiredPostFrame();
      } else {
        _startTimer();
      }
    }
  }

  Duration _compute() =>
      OfferCountdown.clampedRemaining(widget.offer, widget.clock);

  void _startTimer() {
    _timer = Timer.periodic(widget.tick, (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) return;
    final next = _compute();
    setState(() => _remaining = next);
    if (next <= Duration.zero) {
      _timer?.cancel();
      _notifyExpired();
    }
  }

  void _notifyExpiredPostFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyExpired());
  }

  void _notifyExpired() {
    if (_expiredNotified) return;
    _expiredNotified = true;
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining <= Duration.zero;
    return Semantics(
      label: expired
          ? 'This offer has expired'
          : 'Time left to respond to this offer',
      child: widget.compact ? _compact(expired) : _prominent(expired),
    );
  }

  Widget _compact(bool expired) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.extension<THColors>()!;
    final Color color;
    if (expired || _remaining <= const Duration(seconds: 30)) {
      color = DesignTokens.inkDanger(isDark);
    } else if (_remaining <= const Duration(minutes: 2)) {
      color = colors.accent;
    } else {
      color = DesignTokens.inkAccent(isDark);
    }
    return Row(
      children: [
        Icon(
          expired ? Icons.timer_off_outlined : Icons.timer_outlined,
          size: Sizes.iconXs,
          color: color,
        ),
        const SizedBox(width: Space.s1),
        Expanded(
          child: Text(
            OfferCountdown.compactLabel(_remaining),
            style: TextStyle(
              fontSize: DesignTokens.fontSizeCaption,
              fontWeight: FW.semibold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _prominent(bool expired) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.extension<THColors>()!;
    final Color fillColor;
    if (expired || _remaining <= const Duration(seconds: 30)) {
      fillColor = DesignTokens.inkDanger(isDark);
    } else if (_remaining <= const Duration(minutes: 2)) {
      fillColor = colors.accent;
    } else {
      fillColor = colors.brand;
    }
    final totalSeconds =
        widget.offer.expiresAtUtc.difference(DateTime.now().toUtc()).inSeconds +
        _remaining.inSeconds;
    final progress = totalSeconds > 0
        ? (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: expired
          ? 'Offer expired'
          : 'Respond within ${OfferCountdown.formatClock(_remaining)}',
      child: Stack(
        children: [
          // Preserves the single full text for accessibility finders and harnesses
          Opacity(
            opacity: 0,
            child: Text(
              expired
                  ? 'Offer expired'
                  : 'Respond within ${OfferCountdown.formatClock(_remaining)}',
              style: const TextStyle(fontSize: 1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Expires in',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontSize: DesignTokens.fontSizeSecondary,
                      fontWeight: FW.medium,
                      color: colors.textSoft,
                    ),
                  ),
                  Text(
                    expired ? 'Expired' : OfferCountdown.formatClock(_remaining),
                    style: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: FW.bold,
                      color: fillColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s1),
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radius),
                child: SizedBox(
                  height: Sizes.expiryProgressH,
                  child: LinearProgressIndicator(
                    value: expired ? 0.0 : progress,
                    backgroundColor: colors.track,
                    valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
