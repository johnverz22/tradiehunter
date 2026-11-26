// Phase 4.1 #3: v2 Post a Job (`ho_post_job`, covers ho_post_quick and
// ho_post_project). Mapper rules are tested without widgets; the screen is
// exercised through the same viewmodel and repositories as v1, including the
// payload-equivalence check for both modes.
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/address.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/address_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/homeowner/ho_post_job_mapper.dart';
import 'package:fixo/ui/homeowner/ho_post_job_screen.dart';
import 'package:fixo/ui/homeowner/ho_choose_tradie_screen.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/viewmodels/address_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

const _service = ServiceOption(id: 1, name: 'Plumbing', category: 'Plumber');
const _address = AddressCandidate(
  id: 'linz:1',
  address: '42 Queen Street, Auckland',
  latitude: -36.8485,
  longitude: 174.7633,
);
const _results = AddressSearchResult(
  provider: 'LINZ',
  attribution: 'LINZ Data Service',
  attributionUrl: 'https://data.linz.govt.nz',
  items: [_address],
);

class _JobsFake extends JobsRepository {
  _JobsFake() : super(Dio(), const FlutterSecureStorage());

  Map<String, dynamic>? posted;
  int posts = 0;
  bool failPost = false;
  String postError = 'Server validation failed';
  bool failUpload = false;
  int uploads = 0;
  int matchStarts = 0;
  bool matchStartResult = true;

  @override
  Future<List<TradieListEntry>> getTradieList(
    String jobId, {
    String sort = 'best',
    bool? verified,
    bool? insured,
    bool? availableNow,
  }) async => [];

  @override
  Future<bool> triggerMatch(String jobId) async {
    matchStarts++;
    return matchStartResult;
  }

  @override
  Future<List<ServiceOption>> getServiceCatalog() async => [_service];

  @override
  Future<String> postJob(Map<String, dynamic> data) async {
    if (failPost) throw ProfileApiException(postError);
    posts++;
    posted = data;
    return 'job-1';
  }

  @override
  Future<List<String>> uploadPhotos(
    String jobId,
    List<String> filePaths,
  ) async {
    uploads++;
    if (failUpload) throw StateError('private transport detail');
    return ['photo'];
  }
}

class _AddressFake extends AddressRepository {
  _AddressFake() : super(Dio(), const FlutterSecureStorage());

  AddressSearchResult result = _results;
  Object? error;
  AddressCandidate? cached;
  final queries = <String>[];

  @override
  Future<AddressSearchResult> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<AddressCandidate?> loadCachedAddress() async => cached;

  @override
  Future<void> cacheAddress(AddressCandidate address) async {
    cached = address;
  }
}

class _ProfileFake extends ProfileRepository {
  _ProfileFake({this.role = 0}) : super(Dio(), const FlutterSecureStorage());

  final dynamic role;

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'id': 'user-1',
    'role': role,
  };
}

GoRouter _router({Widget? screen}) => GoRouter(
  initialLocation: '/post',
  routes: [
    GoRoute(
      path: '/post',
      builder: (_, _) => screen ?? const ThPostJobScreen(),
    ),
    GoRoute(
      path: '/tradie',
      builder: (_, _) => const Scaffold(body: Text('Tradie Dashboard')),
    ),
    GoRoute(
      path: '/jobs/:id/tradies',
      builder: (_, state) =>
          ThChooseTradieScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jobs/:id/matching',
      builder: (_, state) =>
          Scaffold(body: Text('Matching ${state.pathParameters['id']}')),
    ),
  ],
);

