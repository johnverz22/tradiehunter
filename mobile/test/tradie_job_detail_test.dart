import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/network/external_launcher.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/views/tradie/tradie_job_detail_screen.dart';
import 'package:fixo/views/widgets/compact_progress_bar.dart';
import 'package:fixo/views/widgets/job_timeline.dart';
import 'package:fixo/views/widgets/status_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _JobsFixture extends JobsRepository {
  Job? job;
  JobContact? contact;
  bool contactThrows;
  int loads = 0;
  int contactCalls = 0;
  int cancelCalls = 0;
  int checkInCalls = 0;
  int checkOutCalls = 0;

  _JobsFixture(this.job, {this.contact, this.contactThrows = false})
    : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Job?> getJobById(String jobId) async {
    loads++;
    return job;
  }

  @override
  Future<JobContact?> getJobContact(String jobId) async {
    contactCalls++;
    if (contactThrows) throw StateError('no contact');
    return contact;
  }

  @override
  Future<bool> checkIn(String jobId) async {
    checkInCalls++;
    return true;
  }

  @override
  Future<bool> checkOut(String jobId) async {
    checkOutCalls++;
    return true;
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
}

class _LauncherFixture extends ExternalLauncher {
  final maps = <({String? address, double? lat, double? lng, MapApp? app})>[];
  final calls = <String>[];
  bool launchResult;

  _LauncherFixture({this.launchResult = true});

  @override
  Future<bool> openMap({
    String? address,
    double? latitude,
    double? longitude,
    MapApp? app,
  }) async {
    maps.add((address: address, lat: latitude, lng: longitude, app: app));
    return launchResult;
  }

