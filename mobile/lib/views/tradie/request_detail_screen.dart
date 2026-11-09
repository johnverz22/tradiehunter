import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/offer_responder.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/offer_countdown.dart';

/// Mockup 10-request-detail (tradie): price + live offer countdown above the
/// details, address fallback (exact address is masked until Booked, P5-01),
/// info grid, description, photo strip, Decline / Accept bar.
///
/// Sequential offers (P3-07 / P3-08): when the backend has a pending offer
/// for this tradie the screen counts down to `expiresAtUtc` (UTC on the
/// wire, localized here) and responds through the shared [OfferResponder]
/// command path — one POST /api/jobs/:id/offers/:offerId/respond per tap,
/// shared with the dashboard lead cards (V15-14). At zero the actions
/// disable and the server hands the job to the next ranked tradie.
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not respond to this offer — it may have expired.',
              ),
            ),
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
        appBar: FixoGradientAppBar(
          title: 'Job Request',
          showBack: !widget.embedded,
        ),
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
      appBar: FixoGradientAppBar(
        title: 'Job Request',
        showBack: !widget.embedded,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s6, Space.s2, Space.s6, Space.s6),
        children: [
          // 1. Title row with category chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
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
          // 2. Price block: large total + hours/rate breakdown beneath
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
            _OfferGone(),
          const SizedBox(height: Space.s4),
          // 4. Address card
          FixoCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: DesignTokens.brand500,
                  size: 20,
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
          // 7. Photos
          if (job.photoUrls.isEmpty)
            Text(
              'No photos attached.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: job.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.s2),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusControl,
                  ),
                  child: Image.network(
                    _resolvePhotoUrl(job.photoUrls[i]),
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 120,
                      alignment: Alignment.center,
                      color: isDark
                          ? DesignTokens.brand100Dark
                          : DesignTokens.brand100Light,
                      child: Text(
                        'Photo ${i + 1}',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeCaption,
                          color: DesignTokens.brand500,
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
}

/// Prominent price block (V16-08): large total at 24/700 in dark foreground
/// ink, with hours × rate breakdown on the line below when available.
/// Missing values show '—' rather than a fabricated figure.
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
        ? '${job.hours}h at \$${rate.toStringAsFixed(2)}/h'
        : (job.hours > 0 ? '${job.hours}h' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total != null ? '\$${total.toStringAsFixed(2)}' : '—',
          style: TextStyle(
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
    var dateStr = DateFormat('EEEE d MMMM · h:mm a').format(scheduledUtc.toLocal());
    if (job.hours > 0) dateStr += ' · ${job.hours}h';
    return FixoCard(
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: DesignTokens.brand500,
            size: 20,
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
            size: 22,
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
            size: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: Space.s7, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_disabled_outlined,
            size: 72,
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
            child: FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
