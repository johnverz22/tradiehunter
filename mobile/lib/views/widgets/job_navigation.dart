import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';

/// Where tapping a homeowner's job card should go (P4-07 / P5-07).
///
/// Routing priority (highest to lowest):
/// 1. AwaitingPayment / PaymentReview → payment flow
/// 2. Booked / InProgress / AwaitingConfirmation / Completed → homeowner job detail
///    (shows confirm-completion, stepper, leave-review prompt)
/// 3. Terminal / disputed states → read-only job detail — never a chat
///    that has no live counterpart
/// 4. Everything else → chat (Matched, legacy paths)
void openHomeownerJob(BuildContext context, Job job) {
  switch (job.status) {
    // In-flight match: revisit the matching progress screen.
    case 'Requested':
      context.push('/jobs/${job.id}/matching');
    // Money is owed: the receipt picker is the primary action.
    case 'AwaitingPayment':
      context.push('/jobs/${job.id}/payment');
    // Receipt is with staff — read-only until they respond.
    case 'PaymentReview':
      context.push('/jobs/${job.id}/payment/status');
    // Execution lifecycle and terminal/disputed states: show the homeowner
    // job detail screen (read-only banner + dispute/status affordances).
    case 'Booked':
    case 'InProgress':
    case 'AwaitingConfirmation':
    case 'Completed':
    case 'Cancelled':
    case 'Expired':
    case 'Disputed':
      context.push('/jobs/${job.id}/detail');
    default:
      context.push('/chat/${job.id}');
  }
}
