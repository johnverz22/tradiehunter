// Phase 5.1: v2 tradie home (`tr_home`).
//
// Pure rules (hero net states, week count, banners, groups) are tested
// without widgets; the screen runs against faked repositories + SignalR in
// light and dark, keeping the preserved v1 Keys.
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/ui/feedback/th_notice_controller.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/tradie/tr_home_mapper.dart';
import 'package:fixo/ui/tradie/tr_home_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

Job _job(
  String id,
  String status, {
  String title = 'Fix tap',
  DateTime? scheduledLocal,
  DateTime? createdLocal,
}) => Job(
  id: id,
  title: title,
  category: 'Plumbing',
  suburb: 'Ponsonby',
  status: status,
  stage: Job.stageForStatus(status, flowVersion: Job.flowVersionV2),
  flowVersion: Job.flowVersionV2,
  scheduledStartUtc: scheduledLocal?.toUtc(),
  createdAtUtc: createdLocal?.toUtc(),
);

JobOffer _offer(String jobId, DateTime expiresUtc) => JobOffer(
  id: 'offer-$jobId',
  jobId: jobId,
  tradieId: 't1',
  offeredAtUtc: expiresUtc.subtract(const Duration(minutes: 15)),
  expiresAtUtc: expiresUtc,
  response: 'Pending',
  stage: 'Auto',
);

TradieEarnings _earnings({Decimal? earned, Decimal? pending}) => TradieEarnings(
  periodStartUtc: DateTime.utc(2026, 11, 22),
  periodEndUtc: DateTime.utc(2026, 11, 29),
  asOfUtc: DateTime.utc(2026, 11, 25),
  timeZone: 'Pacific/Auckland',
  earnedNet: earned,
  pendingNet: pending,
);

class _JobsRepo extends JobsRepository {
  _JobsRepo(this.jobs, {this.offerFor = const {}, this.respondOk = true})
    : super(Dio(), const FlutterSecureStorage());
  final List<Job> jobs;
  final Map<String, JobOffer> offerFor;
  final bool respondOk;
  final List<String> responses = [];

  @override
  Future<List<Job>> getTradieJobs() async => jobs;

  @override
  Future<JobOffer?> getPendingOffer(String jobId) async => offerFor[jobId];

  @override
  Future<bool> respondToOffer(
    String jobId,
    String offerId, {
    required String response,
  }) async {
    responses.add('$jobId:$response');
    return respondOk;
  }
}

class _ProfileRepo extends ProfileRepository {
  _ProfileRepo({this.verified = true, this.failAvailability = false})
    : super(Dio(), const FlutterSecureStorage());
  final bool verified;
  final bool failAvailability;
  final List<bool> availabilityCalls = [];

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'firstName': 'Aroha',
    'role': 1,
    'isVerified': verified,
    'isAvailable': true,
    'online': true,
    'averageRating': 4.9,
    'reviewCount': 128,
  };

  @override
  Future<TradieEarnings> getEarnings() async =>
      _earnings(earned: Decimal.parse('1284.5'));

  @override
  Future<void> updateAvailability(bool isAvailable) async {
    availabilityCalls.add(isAvailable);
    if (failAvailability) throw Exception('offline');
  }
}

