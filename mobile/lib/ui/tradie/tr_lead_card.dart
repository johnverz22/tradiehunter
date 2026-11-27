// TrLeadCard: v2 lead card with countdown, quick actions, and request link.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'tr_lead_mapper.dart';

class TrLeadCard extends StatefulWidget {
  const TrLeadCard({
    super.key,
    required this.job,
    required this.offer,
    required this.offerChecked,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
    this.onExpired,
  });

  final Job job;
  final JobOffer? offer;
  final bool offerChecked;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  /// Fired once when a live offer's countdown reaches zero (caller refetches).
  final VoidCallback? onExpired;

  @override
  State<TrLeadCard> createState() => _TrLeadCardState();
}

class _TrLeadCardState extends State<TrLeadCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  bool get _offerLive =>
      widget.offer != null &&
      !_remaining.isNegative &&
      _remaining > Duration.zero &&
      !widget.busy;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    if (_remaining > Duration.zero) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(TrLeadCard old) {
    super.didUpdateWidget(old);
    if (old.offer?.expiresAtUtc != widget.offer?.expiresAtUtc) {
      _timer?.cancel();
      _remaining = _compute();
      if (_remaining > Duration.zero) {
        _startTimer();
      }
    }
  }

  Duration _compute() {
    final offer = widget.offer;
    if (offer == null) return Duration.zero;
    final now = DateTime.now().toUtc();
    final rem = offer.expiresAtUtc.difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _compute();
      setState(() => _remaining = next);
      if (next <= Duration.zero) {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatClock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} left';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (widget.job.category.isNotEmpty) subtitleParts.add(widget.job.category);
    if (widget.job.suburb.isNotEmpty) subtitleParts.add(widget.job.suburb);
    subtitleParts.add('Flexible');
    final subtitle = subtitleParts.join(' · ');

    final String countdownText;
    final THBadgeKind countdownKind;
    if (!widget.offerChecked) {
      countdownText = 'Checking…';
      countdownKind = THBadgeKind.brand;
    } else if (widget.offer == null || _remaining <= Duration.zero) {
      countdownText = 'Expired';
      countdownKind = THBadgeKind.danger;
    } else {
      countdownText = _formatClock(_remaining);
      countdownKind = THBadgeKind.accent;
    }

    // Before acceptance the job has no total — the offer's rate snapshot is
    // the tradie's real price (never the wire's non-nullable $0.00).
    final priceStr = trPriceTotal(widget.job, offer: widget.offer);

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.card),
      onTap: widget.onOpen,
      child: THCard(
        tone: THCardTone.accent,
        padding: Space.s4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: Space.s2,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 2.0,
                  children: [
                    THText(widget.job.title, style: THTextStyle.title),
                    THText(
                      subtitle,
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                    ),
                  ],
                ),
              ),
              THBadge(
                countdownText,
                kind: countdownKind,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: Space.s1_5),
          THKeyValue('Your rate', priceStr, bold: true),
          if (widget.job.photoUrls.isNotEmpty)
            THKeyValue(
              'Photos',
              '${widget.job.photoUrls.length} attached',
              bold: true,
              divider: true,
            ),
          const SizedBox(height: Space.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: Space.s2,
            children: [
              Expanded(
                child: THButton(
                  label: 'Decline',
                  kind: THButtonKind.secondary,
                  size: THButtonSize.sm,
                  onPressed: _offerLive ? widget.onDecline : null,
                ),
              ),
              Expanded(
                flex: 2,
                child: THButton(
                  label: 'Accept',
                  kind: THButtonKind.accent,
                  size: THButtonSize.sm,
                  loading: widget.busy,
                  onPressed: _offerLive ? widget.onAccept : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s1_5),
          Center(
            child: TextButton(
              onPressed: widget.onOpen,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s2,
                  vertical: Space.s1,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const THText(
                'View full request',
                style: THTextStyle.meta,
                tone: THTone.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
