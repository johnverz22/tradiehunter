import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/router/notification_route.dart';
import 'package:fixo/services/local_notifications.dart';
import 'package:fixo/ui/tradie/tr_incoming_offer_screen.dart';
import 'package:fixo/viewmodels/incoming_offer_queue.dart';

JobOffer _offer(
  String id, {
  required DateTime expiresAt,
  String jobId = '1',
  String response = 'Pending',
  DateTime? serverNow,
}) => JobOffer(
  id: id,
  jobId: jobId,
  tradieId: 'tr-1',
  offeredAtUtc: expiresAt.subtract(const Duration(minutes: 30)),
  expiresAtUtc: expiresAt,
  response: response,
  stage: 'Direct',
  serverNowUtc: serverNow,
);

void main() {
  final now = DateTime.utc(2026, 11, 28, 12);

  group('IncomingOfferQueue', () {
    test('replaceAll keeps live pending offers, earliest expiry first', () {
      final queue = const IncomingOfferQueue().replaceAll([
        _offer('late', expiresAt: now.add(const Duration(minutes: 20))),
        _offer('soon', expiresAt: now.add(const Duration(minutes: 5))),
        _offer(
          'done',
          expiresAt: now.add(const Duration(minutes: 9)),
          response: 'Declined',
        ),
        _offer('stale', expiresAt: now.subtract(const Duration(seconds: 1))),
      ], deviceNow: now);

      expect(queue.offers.map((o) => o.id), ['soon', 'late']);
      expect(queue.head?.id, 'soon');
    });

    test('server clock offset corrects a fast device clock', () {
      // Device thinks it is 12:10 but the server says 12:00 → 10 min fast.
      final device = now.add(const Duration(minutes: 10));
      final offer = _offer(
        'a',
        expiresAt: now.add(const Duration(minutes: 5)),
        serverNow: now,
      );
      final queue = const IncomingOfferQueue().replaceAll([
        offer,
      ], deviceNow: device);

      expect(queue.isEmpty, isFalse);
      expect(queue.remaining(offer, device), const Duration(minutes: 5));
    });

    test('offset is kept when a refetch carries no server time', () {
      final device = now.add(const Duration(minutes: 10));
      final first = const IncomingOfferQueue().replaceAll([
        _offer(
          'a',
          expiresAt: now.add(const Duration(minutes: 5)),
          serverNow: now,
        ),
      ], deviceNow: device);
      final second = first.replaceAll([
        _offer('b', expiresAt: now.add(const Duration(minutes: 8))),
      ], deviceNow: device);

      expect(second.clockOffset, first.clockOffset);
      expect(second.offers.single.id, 'b');
    });

    test('upsert de-duplicates by offer id', () {
      final a = _offer('a', expiresAt: now.add(const Duration(minutes: 5)));
      final queue = const IncomingOfferQueue()
          .upsert(a, deviceNow: now)
          .upsert(a, deviceNow: now);

      expect(queue.length, 1);
    });

    test('removeOffer and removeJob', () {
      final queue = const IncomingOfferQueue().replaceAll([
        _offer('a', jobId: '1', expiresAt: now.add(const Duration(minutes: 5))),
        _offer('b', jobId: '2', expiresAt: now.add(const Duration(minutes: 6))),
        _offer('c', jobId: '2', expiresAt: now.add(const Duration(minutes: 7))),
      ], deviceNow: now);

      expect(queue.removeOffer('a').offers.map((o) => o.id), ['b', 'c']);
      expect(queue.removeJob('2').offers.map((o) => o.id), ['a']);
      expect(identical(queue.removeOffer('zzz'), queue), isTrue);
    });

    test('pruneExpired drops lapsed offers and is a no-op otherwise', () {
      final queue = const IncomingOfferQueue().replaceAll([
        _offer('a', expiresAt: now.add(const Duration(seconds: 30))),
        _offer('b', expiresAt: now.add(const Duration(minutes: 10))),
      ], deviceNow: now);

      final later = now.add(const Duration(minutes: 1));
      expect(queue.pruneExpired(later).offers.map((o) => o.id), ['b']);
      expect(identical(queue.pruneExpired(now), queue), isTrue);
    });

    test('remaining never goes negative', () {
      final offer = _offer(
        'a',
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(const IncomingOfferQueue().remaining(offer, now), Duration.zero);
    });
  });

  group('JobOffer.fromJson', () {
    test('reads serverNowUtc when present', () {
      final offer = JobOffer.fromJson({
        'id': 1,
        'jobId': 2,
        'tradieId': 't',
        'offeredAtUtc': '2026-11-28T12:00:00Z',
        'expiresAtUtc': '2026-11-28T12:30:00Z',
        'serverNowUtc': '2026-11-28T12:00:05Z',
      });
      expect(offer.serverNowUtc, DateTime.utc(2026, 11, 28, 12, 0, 5));
    });

    test('serverNowUtc is null when absent', () {
      final offer = JobOffer.fromJson({
        'id': 1,
        'jobId': 2,
        'tradieId': 't',
        'offeredAtUtc': '2026-11-28T12:00:00Z',
        'expiresAtUtc': '2026-11-28T12:30:00Z',
      });
      expect(offer.serverNowUtc, isNull);
    });
  });

  group('incomingCountdownLabel', () {
    test('formats m:ss and clamps at zero', () {
      expect(
        incomingCountdownLabel(const Duration(minutes: 14, seconds: 5)),
        '14:05',
      );
      expect(incomingCountdownLabel(const Duration(seconds: 59)), '0:59');
      expect(incomingCountdownLabel(const Duration(seconds: -4)), '0:00');
    });
  });

  group('notification routing', () {
    test('incoming-request push opens the full-screen alert', () {
      expect(
        routeForMessage({'channel': 'incoming_requests', 'jobId': '7'}),
        '/tradie/incoming',
      );
    });

    test('other pushes are unchanged', () {
      expect(routeForMessage({'type': 'chat'}), '/messages');
      expect(
        routeForMessage({'type': 'quote_submitted', 'jobId': '9'}),
        '/jobs/9/quotes',
      );
    });
  });

  group('LocalNotifications.channelFor', () {
    test('explicit channel wins, then type, then job updates', () {
      expect(
        LocalNotifications.channelFor({
          'channel': 'incoming_requests',
          'type': 'chat',
        }),
        LocalNotifications.incomingRequestsChannel,
      );
      expect(
        LocalNotifications.channelFor({'type': 'chat'}),
        LocalNotifications.chatChannel,
      );
      expect(
        LocalNotifications.channelFor({'type': 'job_status'}),
        LocalNotifications.jobUpdatesChannel,
      );
      expect(
        LocalNotifications.channelFor(const {}),
        LocalNotifications.jobUpdatesChannel,
      );
    });
  });
}
