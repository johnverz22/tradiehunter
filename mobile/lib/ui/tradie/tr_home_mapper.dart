// Pure mapping for the v2 tradie home (`tr_home`, migration plan 5.1 #1).
//
// Ports the grouping / sorting rules of views/tradie/tradie_dashboard_view.dart
// without importing them (lib/ui/** must not import v1). No Flutter widgets here,
// so every rule is unit-testable.
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/profile_viewmodel.dart' show TradieEarningsState;
import '../design/th_widgets.dart' show THBadgeKind;

/// Statuses that count as booked work for the tradie.
const Set<String> kBookedWorkStatuses = {
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
};

/// Matched but not yet confirmed — the homeowner's payment is still in flight.
const Set<String> kAwaitingPaymentStatuses = {
  'AwaitingPayment',
  'PaymentReview',
};

/// True when [job]'s scheduled start is strictly today (local date == today).
bool thIsScheduledToday(Job job, DateTime now) {
  final scheduled = job.scheduledStartUtc;
  if (scheduled == null) return true; // no schedule -> show in today
  final local = scheduled.toLocal();
  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

/// True when [job] is overdue: Booked/InProgress/AwaitingConfirmation with a
/// scheduled start strictly before the start of today.
bool thIsOverdue(Job job, DateTime now) {
  final scheduled = job.scheduledStartUtc;
  if (scheduled == null) return false;
  final startOfToday = DateTime(now.year, now.month, now.day);
  return scheduled.toLocal().isBefore(startOfToday);
}

/// True when [job] is scheduled on or before the end of today (today +
/// overdue; unscheduled counts as today). Port of v1
/// `isScheduledOnOrBeforeToday` (tradie_dashboard_view.dart) for the Jobs
/// tab "Today" filter, which shows everything due today or earlier.
bool thIsScheduledOnOrBeforeToday(Job job, DateTime now) {
  final scheduled = job.scheduledStartUtc;
  if (scheduled == null) return true;
  final endOfToday = DateTime(now.year, now.month, now.day + 1);
  return scheduled.toLocal().isBefore(endOfToday);
}

/// True when [job] requires immediate tradie action.
bool thIsTradieActionRequired(String status) => switch (status) {
  'Booked' || 'InProgress' || 'AwaitingConfirmation' => true,
  _ => false,
};

/// Tradie dashboard jobs grouped by urgency / timeline.
class TrHomeGroups {
  const TrHomeGroups({
    required this.leads,
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.awaitingPayment,
    required this.disputed,
  });

  final List<Job> leads;
  final List<Job> overdue;
  final List<Job> today;
  final List<Job> upcoming;
  final List<Job> awaitingPayment;
  final List<Job> disputed;

  factory TrHomeGroups.from(List<Job> jobs, DateTime now) {
    final leads = jobs.where((j) => j.status == 'Requested').toList();

    // Overdue: booked jobs whose schedule is strictly before today.
    final overdue =
        jobs
            .where(
              (j) =>
                  kBookedWorkStatuses.contains(j.status) && thIsOverdue(j, now),
            )
            .toList()
          ..sort((a, b) {
            final aT = a.scheduledStartUtc;
            final bT = b.scheduledStartUtc;
            if (aT == null && bT == null) return 0;
            if (aT == null) return 1;
            if (bT == null) return -1;
            return aT.compareTo(bT);
          });

    // Today: booked jobs scheduled exactly for today (not overdue).
    final today =
        jobs
            .where(
              (j) =>
                  kBookedWorkStatuses.contains(j.status) &&
                  thIsScheduledToday(j, now) &&
                  !thIsOverdue(j, now),
            )
            .toList()
          ..sort((a, b) {
            final aReq = thIsTradieActionRequired(a.status);
            final bReq = thIsTradieActionRequired(b.status);
            if (aReq != bReq) return aReq ? -1 : 1;
            final aTime = a.scheduledStartUtc;
            final bTime = b.scheduledStartUtc;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return aTime.compareTo(bTime);
          });

    final upcoming = jobs
        .where(
          (j) =>
              kBookedWorkStatuses.contains(j.status) &&
              !thIsScheduledToday(j, now) &&
              !thIsOverdue(j, now),
        )
        .toList();

    final awaitingPayment = jobs
        .where((j) => kAwaitingPaymentStatuses.contains(j.status))
        .toList();

    final disputed = jobs.where((j) => j.status == 'Disputed').toList();

    return TrHomeGroups(
      leads: leads,
      overdue: overdue,
      today: today,
      upcoming: upcoming,
      awaitingPayment: awaitingPayment,
      disputed: disputed,
    );
  }
}

/// Status chip copy + tone.
class TrStatusBadge {
  const TrStatusBadge(this.label, this.kind);
  final String label;
  final THBadgeKind kind;
}

TrStatusBadge thTradieStatusBadge(String status, {bool isOverdue = false}) {
  if (isOverdue) {
    return const TrStatusBadge('Overdue', THBadgeKind.accent);
  }
  return switch (status) {
    'Requested' => const TrStatusBadge('Requested', THBadgeKind.accent),
    'AwaitingPayment' => const TrStatusBadge(
      'Awaiting payment',
      THBadgeKind.accent,
    ),
    'PaymentReview' => const TrStatusBadge('Under review', THBadgeKind.brand),
    'Booked' => const TrStatusBadge('Booked', THBadgeKind.ok),
    'InProgress' => const TrStatusBadge('In progress', THBadgeKind.brand),
    'AwaitingConfirmation' => const TrStatusBadge(
      'Action needed',
      THBadgeKind.accent,
    ),
    'Completed' => const TrStatusBadge('Completed', THBadgeKind.ok),
    'Cancelled' => const TrStatusBadge('Cancelled', THBadgeKind.brand),
    'Expired' => const TrStatusBadge('Expired', THBadgeKind.brand),
    'Disputed' => const TrStatusBadge('Disputed', THBadgeKind.danger),
    _ => TrStatusBadge(status, THBadgeKind.brand),
  };
}

/// Progress mapping (0 to 3 of 4 stages: Requested -> Booked -> InProgress -> Completed).
({int steps, int done, bool current})? thTradieProgress(Job job) {
  const steps = 4;
  final stage = switch (job.status) {
    'Requested' => 0,
    'Booked' => 1,
    'InProgress' => 2,
    'AwaitingConfirmation' => 2,
    'Completed' => 3,
    _ => null,
  };
  if (stage == null) return null;
  return (steps: steps, done: stage + 1, current: stage + 1 < steps);
}

/// Subtitle for tradie job cards (e.g. "Plumbing · Tauranga · Today 1:30 pm").
String thTradieJobSubtitle(Job job) {
  final parts = <String>[];
  if (job.category.isNotEmpty) parts.add(job.category);
  if (job.suburb.isNotEmpty) parts.add(job.suburb);
  final scheduled = job.scheduledStartUtc;
  if (scheduled != null) {
    parts.add(thFormatSchedule(scheduled.toLocal()));
  }
  return parts.isEmpty ? 'Trade job' : parts.join(' · ');
}

/// Relative schedule string.
String thFormatSchedule(DateTime local) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final jobDay = DateTime(local.year, local.month, local.day);
  final time = DateFormat.jm().format(local);

  if (jobDay == today) return 'Today $time';
  if (jobDay == tomorrow) return 'Tomorrow $time';
  return '${DateFormat('EEE d MMM').format(local)} $time';
}

