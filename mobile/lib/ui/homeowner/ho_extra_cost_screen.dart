import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
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
        child: _AdjustmentDecisionSheet(
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
              subtitle: subtitle == null || subtitle.isEmpty
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
                                adjustment == null
                                    ? 'Work is under way'
                                    : 'Review an extra cost',
                                style: THTextStyle.title,
                              ),
                              const THText(
                                'Your tradie is working on this job.',
                                style: THTextStyle.meta,
                                tone: THTone.soft,
                              ),
                            ],
                          ),
                        ),
                        const THBadge('In progress', kind: THBadgeKind.accent),
                      ],
                    ),
                  ],
                ),
                if (subtitle?.isNotEmpty == true)
                  _TradieSummary(name: subtitle!, profile: widget.tradie),
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
                  _PendingAdjustmentCard(
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

class _TradieSummary extends StatelessWidget {
  const _TradieSummary({required this.name, required this.profile});

  final String name;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) => THCard(
    children: [
      Row(
        spacing: Space.s3,
        children: [
          if (profile != null) THAvatar(profile!.initials),
          Expanded(child: THText(name, style: THTextStyle.title)),
        ],
      ),
      if (profile?.isVerified == true || profile?.hasInsurance == true) ...[
        const SizedBox(height: Space.s2),
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          children: [
            if (profile?.isVerified == true)
              const THBadge('Verified', kind: THBadgeKind.ok),
            if (profile?.hasInsurance == true)
              const THBadge('Insured', kind: THBadgeKind.ok),
          ],
        ),
      ],
    ],
  );
}

class _PendingAdjustmentCard extends StatelessWidget {
  const _PendingAdjustmentCard({
    required this.adjustment,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final JobAdjustment adjustment;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => THCard(
    tone: THCardTone.accent,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: Space.s2,
        children: [
          const Expanded(
            child: THBadge('Extra cost request', kind: THBadgeKind.accent),
          ),
          if (adjustment.expiresAtUtc != null)
            THText(
              'Expires ${MaterialLocalizations.of(context).formatShortDate(adjustment.expiresAtUtc!.toLocal())}',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
        ],
      ),
      const SizedBox(height: Space.s3),
      THText(formatMoney(adjustment.amount), style: THTextStyle.moneyLg),
      THText(
        'Incl. GST · ${adjustment.kind}',
        style: THTextStyle.meta,
        tone: THTone.soft,
      ),
      const SizedBox(height: Space.s2),
      THText(
        adjustment.description.isEmpty
            ? 'No description provided.'
            : adjustment.description,
        style: THTextStyle.body,
      ),
      if (adjustment.evidenceUrl?.isNotEmpty == true) ...[
        const SizedBox(height: Space.s2),
        THText('A receipt or photo is attached.', style: THTextStyle.meta),
      ],
      const SizedBox(height: Space.s3),
      Row(
        spacing: Space.s2,
        children: [
          Expanded(
            child: THButton(
              label: 'Decline',
              kind: THButtonKind.secondary,
              size: THButtonSize.sm,
              onPressed: busy ? null : onDecline,
            ),
          ),
          Expanded(
            child: THButton(
              label: busy ? 'Saving…' : 'Approve',
              kind: THButtonKind.primary,
              size: THButtonSize.sm,
              onPressed: busy ? null : onApprove,
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.s2),
      const THText(
        'Nothing is billed until you approve it. Approved extras are recorded against the job.',
        style: THTextStyle.meta,
        tone: THTone.soft,
      ),
    ],
  );
}

class _AdjustmentDecisionSheet extends StatefulWidget {
  const _AdjustmentDecisionSheet({
    required this.adjustment,
    required this.approve,
    required this.estimate,
  });

  final JobAdjustment adjustment;
  final bool approve;
  final Decimal? estimate;

  @override
  State<_AdjustmentDecisionSheet> createState() =>
      _AdjustmentDecisionSheetState();
}

class _AdjustmentDecisionSheetState extends State<_AdjustmentDecisionSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.adjustment;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Sizes.gutter,
          Space.s5,
          Sizes.gutter,
          MediaQuery.viewInsetsOf(context).bottom + Space.s5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.s3,
            children: [
              THText('Extra cost request', style: THTextStyle.h2),
              THText(
                a.description.isEmpty ? a.kind : a.description,
                style: THTextStyle.body,
              ),
              THKeyValue('Amount · incl. GST', formatMoney(a.amount)),
              if (a.evidenceUrl?.isNotEmpty == true)
                const THText(
                  'A receipt or photo is attached.',
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
              if (widget.estimate != null)
                THKeyValue(
                  'Estimate before this request',
                  formatMoney(widget.estimate!),
                ),
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              THButton(
                label: widget.approve
                    ? 'Approve this extra cost'
                    : 'Decline this extra cost',
                kind: widget.approve
                    ? THButtonKind.primary
                    : THButtonKind.secondary,
                onPressed: () =>
                    Navigator.pop(context, _noteController.text.trim()),
              ),
              THText(
                widget.approve
                    ? 'This approval adds the request to the job total. You’ll review the final amount before payment.'
                    : 'A declined extra is not added to the job total.',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
