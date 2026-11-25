// Tradie view of the job status table (migration plan 5.0 #2).
//
// Values are copied from views/widgets/job_status_presentation.dart
// (`JobStatusPresentation`) so lib/ui/** never imports v1. A parity test
// (test/ui/phase5_tr_job_status_test.dart) iterates the v1 table and asserts
// identical labels and flags; keep both in step until Phase 6 deletes v1.
import '../design/th_widgets.dart' show THBadgeKind;
import 'tr_home_mapper.dart' show thTradieStatusBadge;

/// What the tradie sees and must do for one job status.
class TrJobStatus {
  const TrJobStatus(
    this.label, {
    this.tradieAction = 'View request',
    this.tradieActionRequired = false,
  });

  /// Status label (same copy as the v1 status chip).
  final String label;

  /// Primary action label on tradie cards.
  final String tradieAction;

  /// Whether the tradie must act now for this status.
  final bool tradieActionRequired;

  /// Dashboard secondary action: details when the job is finished with,
  /// otherwise the chat.
  String get tradieDashboardAction =>
      tradieAction == 'View job details' ? tradieAction : 'Open chat';

  /// Badge tone for [label] (shared with the tradie card mapper).
  THBadgeKind badgeKind(String status) => thTradieStatusBadge(status).kind;

  /// Total over every status string; an unknown status never throws.
  static TrJobStatus forStatus(String status) =>
      _statuses[status] ?? const TrJobStatus('Status unavailable');

  static const Map<String, TrJobStatus> _statuses = {
    'Requested': TrJobStatus('Requested'),
    'AwaitingPayment': TrJobStatus('Payment due'),
    'PaymentReview': TrJobStatus('Under review'),
    'Booked': TrJobStatus(
      'Booked',
      tradieAction: 'Check in',
      tradieActionRequired: true,
    ),
    'InProgress': TrJobStatus(
      'In progress',
      tradieAction: 'Check out',
      tradieActionRequired: true,
    ),
    'AwaitingConfirmation': TrJobStatus(
      'Action needed',
      tradieAction: 'Mark complete',
      tradieActionRequired: true,
    ),
    'Completed': TrJobStatus('Completed', tradieAction: 'View job details'),
    'Cancelled': TrJobStatus('Cancelled', tradieAction: 'View job details'),
    'Expired': TrJobStatus('Expired'),
    'Disputed': TrJobStatus('Disputed'),
  };

  /// Every status key in the table (used by the parity test).
  static Iterable<String> get knownStatuses => _statuses.keys;
}
