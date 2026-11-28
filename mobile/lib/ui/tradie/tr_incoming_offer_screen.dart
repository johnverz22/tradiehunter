// Full-screen incoming job request alert (QA plan §3).
//
// Pushed over whatever the tradie is doing when a live offer arrives (see
// IncomingOfferHost). One card per offer, earliest expiry first, with a pager
// when several are waiting. Accept / Decline answer through
// IncomingOfferCoordinator; View details opens the full request.
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../services/incoming_alert.dart';
import '../../utils/money.dart';
import '../../viewmodels/incoming_offer_coordinator.dart';
import '../../viewmodels/incoming_offer_queue.dart';
import '../../viewmodels/offer_responder.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';

/// `m:ss` countdown label, never negative.
String incomingCountdownLabel(Duration remaining) {
  final total = remaining.isNegative ? 0 : remaining.inSeconds;
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Last minute turns the countdown badge red.
const Duration incomingUrgentThreshold = Duration(minutes: 1);

class TrIncomingOfferScreen extends ConsumerStatefulWidget {
  const TrIncomingOfferScreen({super.key});

  static const String route = '/tradie/incoming';

  @override
  ConsumerState<TrIncomingOfferScreen> createState() =>
      _TrIncomingOfferScreenState();
}

class _TrIncomingOfferScreenState extends ConsumerState<TrIncomingOfferScreen> {
  final IncomingAlert _alert = IncomingAlert();
  Timer? _clock;
  int _index = 0;
  bool _booted = false;
  bool _closing = false;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(THDurations.countdownTick, (_) {
      if (mounted) setState(() {});
    });
    unawaited(_boot());
  }

  /// Makes sure the coordinator is running (this route can be the first thing
  /// opened from a notification tap) and has fetched, then rings if there is
  /// anything to answer.
  Future<void> _boot() async {
    await ref.read(incomingOfferCoordinatorProvider.notifier).start();
    if (!mounted) return;
    setState(() => _booted = true);
    if (ref.read(incomingOfferCoordinatorProvider).isEmpty) {
      _close();
    } else {
      _alert.start();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _alert.stop();
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _alert.stop();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tradie');
    }
  }

  Future<void> _respond(JobOffer offer, {required bool accept}) async {
    if (_responding) return;
    setState(() => _responding = true);
    _alert.stop();
    final result = await ref
        .read(incomingOfferCoordinatorProvider.notifier)
        .respond(offer, accept: accept);
    if (!mounted) return;
    setState(() => _responding = false);

    switch (result.outcome) {
      case OfferResponseOutcome.success:
        if (accept) {
          THNotice.success(context, NoticeCopy.offerAccepted);
          // Jump to the booked job unless other offers still need an answer.
          if (ref.read(incomingOfferCoordinatorProvider).isEmpty) {
            _closing = true;
            unawaited(context.pushReplacement('/tradie/jobs/${offer.jobId}'));
            return;
          }
        }
      case OfferResponseOutcome.rejected:
        THNotice.error(
          context,
          NoticeCopy.forOfferError(result.errorCode, accept: accept),
        );
      case OfferResponseOutcome.alreadyInFlight:
        break;
    }
    if (ref.read(incomingOfferCoordinatorProvider).isNotEmpty) _alert.start();
  }

  Future<void> _openDetails(JobOffer offer) async {
    _alert.stop();
    await context.push('/tradie/requests/${offer.jobId}');
    if (!mounted || _closing) return;
    if (ref.read(incomingOfferCoordinatorProvider).isNotEmpty) _alert.start();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    ref.listen<IncomingOfferQueue>(incomingOfferCoordinatorProvider, (
      previous,
      next,
    ) {
      if (!_booted) return;
      if (next.isEmpty) {
        _close();
      } else if (_index >= next.length) {
        setState(() => _index = next.length - 1);
      }
    });

    final queue = ref.watch(incomingOfferCoordinatorProvider);
    if (!_booted || queue.isEmpty) {
      return Scaffold(
        backgroundColor: c.paper,
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final index = _index.clamp(0, queue.length - 1);
    final offer = queue.offers[index];
    final remaining = queue.remaining(offer);
    final urgent = remaining <= incomingUrgentThreshold;
    final rate = offer.hourlyRateSnapshot;
    final message = offer.message?.trim();

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const THBadge('New request', kind: THBadgeKind.accent),
                  const Spacer(),
                  if (queue.length > 1) ...[
                    IconButton(
                      tooltip: 'Previous request',
                      onPressed: index > 0
                          ? () => setState(() => _index = index - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${index + 1} of ${queue.length}',
                      style: THType.label.copyWith(color: c.textSoft),
                    ),
                    IconButton(
                      tooltip: 'Next request',
                      onPressed: index < queue.length - 1
                          ? () => setState(() => _index = index + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Space.s4),
              Expanded(
                child: SingleChildScrollView(
                  child: THCard(
                    tone: urgent ? THCardTone.danger : THCardTone.defaultTone,
                    padding: Space.s5,
                    children: [
                      Text(
                        offer.jobTitle?.isNotEmpty == true
                            ? offer.jobTitle!
                            : 'New job request',
                        style: THType.h1.copyWith(color: c.text),
                      ),
                      const SizedBox(height: Space.s3),
                      Wrap(
                        spacing: Space.s2,
                        runSpacing: Space.s2,
                        children: [
                          THBadge(
                            offer.isQuoteRequest
                                ? 'Quote request'
                                : 'Hourly job',
                            kind: THBadgeKind.brand,
                          ),
                          THBadge(
                            'Respond in ${incomingCountdownLabel(remaining)}',
                            kind: urgent
                                ? THBadgeKind.danger
                                : THBadgeKind.glass,
                            icon: Icons.timer_outlined,
                          ),
                        ],
                      ),
                      // Rate is shown only when the server supplied a real one.
                      if (rate != null && rate > Decimal.zero) ...[
                        const SizedBox(height: Space.s4),
                        Text(
                          formatRate(rate),
                          style: THType.moneyLg.copyWith(color: c.text),
                        ),
                      ],
                      if (message != null && message.isNotEmpty) ...[
                        const SizedBox(height: Space.s4),
                        Text(
                          '“$message”',
                          style: THType.body.copyWith(color: c.textSoft),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              THButton(
                key: const Key('incoming_accept'),
                label: 'Accept',
                kind: THButtonKind.accent,
                icon: Icons.check,
                loading: _responding,
                onPressed: _responding
                    ? null
                    : () => _respond(offer, accept: true),
              ),
              const SizedBox(height: Space.s2),
              THButton(
                key: const Key('incoming_decline'),
                label: 'Decline',
                kind: THButtonKind.secondary,
                onPressed: _responding
                    ? null
                    : () => _respond(offer, accept: false),
              ),
              const SizedBox(height: Space.s1),
              THButton(
                key: const Key('incoming_details'),
                label: 'View details',
                kind: THButtonKind.ghost,
                onPressed: _responding ? null : () => _openDetails(offer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
