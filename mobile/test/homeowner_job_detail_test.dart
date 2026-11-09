import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/views/homeowner/homeowner_job_detail_screen.dart';
import 'package:fixo/views/widgets/job_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _JobsFixture extends JobsRepository {
  Job? job;
  int loads = 0;
  int confirmCalls = 0;
  int cancelCalls = 0;
  bool confirmResult = true;

  _JobsFixture(this.job) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Job?> getJobById(String jobId) async {
    loads++;
    return job;
  }

  @override
  Future<bool> confirmCompletion(String jobId) async {
    confirmCalls++;
    return confirmResult;
  }

  @override
  Future<bool> cancelJobWithReason(
    String jobId, {
    required String reasonCode,
    String? notes,
  }) async {
    cancelCalls++;
    return true;
  }

  @override
  Future<JobContact?> getJobContact(String jobId) async => null;
}

class _ReviewsFixture extends ReviewsRepository {
  UserProfile? profile;
  int profileCalls = 0;

  _ReviewsFixture({this.profile}) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<UserProfile?> getProfile(String userId) async {
    profileCalls++;
    return profile;
  }
}

class _ProfileFixture extends ProfileRepository {
  _ProfileFixture() : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'id': 'viewer',
    'firstName': 'Sarah',
    'role': 0,
  };
}

