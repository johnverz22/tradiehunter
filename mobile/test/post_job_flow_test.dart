import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/address.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/address_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/address_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/jobs/post_job_screen.dart';
import 'package:fixo/widgets/fixo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ── Test Fixtures ─────────────────────────────────────────────────────────────

const testServicePlumbing = ServiceOption(id: 1, name: 'Plumbing', category: 'Plumber');
const testServiceElectrical = ServiceOption(id: 2, name: 'Electrical', category: 'Electrician');

const testAddress = AddressCandidate(
  id: 'linz:101',
  address: '42 Queen Street, Auckland',
  latitude: -36.8485,
  longitude: 174.7633,
);

final testRate = ServiceRateOption(
  tradieId: 'tradie-101',
  name: 'Sam Tradie',
  businessName: 'Sam Plumbing Ltd',
  hourlyRate: Decimal.parse('95.00'),
  distanceKm: 2.5,
);

class FakeProfileRepo extends ProfileRepository {
  final dynamic role;
  FakeProfileRepo({this.role = 0}) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'id': 'user-1',
    'role': role,
  };
}

class FakeAddressRepo extends AddressRepository {
  FakeAddressRepo() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<AddressSearchResult> search(String query) async {
    return const AddressSearchResult(
      provider: 'LINZ',
      attribution: 'LINZ Data Service',
      attributionUrl: 'https://data.linz.govt.nz',
      items: [testAddress],
    );
  }
}

class FakeJobsRepo extends JobsRepository {
  List<ServiceOption> services = [testServicePlumbing, testServiceElectrical];
  List<ServiceRateOption> rates = [testRate];
  Map<String, dynamic>? lastPostedData;
  bool shouldThrowPost = false;
  String postErrorMessage = 'Server validation failed';

  FakeJobsRepo() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<ServiceOption>> getServiceCatalog() async => services;

  @override
  Future<List<ServiceRateOption>> searchServiceRates({
    required int serviceId,
    required double latitude,
    required double longitude,
  }) async => rates;

  @override
  Future<String> postJob(Map<String, dynamic> data) async {
    if (shouldThrowPost) {
      throw ProfileApiException(postErrorMessage);
    }
    lastPostedData = data;
    return 'job-789';
  }

  @override
  Future<List<String>> uploadPhotos(String jobId, List<String> filePaths) async => [];
}

// ── Harness Helper ────────────────────────────────────────────────────────────

Widget buildPostJobHarness({
  required FakeJobsRepo jobsRepo,
  required FakeAddressRepo addressRepo,
  required FakeProfileRepo profileRepo,
  GoRouter? router,
  bool isDark = false,
}) {
  final effectiveRouter = router ??
      GoRouter(
        initialLocation: '/post',
        routes: [
          GoRoute(path: '/post', builder: (_, _) => const PostJobScreen()),
          GoRoute(path: '/tradie', builder: (_, _) => const Scaffold(body: Text('Tradie Dashboard'))),
          GoRoute(path: '/jobs/:id/matching', builder: (_, state) => Scaffold(body: Text('Matching Screen ${state.pathParameters['id']}'))),
        ],
      );

  return ProviderScope(
    overrides: [
      jobsRepositoryProvider.overrideWithValue(jobsRepo),
      addressRepositoryProvider.overrideWithValue(addressRepo),
      profileRepositoryProvider.overrideWithValue(profileRepo),
    ],
    child: MaterialApp.router(
      theme: isDark ? FixoTheme.dark() : FixoTheme.light(),
      routerConfig: effectiveRouter,
    ),
  );
}

