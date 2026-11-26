// Phase 5.3: v2 tradie job detail routing & pure state rules (`tr_job`).
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/network/external_launcher.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/tradie/tr_job_router.dart';
import 'package:fixo/ui/tradie/tr_job_state.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

Job _job(
  String status, {
  String? disputeStatus,
  DateTime? scheduledStartUtc,
  String? address,
  String? suburb,
}) => Job(
  id: 'j1',
  title: 'Leaking tap',
  category: 'Plumbing',
  suburb: suburb ?? 'Ponsonby',
  address: address ?? '12 Ponsonby Road, Ponsonby',
  status: status,
  stage: 0,
  disputeStatus: disputeStatus,
  scheduledStartUtc: scheduledStartUtc,
);

class _JobsRepo extends JobsRepository {
  _JobsRepo({this.job, this.failLoad = false, this.failContact = false})
    : super(Dio(), const FlutterSecureStorage());
  final Job? job;
  final bool failLoad;
  final bool failContact;
  int contactCalls = 0;
  int adjustmentCalls = 0;

  @override
  Future<Job?> getJobById(String jobId) async {
    if (failLoad) throw Exception('boom');
    return job;
  }

  @override
  Future<JobContact?> getJobContact(String jobId) async {
    contactCalls++;
    if (failContact) throw Exception('no contact');
    return const JobContact(
      userId: 'h1',
      firstName: 'Sam',
      phoneNumber: '021123456',
    );
  }

