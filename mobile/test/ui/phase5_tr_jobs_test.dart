import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/tradie/tr_job_providers.dart';
import 'package:fixo/ui/tradie/tr_jobs_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';

class _FakeJobsNotifier extends JobsNotifier {
  _FakeJobsNotifier(JobsState initial) : super(_DummyJobsRepo()) {
    state = initial;
  }

  @override
  Future<void> loadTradieJobs() async {}
}

class _Hub extends JobHubClient {
  _Hub() : super(const FlutterSecureStorage());
  @override
  Future<void> connect({required String baseUrl}) async {}
}

class _DummyJobsRepo implements JobsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Job _job({
  required String id,
  required String status,
  DateTime? scheduledStartUtc,
}) => Job(
  id: id,
  title: 'Fix tap $id',
  description: 'Leaking tap',
  category: 'Plumbing',
  status: status,
  stage: 0,
  suburb: 'Ponsonby',
  hourlyRate: Decimal.fromInt(90),
  createdAtUtc: DateTime.utc(2026, 1, 1),
  scheduledStartUtc: scheduledStartUtc,
);

void main() {
  test('filterTradieJobs and groupTradieJobsByDay bucket jobs', () {
    final now = DateTime(2026, 11, 25, 10, 0);
    final jobs = [
      _job(
        id: '1',
        status: 'Booked',
        scheduledStartUtc: DateTime(2026, 11, 25, 14, 0).toUtc(),
      ),
      _job(
        id: '2',
        status: 'Booked',
        scheduledStartUtc: DateTime(2026, 11, 26, 9, 0).toUtc(),
      ),
      _job(id: '3', status: 'AwaitingPayment'),
      _job(id: '4', status: 'Completed'),
    ];

    expect(filterTradieJobs(jobs, TrJobFilter.today, now).map((j) => j.id), [
      '1',
    ]);
    expect(filterTradieJobs(jobs, TrJobFilter.upcoming, now).map((j) => j.id), [
      '2',
    ]);
    expect(
      filterTradieJobs(jobs, TrJobFilter.awaitingPayment, now).map((j) => j.id),
      ['3'],
    );
    expect(filterTradieJobs(jobs, TrJobFilter.done, now).map((j) => j.id), [
      '4',
    ]);
    expect(filterTradieJobs(jobs, TrJobFilter.all, now).length, 4);

    final groups = groupTradieJobsByDay(jobs, now, newestFirst: false);
    expect(groups.map((g) => g.label), ['Today', 'Tomorrow', 'Unscheduled']);
  });

  testWidgets('renders filter row and empty state when no jobs', (
    tester,
  ) async {
    final vm = _FakeJobsNotifier(const JobsState(jobs: []));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobsViewModelProvider.overrideWith((ref) => vm)],
        child: const MaterialApp(home: TrJobsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tradie_filter_row')), findsOneWidget);
    expect(find.text('Nothing scheduled today'), findsOneWidget);
  });

  group('wide master-detail (plan 5.10, wide_layout)', () {
    final cancelled = _job(id: '2', status: 'Cancelled');

    Widget app({required bool? wide}) {
      final vm = _FakeJobsNotifier(JobsState(jobs: [cancelled]));
      return ProviderScope(
        overrides: [
          jobsViewModelProvider.overrideWith((ref) => vm),
          jobHubClientProvider.overrideWithValue(_Hub()),
          trJobDetailProvider('2').overrideWith(
            (ref) async => TrJobDetailData(
              job: cancelled,
              contact: null,
              adjustments: const [],
            ),
          ),
        ],
        // No static MediaQuery: width must follow tester.view so resizes
        // are seen by the screen.
        child: MaterialApp(home: TrJobsScreen(wideLayoutOverride: wide)),
      );
    }

    Future<void> showAll(WidgetTester tester) async {
      final chip = find.widgetWithText(ChoiceChip, 'All');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('360: single pane, no detail placeholder', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(wide: true));
      await tester.pumpAndSettle();
      expect(find.text('Select a job'), findsNothing);
    });

    for (final w in [744.0, 1024.0, 1280.0]) {
      testWidgets('$w: list + empty detail, selecting a job fills the pane '
          'without a nested dock', (tester) async {
        tester.view.physicalSize = Size(w, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(wide: true));
        await tester.pumpAndSettle();
        expect(find.text('Select a job'), findsOneWidget);

        await showAll(tester);
        await tester.tap(find.text('Fix tap 2'));
        await tester.pumpAndSettle();

        expect(find.text('Select a job'), findsNothing);
        expect(find.byKey(const ValueKey('tradie_job_2')), findsOneWidget);
        expect(find.byKey(const Key('dock_jobs')), findsNothing);
      });
    }

    testWidgets('flag off at 1024: stays single pane', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(wide: false));
      await tester.pumpAndSettle();
      expect(find.text('Select a job'), findsNothing);
    });

    testWidgets('resize wide -> narrow clears the selection', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(wide: true));
      await tester.pumpAndSettle();
      await showAll(tester);
      await tester.tap(find.text('Fix tap 2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tradie_job_2')), findsOneWidget);

      tester.view.physicalSize = const Size(360, 900);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tradie_job_2')), findsNothing);
      expect(find.text('Select a job'), findsNothing);
    });
  });
}
