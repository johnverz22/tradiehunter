// Pure mapping for the v2 tradie Jobs tab (`tr_jobs`, migration plan 5.8).
//
// Ports the day grouping and status sets of views/jobs/jobs_list_screen.dart
// without importing them (lib/ui/** must not import v1). No Flutter widgets.
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';

/// Statuses that count as booked work in the tradie Jobs tab.
const Set<String> kTradieWorkStatuses = {
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
};

/// Statuses where the homeowner's payment is still in flight.
const Set<String> kTradieAwaitingPaymentStatuses = {
  'AwaitingPayment',
  'PaymentReview',
};

/// One local-day bucket of tradie jobs for the grouped list.
class TrDayGroup {
  const TrDayGroup(this.label, this.jobs);

  final String label;
  final List<Job> jobs;
}

/// Groups [jobs] by the local calendar day of `scheduledStartUtc`
/// (unscheduled jobs land in a trailing "Unscheduled" group). Labels are
/// Today / Tomorrow / Yesterday or a localized date. [newestFirst] orders days
/// descending for Done/All, ascending for Today/Upcoming.
List<TrDayGroup> trDayGroups(
  List<Job> jobs,
  DateTime now, {
  required bool newestFirst,
}) {
  DateTime dayKey(Job job) {
    final local = job.scheduledStartUtc!.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  final scheduled = jobs.where((j) => j.scheduledStartUtc != null).toList()
    ..sort((a, b) => a.scheduledStartUtc!.compareTo(b.scheduledStartUtc!));
  final unscheduled = jobs.where((j) => j.scheduledStartUtc == null).toList();

  final byDay = <DateTime, List<Job>>{};
  for (final job in scheduled) {
    byDay.putIfAbsent(dayKey(job), () => []).add(job);
  }
  final days = byDay.keys.toList()
    ..sort((a, b) => newestFirst ? b.compareTo(a) : a.compareTo(b));

  final today = DateTime(now.year, now.month, now.day);
  String labelFor(DateTime day) {
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE d MMM').format(day);
  }

  return [
    for (final day in days) TrDayGroup(labelFor(day), byDay[day]!),
    if (unscheduled.isNotEmpty) TrDayGroup('Unscheduled', unscheduled),
  ];
}