  @override
  Future<List<JobAdjustment>> getAdjustments(String jobId) async {
    adjustmentCalls++;
    return const <JobAdjustment>[];
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

  group('trSelectJobView', () {
    const expected = <String, TrJobView>{
      'Booked': TrJobView.booked,
      'InProgress': TrJobView.inProgress,
      'AwaitingConfirmation': TrJobView.awaitingConfirmation,
      'Completed': TrJobView.completed,
      'Cancelled': TrJobView.cancelled,
      'Disputed': TrJobView.disputed,
    };

    for (final entry in expected.entries) {
      test('${entry.key} -> ${entry.value.name}', () {
        expect(trSelectJobView(_job(entry.key)), entry.value);
      });
    }

    test('every other status string falls back, never throws', () {
      for (final status in [
        'Requested',
        'Draft',
        'AwaitingPayment',
        'PaymentReview',
        'Expired',
        '',
        'SomethingNewFromTheServer',
      ]) {
        expect(
          trSelectJobView(_job(status)),
          TrJobView.fallback,
          reason: status,
        );
      }
    });

    test('an open dispute wins over the booking state it was raised on', () {
      for (final status in ['Booked', 'InProgress', 'AwaitingConfirmation']) {
        expect(
          trSelectJobView(_job(status, disputeStatus: 'Open')),
          TrJobView.disputed,
          reason: status,
        );
        expect(
          trSelectJobView(_job(status, disputeStatus: 'UnderReview')),
          TrJobView.disputed,
          reason: status,
        );
      }
    });

    test('a resolved dispute does not hide the booking state', () {
      expect(
        trSelectJobView(_job('Booked', disputeStatus: 'Resolved')),
        TrJobView.booked,
      );
    });

    test('Completed and Cancelled stay put even with a dispute attached', () {
      expect(
        trSelectJobView(_job('Completed', disputeStatus: 'Open')),
        TrJobView.completed,
      );
      expect(
        trSelectJobView(_job('Cancelled', disputeStatus: 'Open')),
        TrJobView.cancelled,
      );
    });
  });

  group('pure rules & helpers', () {
    test('status sets (pinned to the v1 tables)', () {
      expect(trContactableStatuses, {
        'Booked',
        'InProgress',
        'AwaitingConfirmation',
        'Completed',
        'Disputed',
      });
      expect(trIsContactable('Requested'), isFalse);
      expect(trIsContactable('Cancelled'), isFalse);

      expect(trBookedOrLaterStatuses, {
        'Booked',
        'InProgress',
        'AwaitingConfirmation',
        'Completed',
      });
      expect(trIsBookedOrLater('Disputed'), isFalse);
      expect(trIsBookedOrLater('Requested'), isFalse);
    });

    test('cancellable, dispute and extra-cost permissions', () {
      expect(trCanCancel('Booked'), isTrue);
      expect(trCanCancel('InProgress'), isTrue);
      expect(trCanCancel('AwaitingConfirmation'), isTrue);
      expect(trCanCancel('Completed'), isFalse);
      expect(trCanCancel('Requested'), isFalse);

      expect(trCanDispute('Booked'), isTrue);
      expect(trCanDispute('InProgress'), isTrue);
      expect(trCanDispute('Completed'), isTrue);
      expect(trCanDispute('Requested'), isFalse);
      expect(trCanDispute('Cancelled'), isFalse);

      expect(trCanRequestExtraCost('Booked'), isTrue);
      expect(trCanRequestExtraCost('InProgress'), isTrue);
      expect(trCanRequestExtraCost('AwaitingConfirmation'), isTrue);
      expect(trCanRequestExtraCost('Completed'), isFalse);
    });

    test('trCanReportNoShow: only Booked and >15 min after scheduled', () {
      final start = DateTime.utc(2026, 11, 25, 10, 0);
      final job = _job('Booked', scheduledStartUtc: start);

      expect(
        trCanReportNoShow(job, DateTime.utc(2026, 11, 25, 10, 10)),
        isFalse,
      );
      expect(
        trCanReportNoShow(job, DateTime.utc(2026, 11, 25, 10, 15)),
        isFalse,
      );
      expect(
        trCanReportNoShow(job, DateTime.utc(2026, 11, 25, 10, 15, 1)),
        isTrue,
      );

      // Not Booked => false
      expect(
        trCanReportNoShow(
          _job('InProgress', scheduledStartUtc: start),
          DateTime.utc(2026, 11, 25, 11, 0),
        ),
        isFalse,
      );

      // No scheduled start => false
      expect(
        trCanReportNoShow(_job('Booked'), DateTime.utc(2026, 11, 25, 11, 0)),
        isFalse,
      );
    });

    test('trApprovedAdjustmentsTotal sums only approved adjustments', () {
      final adjustments = [
        JobAdjustment(
          id: 'a1',
          jobId: 'j1',
          proposedByTradieId: 't1',
          proposedByTradieName: 'Tradie',
          kind: 'Materials',
          description: 'Tap',
          amount: Decimal.parse('50.00'),
          status: 'Approved',
          createdAtUtc: DateTime.utc(2026, 11, 1),
        ),
        JobAdjustment(
          id: 'a2',
          jobId: 'j1',
          proposedByTradieId: 't1',
          proposedByTradieName: 'Tradie',
          kind: 'Travel',
          description: 'Ferry',
          amount: Decimal.parse('30.00'),
          status: 'Pending',
          createdAtUtc: DateTime.utc(2026, 11, 1),
        ),
        JobAdjustment(
          id: 'a3',
          jobId: 'j1',
          proposedByTradieId: 't1',
          proposedByTradieName: 'Tradie',
          kind: 'Other',
          description: 'Extra',
          amount: Decimal.parse('20.00'),
          status: 'Approved',
          createdAtUtc: DateTime.utc(2026, 11, 1),
        ),
      ];

      expect(trApprovedAdjustmentsTotal(adjustments), Decimal.parse('70.00'));
    });

    test('trAddressLabel masks pre-booked address', () {
      final job = _job(
        'Requested',
        address: '12 Secret Lane',
        suburb: 'Ponsonby',
      );
      expect(trAddressLabel(job), 'Ponsonby');

      final booked = _job(
        'Booked',
        address: '12 Secret Lane',
        suburb: 'Ponsonby',
      );
      expect(trAddressLabel(booked), '12 Secret Lane');
    });

    test('trTradieCancelReasons has the 5 expected codes', () {
      final codes = trTradieCancelReasons.map((r) => r.$1).toList();
      expect(codes, [
        'tradie_unavailable',
        'emergency',
        'scope_change_declined',
        'tradie_issue',
        'homeowner_no_show',
      ]);
    });
  });

  group('TrJobRouter', () {
    late _JobsRepo repo;

    Future<void> pump(WidgetTester tester, _JobsRepo jobsRepo) async {
      repo = jobsRepo;
      final router = GoRouter(
        initialLocation: '/tradie/jobs/j1',
        routes: [
          GoRoute(
            path: '/tradie/jobs/:jobId',
            builder: (_, s) => TrJobRouter(jobId: s.pathParameters['jobId']!),
          ),
          GoRoute(
            path: '/tradie',
            builder: (_, _) => const Scaffold(body: Text('At /tradie')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(repo),
            jobHubClientProvider.overrideWithValue(_Hub()),
            externalLauncherProvider.overrideWithValue(ExternalLauncher()),
            localeConfigProvider.overrideWith(
              (ref) async => {'commissionPercent': '10.0'},
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('Booked renders TrJobBookedScreen with check-in button', (
      tester,
    ) async {
      await pump(tester, _JobsRepo(job: _job('Booked')));
      expect(find.byKey(const Key('check_in_button')), findsOneWidget);
      expect(find.text('Ready to start?'), findsOneWidget);
    });

    testWidgets(
      'InProgress renders TrJobInProgressScreen with check-out button',
      (tester) async {
        await pump(tester, _JobsRepo(job: _job('InProgress')));
        expect(find.byKey(const Key('check_out_button')), findsOneWidget);
        expect(find.text('In progress'), findsOneWidget);
      },
    );

    testWidgets('AwaitingConfirmation renders confirmation banner', (
      tester,
    ) async {
      await pump(tester, _JobsRepo(job: _job('AwaitingConfirmation')));
      expect(find.text('Awaiting confirmation'), findsAtLeast(1));
    });

    testWidgets(
      'Completed renders completion view with rate homeowner button',
      (tester) async {
        await pump(tester, _JobsRepo(job: _job('Completed')));
        expect(find.text('Job completed. Thank you!'), findsOneWidget);
      },
    );

    testWidgets('Cancelled renders cancellation banner', (tester) async {
      await pump(tester, _JobsRepo(job: _job('Cancelled')));
      expect(find.text('This job was cancelled.'), findsOneWidget);
    });

    testWidgets('Disputed renders dispute banner', (tester) async {
      await pump(tester, _JobsRepo(job: _job('Disputed')));
      expect(
        find.text('This job has an active dispute under review.'),
        findsOneWidget,
      );
    });

    testWidgets('fallback renders for unrecognized status', (tester) async {
      await pump(tester, _JobsRepo(job: _job('UnknownStatusFromFuture')));
      expect(find.text('UnknownStatusFromFuture'), findsOneWidget);
    });

    testWidgets('contact is fetched only for contactable statuses', (
      tester,
    ) async {
      await pump(tester, _JobsRepo(job: _job('Booked')));
      expect(repo.contactCalls, 1);
      expect(repo.adjustmentCalls, 1);

      await pump(tester, _JobsRepo(job: _job('Requested')));
      expect(repo.contactCalls, 0);
      expect(repo.adjustmentCalls, 1);
    });

    testWidgets('a contact failure never blocks the detail', (tester) async {
      await pump(tester, _JobsRepo(job: _job('Booked'), failContact: true));
      expect(find.byKey(const Key('check_in_button')), findsOneWidget);
    });

    testWidgets('missing job shows the unavailable state and goes back', (
      tester,
    ) async {
      await pump(tester, _JobsRepo(job: null));
      expect(find.text('This job is no longer available'), findsOneWidget);
      await tester.tap(find.text('Back to my jobs'));
      await tester.pumpAndSettle();
      expect(find.text('At /tradie'), findsOneWidget);
    });

    testWidgets('a load failure shows a retryable error', (tester) async {
      await pump(tester, _JobsRepo(failLoad: true));
      expect(find.textContaining('Could not load this job'), findsOneWidget);
    });
  });
}
