// Pure state rules for the v2 tradie job detail (plan 5.3, id `tr_job`).
//
// `trSelectJobView` is a total function over `Job.status`: every string,
// including ones the server may add later, lands on a view and never on a
// blank screen. The status sets are copied from
// views/tradie/tradie_job_detail_screen.dart (contactable set mirrors
// JobsController.GetJobContact; booked-or-later is the address-masking hint).
import 'package:decimal/decimal.dart';

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

/// Statuses a tradie is allowed to cancel.
const Set<String> trCancellableStatuses = {
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
};

/// Tradie-facing cancellation reason codes and labels.
const List<(String, String)> trTradieCancelReasons = [
  ('tradie_unavailable', 'I\'m no longer available'),
  ('emergency', 'Emergency situation'),
  ('scope_change_declined', 'Scope changed beyond agreed work'),
  ('tradie_issue', 'Personal / equipment issue'),
  ('homeowner_no_show', 'Homeowner is unresponsive / no show'),
];

bool trIsContactable(String status) => trContactableStatuses.contains(status);

bool trIsBookedOrLater(String status) =>
    trBookedOrLaterStatuses.contains(status);

bool trCanCancel(String status) => trCancellableStatuses.contains(status);

bool trCanDispute(String status) =>
    status != 'Requested' && status != 'Cancelled';

bool trCanRequestExtraCost(String status) =>
    status == 'Booked' ||
    status == 'InProgress' ||
    status == 'AwaitingConfirmation';

bool trCanReportNoShow(Job job, [DateTime? now]) {
  if (job.status != 'Booked' || job.scheduledStartUtc == null) return false;
  final current = (now ?? DateTime.now()).toUtc();
  return current.isAfter(
    job.scheduledStartUtc!.add(const Duration(minutes: 15)),
  );
}

Decimal trApprovedAdjustmentsTotal(List<JobAdjustment> adjustments) {
  var total = Decimal.zero;
  for (final a in adjustments) {
    if (a.isApproved) total += a.amount;
  }
  return total;
}

Decimal trLabourPreview(Decimal rate, double hours) {
  final hoursDecimal =
      Decimal.tryParse(hours.toStringAsFixed(2)) ?? Decimal.zero;
  return rate * hoursDecimal;
}

String trAddressLabel(Job job) {
  final showFull = trIsBookedOrLater(job.status);
  if (showFull) return job.address ?? job.suburb;
  return job.suburb.isNotEmpty ? job.suburb : 'Suburb on file';
}

String trFormatHours(double hours) => hours == hours.roundToDouble()
    ? hours.toInt().toString()
    : hours.toString();

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
