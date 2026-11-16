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
import '../../widgets/tradie_widgets.dart';
import '../../widgets/rating_sheet.dart';
import '../widgets/cancel_job_sheet.dart';
import '../widgets/job_info_grid.dart';
import '../widgets/job_status_presentation.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/status_strip.dart';
import '../widgets/fixo_feedback.dart';
import '../../feedback/fixo_notice.dart';


/// Homeowner-side job detail screen (P5-07).
///
/// Shows contextual primary action per status:
/// – Booked / InProgress    → "Open Chat" (tradie is on the way / working)
/// – AwaitingConfirmation   → "Approve & pay" — review the itemised summary,
///                            POST /approve, then continue to payment
/// – Completed              → "Leave a Review" prompt (if no review yet) + read-only stepper
/// – Cancelled              → read-only
///
/// A "Cancel Job" overflow action is available for cancellable statuses (P6-03).
class HomeownerJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  final bool embedded;

  const HomeownerJobDetailScreen({
    super.key,
    required this.jobId,
    this.embedded = false,
  });

  @override
  ConsumerState<HomeownerJobDetailScreen> createState() =>
      _HomeownerJobDetailScreenState();
}

class _HomeownerJobDetailScreenState
    extends ConsumerState<HomeownerJobDetailScreen> {
  bool _busy = false;
  bool _loading = true;
  bool _approving = false;
  Job? _job;
  bool _hasReview = false;
  UserProfile? _tradieProfile;
  JobContact? _contact;
  List<JobAdjustment> _adjustments = const [];
  StreamSubscription<JobStatusEvent>? _statusSub;
  StreamSubscription<JobAdjustmentEvent>? _adjustmentSub;

  // Statuses a homeowner is allowed to cancel.
  static const _cancellableStatuses = {
    'Requested',
    'AwaitingPayment',
    'PaymentReview',
    'Booked',
    'InProgress',
    'AwaitingConfirmation',
  };

  // Homeowner-facing reason codes with display labels.
  static const _homeownerReasons = [
    ('homeowner_changed_mind', 'Changed my mind'),
    ('emergency', 'Emergency situation'),
    ('scope_change_declined', 'Scope changed — tradie declined'),
    ('homeowner_issue', 'Personal / scheduling issue'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
    // Status transitions arrive via SignalR; reload so the sticky action,
    // banner and stepper always reflect the server state.
    _statusSub = ref.read(jobHubClientProvider).onJobStatusChanged.listen((
      event,
    ) {
      if (event.jobId == widget.jobId && mounted) _load();
    });
    // v1.7 P12-18: adjustment proposals/decisions arrive live — reload the
    // adjustments history and the completion summary so the running total
    // stays current.
    _adjustmentSub = ref
        .read(jobHubClientProvider)
        .onAdjustmentChanged
        .listen((event) {
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

    // Matched tradie identity comes from the authorized public profile
    // contract; absence of a profile never fabricates a name.
    UserProfile? tradie;
    JobContact? contact;
    final tradieId = job?.matchedTradieId;
    if (tradieId != null && tradieId.isNotEmpty) {
      tradie = await ref.read(reviewsRepositoryProvider).getProfile(tradieId);
      if (!mounted) return;
      try {
        contact = await repo.getJobContact(widget.jobId);
      } catch (_) {}
      if (!mounted) return;
    }

    const bool hasReview = false;

    // v1.7 P12-20: adjustments history — always loaded when the job exists
    // so the homeowner sees every proposed extra cost.
    final adjustments = await repo.getAdjustments(widget.jobId);
    if (!mounted) return;

    setState(() {
      _job = job;
      _tradieProfile = tradie;
      _contact = contact;
      _hasReview = hasReview;
      _adjustments = adjustments;
      _loading = false;
    });
  }

  /// v1.7 P12-11: homeowner approves the itemised completion summary.
  /// POST /api/jobs/:id/approve books the amount — the job becomes
  /// AwaitingPayment and the homeowner lands on the payment screen
  /// (payment is never reached directly from a Requested job).
  Future<void> _approveAndPay() async {
    if (_approving) return;
    setState(() => _approving = true);
    final repo = ref.read(jobsRepositoryProvider);
    try {
      await repo.approveJob(widget.jobId);
      if (!mounted) return;
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.jobId, 'AwaitingPayment');
      await _load();
      if (mounted) {
        await context.push('/jobs/${widget.jobId}/payment');
      }
    } on ProfileApiException catch (e) {
      if (mounted) FixoNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (mounted) {
        FixoNotice.error(
          context,
          'Could not approve the amount. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _approving = false);
  }

  void _openChat() {
    context.push('/chat/${widget.jobId}');
  }

  /// Picks the single banner shown under the stepper — an active dispute
  /// outranks routine status guidance so banners never stack.
  ///
  /// Terminal jobs (Completed, Cancelled) always show their terminal banner,
  /// never an active dispute banner (V16-02).
  (IconData, Color, String)? _bannerContent(
    Job job,
    String status,
    String? scheduledLabel,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Terminal statuses (Completed, Cancelled) must never show an active
    // dispute banner, even if stale disputeStatus data exists (V16-02).
    if (status == 'Completed') {
      return !_hasReview
          ? (
              Icons.star_outline,
              DesignTokens.foregroundBrand(isDark),
              'Job complete! Leave a review to help future homeowners.',
            )
          : (
              Icons.hourglass_top_outlined,
              DesignTokens.foregroundBrand(isDark),
              'Review submitted — waiting for the other party. It will be visible after both review or 7 days.',
            );
    }
    if (status == 'Cancelled') {
      return (
        Icons.cancel_outlined,
        theme.colorScheme.error,
        'This job was cancelled.',
      );
    }

    // Active dispute on a non-terminal job (Booked, InProgress, AwaitingConfirmation, Disputed)
    // outranks routine status guidance so banners never stack.
    final hasActiveDispute = status == 'Disputed' ||
        job.disputeStatus == 'Open' ||
        job.disputeStatus == 'UnderReview';
    if (hasActiveDispute) {
      return (
        Icons.gavel,
        theme.colorScheme.error,
        'This job has an active dispute under review.',
      );
    }

    // v1.7 P12-11: check-out total exceeded the homeowner's estimate
    // tolerance — flag it ahead of the itemised summary. The server's
    // tolerance reason is not part of the JobDto, so the banner stays
    // factual rather than inventing one.
    if (status == 'AwaitingConfirmation' && job.isAboveEstimateTolerance) {
      return (
        Icons.trending_up_outlined,
        DesignTokens.inkAccent(isDark),
        'The final total is higher than the original estimate. '
            'Check the breakdown before you approve.',
      );
    }

    return switch (status) {
      'Booked' => (
        Icons.schedule_outlined,
        DesignTokens.foregroundBrand(isDark),
        scheduledLabel != null
            ? 'Your tradie is booked for $scheduledLabel.'
            : 'Your tradie is booked and will arrive soon.',
      ),
      'InProgress' => (
        Icons.construction_outlined,
        DesignTokens.inkAccent(isDark),
        'Your tradie is currently working on the job.',
      ),
      'AwaitingConfirmation' => (
        Icons.task_alt_outlined,
        DesignTokens.inkAccent(isDark),
        'Your tradie has checked out. Please review and confirm '
            'the work is complete.',
      ),
      _ => null,
    };
  }

  void _leaveReview() {
    final job = _job;
    if (job == null) return;

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
          revieweeId: job.matchedTradieId ?? '',
        );
        if (mounted) {
          setState(() => _hasReview = true);
          // P10-19: Blind review confirmation
          FixoNotice.success(context, 'Your review has been submitted.');
        }
      },
    );
  }

  // ── P6-03: Cancel job ────────────────────────────────────────────────────

  /// Status-specific fee disclosure, matching the server penalty rules:
  /// no penalty before Booked, a flat 10% platform fee once booked, and
  /// hours-worked + 10% once work has started.
  String _cancellationWarning(String status) {
    return switch (status) {
      'InProgress' || 'AwaitingConfirmation' => 'Cancelling now may incur a fee for hours already worked plus a 10% platform penalty.',
      'Booked' => 'Cancelling a booked job incurs a 10% platform fee.',
      _ => 'You can cancel without a fee before the job is booked. Fees apply once work is booked or started.',
    };
  }

  Future<void> _showCancelSheet() async {
    final result =
        await showModalBottomSheet<({String reasonCode, String? notes})>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.tile)),
          ),
          builder: (_) => CancelJobSheet(
            isTradie: false,
            reasons: _homeownerReasons,
            warning: _cancellationWarning(_job?.status ?? ''),
          ),
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

  // P10-23: Edit job — only available for Draft; backend returns 409 if
  // matching has already started.
  void _editJob() {
    final status = _job?.status;
    // Guard in case the status has changed since last load.
    if (status != null && status != 'Draft') {
      _show409Dialog();
      return;
    }
    context.push('/jobs/${widget.jobId}/edit');
  }

  void _show409Dialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot Edit Job'),
        content: const Text(
          'Job cannot be edited after matching has started. '
          'Cancel and repost to change details.',
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

  Future<void> _reportNoShow() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report No-Show'),
        content: const Text(
          'The tradie hasn\'t arrived. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reassign'),
            child: const Text('Reassign'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(
              'Cancel & Refund',
              style: TextStyle(color: Theme.of(context).extension<THColors>()!.danger),
            ),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final ok = await repo.reportNoShow(widget.jobId, action: action);
    if (!mounted) return;
    if (ok) {
      ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();
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

  // ── v1.7 P12-20: homeowner approve/decline an extra cost ────────────────

  /// Approve/Decline sheet for a pending adjustment (P12-20). Shows what was
  /// proposed, how much, whether a receipt is attached, and the running
  /// total vs estimate before the homeowner commits — one explicit tap, no
  /// auto-approval path (D6 cut).
  Future<void> _showAdjustmentDecisionSheet(JobAdjustment adjustment) async {
    final decision = await showModalBottomSheet<(
      bool approve,
      String? note,
    )>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (_) => _AdjustmentDecisionSheet(
        adjustment: adjustment,
        estimatedTotal: _job?.estimatedTotal,
        approvedAdjustmentsTotal: _approvedAdjustmentsTotal,
      ),
    );
    if (decision == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .respondToAdjustment(
            widget.jobId,
            adjustment.id,
            approve: decision.$1,
            note: decision.$2,
          );
      await _loadAdjustments();
      await _load();
      if (mounted) {
        FixoNotice.success(
          context,
          decision.$1
              ? 'Extra cost approved — it\'s added to the job total.'
              : 'Extra cost declined.',
        );
      }
    } on ProfileApiException catch (e) {
      if (mounted) FixoNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (mounted) {
        FixoNotice.error(
          context,
          'Could not record your decision. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Sum of Approved adjustments only — unapproved extras never reach the
  /// homeowner's total (contract #9).
  Decimal get _approvedAdjustmentsTotal {
    var total = Decimal.zero;
    for (final a in _adjustments) {
      if (a.isApproved) total += a.amount;
    }
    return total;
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
        appBar: FixoAppBar(
          title: 'Job Detail',
          showBack: !widget.embedded,
        ),
        body: _JobNotFoundBody(
          heading: "We couldn't find this job",
          onBack: () => context.go('/jobs'),
          onSupport: () => context.push('/settings'),
        ),
      );
    }

    final status = job.status;
    final hasTradie =
        job.matchedTradieId != null && job.matchedTradieId!.isNotEmpty;
    final canCancel = _cancellableStatuses.contains(status);
    final canChat =
        hasTradie &&
        (status == 'Booked' ||
            status == 'InProgress' ||
            status == 'AwaitingConfirmation');
    final canDispute = status != 'Requested' && status != 'Cancelled';
    final canReportNoShow =
        status == 'Booked' &&
        job.scheduledStartUtc != null &&
        DateTime.now().toUtc().isAfter(
          job.scheduledStartUtc!.add(const Duration(minutes: 15)),
        );

    final scheduledLabel = job.scheduledStartUtc != null
        ? DateFormat.MMMEd().add_jm().format(job.scheduledStartUtc!.toLocal())
        : null;

    // v1.7 (P12-15): never a fixed total before completion. Hourly jobs show
    // the rate with "total confirmed on completion"; project jobs show the
    // quote/estimate total; completed jobs show the final amount. The
    // deprecated `totalAmount` wire alias is intentionally not used here.
    final showRateLine = job.hourlyRate != null &&
        (status == 'Requested' ||
            status == 'Matching' ||
            status == 'Booked' ||
            status == 'InProgress' ||
            status == 'AwaitingConfirmation');
    final totalLabel = switch (status) {
      // After check-out the server's finalAmount is the authority.
      'AwaitingConfirmation' || 'AwaitingPayment' || 'PaymentReview' ||
      'Completed' =>
        job.finalAmount != null
            ? ('Total', job.finalAmount!)
            : (job.estimatedTotal != null
                ? ('Estimated total', job.estimatedTotal!)
                : null),
      _ =>
        // Before completion: an estimate when the server computed one.
        job.estimatedTotal != null
            ? ('Estimated total', job.estimatedTotal!)
            : null,
    };

    // P10-22: materials disclaimer from locale config
    final materialsDisclaimer =
        ref.watch(localeConfigProvider).value?['materialsDisclaimer']
            as String?;

    // H12 app bar: plain surface, title = job title, back + ⋮ only.
    // All actions (cancel, dispute, no-show) live in the overflow menu so
    // the action bar stays clean and the 3-dot icon uses theme ink color.
    final hasOverflowItems =
        (canCancel && !_busy) || canDispute || canReportNoShow;

    return Scaffold(
      appBar: FixoAppBar(
        title: job.title,
        showBack: !widget.embedded,
        actions: [
          if (hasOverflowItems)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: isDark ? DesignTokens.inkDark : DesignTokens.brand900,
              ),
              onSelected: (value) {
                if (value == 'cancel') _showCancelSheet();
                if (value == 'dispute') _openDispute();
                if (value == 'noshow') _reportNoShow();
                if (value == 'edit') _editJob();
              },
              itemBuilder: (context) => [
                if (status == 'Draft')
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit job'),
                  ),
                if (canReportNoShow)
                  const PopupMenuItem(
                    value: 'noshow',
                    child: Text('Report no-show'),
                  ),
                if (canDispute)
                  const PopupMenuItem(
                    value: 'dispute',
                    child: Text('Open dispute'),
                  ),
                if (canCancel && !_busy)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel job'),
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
          // ── Card 1: Tradie card ───────────────────────────────────────────
          if (hasTradie) ...[
            const SizedBox(height: Space.s3),
            _MatchedTradieCard(
              profile: _tradieProfile,
              fallbackTrade: job.category,
              canChat: canChat,
              phoneNumber: _contact?.phoneNumber,
              onChat: _openChat,
              onViewProfile: () =>
                  context.push('/tradie/${job.matchedTradieId}'),
              onCall: (phone) =>
                  ref.read(externalLauncherProvider).callPhone(phone),
            ),
          ],

          // ── Card 2: Details card ──────────────────────────────────────────
          const SizedBox(height: Space.s3),
          FixoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scheduled / Duration grid — "Date TBC" when the job has no
                // confirmed start (v1.7: Flexible/ASAP jobs never fake one).
                JobInfoGrid(
                  tiles: [
                    JobInfoTile(
                      label: 'Scheduled',
                      value: scheduledLabel ?? 'Date TBC',
                      icon: Icons.calendar_today_outlined,
                    ),
                    JobInfoTile(
                      label: 'Duration',
                      value: (job.hours > 0)
                          ? '${job.hours} hour${job.hours != 1 ? 's' : ''}'
                          : (job.estimatedHours != null
                              ? '≈ ${_formatHours(job.estimatedHours!)}'
                              : 'TBC'),
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
                // Address row
                if (job.address != null && job.address!.isNotEmpty) ...[
                  const SizedBox(height: Space.s3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: Sizes.iconSm,
                        color: DesignTokens.inkSoft(isDark),
                      ),
                      const SizedBox(width: Space.s2),
                      Expanded(
                        child: Text(
                          job.address!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: DesignTokens.inkSoft(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Total price row — v1.7: label reflects the pricing stage
                // (Estimated total → Total after approval) and hourly jobs
                // show the rate line instead of a fixed total.
                if (totalLabel case (final totalTitle, final totalValue)) ...[
                  const SizedBox(height: Space.s2_5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          totalTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: DesignTokens.inkSoft(isDark),
                          ),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatMoney(totalValue),
                            style: TextStyle(
                              fontFamily: DesignTokens.fontBody,
                              fontSize: DesignTokens.fontSizeAmount,
                              fontWeight: FW.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: DesignTokens.foreground(isDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (showRateLine) ...[
                  const SizedBox(height: Space.s2),
                  Text(
                    '${formatMoney(job.hourlyRate!)}/hr · total confirmed on completion',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: DesignTokens.inkSoft(isDark),
                    ),
                  ),
                ],
                if (status == 'AwaitingPayment') ...[
                  const SizedBox(height: Space.s3),
                  FixoTonalButton(
                    key: const Key('payment_details_button'),
                    icon: Icons.payments_outlined,
                    label: 'Payment details',
                    fullWidth: true,
                    onPressed: () =>
                        context.push('/jobs/${widget.jobId}/payment'),
                  ),
                ],
                // Divider + description
                const SizedBox(height: Space.s3),
                Divider(height: 1, color: theme.extension<THColors>()!.line),
                const SizedBox(height: Space.s3),
                Text('Job Description', style: theme.textTheme.titleSmall),
                const SizedBox(height: Space.s2),
                Text(
                  job.description?.isNotEmpty == true
                      ? job.description!
                      : 'No description provided.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: DesignTokens.inkSoft(isDark),
                  ),
                ),
                // Status banner (dispute, booked reminder, etc.)
                if (_bannerContent(job, status, scheduledLabel) case (
                  final icon,
                  final color,
                  final message,
                )) ...[
                  const SizedBox(height: Space.s3),
                  FixoInfoBanner(icon: icon, color: color, message: message),
                ],
              ],
            ),
          ),

          // ── v1.7 P12-11: itemised completion summary (AwaitingConfirmation)
          if (status == 'AwaitingConfirmation') ...[
            const SizedBox(height: Space.s3),
            _CompletionSummaryCard(
              job: job,
              adjustments: _adjustments,
              isDark: isDark,
            ),
          ],

          // ── v1.7 P12-24: quote comparison for Project jobs still seeking
          // tradies — quotes live on their own comparison screen.
          if (job.isProject && (status == 'Requested' || status == 'Matching')) ...[
            const SizedBox(height: Space.s3),
            FixoTonalButton(
              key: const Key('compare_quotes_button'),
              icon: Icons.receipt_long_outlined,
              label: 'Compare quotes',
              fullWidth: true,
              onPressed: () => context.push('/jobs/${widget.jobId}/quotes'),
            ),
          ],

          // ── v1.7 P12-20: adjustments history (all statuses, always honest)
          const SizedBox(height: Space.s3),
          _AdjustmentsSection(
            adjustments: _adjustments,
            isDark: isDark,
            // Homeowner decisions only apply while the job is in flight.
            canRespond:
                status == 'Booked' ||
                status == 'InProgress' ||
                status == 'AwaitingConfirmation',
            onRespond: (adjustment) => _showAdjustmentDecisionSheet(adjustment),
          ),

          // ── Collapsible cancellation policy ───────────────────────────────
          if (canCancel) ...[
            const SizedBox(height: Space.s3),
            Material(
              color: DesignTokens.surfaceCard(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusTile),
                side: BorderSide(
                  color: isDark
                      ? DesignTokens.paperLineDark
                      : DesignTokens.paperLineLight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: const Key('cancellation_policy_tile'),
                title: Text(
                  'Cancellation policy',
                  style: theme.textTheme.titleSmall,
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: Space.s4),
                childrenPadding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
                children: [
                  Text(
                    _cancellationWarning(status),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],

          // ── P10-22: Materials disclaimer ──────────────────────────────────
          if (materialsDisclaimer != null &&
              materialsDisclaimer.isNotEmpty) ...[
            const SizedBox(height: Space.s3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.s3_5, vertical: Space.s3),
              decoration: BoxDecoration(
                color: DesignTokens.brand500.withValues(alpha: Alpha.faint),
                borderRadius: BorderRadius.circular(DesignTokens.radiusTile),
                border: Border.all(
                  color: DesignTokens.brand500.withValues(alpha: Alpha.border),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: Sizes.iconInfo,
                    color: DesignTokens.foregroundBrand(isDark),
                  ),
                  const SizedBox(width: Space.s2_5),
                  Expanded(
                    child: Text(
                      materialsDisclaimer,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeCaption,
                        height: 1.45,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Space.stickyBarClearance),
        ],
      ),
          ), // Expanded
        ],
      ), // Column body
      bottomNavigationBar: _buildActionBar(context, job),
    );
  }

  Widget? _buildActionBar(BuildContext context, Job job) {
    final status = job.status;
    final hasTradie =
        job.matchedTradieId != null && job.matchedTradieId!.isNotEmpty;
    final hasOpenDispute =
        job.disputeStatus == 'Open' || job.disputeStatus == 'UnderReview';
    switch (status) {
      case 'Requested':
        if (job.isProject) {
          return StickyActionBar(
            child: FixoPrimaryButton(
              key: const Key('view_quotes_button'),
              label: 'Compare quotes',
              onPressed: () => context.push('/jobs/${widget.jobId}/quotes'),
            ),
          );
        }
        return StickyActionBar(
          child: FixoPrimaryButton(
            key: const Key('view_matching_button'),
            label: 'View matching status',
            onPressed: () => context.push('/jobs/${widget.jobId}/matching'),
          ),
        );
      case 'AwaitingPayment':
        return StickyActionBar(
          child: FixoPrimaryButton(
            key: const Key('continue_payment_button'),
            label: 'Continue to payment',
            onPressed: () => context.push('/jobs/${widget.jobId}/payment'),
          ),
        );
      case 'PaymentReview':
        return StickyActionBar(
          child: FixoPrimaryButton(
            key: const Key('view_payment_status_button'),
            label: 'View payment status',
            onPressed: () =>
                context.push('/jobs/${widget.jobId}/payment/status'),
          ),
        );
      case 'AwaitingConfirmation':
        // v1.7 P12-11: itemised review & approve — the homeowner approves
        // the amount (POST /approve) then pays; nothing is confirmed while
        // a dispute is open or an adjustment is still pending (the server
        // 409s the approve and the message surfaces).
        final hasPendingAdjustments =
            _adjustments.any((a) => a.isPending);
        return StickyActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FixoPrimaryButton(
                key: const Key('approve_pay_button'),
                label: 'Approve & pay',
                isLoading: _approving || _busy,
                onPressed:
                    (hasOpenDispute || hasPendingAdjustments || _approving)
                        ? null
                        : _approveAndPay,
              ),
              if (hasPendingAdjustments) ...[
                const SizedBox(height: Space.s2),
                Text(
                  'An extra cost is waiting for your decision above — '
                  'approve or decline it first.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (hasOpenDispute) ...[
                const SizedBox(height: Space.s2),
                Text(
                  'The amount cannot be approved while a dispute is open.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: Space.s2),
              FixoGhostButton(
                key: const Key('dispute_amount_button'),
                label: 'Dispute amount',
                onPressed: _openDispute,
              ),
            ],
          ),
        );
      case 'Completed':
        if (_hasReview || !hasTradie) return null;
        return StickyActionBar(
          child: FixoPrimaryButton(
            key: const Key('leave_review_button'),
            label: 'Leave a Review',
            isLoading: false,
            onPressed: _leaveReview,
          ),
        );
      case 'Booked':
      case 'InProgress':
        if (!hasTradie) return null;
        return StickyActionBar(
          child: FixoPrimaryButton(
            key: const Key('open_chat_button'),
            label: 'Open Chat',
            onPressed: _openChat,
          ),
        );
      case 'Disputed':
        return StickyActionBar(
          child: FixoGhostButton(
            key: const Key('view_dispute_button'),
            label: 'View dispute',
            onPressed: _openDispute,
          ),
        );
      default:
        return null;
    }
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

/// Compact identity card for the matched tradie (V15-12).
///
/// Renders only fields the authorized public-profile contract returned —
/// never a fabricated name, rating, verification or insurance flag. When the
/// profile can't be loaded the card still offers the authorized profile and
/// chat actions without inventing identity.
class _MatchedTradieCard extends StatelessWidget {
  final UserProfile? profile;
  final String fallbackTrade;
  final bool canChat;
  final String? phoneNumber;
  final VoidCallback onChat;
  final VoidCallback onViewProfile;
  final ValueChanged<String>? onCall;

  const _MatchedTradieCard({
    required this.profile,
    required this.fallbackTrade,
    required this.canChat,
    this.phoneNumber,
    required this.onChat,
    required this.onViewProfile,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final p = profile;

    final name = p == null
        ? 'Your tradie'
        : p.fullName.trim().isEmpty
        ? 'Name unavailable'
        : p.fullName;
    final trade =
        (p?.tradeType?.isNotEmpty == true ? p!.tradeType! : fallbackTrade)
            .trim();

    // Build the secondary line: "Trade · 4.8 ★ (126)" — no "reviews" word.
    String? secondaryLine;
    if (trade.isNotEmpty) {
      if (p != null &&
          p.reviewCount != null &&
          p.reviewCount! > 0 &&
          p.averageRating != null &&
          p.averageRating! > 0 &&
          p.averageRating! <= 5) {
        secondaryLine =
            '$trade · ${p.averageRating!.toStringAsFixed(1)} \u2605 (${p.reviewCount})';
      } else if (p != null && p.reviewCount == 0) {
        secondaryLine = '$trade \u00b7 New to Fixo';
      } else {
        secondaryLine = trade;
      }
    } else if (p != null &&
        p.reviewCount != null &&
        p.reviewCount! > 0 &&
        p.averageRating != null &&
        p.averageRating! > 0 &&
        p.averageRating! <= 5) {
      secondaryLine =
          '${p.averageRating!.toStringAsFixed(1)} \u2605 (${p.reviewCount})';
    }

    final isVerified = p?.isVerified == true;
    final isNarrow = MediaQuery.sizeOf(context).width <= 340;
    final isLargeText = isNarrow ||
        MediaQuery.textScalerOf(context).scale(DesignTokens.fontSizeSecondary) > 17;

    final viewProfileButton = InkWell(
      onTap: onViewProfile,
      borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s1,
          vertical: Space.s0_5,
        ),
        child: Text(
          'View profile',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeCaption,
            fontWeight: FW.semibold,
            color: DesignTokens.foregroundBrand(isDark),
          ),
        ),
      ),
    );

    return FixoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with optional verified check badge overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FixoAvatar(initials: p == null ? '?' : p.initials, radius: Sizes.statusChip),
                  if (isVerified)
                    Positioned(
                      right: -Space.s0_5,
                      bottom: -Space.s0_5,
                      child: Container(
                        width: Sizes.iconSm,
                        height: Sizes.iconSm,
                        decoration: BoxDecoration(
                          color: DesignTokens.inkSuccess(isDark),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DesignTokens.surfaceCard(isDark),
                            width: Sizes.borderWidthThick,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: Sizes.dot,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: Space.s3),
              // Name + trade/rating line
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FW.bold,
                      ),
                    ),
                    if (secondaryLine != null)
                      Text(
                        secondaryLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (isLargeText) ...[
                      const SizedBox(height: Space.s1),
                      viewProfileButton,
                    ],
                  ],
                ),
              ),
              if (!isLargeText) viewProfileButton,
            ],
          ),
          if (isVerified || (p != null && p.hasInsurance == true)) ...[
            const SizedBox(height: Space.s2_5),
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: [
                if (isVerified)
                  FixoPillChip(
                    icon: Icons.check_circle_outline,
                    label: 'Verified',
                    color: DesignTokens.inkSuccess(isDark),
                    bordered: false,
                  ),
                if (p != null && p.hasInsurance == true)
                  FixoPillChip(
                    icon: Icons.shield_outlined,
                    label: 'Insured',
                    color: DesignTokens.foregroundBrand(isDark),
                    bordered: false,
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.s3),
          // Message + Call buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final phone = phoneNumber?.trim();
              final canCall = phone != null && phone.isNotEmpty;

              final buttons = [
                if (canChat)
                  FixoTonalButton(
                    key: const Key('tradie_card_chat_button'),
                    icon: Icons.chat_bubble_outline,
                    label: 'Message',
                    onPressed: onChat,
                  ),
                if (canCall)
                  FixoTonalButton(
                    key: const Key('tradie_card_call_button'),
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onPressed:
                        onCall != null ? () => onCall!(phone) : null,
                  ),
              ];

              if (buttons.isEmpty) return const SizedBox.shrink();

              // 2 buttons × ~100px minimum + 1 × 8px gap = 208px
              final useRow = constraints.maxWidth >= 208;
              if (useRow) {
                return Row(
                  children: [
                    for (int i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: Space.s2),
                      Expanded(child: buttons[i]),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(height: Space.s2),
                    buttons[i],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}



// ── P6-03: Cancel Job bottom sheet lives in views/widgets/cancel_job_sheet.dart ──

/// Friendly recovery screen shown when a job cannot be loaded (V16-02).
/// Replaces the bare "Job not found" text with a heading, subtext and two
/// actionable buttons so the user always has a path forward.
class _JobNotFoundBody extends StatelessWidget {
  final String heading;
  final VoidCallback onBack;
  final VoidCallback onSupport;

  const _JobNotFoundBody({
    required this.heading,
    required this.onBack,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s7, vertical: Space.s9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: Sizes.avatarLg,
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
            'This may have been cancelled or removed. '
            'Check your jobs list for the latest status.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBack,
              child: const Text('Back to my jobs'),
            ),
          ),
          const SizedBox(height: Space.s3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSupport,
              child: const Text('Contact support'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── v1.7 P12-11: itemised completion summary ─────────────────────────────────

/// Itemised summary shown at AwaitingConfirmation: labour + each approved
/// adjustment + the final total, against the original estimate. Renders only
/// server-supplied figures — a missing line stays missing.
class _CompletionSummaryCard extends StatelessWidget {
  final Job job;
  final List<JobAdjustment> adjustments;
  final bool isDark;

  const _CompletionSummaryCard({
    required this.job,
    required this.adjustments,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<THColors>()!;
    final approved =
        adjustments.where((a) => a.isApproved).toList();
    final hasBreakdown =
        job.labourAmount != null || approved.isNotEmpty;

    return FixoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completion summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FW.bold,
            ),
          ),
          const SizedBox(height: Space.s1),
          Text(
            'Review the final amount before approving — payment happens '
            'after you approve.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.s3),
          if (hasBreakdown) ...[
            if (job.finalHours != null)
              _SummaryLine(
                label:
                    'Labour · ${_hours(job.finalHours!)} × ${formatMoney(job.hourlyRate ?? Decimal.zero)}',
                value: formatMoneyOrDash(job.labourAmount),
              ),
            if (job.finalHours == null && job.labourAmount != null)
              _SummaryLine(label: 'Labour', value: formatMoney(job.labourAmount!)),
            for (final a in approved)
              _SummaryLine(
                label:
                    '${_kindLabel(a.kind)} — ${a.description.isEmpty ? 'extra cost' : a.description}',
                value: formatMoney(a.amount),
              ),
            const Divider(height: Space.s5, color: DesignTokens.paperLineLight),
          ],
          if (job.finalAmount != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total to approve',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FW.bold,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(job.finalAmount!),
                      style: TextStyle(
                        fontFamily: DesignTokens.fontBody,
                        fontSize: DesignTokens.fontSizeH2,
                        fontWeight: FW.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: DesignTokens.foreground(isDark),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (job.finalAmount == null)
            Text(
              'The final amount hasn\'t been calculated yet — check back '
              'shortly.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (job.estimatedTotal != null && job.finalAmount != null) ...[
            const SizedBox(height: Space.s2),
            Text(
              job.finalAmount! > job.estimatedTotal!
                  ? 'That\'s ${formatMoney(job.finalAmount! - job.estimatedTotal!)} '
                      'above the original estimate of '
                      '${formatMoney(job.estimatedTotal!)}.'
                  : 'That\'s ${formatMoney(job.estimatedTotal! - job.finalAmount!)} '
                      'under the original estimate of '
                      '${formatMoney(job.estimatedTotal!)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: job.finalAmount! > job.estimatedTotal!
                    ? colors.accentText
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (job.completionSubmittedAtUtc != null) ...[
            const SizedBox(height: Space.s2),
            Text(
              'Submitted ${DateFormat.MMMEd().add_jm().format(job.completionSubmittedAtUtc!.toLocal())}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: DesignTokens.fontSizeCaption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _hours(double hours) =>
      hours == hours.roundToDouble()
          ? hours.round().toString()
          : hours.toString();

  static String _kindLabel(String kind) => switch (kind) {
        JobAdjustment.kindMaterials => 'Materials',
        JobAdjustment.kindExtraLabour => 'Extra labour',
        JobAdjustment.kindTravel => 'Travel',
        _ => 'Other',
      };
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FW.semibold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── v1.7 P12-20: adjustments history ─────────────────────────────────────────

/// Every proposed extra cost with its status chip and the running total of
/// approved items. Pending proposals show the homeowner's Approve / Decline
/// action — the only decision path in v1.7 (D6: no auto-approval).
class _AdjustmentsSection extends StatelessWidget {
  final List<JobAdjustment> adjustments;
  final bool isDark;
  final bool canRespond;
  final ValueChanged<JobAdjustment> onRespond;

  const _AdjustmentsSection({
    required this.adjustments,
    required this.isDark,
    required this.canRespond,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<THColors>()!;

    if (adjustments.isEmpty) return const SizedBox.shrink();

    final approvedTotal = adjustments
        .where((a) => a.isApproved)
        .fold<Decimal>(Decimal.zero, (sum, a) => sum + a.amount);

    return FixoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adjustments',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FW.bold,
            ),
          ),
          const SizedBox(height: Space.s1),
          Text(
            'Extra costs your tradie asked for. Only approved items are '
            'added to the total.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.s3),
          for (final a in adjustments) ...[
            _AdjustmentRow(
              adjustment: a,
              canRespond: canRespond && a.isPending,
              onRespond: () => onRespond(a),
            ),
            const SizedBox(height: Space.s2),
          ],
          if (approvedTotal > Decimal.zero) ...[
            const Divider(height: Space.s4, color: DesignTokens.paperLineLight),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Approved extras so far',
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
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  final JobAdjustment adjustment;
  final bool canRespond;
  final VoidCallback onRespond;

  const _AdjustmentRow({
    required this.adjustment,
    required this.canRespond,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a = adjustment;
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
              _AdjustmentStatusChip(status: a.status),
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
            Text(
              a.description,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: Space.s0_5),
          Text(
            [
              a.kind,
              'asked ${DateFormat('d MMM').format(a.createdAtUtc.toLocal())}',
              if (a.evidenceUrl?.isNotEmpty == true) 'receipt attached',
              if (a.responseNote?.isNotEmpty == true)
                'note: ${a.responseNote}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeCaption,
            ),
          ),
          if (canRespond) ...[
            const SizedBox(height: Space.s2),
            Row(
              children: [
                Expanded(
                  child: FixoTonalButton(
                    key: Key('adjustment_decline_${a.id}'),
                    label: 'Decline',
                    onPressed: onRespond,
                  ),
                ),
                const SizedBox(width: Space.s2),
                Expanded(
                  child: FixoTonalButton(
                    key: Key('adjustment_approve_${a.id}'),
                    label: 'Approve',
                    onPressed: onRespond,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Small tinted chip mirroring the adjustment's server status.
class _AdjustmentStatusChip extends StatelessWidget {
  final String status;

  const _AdjustmentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (:tone, :label, :icon) = switch (status) {
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
          label: 'Waiting on you',
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
          label: status,
          icon: Icons.help_outline_rounded,
        ),
    };
    return StatusChip(label: label, tone: tone, icon: icon);
  }
}

/// Approve / Decline decision sheet (P12-20): what was asked, how much, the
/// receipt indicator and the running total vs estimate — then one explicit
/// Approve or Decline (+ optional note). No pre-approval (D6 cut).
class _AdjustmentDecisionSheet extends StatefulWidget {
  final JobAdjustment adjustment;
  final Decimal? estimatedTotal;
  final Decimal approvedAdjustmentsTotal;

  const _AdjustmentDecisionSheet({
    required this.adjustment,
    required this.estimatedTotal,
    required this.approvedAdjustmentsTotal,
  });

  @override
  State<_AdjustmentDecisionSheet> createState() =>
      _AdjustmentDecisionSheetState();
}

class _AdjustmentDecisionSheetState extends State<_AdjustmentDecisionSheet> {
  late final TextEditingController _noteController;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    Navigator.pop(
      context,
      (_approved, _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a = widget.adjustment;

    // Running total if this proposal were approved: what's already approved
    // plus this item. A truthful projection of server data only.
    final projected =
        widget.approvedAdjustmentsTotal + a.amount;

    return SafeArea(
      child: Padding(
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
              'Extra cost request',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FW.bold,
              ),
            ),
            const SizedBox(height: Space.s3),
            Text(
              a.description.isEmpty
                  ? a.kind
                  : a.description,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: Space.s1),
            Text(
              [
                a.kind,
                'asked by ${a.proposedByTradieName.isEmpty ? 'your tradie' : a.proposedByTradieName}',
                if (a.evidenceUrl?.isNotEmpty == true)
                  'receipt attached',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatMoney(a.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FW.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (widget.estimatedTotal != null) ...[
              const SizedBox(height: Space.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Running total vs estimate',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${formatMoney(projected)} · est. ${formatMoney(widget.estimatedTotal!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FW.semibold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: projected > widget.estimatedTotal!
                            ? theme.extension<THColors>()!.accentText
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.s4),
            TextField(
              controller: _noteController,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything the tradie should know…',
              ),
            ),
            const SizedBox(height: Space.s3),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.check_rounded),
                  label: Text('Approve'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.close_rounded),
                  label: Text('Decline'),
                ),
              ],
              selected: {_approved},
              onSelectionChanged: (selection) =>
                  setState(() => _approved = selection.first),
            ),
            const SizedBox(height: Space.s4),
            FixoPrimaryButton(
              key: const Key('adjustment_decision_submit'),
              label: _approved
                  ? 'Approve this extra cost'
                  : 'Decline this extra cost',
              onPressed: () => _submit(context),
            ),
            const SizedBox(height: Space.s2),
            Text(
              _approved
                  ? 'Approved extras are added to the job total — you\'ll '
                      'see them itemised before you pay.'
                  : 'Declined extras are never added to the total. Your '
                      'tradie can keep to the original scope or cancel '
                      'without penalty.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hours render without a trailing ".0" — 2.5 stays 2.5, 3 stays 3.
String _formatHours(double hours) =>
    hours == hours.roundToDouble()
        ? hours.round().toString()
        : hours.toString();