class _Hub extends JobHubClient {
  _Hub() : super(const FlutterSecureStorage());
  @override
  Future<void> connect({required String baseUrl}) async {}
}

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('trHeroNet keeps the four v1 states apart', () {
    test('loading with no summary', () {
      expect(
        trHeroNet(const TradieEarningsState(isLoading: true)).kind,
        TrNetKind.loading,
      );
    });
    test('error with no summary', () {
      expect(
        trHeroNet(const TradieEarningsState(error: 'x')).kind,
        TrNetKind.error,
      );
    });
    test('summary without a net figure is unavailable, not zero', () {
      final net = trHeroNet(TradieEarningsState(summary: _earnings()));
      expect(net.kind, TrNetKind.unavailable);
      expect(net.amount, isNull);
    });
    test('a loaded zero stays zero', () {
      final net = trHeroNet(
        TradieEarningsState(summary: _earnings(earned: Decimal.zero)),
      );
      expect(net.kind, TrNetKind.loaded);
      expect(net.amount, Decimal.zero);
    });
    test('error with a stale summary still shows the summary', () {
      final net = trHeroNet(
        TradieEarningsState(
          error: 'x',
          summary: _earnings(earned: Decimal.parse('10')),
        ),
      );
      expect(net.kind, TrNetKind.loaded);
    });
    test('pending is never merged into the weekly figure', () {
      final s = TradieEarningsState(
        summary: _earnings(
          earned: Decimal.parse('100'),
          pending: Decimal.parse('50'),
        ),
      );
      expect(trHeroNet(s).amount, Decimal.parse('100'));
      expect(trPendingNet(s), Decimal.parse('50'));
    });
  });

  group('trWeekJobCount', () {
    // Wednesday 25 Nov 2026: week is Mon 23 Nov to Sun 29 Nov.
    final now = DateTime(2026, 11, 25, 12);
    test('counts booked work and completed jobs inside the week only', () {
      final jobs = [
        _job('a', 'Booked', scheduledLocal: DateTime(2026, 11, 23, 8)),
        _job('b', 'Completed', scheduledLocal: DateTime(2026, 11, 29, 23)),
        _job('c', 'Booked', scheduledLocal: DateTime(2026, 11, 22, 23)),
        _job('d', 'Booked', scheduledLocal: DateTime(2026, 11, 30)),
        _job('e', 'Cancelled', scheduledLocal: DateTime(2026, 11, 24)),
        _job('f', 'Requested', scheduledLocal: DateTime(2026, 11, 24)),
        _job('g', 'Booked'),
      ];
      expect(trWeekJobCount(jobs, now), 2);
    });

    test('unscheduled jobs count by creation date (v1.7 flexible)', () {
      final jobs = [
        _job('a', 'Completed', createdLocal: DateTime(2026, 11, 24, 10)),
        _job('b', 'Completed', createdLocal: DateTime(2026, 11, 30, 10)),
        _job('c', 'Requested', createdLocal: DateTime(2026, 11, 24, 10)),
      ];
      expect(trWeekJobCount(jobs, now), 1);
    });
  });

  test('rating needs a real score and at least one review', () {
    expect(trRating(null), isNull);
    expect(trRating({'averageRating': 4.9, 'reviewCount': 0}), isNull);
    expect(trRating({'averageRating': 0, 'reviewCount': 3}), isNull);
    expect(trRating({'averageRating': 4.86, 'reviewCount': 12})?.score, '4.9');
  });

  test('verification banner waits for the profile to load', () {
    expect(
      trShowVerificationBanner(profileLoading: true, isVerified: null),
      isFalse,
    );
    expect(
      trShowVerificationBanner(profileLoading: false, isVerified: null),
      isTrue,
    );
    expect(
      trShowVerificationBanner(profileLoading: false, isVerified: true),
      isFalse,
    );
  });

  test('offline confirm only with leads or booked work', () {
    expect(trNeedsOfflineConfirm([_job('a', 'Completed')]), isFalse);
    expect(trNeedsOfflineConfirm([_job('a', 'Requested')]), isTrue);
    expect(trNeedsOfflineConfirm([_job('a', 'InProgress')]), isTrue);
  });

  group('screen', () {
    late GoRouter router;
    late _JobsRepo jobsRepo;
    late _ProfileRepo profileRepo;

    Future<void> pump(
      WidgetTester tester,
      List<Job> jobs, {
      Map<String, JobOffer> offers = const {},
      bool dark = false,
      bool verified = true,
      bool respondOk = true,
      bool failAvailability = false,
    }) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      jobsRepo = _JobsRepo(jobs, offerFor: offers, respondOk: respondOk);
      profileRepo = _ProfileRepo(
        verified: verified,
        failAvailability: failAvailability,
      );
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TradieHomeScreen()),
          for (final p in [
            '/tradie/requests/:id',
            '/tradie/jobs/:id',
            '/tradie/onboarding',
          ])
            GoRoute(
              path: p,
              builder: (_, s) => Scaffold(body: Text('At ${s.uri.path}')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(jobsRepo),
            profileRepositoryProvider.overrideWithValue(profileRepo),
            jobHubClientProvider.overrideWithValue(_Hub()),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    for (final dark in [false, true]) {
      testWidgets('renders hero, stats and sections (dark=$dark)', (
        tester,
      ) async {
        final today = DateTime.now();
        await pump(tester, [
          _job(
            'b',
            'Booked',
            title: 'Gas hob',
            scheduledLocal: DateTime(today.year, today.month, today.day, 23),
          ),
          _job('d', 'Disputed', title: 'Repaint'),
        ], dark: dark);
        // Profile load is async: let it settle.
        await ref(tester).read(profileViewModelProvider.notifier).loadProfile();
        await tester.pump();

        expect(find.byKey(const Key('tradie_dashboard')), findsOneWidget);
        expect(find.byKey(const Key('availability_button')), findsOneWidget);
        expect(find.text('Net this week'), findsOneWidget);
        expect(find.text('Jobs this week'), findsOneWidget);
        expect(find.byKey(const Key('stat_tile_rating')), findsOneWidget);
        expect(find.byKey(const Key('today_card_cta')), findsOneWidget);
        expect(find.text('Needs attention'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a lapsed lead shows no live accept control', (tester) async {
      await pump(tester, [_job('r1', 'Requested', title: 'Fence')]);
      expect(find.text('Fence'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(jobsRepo.responses, isEmpty);
    });

    testWidgets('accept sends exactly one POST and refetches', (tester) async {
      final expires = DateTime.now().toUtc().add(const Duration(minutes: 10));
      await pump(
        tester,
        [_job('r1', 'Requested', title: 'Fence')],
        offers: {'r1': _offer('r1', expires)},
      );
      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(jobsRepo.responses, ['r1:Accepted']);
    });

    testWidgets('rejected accept shows the v1 notice copy', (tester) async {
      final expires = DateTime.now().toUtc().add(const Duration(minutes: 10));
      await pump(
        tester,
        [_job('r1', 'Requested', title: 'Fence')],
        offers: {'r1': _offer('r1', expires)},
        respondOk: false,
      );
      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // THNotice publishes to the notice provider; the host is mounted by
      // the app root, so assert on the provider state here.
      expect(
        ref(tester).read(thNoticeProvider)?.message,
        'Could not accept — please try again.',
      );
    });

    testWidgets('going offline with a lead asks first; cancel keeps online', (
      tester,
    ) async {
      final expires = DateTime.now().toUtc().add(const Duration(minutes: 10));
      await pump(
        tester,
        [_job('r1', 'Requested')],
        offers: {'r1': _offer('r1', expires)},
      );
      await ref(tester).read(profileViewModelProvider.notifier).loadProfile();
      await tester.pump();
      await tester.tap(find.byKey(const Key('availability_button')));
      await tester.pumpAndSettle();
      expect(find.text('Go offline?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(profileRepo.availabilityCalls, isEmpty);

      await tester.tap(find.byKey(const Key('availability_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go offline'));
      await tester.pumpAndSettle();
      expect(profileRepo.availabilityCalls, [false]);
      expect(
        find.text(
          'You’re currently paused. Toggle back on to receive new job offers.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('going offline with no work needs no confirm', (tester) async {
      await pump(tester, [_job('c', 'Completed')]);
      await ref(tester).read(profileViewModelProvider.notifier).loadProfile();
      await tester.pump();
      await tester.tap(find.byKey(const Key('availability_button')));
      await tester.pumpAndSettle();
      expect(find.text('Go offline?'), findsNothing);
      expect(profileRepo.availabilityCalls, [false]);
    });

    testWidgets('verification banner links to the setup wizard', (
      tester,
    ) async {
      await pump(tester, [_job('c', 'Completed')], verified: false);
      await ref(tester).read(profileViewModelProvider.notifier).loadProfile();
      await tester.pump();
      expect(find.text('Not verified yet'), findsOneWidget);
      await tester.ensureVisible(find.text('Review my setup'));
      await tester.tap(find.text('Review my setup'));
      await tester.pumpAndSettle();
      expect(find.text('At /tradie/onboarding'), findsOneWidget);
    });

    testWidgets('survives 200% text on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      jobsRepo = _JobsRepo([_job('c', 'Completed')]);
      profileRepo = _ProfileRepo();
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TradieHomeScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(jobsRepo),
            profileRepositoryProvider.overrideWithValue(profileRepo),
            jobHubClientProvider.overrideWithValue(_Hub()),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Container of the pumped app, for loading the profile deterministically.
ProviderContainer ref(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TradieHomeScreen)));
