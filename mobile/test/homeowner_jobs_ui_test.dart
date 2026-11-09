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
import 'package:fixo/views/homeowner/homeowner_dashboard_view.dart';
import 'package:fixo/views/jobs/jobs_list_screen.dart';
import 'package:fixo/views/widgets/modern_job_card.dart';
import 'package:fixo/views/widgets/homeowner_job_summary.dart';
import 'package:fixo/widgets/fixo_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class JobsFixture extends JobsRepository {
  final List<Job> jobs;
  bool fail = false;
  int loads = 0;
  JobsFixture(this.jobs) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<List<Job>> getMyJobs({String? status}) async {
    loads++;
    if (fail) throw const ProfileApiException('Unavailable');
    return jobs;
  }

  @override
  Future<List<Job>> getTradieJobs({String? status}) => getMyJobs();
}

class ProfileFixture extends ProfileRepository {
  final int role;
  ProfileFixture(this.role) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'id': 'viewer',
    'firstName': '  Sarah  ',
    'role': role,
  };
}

class HubFixture extends JobHubClient {
  final events = StreamController<JobStatusEvent>.broadcast();
  HubFixture() : super(const FlutterSecureStorage());
  @override
  Stream<JobStatusEvent> get onJobStatusChanged => events.stream;
  @override
  Future<void> connect({required String baseUrl}) async {}
  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

Job fixture(String status) => Job(
  id: status,
  title: 'Customer title $status',
  category: 'Plumbing',
  suburb: 'Auckland',
  status: status,
  stage: 0,
  totalAmount: Decimal.parse('123.45'),
  scheduledStartUtc: DateTime.utc(2026, 11, 3, 9),
  hours: 2,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'past and attention classifications preserve all other states as active',
    () {
      for (final status in [
        'Requested',
        'AwaitingPayment',
        'PaymentReview',
        'Booked',
        'InProgress',
        'AwaitingConfirmation',
        'Completed',
        'Cancelled',
        'Expired',
        'Disputed',
        'FutureState',
      ]) {
        expect(
          isPastHomeownerJob(status),
          ['Completed', 'Cancelled', 'Expired'].contains(status),
        );
        expect(
          needsHomeownerAttention(status),
          [
            'AwaitingPayment',
            'PaymentReview',
            'AwaitingConfirmation',
            'Disputed',
          ].contains(status),
        );
      }
    },
  );
  Future<GoRouter> mount(
    WidgetTester tester,
    JobsFixture repo, {
    bool dashboard = false,
    bool dark = false,
    double scale = 1,
    double width = 320,
    int role = 0,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hub = HubFixture();
    addTearDown(hub.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => dashboard
              ? const HomeownerDashboardView()
              : const JobsListScreen(),
        ),
        for (final path in [
          '/jobs/:id/payment',
          '/jobs/:id/payment/status',
          '/jobs/:id/detail',
          '/jobs/:id/matching',
          '/chat/:id',
          '/tradie/jobs/:id',
          '/tradie/requests/:id',
          '/jobs/new',
          '/jobs',
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
          jobsRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(ProfileFixture(role)),
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

  for (final dark in [false, true]) {
    testWidgets('dashboard partitions jobs without duplicates dark=$dark', (
      tester,
    ) async {
      await mount(
        tester,
        JobsFixture([
          fixture('AwaitingPayment'),
          fixture('Booked'),
          fixture('Completed'),
        ]),
        dashboard: true,
        dark: dark,
      );
      expect(find.text('Sarah'), findsOneWidget);
      expect(find.byKey(const Key('homeowner_hero')), findsOneWidget);
      expect(find.text('Booked'), findsNWidgets(2));
      expect(find.text('Open chat'), findsOneWidget);
      expect(find.text('Needs your attention'), findsOneWidget);
      expect(find.text('Customer title AwaitingPayment'), findsOneWidget);
      expect(find.text('Customer title Booked'), findsOneWidget);
      expect(find.text('Customer title Completed'), findsNothing);
      await tester.scrollUntilVisible(find.text('Past jobs (1)'), 500);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Past jobs (1)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Customer title Completed'),
        400,
      );
      expect(find.text('Customer title Completed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filters keep disputed and unknown visible dark=$dark', (
      tester,
    ) async {
      await mount(
        tester,
        JobsFixture([
          fixture('Disputed'),
          fixture('FutureState'),
          fixture('Completed'),
          fixture('Cancelled'),
          fixture('Expired'),
        ]),
        dark: dark,
      );
      expect(find.text('Customer title Disputed'), findsOneWidget);
      await tester.tap(find.text('Completed', skipOffstage: false).first);
      await tester.pumpAndSettle();
      expect(find.text('Customer title Completed'), findsOneWidget);
      expect(find.text('Customer title Disputed'), findsNothing);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Customer title Expired'), 600);
      expect(find.text('Customer title Expired'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in {
    'AwaitingPayment': '/jobs/AwaitingPayment/payment',
    'PaymentReview': '/jobs/PaymentReview/payment/status',
    'AwaitingConfirmation': '/jobs/AwaitingConfirmation/detail',
  }.entries) {
    for (final dashboard in [false, true]) {
      testWidgets('${entry.key} canonical route dashboard=$dashboard', (
        tester,
      ) async {
        await mount(
          tester,
          JobsFixture([fixture(entry.key)]),
          dashboard: dashboard,
        );
        final card = find.byType(ModernJobCard);
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text('Destination ${entry.value}'), findsOneWidget);
      });
    }
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('screens fit narrow text=$scale dark=$dark', (tester) async {
        for (final dashboard in [false, true]) {
          await mount(
            tester,
            JobsFixture([fixture('AwaitingConfirmation')]),
            dashboard: dashboard,
            dark: dark,
            scale: scale,
          );
          expect(find.text(r'$123.45'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.widgetWithText(TextButton, 'Review completion'),
            300,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
    }
  }

  testWidgets('SignalR moves a job into attention without duplicating it', (
    tester,
  ) async {
    await mount(tester, JobsFixture([fixture('Booked')]), dashboard: true);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeownerDashboardView)),
    );
    final hub = container.read(jobHubClientProvider) as HubFixture;
    hub.events.add(
      const JobStatusEvent(jobId: 'Booked', status: 'AwaitingConfirmation'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Needs your attention'), findsOneWidget);
    expect(find.text('Active jobs'), findsNothing);
    expect(find.text('Customer title Booked'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Review completion'),
      findsOneWidget,
    );
    expect(find.byType(StatusBadge), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(hub.events.hasListener, isFalse);
  });

  testWidgets(
    'wide dashboard constrains cards and long titles stay two lines',
    (tester) async {
      await mount(
        tester,
        JobsFixture([
          const Job(
            id: 'long',
            title: 'A very long real customer job title that must remain unchanged even when it needs more than two lines on screen',
            category: '',
            suburb: '',
            status: 'Requested',
            stage: 0,
          ),
        ]),
        dashboard: true,
        width: 1200,
        scale: 2,
      );
      final card = tester.widget<ModernJobCard>(find.byType(ModernJobCard));
      expect(card.priceLabel, isNull);
      expect(card.identityLabel, isNull);
      expect(card.reference, isNull);
      expect(
        tester.getSize(find.byType(ModernJobCard)).width,
        lessThanOrEqualTo(760),
      );
      final title = tester.widget<Text>(find.text(card.title));
      expect(title.maxLines, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dashboard in [false, true]) {
    testWidgets('empty post and initial error retry dashboard=$dashboard', (
      tester,
    ) async {
      final repo = JobsFixture([])..fail = true;
      await mount(tester, repo, dashboard: dashboard);
      expect(find.text('Post a Job'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text(dashboard ? 'Find a tradie you can trust' : 'No jobs yet'),
        findsOneWidget,
      );
      final post = find.text(dashboard ? 'Post a job' : 'Post a Job');
      await tester.ensureVisible(post);
      await tester.tap(post);
      await tester.pumpAndSettle();
      expect(find.text('Destination /jobs/new'), findsOneWidget);
    });
  }

  testWidgets('tradie list retains all jobs and existing detail routing', (
    tester,
  ) async {
    await mount(tester, JobsFixture([fixture('Completed')]), role: 1);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ModernJobCard));
    await tester.pumpAndSettle();
    expect(find.text('Destination /tradie/jobs/Completed'), findsOneWidget);
  });

  testWidgets('cached jobs show refresh failure with retry', (tester) async {
    final repo = JobsFixture([fixture('Booked')]);
    await mount(tester, repo);
    repo.fail = true;
    final element = tester.element(find.byType(JobsListScreen));
    final container = ProviderScope.containerOf(element);
    await container.read(jobsViewModelProvider.notifier).loadHomeownerJobs();
    await tester.pumpAndSettle();
    expect(
      find.text('Could not refresh jobs. Showing previously loaded jobs.'),
      findsOneWidget,
    );
    expect(find.text('Customer title Booked'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.loads, 3);
    expect(
      find.text('Could not refresh jobs. Showing previously loaded jobs.'),
      findsNothing,
    );
  });

  testWidgets('completed filter empty state does not imply no jobs', (
    tester,
  ) async {
    await mount(tester, JobsFixture([fixture('Booked')]));
    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();
    expect(find.text('No completed jobs yet'), findsOneWidget);
    expect(find.text('Post a Job'), findsNothing);
  });

  test('Job model serializes and parses matchedTradieName projection', () {
    final json = {
      'id': 42,
      'title': 'Leaking pipe',
      'category': 'Plumbing',
      'suburb': 'Grafton',
      'status': 'Booked',
      'stage': 2,
      'matchedTradieId': 'tradie-123',
      'matchedTradieName': 'Alex Plumber',
    };
    final job = Job.fromJson(json);
    expect(job.matchedTradieId, 'tradie-123');
    expect(job.matchedTradieName, 'Alex Plumber');
    expect(job.toJson()['matchedTradieName'], 'Alex Plumber');

    final jobWithout = Job.fromJson({
      'id': 43,
      'title': 'Unmatched',
      'category': 'Plumbing',
      'suburb': 'Ponsonby',
      'status': 'Requested',
      'stage': 0,
    });
    expect(jobWithout.matchedTradieName, isNull);
    expect(jobWithout.toJson().containsKey('matchedTradieName'), isFalse);
  });

  testWidgets('card renders real matched tradie identity when present', (
    tester,
  ) async {
    final jobWithTradie = Job(
      id: '50',
      title: 'Fix kitchen tap',
      category: 'Plumbing',
      suburb: 'Auckland Central',
      status: 'Booked',
      stage: 2,
      matchedTradieId: 'tradie-abc',
      matchedTradieName: 'David Builder',
    );
    await mount(tester, JobsFixture([jobWithTradie]));
    expect(find.text('David Builder'), findsOneWidget);
  });
}
