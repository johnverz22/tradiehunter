import 'package:dio/dio.dart';
import 'package:fixo/models/payment.dart';
import 'package:fixo/repositories/payments_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/viewmodels/payment_viewmodel.dart';
import 'package:fixo/views/payment/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'payment_test.dart' show payload;

class InstructionsFixture extends PaymentsRepository {
  final BankDetails? bank;
  InstructionsFixture(this.bank) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<PaymentStatus> getPayment(String jobId) async =>
      PaymentStatus.fromJson({
        ...payload(),
        'bankDetails': bank == null
            ? null
            : {
                'accountName': bank!.accountName,
                'accountNumber': bank!.accountNumber,
              },
      });
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final dark in [false, true]) {
    for (final kind in ['missing', 'sentinel', 'legal']) {
      testWidgets('payment instructions $kind dark=$dark', (tester) async {
        final bank = kind == 'missing'
            ? null
            : BankDetails(
                accountName: 'Fixo Legal Partner Ltd',
                accountNumber: kind == 'legal'
                    ? '12-3456-7890123-00'
                    : '00-0000-0000000-00',
              );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              paymentsRepositoryProvider.overrideWithValue(
                InstructionsFixture(bank),
              ),
              localeConfigProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp(
              theme: dark ? FixoTheme.dark() : FixoTheme.light(),
              home: const PaymentScreen(jobId: '42'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text(
            kind == 'legal' ? 'Fixo Legal Partner Ltd' : 'Bank transfer details are unavailable. Do not transfer money until valid instructions are available. Try refreshing payment details.',
          ),
          250,
          scrollable: list,
        );
        expect(find.text('00-0000-0000000-00'), findsNothing);
        if (kind == 'legal') {
          expect(find.text('Fixo Legal Partner Ltd'), findsOneWidget);
          expect(find.text('12-3456-7890123-00'), findsOneWidget);
        } else {
          expect(find.text('Account number'), findsNothing);
        }
        expect(find.byKey(const Key('upload_receipt_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
