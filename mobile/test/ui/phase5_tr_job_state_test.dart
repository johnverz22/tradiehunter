// Phase 5.3 PR A: v2 tradie job detail routing (`tr_job`).
//
// The selector is a total function over `Job.status`; the router loads once
// and (PR A) hands every state to the injected v1 screen, with its own
// not-found / error states and the v1 loading rules for the contact.
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/tradie/tr_job_router.dart';
import 'package:fixo/ui/tradie/tr_job_state.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

Job _job(String status, {String? disputeStatus}) => Job(
  id: 'j1',
  title: 'Leaking tap',
  category: 'Plumbing',
  suburb: 'Ponsonby',
  status: status,
  stage: 0,
  disputeStatus: disputeStatus,
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
    return const JobContact(userId: 'h1', firstName: 'Sam');
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

  group('status sets (pinned to the v1 tables)', () {
    test('contactable', () {
      expect(trContactableStatuses, {
        'Booked',
        'InProgress',
        'AwaitingConfirmation',
        'Completed',
        'Disputed',
      });
      expect(trIsContactable('Requested'), isFalse);
      expect(trIsContactable('Cancelled'), isFalse);
    });

    test('booked or later shows the address, Disputed does not', () {
      expect(trBookedOrLaterStatuses, {
        'Booked',
        'InProgress',
        'AwaitingConfirmation',
        'Completed',
      });
      expect(trIsBookedOrLater('Disputed'), isFalse);
      expect(trIsBookedOrLater('Requested'), isFalse);
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
            builder: (_, s) => TrJobRouter(
              jobId: s.pathParameters['jobId']!,
              v1Fallback: () => const Scaffold(body: Text('v1 job detail')),
            ),
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
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    for (final status in [
      'Booked',
      'InProgress',
      'AwaitingConfirmation',
      'Completed',
      'Cancelled',
      'Disputed',
      'Requested',
      'SomethingNewFromTheServer',
    ]) {
      testWidgets('$status renders the injected v1 screen', (tester) async {
        await pump(tester, _JobsRepo(job: _job(status)));
        expect(find.text('v1 job detail'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

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
      expect(find.text('v1 job detail'), findsOneWidget);
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
      expect(find.text('v1 job detail'), findsNothing);
    });
  });
}
