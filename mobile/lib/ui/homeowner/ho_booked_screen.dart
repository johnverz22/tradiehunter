import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../network/external_launcher.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../../utils/money.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'ho_booked_parts.dart';
import 'ho_job_detail_providers.dart';

class HoBookedScreen extends ConsumerStatefulWidget {
  const HoBookedScreen({
    super.key,
    required this.job,
    required this.tradie,
    required this.contact,
  });

  final Job job;
  final UserProfile? tradie;
  final JobContact? contact;

  @override
  ConsumerState<HoBookedScreen> createState() => _HoBookedScreenState();
}

class _HoBookedScreenState extends ConsumerState<HoBookedScreen> {
  bool _busy = false;

  Future<void> _cancel() async {
    final result = await showModalBottomSheet<({String reason, String? notes})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ThScope(
        themeMode: ref.read(themeModeProvider),
        child: const HoCancelJobSheet(),
      ),
    );
    if (result == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(jobsRepositoryProvider)
          .cancelJobWithReason(
            widget.job.id,
            reasonCode: result.reason,
            notes: result.notes,
          );
      if (!mounted) return;
      if (ok) {
        ref
            .read(jobsViewModelProvider.notifier)
            .applyStatusUpdate(widget.job.id, 'Cancelled');
        ref.invalidate(hoJobDetailProvider(widget.job.id));
        THNotice.success(context, 'Job cancelled.');
      } else {
        THNotice.error(context, 'Could not cancel this job. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        THNotice.error(context, 'Could not cancel this job. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportNoShow() async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report no-show'),
        content: const Text(
          'The tradie hasn’t arrived. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'reassign'),
            child: const Text('Reassign'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel & refund'),
          ),
        ],
      ),
    );
    if (action == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(jobsRepositoryProvider)
          .reportNoShow(widget.job.id, action: action);
      if (!mounted) return;
      if (ok) {
        ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();
        ref.invalidate(hoJobDetailProvider(widget.job.id));
        THNotice.success(context, 'No-show reported.');
      } else {
        THNotice.error(
          context,
          'Could not report the no-show. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        THNotice.error(
          context,
          'Could not report the no-show. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final tradieId = job.matchedTradieId;
    final canReportNoShow =
        job.scheduledStartUtc != null &&
        DateTime.now().toUtc().isAfter(
          job.scheduledStartUtc!.add(const Duration(minutes: 15)),
        );
    final scheduled = job.scheduledStartUtc == null
        ? null
        : DateFormat.MMMEd().add_jm().format(job.scheduledStartUtc!.toLocal());
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: THScaffold(
        appBar: THAppBar(
          title: job.title,
          subtitle: 'Booked',
          actions: [
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (value) {
                if (value == 'cancel') _cancel();
                if (value == 'dispute') context.push('/jobs/${job.id}/dispute');
                if (value == 'noshow') _reportNoShow();
              },
              itemBuilder: (context) => [
                if (canReportNoShow)
                  const PopupMenuItem(
                    value: 'noshow',
                    child: Text('Report no-show'),
                  ),
                const PopupMenuItem(
                  value: 'dispute',
                  child: Text('Open dispute'),
                ),
                const PopupMenuItem(value: 'cancel', child: Text('Cancel job')),
              ],
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
            THCard(
              children: [
                THProgress(steps: 5, done: 2, current: true),
                const SizedBox(height: Space.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.s2,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: Space.s1,
                        children: [
                          THText(
                            scheduled == null
                                ? 'Booked'
                                : 'Booked for $scheduled',
                            style: THTextStyle.title,
                          ),
                          const THText(
                            'Your tradie will check in on arrival.',
                            style: THTextStyle.meta,
                            tone: THTone.soft,
                          ),
                        ],
                      ),
                    ),
                    const THBadge('Booked', kind: THBadgeKind.ok),
                  ],
                ),
              ],
            ),
            if (bookedTradieName(job, widget.tradie).isNotEmpty)
              HoBookedTradieCard(
                name: bookedTradieName(job, widget.tradie),
                profile: widget.tradie,
                canViewProfile: tradieId?.isNotEmpty == true,
                onViewProfile: tradieId?.isNotEmpty == true
                    ? () => context.push('/tradie/$tradieId')
                    : null,
                onChat: () => context.push('/chat/${job.id}'),
                onCall: widget.contact?.phoneNumber?.trim().isNotEmpty == true
                    ? () => ref
                          .read(externalLauncherProvider)
                          .callPhone(widget.contact!.phoneNumber!.trim())
                    : null,
              ),
            THCard(
              children: [
                const THText('Job details', style: THTextStyle.title),
                const SizedBox(height: Space.s2),
                THKeyValue('Service', job.category),
                THKeyValue(
                  'Address',
                  job.address?.isNotEmpty == true
                      ? job.address!
                      : 'Not provided',
                ),
                THKeyValue(
                  'Timing',
                  scheduled ?? bookedTimingLabel(job.timingPreference),
                ),
                THKeyValue('Duration', bookedDurationLabel(job)),
                if (job.hourlyRate != null)
                  THKeyValue(
                    'Rate · incl. GST',
                    '${formatMoney(job.hourlyRate!)}/hr',
                  ),
                if (bookedEstimate(job) case final estimate?)
                  THKeyValue('Estimated total', formatMoney(estimate))
                else
                  const THKeyValue('Total', 'Confirmed on completion'),
                if (job.description?.isNotEmpty == true) ...[
                  const SizedBox(height: Space.s2),
                  THText(job.description!, style: THTextStyle.body),
                ],
              ],
            ),
            THCard(
              children: [
                const THText('Job timeline', style: THTextStyle.title),
                const SizedBox(height: Space.s2),
                const HoJobTimelineRow('Request accepted', done: true),
                HoJobTimelineRow(
                  scheduled == null ? 'Booked' : 'Booked · $scheduled',
                  current: true,
                ),
                const HoJobTimelineRow('Check-in on site'),
                const HoJobTimelineRow('Work complete and hours entered'),
                const HoJobTimelineRow('Approve final amount and pay'),
              ],
            ),
            ExpansionTile(
              key: const Key('cancellation_policy_tile'),
              title: const THText(
                'Cancellation policy',
                style: THTextStyle.title,
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: Space.s4),
              childrenPadding: const EdgeInsets.fromLTRB(
                Space.s4,
                0,
                Space.s4,
                Space.s4,
              ),
              children: [
                const THText(bookedCancellationNotice, style: THTextStyle.body),
              ],
            ),
            THButton(
              key: const Key('open_chat_button'),
              label: 'Open Chat',
              icon: Icons.chat_bubble_outline,
              kind: THButtonKind.primary,
              onPressed: tradieId?.isNotEmpty == true
                  ? () => context.push('/chat/${job.id}')
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
