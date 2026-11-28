// Full-screen incoming job request alert (QA plan §3).
//
// Pushed over whatever the tradie is doing when a live offer arrives (see
// IncomingOfferHost). Lists every waiting request as a card, earliest expiry
// first. Cards carry no actions: tapping one opens the full request, where
// the tradie accepts or declines.
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
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

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
  bool _booted = false;
  bool _closing = false;

  /// True while a request's detail page is on top. The queue can empty there
  /// (the tradie accepts or declines), and popping now would pop the detail
  /// page instead of this one, so closing waits until it returns.
  bool _detailsOpen = false;

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

  /// Opens the full request. The ring pauses while the tradie reads it and
  /// resumes on return if other requests are still waiting.
  Future<void> _openDetails(JobOffer offer) async {
    _alert.stop();
    _detailsOpen = true;
    await context.push('/tradie/requests/${offer.jobId}');
    _detailsOpen = false;
    if (!mounted || _closing) return;
    if (ref.read(incomingOfferCoordinatorProvider).isEmpty) {
      _close();
    } else {
      _alert.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    ref.listen<IncomingOfferQueue>(incomingOfferCoordinatorProvider, (
      previous,
      next,
    ) {
      if (_booted && next.isEmpty && !_detailsOpen) _close();
    });

    final queue = ref.watch(incomingOfferCoordinatorProvider);
    if (!_booted || queue.isEmpty) {
      return Scaffold(
        backgroundColor: c.paper,
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final count = queue.length;
    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.gutter,
                Space.s2,
                Space.s2,
                0,
              ),
              child: Row(
                children: [
                  const THBadge('New requests', kind: THBadgeKind.accent),
                  const Spacer(),
                  IconButton(
                    key: const Key('incoming_close'),
                    tooltip: 'Close',
                    onPressed: _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.gutter,
                Space.s2,
                Sizes.gutter,
                Space.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1 ? '1 request waiting' : '$count requests waiting',
                    style: THType.h1.copyWith(color: c.text),
                  ),
                  const SizedBox(height: Space.s1),
                  Text(
                    'Open a request to review it, then accept or decline.',
                    style: THType.body.copyWith(color: c.textSoft),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  Sizes.gutter,
                  0,
                  Sizes.gutter,
                  Space.s4,
                ),
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(height: Space.s3),
                itemBuilder: (context, i) {
                  final offer = queue.offers[i];
                  return _RequestCard(
                    key: ValueKey('incoming_${offer.id}'),
                    offer: offer,
                    remaining: queue.remaining(offer),
                    onTap: () => _openDetails(offer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: THStickyBar(
        children: [
          THButton(
            key: const Key('incoming_later'),
            label: 'Later',
            kind: THButtonKind.secondary,
            onPressed: _close,
          ),
          THButton(
            key: const Key('incoming_review'),
            label: count == 1 ? 'Review request' : 'Review first',
            kind: THButtonKind.accent,
            onPressed: () => _openDetails(queue.offers.first),
          ),
        ],
      ),
    );
  }
}

/// One waiting request. Display only: the whole card is the tap target.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.offer,
    required this.remaining,
    required this.onTap,
  });

  final JobOffer offer;
  final Duration remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final urgent = remaining <= incomingUrgentThreshold;
    final rate = offer.hourlyRateSnapshot;
    final message = offer.message?.trim();
    final title = offer.jobTitle?.isNotEmpty == true
        ? offer.jobTitle!
        : 'New job request';

    return Semantics(
      button: true,
      onTap: onTap,
      label: '$title, respond in ${incomingCountdownLabel(remaining)}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: THCard(
            tone: urgent ? THCardTone.danger : THCardTone.defaultTone,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: THType.title.copyWith(color: c.text),
                    ),
                  ),
                  const SizedBox(width: Space.s2),
                  Icon(Icons.chevron_right, color: c.textSoft),
                ],
              ),
              const SizedBox(height: Space.s2_5),
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [
                  THBadge(
                    offer.isQuoteRequest ? 'Quote request' : 'Hourly job',
                    kind: THBadgeKind.brand,
                  ),
                  THBadge(
                    'Respond in ${incomingCountdownLabel(remaining)}',
                    kind: urgent ? THBadgeKind.danger : THBadgeKind.glass,
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
              // Rate is shown only when the server supplied a real one.
              if (rate != null && rate > Decimal.zero) ...[
                const SizedBox(height: Space.s3),
                Text(
                  formatRate(rate),
                  style: THType.money.copyWith(color: c.text),
                ),
              ],
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: Space.s2),
                Text(
                  '“$message”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: THType.body.copyWith(color: c.textSoft),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
