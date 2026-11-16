import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/offer_responder.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../widgets/fixo_filter_pill.dart';
import '../widgets/offer_countdown.dart';
import '../widgets/sticky_action_bar.dart';
import '../../feedback/fixo_notice.dart';

/// Tradie request detail screen (T21): price + live offer countdown above
/// the details, address fallback (exact address is masked until Booked, P5-01),
/// info cards, description, photo gallery with full-screen inspector, and
/// Decline / Accept sticky action bar.
///
/// Sequential offers (P3-07 / P3-08): when the backend has a pending offer
/// for this tradie the screen counts down to `expiresAtUtc` (UTC on the
/// wire, localized here) and responds through the shared [OfferResponder]
/// command path — one POST /api/jobs/:id/offers/:offerId/respond per tap,
/// shared with the dashboard lead cards (V15-14). At zero the actions
/// disable and the server hands the job to the next ranked tradie.
///
/// Quote requests (v1.7 contract #12): a pending offer with kind
/// `QuoteRequest` replaces the one-tap accept with a "Submit quote" action
/// that opens the structured quote form — pricing model, amounts,
/// inclusions/exclusions, materials + GST flags, proposed start and duration
/// — submitted via POST /api/jobs/:id/quotes.
class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  final bool embedded;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    this.embedded = false,
  });

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _loading = true;
  Job? _job;
  JobOffer? _offer;

  /// The pending-offer fetch finished (so a null offer means lapsed or
  /// answered, not still loading).
  bool _offerChecked = false;

  /// The pending-offer fetch failed — distinct from "no offer".
  bool _offerError = false;

  StreamSubscription? _offerSub;
  StreamSubscription? _reconnectSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_load);
  }

  /// Reconcile after a resume — the offer may have timed out server-side
  /// while the app was backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadOffer();
  }

  Future<void> _load() async {
    final repo = ref.read(jobsRepositoryProvider);
    final job = await repo.getJobById(widget.requestId);
    if (!mounted) return;

    setState(() {
      _job = job;
      _loading = false;
    });

    await _reloadOffer();
    _listenToHub();
  }

  /// The offer is what carries the expiry deadline; it may legitimately be
  /// null (never offered, already answered, or timed out). A fetch failure is
  /// tracked separately so it isn't presented as "no offer".
  Future<void> _reloadOffer() async {
    final repo = ref.read(jobsRepositoryProvider);
    try {
      final offer = await repo.getPendingOffer(widget.requestId);
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _offerChecked = true;
        _offerError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offerChecked = true;
        _offerError = true;
      });
    }
  }

  /// The server is the authority on whether the offer is still live — it
  /// broadcasts OfferExpired/OfferAccepted so the countdown stops even if
  /// this device's clock disagrees (P3-10). Job-status changes (e.g. the
  /// homeowner cancelled) reload both job and offer; a reconnect re-reads
  /// state because server-side group membership is re-established.
  void _listenToHub() {
    final hub = ref.read(jobHubClientProvider);
    _offerSub = hub.onOfferLifecycle.listen((event) {
      if (event.jobId != widget.requestId) return;
      if (event.eventType == OfferEventType.expired ||
          event.eventType == OfferEventType.accepted) {
        if (!mounted) return;
        setState(() {
          _offer = null;
          _busy = false;
        });
        if (event.eventType == OfferEventType.accepted) context.pop();
      }
    });
    _statusSub = hub.onJobStatusChanged.listen((event) {
      if (event.jobId != widget.requestId || !mounted) return;
      _reloadJobAndOffer();
    });
    _reconnectSub = hub.onReconnected.listen((_) => _reloadJobAndOffer());
  }

  Future<void> _reloadJobAndOffer() async {
    final repo = ref.read(jobsRepositoryProvider);
    final job = await repo.getJobById(widget.requestId);
    if (!mounted) return;
    setState(() => _job = job);
    await _reloadOffer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offerSub?.cancel();
    _reconnectSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  /// Resolves backend-relative photo paths (/api/photos/...) to absolute URLs.
  String _resolvePhotoUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${resolveBaseUrl()}$url';
  }

  /// Opens full-screen photo gallery viewer using Flutter's built-in InteractiveViewer.
  void _openPhotoViewer(BuildContext context, int initialIndex) {
    final job = _job;
    if (job == null || job.photoUrls.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoGalleryViewer(
          photoUrls: job.photoUrls,
          initialIndex: initialIndex,
          resolveUrl: _resolvePhotoUrl,
        ),
      ),
    );
  }

  /// Accept or decline through the shared [OfferResponder] command path —
  /// exactly one authorized request per job, and a stale or rejected response
  /// reconciles the offer against the server rather than guessing (V15-14).
  /// There is no "accept without an offer" path: the sequential engine only
  /// honors responses to a live pending offer.
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
        // Server accepted — the resulting booking state arrives via SignalR.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/tradie');
        }
      case OfferResponseOutcome.rejected:
        setState(() => _busy = false);
        await _reloadOffer();
        if (mounted) {
          FixoNotice.error(
            context,
            'Could not respond to this offer — it may have expired.',
          );
        }
      case OfferResponseOutcome.alreadyInFlight:
        setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final job = _job;
    if (job == null) {
      return Scaffold(
        appBar: FixoAppBar(title: 'Job Request', showBack: !widget.embedded),
        body: _RequestNotFoundBody(
          heading: 'This request expired',
          subtext: 'Another tradie may have accepted this job, or the offer window closed.',
          onAction: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/tradie');
            }
          },
          actionLabel: 'View open leads',
        ),
      );
    }
    // Exact address is masked for tradies until Booked (P5-01) — the suburb
    // is the truthful location available at offer time.
    final locationLabel = job.suburb.isNotEmpty
        ? job.suburb
        : (job.address ?? 'Location on file');

    final offer = _offer;
    final expired = offer != null && offer.remaining().isNegative;
    final canRespond = !_busy && offer != null && !expired;

    return Scaffold(
      appBar: FixoAppBar(title: 'Job Request', showBack: !widget.embedded),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.s6,
          Space.s2,
          Space.s6,
          Space.s6,
        ),
        children: [
          // 1. Title row with category chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FW.bold,
                  ),
                ),
              ),
              const SizedBox(width: Space.s2),
              Flexible(
                child: StatusBadge(
                  label: job.category,
                  kind: FixoBadgeKind.waiting,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s3),

          // 2. Prominent price block: large total + hours/rate breakdown
          _PriceBlock(job: job, isDark: isDark),
          const SizedBox(height: Space.s3),

          // 3. Countdown / offer state
          if (_offerError)
            _OfferCheckError(
              onRetry: () {
                setState(() => _offerError = false);
                _reloadOffer();
              },
            )
          else if (offer != null)
            OfferCountdown(offer: offer, onExpired: _onCountdownExpired)
          else if (_offerChecked)
            const _OfferGone(),
          const SizedBox(height: Space.s4),

          // 4. Address card
          FixoCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: DesignTokens.brand500,
                  size: Sizes.iconAction,
                ),
                const SizedBox(width: Space.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationLabel,
                        style: TextStyle(
                          color: DesignTokens.brand500,
                          fontWeight: FW.semibold,
                        ),
                      ),
                      const SizedBox(height: Space.s1),
                      Text(
                        'Exact address is shared after the job is booked.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Schedule card — only when scheduledStartUtc is set
          if (job.scheduledStartUtc != null) ...[
            const SizedBox(height: Space.s3),
            _ScheduleCard(job: job),
          ],
          const SizedBox(height: Space.s5),

          // 6. Description
          Text(
            job.description?.isNotEmpty == true
                ? job.description!
                : 'No description provided.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Space.s4),

          // 7. Photos gallery with tap-to-inspect
          if (job.photoUrls.isEmpty)
            Text(
              'No photos attached.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            SizedBox(
              height: Sizes.photoThumb,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: job.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.s2),
                itemBuilder: (ctx, i) => Semantics(
                  button: true,
                  label:
                      'Photo ${i + 1} of ${job.photoUrls.length}, tap to view full screen',
                  child: GestureDetector(
                    key: ValueKey('photo_thumb_$i'),
                    onTap: () => _openPhotoViewer(context, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: Image.network(
                        _resolvePhotoUrl(job.photoUrls[i]),
                        width: Sizes.photoThumbW,
                        height: Sizes.photoThumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: Sizes.photoThumbW,
                          height: Sizes.photoThumb,
                          alignment: Alignment.center,
                          color: isDark
                              ? DesignTokens.brand100Dark
                              : DesignTokens.brand100Light,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_outlined,
                                size: Sizes.iconAction,
                                color: DesignTokens.brand500,
                              ),
                              const SizedBox(height: Space.s1),
                              Text(
                                'Photo ${i + 1}',
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeCaption,
                                  color: DesignTokens.brand500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        child: offer == null || expired
            ? Text(
                offer == null
                    ? 'This offer is no longer available.'
                    : 'This offer has expired.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            // v1.7 contract #12: a QuoteRequest is answered with a structured
            // quote, never a one-tap accept.
            : offer.isQuoteRequest
            ? Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: FixoGhostButton(
                      label: 'Decline',
                      onPressed: canRespond
                          ? () => _respond(accept: false)
                          : null,
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  Expanded(
                    flex: 2,
                    child: FixoPrimaryButton(
                      key: const Key('submit_quote_button'),
                      label: 'Submit quote',
                      isLoading: _busy,
                      onPressed: canRespond ? _submitQuote : null,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: FixoGhostButton(
                      label: 'Decline',
                      onPressed: canRespond
                          ? () => _respond(accept: false)
                          : null,
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  Expanded(
                    flex: 2,
                    child: FixoPrimaryButton(
                      label: 'Accept Job',
                      isLoading: _busy,
                      onPressed: canRespond
                          ? () => _respond(accept: true)
                          : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// The shared countdown reached zero — the server's timeout job owns the
  /// authoritative timeout; here we just disable the actions.
  void _onCountdownExpired() {
    if (mounted) setState(() {});
  }

  // ── v1.7 contract #12: structured quote form ────────────────────────────

  /// The tradie's own GST registration from their profile — null when the
  /// profile data doesn't carry it, in which case the form leaves the flag
  /// unset with truthful helper copy (the backend validates on submit).
  bool? _profileGstRegistered() {
    final raw = ref.read(profileViewModelProvider).profile?['isGstRegistered'];
    return raw is bool ? raw : null;
  }

  /// Opens the quote form sheet and POSTs the returned payload through
  /// POST /api/jobs/:id/quotes. Success pops the screen — the request is
  /// answered with a quote, not an accept.
  Future<void> _submitQuote() async {
    final offer = _offer;
    if (offer == null || _busy) return;

    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (_) =>
          _QuoteFormSheet(gstRegisteredFromProfile: _profileGstRegistered()),
    );
    if (payload == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .createQuote(widget.requestId, payload);
      if (!mounted) return;
      FixoNotice.success(
        context,
        'Quote sent — the homeowner will compare it with the others.',
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/tradie');
      }
    } on ProfileApiException catch (e) {
      if (mounted) FixoNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (mounted) {
        FixoNotice.error(
          context,
          'Could not send your quote. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }
}

/// Prominent price block (V16-08 / T21): large total in display typography,
/// with estimated hours × rate breakdown beneath when available.
class _PriceBlock extends StatelessWidget {
  final Job job;
  final bool isDark;
  const _PriceBlock({required this.job, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = job.totalAmount;
    final rate = job.hourlyRate;
    final breakdown = rate != null && job.hours > 0
        ? '${job.hours} h × ${formatRate(rate)}'
        : (job.hours > 0 ? '${job.hours}h' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total != null ? formatMoney(total) : '—',
          style: TextStyle(
            fontFamily: TypeTokens.fontDisplay,
            fontSize: DesignTokens.fontSizeH1,
            fontWeight: FW.bold,
            color: DesignTokens.foreground(isDark),
          ),
        ),
        if (breakdown != null) ...[
          const SizedBox(height: Space.s1),
          Text(
            breakdown,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: DesignTokens.fontSizeH3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Schedule card shown below the address when scheduledStartUtc is set (V16-08).
class _ScheduleCard extends StatelessWidget {
  final Job job;
  const _ScheduleCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduledUtc = job.scheduledStartUtc!;
    var dateStr = DateFormat('EEEE d MMMM · h:mm a')
        .format(scheduledUtc.toLocal());
    if (job.hours > 0) dateStr += ' · ${job.hours}h';
    return FixoCard(
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: DesignTokens.brand500,
            size: Sizes.iconAction,
          ),
          const SizedBox(width: Space.s2),
          Expanded(
            child: Text(
              dateStr,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FW.semibold,
                color: DesignTokens.brand500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen photo gallery viewer using Flutter's built-in InteractiveViewer.
class _PhotoGalleryViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;
  final String Function(String) resolveUrl;

  const _PhotoGalleryViewer({
    required this.photoUrls,
    required this.initialIndex,
    required this.resolveUrl,
  });

  @override
  State<_PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<_PhotoGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: SizedBox(
          width: Sizes.tapMin,
          height: Sizes.tapMin,
          child: IconButton(
            icon: const Icon(Icons.close, size: Sizes.iconLg),
            tooltip: 'Close photo viewer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Photo ${_currentIndex + 1} of ${widget.photoUrls.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: FW.semibold,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final url = widget.resolveUrl(widget.photoUrls[index]);
          return Center(
            child: InteractiveViewer(
              minScale: Sizes.photoMinScale,
              maxScale: Sizes.photoMaxScale,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  padding: const EdgeInsets.all(Space.s6),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: Sizes.iconHero,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: Space.s3),
                      Text(
                        'Failed to load photo ${index + 1}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The pending-offer fetch failed — distinct from "no offer" so the screen
/// can offer a retry instead of a dead end.
class _OfferCheckError extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfferCheckError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return FixoCard(
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: DesignTokens.inkAccent(isDark),
            size: Sizes.iconMd,
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Text(
              'Could not check this offer.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FW.semibold,
              ),
            ),
          ),
          const SizedBox(width: Space.s2),
          FixoTonalButton(
            label: 'Try again',
            icon: Icons.refresh_outlined,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// The pending-offer fetch succeeded but returned none — the offer lapsed or
/// was already answered. Truthful state, not a live countdown at zero.
class _OfferGone extends StatelessWidget {
  const _OfferGone();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FixoCard(
      child: Row(
        children: [
          Icon(
            Icons.timer_off_outlined,
            color: theme.colorScheme.onSurfaceVariant,
            size: Sizes.iconMd,
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Text(
              'This offer is no longer available — it may have expired or '
              'already been answered.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FW.semibold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly recovery screen shown when an offer/request cannot be loaded (V16-02).
/// Replaces the blank "Job not found" text with clear context and a button to return
/// to open leads.
class _RequestNotFoundBody extends StatelessWidget {
  final String heading;
  final String subtext;
  final VoidCallback onAction;
  final String actionLabel;

  const _RequestNotFoundBody({
    required this.heading,
    required this.subtext,
    required this.onAction,
    this.actionLabel = 'View open leads',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s7,
        vertical: Space.s9,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_disabled_outlined,
            size: Sizes.iconEmpty,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Space.s6),
          Text(
            heading,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s3),
          Text(
            subtext,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s8),
          SizedBox(
            width: double.infinity,
            height: Sizes.button,
            child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}

// ── v1.7 contract #12: quote form sheet ──────────────────────────────────────

/// Pricing models a quote can use (contract #12 wire values).
const _quotePricingOptions = <(String, String)>[
  (Quote.pricingFixed, 'Fixed price'),
  (Quote.pricingEstimateRange, 'Estimate range'),
  (Quote.pricingHourlyWithCap, 'Hourly with cap'),
];

/// Structured quote form (v1.7 P12-23): pricing model with the matching
/// amount fields, inclusions/exclusions, materials + GST flags, proposed
/// start and estimated duration. Pops a ready-to-POST payload map, or null
/// when dismissed. The GST flag defaults from the tradie's profile when the
/// profile carries it; otherwise it is an explicit, un-ticked toggle with
/// truthful helper copy — the backend re-validates either way.
class _QuoteFormSheet extends StatefulWidget {
  /// The tradie's profile GST registration, when known.
  final bool? gstRegisteredFromProfile;

  const _QuoteFormSheet({required this.gstRegisteredFromProfile});

  @override
  State<_QuoteFormSheet> createState() => _QuoteFormSheetState();
}

class _QuoteFormSheetState extends State<_QuoteFormSheet> {
  final _amountController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _rateController = TextEditingController();
  final _capController = TextEditingController();
  final _inclusionsController = TextEditingController();
  final _exclusionsController = TextEditingController();
  final _durationController = TextEditingController();

  String _pricingModel = Quote.pricingFixed;
  bool _materialsIncluded = false;
  late bool _gstIncluded = widget.gstRegisteredFromProfile ?? false;
  DateTime? _proposedStart;

  @override
  void dispose() {
    _amountController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _rateController.dispose();
    _capController.dispose();
    _inclusionsController.dispose();
    _exclusionsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Decimal? _amount(String text) {
    final parsed = Decimal.tryParse(text.trim());
    return parsed != null && parsed > Decimal.zero ? parsed : null;
  }

  Decimal? get _fixedAmount => _amount(_amountController.text);
  Decimal? get _rangeMin => _amount(_minController.text);
  Decimal? get _rangeMax => _amount(_maxController.text);
  Decimal? get _hourlyRate => _amount(_rateController.text);
  Decimal? get _hourlyCap => _amount(_capController.text);

  int? get _durationDays {
    final parsed = int.tryParse(_durationController.text.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  bool get _canSubmit => switch (_pricingModel) {
    Quote.pricingFixed => _fixedAmount != null,
    Quote.pricingEstimateRange =>
      _rangeMin != null && _rangeMax != null && _rangeMin! <= _rangeMax!,
    Quote.pricingHourlyWithCap => _hourlyRate != null && _hourlyCap != null,
    _ => false,
  };

  void _submit(BuildContext context) {
    if (!_canSubmit) return;
    Navigator.pop(context, {
      'pricingModel': _pricingModel,
      if (_pricingModel == Quote.pricingFixed && _fixedAmount != null)
        'amount': _fixedAmount.toString(),
      if (_pricingModel == Quote.pricingEstimateRange && _rangeMin != null)
        'minAmount': _rangeMin.toString(),
      if (_pricingModel == Quote.pricingEstimateRange && _rangeMax != null)
        'maxAmount': _rangeMax.toString(),
      if (_pricingModel == Quote.pricingHourlyWithCap && _hourlyRate != null)
        'amount': _hourlyRate.toString(),
      if (_pricingModel == Quote.pricingHourlyWithCap && _hourlyCap != null)
        'cap': _hourlyCap.toString(),
      if (_inclusionsController.text.trim().isNotEmpty)
        'inclusions': _inclusionsController.text.trim(),
      if (_exclusionsController.text.trim().isNotEmpty)
        'exclusions': _exclusionsController.text.trim(),
      'materialsIncluded': _materialsIncluded,
      'gstIncluded': _gstIncluded,
      if (_proposedStart != null)
        'proposedStartUtc': _proposedStart!.toUtc().toIso8601String(),
      if (_durationDays != null) 'estimatedDurationDays': _durationDays,
    });
  }

  Future<void> _pickStart(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: _proposedStart ?? now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_proposedStart ?? now),
    );
    if (time == null) return;
    setState(() {
      _proposedStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gstKnown = widget.gstRegisteredFromProfile != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.s6,
          Space.gutter,
          MediaQuery.of(context).viewInsets.bottom + Space.s6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submit quote',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FW.bold,
                ),
              ),
              const SizedBox(height: Space.s1),
              Text(
                'The homeowner compares quotes side by side — price, scope '
                'and timing all show on your card.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.s4),

              // ── Pricing model ───────────────────────────────────────────
              Text(
                'How do you want to price this job?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FW.semibold,
                ),
              ),
              const SizedBox(height: Space.s2),
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: _quotePricingOptions
                    .map(
                      (option) => FixoFilterPill(
                        pillKey: ValueKey('quote_pricing_${option.$1}'),
                        label: option.$2,
                        selected: _pricingModel == option.$1,
                        onSelected: (_) =>
                            setState(() => _pricingModel = option.$1),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: Space.s3),

              // ── Amount fields for the selected model ────────────────────
              if (_pricingModel == Quote.pricingFixed)
                TextField(
                  key: const Key('quote_amount_field'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total price',
                    prefixText: r'$',
                    hintText: 'The all-up price for the whole job',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_pricingModel == Quote.pricingEstimateRange) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('quote_min_field'),
                        controller: _minController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimate min',
                          prefixText: r'$',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: TextField(
                        key: const Key('quote_max_field'),
                        controller: _maxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimate max',
                          prefixText: r'$',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (_rangeMin != null &&
                    _rangeMax != null &&
                    _rangeMin! > _rangeMax!) ...[
                  const SizedBox(height: Space.s1),
                  Text(
                    'The minimum must not exceed the maximum.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
              if (_pricingModel == Quote.pricingHourlyWithCap) ...[
                TextField(
                  key: const Key('quote_rate_field'),
                  controller: _rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hourly rate',
                    prefixText: r'$',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Space.s3),
                TextField(
                  key: const Key('quote_cap_field'),
                  controller: _capController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cap (maximum total)',
                    prefixText: r'$',
                    helperText: 'The homeowner pays your rate, never more than the cap.',
                    helperMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: Space.s3),

              // ── Scope ───────────────────────────────────────────────────
              TextField(
                key: const Key('quote_inclusions_field'),
                controller: _inclusionsController,
                maxLines: 3,
                maxLength: 1000,
                buildCounter: _hideQuoteCounterUntilThreshold(threshold: 0.8),
                decoration: const InputDecoration(
                  labelText: 'Inclusions (optional)',
                  hintText: 'What the price covers…',
                ),
              ),
              const SizedBox(height: Space.s3),
              TextField(
                key: const Key('quote_exclusions_field'),
                controller: _exclusionsController,
                maxLines: 3,
                maxLength: 1000,
                buildCounter: _hideQuoteCounterUntilThreshold(threshold: 0.8),
                decoration: const InputDecoration(
                  labelText: 'Exclusions (optional)',
                  hintText: 'What it does not cover…',
                ),
              ),
              const SizedBox(height: Space.s2),
              SwitchListTile(
                key: const Key('quote_materials_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Materials included in the price'),
                value: _materialsIncluded,
                onChanged: (value) =>
                    setState(() => _materialsIncluded = value),
              ),
              SwitchListTile(
                key: const Key('quote_gst_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Quote includes GST'),
                value: _gstIncluded,
                onChanged: (value) => setState(() => _gstIncluded = value),
              ),
              Text(
                gstKnown
                    ? (_gstIncluded
                          ? 'From your profile — you are GST-registered.'
                          : 'From your profile — you are not GST-registered.')
                    : 'Tick only if you are GST-registered — the app validates '
                          'this against your profile.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.s3),

              // ── Timing ──────────────────────────────────────────────────
              InkWell(
                key: const Key('quote_start_field'),
                onTap: () => _pickStart(context),
                borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: DesignTokens.heightInput,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s4,
                    vertical: Space.s2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusInput,
                    ),
                    border: Border.all(
                      color: DesignTokens.borderControl(
                        theme.brightness == Brightness.dark,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: Sizes.iconAction,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Space.s3),
                      Expanded(
                        child: Text(
                          _proposedStart == null
                              ? 'Proposed start (optional)'
                              : '${DateFormat('EEE d MMM y').format(_proposedStart!)} · '
                                    '${DateFormat('h:mm a').format(_proposedStart!)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _proposedStart == null
                                ? theme.hintColor
                                : null,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.s3),
              TextField(
                key: const Key('quote_duration_field'),
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated duration in days (optional)',
                  hintText: 'e.g. 3',
                ),
              ),
              const SizedBox(height: Space.s4),

              FixoPrimaryButton(
                key: const Key('quote_submit_button'),
                label: 'Send quote',
                onPressed: _canSubmit ? () => _submit(context) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Counter callback that hides the TextField counter until the current
/// length reaches [threshold] of the max length.
InputCounterWidgetBuilder _hideQuoteCounterUntilThreshold({
  double threshold = 0.8,
}) {
  return (
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (maxLength == null || currentLength < (maxLength * threshold).ceil()) {
      return null;
    }
    return Text(
      '$currentLength / $maxLength',
      style: Theme.of(context).textTheme.bodySmall,
    );
  };
}
