import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/ui/homeowner/ho_job_detail_fallback_screen.dart';
import 'package:fixo/ui/homeowner/ho_job_detail_state.dart';
import 'package:fixo/ui/homeowner/ho_review_completion_screen.dart';
import 'package:fixo/ui/homeowner/ho_review_screen.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';

class _JobsFixture extends JobsRepository {
  _JobsFixture() : super(Dio(), const FlutterSecureStorage());
  int approveCalls = 0;

  @override
  Future<void> approveJob(String jobId, {String? note}) async {
    approveCalls++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'completion screen shows server amounts and gates pending extra',
    (tester) async {
      await tester.pumpWidget(
        _app(
          HoReviewCompletionScreen(
            job: _completionJob,
            adjustments: [_pendingAdjustment],
          ),
        ),
      );

      expect(find.text(r'$261.00'), findsNWidgets(2));
      expect(find.text('Replacement cartridge'), findsOneWidget);
      expect(find.text('Approve & pay'), findsOneWidget);
      final approve = tester.widget<THButton>(
        find.byKey(const Key('approve_pay_button')),
      );
      expect(approve.onPressed, isNull);
      expect(find.text('Extra cost request'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    },
  );

  testWidgets('approve is one-shot and continues to the payment route', (
    tester,
  ) async {
    final jobs = _JobsFixture();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HoReviewCompletionScreen(
            job: _completionJob,
            adjustments: const [],
          ),
        ),
        GoRoute(
          path: '/jobs/:id/payment',
          builder: (_, state) =>
              Scaffold(body: Text('Payment ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(jobs),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final approveButton = find.byKey(const Key('approve_pay_button'));
    await tester.tap(approveButton);
    await tester.tap(approveButton);
    await tester.pumpAndSettle();

    expect(jobs.approveCalls, 1);
    expect(find.text('Payment job-1'), findsOneWidget);
  });

  testWidgets('completed review only enables the real rating form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        HoReviewScreen(job: _completedJob, tradie: _tradie, hasReview: false),
      ),
    );

    expect(find.text('Job completed'), findsOneWidget);
    expect(find.byKey(const Key('leave_review_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('leave_review_button')));
    await tester.pumpAndSettle();
    expect(find.text('Review Aroha Plumbing'), findsOneWidget);
    final submit = tester.widget<THButton>(
      find.byKey(const Key('submit_review_button')),
    );
    expect(submit.onPressed, isNotNull);
    await tester.tap(find.byTooltip('5 stars'));
    await tester.pump();
    expect(
      tester
          .widget<THButton>(find.byKey(const Key('submit_review_button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('cancelled and disputed fallback states keep safe navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        HoJobDetailFallbackScreen(
          job: _cancelledJob,
          reason: HoJobDetailFallback.cancelled,
        ),
      ),
    );
    expect(find.text('This job was cancelled'), findsOneWidget);
    expect(find.byKey(const Key('back_to_jobs_button')), findsOneWidget);
  });
}

Widget _app(Widget child) => ProviderScope(
  overrides: [themeModeProvider.overrideWith((ref) => ThemeModeNotifier())],
  child: MaterialApp(home: ThScope(child: child)),
);

final _completionJob = Job(
  id: 'job-1',
  title: 'Repair kitchen tap',
  category: 'Plumbing',
  suburb: 'Tauranga',
  status: 'AwaitingConfirmation',
  stage: 3,
  finalHours: 2.5,
  labourAmount: Decimal.parse('212.50'),
  finalAmount: Decimal.parse('261.00'),
  hourlyRate: Decimal.fromInt(85),
  matchedTradieId: 'tradie-1',
);

final _completedJob = Job(
  id: 'job-1',
  title: 'Repair kitchen tap',
  category: 'Plumbing',
  suburb: 'Tauranga',
  status: 'Completed',
  stage: 5,
  matchedTradieId: 'tradie-1',
  matchedTradieName: 'Aroha Plumbing',
);

final _cancelledJob = Job(
  id: 'job-1',
  title: 'Repair kitchen tap',
  category: 'Plumbing',
  suburb: 'Tauranga',
  status: 'Cancelled',
  stage: 5,
);

final _pendingAdjustment = JobAdjustment(
  id: 'adjustment-1',
  jobId: 'job-1',
  proposedByTradieId: 'tradie-1',
  proposedByTradieName: 'Aroha Plumbing',
  kind: JobAdjustment.kindMaterials,
  description: 'Replacement cartridge',
  amount: Decimal.parse('48.50'),
  status: JobAdjustment.statusPending,
  createdAtUtc: DateTime.utc(2026, 11, 17),
);

const _tradie = UserProfile(
  id: 'tradie-1',
  firstName: 'Aroha',
  lastName: 'Plumbing',
  role: 'Tradie',
  averageRating: null,
  reviewCount: null,
  isVerified: true,
  hasInsurance: false,
);
