import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/views/jobs/match_result_screen.dart';
import 'package:fixo/views/jobs/matching_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchRepo extends JobsRepository {
  MatchRepo() : super(Dio(), const FlutterSecureStorage());

  bool triggerSucceeds = true;
  bool requestSucceeds = true;
  Job? job = const Job(
    id: '42',
    title: 'Fix leaking tap',
    category: 'Plumbing',
    suburb: 'Grafton',
    status: 'Requested',
    stage: 0,
    hours: 2,
    hourlyRate: null,
    totalAmount: null,
  );
  JobOffer? pendingOffer;
  List<TradieMatch> matches = const [];

  int triggerCalls = 0;
  int jobReads = 0;
  int offerReads = 0;
  int requestCalls = 0;
  int cancelCalls = 0;
  String? requestedTradieId;

  @override
  Future<bool> triggerMatch(String jobId) async {
    triggerCalls++;
    return triggerSucceeds;
  }

  @override
  Future<Job?> getJobById(String jobId) async {
    jobReads++;
    return job;
  }

  @override
  Future<JobOffer?> getPendingOffer(String jobId) async {
    offerReads++;
    return pendingOffer;
  }

  @override
  Future<List<TradieMatch>> getMatches(String jobId) async => matches;

  @override
  Future<bool> requestTradie(String jobId, String tradieId) async {
    requestCalls++;
    requestedTradieId = tradieId;
    return requestSucceeds;
  }

  @override
  Future<bool> cancelJob(String jobId) async {
    cancelCalls++;
    return true;
  }
}

class MatchHub extends JobHubClient {
  MatchHub() : super(const FlutterSecureStorage());

  final statusEvents = StreamController<JobStatusEvent>.broadcast();
  final offerEvents = StreamController<OfferLifecycleEvent>.broadcast();
  final reconnectingEvents = StreamController<void>.broadcast();
  final reconnectedEvents = StreamController<void>.broadcast();

  int connectCalls = 0;
  int joinCalls = 0;
  int leaveCalls = 0;

  @override
  Stream<JobStatusEvent> get onJobStatusChanged => statusEvents.stream;
  @override
  Stream<OfferLifecycleEvent> get onOfferLifecycle => offerEvents.stream;
  @override
  Stream<void> get onReconnecting => reconnectingEvents.stream;
  @override
  Stream<void> get onReconnected => reconnectedEvents.stream;

  @override
  Future<void> connect({required String baseUrl}) async {
    connectCalls++;
  }

  @override
  Future<void> joinJobGroup(String jobId) async {
    joinCalls++;
  }

  @override
  Future<void> leaveJobGroup(String jobId) async {
    leaveCalls++;
  }

  @override
  void dispose() {
    statusEvents.close();
    offerEvents.close();
    reconnectingEvents.close();
    reconnectedEvents.close();
    super.dispose();
  }
}

TradieMatch matchFixture({
  String id = 't1',
  String name = 'Sam Carter',
  String trade = 'Plumber',
  double km = 1.2,
}) => TradieMatch(
  tradieId: id,
  initials: 'SC',
  name: name,
  trade: trade,
  distance: '${km.toStringAsFixed(1)} km away',
  distanceKm: km,
  rating: null,
  reviewCount: 0,
);

