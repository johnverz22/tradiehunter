// v2 copy of views/widgets/job_navigation.dart `openHomeownerJob`
// (lib/ui/** cannot import v1). Routes are unchanged (plan 4.4): same paths,
// same stage/status mapping. Remove the v1 original in Phase 6.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';

const _v2KnownStatuses = {
  'Requested',
  'Matching',
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
  'AwaitingPayment',
  'PaymentReview',
  'Completed',
};

/// Path a homeowner job card should open (pure, so it can be tested).
String thHomeownerJobPath(Job job) {
  if (job.status == 'Cancelled' ||
      job.status == 'Expired' ||
      job.status == 'Disputed') {
    return '/jobs/${job.id}/detail';
  }
  // Plan 10 (D4 / Q7.9): an open-board project or one with quote requests
  // opens the quotes screen; invite-only with 0 requests opens the tradie
  // picker. Without counts (older server) fall through to the existing mapping.
  if (job.isProject && job.status == 'Requested') {
    if (job.openToBoard || job.quotesCloseAtUtc != null) {
      return '/jobs/${job.id}/quotes';
    }
    final requested = job.quotesRequested;
    if (requested != null) {
      return requested > 0
          ? '/jobs/${job.id}/quotes'
          : '/jobs/${job.id}/tradies';
    }
  }
  if (job.usesV2Flow && _v2KnownStatuses.contains(job.status)) {
    switch (job.stage) {
      case 0:
        return '/jobs/${job.id}/matching';
      case 1:
      case 2:
      case 3:
      case 5:
        return '/jobs/${job.id}/detail';
      case 4:
        return job.status == 'PaymentReview'
            ? '/jobs/${job.id}/payment/status'
            : '/jobs/${job.id}/payment';
    }
  }
  return _legacyPath(job);
}

String _legacyPath(Job job) => switch (job.status) {
  'Requested' || 'Matching' => '/jobs/${job.id}/matching',
  'AwaitingPayment' => '/jobs/${job.id}/payment',
  'PaymentReview' => '/jobs/${job.id}/payment/status',
  'Booked' ||
  'InProgress' ||
  'AwaitingConfirmation' ||
  'Completed' => '/jobs/${job.id}/detail',
  _ => '/chat/${job.id}',
};

void thOpenHomeownerJob(BuildContext context, Job job) =>
    context.push(thHomeownerJobPath(job));
