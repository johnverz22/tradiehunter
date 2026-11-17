// Phase 4.1 #1: v2 homeowner home (`ho_home`).
//
// Pure rules (grouping, hero, progress, navigation paths) are tested without
// widgets; the screen is tested with faked repositories + SignalR in light and
// dark, keeping the preserved `homeowner_dashboard` Key.
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/ui/homeowner/ho_home_mapper.dart';
import 'package:fixo/ui/homeowner/ho_home_screen.dart';
import 'package:fixo/ui/homeowner/ho_job_navigation.dart';
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
  int? stage,
  int flowVersion = Job.flowVersionV2,
  String title = 'Fix tap',
  String? tradie,
  String? tradieId,
  DateTime? created,
  Decimal? total,
}) => Job(
  id: id,
  title: title,
  category: 'Plumbing',
  suburb: 'Ponsonby',
  status: status,
  stage: stage ?? Job.stageForStatus(status, flowVersion: flowVersion),
  flowVersion: flowVersion,
  matchedTradieName: tradie,
  matchedTradieId: tradieId,
  createdAtUtc: created,
  finalAmount: total,
);

class _JobsRepo extends JobsRepository {
  _JobsRepo(this.jobs, {this.fail = false})
    : super(Dio(), const FlutterSecureStorage());
  final List<Job> jobs;
  final bool fail;
  int loads = 0;

  @override
  Future<List<Job>> getMyJobs({String? status}) async {
    loads++;
    if (fail) throw Exception('offline');
    return jobs;
  }
}

class _ProfileRepo extends ProfileRepository {
  _ProfileRepo() : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'firstName': 'Mere',
    'role': 0,
  };
}

class _ChatRepo extends ChatRepository {
  _ChatRepo() : super(Dio(), const FlutterSecureStorage());
  @override
  Future<List<ConversationSummary>> getConversations() async => const [];
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

  group('HoHomeGroups', () {
    test('groups like the v1 dashboard and sorts attention by urgency', () {
      final jobs = [
        _job('review', 'PaymentReview'),
        _job('pay', 'AwaitingPayment'),
        _job('confirm', 'AwaitingConfirmation'),
        _job('dispute', 'Disputed'),
        _job('booked', 'Booked'),
        _job('prog', 'InProgress'),
        _job('req', 'Requested'),
        _job('done', 'Completed'),
        _job('gone', 'Cancelled'),
      ];
      final g = HoHomeGroups.from(jobs);
      expect(g.attention.map((j) => j.id), [
        'pay',
        'confirm',
        'dispute',
        'review',
      ]);
      expect(g.booked.map((j) => j.id), ['booked', 'prog']);
      expect(g.active.map((j) => j.id), ['req']);
      expect(g.past.map((j) => j.id), ['done', 'gone']);
    });

    test('same-priority attention jobs go oldest first', () {
      final g = HoHomeGroups.from([
        _job('b', 'AwaitingPayment', created: DateTime.utc(2026, 2, 1)),
        _job('a', 'AwaitingPayment', created: DateTime.utc(2026, 1, 1)),
      ]);
      expect(g.attention.map((j) => j.id), ['a', 'b']);
    });
  });

  group('attention hero', () {
    test('is null when nothing needs attention', () {
      expect(thAttentionHero(const []), isNull);
    });

    test('approve-final-amount copy with priced amount', () {
      final hero = thAttentionHero([
        _job(
          'j1',
          'AwaitingConfirmation',
          title: 'Leaking tap',
          tradie: 'Aroha Plumbing',
          total: Decimal.parse('261'),
        ),
      ])!;
      expect(hero.headline, 'Approve final amount');
      expect(hero.subtitle, 'Leaking tap · Aroha Plumbing');
      expect(hero.actionLabel, 'Review');
      expect(hero.amountLabel, r'$261.00');
    });

    test('unpriced job never shows a zero amount', () {
      final hero = thAttentionHero([_job('j1', 'AwaitingPayment')])!;
      expect(hero.amountLabel, isNull);
      expect(hero.headline, 'Payment due');
    });
  });

  group('progress and badges', () {
    test('v1.7 flow has 6 steps, completed has none pending', () {
      final p = thHomeProgress(_job('a', 'Booked'))!;
      expect((p.steps, p.done, p.current), (6, 2, true));
      final done = thHomeProgress(_job('b', 'Completed'))!;
      expect((done.steps, done.done, done.current), (6, 6, false));
    });

    test('legacy flow keeps the 4-step order', () {
      final p = thHomeProgress(
        _job('a', 'InProgress', flowVersion: Job.flowVersionLegacy),
      )!;
      expect((p.steps, p.done), (4, 3));
    });

    test('terminal states show no progress', () {
      for (final s in ['Cancelled', 'Expired', 'Disputed']) {
        expect(thHomeProgress(_job('a', s)), isNull, reason: s);
      }
    });

    test('unknown status degrades to a neutral badge', () {
      expect(thHomeStatusBadge('Weird').label, 'Status unavailable');
      expect(thHomeStatusBadge('Disputed').kind, THBadgeKind.danger);
    });
  });

