// Phase 4.1 #2: v2 homeowner jobs list (`ho_jobs`).
//
// Filter rules are tested without widgets; the screen and the role gate are
// tested with faked repositories in light and dark, keeping the v1 behaviour:
// Active / Completed / All filter, empty states, refresh error, card taps.
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/homeowner/ho_jobs_mapper.dart';
import 'package:fixo/ui/homeowner/ho_jobs_screen.dart';
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
  String? tradie,
  String? tradieId,
  Decimal? total,
}) => Job(
  id: id,
  title: title,
  category: 'Plumbing',
  suburb: 'Ponsonby',
  status: status,
  stage: Job.stageForStatus(status, flowVersion: Job.flowVersionV2),
  flowVersion: Job.flowVersionV2,
  matchedTradieName: tradie,
  matchedTradieId: tradieId,
  finalAmount: total,
);

class _JobsRepo extends JobsRepository {
  _JobsRepo(this.jobs, {this.fail = false})
    : super(Dio(), const FlutterSecureStorage());
  final List<Job> jobs;
  bool fail;
  int loads = 0;

  @override
  Future<List<Job>> getMyJobs({String? status}) async {
    loads++;
    if (fail) throw Exception('offline');
    return jobs;
  }
}

class _ProfileRepo extends ProfileRepository {
  _ProfileRepo({this.role = 0, this.fail = false})
    : super(Dio(), const FlutterSecureStorage());
  final int? role;
  bool fail;
  int loads = 0;

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async {
    loads++;
    if (fail) throw Exception('profile offline');
    return {'firstName': 'Mere', if (role != null) 'role': role};
  }
}

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('thFilterHomeownerJobs (same rules as v1)', () {
    final jobs = [
      _job('req', 'Requested'),
      _job('pay', 'AwaitingPayment'),
      _job('dispute', 'Disputed'),
      _job('done', 'Completed'),
      _job('gone', 'Cancelled'),
      _job('late', 'Expired'),
    ];

    test('active hides completed, cancelled and expired', () {
      expect(
        thFilterHomeownerJobs(jobs, HoJobsFilter.active).map((j) => j.id),
        ['req', 'pay', 'dispute'],
      );
    });

    test('completed keeps only Completed', () {
      expect(
        thFilterHomeownerJobs(jobs, HoJobsFilter.completed).map((j) => j.id),
        ['done'],
      );
    });

    test('all keeps everything in server order', () {
      expect(
        thFilterHomeownerJobs(jobs, HoJobsFilter.all).map((j) => j.id),
        ['req', 'pay', 'dispute', 'done', 'gone', 'late'],
      );
    });

    test('empty-state titles', () {
      expect(
        thJobsFilterEmptyTitle(HoJobsFilter.completed),
        'No completed jobs yet',
      );
      expect(thJobsFilterEmptyTitle(HoJobsFilter.active), 'No active jobs');
    });

    test('segment labels match the filter order', () {
      expect(HoJobsFilter.values.map((f) => f.label), [
        'Active',
        'Completed',
        'All',
      ]);
    });
  });

  group('ThJobsScreen', () {
    Future<(GoRouter, _JobsRepo)> pump(
      WidgetTester tester,
      List<Job> jobs, {
      bool dark = false,
      bool fail = false,
      Widget? home,
      _ProfileRepo? profileRepo,
    }) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _JobsRepo(jobs, fail: fail);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home ?? const ThJobsScreen()),
          for (final p in [
            '/jobs/:id/payment',
            '/jobs/:id/detail',
            '/jobs/:id/matching',
            '/jobs/:id/payment/status',
            '/chat/:id',
            '/jobs/new',
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
            jobsRepositoryProvider.overrideWithValue(repo),
            profileRepositoryProvider.overrideWithValue(
              profileRepo ?? _ProfileRepo(),
            ),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (router, repo);
    }

    final sample = [
      _job(
        'c',
        'AwaitingConfirmation',
        title: 'Leaking tap',
        tradie: 'Aroha Plumbing',
        total: Decimal.parse('261'),
      ),
      _job('b', 'Booked', title: 'Hallway', tradie: 'Kiri', tradieId: 't'),
      _job('d', 'Completed', title: 'Old fence'),
      _job('x', 'Cancelled', title: 'Cancelled deck'),
    ];

    for (final dark in [false, true]) {
      testWidgets('renders title, filter and active cards (dark=$dark)', (
        tester,
      ) async {
        await pump(tester, sample, dark: dark);

        expect(find.byKey(const Key('homeowner_jobs')), findsOneWidget);
        expect(find.text('My jobs'), findsOneWidget);
        expect(find.byKey(const Key('jobs_filter')), findsOneWidget);
        expect(find.text('Leaking tap'), findsOneWidget);
        expect(find.text('Hallway'), findsOneWidget);
        expect(find.text('Old fence'), findsNothing);
        expect(find.text('Cancelled deck'), findsNothing);
        expect(find.text(r'$261.00'), findsOneWidget);
        expect(find.byKey(const Key('jobs_chat_b')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('filter switches between Completed and All', (tester) async {
      await pump(tester, sample);

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('Old fence'), findsOneWidget);
      expect(find.text('Leaking tap'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled deck'), findsOneWidget);
      expect(find.text('Leaking tap'), findsOneWidget);
    });

    testWidgets('empty filter offers View all jobs', (tester) async {
      await pump(tester, [_job('d', 'Completed', title: 'Old fence')]);
      expect(find.text('No active jobs'), findsOneWidget);
      expect(find.text('Choose All to see your other jobs.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('jobs_view_all')));
      await tester.pumpAndSettle();
      expect(find.text('Old fence'), findsOneWidget);
      expect(find.byKey(const Key('jobs_filter_empty')), findsNothing);
    });

    testWidgets('completed filter empty copy', (tester) async {
      await pump(tester, [_job('r', 'Requested')]);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('No completed jobs yet'), findsOneWidget);
    });

    testWidgets('cards navigate like v1', (tester) async {
      final (router, _) = await pump(tester, [
        _job('c', 'AwaitingConfirmation', title: 'Leaking tap'),
        _job('p', 'AwaitingPayment', title: 'Pay me'),
        _job('b', 'Booked', title: 'Hallway', tradie: 'Kiri', tradieId: 't'),
      ]);

      await tester.tap(find.text('Leaking tap'));
      await tester.pumpAndSettle();
      expect(find.text('At /jobs/c/detail'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay me'));
      await tester.pumpAndSettle();
      expect(find.text('At /jobs/p/payment'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('jobs_chat_b')));
      await tester.pumpAndSettle();
      expect(find.text('At /chat/b'), findsOneWidget);
    });

    testWidgets('no jobs at all offers Post a job', (tester) async {
      await pump(tester, const []);
      expect(find.text('No jobs yet'), findsOneWidget);
      expect(find.text('Post your first job to get matched.'), findsOneWidget);
      await tester.tap(find.text('Post a job'));
      await tester.pumpAndSettle();
      expect(find.text('At /jobs/new'), findsOneWidget);
    });

    testWidgets('load error with no data shows retry', (tester) async {
      final (_, repo) = await pump(tester, const [], fail: true);
      expect(
        find.text('Could not load your jobs. Please try again.'),
        findsOneWidget,
      );
      final before = repo.loads;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repo.loads, greaterThan(before));
    });

    testWidgets('refresh error keeps the list and shows a notice', (
      tester,
    ) async {
      final (_, repo) = await pump(tester, sample);
      repo.fail = true;
      await tester.drag(find.text('My jobs'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't refresh your jobs."), findsOneWidget);
      expect(find.text('Leaking tap'), findsOneWidget);

      repo.fail = false;
      await tester.tap(find.byKey(const Key('jobs_retry')));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't refresh your jobs."), findsNothing);
    });
  });

  group('ThJobsRoute (role gate)', () {
    const fallback = Scaffold(body: Text('v1 tradie list'));

    testWidgets('homeowner gets the v2 screen', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _JobsRepo([_job('b', 'Booked', title: 'Hallway')]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(repo),
            profileRepositoryProvider.overrideWithValue(_ProfileRepo()),
          ],
          child: const MaterialApp(
            home: ThJobsRoute(tradieFallback: fallback),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homeowner_jobs')), findsOneWidget);
      expect(find.text('Hallway'), findsOneWidget);
      expect(find.text('v1 tradie list'), findsNothing);
    });

    testWidgets('tradie keeps the v1 list and never loads homeowner jobs', (
      tester,
    ) async {
      final repo = _JobsRepo(const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(repo),
            profileRepositoryProvider.overrideWithValue(_ProfileRepo(role: 1)),
          ],
          child: const MaterialApp(
            home: ThJobsRoute(tradieFallback: fallback),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('v1 tradie list'), findsOneWidget);
      expect(find.byKey(const Key('homeowner_jobs')), findsNothing);
      expect(repo.loads, 0);
    });

    testWidgets('unknown role waits instead of loading jobs', (tester) async {
      final repo = _JobsRepo(const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(repo),
            profileRepositoryProvider.overrideWithValue(
              _ProfileRepo(role: null),
            ),
          ],
          child: const MaterialApp(
            home: ThJobsRoute(tradieFallback: fallback),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homeowner_jobs_pending')), findsOneWidget);
      expect(repo.loads, 0);
    });

    testWidgets('profile failure shows retry that reloads the profile', (
      tester,
    ) async {
      final profileRepo = _ProfileRepo(fail: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(_JobsRepo(const [])),
            profileRepositoryProvider.overrideWithValue(profileRepo),
          ],
          child: const MaterialApp(
            home: ThJobsRoute(tradieFallback: fallback),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load your jobs. Please try again.'),
        findsOneWidget,
      );
      final before = profileRepo.loads;
      profileRepo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(profileRepo.loads, greaterThan(before));
      expect(find.byKey(const Key('homeowner_jobs')), findsOneWidget);
    });
  });
}