class _HubFixture extends JobHubClient {
  final events = StreamController<JobStatusEvent>.broadcast();
  _HubFixture() : super(const FlutterSecureStorage());
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

Job _job(
  String status, {
  String? tradieId,
  String? disputeStatus,
  DateTime? scheduled,
}) => Job(
  id: '42',
  title: 'Fix leaking tap',
  category: 'Plumbing',
  suburb: 'Grafton',
  status: status,
  stage: 0,
  description: 'Kitchen tap drips constantly.',
  address: '70 Symonds Street, Grafton, Auckland',
  matchedTradieId: tradieId,
  disputeStatus: disputeStatus,
  hourlyRate: Decimal.parse('85.50'),
  totalAmount: Decimal.parse('171.00'),
  hours: 2,
  scheduledStartUtc: scheduled ?? DateTime.utc(2026, 11, 3, 9),
);

UserProfile _tradie() => const UserProfile(
  id: 't-1',
  firstName: 'Mike',
  lastName: 'Rangi',
  role: 'Tradie',
  averageRating: 4.6,
  reviewCount: 12,
  tradeType: 'Plumber',
  businessName: 'Rangi Plumbing',
  isVerified: true,
  hasInsurance: false,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<GoRouter> mount(
    WidgetTester tester,
    _JobsFixture jobs, {
    _ReviewsFixture? reviews,
    _HubFixture? hub,
    bool dark = false,
    double scale = 1,
    double width = 320,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = hub ?? _HubFixture();
    addTearDown(h.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const HomeownerJobDetailScreen(jobId: '42'),
        ),
        for (final path in [
          '/jobs/:id/payment',
          '/jobs/:id/payment/status',
          '/jobs/:id/matching',
          '/jobs/:id/dispute',
          '/chat/:id',
          '/tradie/:id',
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
          profileRepositoryProvider.overrideWithValue(_ProfileFixture()),
          reviewsRepositoryProvider.overrideWithValue(
            reviews ?? _ReviewsFixture(),
          ),
          jobHubClientProvider.overrideWithValue(h),
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

  group('state-aware primary action', () {
    testWidgets('Requested offers View matching status', (tester) async {
      await mount(tester, _JobsFixture(_job('Requested')));
      await tester.tap(find.text('View matching status'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /jobs/42/matching'), findsOneWidget);
    });

    testWidgets('AwaitingPayment offers Continue to payment', (tester) async {
      await mount(
        tester,
        _JobsFixture(_job('AwaitingPayment', tradieId: 't-1')),
      );
      expect(find.text('Continue to payment'), findsOneWidget);
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /jobs/42/payment'), findsOneWidget);
    });

    testWidgets('PaymentReview offers View payment status', (tester) async {
      await mount(
        tester,
        _JobsFixture(_job('PaymentReview', tradieId: 't-1')),
      );
      await tester.tap(find.text('View payment status'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /jobs/42/payment/status'), findsOneWidget);
    });

    testWidgets('Booked with matched tradie offers Open Chat', (tester) async {
      await mount(
        tester,
        _JobsFixture(_job('Booked', tradieId: 't-1')),
        reviews: _ReviewsFixture(profile: _tradie()),
      );
      expect(find.text('Open Chat'), findsOneWidget);
    });

    testWidgets('Booked without matched tradie shows no chat action', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Booked')));
      expect(find.text('Open Chat'), findsNothing);
      expect(find.byTooltip('Open chat'), findsNothing);
    });

    testWidgets('AwaitingConfirmation exposes Confirm Completion', (
      tester,
    ) async {
      final jobs = _JobsFixture(_job('AwaitingConfirmation', tradieId: 't-1'));
      await mount(tester, jobs);
      expect(find.text('Confirm Completion'), findsOneWidget);
      await tester.tap(find.text('Confirm Completion'));
      await tester.pumpAndSettle();
      expect(jobs.confirmCalls, 1);
    });

    testWidgets(
      'AwaitingConfirmation with open dispute disables Confirm Completion',
      (tester) async {
        final jobs = _JobsFixture(
          _job('AwaitingConfirmation', tradieId: 't-1', disputeStatus: 'Open'),
        );
        await mount(tester, jobs);
        expect(find.text('Confirm Completion'), findsOneWidget);
        expect(
          find.textContaining('cannot be confirmed while a dispute is open'),
          findsOneWidget,
        );
        // Tapping disabled button does not trigger confirm
        await tester.tap(find.text('Confirm Completion'));
        await tester.pumpAndSettle();
        expect(jobs.confirmCalls, 0);
      },
    );

    testWidgets('Completed without review offers Leave a Review', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Completed', tradieId: 't-1')));
      expect(find.text('Leave a Review'), findsOneWidget);
    });

    testWidgets('Cancelled shows no action bar and no chat affordance', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Cancelled', tradieId: 't-1')));
      expect(find.text('Open Chat'), findsNothing);
      expect(find.byTooltip('Open chat'), findsNothing);
      expect(find.text('Confirm Completion'), findsNothing);
      expect(find.text('Leave a Review'), findsNothing);
      expect(find.text('This job was cancelled.'), findsWidgets);
    });

    testWidgets('Disputed routes to the dispute screen', (tester) async {
      await mount(
        tester,
        _JobsFixture(_job('Disputed', tradieId: 't-1', disputeStatus: 'Open')),
      );
      expect(find.text('View dispute'), findsOneWidget);
      await tester.tap(find.text('View dispute'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /jobs/42/dispute'), findsOneWidget);
    });
  });

  group('tradie identity and contact', () {
    testWidgets('shows matched tradie mini-card with truthful fields', (
      tester,
    ) async {
      await mount(
        tester,
        _JobsFixture(_job('Booked', tradieId: 't-1')),
        reviews: _ReviewsFixture(profile: _tradie()),
      );
      expect(find.text('Mike Rangi'), findsOneWidget);
      expect(find.textContaining('Plumber'), findsWidgets);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Insured'), findsNothing);
      expect(find.textContaining('4.6'), findsOneWidget);
      expect(find.text('View profile'), findsOneWidget);
    });

    testWidgets('new tradie with zero reviews never renders a 0.0 rating', (
      tester,
    ) async {
      await mount(
        tester,
        _JobsFixture(_job('Booked', tradieId: 't-1')),
        reviews: _ReviewsFixture(
          profile: const UserProfile(
            id: 't-1',
            firstName: 'Aroha',
            lastName: 'Ngata',
            role: 'Tradie',
            averageRating: null,
            reviewCount: 0,
            tradeType: 'Plumber',
          ),
        ),
      );
      expect(find.text('Aroha Ngata'), findsOneWidget);
      expect(find.textContaining('0.0'), findsNothing);
    });

    testWidgets('profile fetch failure shows no fabricated name', (
      tester,
    ) async {
      await mount(
        tester,
        _JobsFixture(_job('Booked', tradieId: 't-1')),
        reviews: _ReviewsFixture(profile: null),
      );
      expect(find.text('View profile'), findsOneWidget);
      expect(find.text('Mike Rangi'), findsNothing);
    });

    testWidgets('View profile opens the public tradie profile', (tester) async {
      await mount(
        tester,
        _JobsFixture(_job('Booked', tradieId: 't-1')),
        reviews: _ReviewsFixture(profile: _tradie()),
      );
      await tester.tap(find.text('View profile'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /tradie/t-1'), findsOneWidget);
    });

    testWidgets('no tradie card when job has no match', (tester) async {
      await mount(tester, _JobsFixture(_job('Requested')));
      expect(find.text('View profile'), findsNothing);
    });
  });

  group('single banner and cancellation policy', () {
    testWidgets('dispute banner wins over status banner — one banner only', (
      tester,
    ) async {
      await mount(
        tester,
        _JobsFixture(_job('Booked', tradieId: 't-1', disputeStatus: 'Open')),
      );
      expect(
        find.text('This job has an active dispute under review.'),
        findsOneWidget,
      );
      // The Booked status guidance must not stack a second banner.
      expect(find.textContaining('is booked'), findsNothing);
    });

    testWidgets('dispute banner never appears on Completed or Cancelled jobs', (
      tester,
    ) async {
      await mount(
        tester,
        _JobsFixture(_job('Completed', tradieId: 't-1', disputeStatus: 'Open')),
      );
      expect(
        find.text('This job has an active dispute under review.'),
        findsNothing,
      );
      expect(find.textContaining('Job complete'), findsOneWidget);

      await mount(
        tester,
        _JobsFixture(_job('Cancelled', tradieId: 't-1', disputeStatus: 'Open')),
      );
      expect(
        find.text('This job has an active dispute under review.'),
        findsNothing,
      );
      expect(find.text('This job was cancelled.'), findsWidgets);
    });

    testWidgets('job not found shows friendly recovery with back and support', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(null));
      expect(find.text("We couldn't find this job"), findsOneWidget);
      expect(find.text('Back to my jobs'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('cancellation fee lives in a collapsible policy section', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Booked', tradieId: 't-1')));
      await tester.scrollUntilVisible(find.text('Cancellation policy'), 400);
      expect(find.text('Cancellation policy'), findsOneWidget);
      expect(find.textContaining('10% platform fee'), findsNothing);
      await tester.tap(find.text('Cancellation policy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('10% platform fee'), findsOneWidget);
    });

    testWidgets(
      'cancel sheet repeats the status-specific warning before confirming',
      (tester) async {
        await mount(tester, _JobsFixture(_job('Booked', tradieId: 't-1')));
        await tester.tap(find.byTooltip('Cancel job'));
        await tester.pumpAndSettle();
        // Warning is visible even though the page policy section is collapsed.
        expect(find.textContaining('10% platform fee'), findsOneWidget);
        expect(find.text('Confirm Cancellation'), findsOneWidget);
      },
    );

    testWidgets('in-progress warning mentions hours already worked', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('InProgress', tradieId: 't-1')));
      await tester.tap(find.byTooltip('Cancel job'));
      await tester.pumpAndSettle();
      expect(find.textContaining('hours already worked'), findsOneWidget);
    });
  });

  group('live status refresh', () {
    testWidgets('SignalR status event reloads the job', (tester) async {
      final jobs = _JobsFixture(_job('Booked', tradieId: 't-1'));
      final hub = _HubFixture();
      await mount(tester, jobs, hub: hub);
      expect(jobs.loads, 1);
      jobs.job = _job('AwaitingConfirmation', tradieId: 't-1');
      hub.events.add(
        const JobStatusEvent(jobId: '42', status: 'AwaitingConfirmation'),
      );
      await tester.pumpAndSettle();
      expect(jobs.loads, greaterThan(1));
      expect(find.text('Confirm Completion'), findsOneWidget);
    });
  });

  group('terminal job routing', () {
    testWidgets('cancelled and disputed cards route to detail, not chat', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () =>
                        openHomeownerJob(context, _job('Cancelled')),
                    child: const Text('open cancelled'),
                  ),
                  TextButton(
                    onPressed: () => openHomeownerJob(
                      context,
                      _job('Disputed', disputeStatus: 'Open'),
                    ),
                    child: const Text('open disputed'),
                  ),
                  TextButton(
                    onPressed: () => openHomeownerJob(context, _job('Expired')),
                    child: const Text('open expired'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/jobs/:id/detail',
            builder: (_, state) =>
                Scaffold(body: Text('detail ${state.uri.path}')),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (_, state) =>
                Scaffold(body: Text('chat ${state.uri.path}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('open cancelled'));
      await tester.pumpAndSettle();
      expect(find.text('detail /jobs/42/detail'), findsOneWidget);
      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.text('open disputed'));
      await tester.pumpAndSettle();
      expect(find.text('detail /jobs/42/detail'), findsOneWidget);
      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.text('open expired'));
      await tester.pumpAndSettle();
      expect(find.text('detail /jobs/42/detail'), findsOneWidget);
    });
  });

  group('responsive layout', () {
    for (final dark in [false, true]) {
      testWidgets('320px wide at 2x text scale overflows nowhere dark=$dark', (
        tester,
      ) async {
        await mount(
          tester,
          _JobsFixture(_job('Booked', tradieId: 't-1')),
          reviews: _ReviewsFixture(profile: _tradie()),
          dark: dark,
          scale: 2.0,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Mike Rangi'), findsOneWidget);
      });
    }
  });
}
