import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'ho_extra_cost_parts.dart';
import 'ho_job_detail_providers.dart';

/// Shared InProgress detail. A pending adjustment is an optional section: the
/// job remains useful to the homeowner while work continues without extras.
class HoExtraCostScreen extends ConsumerStatefulWidget {
  const HoExtraCostScreen({
    super.key,
    required this.job,
    required this.adjustment,
    required this.tradie,
  });

  final Job job;
  final JobAdjustment? adjustment;
  final UserProfile? tradie;

  @override
  ConsumerState<HoExtraCostScreen> createState() => _HoExtraCostScreenState();
}

class _HoExtraCostScreenState extends ConsumerState<HoExtraCostScreen> {
  bool _busy = false;

  Future<void> _respond(bool approve) async {
    final adjustment = widget.adjustment;
    if (adjustment == null || _busy) return;
    final note = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ThScope(
        themeMode: ref.read(themeModeProvider),
        child: HoAdjustmentDecisionSheet(
          adjustment: adjustment,
          approve: approve,
          estimate: widget.job.estimatedTotal,
        ),
      ),
    );
    if (note == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .respondToAdjustment(
            widget.job.id,
            adjustment.id,
            approve: approve,
            note: note.isEmpty ? null : note,
          );
      ref.invalidate(hoJobDetailProvider(widget.job.id));
      if (mounted) {
        THNotice.success(
          context,
          approve
              ? 'Extra cost approved — it’s added to the job total.'
              : 'Extra cost declined.',
        );
      }
    } on ProfileApiException catch (error) {
      if (mounted) THNotice.errorDynamic(context, error.message);
    } catch (_) {
      if (mounted) {
        THNotice.error(
          context,
          'Could not record your decision. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final adjustment = widget.adjustment;
    final isBooked = job.status == 'Booked';
    final businessName = widget.tradie?.businessName?.trim();
    final subtitle = businessName?.isNotEmpty == true
        ? businessName
        : (widget.tradie?.fullName.isNotEmpty == true
              ? widget.tradie!.fullName
              : job.matchedTradieName);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          return THScaffold(
            appBar: THAppBar(
              title: job.title,
              subtitle: isBooked
                  ? 'Booked'
                  : subtitle == null || subtitle.isEmpty
                  ? 'Job in progress'
                  : 'In progress with $subtitle',
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
                                adjustment != null
                                    ? 'Review an extra cost'
                                    : isBooked
                                    ? 'Job is booked'
                                    : 'Work is under way',
                                style: THTextStyle.title,
                              ),
                              THText(
                                isBooked
                                    ? 'Your tradie is booked for this job.'
                                    : 'Your tradie is working on this job.',
                                style: THTextStyle.meta,
                                tone: THTone.soft,
                              ),
                            ],
                          ),
                        ),
                        THBadge(
                          isBooked ? 'Booked' : 'In progress',
                          kind: isBooked ? THBadgeKind.ok : THBadgeKind.accent,
                        ),
                      ],
                    ),
                  ],
                ),
                if (subtitle?.isNotEmpty == true)
                  HoTradieSummary(name: subtitle!, profile: widget.tradie),
                THCard(
                  children: [
                    THText('Job details', style: THTextStyle.title),
                    const SizedBox(height: Space.s2),
                    THKeyValue('Service', job.category),
                    if (job.address?.isNotEmpty == true)
                      THKeyValue('Address', job.address!),
                    THKeyValue('Estimated hours', _duration(job)),
                    if (job.hourlyRate != null)
                      THKeyValue(
                        'Hourly rate · incl. GST',
                        '${formatMoney(job.hourlyRate!)}/hr',
                      ),
                    if (job.estimatedTotal != null)
                      THKeyValue(
                        'Estimate · not a fixed total',
                        formatMoney(job.estimatedTotal!),
                      ),
                    if (job.description?.isNotEmpty == true) ...[
                      const SizedBox(height: Space.s2),
                      THText(job.description!, style: THTextStyle.body),
                    ],
                  ],
                ),
                if (adjustment != null)
                  HoPendingAdjustmentCard(
                    adjustment: adjustment,
                    busy: _busy,
                    onApprove: () => _respond(true),
                    onDecline: () => _respond(false),
                  ),
                if (adjustment == null)
                  THCard(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: Space.s2,
                        children: [
                          Icon(Icons.info_outline, color: c.textBrand),
                          Expanded(
                            child: THText(
                              'You’ll review the final hours and amount after the work is complete. Nothing is charged before you approve it.',
                              style: THTextStyle.body,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                THButton(
                  key: const Key('job_message_tradie'),
                  label: 'Message tradie',
                  kind: THButtonKind.primary,
                  onPressed: () => context.push('/chat/${job.id}'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _duration(Job job) {
  if (job.estimatedHours case final hours?) {
    final label = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toString();
    return '$label ${hours == 1 ? 'hour' : 'hours'}';
  }
  if (job.hours > 0) return '${job.hours} ${job.hours == 1 ? 'hour' : 'hours'}';
  return 'Not specified';
}
