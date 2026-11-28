import 'package:fixo/models/marketplace.dart';
import 'package:fixo/router/notification_route.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/ui/homeowner/ho_home_mapper.dart';
import 'package:fixo/ui/homeowner/ho_job_navigation.dart';
import 'package:fixo/ui/homeowner/ho_quotes_screen.dart'
    show thQuotesCloseLabel;
import 'package:flutter_test/flutter_test.dart';

// Plan 10 (Q2.3-Q2.6): quotes surfaced on cards, home, navigation and push taps.

Job _project({
  String status = 'Requested',
  int stage = 0,
  int? requested,
  int? received,
  String? tradie,
  bool openToBoard = false,
  DateTime? quotesCloseAtUtc,
}) => Job(
  id: '9',
  title: 'Kitchen renovation',
  category: 'Building',
  suburb: 'Grey Lynn',
  status: status,
  stage: stage,
  jobType: Job.jobTypeProject,
  quotesRequested: requested,
  quotesReceived: received,
  matchedTradieName: tradie,
  openToBoard: openToBoard,
  quotesCloseAtUtc: quotesCloseAtUtc,
);

Job _hourly() => const Job(
  id: '1',
  title: 'Fix tap',
  category: 'Plumbing',
  suburb: 'Ponsonby',
  status: 'Requested',
  stage: 0,
);

void main() {
  group('card badge and subtitle', () {
    test('shows Quotes badge and "N of M quotes in"', () {
      final job = _project(requested: 3, received: 2);
      expect(thHomeStatusBadgeForJob(job).label, 'Quotes');
      expect(thHomeStatusBadgeForJob(job).kind, THBadgeKind.ok);
      expect(thHomeJobSubtitle(job), '2 of 3 quotes in');
    });

    test('zero received waits; denominator never below numerator', () {
      expect(
        thHomeJobSubtitle(_project(requested: 3, received: 0)),
        'Waiting for quotes',
      );
      expect(
        thHomeJobSubtitle(_project(requested: 1, received: 2)),
        '2 of 2 quotes in',
      );
    });

    test('without counts or for hourly jobs the old copy is kept', () {
      expect(thHomeStatusBadgeForJob(_project()).label, 'Requested');
      expect(thHomeJobSubtitle(_project()), 'Finding a tradie');
      expect(thHomeStatusBadgeForJob(_hourly()).label, 'Requested');
      expect(thHomeJobSubtitle(_hourly()), 'Finding a tradie');
    });
  });

  group('home attention', () {
    test('a project with a quote waiting is in attention with a hero', () {
      final job = _project(requested: 3, received: 1);
      final groups = HoHomeGroups.from([job]);
      expect(groups.attention, [job]);
      expect(groups.active, isEmpty);
      final hero = thAttentionHero(groups.attention)!;
      expect(hero.headline, 'Review quotes');
      expect(hero.actionLabel, 'Compare');
    });

    test('no quote yet stays in active', () {
      final groups = HoHomeGroups.from([_project(requested: 3, received: 0)]);
      expect(groups.attention, isEmpty);
      expect(groups.active, hasLength(1));
    });
  });

  group('thHomeownerJobPath (D4)', () {
    test('requests sent -> quotes; none sent -> tradie picker', () {
      expect(thHomeownerJobPath(_project(requested: 2)), '/jobs/9/quotes');
      expect(thHomeownerJobPath(_project(requested: 0)), '/jobs/9/tradies');
    });

    test('unknown counts and non-requested statuses are unchanged', () {
      expect(thHomeownerJobPath(_project()), '/jobs/9/matching');
      expect(thHomeownerJobPath(_hourly()), '/jobs/1/matching');
      expect(
        thHomeownerJobPath(_project(status: 'Booked', stage: 1, requested: 3)),
        '/jobs/9/detail',
      );
      expect(
        thHomeownerJobPath(_project(status: 'Cancelled', requested: 3)),
        '/jobs/9/detail',
      );
    });
  });

  group('routeForMessage', () {
    test('quote_submitted opens that job\'s quotes', () {
      expect(
        routeForMessage({'type': 'quote_submitted', 'jobId': '12'}),
        '/jobs/12/quotes',
      );
      expect(
        routeForMessage({'type': 'quote_submitted', 'jobId': 12}),
        '/jobs/12/quotes',
      );
    });

    test('missing jobId or other types use the existing mapping', () {
      expect(routeForMessage({'type': 'quote_submitted'}), '/messages');
      expect(routeForMessage({'type': 'match'}), '/jobs');
      expect(routeForMessage({}), '/messages');
    });
  });

  group('open-board projects (Q7.8 / Q7.9)', () {
    test('subtitle omits "of M" when quotesRequested is null', () {
      final zero = _project(openToBoard: true, received: 0);
      final one = _project(openToBoard: true, received: 1);
      final three = _project(openToBoard: true, received: 3);
      expect(thHomeStatusBadgeForJob(zero).label, 'Quotes');
      expect(thHomeJobSubtitle(zero), 'Waiting for quotes');
      expect(thHomeJobSubtitle(one), '1 quote in');
      expect(thHomeJobSubtitle(three), '3 quotes in');
    });

    test('thHomeownerJobPath routes open-board project straight to quotes', () {
      expect(thHomeownerJobPath(_project(openToBoard: true)), '/jobs/9/quotes');
      expect(
        thHomeownerJobPath(
          _project(quotesCloseAtUtc: DateTime.utc(2026, 11, 30)),
        ),
        '/jobs/9/quotes',
      );
    });

    test('thQuotesCloseLabel formats days, hours, minutes, and closed', () {
      final now = DateTime.utc(2026, 11, 27, 12);
      expect(
        thQuotesCloseLabel(now.add(const Duration(hours: 50)), nowUtc: now),
        'Quotes close in 2 days',
      );
      expect(
        thQuotesCloseLabel(now.add(const Duration(hours: 5)), nowUtc: now),
        'Quotes close in 5 hours',
      );
      expect(
        thQuotesCloseLabel(now.add(const Duration(minutes: 15)), nowUtc: now),
        'Quotes close in 15 minutes',
      );
      expect(
        thQuotesCloseLabel(
          now.subtract(const Duration(minutes: 1)),
          nowUtc: now,
        ),
        'Quotes closed',
      );
      expect(thQuotesCloseLabel(null, nowUtc: now), isNull);
    });
  });
}
