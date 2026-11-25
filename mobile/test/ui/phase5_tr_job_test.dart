// Phase 5.3: v2 Tradie job detail widget tests (`tr_job`).
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/network/external_launcher.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/tradie/tr_job_booked_screen.dart';
import 'package:fixo/ui/tradie/tr_job_inprogress_screen.dart';
import 'package:fixo/ui/tradie/tr_job_review_states.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

class _FakeJobsRepo extends JobsRepository {
  _FakeJobsRepo() : super(Dio(), const FlutterSecureStorage());

  bool checkInCalled = false;
  bool cancelCalled = false;
  bool noShowCalled = false;
  double? checkOutHours;

  @override
  Future<bool> checkIn(String jobId) async {
    checkInCalled = true;
    return true;
  }

  @override
  Future<bool> cancelJobWithReason(
    String jobId, {
    required String reasonCode,
    String? notes,
  }) async {
    cancelCalled = true;
    return true;
  }

  @override
  Future<bool> reportNoShow(String jobId, {String? action = 'cancel'}) async {
    noShowCalled = true;
    return true;
  }

  @override
  Future<CheckOutSummary?> checkOut(
    String jobId, {
    required double finalHours,
    String? notes,
  }) async {
    checkOutHours = finalHours;
    return CheckOutSummary(
      jobId: jobId,
      finalHours: finalHours,
      finalAmount: Decimal.parse('170.00'),
      labourAmount: Decimal.parse('170.00'),
      exceedsTolerance: false,
    );
  }
}

class _FakeLauncher extends ExternalLauncher {
  List<String> calls = [];
  MapApp? openedMapApp;

  @override
  Future<bool> callPhone(String phoneNumber) async {
    calls.add(phoneNumber);
    return true;
  }

  @override
  Future<bool> openMap({
    String? address,
    double? latitude,
    double? longitude,
    MapApp? app,
  }) async {
    openedMapApp = app;
    return true;
  }
}

Job _testJob({
  String status = 'Booked',
  String? urgency,
  DateTime? scheduledStartUtc,
}) => Job(
  id: 'j42',
  title: 'Fix kitchen pipe',
  category: 'Plumbing',
  suburb: 'Grey Lynn',
  address: '22 Crummer Road, Grey Lynn',
  status: status,
  stage: 2,
  hours: 2,
  hourlyRate: Decimal.parse('85.00'),
  estimatedTotal: Decimal.parse('170.00'),
  referenceCode: 'FIXO-PIPE-42',
  homeownerId: 'owner-99',
  urgency: urgency,
  scheduledStartUtc: scheduledStartUtc ?? DateTime.utc(2026, 11, 25, 10, 0),
  description: 'The kitchen pipe under the sink has a small leak.',
);

