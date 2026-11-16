import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';

/// The v1.7 (flowVersion 2) statuses that carry a trustworthy [Job.stage].
/// Anything outside this set is a state this client has never heard of —
/// the stage can't be trusted for it, so the legacy status mapping (which
/// falls through to chat) applies instead of guessing a destination.
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

/// Where tapping a homeowner's job card should go (P4-07 / P5-07).
///
/// v1.7 (contract #6): v2-flow jobs route by the server's own [Job.stage]
/// — the same field that drives the 6-step stepper — so the mapping can
/// never drift between the card tap and the status strip:
///   0 Requested → matching screen
///   1 Booked / 2 In progress → homeowner job detail
///   3 Review & approve → homeowner job detail (NEVER the payment screen —
///     the homeowner approves the itemised amount there and only then
///     follows "Approve & pay" into the payment flow)
///   4 Pay → payment flow (payment status screen when the receipt is
///     already under review)
///   5 Completed → homeowner job detail
/// Terminal and disputed states always land on the read-only detail screen
/// regardless of stage.
///
/// Legacy flowVersion-1 jobs keep the v1 pay-first behaviour: payment comes
/// before booking (AwaitingPayment/PaymentReview/Matched = pay first), so
/// the status-based mapping in [_openLegacy] is what those jobs keep using.
void openHomeownerJob(BuildContext context, Job job) {
  // Terminal and disputed states: show the homeowner job detail screen
  // (read-only banner + dispute/status affordances) — never payment or chat.
  if (job.status == 'Cancelled' ||
      job.status == 'Expired' ||
      job.status == 'Disputed') {
    context.push('/jobs/${job.id}/detail');
    return;
  }

  if (job.usesV2Flow && _v2KnownStatuses.contains(job.status)) {
    switch (job.stage) {
      // Requested / Matching still in flight: revisit the matching screen.
      case 0:
        context.push('/jobs/${job.id}/matching');
      // Booked → In progress → Review & approve → Completed: job detail.
      // Stage 3 is the review-&-approve step; payment is reached from the
      // "Approve & pay" action after POST /approve, not from a card tap.
      case 1:
      case 2:
      case 3:
      case 5:
        context.push('/jobs/${job.id}/detail');
      // Pay: the receipt picker is the primary action, except while staff
      // already hold a receipt — that shows the status screen instead.
      case 4:
        job.status == 'PaymentReview'
            ? context.push('/jobs/${job.id}/payment/status')
            : context.push('/jobs/${job.id}/payment');
      default:
        _openLegacy(context, job);
    }
    return;
  }

  _openLegacy(context, job);
}

/// flowVersion-1 (pay-first) mapping, also the fallback for jobs whose v2
/// stage is out of range or whose status is unknown to this client.
void _openLegacy(BuildContext context, Job job) {
  switch (job.status) {
    // In-flight match: revisit the matching progress screen.
    case 'Requested':
    case 'Matching':
      context.push('/jobs/${job.id}/matching');
    // Money is owed: the receipt picker is the primary action.
    case 'AwaitingPayment':
      context.push('/jobs/${job.id}/payment');
    // Receipt is with staff — read-only until they respond.
    case 'PaymentReview':
      context.push('/jobs/${job.id}/payment/status');
    // Execution lifecycle: show the homeowner job detail screen.
    case 'Booked':
    case 'InProgress':
    case 'AwaitingConfirmation':
    case 'Completed':
      context.push('/jobs/${job.id}/detail');
    default:
      // Matched and other legacy in-betweens: chat is the live counterpart.
      context.push('/chat/${job.id}');
  }
}
