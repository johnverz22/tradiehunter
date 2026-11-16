import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../network/external_launcher.dart';
import '../../repositories/job_hub_client.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/rating_sheet.dart';
import '../../widgets/tradie_widgets.dart';
import '../widgets/cancel_job_sheet.dart';
import '../widgets/fixo_filter_pill.dart';
import '../widgets/job_info_grid.dart';
import '../widgets/job_status_presentation.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/status_strip.dart';
import '../widgets/fixo_feedback.dart';
import '../../feedback/fixo_notice.dart';

/// Tradie-side job detail screen for Booked / InProgress / AwaitingConfirmation
/// / Completed / Cancelled jobs (P5-06).
///
/// – Booked      → "Check In" button (Booked → InProgress)
/// – InProgress   → "Check Out" button (InProgress → AwaitingConfirmation)
/// – AwaitingConfirmation → info text: waiting for homeowner confirmation
/// – Completed / Cancelled → read-only
///
/// A "Cancel Job" overflow action is available for Booked and InProgress
/// statuses (P6-03). Tradie is warned about account flags on cancellation.
///
/// Address privacy (P5-01): the backend masks the exact address for jobs
/// before Booked. This screen shows whatever the API returns in job.address,
/// so it automatically respects the server's masking.
class TradieJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  /// When [embedded] is true the screen is hosted in a master-detail right
  /// panel — it should not show a back arrow since the user selects from the
  /// list panel instead of navigating with the router.
  final bool embedded;

  const TradieJobDetailScreen({
    super.key,
    required this.jobId,
    this.embedded = false,
  });

  @override
  ConsumerState<TradieJobDetailScreen> createState() =>
      _TradieJobDetailScreenState();
}

class _TradieJobDetailScreenState extends ConsumerState<TradieJobDetailScreen> {
  bool _busy = false;
  bool _loading = true;
  bool _hasReview = false;
  Job? _job;
  JobContact? _contact;
  List<JobAdjustment> _adjustments = const [];
  StreamSubscription<JobStatusEvent>? _statusSub;
  StreamSubscription<JobAdjustmentEvent>? _adjustmentSub;

  // Statuses a tradie is allowed to cancel.
  static const _cancellableStatuses = {
    'Booked',
    'InProgress',
    'AwaitingConfirmation',
  };

  // Statuses where the server exposes the homeowner's contact (V15-15) —
  // mirrors the contactable set in JobsController.GetJobContact.
  static const _contactableStatuses = {
    'Booked',
    'InProgress',
    'AwaitingConfirmation',
    'Completed',
    'Disputed',
  };