  @override
  Future<bool> callPhone(String phoneNumber) async {
    calls.add(phoneNumber);
    return launchResult;
  }
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
  String? address = '70 Symonds Street, Grafton, Auckland',
  double? latitude,
  double? longitude,
  Decimal? total,
  DateTime? scheduled,
}) => Job(
  id: '42',
  title: 'Fix leaking tap',
  category: 'Plumbing',
  suburb: 'Grafton',
  status: status,
  stage: 2,
  description: 'Kitchen tap drips constantly.',
  address: address,
  latitude: latitude,
  longitude: longitude,
  matchedTradieId: 'me',
  homeownerId: 'owner-1',
  hourlyRate: Decimal.parse('85.50'),
  totalAmount: total ?? Decimal.parse('171.00'),
  hours: 2,
  scheduledStartUtc: scheduled ?? DateTime.utc(2026, 11, 3, 9),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(
    WidgetTester tester,
    _JobsFixture jobs, {
    _LauncherFixture? launcher,
    _HubFixture? hub,
    Object? locale = const {'commissionPercent': '12.5'},
    bool dark = false,
    double scale = 1,
    double width = 390,
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
          builder: (_, _) => const TradieJobDetailScreen(jobId: '42'),
        ),
        for (final path in ['/chat/:id', '/jobs/:id/dispute'])
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
          jobHubClientProvider.overrideWithValue(h),
          externalLauncherProvider.overrideWithValue(
            launcher ?? _LauncherFixture(),
          ),
          if (locale != null)
            localeConfigProvider.overrideWith(
              (ref) async => (locale as Map).cast<String, dynamic>(),
            )
          else
            localeConfigProvider.overrideWith((ref) async => null),
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
  }

  group('payoutNetAmount', () {
    test('computes net after commission, matching server rounding', () {
      // 171.00 * 12.5% = 21.375 -> 21.38; net 149.62
      expect(
        payoutNetAmount(Decimal.parse('171.00'), Decimal.parse('12.5')),
        Decimal.parse('149.62'),
      );
    });

    test('rounds half-cent ties to even like Math.Round', () {
      // 100.04 * 12.5 = 1250.5 -> 1250 (even) -> commission 12.50
      expect(
        payoutNetAmount(Decimal.parse('100.04'), Decimal.parse('12.5')),
        Decimal.parse('87.54'),
      );
      // 100.12 * 12.5 = 1251.5 -> 1252 (even) -> commission 12.52
      expect(
        payoutNetAmount(Decimal.parse('100.12'), Decimal.parse('12.5')),
        Decimal.parse('87.60'),
      );
    });

    test('returns null when inputs are missing or non-positive', () {
      expect(payoutNetAmount(null, Decimal.parse('12.5')), isNull);
      expect(payoutNetAmount(Decimal.parse('10'), null), isNull);
      expect(
        payoutNetAmount(Decimal.parse('0'), Decimal.parse('12.5')),
        isNull,
      );
    });
  });

  group('navigate action', () {
    testWidgets('shows ≥48px Navigate on Booked job and launches maps', (
      tester,
    ) async {
      final launcher = _LauncherFixture();
      await mount(
        tester,
        _JobsFixture(_job('Booked', latitude: -36.86, longitude: 174.76)),
        launcher: launcher,
      );
      final button = find.byKey(const Key('navigate_button'));
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple Maps'));
      await tester.pumpAndSettle();
      expect(launcher.maps, hasLength(1));
      expect(launcher.maps.single.address, contains('Symonds'));
      expect(launcher.maps.single.lat, -36.86);
    });

    testWidgets('hidden on Cancelled job (address masked, not contactable)', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Cancelled', address: null)));
      expect(find.byKey(const Key('navigate_button')), findsNothing);
    });

    testWidgets('launch failure surfaces a truthful snackbar', (tester) async {
      await mount(
        tester,
        _JobsFixture(_job('Booked')),
        launcher: _LauncherFixture(launchResult: false),
      );
      await tester.tap(find.byKey(const Key('navigate_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple Maps'));
      await tester.pumpAndSettle();
      expect(find.textContaining('maps app'), findsOneWidget);
    });

    testWidgets('navigate options menu allows choosing Google Maps and Apple Maps', (
      tester,
    ) async {
      final launcher = _LauncherFixture();
      await mount(
        tester,
        _JobsFixture(_job('Booked', latitude: -36.86, longitude: 174.76)),
        launcher: launcher,
      );
      final navigateButton = find.byKey(const Key('navigate_button'));
      expect(navigateButton, findsOneWidget);

      // Open popup and choose Google Maps
      await tester.tap(navigateButton);
      await tester.pumpAndSettle();
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Apple Maps'), findsOneWidget);

      await tester.tap(find.text('Google Maps'));
      await tester.pumpAndSettle();
      expect(launcher.maps, hasLength(1));
      expect(launcher.maps.single.app, MapApp.googleMaps);
      expect(launcher.maps.single.lat, -36.86);

      // Open popup and choose Apple Maps
      await tester.tap(navigateButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple Maps'));
      await tester.pumpAndSettle();
      expect(launcher.maps, hasLength(2));
      expect(launcher.maps.last.app, MapApp.appleMaps);
    });
  });

  group('contact card', () {
    testWidgets('shows Message and Call when phone is present', (tester) async {
      final launcher = _LauncherFixture();
      await mount(
        tester,
        _JobsFixture(
          _job('Booked'),
          contact: const JobContact(
            userId: 'owner-1',
            firstName: 'Aroha',
            phoneNumber: '+64 21 555 0101',
          ),
        ),
        launcher: launcher,
      );
      expect(find.text('Aroha'), findsOneWidget);
      expect(find.byKey(const Key('message_homeowner_button')), findsOneWidget);
      final call = find.byKey(const Key('call_homeowner_button'));
      expect(call, findsOneWidget);
      expect(tester.getSize(call).height, greaterThanOrEqualTo(48));
      await tester.tap(call);
      await tester.pumpAndSettle();
      expect(launcher.calls, ['+64 21 555 0101']);
    });

    testWidgets('hides Call when the contact has no phone', (tester) async {
      await mount(
        tester,
        _JobsFixture(
          _job('Booked'),
          contact: const JobContact(userId: 'owner-1', firstName: 'Aroha'),
        ),
      );
      expect(find.byKey(const Key('message_homeowner_button')), findsOneWidget);
      expect(find.byKey(const Key('call_homeowner_button')), findsNothing);
    });

    testWidgets('Message opens the existing chat route', (tester) async {
      await mount(
        tester,
        _JobsFixture(
          _job('Booked'),
          contact: const JobContact(userId: 'owner-1', firstName: 'Aroha'),
        ),
      );
      await tester.tap(find.byKey(const Key('message_homeowner_button')));
      await tester.pumpAndSettle();
      expect(find.text('Destination /chat/42'), findsOneWidget);
    });

    testWidgets('no card when the server returns no contact', (tester) async {
      await mount(tester, _JobsFixture(_job('Booked'), contact: null));
      expect(find.byKey(const Key('message_homeowner_button')), findsNothing);
      expect(find.byKey(const Key('call_homeowner_button')), findsNothing);
    });

    testWidgets('contact fetch failure hides the card, not the screen', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Booked'), contactThrows: true));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('message_homeowner_button')), findsNothing);
      expect(find.byKey(const Key('check_in_button')), findsOneWidget);
    });

    testWidgets('not fetched for pre-Booked or terminal jobs', (tester) async {
      final jobs = _JobsFixture(
        _job('Cancelled'),
        contact: const JobContact(userId: 'o', firstName: 'X'),
      );
      await mount(tester, jobs);
      expect(jobs.contactCalls, 0);
    });
  });

  group('gross/net labels', () {
    testWidgets('shows gross total and net after commission', (tester) async {
      await mount(tester, _JobsFixture(_job('Booked')));
      await tester.scrollUntilVisible(find.text('Job total'), 200);
      expect(find.text('\$171.00'), findsOneWidget);
      expect(
        find.textContaining('You earn (after 12.5% platform fee)'),
        findsOneWidget,
      );
      expect(find.text('\$149.62'), findsOneWidget);
    });

    testWidgets('omits the net line when commission config is unavailable', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Booked')), locale: null);
      await tester.scrollUntilVisible(find.text('You earn'), 200);
      expect(find.text('\$171.00'), findsOneWidget);
      expect(find.textContaining('platform fee'), findsNothing);
    });
  });

  group('cancel via overflow', () {
    testWidgets('cancel lives in the overflow and still needs the sheet', (
      tester,
    ) async {
      final jobs = _JobsFixture(_job('Booked'));
      await mount(tester, jobs);
      expect(find.byTooltip('Cancel job'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel Job'));
      await tester.pumpAndSettle();
      // Confirmation sheet opened — nothing dispatched yet.
      expect(find.text('Cancel this job'), findsOneWidget);
      expect(jobs.cancelCalls, 0);
    });

    testWidgets('cancel item absent for non-cancellable statuses', (
      tester,
    ) async {
      // Completed still shows the overflow (Open Dispute) but not Cancel.
      await mount(tester, _JobsFixture(_job('Completed')));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Cancel Job'), findsNothing);
    });
  });

  group('state and SignalR', () {
    testWidgets('check-in and check-out dispatch via the repository', (
      tester,
    ) async {
      final jobs = _JobsFixture(_job('Booked'));
      await mount(tester, jobs);
      await tester.tap(find.byKey(const Key('check_in_button')));
      await tester.pumpAndSettle();
      expect(jobs.checkInCalls, 1);
      expect(jobs.checkOutCalls, 0);
    });

    testWidgets('job status event for this job reloads state', (tester) async {
      final jobs = _JobsFixture(_job('Booked'));
      final hub = _HubFixture();
      await mount(tester, jobs, hub: hub);
      expect(jobs.loads, 1);
      hub.events.add(const JobStatusEvent(jobId: '42', status: 'InProgress'));
      await tester.pumpAndSettle();
      expect(jobs.loads, 2);
      // An event for a different job must not reload.
      hub.events.add(const JobStatusEvent(jobId: '99', status: 'InProgress'));
      await tester.pumpAndSettle();
      expect(jobs.loads, 2);
    });
  });

  group('recovery and dispute banner', () {
    testWidgets('job not found shows friendly recovery with back and support', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(null));
      expect(find.text('This job is no longer available'), findsOneWidget);
      expect(find.text('Back to dashboard'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('dispute banner never appears on Completed or Cancelled jobs', (
      tester,
    ) async {
      await mount(
        tester,
        _JobsFixture(
          Job(
            id: '42',
            title: 'Fix leaking tap',
            category: 'Plumbing',
            suburb: 'Grafton',
            status: 'Completed',
            stage: 3,
            hourlyRate: Decimal.parse('85.50'),
            totalAmount: Decimal.parse('171.00'),
            hours: 2,
            disputeStatus: 'Open',
          ),
        ),
      );
      expect(
        find.text('This job has an active dispute under review.'),
        findsNothing,
      );
      expect(find.text('Job completed. Thank you!'), findsOneWidget);
    });
  });

  group('Task 7: StatusStrip and notices polish', () {
    testWidgets('duplicate JobTimeline card is removed from body', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Booked')));
      expect(find.byType(StatusStrip), findsOneWidget);
      expect(find.byType(JobTimeline), findsNothing);
    });

    testWidgets('notices stack renders notices directly at top of body', (
      tester,
    ) async {
      await mount(
        tester,
        _JobsFixture(
          Job(
            id: '42',
            title: 'Fix leaking tap',
            category: 'Plumbing',
            suburb: 'Grafton',
            status: 'AwaitingConfirmation',
            stage: 2,
            urgency: 'Emergency',
            hourlyRate: Decimal.parse('85.50'),
            totalAmount: Decimal.parse('171.00'),
            hours: 2,
          ),
        ),
      );
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(
        find.textContaining('Waiting for the homeowner to confirm'),
        findsOneWidget,
      );
      expect(find.byType(JobTimeline), findsNothing);
    });

    testWidgets(
      'StatusStrip deduplicates status caption when matching StatusBadge',
      (tester) async {
        await mount(tester, _JobsFixture(_job('Booked')));
        // "Booked" pill is in the StatusBadge
        expect(find.text('Booked'), findsOneWidget);
        // Caption is "Step 2 of 4" without duplicate "· Booked" suffix
        expect(find.text('Step 2 of 4'), findsOneWidget);
        expect(find.text('Step 2 of 4 · Booked'), findsNothing);
      },
    );

    testWidgets('StatusStrip progress caption tap target is >= 48dp', (
      tester,
    ) async {
      await mount(tester, _JobsFixture(_job('Booked')));
      final captionFinder = find.byType(CompactProgressBar);
      expect(captionFinder, findsOneWidget);
      final gestureFinder = find.descendant(
        of: captionFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureFinder, findsOneWidget);
      expect(tester.getSize(gestureFinder).height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
      'job code is monospace and long-press copies to clipboard with snackbar',
      (tester) async {
        await mount(
          tester,
          _JobsFixture(
            Job(
              id: '42',
              title: 'Fix leaking tap',
              category: 'Plumbing',
              suburb: 'Grafton',
              status: 'Booked',
              stage: 1,
              referenceCode: 'FIXO-2481-JB',
              hourlyRate: Decimal.parse('85.50'),
              totalAmount: Decimal.parse('171.00'),
              hours: 2,
            ),
          ),
        );
        final jobCode = find.byKey(const Key('status_strip_job_code'));
        expect(jobCode, findsOneWidget);
        final textWidget = tester.widget<Text>(
          find.descendant(of: jobCode, matching: find.byType(Text)),
        );
        expect(textWidget.style?.fontFamily, DesignTokens.fontMono);
        expect(textWidget.style?.fontSize, DesignTokens.fontSizeMono);

        await tester.longPress(jobCode);
        await tester.pumpAndSettle();
        expect(find.text('Job code copied: FIXO-2481-JB'), findsOneWidget);
      },
    );
  });

  group('responsive and themes', () {
    for (final dark in [false, true]) {
      testWidgets('renders at 320px and 2.0 text scale, dark=$dark', (
        tester,
      ) async {
        await mount(
          tester,
          _JobsFixture(
            _job('InProgress'),
            contact: const JobContact(
              userId: 'o',
              firstName: 'Aroha',
              phoneNumber: '+64 21 555 0101',
            ),
          ),
          dark: dark,
          scale: 2,
          width: 320,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Fix leaking tap'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('navigate_button')),
          200,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
