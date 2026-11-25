// TrJobInProgressScreen: InProgress state view for tradie job detail (plan 5.3 PR C).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../network/external_launcher.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'tr_job_parts.dart';
import 'tr_job_providers.dart';
import 'tr_job_state.dart';

class TrJobInProgressScreen extends ConsumerStatefulWidget {
  const TrJobInProgressScreen({
    super.key,
    required this.job,
    required this.contact,
    required this.adjustments,
  });

  final Job job;
  final JobContact? contact;
  final List<JobAdjustment> adjustments;

  @override
  ConsumerState<TrJobInProgressScreen> createState() =>
      _TrJobInProgressScreenState();
}

class _TrJobInProgressScreenState extends ConsumerState<TrJobInProgressScreen> {
  bool _busy = false;

  Future<void> _checkOut() async {
    final approvedTotal = trApprovedAdjustmentsTotal(widget.adjustments);
    final hours = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TrCheckOutSheet(
        job: widget.job,
        approvedAdjustmentsTotal: approvedTotal,
      ),
    );
    if (hours == null || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final summary = await repo.checkOut(widget.job.id, finalHours: hours);
    if (!mounted) return;
    if (summary != null) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.job.id, 'AwaitingConfirmation');
      ref.invalidate(trJobDetailProvider(widget.job.id));
      if (mounted) showTrCheckOutSummaryDialog(context, summary);
    } else {
      THNotice.error(context, NoticeCopy.checkOutFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _navigate([MapApp? app]) async {
    final job = widget.job;
    final launched = await ref
        .read(externalLauncherProvider)
        .openMap(
          address: job.address ?? job.suburb,
          latitude: job.latitude,
          longitude: job.longitude,
          app: app,
        );
    if (!launched && mounted) {
      THNotice.warning(context, "Couldn't open a maps app on this device.");
    }
  }

  Future<void> _call(String phoneNumber) async {
    final launched = await ref
        .read(externalLauncherProvider)
        .callPhone(phoneNumber);
    if (!launched && mounted) {
      THNotice.warning(context, "Couldn't open the phone app on this device.");
    }
  }

  void _message() {
    context.push('/chat/${widget.job.id}');
  }

  void _openDispute() {
    context.push('/jobs/${widget.job.id}/dispute');
  }

  Future<void> _cancelJob() async {
    final result =
        await showModalBottomSheet<({String reasonCode, String? notes})>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const TrCancelJobSheet(),
        );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(jobsRepositoryProvider);
    final ok = await repo.cancelJobWithReason(
      widget.job.id,
      reasonCode: result.reasonCode,
      notes: result.notes,
    );
    if (!mounted) return;
    if (ok) {
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.job.id, 'Cancelled');
      ref.invalidate(trJobDetailProvider(widget.job.id));
      THNotice.success(context, NoticeCopy.jobCancelled);
    } else {
      THNotice.error(context, NoticeCopy.cancelFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _requestExtraCost() async {
    final proposal = await showModalBottomSheet<(String, Decimal, String)?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TrRequestExtraCostSheet(),
    );
    if (proposal == null || !mounted) return;
    final (kind, amount, description) = proposal;

    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .createAdjustment(
            widget.job.id,
            kind: kind,
            amount: amount,
            description: description,
          );
      ref.invalidate(trJobDetailProvider(widget.job.id));
      if (mounted) {
        THNotice.success(
          context,
          'Extra cost sent — you\'ll hear back as soon as the homeowner decides.',
        );
      }
    } on ProfileApiException catch (e) {
      if (mounted) THNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (mounted) {
        THNotice.error(
          context,
          'Could not send the extra cost request. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _withdrawAdjustment(JobAdjustment adjustment) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .withdrawAdjustment(widget.job.id, adjustment.id);
      ref.invalidate(trJobDetailProvider(widget.job.id));
      if (mounted) {
        THNotice.success(context, 'Extra cost withdrawn.');
      }
    } on ProfileApiException catch (e) {
      if (mounted) THNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (mounted) {
        THNotice.error(
          context,
          'Could not withdraw the request. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _page(ctx)),
  );

  Widget _page(BuildContext context) {
    final job = widget.job;
    final commissionPercent = Decimal.tryParse(
      '${ref.watch(localeConfigProvider).valueOrNull?['commissionPercent'] ?? ''}',
    );

    return THScaffold(
      key: ValueKey('tradie_job_${job.id}'),
      appBar: TrJobAppBar(
        job: job,
        busy: _busy,
        onCancel: _cancelJob,
        onReportNoShow: () {},
        onDispute: _openDispute,
      ),
      dock: const THDock(role: THDockRole.tradie, active: THDockTab.jobs),
      scrollable: true,
      stickyBar: THStickyBar(
        children: [
          THButton(
            key: const Key('check_out_button'),
            label: 'Check out',
            kind: THButtonKind.accent,
            icon: Icons.done_all_rounded,
            loading: _busy,
            onPressed: _busy ? null : _checkOut,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          // Step progress
          THCard(
            children: [
              const THProgress(steps: 5, done: 3, current: true),
              const SizedBox(height: Space.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s2,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        THText('In progress', style: THTextStyle.title),
                        THText(
                          'Tap Check out when work is finished.',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  const THBadge('In Progress', kind: THBadgeKind.ok),
                ],
              ),
              if (job.referenceCode?.isNotEmpty == true) ...[
                const SizedBox(height: Space.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TrJobCodeBadge(referenceCode: job.referenceCode!),
                ),
              ],
            ],
          ),

          // Urgency notice
          if (job.urgency != null &&
              (job.urgency == 'Emergency' || job.urgency == 'High'))
            Align(
              alignment: Alignment.centerLeft,
              child: THBadge(
                job.urgency!.toUpperCase(),
                kind: THBadgeKind.danger,
              ),
            ),

          // Contact card
          if (widget.contact != null)
            TrContactCard(
              contact: widget.contact!,
              address: trAddressLabel(job),
              onMessage: _message,
              onCall: _call,
            ),

          // Location
          TrLocationCard(job: job, onNavigate: _navigate),

          // Job details & money
          TrJobDetailsCard(job: job, commissionPercent: commissionPercent),

          // Extra costs
          TrAdjustmentsCard(
            adjustments: widget.adjustments,
            onRequestExtra: _requestExtraCost,
            onWithdraw: _withdrawAdjustment,
          ),

          // Timeline
          const THCard(
            padding: Space.s4,
            children: [
              THTimeline(
                items: [
                  THTimelineItem('Accepted', state: THTimelineState.done),
                  THTimelineItem('Booked', state: THTimelineState.done),
                  THTimelineItem('Check in', state: THTimelineState.cur),
                  THTimelineItem(
                    'Complete and enter hours',
                    state: THTimelineState.todo,
                  ),
                  THTimelineItem('Paid', state: THTimelineState.todo),
                ],
              ),
            ],
          ),

          // Help / dispute action
          Center(
            child: TextButton.icon(
              icon: Icon(
                Icons.help_outline_rounded,
                size: Sizes.iconSm,
                color: context.th.textSoft,
              ),
              label: Text(
                'Need help with this job?',
                style: TextStyle(color: context.th.textSoft, fontSize: 13.0),
              ),
              onPressed: () {
                if (trCanDispute(job.status)) {
                  _openDispute();
                } else if (trCanCancel(job.status) && !_busy) {
                  _cancelJob();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