  // Tradie-facing reason codes.
  static const _tradieReasons = [
    ('tradie_unavailable', 'I\'m no longer available'),
    ('emergency', 'Emergency situation'),
    ('scope_change_declined', 'Scope changed beyond agreed work'),
    ('tradie_issue', 'Personal / equipment issue'),
    ('homeowner_no_show', 'Homeowner is unresponsive / no show'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
    // Status transitions arrive via SignalR; reload so the primary action,
    // banner and contact card always reflect the server state.
    _statusSub = ref.read(jobHubClientProvider).onJobStatusChanged.listen((
      event,
    ) {
      if (event.jobId == widget.jobId && mounted) _load();
    });
    // v1.7 P12-18: homeowner decisions on extra costs arrive live.
    _adjustmentSub = ref.read(jobHubClientProvider).onAdjustmentChanged.listen((
      event,
    ) {
      if (event.jobId == widget.jobId && mounted) _loadAdjustments();
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _adjustmentSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAdjustments() async {
    final adjustments = await ref
        .read(jobsRepositoryProvider)
        .getAdjustments(widget.jobId);
    if (!mounted) return;
    setState(() => _adjustments = adjustments);
  }

  Future<void> _load() async {
    final repo = ref.read(jobsRepositoryProvider);
    final job = await repo.getJobById(widget.jobId);
    if (!mounted) return;

    // Contact is served only for participants on Booked+ jobs; a null
    // response or failure hides the card rather than fabricating a name
    // or number.
    JobContact? contact;
    if (job != null && _contactableStatuses.contains(job.status)) {
      try {
        contact = await repo.getJobContact(widget.jobId);
      } catch (_) {}
      if (!mounted) return;
    }
    // v1.7 P12-19: keep the extra-cost list in sync on every load.
    final adjustments = await repo.getAdjustments(widget.jobId);
    if (!mounted) return;
    setState(() {
      _job = job;
      _contact = contact;
      _adjustments = adjustments;
      _loading = false;
    });
  }

  // ── V15-15: external actions (maps / phone) ───────────────────────────────

  Future<void> _navigate([MapApp? app]) async {
    final job = _job;
    if (job == null) return;
    final launched = await ref
        .read(externalLauncherProvider)
        .openMap(
          address: job.address ?? job.suburb,
          latitude: job.latitude,
          longitude: job.longitude,
          app: app,
        );
    if (!launched && mounted) {
      FixoNotice.warning(context, "Couldn't open a maps app on this device.");
    }
  }

  Future<void> _call(String phoneNumber) async {
    final launched = await ref
        .read(externalLauncherProvider)
        .callPhone(phoneNumber);
    if (!launched && mounted) {
      FixoNotice.warning(
        context,
        "Couldn't open the phone app on this device.",
      );
    }
  }

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final ok = await repo.checkIn(widget.jobId);
    if (!mounted) return;
    if (ok) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.jobId, 'InProgress');
      await _load();
    } else {
      FixoNotice.error(context, NoticeCopy.checkInFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// v1.7 P12-11: check-out collects the hours actually worked (plus an
  /// optional note), shows the computed total before submitting, then
  /// renders the server's own [CheckOutSummary] verbatim.
  Future<void> _checkOut() async {
    final job = _job;
    if (job == null) return;
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (_) => _CheckOutSheet(
        job: job,
        approvedAdjustmentsTotal: _approvedAdjustmentsTotal,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    final summary = await ref
        .read(jobsRepositoryProvider)
        .checkOut(widget.jobId, finalHours: result);
    if (!mounted) return;
    if (summary != null) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.jobId, 'AwaitingConfirmation');
      await _load();
      if (mounted) _showCheckOutSummary(summary);
    } else {
      FixoNotice.error(context, NoticeCopy.checkOutFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Renders the server's returned check-out summary — never recomputed
  /// client-side (contract #7).
  void _showCheckOutSummary(CheckOutSummary summary) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-out submitted'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.finalHours != null)
                Text('Hours worked: ${_formatHours(summary.finalHours!)}'),
              if (summary.labourAmount != null)
                Text('Labour: ${formatMoney(summary.labourAmount!)}'),
              if (summary.adjustmentsTotal != null &&
                  summary.adjustmentsTotal! > Decimal.zero)
                Text(
                  'Approved extras: ${formatMoney(summary.adjustmentsTotal!)}',
                ),
              if (summary.finalAmount != null)
                Text('Final total: ${formatMoney(summary.finalAmount!)}'),
              if (summary.estimatedTotal != null && summary.finalAmount != null)
                Text(
                  'Original estimate: ${formatMoney(summary.estimatedTotal!)}',
                ),
              const SizedBox(height: Space.s2),
              Text(
                summary.exceedsTolerance
                    ? (summary.toleranceNote?.isNotEmpty == true
                          ? summary.toleranceNote!
                          : 'This total is above the estimate tolerance — the '
                                'homeowner will review it before paying.')
                    : 'The homeowner now reviews the summary and approves '
                          'the amount.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Sum of Approved adjustments — what actually lands on the homeowner's
  /// bill (contract #9). Used by the check-out sheet's pre-submit total.
  Decimal get _approvedAdjustmentsTotal {
    var total = Decimal.zero;
    for (final a in _adjustments) {
      if (a.isApproved) total += a.amount;
    }
    return total;
  }

  // ── v1.7 P12-19: "Request extra cost" ─────────────────────────────────────

  /// Bottom sheet: pick kind, amount, description and an optional receipt
  /// indicator. Evidence attach is optional — the current API surface has no
  /// generic blob-upload endpoint, so `evidenceFileKey` is only sent when a
  /// key is already available (see [JobsRepository.createAdjustment]).
  Future<void> _showRequestExtraCostSheet() async {
    final proposal = await showModalBottomSheet<(String, Decimal, String)?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (_) => _RequestExtraCostSheet(),
    );
    if (proposal == null || !mounted) return;
    final (kind, amount, description) = proposal;

    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .createAdjustment(
            widget.jobId,
            kind: kind,
            amount: amount,
            description: description,
          );
      await _loadAdjustments();
      if (mounted) {
        FixoNotice.success(
          context,
          'Extra cost sent — you\'ll hear back as soon as '
          'the homeowner decides.',
        );
      }
    } on ProfileApiException catch (e) {
      if (mounted) FixoNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (mounted) {
        FixoNotice.error(
          context,
          'Could not send the extra cost request. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Withdraw a still-pending proposal (contract #10).
  Future<void> _withdrawAdjustment(JobAdjustment adjustment) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .withdrawAdjustment(widget.jobId, adjustment.id);
      await _loadAdjustments();
      if (mounted) {
        FixoNotice.success(context, 'Extra cost withdrawn.');
      }
    } on ProfileApiException catch (e) {
      if (mounted) FixoNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (mounted) {
        FixoNotice.error(
          context,
          'Could not withdraw the request. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  // P10-20: Rate homeowner after job completion
  void _rateHomeowner() {
    final job = _job;
    if (job == null) return;

    final homeownerId = job.homeownerId ?? '';
    if (homeownerId.isEmpty) return;

    RatingSheet.show(
      context,
      jobId: widget.jobId,
      jobTitle: job.title,
      onSubmit: (rating, comment) async {
        final reviewRepo = ref.read(reviewsRepositoryProvider);
        await reviewRepo.submitReview(
          widget.jobId,
          rating,
          comment,
          revieweeId: homeownerId,
        );
        if (mounted) {
          setState(() => _hasReview = true);
          FixoNotice.success(context, 'Your review has been submitted.');
        }
      },
    );
  }

  // ── P6-03: Cancel job ────────────────────────────────────────────────────

  Future<void> _showCancelSheet() async {
    final result =
        await showModalBottomSheet<({String reasonCode, String? notes})>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Radii.tile),
            ),
          ),
          builder: (_) =>
              CancelJobSheet(isTradie: true, reasons: _tradieReasons),
        );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final ok = await repo.cancelJobWithReason(
      widget.jobId,
      reasonCode: result.reasonCode,
      notes: result.notes,
    );
    if (!mounted) return;
    if (ok) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.jobId, 'Cancelled');
      await _load();
      if (mounted) {
        FixoNotice.success(context, NoticeCopy.jobCancelled);
      }
    } else {
      FixoNotice.error(context, NoticeCopy.cancelFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  // ── P7: Disputes & No-Shows ──────────────────────────────────────────────

  void _openDispute() {
    context.push('/jobs/${widget.jobId}/dispute');
  }

  Future<void> _reportNoShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Homeowner No-Show'),
        content: const Text(
          'Are you sure the homeowner is not present? This will cancel the job and apply a penalty to the homeowner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Report No-Show',
              style: TextStyle(
                color: Theme.of(context).extension<THColors>()!.danger,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final ok = await repo.reportNoShow(widget.jobId);
    if (!mounted) return;
    if (ok) {
      ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
      await _load();
      if (mounted) {
        FixoNotice.success(context, NoticeCopy.noShowReported);
      }
    } else {
      if (mounted) {
        FixoNotice.error(context, NoticeCopy.noShowFailed);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final job = _job;
    if (job == null) {
      return Scaffold(
        appBar: const FixoGradientAppBar(title: 'Job Detail'),
        body: _TradieJobNotFoundBody(
          heading: 'This job is no longer available',
          subtext: 'It may have been cancelled or assigned to another tradie.',
          onBack: () => context.go('/tradie'),
          onSupport: () => context.push('/settings'),
        ),
      );
    }

    final status = job.status;

    // Determine if the address should be shown in full (status >= Booked).
    // The backend already enforces masking; this is a display hint only.
    final showFullAddress = _isBookedOrLater(status);
    final addressLabel = showFullAddress
        ? (job.address ?? job.suburb)
        : (job.suburb.isNotEmpty ? job.suburb : 'Suburb on file');

    final scheduledLabel = job.scheduledStartUtc != null
        ? DateFormat.MMMEd().add_jm().format(job.scheduledStartUtc!.toLocal())
        : null;

    final canCancel = _cancellableStatuses.contains(status);
    final canDispute = status != 'Requested' && status != 'Cancelled';
    final canReportNoShow =
        status == 'Booked' &&
        job.scheduledStartUtc != null &&
        DateTime.now().toUtc().isAfter(
          job.scheduledStartUtc!.add(const Duration(minutes: 15)),
        );

    // Gross = what the homeowner pays; net = tradie's payout after the
    // platform commission. The commission percent comes from the authorized
    // locale config; when it can't be loaded the net line is omitted rather
    // than estimated.
    // v1.7: `totalAmount` is a deprecated wire alias — the figure the tradie
    // cares about is finalAmount (post check-out) or estimatedTotal before.
    final total = job.finalAmount ?? job.estimatedTotal ?? job.totalAmount;
    final totalLabel = job.finalAmount != null
        ? 'Job total'
        : (job.estimatedTotal != null ? 'Estimated total' : 'Job total');
    final grossLabel = total != null ? formatMoney(total) : null;
    final commissionPercent = Decimal.tryParse(
      '${ref.watch(localeConfigProvider).valueOrNull?['commissionPercent'] ?? ''}',
    );
    final net = payoutNetAmount(total, commissionPercent);

    final canRequestExtraCost =
        status == 'Booked' ||
        status == 'InProgress' ||
        status == 'AwaitingConfirmation';

    final canNavigate =
        showFullAddress &&
        ((job.address?.isNotEmpty ?? false) ||
            (job.latitude != null && job.longitude != null));

    return Scaffold(
      appBar: FixoGradientAppBar(
        title: job.title,
        subtitle: job.category,
        showBack: !widget.embedded,
        actions: [
          if ((canCancel && !_busy) || canDispute || canReportNoShow)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
              onSelected: (value) {
                if (value == 'dispute') _openDispute();
                if (value == 'noshow') _reportNoShow();
                if (value == 'cancel') _showCancelSheet();
              },
              itemBuilder: (context) => [
                if (canReportNoShow)
                  const PopupMenuItem(
                    value: 'noshow',
                    child: Text('Report No-Show'),
                  ),
                if (canDispute)
                  const PopupMenuItem(
                    value: 'dispute',
                    child: Text('Open Dispute'),
                  ),
                if (canCancel && !_busy)
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      'Cancel Job',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          StatusStrip(
            status: status,
            stage: job.stage,
            flowVersion: job.flowVersion,
            referenceCode: job.referenceCode,
          ),
          Expanded(
            child: ListView(
              padding: FixoPadding.page,
              children: [
                // ── Notices stack ────────────────────────────────────────────────
                ..._buildNotices(job, status, theme),

                // ── Card 1: People Card (Homeowner contact, Booked+ only) ─────────
                if (_contact != null) ...[
                  _ContactCard(
                    contact: _contact!,
                    onMessage: () => context.push('/chat/${widget.jobId}'),
                    onCall: (phone) => _call(phone),
                  ),
                  const SizedBox(height: Space.s4),
                ],

                // ── Card 2: Details Card ──────────────────────────────────────────
                FixoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FW.bold,
                        ),
                      ),
                      const SizedBox(height: Space.s3),
                      JobInfoGrid(
                        tiles: [
                          JobInfoTile(
                            label: 'Scheduled',
                            // v1.7: Flexible/ASAP jobs legitimately have no start
                            // yet — show Date TBC, never a fabricated date.
                            value: scheduledLabel ?? 'Date TBC',
                            icon: Icons.calendar_today_outlined,
                          ),
                          JobInfoTile(
                            label: 'Duration',
                            value: job.hours > 0
                                ? '${job.hours} hour${job.hours != 1 ? 's' : ''}'
                                : (job.estimatedHours != null
                                      ? '≈ ${_formatHours(job.estimatedHours!)}'
                                      : 'TBC'),
                            icon: Icons.timer_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.s3),
                      JobInfoTile(
                        icon: showFullAddress
                            ? Icons.location_on
                            : Icons.location_on_outlined,
                        label: showFullAddress
                            ? 'Full Address'
                            : 'Approximate Location',
                        value: addressLabel,
                      ),
                      if (!showFullAddress) ...[
                        const SizedBox(height: Space.s1),
                        Text(
                          'Full address shown once booked.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (canNavigate) ...[
                        const SizedBox(height: Space.s2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _NavigateButton(
                            onAppSelected: (app) => _navigate(app),
                          ),
                        ),
                      ],
                      if (grossLabel != null) ...[
                        const SizedBox(height: Space.s3),
                        // Show net earnings as the primary figure (V16-16).
                        if (net != null && commissionPercent != null) ...[
                          JobInfoTile(
                            emphasized: true,
                            label:
                                'You earn (after '
                                '${commissionPercent.toStringAsFixed(1)}% platform fee)',
                            value: formatMoney(net),
                            icon: Icons.payments_outlined,
                          ),
                          const SizedBox(height: Space.s2),
                          JobInfoTile(
                            label: totalLabel,
                            value: grossLabel,
                            icon: Icons.attach_money_outlined,
                          ),
                        ] else ...[
                          JobInfoTile(
                            emphasized: true,
                            label: 'You earn',
                            value: grossLabel,
                            icon: Icons.payments_outlined,
                          ),
                        ],
                        if (job.estimatedTotal != null &&
                            job.finalAmount == null) ...[
                          const SizedBox(height: Space.s2),
                          Text(
                            'Total confirmed on completion',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: Space.s4),
                      Text(
                        'Job Description',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: Space.s2),
                      Text(
                        job.description?.isNotEmpty == true
                            ? job.description!
                            : 'No description provided.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),

                // ── v1.7 P12-19: extra-cost requests + running total ─────────────
                if (canRequestExtraCost) ...[
                  const SizedBox(height: Space.s4),
                  _TradieAdjustmentsCard(
                    adjustments: _adjustments,
                    onRequestExtra: _showRequestExtraCostSheet,
                    onWithdraw: _withdrawAdjustment,
                  ),
                ],

                // ── Quiet "Need help?" row ────────────────────────────────────────
                if (canCancel || canDispute) ...[
                  const SizedBox(height: Space.s5),
                  Center(
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.help_outline,
                        size: Sizes.iconInfo,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        'Need help with this job?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onPressed: () {
                        if (canDispute) {
                          _openDispute();
                        } else if (canCancel && !_busy) {
                          _showCancelSheet();
                        }
                      },
                    ),
                  ),
                ],

                // Spacer so the bottom nav doesn't overlap content.
                const SizedBox(height: Space.stickyBarClearance),
              ],
            ),
          ), // Expanded
        ],
      ), // Column body
      // ── Action bar ─────────────────────────────────────────────────────────
      bottomNavigationBar: _buildActionBar(context, status),
    );
  }

  Widget? _buildActionBar(BuildContext context, String status) {
    if (status == 'Booked') {
      return StickyActionBar(
        child: FixoPrimaryButton(
          key: const Key('check_in_button'),
          label: 'Check In',
          isLoading: _busy,
          onPressed: _busy ? null : _checkIn,
        ),
      );
    }

    if (status == 'InProgress') {
      return StickyActionBar(
        child: FixoPrimaryButton(
          key: const Key('check_out_button'),
          label: 'Check Out',
          isLoading: _busy,
          onPressed: _busy ? null : _checkOut,
        ),
      );
    }

    // P10-20: Rate Homeowner button on Completed status.
    if (status == 'Completed') {
      if (_hasReview) {
        // P10-19: Show pending/revealed state after review submitted.
        return StickyActionBar(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s4,
              vertical: Space.s3,
            ),
            decoration: BoxDecoration(
              color: DesignTokens.brand500.withValues(alpha: Alpha.tint),
              borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
              border: Border.all(
                color: DesignTokens.brand500.withValues(alpha: Alpha.borderMid),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_top_outlined,
                  color: DesignTokens.brand500,
                  size: Sizes.iconAction,
                ),
                const SizedBox(width: Space.s2_5),
                Expanded(
                  child: Text(
                    'Review submitted — waiting for the other party.',
                    style: TextStyle(
                      color: DesignTokens.brand500,
                      fontWeight: FW.medium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Show Rate Homeowner button if homeownerId is available.
      final homeownerId = _job?.homeownerId ?? '';
      if (homeownerId.isNotEmpty) {
        return StickyActionBar(
          child: FixoPrimaryButton(
            key: const Key('rate_homeowner_button'),
            label: 'Rate Homeowner',
            onPressed: _rateHomeowner,
          ),
        );
      }
    }

    // No action bar for other statuses.
    return null;
  }

  List<Widget> _buildNotices(Job job, String status, ThemeData theme) {
    final notices = <Widget>[];

    if (job.urgency != null &&
        (job.urgency == 'Emergency' || job.urgency == 'High')) {
      notices.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              label: job.urgency!.toUpperCase(),
              kind: FixoBadgeKind.actionNeeded,
            ),
          ),
        ),
      );
    }

    if (status == 'AwaitingConfirmation') {
      notices.add(
        const Padding(
          padding: EdgeInsets.only(bottom: Space.s3),
          child: FixoInfoBanner(
            icon: Icons.hourglass_top_outlined,
            color: DesignTokens.amber,
            message:
                'Waiting for the homeowner to confirm the work is complete. '
                'They have 48 hours — if they don\'t respond the job '
                'auto-completes.',
          ),
        ),
      );
    }

    if (status == 'Completed') {
      notices.add(
        const Padding(
          padding: EdgeInsets.only(bottom: Space.s3),
          child: FixoInfoBanner(
            icon: Icons.check_circle_outline,
            color: DesignTokens.brand500,
            message: 'Job completed. Thank you!',
          ),
        ),
      );
    }

    if (status == 'Cancelled') {
      notices.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: FixoInfoBanner(
            icon: Icons.cancel_outlined,
            color: theme.colorScheme.error,
            message: 'This job was cancelled.',
          ),
        ),
      );
    }

    // Dispute banner: shown only on non-terminal jobs with an active dispute.
    if (status != 'Completed' &&
        status != 'Cancelled' &&
        (status == 'Disputed' ||
            job.disputeStatus == 'Open' ||
            job.disputeStatus == 'UnderReview')) {
      notices.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: FixoInfoBanner(
            icon: Icons.gavel,
            color: theme.colorScheme.error,
            message: 'This job has an active dispute under review.',
          ),
        ),
      );
    }

    return notices;
  }

  /// Returns true if the job is at a stage where the exact address
  /// should be visible to the tradie.
  static bool _isBookedOrLater(String status) {
    const bookedOrLater = {
      'Booked',
      'InProgress',
      'AwaitingConfirmation',
      'Completed',
    };
    return bookedOrLater.contains(status);
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

/// ≥48px maps-launch action under the address tile. Disabled states are
/// handled by the caller hiding this widget entirely (no address/coords).
/// Tapping opens a bottom-sheet map-app picker (V16-16).
class _NavigateButton extends StatelessWidget {
  final ValueChanged<MapApp>? onAppSelected;
  const _NavigateButton({this.onAppSelected});

  void _showMapPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DesignTokens.surfaceCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: Sizes.handleW,
                  height: Sizes.handleH,
                  margin: const EdgeInsets.only(bottom: Space.s4),
                  decoration: BoxDecoration(
                    color: DesignTokens.paperLine(isDark),
                    borderRadius: BorderRadius.circular(Radii.micro),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.map_outlined,
                    color: DesignTokens.foregroundBrand(isDark),
                  ),
                  title: Text(
                    'Apple Maps',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontWeight: FW.semibold,
                      color: DesignTokens.foreground(isDark),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    onAppSelected?.call(MapApp.appleMaps);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.navigation_outlined,
                    color: DesignTokens.foregroundBrand(isDark),
                  ),
                  title: Text(
                    'Google Maps',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontWeight: FW.semibold,
                      color: DesignTokens.foreground(isDark),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    onAppSelected?.call(MapApp.googleMaps);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FixoTonalButton(
      key: const Key('navigate_button'),
      onPressed: () => _showMapPicker(context),
      icon: Icons.directions_outlined,
      label: 'Navigate',
      height: Sizes.tapMin,
    );
  }
}

/// Authorized homeowner contact card (V15-15, V16-07). Rendered only when the server
/// returned a contact for a Booked+ job; the Call action appears only when a
/// real phone number exists — never a fabricated or placeholder one.
class _ContactCard extends StatelessWidget {
  final JobContact contact;
  final VoidCallback onMessage;
  final ValueChanged<String> onCall;

  const _ContactCard({
    required this.contact,
    required this.onMessage,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = contact.phoneNumber?.trim();
    final canCall = phone != null && phone.isNotEmpty;

    return FixoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FixoAvatar(
                initials: contact.firstName.isNotEmpty
                    ? contact.firstName[0].toUpperCase()
                    : 'H',
                radius: Sizes.avatarRadius,
              ),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.firstName.isNotEmpty
                          ? contact.firstName
                          : 'Homeowner',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FW.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Homeowner',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s3),
          Row(
            children: [
              Expanded(
                child: FixoTonalButton(
                  key: const Key('message_homeowner_button'),
                  icon: Icons.chat_bubble_outline,
                  label: 'Message',
                  onPressed: onMessage,
                ),
              ),
              if (canCall) ...[
                const SizedBox(width: Space.s2),
                Expanded(
                  child: FixoTonalButton(
                    key: const Key('call_homeowner_button'),
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onPressed: () => onCall(phone),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Friendly recovery body for tradie screens where a job cannot be loaded
/// (expired, unavailable, or deleted). Always provides a path back (V16-02).
class _TradieJobNotFoundBody extends StatelessWidget {
  final String heading;
  final String subtext;
  final VoidCallback onBack;
  final VoidCallback? onSupport;

  const _TradieJobNotFoundBody({
    required this.heading,
    required this.subtext,
    required this.onBack,
    this.onSupport,
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
            Icons.work_off_outlined,
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
            child: FilledButton(
              onPressed: onBack,
              child: const Text('Back to dashboard'),
            ),
          ),
          if (onSupport != null) ...[
            const SizedBox(height: Space.s3),
            SizedBox(
              width: double.infinity,
              height: Sizes.button,
              child: OutlinedButton(
                onPressed: onSupport,
                child: const Text('Contact support'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── v1.7 P12-11: check-out sheet ─────────────────────────────────────────────

/// Collects the hours actually worked (+ optional note) and previews the
/// computed total before submitting: labour = rate × hours, plus the extras
/// already approved by the homeowner. The server recomputes everything —
/// this preview is arithmetic on server-owned figures only.
class _CheckOutSheet extends StatefulWidget {
  final Job job;
  final Decimal approvedAdjustmentsTotal;

  const _CheckOutSheet({
    required this.job,
    required this.approvedAdjustmentsTotal,
  });

  @override
  State<_CheckOutSheet> createState() => _CheckOutSheetState();
}

class _CheckOutSheetState extends State<_CheckOutSheet> {
  late final TextEditingController _hoursController;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController(
      text: _formatHoursText(widget.job.hours.toDouble()),
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static String _formatHoursText(double hours) => hours == hours.roundToDouble()
      ? hours.round().toString()
      : hours.toString();

  double? get _parsedHours {
    final parsed = double.tryParse(
      _hoursController.text.trim().replaceAll(',', '.'),
    );
    return parsed != null && parsed > 0 ? parsed : null;
  }

  void _submit(BuildContext context) {
    final hours = _parsedHours;
    if (hours == null) return;
    Navigator.pop(context, hours);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final job = widget.job;
    final hours = _parsedHours;
    final rate = job.hourlyRate;

    // Preview only — the server's check-out response is the authority.
    Decimal? labour;
    if (hours != null && rate != null) {
      labour = labourPreview(rate, hours);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.s6,
          Space.gutter,
          MediaQuery.of(context).viewInsets.bottom + Space.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Check out & submit hours',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FW.bold),
            ),
            const SizedBox(height: Space.s1),
            Text(
              'The homeowner reviews this summary and approves the amount '
              'before paying.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.s4),
            TextField(
              key: const Key('final_hours_field'),
              controller: _hoursController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Hours worked',
                errorText:
                    _hoursController.text.trim().isNotEmpty && hours == null
                    ? 'Enter the hours you worked, e.g. 3.5'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.s3),
            TextField(
              controller: _notesController,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText:
                    'What was done, anything the homeowner should '
                    'know…',
              ),
            ),
            const SizedBox(height: Space.s3),
            // Computed preview — shown before the submit button (P12-11).
            if (labour != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Labour (${_formatHoursText(hours!)} × ${formatMoney(rate!)})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatMoney(labour),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FW.semibold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.approvedAdjustmentsTotal > Decimal.zero) ...[
              const SizedBox(height: Space.s1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Approved extras',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatMoney(widget.approvedAdjustmentsTotal),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FW.semibold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (labour != null) ...[
              const SizedBox(height: Space.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estimated total',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FW.bold,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatMoney(labour + widget.approvedAdjustmentsTotal),
                      style: TextStyle(
                        fontFamily: DesignTokens.fontBody,
                        fontSize: DesignTokens.fontSizeH2,
                        fontWeight: FW.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark ? Colors.white : DesignTokens.brand900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.s4),
            FixoPrimaryButton(
              key: const Key('check_out_submit_button'),
              label: 'Submit check-out',
              onPressed: hours == null ? null : () => _submit(context),
            ),
            if (hours == null)
              Padding(
                padding: const EdgeInsets.only(top: Space.s2),
                child: Text(
                  'Enter your hours to enable check-out.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper used by the labour preview — multiplies the hourly [rate] by
/// [hours] without ever leaving decimal arithmetic.
Decimal labourPreview(Decimal rate, double hours) {
  final hoursDecimal =
      Decimal.tryParse(hours.toStringAsFixed(2)) ?? Decimal.zero;
  return rate * hoursDecimal;
}

// ── v1.7 P12-19: extra-cost card + sheets ────────────────────────────────────

/// The tradie's extra-cost list for this job: status per request, running
/// approved total, withdraw action for pending items, and the
/// "Request extra cost" entry point.
class _TradieAdjustmentsCard extends StatelessWidget {
  final List<JobAdjustment> adjustments;
  final VoidCallback onRequestExtra;
  final ValueChanged<JobAdjustment> onWithdraw;

  const _TradieAdjustmentsCard({
    required this.adjustments,
    required this.onRequestExtra,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<THColors>()!;

    final approvedTotal = adjustments
        .where((a) => a.isApproved)
        .fold<Decimal>(Decimal.zero, (sum, a) => sum + a.amount);
    final declined = adjustments
        .where((a) => a.status == JobAdjustment.statusDeclined)
        .toList();

    return FixoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extra costs',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FW.bold),
          ),
          const SizedBox(height: Space.s1),
          Text(
            'Ask the homeowner to approve extra costs — materials, labour, '
            'travel. Nothing is billed without their approval.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.s3),
          FixoTonalButton(
            key: const Key('request_extra_cost_button'),
            icon: Icons.add_circle_outline,
            label: 'Request extra cost',
            fullWidth: true,
            onPressed: onRequestExtra,
          ),
          if (adjustments.isNotEmpty) ...[
            const SizedBox(height: Space.s3),
            for (final a in adjustments) ...[
              _TradieAdjustmentRow(
                adjustment: a,
                onWithdraw: a.isPending ? () => onWithdraw(a) : null,
              ),
              const SizedBox(height: Space.s2),
            ],
            if (approvedTotal > Decimal.zero) ...[
              const Divider(
                height: Space.s4,
                color: DesignTokens.paperLineLight,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Approved total',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatMoney(approvedTotal),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FW.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          // A declined proposal puts the choice back with the tradie —
          // continue the original scope, or cancel with the no-penalty
          // scope_change_declined reason (P6-03 cancel sheet).
          if (declined.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.s2),
              child: Text(
                'A declined extra isn\'t billed — keep to the original scope '
                'or cancel the job with "Scope changed" (no penalty).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.accentText,
                  fontSize: DesignTokens.fontSizeCaption,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TradieAdjustmentRow extends StatelessWidget {
  final JobAdjustment adjustment;
  final VoidCallback? onWithdraw;

  const _TradieAdjustmentRow({required this.adjustment, this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a = adjustment;
    final (:tone, :label, :icon) = switch (a.status) {
      JobAdjustment.statusApproved => (
        tone: ChipTone.success,
        label: 'Approved',
        icon: Icons.check_circle_outline,
      ),
      JobAdjustment.statusDeclined => (
        tone: ChipTone.danger,
        label: 'Declined',
        icon: Icons.cancel_outlined,
      ),
      JobAdjustment.statusPending => (
        tone: ChipTone.warning,
        label: 'Waiting for approval',
        icon: Icons.hourglass_top_outlined,
      ),
      JobAdjustment.statusWithdrawn => (
        tone: ChipTone.neutral,
        label: 'Withdrawn',
        icon: Icons.undo_outlined,
      ),
      JobAdjustment.statusExpired => (
        tone: ChipTone.neutral,
        label: 'Expired',
        icon: Icons.timer_off_outlined,
      ),
      _ => (
        tone: ChipTone.neutral,
        label: a.status,
        icon: Icons.help_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceTonal(isDark),
        borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
        border: Border.all(color: DesignTokens.paperLine(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: label, tone: tone, icon: icon),
              const Spacer(),
              Flexible(
                child: Text(
                  formatMoney(a.amount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FW.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s1),
          if (a.description.isNotEmpty)
            Text(a.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Space.s0_5),
          Text(
            [
              a.kind,
              'sent ${DateFormat('d MMM').format(a.createdAtUtc.toLocal())}',
              if (a.evidenceUrl?.isNotEmpty == true) 'receipt attached',
              if (a.responseNote?.isNotEmpty == true) 'note: ${a.responseNote}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeCaption,
            ),
          ),
          if (onWithdraw != null) ...[
            const SizedBox(height: Space.s2),
            Align(
              alignment: Alignment.centerRight,
              child: FixoTonalButton(
                key: Key('adjustment_withdraw_${a.id}'),
                label: 'Withdraw',
                onPressed: onWithdraw,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kind picker + amount + description for a new extra-cost proposal
/// (P12-19). Receipt attach is shown as a disabled "add from camera" row —
/// the API has no generic upload endpoint yet, so it stays optional and
/// documents itself.
class _RequestExtraCostSheet extends StatefulWidget {
  const _RequestExtraCostSheet();

  @override
  State<_RequestExtraCostSheet> createState() => _RequestExtraCostSheetState();
}

class _RequestExtraCostSheetState extends State<_RequestExtraCostSheet> {
  static const _kinds = <(String, String)>[
    (JobAdjustment.kindMaterials, 'Materials'),
    (JobAdjustment.kindExtraLabour, 'Extra labour'),
    (JobAdjustment.kindTravel, 'Travel'),
    (JobAdjustment.kindOther, 'Other'),
  ];

  String _kind = JobAdjustment.kindMaterials;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Decimal? get _parsedAmount => Decimal.tryParse(_amountController.text.trim());

  bool get _canSubmit =>
      _parsedAmount != null &&
      _parsedAmount! > Decimal.zero &&
      _descriptionController.text.trim().isNotEmpty;

  void _submit(BuildContext context) {
    if (!_canSubmit) return;
    Navigator.pop(context, (
      _kind,
      _parsedAmount!,
      _descriptionController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.s6,
          Space.gutter,
          MediaQuery.of(context).viewInsets.bottom + Space.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Request extra cost',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FW.bold),
            ),
            const SizedBox(height: Space.s1),
            Text(
              'The homeowner approves or declines — only approved extras '
              'are added to the total.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.s4),
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: _kinds
                  .map(
                    (kind) => FixoFilterPill(
                      label: kind.$2,
                      selected: _kind == kind.$1,
                      onSelected: (_) => setState(() => _kind = kind.$1),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: Space.s3),
            TextField(
              key: const Key('extra_cost_amount_field'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.s3),
            TextField(
              key: const Key('extra_cost_description_field'),
              controller: _descriptionController,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'What is it for?',
                hintText: 'e.g. Replacement mixer tap, bought from Mitre 10',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.s2),
            // Receipt attach — optional and documented: the API surface has
            // no generic blob-upload endpoint, so nothing is faked here.
            Opacity(
              opacity: Alpha.divider,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.receipt_long_outlined,
                  size: Sizes.iconAction,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Attach a receipt or photo (optional — coming soon)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s3),
            FixoPrimaryButton(
              key: const Key('extra_cost_submit_button'),
              label: 'Send to homeowner',
              onPressed: _canSubmit ? () => _submit(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hours render without a trailing ".0" — 2.5 stays 2.5, 3 stays 3.
String _formatHours(double hours) => hours == hours.roundToDouble()
    ? hours.round().toString()
    : hours.toString();
