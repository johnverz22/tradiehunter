// Phase 5.8: tradie own-profile summary labels (rating, rates, credentials).
import 'package:decimal/decimal.dart';
import 'package:fixo/models/tradie_onboarding.dart';
import 'package:fixo/ui/tradie/tr_profile_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TradieRateEntry _rate(int id, String hourly) => TradieRateEntry(
  serviceId: id,
  serviceName: 'Service $id',
  hourlyRate: Decimal.parse(hourly),
);

TradieCredential _cred(int id, String status) => TradieCredential(
  id: id,
  type: 'License',
  originalFileName: 'doc$id.pdf',
  status: status,
);

void main() {
  group('trRatingLabel', () {
    test('score and count', () {
      expect(trRatingLabel(4.8, 12), '4.8 · 12 reviews');
      expect(trRatingLabel(5, 1), '5.0 · 1 review');
    });

    test('no reviews never shows a zero rating', () {
      expect(trRatingLabel(0, 0), 'No reviews yet');
      expect(trRatingLabel(null, null), 'No reviews yet');
      expect(trRatingLabel(4.5, 0), 'No reviews yet');
    });
  });

  group('trRatesSummary', () {
    test('empty is "Not set"', () {
      expect(trRatesSummary(const []), 'Not set');
    });

    test('single service', () {
      expect(trRatesSummary([_rate(1, '80')]), r'1 service · $80.00/hr');
    });

    test('range across services, order independent', () {
      expect(
        trRatesSummary([_rate(1, '95'), _rate(2, '60'), _rate(3, '75.5')]),
        r'3 services · $60.00–$95.00/hr',
      );
    });

    test('equal rates collapse to one figure', () {
      expect(
        trRatesSummary([_rate(1, '70'), _rate(2, '70')]),
        r'2 services · $70.00/hr',
      );
    });
  });

  group('trCredentialsSummary', () {
    test('empty', () {
      expect(trCredentialsSummary(const []), 'None uploaded');
    });

    test('buckets by status and skips zero buckets', () {
      expect(
        trCredentialsSummary([
          _cred(1, 'Approved'),
          _cred(2, 'Approved'),
          _cred(3, 'Pending'),
          _cred(4, 'Rejected'),
        ]),
        '2 approved · 1 pending · 1 rejected',
      );
      expect(trCredentialsSummary([_cred(1, 'Pending')]), '1 pending');
    });

    test('unknown statuses fall back to a plain count', () {
      expect(trCredentialsSummary([_cred(1, 'Weird')]), '1 uploaded');
    });
  });

  test('trSummaryOr covers loading, error and data', () {
    expect(
      trSummaryOr<int>(const AsyncValue.loading(), (d) => '$d'),
      'Loading…',
    );
    expect(
      trSummaryOr<int>(AsyncValue.error('x', StackTrace.empty), (d) => '$d'),
      'Unavailable',
    );
    expect(trSummaryOr<int>(const AsyncValue.data(3), (d) => 'n=$d'), 'n=3');
  });
}
