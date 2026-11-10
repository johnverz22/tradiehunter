import 'dart:async';

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
import '../widgets/sticky_action_bar.dart';
import '../widgets/status_strip.dart';
import '../widgets/fixo_feedback.dart';
import '../../feedback/fixo_notice.dart';


/// Homeowner-side job detail screen (P5-07).
///
/// Shows contextual primary action per status:
/// – Booked / InProgress    → "Open Chat" (tradie is on the way / working)
/// – AwaitingConfirmation   → "Confirm Completion" button
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
  Job? _job;
  bool _hasReview = false;
  UserProfile? _tradieProfile;
  JobContact? _contact;
  StreamSubscription<JobStatusEvent>? _statusSub;

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
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
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

    setState(() {
      _job = job;
      _tradieProfile = tradie;
      _contact = contact;
      _hasReview = hasReview;
      _loading = false;
    });
  }

  Future<void> _confirmCompletion() async {
    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final ok = await repo.confirmCompletion(widget.jobId);
    if (!mounted) return;
    if (ok) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.jobId, 'Completed');
      await _load();
    } else {
      FixoNotice.error(context, 'Could not confirm completion. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
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

    final priceLabel = job.totalAmount != null
        ? formatMoney(job.totalAmount!)
        : null;

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
                // Scheduled / Duration grid
                JobInfoGrid(
                  tiles: [
                    JobInfoTile(
                      label: 'Scheduled',
                      value: scheduledLabel ?? 'Not set',
                      icon: Icons.calendar_today_outlined,
                    ),
                    JobInfoTile(
                      label: 'Duration',
                      value: '${job.hours} hour${job.hours != 1 ? 's' : ''}',
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
                // Total price row
                if (priceLabel != null) ...[
                  const SizedBox(height: Space.s2_5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: DesignTokens.inkSoft(isDark),
                          ),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            priceLabel,
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
        // Completion cannot be confirmed while a dispute is open (V16-02).
        if (hasOpenDispute) {
          return StickyActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FixoPrimaryButton(
                  key: const Key('confirm_completion_button'),
                  label: 'Confirm Completion',
                  onPressed: null, // semantically disabled
                ),
                const SizedBox(height: Space.s2),
                Text(
                  'Completion cannot be confirmed while a dispute is open.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }
        return StickyActionBar(
          child: FixoPrimaryButton(
            key: const Key('confirm_completion_button'),
            label: 'Confirm Completion',
            isLoading: _busy,
            onPressed: _busy ? null : _confirmCompletion,
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
