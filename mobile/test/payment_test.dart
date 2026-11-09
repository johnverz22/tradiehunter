// Wire-format tests for the manual payment flow (P4-07). These cover the seam
// where the Flutter client meets the .NET API: PascalCase `PaymentStatus`
// enums, `decimal` amounts, nullable bank details, and the server's own
// `canUploadReceipt` decision, which the UI must not re-derive.

import 'package:decimal/decimal.dart';
import 'package:fixo/models/payment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shaped exactly like the backend's `PaymentStatusDto`.
Map<String, dynamic> payload({
  String status = 'Pending',
  Map<String, dynamic>? bankDetails,
  bool canUploadReceipt = true,
  String? rejectReason,
  int reUploadCount = 0,
}) =>
    {
      'paymentId': 1,
      'jobId': 42,
      'jobTitle': 'Leaking kitchen tap',
      'jobStatus': 'AwaitingPayment',
      'amount': 171.00,
      'currency': 'NZD',
      'method': 'BankTransfer',
      'provider': 'Manual',
      'reference': 'FIXO-42',
      'status': status,
      'bankDetails': bankDetails ??
          {'accountName': 'Fixo Ltd', 'accountNumber': '00-0000-0000000-00'},
      'dueAtUtc': '2099-01-01T00:00:00Z',
      'submittedAtUtc': null,
      'verifiedAtUtc': null,
      'rejectReason': rejectReason,
      'reUploadCount': reUploadCount,
      'createdAtUtc': '2026-09-28T14:00:00Z',
      'canUploadReceipt': canUploadReceipt,
    };

void main() {
  group('PaymentStage.fromWire', () {
    test('maps every backend PaymentStatus', () {
      expect(PaymentStage.fromWire('Pending'), PaymentStage.pending);
      expect(PaymentStage.fromWire('Submitted'), PaymentStage.submitted);
      expect(PaymentStage.fromWire('Verified'), PaymentStage.verified);
      expect(PaymentStage.fromWire('Rejected'), PaymentStage.rejected);
      expect(PaymentStage.fromWire('Expired'), PaymentStage.expired);
    });

    test('falls back to unknown instead of throwing on a new state', () {
      // The server may add a status before the app ships an update; the screen
      // must render something rather than crash.
      expect(PaymentStage.fromWire('PartiallyRefunded'), PaymentStage.unknown);
      expect(PaymentStage.fromWire(null), PaymentStage.unknown);
    });

    test('only pending and rejected allow a new upload', () {
      expect(PaymentStage.pending.allowsUpload, isTrue);
      expect(PaymentStage.rejected.allowsUpload, isTrue);
      expect(PaymentStage.submitted.allowsUpload, isFalse);
      expect(PaymentStage.verified.allowsUpload, isFalse);
      expect(PaymentStage.expired.allowsUpload, isFalse);
    });
  });

  group('PaymentStatus.fromJson', () {
    test('parses a pending payment with instructions', () {
      final payment = PaymentStatus.fromJson(payload());

      expect(payment.jobId, 42);
      expect(payment.reference, 'FIXO-42');
      expect(payment.stage, PaymentStage.pending);
      expect(payment.bankDetails?.accountName, 'Fixo Ltd');
      expect(payment.bankDetails?.accountNumber, '00-0000-0000000-00');
      expect(payment.canUploadReceipt, isTrue);
    });

    test('keeps money exact — cents survive as Decimal, not double', () {
      // Three amounts a double would accumulate error on. Decimal holds them
      // exactly, so the sum is the cent-accurate total.
      final amounts = ['640.50', '171.00', '95.25']
          .map((v) => PaymentStatus.fromJson({...payload(), 'amount': v}).amount)
          .toList();

      expect(amounts, [
        Decimal.parse('640.50'),
        Decimal.parse('171.00'),
        Decimal.parse('95.25'),
      ]);
      expect(
        amounts.reduce((a, b) => a + b),
        Decimal.parse('906.75'),
      );
    });

    test('accepts an amount sent as a JSON string', () {
      final payment = PaymentStatus.fromJson(
        {...payload(), 'amount': '171.00'},
      );
      expect(payment.amount, Decimal.parse('171.00'));
    });

    test('tolerates a null bankDetails (a verified payment hides it)', () {
      final payment = PaymentStatus.fromJson({
        ...payload(status: 'Verified', canUploadReceipt: false),
        'bankDetails': null,
      });
      expect(payment.bankDetails, isNull);
      expect(payment.canUploadReceipt, isFalse);
    });

    test('carries the rejection reason and send-back count', () {
      final payment = PaymentStatus.fromJson(payload(
        status: 'Rejected',
        rejectReason: 'The amount on the slip does not match.',
        reUploadCount: 2,
      ));
      expect(payment.stage, PaymentStage.rejected);
      expect(payment.rejectReason, 'The amount on the slip does not match.');
      expect(payment.reUploadCount, 2);
    });

    test("defers to the server's canUploadReceipt, not the job status", () {
      // Job is AwaitingPayment but staff hold the receipt: the client must not
      // re-derive the rule and offer a second upload.
      final payment = PaymentStatus.fromJson(
        payload(status: 'Submitted', canUploadReceipt: false),
      );
      expect(payment.jobStatus, 'AwaitingPayment');
      expect(payment.canUploadReceipt, isFalse);
    });

    test('survives missing optional fields', () {
      final payment = PaymentStatus.fromJson({'status': 'Pending'});
      expect(payment.stage, PaymentStage.pending);
      expect(payment.reference, '');
      expect(payment.reUploadCount, 0);
      expect(payment.bankDetails, isNull);
      expect(payment.canUploadReceipt, isFalse);
    });

    test('localizes UTC timestamps to device time', () {
      final payment = PaymentStatus.fromJson(
        payload()..['dueAtUtc'] = '2026-09-28T14:00:00Z',
      );
      expect(payment.dueAtUtc.isUtc, isFalse);
    });

    test('reports the time left before the window closes', () {
      final future = PaymentStatus.fromJson(
        payload()
          ..['dueAtUtc'] = DateTime.now()
              .add(const Duration(hours: 2))
              .toUtc()
              .toIso8601String(),
      );
      expect(future.isOverdue, isFalse);
      expect(future.timeRemaining.inHours, 1);

      final past = PaymentStatus.fromJson(
        payload()
          ..['dueAtUtc'] =
              DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
      );
      expect(past.isOverdue, isTrue);
    });
  });
}