const _testContact = JobContact(
  userId: 'owner-99',
  firstName: 'Aroha',
  phoneNumber: '+64 21 987 654',
);

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('TrJobBookedScreen', () {
    late _FakeJobsRepo repo;
    late _FakeLauncher launcher;

    Widget buildScreen({
      bool dark = false,
      double textScale = 1.0,
      Size size = const Size(390, 844),
      Job? job,
    }) {
      repo = _FakeJobsRepo();
      launcher = _FakeLauncher();

      final router = GoRouter(
        initialLocation: '/tradie/jobs/j42',
        routes: [
          GoRoute(
            path: '/tradie/jobs/:jobId',
            builder: (_, _) => TrJobBookedScreen(
              job: job ?? _testJob(),
              contact: _testContact,
              adjustments: const [],
            ),
          ),
          GoRoute(
            path: '/chat/:jobId',
            builder: (_, s) =>
                Scaffold(body: Text('Chat ${s.pathParameters['jobId']}')),
          ),
          GoRoute(
            path: '/jobs/:jobId/dispute',
            builder: (_, s) =>
                Scaffold(body: Text('Dispute ${s.pathParameters['jobId']}')),
          ),
        ],
      );

      return MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          platformBrightness: dark ? Brightness.dark : Brightness.light,
        ),
        child: ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(repo),
            externalLauncherProvider.overrideWithValue(launcher),
            localeConfigProvider.overrideWith(
              (ref) async => {'commissionPercent': '10.0'},
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    testWidgets('renders all essential elements and keys in light and dark', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(buildScreen(dark: dark));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tradie_job_j42')), findsOneWidget);
        expect(find.byKey(const Key('check_in_button')), findsOneWidget);
        expect(find.byKey(const Key('navigate_button')), findsOneWidget);
        expect(
          find.byKey(const Key('message_homeowner_button')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('call_homeowner_button')), findsOneWidget);
        expect(
          find.byKey(const Key('request_extra_cost_button')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('status_strip_job_code')), findsOneWidget);
        expect(find.text('Fix kitchen pipe'), findsOneWidget);
        expect(find.text('Aroha'), findsOneWidget);
        expect(find.text('22 Crummer Road, Grey Lynn'), findsAtLeast(1));
      }
    });

    testWidgets('check-in button dispatches checkIn', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('check_in_button')));
      await tester.pump();
      expect(repo.checkInCalled, isTrue);
    });

    testWidgets('navigate button opens map picker and launches Apple Maps', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('navigate_button')));
      await tester.pumpAndSettle();

      expect(find.text('Apple Maps'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);

      await tester.tap(find.text('Apple Maps'));
      await tester.pumpAndSettle();
      expect(launcher.openedMapApp, MapApp.appleMaps);
    });

    testWidgets('message button navigates to chat', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('message_homeowner_button')));
      await tester.pumpAndSettle();
      expect(find.text('Chat j42'), findsOneWidget);
    });

    testWidgets('call button calls homeowner phone', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('call_homeowner_button')));
      await tester.pumpAndSettle();
      expect(launcher.calls, ['+64 21 987 654']);
    });

    testWidgets('cancel job via overflow menu opens cancel sheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('job_overflow_menu')));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Job'), findsOneWidget);
      await tester.tap(find.text('Cancel Job'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Job'), findsWidgets);
      expect(find.byKey(const Key('cancel_confirm_button')), findsOneWidget);
      expect(find.byKey(const Key('cancel_dismiss_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel_confirm_button')));
      await tester.pump();
      expect(repo.cancelCalled, isTrue);
    });

    testWidgets('survives 200% text scale on narrow phone', (tester) async {
      await tester.pumpWidget(
        buildScreen(textScale: 2.0, size: const Size(320, 640)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('TrJobInProgressScreen', () {
    late _FakeJobsRepo repo;

    Widget buildScreen() {
      repo = _FakeJobsRepo();
      return ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(repo),
          externalLauncherProvider.overrideWithValue(_FakeLauncher()),
          localeConfigProvider.overrideWith(
            (ref) async => {'commissionPercent': '10.0'},
          ),
        ],
        child: MaterialApp(
          home: TrJobInProgressScreen(
            job: _testJob(status: 'InProgress'),
            contact: _testContact,
            adjustments: const [],
          ),
        ),
      );
    }

    testWidgets('renders check_out_button and submits check-out', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('check_out_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('check_out_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('final_hours_field')), findsOneWidget);
      expect(find.byKey(const Key('check_out_submit_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('check_out_submit_button')));
      await tester.pump();
      expect(repo.checkOutHours, 2.0);
    });
  });

  group('TrJobCompletedScreen', () {
    testWidgets('renders rate_homeowner_button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeConfigProvider.overrideWith(
              (ref) async => {'commissionPercent': '10.0'},
            ),
          ],
          child: MaterialApp(
            home: TrJobCompletedScreen(
              job: _testJob(status: 'Completed'),
              contact: _testContact,
              adjustments: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rate_homeowner_button')), findsOneWidget);
    });
  });
}
