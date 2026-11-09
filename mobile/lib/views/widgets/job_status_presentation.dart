import '../../widgets/fixo_cards.dart';

class JobStatusPresentation {
  final String label;
  final FixoBadgeKind kind;
  final String homeownerAction;
  final String tradieAction;
  final int? progressStage;

  static const progressLabels = ['Requested', 'Booked', 'In progress', 'Done'];

  String? get progressLabel => progressStage == null
      ? null
      : 'Step ${progressStage! + 1} of 4 · ${progressLabels[progressStage!]}';

  const JobStatusPresentation(
    this.label, {
    this.kind = FixoBadgeKind.cancelled,
    this.homeownerAction = 'Open chat',
    this.tradieAction = 'View request',
    this.progressStage,
  });

  String get tradieDashboardAction =>
      tradieAction == 'View job details' ? tradieAction : 'Open chat';

  static JobStatusPresentation forStatus(String status) =>
      _statuses[status] ?? const JobStatusPresentation('Status unavailable');

  static const _statuses = {
    'Requested': JobStatusPresentation(
      'Requested',
      progressStage: 0,
      kind: FixoBadgeKind.waiting,
      homeownerAction: 'View matching',
    ),
    'AwaitingPayment': JobStatusPresentation(
      'Payment due',
      progressStage: 0,
      kind: FixoBadgeKind.actionNeeded,
      homeownerAction: 'Payment details',
    ),
    'PaymentReview': JobStatusPresentation(
      'Under review',
      progressStage: 0,
      kind: FixoBadgeKind.waiting,
      homeownerAction: 'View payment status',
    ),
    'Booked': JobStatusPresentation(
      'Booked',
      progressStage: 1,
      kind: FixoBadgeKind.active,
      homeownerAction: 'View job details',
      tradieAction: 'View job details',
    ),
    'InProgress': JobStatusPresentation(
      'In progress',
      progressStage: 2,
      kind: FixoBadgeKind.active,
      homeownerAction: 'View job details',
      tradieAction: 'View job details',
    ),
    'AwaitingConfirmation': JobStatusPresentation(
      'Action needed',
      progressStage: 2,
      kind: FixoBadgeKind.actionNeeded,
      homeownerAction: 'Review completion',
      tradieAction: 'View job details',
    ),
    'Completed': JobStatusPresentation(
      'Completed',
      progressStage: 3,
      kind: FixoBadgeKind.done,
      homeownerAction: 'View job details',
      tradieAction: 'View job details',
    ),
    'Cancelled': JobStatusPresentation(
      'Cancelled',
      kind: FixoBadgeKind.cancelled,
      tradieAction: 'View job details',
    ),
    'Expired': JobStatusPresentation(
      'Expired',
      kind: FixoBadgeKind.cancelled,
    ),
    'Disputed': JobStatusPresentation(
      'Disputed',
      kind: FixoBadgeKind.problem,
    ),
  };
}
