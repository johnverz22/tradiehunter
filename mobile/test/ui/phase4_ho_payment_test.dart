import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/payment.dart';
import 'package:fixo/repositories/payments_repository.dart';
import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/homeowner/ho_payment_screen.dart';
import 'package:fixo/viewmodels/payment_viewmodel.dart';

void main() {
  testWidgets(
    'payment details block upload when bank instructions are absent',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentFixture(_unavailableBankPayment),
            ),
            paymentJobProvider('42').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: ThScope(child: HoPaymentScreen(jobId: '42')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$171.00'), findsNWidgets(2));
      expect(
        find.text(
          'Bank transfer details are unavailable. Do not transfer money until valid instructions are shown.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('upload_disabled_hint')), findsOneWidget);
      expect(find.byKey(const Key('upload_receipt_button')), findsNothing);
      expect(find.text('Payment status'), findsNothing);
      expect(find.text('Awaiting payment'), findsNothing);
    },
  );

  testWidgets(
    'payment details render transfer instructions, copy reference, and allow receipt upload when bank details are valid',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentFixture(_validBankPayment),
            ),
            paymentJobProvider('42').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: ThScope(child: HoPaymentScreen(jobId: '42')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mockup ho_payment: bank card is three rows, then the dashed upload
      // box; no titled card, copy buttons, Method row or status sub-screen.
      expect(find.text('Account name'), findsOneWidget);
      expect(find.text('Fixo Ltd Client Funds'), findsOneWidget);
      expect(find.text('12-3456-7890123-00'), findsOneWidget);
      expect(find.byKey(const Key('copy_reference_button')), findsOneWidget);
      expect(find.text('Upload your receipt'), findsOneWidget);
      expect(find.text('Transfer to the tradie'), findsNothing);
      expect(find.text('Copy all payment details'), findsNothing);
      expect(find.text('Method'), findsNothing);
      expect(find.text('Payment status'), findsNothing);
      expect(find.byKey(const Key('upload_receipt_button')), findsOneWidget);
      expect(find.byKey(const Key('upload_disabled_hint')), findsNothing);
    },
  );

  testWidgets(
    'payment status submitted state shows review explanation and amount/reference',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentFixture(_submittedPayment),
            ),
            paymentJobProvider('42').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: ThScope(child: HoPaymentStatusScreen(jobId: '42')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt sent for review'), findsOneWidget);
      expect(
        find.text(
          'Our team is checking your receipt. We usually verify within one business day.',
        ),
        findsOneWidget,
      );
      expect(find.text(r'$171.00'), findsOneWidget);
      expect(find.text('FX-42'), findsOneWidget);
      expect(find.text('Back to job'), findsOneWidget);
    },
  );

  testWidgets(
    'payment status verified state shows confirmed badge and back to job',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentFixture(_verifiedPayment),
            ),
            paymentJobProvider('42').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: ThScope(child: HoPaymentStatusScreen(jobId: '42')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment confirmed'), findsOneWidget);
      expect(
        find.text(
          'Your payment has been verified and the completed work is settled.',
        ),
        findsOneWidget,
      );
      expect(find.text('Back to job'), findsOneWidget);
    },
  );

  testWidgets(
    'payment status rejected state shows rejection reason and upload again action',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentFixture(_rejectedPayment),
            ),
            paymentJobProvider('42').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: ThScope(child: HoPaymentStatusScreen(jobId: '42')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt needs another look'), findsOneWidget);
      expect(
        find.text('Account number is not visible on the receipt.'),
        findsOneWidget,
      );
      expect(find.text('Upload again'), findsOneWidget);
      expect(find.text('Back to job'), findsOneWidget);
    },
  );

  testWidgets(
    'payment status expired state shows expired notice and contact support action',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentFixture(_expiredPayment),
            ),
            paymentJobProvider('42').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: ThScope(child: HoPaymentStatusScreen(jobId: '42')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment window expired'), findsOneWidget);
      expect(
        find.text(
          'The payment window closed without a receipt. Contact support for help.',
        ),
        findsOneWidget,
      );
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Back to job'), findsOneWidget);
    },
  );
}

final _unavailableBankPayment = PaymentStatus.fromJson({
  'paymentId': 1,
  'jobId': 42,
  'jobTitle': 'Leaking kitchen tap',
  'jobStatus': 'AwaitingPayment',
  'amount': '171.00',
  'currency': 'NZD',
  'method': 'BankTransfer',
  'provider': 'Manual',
  'reference': 'FX-42',
  'status': 'Pending',
  'bankDetails': {'accountName': 'Not configured', 'accountNumber': '0000000'},
  'dueAtUtc': '2099-01-01T00:00:00Z',
  'createdAtUtc': '2026-01-01T00:00:00Z',
  'canUploadReceipt': true,
});

final _validBankPayment = PaymentStatus.fromJson({
  'paymentId': 1,
  'jobId': 42,
  'jobTitle': 'Leaking kitchen tap',
  'jobStatus': 'AwaitingPayment',
  'amount': '171.00',
  'currency': 'NZD',
  'method': 'BankTransfer',
  'provider': 'Manual',
  'reference': 'FX-42',
  'status': 'Pending',
  'bankDetails': {
    'accountName': 'Fixo Ltd Client Funds',
    'accountNumber': '12-3456-7890123-00',
  },
  'dueAtUtc': '2099-01-01T00:00:00Z',
  'createdAtUtc': '2026-01-01T00:00:00Z',
  'canUploadReceipt': true,
});

final _submittedPayment = PaymentStatus.fromJson({
  'paymentId': 1,
  'jobId': 42,
  'jobTitle': 'Leaking kitchen tap',
  'jobStatus': 'PaymentReview',
  'amount': '171.00',
  'currency': 'NZD',
  'method': 'BankTransfer',
  'provider': 'Manual',
  'reference': 'FX-42',
  'status': 'Submitted',
  'canUploadReceipt': false,
});

final _verifiedPayment = PaymentStatus.fromJson({
  'paymentId': 1,
  'jobId': 42,
  'jobTitle': 'Leaking kitchen tap',
  'jobStatus': 'Completed',
  'amount': '171.00',
  'currency': 'NZD',
  'method': 'BankTransfer',
  'provider': 'Manual',
  'reference': 'FX-42',
  'status': 'Verified',
  'canUploadReceipt': false,
});

final _rejectedPayment = PaymentStatus.fromJson({
  'paymentId': 1,
  'jobId': 42,
  'jobTitle': 'Leaking kitchen tap',
  'jobStatus': 'AwaitingPayment',
  'amount': '171.00',
  'currency': 'NZD',
  'method': 'BankTransfer',
  'provider': 'Manual',
  'reference': 'FX-42',
  'status': 'Rejected',
  'rejectReason': 'Account number is not visible on the receipt.',
  'canUploadReceipt': true,
});

final _expiredPayment = PaymentStatus.fromJson({
  'paymentId': 1,
  'jobId': 42,
  'jobTitle': 'Leaking kitchen tap',
  'jobStatus': 'Expired',
  'amount': '171.00',
  'currency': 'NZD',
  'method': 'BankTransfer',
  'provider': 'Manual',
  'reference': 'FX-42',
  'status': 'Expired',
  'canUploadReceipt': false,
});

class _PaymentFixture extends PaymentsRepository {
  _PaymentFixture(this.payment) : super(Dio(), const FlutterSecureStorage());

  final PaymentStatus payment;

  @override
  Future<PaymentStatus> getPayment(String jobId) async => payment;
}
