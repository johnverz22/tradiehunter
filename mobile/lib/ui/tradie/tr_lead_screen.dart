// TradieLeadScreen: v2 tradie request detail (migration plan 5.2, id
// `tr_lead`, route `/tradie/requests/:requestId`).
//
// Hand-owned port of views/tradie/request_detail_screen.dart. Same data flow:
// job + pending offer from jobsRepositoryProvider, SignalR (offer lifecycle,
// job status, reconnect) and an app-resume reload, accept/decline through the
// shared OfferResponder (one POST per tap), quote requests answered with the
// structured quote form via POST /api/jobs/:id/quotes.
//
// Gaps (plan G-16..G-18): no homeowner card, no Access / distance rows, the
// exact address stays hidden until Booked.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../viewmodels/auth_viewmodel.dart' show resolveBaseUrl;
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/offer_responder.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import '../feedback/th_state_view.dart';
import 'tr_lead_mapper.dart';
import 'tr_lead_parts.dart';
import 'tr_lead_states.dart';
import 'tr_photo_viewer.dart';
import 'tr_quote_sheet.dart';

class TradieLeadScreen extends ConsumerStatefulWidget {
  const TradieLeadScreen({
    super.key,
    required this.requestId,
    this.embedded = false,
  });

  final String requestId;
  final bool embedded;

  static const String route = '/tradie/requests/:requestId';

  @override
  ConsumerState<TradieLeadScreen> createState() => _TradieLeadScreenState();
}

