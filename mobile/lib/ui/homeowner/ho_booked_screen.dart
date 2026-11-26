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
    final tradieName = bookedTradieName(job, widget.tradie);
    final firstName = tradieName.split(' ').first;
    final phone = widget.contact?.phoneNumber?.trim().isNotEmpty == true
        ? widget.contact!.phoneNumber!.trim()
        : null;
    final canChat = tradieId?.isNotEmpty == true;
    final estimate = bookedEstimate(job);
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: THScaffold(
        // The action always lives in the sticky bottom bar (never inline at
        // the end of the scroll): primary Message beside ghost Cancel job.
        // THStickyBar lays its children out side by side (and only stacks
        // them at large text scales), so each button is its own child.
        stickyBar: THStickyBar(
          children: [
            THButton(
              key: const Key('open_chat_button'),
              label: firstName.isEmpty ? 'Message' : 'Message $firstName',
              icon: Icons.chat_bubble_rounded,
              kind: THButtonKind.primary,
              onPressed: canChat ? () => context.push('/chat/${job.id}') : null,
            ),
            THButton(
              key: const Key('cancel_job_button'),
              label: 'Cancel job',
              kind: THButtonKind.ghost,
              onPressed: _busy ? null : _cancel,
            ),
          ],
        ),
        appBar: THAppBar(
          title: job.title,
          subtitle: 'Booked',
          actions: [
            Semantics(
              identifier: 'job_overflow_menu',
              child: PopupMenuButton<String>(
                key: const Key('job_overflow_menu'),
                enabled: !_busy,
                onSelected: (value) {
                  if (value == 'call' && phone != null) {
                    ref.read(externalLauncherProvider).callPhone(phone);
                  }
                  if (value == 'dispute') {
                    context.push('/jobs/${job.id}/dispute');
                  }
                  if (value == 'noshow') {
                    _reportNoShow();
                  }
                },
                itemBuilder: (context) => [
                  if (phone != null)
                    const PopupMenuItem(
                      value: 'call',
                      child: Text('Call tradie'),
                    ),
                  if (canReportNoShow)
                    const PopupMenuItem(
                      value: 'noshow',
                      child: Text('Report no-show'),
                    ),
                  const PopupMenuItem(
                    value: 'dispute',
                    child: Text('Open dispute'),
                  ),
                ],
              ),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: Space.s2,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          THText(
                            scheduled == null
                                ? 'Booked'
                                : 'Booked for $scheduled',
                            style: THTextStyle.title,
                          ),
                          THText(
                            tradieName.isEmpty
                                ? 'Your tradie will check in on arrival.'
                                : '$tradieName will check in on arrival.',
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
            if (tradieName.isNotEmpty)
              HoBookedTradieCard(
                name: tradieName,
                profile: widget.tradie,
                subtitle: job.hourlyRate != null
                    ? '${formatMoney(job.hourlyRate!)}/hr incl. GST · locked'
                    : null,
                onViewProfile: canChat
                    ? () => context.push('/tradie/$tradieId')
                    : null,
                onChat: () => context.push('/chat/${job.id}'),
              ),
            THCard(
              children: [
                THKeyValue('Service', job.category),
                THKeyValue(
                  'Address',
                  job.address?.isNotEmpty == true
                      ? job.address!
                      : 'Not provided',
                  divider: true,
                ),
                THKeyValue(
                  'Timing',
                  scheduled ?? bookedTimingLabel(job.timingPreference),
                  divider: true,
                ),
                THKeyValue(
                  'Estimate',
                  estimate != null
                      ? formatMoney(estimate)
                      : 'Confirmed on completion',
                  divider: true,
                ),
              ],
            ),
            THCard(
              children: [
                THTimeline(
                  items: [
                    THTimelineItem(
                      'Request accepted',
                      state: THTimelineState.done,
                      subtitle: tradieName.isEmpty ? null : tradieName,
                    ),
                    THTimelineItem(
                      'Booked',
                      state: THTimelineState.cur,
                      subtitle: scheduled,
                    ),
                    const THTimelineItem('Check-in on site'),
                    const THTimelineItem('Work complete and hours entered'),
                    const THTimelineItem('Approve final amount and pay'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
