import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_router.dart';
import '../../viewmodels/incoming_offer_coordinator.dart';
import '../../viewmodels/incoming_offer_queue.dart';
import '../tradie/tr_incoming_offer_screen.dart';

/// Root-level listener that raises the full-screen incoming-request alert
/// (QA plan §3) over whatever screen the tradie is on.
///
/// Opens [TrIncomingOfferScreen] the first time an offer id appears. Backing
/// out dismisses it without re-opening for the same offers, which stay
/// answerable from the tradie home lead cards; only a genuinely new offer
/// raises the alert again.
class IncomingOfferHost extends ConsumerStatefulWidget {
  const IncomingOfferHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingOfferHost> createState() => _IncomingOfferHostState();
}

class _IncomingOfferHostState extends ConsumerState<IncomingOfferHost> {
  final Set<String> _announced = {};
  bool _open = false;

  void _onQueue(IncomingOfferQueue? previous, IncomingOfferQueue next) {
    final fresh = next.offers.where((o) => _announced.add(o.id)).isNotEmpty;
    if (!fresh || _open) return;
    _open = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _open = false;
        return;
      }
      appRouter
          .push<void>(TrIncomingOfferScreen.route)
          .whenComplete(() => _open = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<IncomingOfferQueue>(incomingOfferCoordinatorProvider, _onQueue);
    return widget.child;
  }
}