void main() {
  late FakeJobsRepo jobsRepo;
  late FakeAddressRepo addressRepo;
  late FakeProfileRepo profileRepo;

  setUp(() {
    jobsRepo = FakeJobsRepo();
    addressRepo = FakeAddressRepo();
    profileRepo = FakeProfileRepo(role: 0); // Homeowner by default
  });

  group('PostJobScreen role protection', () {
    testWidgets('Tradie role redirects to /tradie', (tester) async {
      final tradieProfile = FakeProfileRepo(role: 1); // Tradie role
      final router = GoRouter(
        initialLocation: '/post',
        routes: [
          GoRoute(path: '/post', builder: (_, _) => const PostJobScreen()),
          GoRoute(path: '/tradie', builder: (_, _) => const Scaffold(body: Text('Tradie Dashboard'))),
        ],
      );

      await tester.pumpWidget(
        buildPostJobHarness(
          jobsRepo: jobsRepo,
          addressRepo: addressRepo,
          profileRepo: tradieProfile,
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tradie Dashboard'), findsOneWidget);
      expect(find.text('Post a Job'), findsNothing);
    });

    testWidgets('Homeowner role allows viewing Post Job screen', (tester) async {
      await tester.pumpWidget(
        buildPostJobHarness(
          jobsRepo: jobsRepo,
          addressRepo: addressRepo,
          profileRepo: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Post a Job'), findsOneWidget);
      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('Where is the job?'), findsOneWidget);
    });
  });

  group('PostJobScreen form progression and validation helper', () {
    testWidgets('shows progressive missing field helper copy', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildPostJobHarness(
          jobsRepo: jobsRepo,
          addressRepo: addressRepo,
          profileRepo: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      final postButtonFinder = find.byKey(const Key('post_job_button'));
      expect(postButtonFinder, findsOneWidget);

      // Initially no service is selected
      expect(find.text('Select a service to post your job'), findsOneWidget);
      final initialButton = tester.widget<FixoPrimaryButton>(postButtonFinder);
      expect(initialButton.onPressed, isNull);

      // Select service via ViewModel
      final element = tester.element(find.byType(PostJobScreen));
      final container = ProviderScope.containerOf(element);
      final notifier = container.read(postJobProvider.notifier);

      await notifier.selectService(testServicePlumbing);
      await tester.pumpAndSettle();

      // Now asks for address
      expect(find.text('Select a job address to post your job'), findsOneWidget);

      // Select address
      await notifier.selectAddress(testAddress, 'LINZ Data Service');
      await tester.pumpAndSettle();

      // Now asks for title
      expect(find.text('Add a title to post your job'), findsOneWidget);

      // Enter title
      notifier.setTitle('Leaking sink pipe');
      await tester.pumpAndSettle();

      // Now asks for description
      expect(find.text('Add a description to post your job'), findsOneWidget);

      // Enter description
      notifier.setDescription('The pipe under the kitchen sink is leaking heavily.');
      await tester.pumpAndSettle();

      // Now asks for scheduled start
      expect(find.text('Choose a start date and time to post your job'), findsOneWidget);

      // Set scheduled start
      notifier.setScheduledStartLocal(DateTime.now().add(const Duration(days: 1)));
      await tester.pumpAndSettle();

      // Hours default is 2, so next missing is rate
      expect(find.text('Choose an hourly rate to post your job'), findsOneWidget);

      // Select rate
      notifier.selectRate(testRate);
      await tester.pumpAndSettle();

      // All requirements met -> helper is gone and button is enabled!
      expect(find.text('Select a service to post your job'), findsNothing);
      expect(find.text('Choose an hourly rate to post your job'), findsNothing);
      final enabledButton = tester.widget<FixoPrimaryButton>(postButtonFinder);
      expect(enabledButton.onPressed, isNotNull);
    });
  });

  group('PostJobScreen estimate card & submission', () {
    testWidgets('renders live estimate card with rate and hours', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildPostJobHarness(
          jobsRepo: jobsRepo,
          addressRepo: addressRepo,
          profileRepo: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(PostJobScreen));
      final container = ProviderScope.containerOf(element);
      final notifier = container.read(postJobProvider.notifier);

      await notifier.selectService(testServicePlumbing);
      await notifier.selectAddress(testAddress, 'LINZ');
      notifier.selectRate(testRate); // $95/hr
      notifier.setHours('3'); // 3 hours -> $285
      await tester.pumpAndSettle();

      expect(find.text(r'3 hours × $95.00 / hour'), findsOneWidget);
      expect(find.text(r'$285.00'), findsOneWidget);
    });

    testWidgets('submitting valid form posts to repo and navigates to matching', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildPostJobHarness(
          jobsRepo: jobsRepo,
          addressRepo: addressRepo,
          profileRepo: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(PostJobScreen));
      final container = ProviderScope.containerOf(element);
      final notifier = container.read(postJobProvider.notifier);

      await notifier.selectService(testServicePlumbing);
      await notifier.selectAddress(testAddress, 'LINZ');
      notifier.setTitle('Emergency Leak Fix');
      notifier.setDescription('Water flooding the floor from under kitchen basin.');
      notifier.setUrgency('immediate');
      notifier.setHours('2');
      notifier.setScheduledStartLocal(DateTime.utc(2026, 11, 10, 14, 0));
      notifier.selectRate(testRate);
      await tester.pumpAndSettle();

      // Tap Post Job button
      final postButtonFinder = find.byKey(const Key('post_job_button'));
      await tester.tap(postButtonFinder);
      await tester.pumpAndSettle();

      // Verify repository was called with correct fields
      expect(jobsRepo.lastPostedData, isNotNull);
      expect(jobsRepo.lastPostedData!['title'], 'Emergency Leak Fix');
      expect(jobsRepo.lastPostedData!['urgency'], 'immediate');
      expect(jobsRepo.lastPostedData!['serviceId'], 1);
      expect(jobsRepo.lastPostedData!['hours'], 2);
      expect(jobsRepo.lastPostedData!['hourlyRate'], '95');

      // Verify routed to matching screen
      expect(find.text('Matching Screen job-789'), findsOneWidget);
    });

    testWidgets('surfaces error banner on post failure', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      jobsRepo.shouldThrowPost = true;
      jobsRepo.postErrorMessage = 'Service region currently unavailable';

      await tester.pumpWidget(
        buildPostJobHarness(
          jobsRepo: jobsRepo,
          addressRepo: addressRepo,
          profileRepo: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(PostJobScreen));
      final container = ProviderScope.containerOf(element);
      final notifier = container.read(postJobProvider.notifier);

      await notifier.selectService(testServicePlumbing);
      await notifier.selectAddress(testAddress, 'LINZ');
      notifier.setTitle('Pipe fix');
      notifier.setDescription('Leaking tap repair');
      notifier.setScheduledStartLocal(DateTime.now().add(const Duration(days: 1)));
      notifier.selectRate(testRate);
      await tester.pumpAndSettle();

      final postButtonFinder = find.byKey(const Key('post_job_button'));
      await tester.tap(postButtonFinder);
      await tester.pumpAndSettle();

      // Error message should appear in banner
      expect(find.text('Service region currently unavailable'), findsOneWidget);
    });
  });

  group('PostJobScreen theme sanity', () {
    for (final isDark in [false, true]) {
      testWidgets('renders cleanly on 320px dark=$isDark', (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildPostJobHarness(
            jobsRepo: jobsRepo,
            addressRepo: addressRepo,
            profileRepo: profileRepo,
            isDark: isDark,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Post a Job'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