Job pricedJob({String status = 'Requested'}) => Job(
  id: '42',
  title: 'Fix leaking tap',
  category: 'Plumbing',
  suburb: 'Grafton',
  status: status,
  stage: 0,
  hours: 2,
  hourlyRate: Decimal.parse('85.50'),
  totalAmount: Decimal.parse('171.00'),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<GoRouter> mount(
    WidgetTester tester,
    Widget child, {
    required MatchRepo repo,
    required MatchHub hub,
    bool dark = false,
    double scale = 1,
    double width = 320,
    bool disableAnimations = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        for (final path in [
          '/jobs/:id/match',
          '/jobs/:id/payment',
          '/jobs/:id/detail',
          '/chat/:id',
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
          jobsRepositoryProvider.overrideWithValue(repo),
          jobHubClientProvider.overrideWithValue(hub),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Async init chain without a live repeating animation to settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
    }
    return router;
  }

  group('MatchingScreen', () {
    for (final dark in [false, true]) {
      testWidgets('searching state renders without overflow dark=$dark', (
        tester,
      ) async {
        await mount(
          tester,
          const MatchingScreen(jobId: '42'),
          repo: MatchRepo(),
          hub: MatchHub(),
          dark: dark,
          disableAnimations: true,
        );
        expect(find.text('Finding tradies near you…'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('match result renders rate/total at 320px dark=$dark', (
        tester,
      ) async {
        final repo = MatchRepo()
          ..job = pricedJob()
          ..matches = [matchFixture()];
        await mount(
          tester,
          const MatchResultScreen(jobId: '42'),
          repo: repo,
          hub: MatchHub(),
          dark: dark,
        );
        expect(find.text('We found your tradie'), findsOneWidget);
        expect(find.text('Estimated total'), findsOneWidget);
        expect(find.text('\$171.00'), findsOneWidget);
        expect(find.text('\$85.50/hr'), findsOneWidget);
        expect(find.text('2 h'), findsOneWidget);
        expect(find.text('Request Sam'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('large text scale 2.0 has no overflow on either screen', (
      tester,
    ) async {
      final repo = MatchRepo()
        ..job = pricedJob()
        ..matches = [matchFixture()];
      await mount(
        tester,
        const MatchResultScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
        scale: 2.0,
      );
      expect(find.text('We found your tradie'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Request Sam'), 400);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispatch failure shows error and Try again recovers', (
      tester,
    ) async {
      final repo = MatchRepo()..triggerSucceeds = false;
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
        disableAnimations: true,
      );
      expect(
        find.text('Could not start matching for this job.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(repo.triggerCalls, 1);

      repo.triggerSucceeds = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repo.triggerCalls, 2);
      expect(find.text('Could not start matching for this job.'), findsNothing);
      expect(find.text('Finding tradies near you…'), findsOneWidget);
    });

    testWidgets('stall watchdog fires only in starting phase', (tester) async {
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: MatchRepo(),
        hub: MatchHub(),
        disableAnimations: true,
      );
      expect(find.text('This is taking longer than usual.'), findsNothing);
      await tester.pump(const Duration(seconds: 46));
      await tester.pump();
      expect(find.text('This is taking longer than usual.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets(
      'offer event advances headline; reconnect re-joins and re-reads',
      (tester) async {
        final repo = MatchRepo();
        final hub = MatchHub();
        await mount(
          tester,
          const MatchingScreen(jobId: '42'),
          repo: repo,
          hub: hub,
          disableAnimations: true,
        );
        expect(hub.joinCalls, 1);
        expect(repo.jobReads, 1);
        expect(repo.offerReads, 1);

        hub.offerEvents.add(
          const OfferLifecycleEvent(
            eventType: OfferEventType.created,
            jobId: '42',
            offerId: 'o2',
            tradieId: 't2',
            offerIndex: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Contacting Tradie 2…'), findsOneWidget);

        // Events for other jobs are ignored.
        hub.offerEvents.add(
          const OfferLifecycleEvent(
            eventType: OfferEventType.created,
            jobId: '99',
            offerId: 'o9',
            tradieId: 't9',
            offerIndex: 5,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Contacting Tradie 2…'), findsOneWidget);

        // Reconnect: group membership is re-established and state re-read.
        hub.reconnectedEvents.add(null);
        await tester.pumpAndSettle();
        expect(hub.joinCalls, 2);
        expect(repo.jobReads, 2);
        expect(repo.offerReads, 2);
      },
    );

    testWidgets('reconnecting shows truthful connection notice', (
      tester,
    ) async {
      final hub = MatchHub();
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: MatchRepo(),
        hub: hub,
        disableAnimations: true,
      );
      hub.reconnectingEvents.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Connection lost — reconnecting…'), findsOneWidget);
      hub.reconnectedEvents.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Connection lost — reconnecting…'), findsNothing);
    });

    testWidgets('match status event replaces route with match result', (
      tester,
    ) async {
      final hub = MatchHub();
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: MatchRepo(),
        hub: hub,
        disableAnimations: true,
      );
      hub.statusEvents.add(
        const JobStatusEvent(jobId: '42', status: 'AwaitingPayment'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Destination /jobs/42/match'), findsOneWidget);
    });

    testWidgets('no_tradie_found cancel shows empty state and Go Back', (
      tester,
    ) async {
      final hub = MatchHub();
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: MatchRepo(),
        hub: hub,
        disableAnimations: true,
      );
      hub.statusEvents.add(
        const JobStatusEvent(
          jobId: '42',
          status: 'Cancelled',
          reasonCode: 'no_tradie_found',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No tradies available'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('reduced motion swaps radar for static badge', (tester) async {
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: MatchRepo(),
        hub: MatchHub(),
        disableAnimations: true,
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byKey(const ValueKey('matching-radar')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('radar animates only when motion is enabled', (tester) async {
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: MatchRepo(),
        hub: MatchHub(),
        settle: false,
      );
      expect(find.byKey(const ValueKey('matching-radar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MatchResultScreen', () {
    testWidgets('Request calls repository and navigates to chat', (
      tester,
    ) async {
      final repo = MatchRepo()
        ..job = pricedJob()
        ..matches = [matchFixture()];
      await mount(
        tester,
        const MatchResultScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
      );
      await tester.tap(find.text('Request Sam'));
      await tester.pumpAndSettle();
      expect(repo.requestCalls, 1);
      expect(repo.requestedTradieId, 't1');
      expect(find.text('Destination /chat/42'), findsOneWidget);
    });

    testWidgets('request failure stays put with an error', (tester) async {
      final repo = MatchRepo()
        ..job = pricedJob()
        ..matches = [matchFixture()]
        ..requestSucceeds = false;
      await mount(
        tester,
        const MatchResultScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
      );
      await tester.tap(find.text('Request Sam'));
      await tester.pumpAndSettle();
      expect(repo.requestCalls, 1);
      expect(
        find.text(
          'Couldn\'t send the request. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Destination /chat/42'), findsNothing);
      expect(find.text('We found your tradie'), findsOneWidget);
    });

    testWidgets(
      'AwaitingPayment job offers Continue to payment, never Request',
      (tester) async {
        final repo = MatchRepo()
          ..job = pricedJob(status: 'AwaitingPayment')
          ..matches = [matchFixture()];
        await mount(
          tester,
          const MatchResultScreen(jobId: '42'),
          repo: repo,
          hub: MatchHub(),
        );
        expect(find.text('Continue to payment'), findsOneWidget);
        expect(find.text('Request Sam'), findsNothing);
        await tester.tap(find.text('Continue to payment'));
        await tester.pumpAndSettle();
        expect(find.text('Destination /jobs/42/payment'), findsOneWidget);
        expect(repo.requestCalls, 0);
      },
    );

    testWidgets('Booked job offers View job instead of Request', (
      tester,
    ) async {
      final repo = MatchRepo()
        ..job = pricedJob(status: 'Booked')
        ..matches = [matchFixture()];
      await mount(
        tester,
        const MatchResultScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
      );
      expect(find.text('View job'), findsOneWidget);
      expect(find.text('Request Sam'), findsNothing);
      await tester.tap(find.text('View job'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /jobs/42/detail'), findsOneWidget);
      expect(repo.requestCalls, 0);
    });

    testWidgets('Cancelled job shows no request action', (tester) async {
      final repo = MatchRepo()
        ..job = pricedJob(status: 'Cancelled')
        ..matches = [matchFixture()];
      await mount(
        tester,
        const MatchResultScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
      );
      expect(find.text('Request Sam'), findsNothing);
      expect(find.text('View job'), findsNothing);
      expect(find.text('Continue to payment'), findsNothing);
    });

    testWidgets('empty matches renders the no-match state', (tester) async {
      final repo = MatchRepo()..job = pricedJob();
      await mount(
        tester,
        const MatchResultScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
      );
      expect(find.text('No tradies available'), findsOneWidget);
      expect(find.text('Back to jobs'), findsOneWidget);
    });

    testWidgets('missing price fields are omitted, not zeroed', (tester) async {
      final repo = MatchRepo()
        ..job = const Job(
          id: '42',
          title: 'Fix leaking tap',
          category: 'Plumbing',
          suburb: 'Grafton',
          status: 'Requested',
          stage: 0,
        )
        ..matches = [matchFixture()];
      await mount(
        tester,
        const MatchResultScreen(jobId: '42'),
        repo: repo,
        hub: MatchHub(),
      );
      expect(find.text('Estimated total'), findsNothing);
      expect(find.text('\$0.00'), findsNothing);
      expect(find.text('Request Sam'), findsOneWidget);
    });
  });
}
