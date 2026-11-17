import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/address.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/address_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/homeowner/ho_browse_tradies_screen.dart';
import 'package:fixo/viewmodels/address_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _JobsFixture extends JobsRepository {
  _JobsFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<ServiceOption>> getServiceCatalog() async => const [
    ServiceOption(id: 1, name: 'Tap repair', category: 'Plumbing'),
  ];

  @override
  Future<List<ServiceRateOption>> searchServiceRates({
    required int serviceId,
    required double latitude,
    required double longitude,
  }) async => [
    ServiceRateOption(
      tradieId: 'tradie-1',
      name: 'Aroha Plumbing',
      businessName: 'Aroha Plumbing Ltd',
      hourlyRate: Decimal.fromInt(85),
      distanceKm: 2.4,
    ),
  ];
}

class _AddressFixture extends AddressRepository {
  _AddressFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<AddressSearchResult> search(String query) async =>
      const AddressSearchResult(
        provider: 'LINZ',
        attribution: 'LINZ Data Service',
        attributionUrl: 'https://data.linz.govt.nz',
        items: [
          AddressCandidate(
            id: 'linz:1',
            address: '14 Marine Parade, Tauranga',
            suburb: 'Tauranga',
            latitude: -37.6878,
            longitude: 176.1651,
          ),
        ],
      );
}

void main() {
  testWidgets('browse uses real service/address search results', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(_JobsFixture()),
          addressRepositoryProvider.overrideWithValue(_AddressFixture()),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(
          home: HoBrowseTradiesScreen(initialCategory: 'Plumbing'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tap repair'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Tauranga');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14 Marine Parade, Tauranga'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Aroha Plumbing Ltd'));
    await tester.pumpAndSettle();
    expect(find.text('Aroha Plumbing Ltd'), findsOneWidget);
    expect(find.textContaining('85.00'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
  });
}
