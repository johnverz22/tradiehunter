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
            paymentsRepositoryProvider.overrideWithValue(_PaymentFixture()),
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
    },
  );
}

class _PaymentFixture extends PaymentsRepository {
  _PaymentFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<PaymentStatus> getPayment(String jobId) async =>
      PaymentStatus.fromJson({
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
          'accountName': 'Not configured',
          'accountNumber': '0000000',
        },
        'dueAtUtc': '2099-01-01T00:00:00Z',
        'createdAtUtc': '2026-01-01T00:00:00Z',
        'canUploadReceipt': true,
      });
}
