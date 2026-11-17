// Pure mapping for the v2 homeowner home (`ho_home`, migration plan 4.1 #1).
//
// Ports the grouping / sorting rules of views/homeowner/homeowner_dashboard_view.dart
// and the status copy of views/widgets/job_status_presentation.dart without
// importing them (lib/ui/** must not import v1). No Flutter widgets here, so
// every rule is unit-testable.
import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../design/th_widgets.dart' show THBadgeKind;

bool thIsPastHomeownerJob(String status) =>
    const {'Completed', 'Cancelled', 'Expired'}.contains(status);

bool thNeedsHomeownerAttention(String status) => const {
  'AwaitingPayment',
  'PaymentReview',
  'AwaitingConfirmation',
  'Disputed',
}.contains(status);

bool thIsBookedJob(String status) =>
    status == 'Booked' || status == 'InProgress';

int _attentionPriority(String status) => switch (status) {
  'AwaitingPayment' => 0,
  'AwaitingConfirmation' => 1,
  'Disputed' => 2,
  'PaymentReview' => 3,
  _ => 4,
};

/// Jobs grouped exactly like the v1 dashboard.
class HoHomeGroups {
  const HoHomeGroups({
    required this.attention,
    required this.booked,
    required this.active,
    required this.past,
  });

  /// Needs the homeowner now, most urgent first (payment, confirmation,
  /// dispute, payment review), then earliest scheduled/created first.
  final List<Job> attention;
  final List<Job> booked;
  final List<Job> active;
  final List<Job> past;

  factory HoHomeGroups.from(List<Job> jobs) {
    final attention = jobs
        .where((j) => thNeedsHomeownerAttention(j.status))
        .toList();
    attention.sort((a, b) {
      final pA = _attentionPriority(a.status);
      final pB = _attentionPriority(b.status);
      if (pA != pB) return pA.compareTo(pB);
      final dateA = a.scheduledStartUtc ?? a.createdAtUtc;
      final dateB = b.scheduledStartUtc ?? b.createdAtUtc;
      if (dateA != null && dateB != null) return dateA.compareTo(dateB);
      if (dateA != null) return -1;
      if (dateB != null) return 1;
      return 0;
    });
    return HoHomeGroups(
      attention: attention,
      booked: jobs.where((j) => thIsBookedJob(j.status)).toList(),
      active: jobs
          .where(
            (j) =>
                !thIsPastHomeownerJob(j.status) &&
                !thNeedsHomeownerAttention(j.status) &&
                !thIsBookedJob(j.status),
          )
          .toList(),
      past: jobs.where((j) => thIsPastHomeownerJob(j.status)).toList(),
    );
  }
}

/// Status chip copy + tone (mirrors `JobStatusPresentation.forStatus`).
class HoStatusBadge {
  const HoStatusBadge(this.label, this.kind);
  final String label;
  final THBadgeKind kind;
}

HoStatusBadge thHomeStatusBadge(String status) => switch (status) {
  'Requested' => const HoStatusBadge('Requested', THBadgeKind.accent),
  'Matching' => const HoStatusBadge('Matching', THBadgeKind.accent),
  'AwaitingPayment' => const HoStatusBadge('Payment due', THBadgeKind.accent),
  'PaymentReview' => const HoStatusBadge('Under review', THBadgeKind.brand),
  'Booked' => const HoStatusBadge('Booked', THBadgeKind.brand),
  'InProgress' => const HoStatusBadge('In progress', THBadgeKind.brand),
  'AwaitingConfirmation' => const HoStatusBadge(
    'Action needed',
    THBadgeKind.accent,
  ),
  'Completed' => const HoStatusBadge('Completed', THBadgeKind.ok),
  'Cancelled' => const HoStatusBadge('Cancelled', THBadgeKind.brand),
  'Expired' => const HoStatusBadge('Expired', THBadgeKind.brand),
  'Disputed' => const HoStatusBadge('Disputed', THBadgeKind.danger),
  _ => const HoStatusBadge('Status unavailable', THBadgeKind.brand),
};

/// Segmented progress for a job card, or null when the status has no
/// progress (cancelled / expired / disputed / unknown).
class HoProgress {
  const HoProgress({
    required this.steps,
    required this.done,
    required this.current,
  });
  final int steps;
  final int done;
  final bool current;
}

HoProgress? thHomeProgress(Job job) {
  const noProgress = {'Cancelled', 'Expired', 'Disputed'};
  if (noProgress.contains(job.status)) return null;
  if (job.usesV2Flow) {
    // v1.7: Requested → Booked → In progress → Review & approve → Pay → Completed
    const steps = 6;
    final stage = job.stage.clamp(0, steps - 1);
    return HoProgress(
      steps: steps,
      done: stage + 1,
      current: stage + 1 < steps,
    );
  }
  // Legacy flow: Requested → Booked → In progress → Done.
  const steps = 4;
  final stage = switch (job.status) {
    'Requested' || 'Matching' || 'AwaitingPayment' || 'PaymentReview' => 0,
    'Booked' => 1,
    'InProgress' || 'AwaitingConfirmation' => 2,
    'Completed' => 3,
    _ => null,
  };
  if (stage == null) return null;
  return HoProgress(steps: steps, done: stage + 1, current: stage + 1 < steps);
}

/// One-line subtitle under a job title, never inventing data.
String thHomeJobSubtitle(Job job) {
  final tradie = job.matchedTradieName?.trim();
  if (tradie != null && tradie.isNotEmpty) return tradie;
  return switch (job.status) {
    'Requested' || 'Matching' => 'Finding a tradie',
    _ => job.suburb,
  };
}

/// Content of the navy "needs your attention" hero for the most urgent job.
class HoAttentionHero {
  const HoAttentionHero({
    required this.job,
    required this.headline,
    required this.subtitle,
    required this.actionLabel,
    this.amountLabel,
  });
  final Job job;
  final String headline;
  final String subtitle;
  final String actionLabel;

  /// Null when the API has not priced the job yet (never shown as $0.00).
  final String? amountLabel;
}

HoAttentionHero? thAttentionHero(List<Job> attention) {
  if (attention.isEmpty) return null;
  final job = attention.first;
  final (headline, action) = switch (job.status) {
    'AwaitingPayment' => ('Payment due', 'Pay now'),
    'PaymentReview' => ('Payment under review', 'View status'),
    'AwaitingConfirmation' => ('Approve final amount', 'Review'),
    'Disputed' => ('Dispute in progress', 'View'),
    _ => ('Needs your attention', 'Open'),
  };
  final tradie = job.matchedTradieName?.trim();
  final amount = job.finalAmount ?? job.totalAmount ?? job.estimatedTotal;
  return HoAttentionHero(
    job: job,
    headline: headline,
    subtitle: (tradie == null || tradie.isEmpty)
        ? job.title
        : '${job.title} · $tradie',
    actionLabel: action,
    amountLabel: amount == null ? null : formatMoney(amount),
  );
}
