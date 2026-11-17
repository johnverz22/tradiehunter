import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_job_detail_state.dart';

/// Composed v2 detail states without a dedicated design frame.
class HoJobDetailFallbackScreen extends StatelessWidget {
  const HoJobDetailFallbackScreen({
    super.key,
    required this.job,
    required this.reason,
  });

  final Job job;
  final HoJobDetailFallback reason;

  @override
  Widget build(BuildContext context) {
    final cancelled = reason == HoJobDetailFallback.cancelled;
    final disputed = reason == HoJobDetailFallback.dispute;
    final primary = switch (job.status) {
      'Requested' =>
        job.isProject
            ? ('Compare quotes', '/jobs/${job.id}/quotes')
            : ('View matching status', '/jobs/${job.id}/matching'),
      'Matching' => ('View matching status', '/jobs/${job.id}/matching'),
      'AwaitingPayment' => ('Continue to payment', '/jobs/${job.id}/payment'),
      'PaymentReview' => (
        'View payment status',
        '/jobs/${job.id}/payment/status',
      ),
      _ => ('Back to jobs', '/jobs'),
    };
    final title = switch (job.status) {
      'Requested' => 'Your request is being matched',
      'Matching' => 'Finding your tradie',
      'AwaitingPayment' => 'Payment is due',
      'PaymentReview' => 'Payment is under review',
      'Expired' => 'This request has expired',
      _ => 'Status unavailable',
    };
    final message = switch (job.status) {
      'Requested' || 'Matching' =>
        'Your job details are still available while we find the right tradie.',
      'AwaitingPayment' =>
        'Continue to the existing payment flow to complete this job.',
      'PaymentReview' =>
        'Your payment receipt is being reviewed. Open its status for updates.',
      'Expired' => 'This request is no longer active.',
      _ => 'Return to your jobs list to see the latest status.',
    };
    return THScaffold(
      appBar: THAppBar(
        title: job.title,
        subtitle: cancelled
            ? 'Cancelled'
            : disputed
            ? 'Dispute under review'
            : job.status,
      ),
      stickyBar: THStickyBar(
        children: [
          if (disputed)
            THButton(
              key: const Key('view_dispute_button'),
              label: 'View dispute',
              kind: THButtonKind.secondary,
              onPressed: () => context.push('/jobs/${job.id}/dispute'),
            ),
          THButton(
            key: primary.$2 == '/jobs'
                ? const Key('back_to_jobs_button')
                : null,
            label: cancelled || disputed ? 'Back to jobs' : primary.$1,
            kind: THButtonKind.accent,
            onPressed: () => primary.$2 == '/jobs'
                ? context.go('/jobs')
                : context.push(primary.$2),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THCard(
            tone: disputed ? THCardTone.danger : THCardTone.defaultTone,
            children: [
              THText(
                cancelled
                    ? 'This job was cancelled'
                    : disputed
                    ? 'This job has an active dispute'
                    : title,
                style: THTextStyle.title,
              ),
              const SizedBox(height: Space.s2),
              THText(
                cancelled
                    ? 'The job is no longer active.'
                    : disputed
                    ? 'Payment and job confirmation remain paused while the dispute is reviewed.'
                    : message,
                style: THTextStyle.body,
                tone: THTone.soft,
              ),
            ],
          ),
          THCard(
            children: [
              const THText('Job details', style: THTextStyle.title),
              const SizedBox(height: Space.s2),
              THKeyValue('Service', job.category),
              if (job.address?.trim().isNotEmpty == true)
                THKeyValue('Address', job.address!.trim()),
              if (job.suburb.isNotEmpty) THKeyValue('Area', job.suburb),
              if (job.referenceCode?.isNotEmpty == true)
                THKeyValue('Reference', job.referenceCode!),
            ],
          ),
        ],
      ),
    );
  }
}
