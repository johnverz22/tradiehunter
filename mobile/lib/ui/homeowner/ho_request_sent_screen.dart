import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

/// v2 presentation of the request-sent waiting screen (ho_request_sent).
///
/// This widget is stateless — the `ThMatchingScreen` controller owns all
/// of the SignalR / polling / action state and passes the minimum surface it
/// needs through callbacks and value parameters.  `ThScope` is provided internally
/// so this widget can be mounted directly.
class ThRequestSentScreen extends StatelessWidget {
  const ThRequestSentScreen({
    super.key,
    required this.requestChecked,
    required this.reconnecting,
    required this.request,
    required this.gstLabel,
    required this.onPickSomeoneElse,
    required this.onCancelRequest,
    required this.onExpired,
  });

  /// True once the first read of GET /api/jobs/:id/offers/pending has returned.
  final bool requestChecked;

  /// True while SignalR is reconnecting (shows a banner).
  final bool reconnecting;

  /// The pending offer; null means the request is gone or not yet loaded.
  final JobOffer? request;

  /// D8 GST label ("Incl. GST" / "No GST charged"); omitted when null.
  final String? gstLabel;

  /// Called when the homeowner taps "Pick someone else" (request gone/expired).
  final VoidCallback onPickSomeoneElse;

  /// Called when the homeowner taps "Cancel request" (offer still live).
  final VoidCallback onCancelRequest;

  /// Called when the countdown timer reaches zero.
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    return ThScope(
      child: Builder(
        builder: (context) {
          final req = request;
          final expired = req != null && req.remaining() <= Duration.zero;
          final name = req == null ? null : _displayName(req);

          return THScaffold(
            appBar: const THAppBar(title: 'Request sent'),
            stickyBar: THStickyBar(
              children: [
                THButton(
                  key: const Key('pick_someone_else_button'),
                  label: 'Pick someone else',
                  kind: THButtonKind.secondary,
                  onPressed: req == null || expired ? onPickSomeoneElse : null,
                ),
                THButton(
                  key: const Key('cancel_request_button'),
                  label: 'Withdraw request',
                  kind: THButtonKind.ghost,
                  onPressed: req == null || expired ? null : onCancelRequest,
                ),
              ],
            ),
            body: !requestChecked
                ? const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading request status',
                    ),
                  )
                : req == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Space.s8),
                      const THIcon(
                        Icons.timer_off_outlined,
                        size: Sizes.iconLg,
                      ),
                      const SizedBox(height: Space.s4),
                      const THText(
                        'This request is no longer open',
                        style: THTextStyle.h2,
                        align: TextAlign.center,
                      ),
                      const SizedBox(height: Space.s2),
                      const THText(
                        'It may have expired or been answered. Pick another tradie to keep going.',
                        style: THTextStyle.body,
                        tone: THTone.soft,
                        align: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (reconnecting)
                        const THCard(
                          padding: Space.s3,
                          children: [
                            THText(
                              'Connection lost — reconnecting…',
                              style: THTextStyle.meta,
                              tone: THTone.soft,
                            ),
                          ],
                        ),
                      const SizedBox(height: Space.s4),
                      THText(
                        'You asked $name',
                        style: THTextStyle.h1,
                        align: TextAlign.center,
                      ),
                      const SizedBox(height: Space.s2),
                      const THText(
                        'We\u2019ll let you know when they reply. If they decline or time runs out, the job stays open and nothing is charged.',
                        style: THTextStyle.body,
                        tone: THTone.soft,
                        align: TextAlign.center,
                      ),
                      const SizedBox(height: Space.s4),
                      THCard(
                        padding: Space.s4,
                        children: [
                          if (req.hourlyRateSnapshot != null)
                            THKeyValue(
                              'Rate locked',
                              '${formatRate(req.hourlyRateSnapshot!)}${gstLabel == null ? '' : ' · $gstLabel'}',
                              bold: true,
                            ),
                          _RequestOfferCountdown(
                            key: ValueKey(req.expiresAtUtc),
                            offer: req,
                            onExpired: onExpired,
                          ),
                          if (req.message?.trim().isNotEmpty ?? false)
                            THKeyValue(
                              'Your message',
                              req.message!.trim(),
                              divider: true,
                            ),
                        ],
                      ),
                      if (expired) ...[
                        const SizedBox(height: Space.s3),
                        const THText(
                          'The request has run out of time. Pick another tradie — the job stays open.',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                          align: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }

  static String _displayName(JobOffer offer) {
    final name = offer.tradieName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'the tradie';
  }
}

/// Countdown ring inside the request card — ticks once per [THDurations.countdownTick].
class _RequestOfferCountdown extends StatefulWidget {
  const _RequestOfferCountdown({
    super.key,
    required this.offer,
    required this.onExpired,
  });

  final JobOffer offer;
  final VoidCallback onExpired;

  @override
  State<_RequestOfferCountdown> createState() => _RequestOfferCountdownState();
}

class _RequestOfferCountdownState extends State<_RequestOfferCountdown> {
  // ignore: unused_field
  late final _timer = _startTimer();

  Duration get _remaining {
    final value = widget.offer.remaining();
    return value.isNegative ? Duration.zero : value;
  }

  dynamic _startTimer() {
    if (_remaining > Duration.zero) {
      return Future.delayed(THDurations.countdownTick, _tick);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpired();
    });
    return null;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_remaining <= Duration.zero) {
      widget.onExpired();
      return;
    }
    Future.delayed(THDurations.countdownTick, _tick);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.offer.expiresAtUtc
        .difference(widget.offer.offeredAtUtc)
        .inMilliseconds;
    final progress = total <= 0
        ? 0.0
        : (_remaining.inMilliseconds / total).clamp(0.0, 1.0);
    final minutes = _remaining.inMinutes;
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return THRing(
      value: '$minutes:$seconds',
      caption: 'left to respond',
      percent: progress,
    );
  }
}