  group('thHomeownerJobPath (routes unchanged, plan 4.4)', () {
    test('v1.7 stages', () {
      expect(thHomeownerJobPath(_job('1', 'Requested')), '/jobs/1/matching');
      expect(thHomeownerJobPath(_job('1', 'Booked')), '/jobs/1/detail');
      expect(
        thHomeownerJobPath(_job('1', 'AwaitingConfirmation')),
        '/jobs/1/detail',
      );
      expect(
        thHomeownerJobPath(_job('1', 'AwaitingPayment')),
        '/jobs/1/payment',
      );
      expect(
        thHomeownerJobPath(_job('1', 'PaymentReview')),
        '/jobs/1/payment/status',
      );
      expect(thHomeownerJobPath(_job('1', 'Completed')), '/jobs/1/detail');
    });

    test('terminal and disputed always go to the detail', () {
      for (final s in ['Cancelled', 'Expired', 'Disputed']) {
        expect(thHomeownerJobPath(_job('1', s)), '/jobs/1/detail');
      }
    });

    test('legacy pay-first and unknown fall back as in v1', () {
      expect(
        thHomeownerJobPath(
          _job('1', 'AwaitingPayment', flowVersion: Job.flowVersionLegacy),
        ),
        '/jobs/1/payment',
      );
      expect(thHomeownerJobPath(_job('1', 'Matched')), '/chat/1');
    });
  });

  group('ThHomeScreen', () {
    Future<(GoRouter, _JobsRepo)> pump(
      WidgetTester tester,
      List<Job> jobs, {
      bool dark = false,
      bool fail = false,
    }) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _JobsRepo(jobs, fail: fail);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ThHomeScreen()),
          for (final p in [
            '/jobs/:id/payment',
            '/jobs/:id/detail',
            '/jobs/:id/matching',
            '/chat/:id',
            '/jobs/new',
            '/jobs',
            '/notifications',
            '/find-tradie',
            '/categories',
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
            profileRepositoryProvider.overrideWithValue(_ProfileRepo()),
            chatRepositoryProvider.overrideWithValue(_ChatRepo()),
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
      await tester.pumpAndSettle();
      return (router, repo);
    }

    for (final dark in [false, true]) {
      testWidgets('renders greeting, hero and sections (dark=$dark)', (
        tester,
      ) async {
        await pump(tester, [
          _job(
            'c',
            'AwaitingConfirmation',
            title: 'Leaking tap',
            tradie: 'Aroha Plumbing',
            total: Decimal.parse('261'),
          ),
          _job('b', 'Booked', title: 'Hallway', tradie: 'Kiri', tradieId: 't'),
          _job('r', 'Requested', title: 'Fence'),
        ], dark: dark);

        expect(find.byKey(const Key('homeowner_dashboard')), findsOneWidget);
        expect(find.byKey(const Key('homeowner_hero')), findsOneWidget);
        expect(find.text('Mere'), findsOneWidget);
        expect(find.text('NEEDS YOUR ATTENTION'), findsOneWidget);
        expect(find.text('Approve final amount'), findsOneWidget);
        expect(find.text(r'$261.00'), findsOneWidget);
        expect(find.text('Booked'), findsWidgets);
        expect(find.text('Active jobs'), findsOneWidget);
        expect(find.text('Open chat'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('hero action and cards navigate like v1', (tester) async {
      final (router, _) = await pump(tester, [
        _job('c', 'AwaitingConfirmation', title: 'Leaking tap'),
      ]);
      await tester.tap(find.byKey(const Key('home_hero_action')));
      await tester.pumpAndSettle();
      expect(find.text('At /jobs/c/detail'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      // A job awaiting confirmation is not chat-bookable from the card.
      expect(find.byKey(const Key('home_chat_c')), findsNothing);
    });

    testWidgets('booked job card opens chat', (tester) async {
      await pump(tester, [
        _job('b', 'Booked', title: 'Hallway', tradie: 'Kiri', tradieId: 't'),
      ]);
      await tester.tap(find.byKey(const Key('home_chat_b')));
      await tester.pumpAndSettle();
      expect(find.text('At /chat/b'), findsOneWidget);
    });

    testWidgets('empty state offers Post a job', (tester) async {
      await pump(tester, const []);
      expect(find.text('Find a tradie you can trust'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home_post_job')));
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

    testWidgets('search, category tile and More navigate', (tester) async {
      final (router, _) = await pump(tester, const []);
      await tester.tap(find.byKey(const Key('home_search')));
      await tester.pumpAndSettle();
      expect(find.text('At /find-tradie'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_category_Plumbing')));
      await tester.pumpAndSettle();
      expect(find.text('At /find-tradie'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_category_More')));
      await tester.pumpAndSettle();
      expect(find.text('At /categories'), findsOneWidget);
    });
  });
}
