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
import '../widgets/job_info_grid.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/status_strip.dart';
import '../widgets/fixo_feedback.dart';


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
  StreamSubscription<JobStatusEvent>? _statusSub;

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
    setState(() {
      _job = job;
      _contact = contact;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t open a maps app on this device.'),
        ),
      );
    }
  }

  Future<void> _call(String phoneNumber) async {
    final launched = await ref
        .read(externalLauncherProvider)
        .callPhone(phoneNumber);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t open the phone app on this device.'),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in failed. Please try again.')),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _checkOut() async {
    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final ok = await repo.checkOut(widget.jobId);
    if (!mounted) return;
    if (ok) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.jobId, 'AwaitingConfirmation');
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out failed. Please try again.')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your review has been submitted. It will be visible once the other party also reviews, or after 7 days.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.tile)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Job cancelled. We\'ll find the homeowner a new tradie.',
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel the job. Please try again.'),
        ),
      );
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
              style: TextStyle(color: Theme.of(context).extension<THColors>()!.danger),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No-show reported successfully.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not report no-show.')),
        );
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
    final total = job.totalAmount;
    final grossLabel = total != null ? formatMoney(total) : null;
    final commissionPercent = Decimal.tryParse(
      '${ref.watch(localeConfigProvider).valueOrNull?['commissionPercent'] ?? ''}',
    );
    final net = payoutNetAmount(total, commissionPercent);

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
                const SizedBox(height: Space.s3),
                JobInfoTile(
                  icon: showFullAddress
                      ? Icons.location_on
                      : Icons.location_on_outlined,
                  label:
                      showFullAddress ? 'Full Address' : 'Approximate Location',
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
                      label: 'Job total',
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
                ],
                const SizedBox(height: Space.s4),
                Text('Job Description', style: theme.textTheme.titleSmall),
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
            padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
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
