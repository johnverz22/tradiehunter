import '../design/th_widgets.dart';

/// v2-owned copy of the status vocabulary used by the v1 detail screen.
/// Keep this table presentation-only; repository/model code remains shared.
class HoJobStatus {
  const HoJobStatus({
    required this.label,
    required this.stage,
    required this.tone,
  });

  final String label;
  final int? stage;
  final THBadgeKind tone;

  static const Map<String, HoJobStatus> values = {
    'Requested': HoJobStatus(
      label: 'Requested',
      stage: 0,
      tone: THBadgeKind.glass,
    ),
    'AwaitingPayment': HoJobStatus(
      label: 'Payment due',
      stage: 0,
      tone: THBadgeKind.accent,
    ),
    'PaymentReview': HoJobStatus(
      label: 'Under review',
      stage: 0,
      tone: THBadgeKind.glass,
    ),
    'Booked': HoJobStatus(label: 'Booked', stage: 1, tone: THBadgeKind.brand),
    'InProgress': HoJobStatus(
      label: 'In progress',
      stage: 2,
      tone: THBadgeKind.accent,
    ),
    'AwaitingConfirmation': HoJobStatus(
      label: 'Action needed',
      stage: 2,
      tone: THBadgeKind.accent,
    ),
    'Completed': HoJobStatus(
      label: 'Completed',
      stage: 3,
      tone: THBadgeKind.ok,
    ),
    'Cancelled': HoJobStatus(
      label: 'Cancelled',
      stage: null,
      tone: THBadgeKind.glass,
    ),
    'Expired': HoJobStatus(
      label: 'Expired',
      stage: null,
      tone: THBadgeKind.glass,
    ),
    'Disputed': HoJobStatus(
      label: 'Disputed',
      stage: null,
      tone: THBadgeKind.danger,
    ),
  };

  static HoJobStatus forStatus(String? status) =>
      values[status] ??
      const HoJobStatus(
        label: 'Status unavailable',
        stage: null,
        tone: THBadgeKind.glass,
      );
}
