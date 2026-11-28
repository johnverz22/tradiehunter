import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/homeowner/ho_post_job_project.dart';
import 'package:fixo/ui/homeowner/ho_quotes_screen.dart';
import 'package:fixo/ui/tradie/tr_available_jobs_screen.dart';
import 'package:fixo/ui/tradie/tr_job_board_detail_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _BoardJobsRepo extends JobsRepository {
  _BoardJobsRepo({this.available = const [], this.job})
    : super(Dio(), const FlutterSecureStorage());

  final List<AvailableJob> available;
  final Job? job;

  @override
  Future<List<ServiceOption>> getServiceCatalog() async => const [];

  @override
  Future<List<AvailableJob>> getAvailableJobs({
    int page = 1,
    int pageSize = 20,
  }) async => available;

  @override
  Future<List<Quote>> getQuotes(String jobId) async => const [];

  @override
  Future<Job?> getJobById(String jobId) async => job;
}

AvailableJob _sampleBoardJob({int? validityHours = 72}) => AvailableJob(
  id: '42',
  title: 'Kitchen renovation',
  category: 'Carpentry',
  description: 'Full kitchen strip-out and new cabinetry.',
  urgency: 'Medium',
  suburb: 'Papamoa',
  distanceKm: 4.2,
  scopeNotes: 'Keep existing island footprint.',
  budgetMin: Decimal.fromInt(15000),
  budgetMax: Decimal.fromInt(25000),
  materialsBy: 'Undecided',
  siteVisitWelcome: true,
  timingPreference: 'Flexible',
  quotesReceived: 2,
  quotesCloseAtUtc: DateTime.now().toUtc().add(const Duration(hours: 50)),
  createdAtUtc: DateTime.now().toUtc(),
  quoteValidityHours: validityHours,
);

void main() {
  testWidgets(
    'HoPostJobProject defaults to Open to nearby tradies and toggles',
    (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(_BoardJobsRepo()),
            themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: ThScope(
                  themeMode: ThemeMode.light,
                  child: Scaffold(
                    body: SingleChildScrollView(child: HoPostJobProject()),
                  ),
                ),
              );
            },
          ),
        ),
      );
      container.read(postJobProvider.notifier).setJobType(Job.jobTypeProject);
      await tester.pumpAndSettle();

      expect(find.text('Open to nearby tradies'), findsOneWidget);
      expect(find.text('Invite tradies'), findsOneWidget);
      expect(container.read(postJobProvider).openToBoard, isTrue);

      await tester.tap(find.byKey(const Key('post_project_invite_pill')));
      await tester.pumpAndSettle();
      expect(container.read(postJobProvider).openToBoard, isFalse);
    },
  );

  testWidgets('HoQuotesScreen shows close countdown for open-board projects', (
    tester,
  ) async {
    final job = Job(
      id: '42',
      title: 'Kitchen renovation',
      category: 'Carpentry',
      suburb: 'Papamoa',
      status: 'Requested',
      stage: 0,
      jobType: Job.jobTypeProject,
      openToBoard: true,
      quotesCloseAtUtc: DateTime.now().toUtc().add(const Duration(hours: 50)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(_BoardJobsRepo(job: job)),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: HoQuotesScreen(jobId: '42')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quotes_close_badge')), findsOneWidget);
    expect(find.text('Quotes close in 2 days'), findsOneWidget);
  });

  testWidgets('TrAvailableJobsScreen renders open projects and empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(
            _BoardJobsRepo(available: [_sampleBoardJob()]),
          ),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: TrAvailableJobsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kitchen renovation'), findsOneWidget);
    expect(find.text('Papamoa · 4.2 km · 2 quotes in'), findsOneWidget);
    expect(find.byKey(const Key('view_board_job_42')), findsOneWidget);
  });

  testWidgets(
    'TrJobBoardDetailScreen renders D7 details and opens quote sheet with validity',
    (tester) async {
      final job = _sampleBoardJob(validityHours: 72);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(_BoardJobsRepo()),
            themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
          ],
          child: MaterialApp(
            home: TrJobBoardDetailScreen(jobId: job.id, initialJob: job),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kitchen renovation'), findsOneWidget);
      expect(find.text('Keep existing island footprint.'), findsOneWidget);
      expect(find.text('Welcome before quoting'), findsOneWidget);
      expect(
        find.text('Quote valid for 72 hours once submitted.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('board_submit_quote_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Valid for 72 hours.'), findsOneWidget);
    },
  );
}