Widget _harness({
  required _JobsFake jobs,
  required _AddressFake addresses,
  required _ProfileFake profile,
  required GoRouter router,
  bool dark = false,
  double scale = 1,
}) => ProviderScope(
  overrides: [
    jobsRepositoryProvider.overrideWithValue(jobs),
    addressRepositoryProvider.overrideWithValue(addresses),
    profileRepositoryProvider.overrideWithValue(profile),
  ],
  child: MaterialApp.router(
    theme: dark ? THTheme.dark : THTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    routerConfig: router,
  ),
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _JobsFake jobs,
  required _AddressFake addresses,
  _ProfileFake? profile,
  Widget? screen,
  bool dark = false,
  double scale = 1,
  Size size = const Size(390, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _harness(
      jobs: jobs,
      addresses: addresses,
      profile: profile ?? _ProfileFake(),
      router: _router(screen: screen),
      dark: dark,
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
}

PostJobNotifier _notifier(WidgetTester tester, Type screenType) {
  final element = tester.element(find.byType(screenType));
  return ProviderScope.containerOf(element).read(postJobProvider.notifier);
}

Future<void> _fillQuick(PostJobNotifier notifier) async {
  await notifier.selectService(_service);
  await notifier.selectAddress(_address, 'LINZ');
  notifier.setTitle('Leaking tap');
  notifier.setDescription('The kitchen tap is leaking.');
  notifier.setUrgency('Emergency');
  notifier.setEstimatedHours('2');
}

Future<void> _fillProject(PostJobNotifier notifier) async {
  notifier.setJobType(Job.jobTypeProject);
  await _fillQuick(notifier);
  notifier.setTimingPreference('SpecificDate');
  notifier.setScheduledStartLocal(DateTime(2027, 1, 5, 10));
  notifier.setBudgetMin('15000');
  notifier.setBudgetMax('25000');
  notifier.setMaterialsBy('Homeowner');
  notifier.setSiteVisitWelcome(true);
  notifier.setScopeNotes('Replace cabinets, keep plumbing.');
}

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('post-job mapper', () {
    test('copy follows the mode', () {
      final quick = thPostJobCopy(Job.jobTypeHourly);
      expect(quick.titleLabel, 'JOB TITLE');
      expect(quick.descriptionLabel, 'DESCRIPTION');
      expect(quick.buttonLabel, 'Choose a tradie');
      expect(quick.subtitle, 'Describe it. No price needed yet.');

      final project = thPostJobCopy(Job.jobTypeProject);
      expect(project.titleLabel, 'PROJECT SUMMARY');
      expect(project.descriptionLabel, 'SCOPE');
      expect(project.buttonLabel, 'Request up to 3 quotes');
      expect(project.subtitle, 'Get up to 3 quotes');
    });

    test('missing-field helper keeps the v1 order and strings', () {
      var state = const PostJobState();
      expect(thMissingFieldHelper(state), 'Select a service to post your job');
      state = state.copyWith(selectedService: _service);
      expect(
        thMissingFieldHelper(state),
        'Select a job address to post your job',
      );
      state = state.copyWith(
        resolvedAddress: _address,
        latitude: _address.latitude,
        longitude: _address.longitude,
      );
      expect(thMissingFieldHelper(state), 'Add a title to post your job');
      state = state.copyWith(title: 'Fix tap');
      expect(thMissingFieldHelper(state), 'Add a description to post your job');
      state = state.copyWith(description: 'Drips');
      expect(thMissingFieldHelper(state), isNull);
      state = state.copyWith(timingPreference: 'SpecificDate');
      expect(thMissingFieldHelper(state), 'Pick a start date to post your job');
      state = state.copyWith(
        timingPreference: 'DateRange',
        scheduledStartLocal: DateTime(2027),
      );
      expect(thMissingFieldHelper(state), 'Pick an end date to post your job');
      state = state.copyWith(scheduledEndLocal: DateTime(2027, 1, 2));
      expect(thMissingFieldHelper(state), isNull);
    });

    test('hours, counter and budget formatting', () {
      expect(thFormatHours(3), '3');
      expect(thFormatHours(2.5), '2.5');
      expect(thShowCounter(79, 100), isFalse);
      expect(thShowCounter(80, 100), isTrue);
      expect(thBudgetSummary(null, null), 'Not set');
      expect(
        thBudgetSummary(Decimal.parse('15000'), Decimal.parse('25000')),
        '\$15000 – \$25000',
      );
      expect(thBudgetSummary(Decimal.parse('15000'), null), 'From \$15000');
      expect(thBudgetSummary(null, Decimal.parse('25000')), 'Up to \$25000');
    });

    test('review rows use v1 placeholders and only real values', () {
      var state = const PostJobState();
      var rows = thReviewRows(state);
      expect(rows.map((r) => r.label), ['Job', 'Location']);
      expect(rows.first.value, 'Add a job title above');
      expect(rows.last.value, 'Choose an address result above');

      state = state.copyWith(
        title: 'Leaking tap',
        resolvedAddress: _address,
        scheduledStartLocal: DateTime(2027, 1, 5, 10),
        jobType: Job.jobTypeProject,
        budgetMin: Decimal.parse('15000'),
      );
      rows = thReviewRows(state);
      expect(rows.map((r) => r.label), ['Job', 'Location', 'When', 'Budget']);
      expect(rows[2].when, DateTime(2027, 1, 5, 10));
      expect(rows[3].value, 'From \$15000');
    });

    test('photo limits and timing options', () {
      expect(thMaxPhotos, 5);
      expect(thMaxPhotoBytes, 10 * 1024 * 1024);
      expect(thPhotoTooLarge(10 * 1024 * 1024), isFalse);
      expect(thPhotoTooLarge(10 * 1024 * 1024 + 1), isTrue);
      expect(thTimingOptions(Job.jobTypeHourly).length, 4);
      expect(thTimingOptions(Job.jobTypeProject).length, 4);
    });
  });

  group('post-job role guard', () {
    testWidgets('tradie is redirected to /tradie', (tester) async {
      await _pumpScreen(
        tester,
        jobs: _JobsFake(),
        addresses: _AddressFake(),
        profile: _ProfileFake(role: 1),
      );
      expect(find.text('Tradie Dashboard'), findsOneWidget);
      expect(find.text('Post a Job'), findsNothing);
    });

    testWidgets('homeowner and unknown roles see the form', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      expect(find.text('Post a Job'), findsOneWidget);
      expect(find.byKey(const Key('post_job_screen')), findsOneWidget);
    });
  });

  group('post-job form', () {
    testWidgets('progressive helper and button enablement', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);
      final button = find.byKey(const Key('post_job_button'));

      expect(find.text('Select a service to post your job'), findsOneWidget);
      expect(tester.widget<THButton>(button).onPressed, isNull);

      await notifier.selectService(_service);
      await tester.pumpAndSettle();
      expect(
        find.text('Select a job address to post your job'),
        findsOneWidget,
      );

      await notifier.selectAddress(_address, 'LINZ');
      notifier.setTitle('Leaking tap');
      notifier.setDescription('The kitchen tap is leaking.');
      await tester.pumpAndSettle();
      expect(tester.widget<THButton>(button).onPressed, isNotNull);
    });

    testWidgets('mode switch keeps shared input', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);
      notifier.setTitle('Shared title');
      notifier.setJobType(Job.jobTypeProject);
      await tester.pumpAndSettle();

      expect(find.text('PROJECT SUMMARY'), findsOneWidget);
      expect(find.text('SCOPE'), findsOneWidget);
      expect(find.byKey(const Key('budget_min_field')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: find.byKey(const Key('title_field')),
                matching: find.byType(TextFormField),
              ),
            )
            .controller!
            .text,
        'Shared title',
      );
    });

    testWidgets('mode keys, service sheet, timing and urgency are tappable', (
      tester,
    ) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);

      await tester.tap(find.byKey(const Key('job_type_project')));
      await tester.pumpAndSettle();
      expect(notifier.state.isProject, isTrue);
      expect(find.text('PROJECT SUMMARY'), findsOneWidget);

      await tester.tap(find.byKey(const Key('job_type_hourly')));
      await tester.pumpAndSettle();
      expect(notifier.state.isProject, isFalse);

      await tester.tap(find.byKey(const Key('service_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plumbing'));
      await tester.pumpAndSettle();
      expect(notifier.state.selectedService?.id, 1);

      await tester.tap(find.text('Pick a date'));
      await tester.pumpAndSettle();
      expect(notifier.state.timingPreference, 'SpecificDate');
      expect(find.byKey(const Key('scheduled_start_field')), findsOneWidget);

      // Urgency now sits in the "More details" group below the mockup fields.
      await tester.ensureVisible(find.text('Emergency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergency'));
      await tester.pumpAndSettle();
      expect(notifier.state.urgency, 'Emergency');
      expect(
        find.text('Immediate response · needed today or ASAP'),
        findsOneWidget,
      );
    });

    testWidgets('quick field order follows the mockup (H-05)', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      double y(Finder f) => tester.getTopLeft(f).dy;

      final order = [
        y(find.byKey(const Key('title_field'))),
        y(find.byKey(const Key('service_dropdown'))),
        y(find.byKey(const Key('description_field'))),
        y(find.text('Flexible')),
        y(find.byKey(const Key('hours_field'))),
        y(find.byKey(const Key('address_search_field'))),
        y(find.text('MORE DETAILS')),
        y(find.text('URGENCY')),
        y(find.text('REVIEW YOUR JOB')),
      ];
      expect(order, orderedEquals([...order]..sort()));
      expect(order.toSet().length, order.length);
    });

    testWidgets('project budget follows the scope, before WHEN (H-05)', (
      tester,
    ) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      _notifier(tester, ThPostJobScreen).setJobType(Job.jobTypeProject);
      await tester.pumpAndSettle();
      double y(Finder f) => tester.getTopLeft(f).dy;

      expect(
        y(find.byKey(const Key('description_field'))),
        lessThan(y(find.byKey(const Key('budget_min_field')))),
      );
      expect(
        y(find.byKey(const Key('budget_min_field'))),
        lessThan(y(find.text('Flexible'))),
      );
    });

    testWidgets('project controls update the viewmodel', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);
      notifier.setJobType(Job.jobTypeProject);
      await tester.pumpAndSettle();

      await tester.tap(find.text('I buy'));
      await tester.pumpAndSettle();
      expect(notifier.state.materialsBy, 'Homeowner');

      await tester.ensureVisible(find.byKey(const Key('site_visit_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('site_visit_switch')));
      await tester.pumpAndSettle();
      expect(notifier.state.siteVisitWelcome, isTrue);
    });

    testWidgets('submits quick payload and lands on choose-a-tradie', (
      tester,
    ) async {
      final jobs = _JobsFake();
      await _pumpScreen(tester, jobs: jobs, addresses: _AddressFake());
      await _fillQuick(_notifier(tester, ThPostJobScreen));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_job_button')));
      await tester.pumpAndSettle();

      expect(jobs.posted, isNotNull);
      expect(jobs.posted!['title'], 'Leaking tap');
      expect(jobs.posted!['urgency'], 'Emergency');
      expect(jobs.posted!['serviceId'], 1);
      expect(jobs.posted!['jobType'], Job.jobTypeHourly);
      expect(jobs.posted!.containsKey('hourlyRate'), isFalse);
      expect(find.byKey(const Key('choose_tradie')), findsOneWidget);
      expect(find.text('Choose a Tradie'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_match_button')));
      await tester.pumpAndSettle();

      expect(jobs.matchStarts, 1);
      expect(find.text('Matching job-1'), findsOneWidget);
    });

    testWidgets('submits project payload with project-only fields', (
      tester,
    ) async {
      final jobs = _JobsFake();
      await _pumpScreen(tester, jobs: jobs, addresses: _AddressFake());
      await _fillProject(_notifier(tester, ThPostJobScreen));
      await tester.pumpAndSettle();

      expect(find.text('Project summary'), findsOneWidget);
      expect(find.textContaining('quotes to compare'), findsOneWidget);
      await tester.tap(find.byKey(const Key('post_job_button')));
      await tester.pumpAndSettle();

      expect(jobs.posted!['jobType'], Job.jobTypeProject);
      expect(jobs.posted!['budgetMin'], '15000');
      expect(jobs.posted!['budgetMax'], '25000');
      expect(jobs.posted!['materialsBy'], 'Homeowner');
      expect(jobs.posted!['siteVisitWelcome'], isTrue);
      expect(jobs.posted!['scopeNotes'], 'Replace cabinets, keep plumbing.');
      expect(jobs.posted!.containsKey('hourlyRate'), isFalse);
    });

    testWidgets('post failure shows the error banner and stays', (
      tester,
    ) async {
      final jobs = _JobsFake()
        ..failPost = true
        ..postError = 'Service region currently unavailable';
      await _pumpScreen(tester, jobs: jobs, addresses: _AddressFake());
      await _fillQuick(_notifier(tester, ThPostJobScreen));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_job_button')));
      await tester.pumpAndSettle();

      expect(find.text('Service region currently unavailable'), findsOneWidget);
      expect(find.byKey(const Key('post_job_screen')), findsOneWidget);
    });

    testWidgets('description errors sit under the field, not the banner', (
      tester,
    ) async {
      final jobs = _JobsFake()
        ..failPost = true
        ..postError = 'description is too short';
      await _pumpScreen(tester, jobs: jobs, addresses: _AddressFake());
      await _fillQuick(_notifier(tester, ThPostJobScreen));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_job_button')));
      await tester.pumpAndSettle();

      expect(find.text('description is too short'), findsOneWidget);
    });

    testWidgets('photo failure locks the form and retries without re-posting', (
      tester,
    ) async {
      final jobs = _JobsFake()..failUpload = true;
      await _pumpScreen(tester, jobs: jobs, addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);
      await _fillQuick(notifier);
      notifier.addPhoto('fixture-image');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_job_button')));
      await tester.pumpAndSettle();

      expect(find.text('Retry photo upload'), findsOneWidget);
      expect(jobs.posts, 1);
      expect(find.byType(AbsorbPointer), findsWidgets);

      jobs.failUpload = false;
      await tester.tap(find.byKey(const Key('post_job_button')));
      await tester.pumpAndSettle();

      expect(jobs.posts, 1);
      expect(jobs.uploads, 2);
      expect(find.byKey(const Key('choose_tradie')), findsOneWidget);
      expect(find.text('Choose a Tradie'), findsOneWidget);
    });

    testWidgets('review card is truthful before and after filling', (
      tester,
    ) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      expect(find.text('Quick job summary'), findsOneWidget);
      expect(find.textContaining('pay when the job is done'), findsOneWidget);
      expect(find.text('Add a job title above'), findsOneWidget);
      expect(find.text('Choose an address result above'), findsOneWidget);
      expect(find.text('When'), findsNothing);

      final notifier = _notifier(tester, ThPostJobScreen);
      await _fillQuick(notifier);
      notifier.setScheduledStartLocal(DateTime(2027, 1, 5, 10));
      await tester.pumpAndSettle();

      expect(find.text('Leaking tap'), findsWidgets);
      expect(find.text('42 Queen Street, Auckland'), findsWidgets);
      expect(find.text('When'), findsOneWidget);
    });
  });

  group('post-job address', () {
    testWidgets('search, select and edit after select', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final field = find.byKey(const Key('address_search_field'));

      await tester.enterText(field, '42 Queen');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(_address.address), findsOneWidget);

      await tester.tap(find.text(_address.address));
      await tester.pumpAndSettle();
      expect(find.text('Address selected'), findsOneWidget);

      await tester.enterText(field, 'Edited');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Address selected'), findsNothing);
    });

    testWidgets('error offers a retry and empty is distinct', (tester) async {
      final addresses = _AddressFake()
        ..error = const ProfileApiException('Address search unavailable');
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: addresses);
      final field = find.byKey(const Key('address_search_field'));

      await tester.enterText(field, '42 Queen');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Address search unavailable'), findsOneWidget);
      expect(find.textContaining('No matching addresses'), findsNothing);

      addresses
        ..error = null
        ..result = const AddressSearchResult(
          provider: 'LINZ',
          attribution: 'LINZ',
          attributionUrl: '',
          items: [],
        );
      await tester.tap(find.text('Retry address search'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No matching addresses'), findsOneWidget);
    });

    testWidgets('cached address arrives after first build', (tester) async {
      final addresses = _AddressFake()..cached = _address;
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: addresses);
      await tester.pumpAndSettle();
      expect(find.text('Address selected'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: find.byKey(const Key('address_search_field')),
                matching: find.byType(TextFormField),
              ),
            )
            .controller!
            .text,
        _address.address,
      );
    });
  });

  group('post-job photos and timing', () {
    testWidgets('photo count, add limit and remove', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);
      expect(find.text('0/5 photos added'), findsOneWidget);
      expect(find.text('Add photos'), findsOneWidget);

      for (var i = 0; i < 6; i++) {
        notifier.addPhoto('fixture-$i');
      }
      await tester.pumpAndSettle();
      expect(find.text('5/5 photos added'), findsOneWidget);
      expect(find.bySemanticsLabel('Photo 1 of 5, remove'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Photo 1 of 5, remove'));
      await tester.pumpAndSettle();
      expect(find.text('4/5 photos added'), findsOneWidget);
    });

    testWidgets('date-backed timing reveals the v1 keys', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);

      expect(find.text('Flexible'), findsOneWidget);
      expect(find.text('ASAP'), findsOneWidget);
      expect(find.text('Pick a date'), findsOneWidget);
      expect(find.text('Date range'), findsOneWidget);

      notifier.setTimingPreference('SpecificDate');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scheduled_start_field')), findsOneWidget);
      expect(find.byKey(const Key('scheduled_end_field')), findsNothing);

      notifier.setTimingPreference('DateRange');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scheduled_start_field')), findsOneWidget);
      expect(find.byKey(const Key('scheduled_end_field')), findsOneWidget);
    });

    testWidgets('urgency keeps its meaning line and payload', (tester) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      final notifier = _notifier(tester, ThPostJobScreen);
      notifier.setUrgency('Emergency');
      await tester.pumpAndSettle();
      expect(
        find.text('Immediate response · needed today or ASAP'),
        findsOneWidget,
      );
    });
  });

  group('post-job project block', () {
    testWidgets('shows all kept project fields and the info card', (
      tester,
    ) async {
      await _pumpScreen(tester, jobs: _JobsFake(), addresses: _AddressFake());
      _notifier(tester, ThPostJobScreen).setJobType(Job.jobTypeProject);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budget_min_field')), findsOneWidget);
      expect(find.byKey(const Key('budget_max_field')), findsOneWidget);
      expect(find.text('WHO BUYS THE MATERIALS?'), findsOneWidget);
      expect(find.byKey(const Key('site_visit_switch')), findsOneWidget);
      expect(find.byKey(const Key('scope_notes_field')), findsOneWidget);
      expect(
        find.textContaining('Jobs over \$30,000 need a written contract'),
        findsOneWidget,
      );
    });
  });

  group('post-job layout', () {
    for (final dark in [false, true]) {
      testWidgets('320px, 2x text, dark=$dark does not overflow', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          jobs: _JobsFake(),
          addresses: _AddressFake(),
          dark: dark,
          scale: 2,
          size: const Size(320, 1000),
        );
        expect(find.text('Post a Job'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