class _TradieLeadScreenState extends ConsumerState<TradieLeadScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _loading = true;
  bool _loadFailed = false;
  Job? _job;
  JobOffer? _offer;

  /// The pending-offer fetch finished (so a null offer means lapsed or
  /// answered, not still loading).
  bool _offerChecked = false;

  /// The pending-offer fetch failed — distinct from "no offer".
  bool _offerError = false;

  StreamSubscription<OfferLifecycleEvent>? _offerSub;
  StreamSubscription<JobStatusEvent>? _statusSub;
  StreamSubscription<void>? _reconnectSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) unawaited(_load());
    });
  }

  /// The offer may have timed out server-side while backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reloadOffer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offerSub?.cancel();
    _statusSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final job = await ref
          .read(jobsRepositoryProvider)
          .getJobById(widget.requestId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _loading = false;
      });
    } catch (e) {
      debugPrint('tr_lead load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      return;
    }
    await _reloadOffer();
    if (mounted) _listenToHub();
  }

  Future<void> _reloadOffer() async {
    try {
      final offer = await ref
          .read(jobsRepositoryProvider)
          .getPendingOffer(widget.requestId);
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _offerChecked = true;
        _offerError = false;
      });
    } catch (e) {
      debugPrint('tr_lead offer check failed: $e');
      if (!mounted) return;
      setState(() {
        _offerChecked = true;
        _offerError = true;
      });
    }
  }

  Future<void> _reloadJobAndOffer() async {
    try {
      final job = await ref
          .read(jobsRepositoryProvider)
          .getJobById(widget.requestId);
      if (!mounted) return;
      setState(() => _job = job);
    } catch (e) {
      debugPrint('tr_lead job reload failed: $e');
    }
    await _reloadOffer();
  }

  /// The server is the authority on whether the offer is still live.
  void _listenToHub() {
    final hub = ref.read(jobHubClientProvider);
    _offerSub = hub.onOfferLifecycle.listen((event) {
      if (event.jobId != widget.requestId || !mounted) return;
      final type = event.eventType;
      if (type != OfferEventType.expired && type != OfferEventType.accepted) {
        return;
      }
      setState(() {
        _offer = null;
        _busy = false;
      });
      if (type == OfferEventType.accepted) _leave();
    });
    _statusSub = hub.onJobStatusChanged.listen((event) {
      if (event.jobId != widget.requestId || !mounted) return;
      unawaited(_reloadJobAndOffer());
    });
    _reconnectSub = hub.onReconnected.listen((_) {
      if (mounted) unawaited(_reloadJobAndOffer());
    });
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tradie');
    }
  }

  /// Accept or decline through the shared [OfferResponder]: one request per
  /// job, a rejected response reconciles against the server.
  Future<void> _respond({required bool accept}) async {
    final offer = _offer;
    if (offer == null || _busy) return;
    setState(() => _busy = true);
    final outcome = await ref
        .read(offerResponderProvider)
        .respond(jobId: widget.requestId, offer: offer, accept: accept);
    if (!mounted) return;
    switch (outcome) {
      case OfferResponseOutcome.success:
        _leave();
      case OfferResponseOutcome.rejected:
        setState(() => _busy = false);
        await _reloadOffer();
        if (!mounted) return;
        THNotice.error(
          context,
          'Could not respond to this offer — it may have expired.',
        );
      case OfferResponseOutcome.alreadyInFlight:
        setState(() => _busy = false);
    }
  }

  bool? _profileGstRegistered() {
    final raw = ref.read(profileViewModelProvider).profile?['isGstRegistered'];
    return raw is bool ? raw : null;
  }

  /// Opens the quote form and POSTs the payload; success leaves the screen.
  Future<void> _submitQuote() async {
    if (_offer == null || _busy) return;
    final payload = await showTrQuoteSheet(
      context,
      themeMode: ref.read(themeModeProvider),
      gstRegisteredFromProfile: _profileGstRegistered(),
    );
    if (payload == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .createQuote(widget.requestId, payload);
      if (!mounted) return;
      THNotice.success(
        context,
        'Quote sent — the homeowner will compare it with the others.',
      );
      _leave();
      return;
    } on ProfileApiException catch (e) {
      if (mounted) THNotice.errorDynamic(context, e.message);
    } catch (e) {
      debugPrint('tr_lead quote failed: $e');
      if (mounted) {
        THNotice.error(context, 'Could not send your quote. Please try again.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) =>
      ThScope(themeMode: ref.watch(themeModeProvider), child: _page());

  Widget _page() {
    if (_loading) {
      return THScaffold(
        appBar: THAppBar(title: 'New request', showBack: !widget.embedded),
        scrollable: false,
        body: const ThStateView.loading(label: 'Loading request...'),
      );
    }
    if (_loadFailed) {
      return THScaffold(
        appBar: THAppBar(title: 'New request', showBack: !widget.embedded),
        scrollable: false,
        body: ThStateView.error(
          message: 'Could not load this request. Please try again.',
          onRetry: () => unawaited(_load()),
        ),
      );
    }
    final job = _job;
    if (job == null) {
      return THScaffold(
        appBar: THAppBar(title: 'New request', showBack: !widget.embedded),
        scrollable: false,
        body: TrRequestNotFound(onAction: _leave),
      );
    }
    return _content(job);
  }

  Widget _content(Job job) {
    final baseUrl = resolveBaseUrl();
    return THScaffold(
      appBar: THAppBar(
        title: 'New request',
        subtitle: trLeadSubtitle(job, _offer, DateTime.now()),
        showBack: !widget.embedded,
      ),
      stickyBar: TrLeadActions(
        bar: trLeadBar(_offer),
        busy: _busy,
        onDecline: () => unawaited(_respond(accept: false)),
        onAccept: () => unawaited(_respond(accept: true)),
        onSubmitQuote: () => unawaited(_submitQuote()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          TrLeadOfferCard(
            offer: _offer,
            offerChecked: _offerChecked,
            offerError: _offerError,
            onRetry: () {
              setState(() => _offerError = false);
              unawaited(_reloadOffer());
            },
            onExpired: () {
              if (mounted) setState(() {});
            },
          ),
          TrLeadJobCard(job: job),
          TrLeadPriceCard(job: job, offer: _offer),
          if (job.photoUrls.isEmpty)
            const THText(
              'No photos attached.',
              style: THTextStyle.meta,
              tone: THTone.soft,
            )
          else ...[
            const THText('Photos from the homeowner', style: THTextStyle.title),
            TrPhotoStrip(
              photoUrls: job.photoUrls,
              baseUrl: baseUrl,
              onOpen: (i) => showTrPhotoViewer(
                context,
                photoUrls: job.photoUrls,
                initialIndex: i,
                baseUrl: baseUrl,
              ),
            ),
          ],
          const THText('Location', style: THTextStyle.title),
          TrLeadLocationCard(job: job),
          const THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s2_5,
                children: [
                  THIcon(
                    Icons.info_outline_rounded,
                    size: 18.0,
                    tone: THTone.brand,
                  ),
                  Expanded(
                    child: THText(
                      'Declining does not affect your rating. You can turn '
                      'off leads any time with the online switch.',
                      style: THTextStyle.meta,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
