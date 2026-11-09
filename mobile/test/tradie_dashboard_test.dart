// V15-13: tradie dashboard (T19) + jobs list (T20) — truthful metrics,
// field-ready lead cards, local-day buckets and exceptional-state access.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/jobs/jobs_list_screen.dart';
import 'package:fixo/views/tradie/tradie_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class JobsFixture extends JobsRepository {
  final List<Job> jobs;
  final Map<String, JobOffer?> offers;
  final responded = <({String jobId, String offerId, String response})>[];
  int jobLoads = 0;
  bool respondOk = true;

  JobsFixture(this.jobs, {this.offers = const {}})
    : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<Job>> getTradieJobs() async {
    jobLoads++;
    return jobs;
  }

  @override
  Future<JobOffer?> getPendingOffer(String jobId) async => offers[jobId];

  @override
  Future<bool> respondToOffer(
    String jobId,
    String offerId, {
    required String response,
  }) async {
    responded.add((jobId: jobId, offerId: offerId, response: response));
    return respondOk;
  }
}

class ProfileFixture extends ProfileRepository {
  final TradieEarnings? earnings;
  final bool earningsFail;
  int earningsLoads = 0;
  final Map<String, dynamic> profileMap;

  ProfileFixture({
    this.earnings,
    this.earningsFail = false,
    this.profileMap = const {},
  }) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'id': 'tradie-1',
    'firstName': 'Jay',
    'role': 1,
    'isVerified': true,
    'isAvailable': true,
    ...profileMap,
  };

  @override
  Future<TradieEarnings> getEarnings() async {
    earningsLoads++;
    if (earningsFail) throw const ProfileApiException('Unavailable');
    if (earnings != null) return earnings!;
    return TradieEarnings(
      periodStartUtc: DateTime.utc(2026, 7, 5, 12),
      periodEndUtc: DateTime.utc(2026, 7, 12, 12),
      asOfUtc: DateTime.utc(2026, 7, 8),
      timeZone: 'Pacific/Auckland',
      earnedNet: Decimal.parse('437.50'),
      processedNet: Decimal.parse('210.00'),
      pendingNet: Decimal.parse('87.50'),
      failedNet: Decimal.zero,
    );
  }

  @override
  Future<void> updateAvailability(bool isAvailable) async {}
}

class HubFixture extends JobHubClient {
  final statusEvents = StreamController<JobStatusEvent>.broadcast();
  final offerEvents = StreamController<OfferLifecycleEvent>.broadcast();
  HubFixture() : super(const FlutterSecureStorage());
  @override
  Stream<JobStatusEvent> get onJobStatusChanged => statusEvents.stream;
  @override
  Stream<OfferLifecycleEvent> get onOfferLifecycle => offerEvents.stream;
  @override
  Future<void> connect({required String baseUrl}) async {}
  @override
  void dispose() {
    statusEvents.close();
    offerEvents.close();
    super.dispose();
  }
}

Job jobFixture(
  String status, {
  DateTime? scheduled,
  Decimal? total,
  String? description,
}) => Job(
  id: status,
  title: 'Job $status',
  category: 'Plumbing',
  suburb: 'Ponsonby',
  status: status,
  stage: 0,
  totalAmount: total,
  scheduledStartUtc: scheduled,
  hours: 2,
  description: description,
);

