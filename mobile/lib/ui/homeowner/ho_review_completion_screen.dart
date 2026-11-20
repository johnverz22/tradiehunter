import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'ho_extra_cost_parts.dart' show HoAdjustmentDecisionSheet;
import 'ho_job_detail_providers.dart';
import 'ho_review_completion_parts.dart';

class HoReviewCompletionScreen extends ConsumerStatefulWidget {
  const HoReviewCompletionScreen({
    super.key,
    required this.job,
    required this.adjustments,
  });

  final Job job;
  final List<JobAdjustment> adjustments;

  @override
  ConsumerState<HoReviewCompletionScreen> createState() =>
      _HoReviewCompletionScreenState();
}

class _HoReviewCompletionScreenState
    extends ConsumerState<HoReviewCompletionScreen> {
  bool _busy = false;

  bool get _hasPendingAdjustment =>
      widget.adjustments.any((adjustment) => adjustment.isPending);

  JobAdjustment? get _pendingAdjustment => widget.adjustments
      .where((adjustment) => adjustment.isPending)
      .firstOrNull;

  Future<void> _respondToAdjustment(
    JobAdjustment adjustment,
    bool approve,
  ) async {
    if (_busy) return;
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
          approve ? 'Extra cost approved.' : 'Extra cost declined.',
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

  Future<void> _approve() async {
    if (_busy || _hasPendingAdjustment || _hasOpenDispute) return;
    setState(() => _busy = true);
    try {
      await ref.read(jobsRepositoryProvider).approveJob(widget.job.id);
      if (!mounted) return;
      ref
          .read(jobsViewModelProvider.notifier)
          .applyStatusUpdate(widget.job.id, 'AwaitingPayment');
      ref.invalidate(hoJobDetailProvider(widget.job.id));
      await context.push('/jobs/${widget.job.id}/payment');
    } on ProfileApiException catch (error) {
      if (mounted) THNotice.errorDynamic(context, error.message);
    } catch (_) {
      if (mounted) {
        THNotice.error(
          context,
          'Could not approve the amount. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _hasOpenDispute =>
      widget.job.status == 'Disputed' ||
      widget.job.disputeStatus == 'Open' ||
      widget.job.disputeStatus == 'UnderReview';

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: THScaffold(
      appBar: THAppBar(title: widget.job.title, subtitle: 'Review completion'),
      stickyBar: THStickyBar(
        children: [
          THButton(
            key: const Key('dispute_amount_button'),
            label: 'Dispute amount',
            kind: THButtonKind.secondary,
            onPressed: _busy
                ? null
                : () => context.push('/jobs/${widget.job.id}/dispute'),
          ),
          THButton(
            key: const Key('approve_pay_button'),
            label: 'Approve & pay',
            loading: _busy,
            kind: THButtonKind.accent,
            onPressed:
                _busy ||
                    _hasPendingAdjustment ||
                    _hasOpenDispute ||
                    widget.job.finalAmount == null
                ? null
                : _approve,
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THHero(
            children: [
              const THText(
                'FINAL AMOUNT',
                style: THTextStyle.label,
                tone: THTone.gold,
              ),
              const SizedBox(height: Space.s2),
              THText(
                widget.job.finalAmount == null
                    ? 'Not ready'
                    : formatMoney(widget.job.finalAmount!),
                style: THTextStyle.moneyLg,
                tone: THTone.onHero,
              ),
              const THText(
                'Payment happens after you approve.',
                style: THTextStyle.meta,
                tone: THTone.onHeroSoft,
              ),
            ],
          ),
          if (widget.job.isAboveEstimateTolerance)
            const THCard(
              tone: THCardTone.accent,
              children: [
                THText(
                  'The final total is higher than the original estimate. Check the breakdown before approving.',
                  style: THTextStyle.body,
                ),
              ],
            ),
          HoCompletionBreakdown(
            job: widget.job,
            adjustments: widget.adjustments,
          ),
          if (_hasPendingAdjustment)
            HoPendingCompletionAdjustment(
              adjustment: _pendingAdjustment!,
              busy: _busy,
              onApprove: () => _respondToAdjustment(_pendingAdjustment!, true),
              onDecline: () => _respondToAdjustment(_pendingAdjustment!, false),
            ),
          if (_hasOpenDispute)
            const THCard(
              tone: THCardTone.danger,
              children: [
                THText(
                  'The amount cannot be approved while a dispute is open.',
                  style: THTextStyle.body,
                ),
              ],
            ),
          if (widget.job.completionSubmittedAtUtc case final submitted?)
            THCard(
              children: [
                const THText('Completion submitted', style: THTextStyle.title),
                const SizedBox(height: Space.s1),
                THText(
                  DateFormat.MMMEd().add_jm().format(submitted.toLocal()),
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
