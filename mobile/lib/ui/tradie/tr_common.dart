// Shared v2 tradie widgets (tradie sub-plan 5.0 #3).
//
// `TrOfferCountdown` is the v2 rebuild of v1 `OfferCountdown`
// (views/widgets/offer_countdown.dart): same clamping, same `mm:ss` /
// `h:mm:ss` formatting, same one-shot `onExpired`, but styled from TH tokens
// and ticking on [THDurations.countdownTick].
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';

/// Remaining time on [offer], clamped at zero (never negative).
Duration trOfferRemaining(JobOffer offer, [DateTime Function()? clock]) {
  final r = offer.remaining(clock?.call());
  return r.isNegative ? Duration.zero : r;
}

/// `mm:ss` under an hour, `h:mm:ss` at or above it.
String trFormatCountdown(Duration remaining) {
  final d = remaining.isNegative ? Duration.zero : remaining;
  final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$mm:$ss';
  }
  return '${d.inMinutes}:$ss';
}

/// Compact label — coarse above an hour so long offers stay readable.
String trCompactCountdownLabel(Duration remaining) {
  if (remaining <= Duration.zero) return 'Offer expired';
  if (remaining.inHours >= 1) {
    return 'Expires in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
  }
  return 'Expires in ${trFormatCountdown(remaining)}';
}

/// Urgency band of the countdown colour.
enum TrCountdownTone { calm, soon, urgent }

/// Danger at or under 30 s (or expired), accent at or under 2 min.
TrCountdownTone trCountdownTone(Duration remaining) {
  if (remaining <= const Duration(seconds: 30)) return TrCountdownTone.urgent;
  if (remaining <= const Duration(minutes: 2)) return TrCountdownTone.soon;
  return TrCountdownTone.calm;
}

/// Offer expiry countdown. Owns its ticker so parents never rebuild per tick;
/// [onExpired] fires exactly once when the remaining time first reaches zero.
/// [clock] and [tick] are injectable for fake-clock tests.
class TrOfferCountdown extends StatefulWidget {
  const TrOfferCountdown({
    super.key,
    required this.offer,
    this.compact = false,
    this.clock,
    this.tick = THDurations.countdownTick,
    this.onExpired,
  });

  final JobOffer offer;

  /// Lead-card variant: one inline label with a timer icon.
  final bool compact;

  /// Injectable "now"; defaults to the wall clock.
  final DateTime Function()? clock;

  /// Tick interval; tests may shorten it.
  final Duration tick;

  /// Fired once, the first time the remaining time reaches zero.
  final VoidCallback? onExpired;

  @override
  State<TrOfferCountdown> createState() => _TrOfferCountdownState();
}

class _TrOfferCountdownState extends State<TrOfferCountdown> {
  Timer? _timer;
  late Duration _remaining;
  bool _expiredNotified = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(TrOfferCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.expiresAtUtc != widget.offer.expiresAtUtc) {
      _timer?.cancel();
      _expiredNotified = false;
      _restart();
    }
  }

  void _restart() {
    _remaining = trOfferRemaining(widget.offer, widget.clock);
    if (_remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyExpired());
    } else {
      _timer = Timer.periodic(widget.tick, (_) => _onTick());
    }
  }

  void _onTick() {
    if (!mounted) return;
    final next = trOfferRemaining(widget.offer, widget.clock);
    setState(() => _remaining = next);
    if (next <= Duration.zero) {
      _timer?.cancel();
      _notifyExpired();
    }
  }

  void _notifyExpired() {
    if (!mounted || _expiredNotified) return;
    _expiredNotified = true;
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _toneColor(BuildContext context, {required bool prominent}) {
    final c = context.th;
    return switch (trCountdownTone(_remaining)) {
      TrCountdownTone.urgent => c.danger,
      TrCountdownTone.soon => c.accentText,
      TrCountdownTone.calm => prominent ? c.textBrand : c.accentText,
    };
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining <= Duration.zero;
    final color = _toneColor(context, prominent: !widget.compact);
    final label = widget.compact
        ? trCompactCountdownLabel(_remaining)
        : (expired
              ? 'Offer expired'
              : 'Respond within ${trFormatCountdown(_remaining)}');
    return Semantics(
      container: true,
      label: expired
          ? 'This offer has expired'
          : 'Time left to respond to this offer: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.s1,
        children: [
          Icon(
            expired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: Sizes.iconSm,
            color: color,
          ),
          Flexible(
            child: Text(
              label,
              style: THType.compact.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
