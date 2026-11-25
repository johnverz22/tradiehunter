// Pure state rules for the v2 tradie job detail (plan 5.3, id `tr_job`).
//
// `trSelectJobView` is a total function over `Job.status`: every string,
// including ones the server may add later, lands on a view and never on a
// blank screen. The status sets are copied from
// views/tradie/tradie_job_detail_screen.dart (contactable set mirrors
// JobsController.GetJobContact; booked-or-later is the address-masking hint).
import '../../models/marketplace.dart';

/// Which v2 state widget a job renders as.
enum TrJobView {
  booked,
  inProgress,
  awaitingConfirmation,
  completed,
  cancelled,
  disputed,

  /// Unknown / not-yet-designed status: a plain job detail with the status
  /// badge. Also what PR A injects the v1 screen for.
  fallback,
}

/// Statuses where the server exposes the homeowner's contact (V15-15).
const Set<String> trContactableStatuses = {
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
  'Completed',
  'Disputed',
};

/// Statuses where the exact address is shown (display hint only; the backend
/// enforces the masking).
const Set<String> trBookedOrLaterStatuses = {
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
  'Completed',
};

bool trIsContactable(String status) => trContactableStatuses.contains(status);

bool trIsBookedOrLater(String status) =>
    trBookedOrLaterStatuses.contains(status);

/// An open dispute wins over the booking state it was raised on, except for a
/// finished job (same precedence as the homeowner selector).
bool trHasOpenDispute(Job job) =>
    job.status == 'Disputed' ||
    job.disputeStatus == 'Open' ||
    job.disputeStatus == 'UnderReview';

TrJobView trSelectJobView(Job job) {
  if (job.status == 'Completed') return TrJobView.completed;
  if (job.status == 'Cancelled') return TrJobView.cancelled;
  if (trHasOpenDispute(job)) return TrJobView.disputed;
  return switch (job.status) {
    'AwaitingConfirmation' => TrJobView.awaitingConfirmation,
    'InProgress' => TrJobView.inProgress,
    'Booked' => TrJobView.booked,
    _ => TrJobView.fallback,
  };
}
