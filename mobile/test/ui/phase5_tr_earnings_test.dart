// Phase 5.6: v2 tradie earnings (`tr_earnings`).
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/tradie/tr_earnings_screen.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase3_test_setup.dart';

class _FakeProfileRepo extends ProfileRepository {
  _FakeProfileRepo({this.earnings})
    : super(Dio(), const FlutterSecureStorage());

  final TradieEarnings? earnings;

  @override
  Future<TradieEarnings> getEarnings() async => earnings!;
}

TradieEarnings _earnings({
  Decimal? earnedNet,
  Decimal? processedNet,
  Decimal? pendingNet,
  Decimal? failedNet,
}) => TradieEarnings(
  periodStartUtc: DateTime.utc(2026, 11, 23, 0, 0),
  periodEndUtc: DateTime.utc(2026, 11, 29, 23, 59),
  asOfUtc: DateTime.utc(2026, 11, 25, 12, 0),
  timeZone: 'Pacific/Auckland',
  earnedNet: earnedNet,
  processedNet: processedNet,
  pendingNet: pendingNet,
  failedNet: failedNet,
);

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildScreen(_FakeProfileRepo repo, {bool dark = false}) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        platformBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TrEarningsScreen()),
      ),
    );
  }

  group('TrEarningsScreen', () {
    testWidgets('renders loaded amounts in light and dark', (tester) async {
      final repo = _FakeProfileRepo(
        earnings: _earnings(
          earnedNet: Decimal.parse('1284.50'),
          processedNet: Decimal.parse('1000.00'),
          pendingNet: Decimal.parse('284.50'),
          failedNet: Decimal.zero,
        ),
      );

      for (final dark in [false, true]) {
        await tester.pumpWidget(buildScreen(repo, dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('Earnings'), findsOneWidget);
        expect(find.text('NET THIS WEEK'), findsOneWidget);
        expect(find.text('\$1,284.50'), findsOneWidget);
        expect(find.text('Processed'), findsOneWidget);
        expect(find.text('Outstanding (all time)'), findsOneWidget);
        expect(find.text('Failed payouts'), findsNothing);
      }
    });

    testWidgets('distinguishes null amounts as No figure yet', (tester) async {
      final repo = _FakeProfileRepo(earnings: _earnings());
      await tester.pumpWidget(buildScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('No figure yet'), findsNWidgets(3));
    });

    testWidgets('shows failed payouts card only when failedNet > 0', (
      tester,
    ) async {
      final repo = _FakeProfileRepo(
        earnings: _earnings(
          earnedNet: Decimal.zero,
          processedNet: Decimal.zero,
          pendingNet: Decimal.zero,
          failedNet: Decimal.parse('50.00'),
        ),
      );
      await tester.pumpWidget(buildScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Failed payouts'), findsOneWidget);
      expect(find.text('\$50.00'), findsOneWidget);
    });
  });
}
