import 'package:decimal/decimal.dart';

/// Payment lifecycle as sent by the API (P4-01 `PaymentStatus`), stored as a
/// string on the wire. Mirrors the backend enum.
enum PaymentStage {
  pending,
  submitted,
  verified,
  rejected,
  expired,
  unknown;

  static PaymentStage fromWire(String? value) => switch (value) {
    'Pending' => PaymentStage.pending,
    'Submitted' => PaymentStage.submitted,
    'Verified' => PaymentStage.verified,
    'Rejected' => PaymentStage.rejected,
    'Expired' => PaymentStage.expired,
    _ => PaymentStage.unknown,
  };

  String get label => switch (this) {
    PaymentStage.pending => 'Awaiting payment',
    PaymentStage.submitted => 'Under review',
    PaymentStage.verified => 'Paid',
    PaymentStage.rejected => 'Needs a new receipt',
    PaymentStage.expired => 'Expired',
    PaymentStage.unknown => 'Unknown',
  };

  String get description => switch (this) {
    PaymentStage.pending => 'Transfer the amount using the reference below, then upload your receipt.',
    PaymentStage.submitted => "We've got your receipt. Our team is checking it against our bank account.",
    PaymentStage.verified => 'Payment confirmed. Your tradie has been booked.',
    PaymentStage.rejected =>
      'We could not accept this receipt. See the reason and try again.',
    PaymentStage.expired => 'The payment window closed before payment arrived.',
    PaymentStage.unknown => 'Payment status is unavailable.',
  };

  /// Only a pending or rejected payment can be (re-)submitted.
  bool get allowsUpload =>
      this == PaymentStage.pending || this == PaymentStage.rejected;
}

/// Bank account the transfer is sent to (P4-04). Comes from the
/// `PaymentInstructions` config section, never hardcoded in the app.
class BankDetails {
  final String accountName;
  final String accountNumber;

  const BankDetails({required this.accountName, required this.accountNumber});

  bool get isAvailable {
    bool usable(String value) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty &&
          !normalized.contains('<') &&
          !normalized.contains('>') &&
          !RegExp(
            r'^(change[ _-]?me|todo|tbd|placeholder|n/?a|not configured)$',
          ).hasMatch(normalized);
    }

    final digits = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return usable(accountName) &&
        usable(accountNumber) &&
        digits.isNotEmpty &&
        !RegExp(r'^0+$').hasMatch(digits);
  }

  factory BankDetails.fromJson(Map<String, dynamic> json) => BankDetails(
    accountName: json['accountName'] as String? ?? '',
    accountNumber: json['accountNumber'] as String? ?? '',
  );
}

/// The homeowner's view of a job's manual payment (P4-04 `PaymentStatusDto`).
class PaymentStatus {
  final int paymentId;
  final int jobId;
  final String jobTitle;

  /// The job's own status — `AwaitingPayment`, `PaymentReview`, `Booked`…
  /// Drives the job stepper; distinct from the payment's [stage].
  final String jobStatus;

  final Decimal amount;
  final String currency;
  final String method;
  final String provider;

  /// Job-specific code that must be quoted on the transfer.
  final String reference;

  final PaymentStage stage;
  final BankDetails? bankDetails;

  /// Deadline before the job expires and the tradie is released (P4-06).
  final DateTime dueAtUtc;

  final DateTime? submittedAtUtc;
  final DateTime? verifiedAtUtc;

  /// Staff's reason for a rejection, shown verbatim.
  final String? rejectReason;

  final int reUploadCount;
  final DateTime createdAtUtc;

  /// Server's own answer to "can the homeowner submit right now", so the
  /// client never has to re-derive the rule from [jobStatus].
  final bool canUploadReceipt;

  const PaymentStatus({
    required this.paymentId,
    required this.jobId,
    required this.jobTitle,
    required this.jobStatus,
    required this.amount,
    required this.currency,
    required this.method,
    required this.provider,
    required this.reference,
    required this.stage,
    required this.bankDetails,
    required this.dueAtUtc,
    required this.submittedAtUtc,
    required this.verifiedAtUtc,
    required this.rejectReason,
    required this.reUploadCount,
    required this.createdAtUtc,
    required this.canUploadReceipt,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> json) => PaymentStatus(
    paymentId: (json['paymentId'] as num?)?.toInt() ?? 0,
    jobId: (json['jobId'] as num?)?.toInt() ?? 0,
    jobTitle: json['jobTitle'] as String? ?? '',
    jobStatus: json['jobStatus'] as String? ?? '',
    amount: Decimal.tryParse(json['amount']?.toString() ?? '0') ?? Decimal.zero,
    currency: json['currency'] as String? ?? 'NZD',
    method: json['method'] as String? ?? 'BankTransfer',
    provider: json['provider'] as String? ?? 'Manual',
    reference: json['reference'] as String? ?? '',
    stage: PaymentStage.fromWire(json['status'] as String?),
    bankDetails: json['bankDetails'] == null
        ? null
        : BankDetails.fromJson(json['bankDetails'] as Map<String, dynamic>),
    dueAtUtc:
        DateTime.tryParse(json['dueAtUtc']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    submittedAtUtc: DateTime.tryParse(json['submittedAtUtc']?.toString() ?? '')
        ?.toLocal(),
    verifiedAtUtc: DateTime.tryParse(json['verifiedAtUtc']?.toString() ?? '')
        ?.toLocal(),
    rejectReason: json['rejectReason'] as String?,
    reUploadCount: (json['reUploadCount'] as num?)?.toInt() ?? 0,
    createdAtUtc:
        DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    canUploadReceipt: json['canUploadReceipt'] as bool? ?? false,
  );

  /// Time left before the job expires. Negative once past the deadline.
  Duration get timeRemaining => dueAtUtc.difference(DateTime.now());

  bool get isOverdue => timeRemaining.isNegative;
}