/// Tradie hero greeting (e.g. "KIA ORA, JAY").
String thTradieGreeting(String? firstName) {
  final name = (firstName ?? '').trim();
  if (name.isEmpty) return 'KIA ORA';
  return 'KIA ORA, ${name.toUpperCase()}';
}


/// What the hero "Net this week" figure should show (plan G-14). Keeps the
/// four v1 states apart: loading, error, no figure from the server, loaded.
enum TrNetKind { loading, error, unavailable, loaded }

class TrHeroNet {
  const TrHeroNet(this.kind, [this.amount]);
  final TrNetKind kind;

  /// Set only when [kind] is [TrNetKind.loaded]; a loaded zero stays zero.
  final Decimal? amount;
}

/// Maps the earnings provider state 1:1 (same precedence as v1 `_TradieHero`).
TrHeroNet trHeroNet(TradieEarningsState state) {
  final summary = state.summary;
  if (state.error != null && summary == null) {
    return const TrHeroNet(TrNetKind.error);
  }
  if (state.isLoading && summary == null) {
    return const TrHeroNet(TrNetKind.loading);
  }
  final earned = summary?.earnedNet;
  if (summary != null && earned == null) {
    return const TrHeroNet(TrNetKind.unavailable);
  }
  if (earned == null) return const TrHeroNet(TrNetKind.unavailable);
  return TrHeroNet(TrNetKind.loaded, earned);
}

/// Pending (all-time outstanding) payout, or null when the server sent none.
/// Never added to the weekly figure (plan G-14 / G-15).
Decimal? trPendingNet(TradieEarningsState state) => state.summary?.pendingNet;

/// Jobs scheduled in the local calendar week of [now] (Monday to Sunday) that
/// are real work: booked, in progress, awaiting confirmation or completed.
/// Derived client-side from the job list (plan G-13); never invented.
int trWeekJobCount(List<Job> jobs, DateTime now) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final weekStart = startOfToday.subtract(
    Duration(days: startOfToday.weekday - DateTime.monday),
  );
  final weekEnd = weekStart.add(const Duration(days: 7));
  const counted = {...kBookedWorkStatuses, 'Completed'};
  return jobs.where((j) {
    final at = j.scheduledStartUtc?.toLocal();
    return at != null &&
        counted.contains(j.status) &&
        !at.isBefore(weekStart) &&
        at.isBefore(weekEnd);
  }).length;
}

/// Verification banner rule (v1): show once the profile finished loading and
/// the tradie is not verified.
bool trShowVerificationBanner({
  required bool profileLoading,
  required bool? isVerified,
}) => !profileLoading && isVerified != true;

/// Rating tile/badge needs a real score and at least one review (v1 rule).
({String score, int count})? trRating(Map<String, dynamic>? profile) {
  final avg = profile?['averageRating'] as num?;
  final count = profile?['reviewCount'] as int?;
  if (avg == null || count == null || count <= 0 || avg <= 0) return null;
  return (score: avg.toStringAsFixed(1), count: count);
}

/// Whether going offline needs the confirm sheet: any lead or booked work.
bool trNeedsOfflineConfirm(List<Job> jobs) => jobs.any(
  (j) => j.status == 'Requested' || kBookedWorkStatuses.contains(j.status),
);

/// Lead card subtitle: category, suburb, timing. Real fields only (G-13/G-16).
String trLeadSubtitle(Job job) {
  final parts = <String>[
    if (job.category.isNotEmpty) job.category,
    if (job.suburb.isNotEmpty) job.suburb,
    if ((job.timingPreference ?? '').isNotEmpty) job.timingPreference!,
  ];
  return parts.isEmpty ? 'New request' : parts.join(' · ');
}
