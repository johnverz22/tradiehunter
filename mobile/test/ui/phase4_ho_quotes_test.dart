import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/homeowner/ho_quotes_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';

void main() {
  testWidgets('quotes render server pricing, scope and acceptance action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(_JobsFixture()),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: HoQuotesScreen(jobId: 'job-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bay Builders'), findsOneWidget);
    expect(find.text(r'$18,400.00'), findsOneWidget);
    expect(find.text('Incl. GST'), findsOneWidget);
    expect(find.text('Cabinetry and benchtop replacement'), findsOneWidget);
    expect(find.byKey(const Key('accept_quote_quote-1')), findsOneWidget);
    expect(
      find.text('Pay only when the job is done and you approve the total.'),
      findsOneWidget,
    );
  });
}

class _JobsFixture extends JobsRepository {
  _JobsFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<Quote>> getQuotes(String jobId) async => [
    Quote(
      id: 'quote-1',
      jobId: 'job-1',
      tradieId: 'tradie-1',
      tradieName: 'Bay Builders',
      businessName: 'Bay Builders',
      initials: 'BB',
      verified: true,
      rating: 4.9,
      reviewCount: 6,
      pricingModel: Quote.pricingFixed,
      amount: Decimal.fromInt(18400),
      inclusions: 'Cabinetry and benchtop replacement',
      materialsIncluded: true,
      gstIncluded: true,
    ),
  ];
}