JobOffer offerFixture(String jobId, Duration remaining) => JobOffer(
  id: 'offer-$jobId',
  jobId: jobId,
  tradieId: 'tradie-1',
  offeredAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  expiresAtUtc: DateTime.now().toUtc().add(remaining),
  response: 'Pending',
  stage: 'Auto',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('local-day helpers', () {
    final now = DateTime(2026, 7, 8, 15, 30); // Wednesday 3:30 pm local

    test('isScheduledOnOrBeforeToday buckets jobs correctly', () {
      expect(
        isScheduledOnOrBeforeToday(
          jobFixture('Booked', scheduled: DateTime.utc(2026, 7, 8, 2)),
          now,
        ),
        isTrue,
      );
      expect(
        isScheduledOnOrBeforeToday(
          jobFixture('Booked', scheduled: DateTime.utc(2026, 7, 7, 22)),
          now,
        ),
        isTrue,
      );
      expect(
        isScheduledOnOrBeforeToday(
          jobFixture('Booked', scheduled: DateTime.utc(2026, 7, 10, 9)),
          now,
        ),
        isFalse,
      );
      // No schedule is treated as due now so booked work is never hidden.
      expect(isScheduledOnOrBeforeToday(jobFixture('Booked'), now), isTrue);
    });

    test('tradieDayGroups labels and orders local days', () {
      final jobs = [
        jobFixture('A', scheduled: DateTime(now.year, now.month, now.day, 9)),
        jobFixture('B', scheduled: DateTime(now.year, now.month, now.day + 1)),
        jobFixture('C', scheduled: DateTime(now.year, now.month, now.day - 2)),
        jobFixture('D'),
      ];
      final ascending = tradieDayGroups(jobs, now, newestFirst: false);
      // Order: oldest day first, then today, tomorrow, unscheduled last.
      expect(ascending[0].jobs.single.id, 'C');
      expect(ascending[1].label, 'Today');
      expect(ascending[1].jobs.single.id, 'A');
      expect(ascending[2].label, 'Tomorrow');
      expect(ascending[2].jobs.single.id, 'B');
      expect(ascending[3].label, 'Unscheduled');
      expect(ascending[3].jobs.single.id, 'D');

      final descending = tradieDayGroups(jobs, now, newestFirst: true);
      expect(descending[0].label, 'Tomorrow');
      expect(descending[1].label, 'Today');
    });
  });

  group('TradieEarnings.fromJson', () {
    test('parses decimal strings without float conversion', () {
      final e = TradieEarnings.fromJson({
        'periodStartUtc': '2026-07-05T12:00:00Z',
        'periodEndUtc': '2026-07-12T12:00:00Z',
        'asOfUtc': '2026-07-08T00:00:00Z',
        'timeZone': 'Pacific/Auckland',
        'earnedNet': '437.50',
        'processedNet': '210.00',
        'pendingNet': '0.00',
        'failedNet': '7.25',
      });
      expect(e.earnedNet, Decimal.parse('437.50'));
      expect(e.pendingNet, Decimal.zero);
      expect(e.failedNet, Decimal.parse('7.25'));
      expect(e.periodStartUtc.isUtc, isTrue);
    });

    test('missing amounts stay null rather than zero', () {
      final e = TradieEarnings.fromJson({
        'periodStartUtc': '2026-07-05T12:00:00Z',
        'periodEndUtc': '2026-07-12T12:00:00Z',
        'asOfUtc': '2026-07-08T00:00:00Z',
        'earnedNet': null,
      });
      expect(e.earnedNet, isNull);
      expect(e.pendingNet, isNull);
    });
  });

  Future<GoRouter> mountDashboard(
    WidgetTester tester,
    JobsFixture jobs,
    ProfileFixture profile, {
    bool dark = false,
    double scale = 1,
    double width = 320,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hub = HubFixture();
    addTearDown(hub.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TradieDashboardView()),
        for (final path in [
          '/tradie/requests/:id',
          '/tradie/jobs/:id',
          '/tradie/onboarding',
        ])
          GoRoute(
            path: path,
            builder: (_, state) =>
                Scaffold(body: Text('Destination ${state.uri.path}')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(jobs),
          profileRepositoryProvider.overrideWithValue(profile),
          jobHubClientProvider.overrideWithValue(hub),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  group('stat tiles', () {
    testWidgets('earned net, pending and rating render truthfully', (
      tester,
    ) async {
      await mountDashboard(
        tester,
        JobsFixture([]),
        ProfileFixture(profileMap: {'reviewCount': 12, 'averageRating': 4.6}),
      );
      expect(find.text(r'$437.50'), findsOneWidget);
      expect(find.text('Net this week'), findsOneWidget);
      expect(find.text(r'Pending $87.50'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('12 reviews'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('zero reviews shows no rating, never a fabricated 0.0', (
      tester,
    ) async {
      await mountDashboard(
        tester,
        JobsFixture([]),
        ProfileFixture(profileMap: {'reviewCount': 0, 'averageRating': 0}),
      );
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      // Fabricated legacy stats must be gone entirely.
      expect(find.text('Avg Response'), findsNothing);
      expect(find.text('Active Jobs'), findsNothing);
      await unmount(tester);
    });

    testWidgets('earnings failure is distinct from a real zero and retries', (
      tester,
    ) async {
      final profile = ProfileFixture(earningsFail: true);
      await mountDashboard(tester, JobsFixture([]), profile);
      expect(find.text('Unavailable — tap to retry'), findsOneWidget);
      expect(find.text(r'$0.00'), findsNothing);
      profile.earningsLoads = 0;
      await tester.tap(find.text('Unavailable — tap to retry'));
      await tester.pumpAndSettle();
      expect(profile.earningsLoads, greaterThan(0));
      await unmount(tester);
    });

    testWidgets('null earned amount renders unavailable, not zero', (
      tester,
    ) async {
      await mountDashboard(
        tester,
        JobsFixture([]),
        ProfileFixture(
          earnings: TradieEarnings(
            periodStartUtc: DateTime.utc(2026, 7, 5, 12),
            periodEndUtc: DateTime.utc(2026, 7, 12, 12),
            asOfUtc: DateTime.utc(2026, 7, 8),
            timeZone: 'Pacific/Auckland',
            earnedNet: null,
            pendingNet: null,
          ),
        ),
      );
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text(r'$0.00'), findsNothing);
      await unmount(tester);
    });
  });

  group('leads', () {
    final lead = jobFixture(
      'Requested',
      scheduled: DateTime.now().add(const Duration(days: 1)).toUtc(),
      total: Decimal.parse('255.00'),
      description: 'Fix the leaking laundry tap and check the waste pipe.',
    );

    testWidgets('lead card shows evaluable details and offer expiry', (
      tester,
    ) async {
      await mountDashboard(
        tester,
        JobsFixture(
          [lead],
          offers: {
            'Requested': offerFixture(
              'Requested',
              const Duration(hours: 2, minutes: 14),
            ),
          },
        ),
        ProfileFixture(),
      );
      expect(find.text('New leads'), findsOneWidget);
      expect(find.text('Job Requested'), findsOneWidget);
      expect(find.text(r'$255.00'), findsOneWidget);
      expect(find.textContaining('Ponsonby'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^2:1[34]:')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('accept dispatches one authorized offer response', (
      tester,
    ) async {
      final jobs = JobsFixture(
        [lead],
        offers: {
          'Requested': offerFixture('Requested', const Duration(hours: 2)),
        },
      );
      await mountDashboard(tester, jobs, ProfileFixture());
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(jobs.responded, hasLength(1));
      expect(jobs.responded.single.response, 'Accepted');
      expect(jobs.responded.single.offerId, 'offer-Requested');
      await unmount(tester);
    });

    testWidgets('decline dispatches a decline response', (tester) async {
      final jobs = JobsFixture(
        [lead],
        offers: {
          'Requested': offerFixture('Requested', const Duration(hours: 2)),
        },
      );
      await mountDashboard(tester, jobs, ProfileFixture());
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(jobs.responded.single.response, 'Declined');
      await unmount(tester);
    });

    testWidgets('expired offer disables actions instead of pretending live', (
      tester,
    ) async {
      final jobs = JobsFixture(
        [lead],
        offers: {
          'Requested': offerFixture('Requested', const Duration(minutes: -5)),
        },
      );
      await mountDashboard(tester, jobs, ProfileFixture());
      expect(find.text('Expired'), findsOneWidget);
      final accept = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Accept'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(accept.onPressed, isNull);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(jobs.responded, isEmpty);
      await unmount(tester);
    });

    testWidgets('tapping a lead opens the request detail', (tester) async {
      await mountDashboard(
        tester,
        JobsFixture(
          [lead],
          offers: {
            'Requested': offerFixture('Requested', const Duration(hours: 2)),
          },
        ),
        ProfileFixture(),
      );
      await tester.tap(find.text('Job Requested'));
      await tester.pumpAndSettle();
      expect(
        find.text('Destination /tradie/requests/Requested'),
        findsOneWidget,
      );
      await unmount(tester);
    });
  });

  group('sections', () {
    testWidgets('today/upcoming/awaiting/disputed partition without loss', (
      tester,
    ) async {
      final now = DateTime.now();
      await mountDashboard(
        tester,
        JobsFixture([
          jobFixture(
            'Booked',
            scheduled: DateTime.utc(now.year, now.month, now.day, 9),
          ),
          jobFixture(
            'InProgress',
            scheduled: DateTime.utc(now.year, now.month, now.day + 3, 9),
          ),
          jobFixture(
            'AwaitingPayment',
            scheduled: DateTime.utc(now.year, now.month, now.day + 2),
          ),
          jobFixture(
            'Disputed',
            scheduled: DateTime.utc(now.year, now.month, now.day - 1),
          ),
        ]),
        ProfileFixture(),
      );
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Job Booked'), findsOneWidget);
      // Collapsed sections exist but their cards are offstage.
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Awaiting homeowner payment (1)'), findsOneWidget);
      // Disputed surfaces expanded — it must never be buried.
      expect(find.text('Needs attention (1)'), findsOneWidget);
      expect(find.text('Job Disputed'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('unverified tradie sees the setup route, not job panic', (
      tester,
    ) async {
      await mountDashboard(
        tester,
        JobsFixture([]),
        ProfileFixture(profileMap: {'isVerified': false}),
      );
      expect(find.text('Not verified yet'), findsOneWidget);
      await tester.tap(find.text('Review my setup'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /tradie/onboarding'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('jobs list filters', () {
    Future<GoRouter> mountList(
      WidgetTester tester,
      JobsFixture jobs,
      ProfileFixture profile,
    ) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const JobsListScreen()),
          for (final path in ['/tradie/requests/:id', '/tradie/jobs/:id'])
            GoRoute(
              path: path,
              builder: (_, state) =>
                  Scaffold(body: Text('Destination ${state.uri.path}')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(jobs),
            profileRepositoryProvider.overrideWithValue(profile),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: FixoTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    List<Job> listJobs() {
      final now = DateTime.now();
      return [
        jobFixture(
          'Requested',
          scheduled: DateTime.utc(now.year, now.month, now.day, 8),
        ),
        jobFixture(
          'Booked',
          scheduled: DateTime.utc(now.year, now.month, now.day, 10),
        ),
        jobFixture(
          'InProgress',
          scheduled: DateTime.utc(now.year, now.month, now.day + 2, 9),
        ),
        jobFixture(
          'AwaitingPayment',
          scheduled: DateTime.utc(now.year, now.month, now.day + 1),
        ),
        jobFixture(
          'Completed',
          scheduled: DateTime.utc(now.year, now.month, now.day - 1),
        ),
        jobFixture(
          'Cancelled',
          scheduled: DateTime.utc(now.year, now.month, now.day - 2),
        ),
      ];
    }

    testWidgets('Today shows only today booked work', (tester) async {
      await mountList(tester, JobsFixture(listJobs()), ProfileFixture());
      expect(find.text('Job Booked'), findsOneWidget);
      expect(find.text('Job Requested'), findsNothing);
      expect(find.text('Job InProgress'), findsNothing);
      expect(find.text('Job Completed'), findsNothing);
    });

    testWidgets('Awaiting payment and Done filters isolate states', (
      tester,
    ) async {
      await mountList(tester, JobsFixture(listJobs()), ProfileFixture());
      await tester.tap(find.text('Awaiting payment'));
      await tester.pumpAndSettle();
      expect(find.text('Job AwaitingPayment'), findsOneWidget);
      expect(find.text('Job Booked'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Job Completed'), findsOneWidget);
      expect(find.text('Job AwaitingPayment'), findsNothing);
    });

    testWidgets('All retains leads and exceptional states with day groups', (
      tester,
    ) async {
      await mountList(tester, JobsFixture(listJobs()), ProfileFixture());
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      // Newest-first: the Tomorrow day-group header tops the list.
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Job Requested'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Job Completed'), 600);
      expect(find.text('Job Completed'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Job Cancelled'), 600);
      expect(find.text('Job Cancelled'), findsOneWidget);
    });

    testWidgets('Requested routes to offer screen, others to job detail', (
      tester,
    ) async {
      await mountList(
        tester,
        JobsFixture([jobFixture('Requested'), jobFixture('AwaitingPayment')]),
        ProfileFixture(),
      );
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Job AwaitingPayment'));
      await tester.pumpAndSettle();
      expect(
        find.text('Destination /tradie/jobs/AwaitingPayment'),
        findsOneWidget,
      );
    });
  });

  for (final dark in [false, true]) {
    testWidgets('dashboard fits 320px at 2x text dark=$dark', (tester) async {
      final now = DateTime.now();
      await mountDashboard(
        tester,
        JobsFixture(
          [
            jobFixture(
              'Requested',
              scheduled: DateTime.utc(now.year, now.month, now.day + 1, 9),
              total: Decimal.parse('255.00'),
              description: 'Fix the leaking laundry tap.',
            ),
            jobFixture(
              'Booked',
              scheduled: DateTime.utc(now.year, now.month, now.day, 9),
            ),
          ],
          offers: {
            'Requested': offerFixture('Requested', const Duration(hours: 2)),
          },
        ),
        ProfileFixture(profileMap: {'reviewCount': 3, 'averageRating': 4.2}),
        dark: dark,
        scale: 2,
      );
      await tester.scrollUntilVisible(find.text('New leads'), 400);
      await tester.scrollUntilVisible(find.text('Accept'), 400);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
