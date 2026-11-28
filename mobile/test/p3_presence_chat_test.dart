import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/homeowner/ho_choose_tradie_mapper.dart';

void main() {
  group('P3 TradieListEntry & presence labels', () {
    test(
      'fromJson parses online and lastSeenAtUtc; defaults online to false',
      () {
        final online = TradieListEntry.fromJson({
          'tradieId': 'tr-1',
          'name': 'Alex',
          'initials': 'AL',
          'distanceKm': 2.0,
          'online': true,
          'lastSeenAtUtc': '2026-11-28T11:58:00Z',
        });
        expect(online.online, isTrue);
        expect(online.lastSeenAtUtc, DateTime.utc(2026, 11, 28, 11, 58));

        final missing = TradieListEntry.fromJson({
          'tradieId': 'tr-2',
          'name': 'Sam',
          'initials': 'SA',
          'distanceKm': 3.0,
        });
        expect(missing.online, isFalse);
        expect(missing.lastSeenAtUtc, isNull);
      },
    );

    test('thTradiePresenceLabel formats Online now vs Active N min ago', () {
      final now = DateTime.utc(2026, 11, 28, 12, 0);

      final recent = TradieListEntry(
        tradieId: '1',
        name: 'A',
        initials: 'A',
        distanceKm: 1,
        online: true,
        lastSeenAtUtc: now.subtract(const Duration(seconds: 45)),
      );
      expect(thTradiePresenceLabel(recent, now), 'Online now');

      final active = TradieListEntry(
        tradieId: '2',
        name: 'B',
        initials: 'B',
        distanceKm: 1,
        online: true,
        lastSeenAtUtc: now.subtract(const Duration(minutes: 5)),
      );
      expect(thTradiePresenceLabel(active, now), 'Active 5 min ago');

      const offline = TradieListEntry(
        tradieId: '3',
        name: 'C',
        initials: 'C',
        distanceKm: 1,
        online: false,
      );
      expect(thTradiePresenceLabel(offline, now), isNull);
    });
  });
}
