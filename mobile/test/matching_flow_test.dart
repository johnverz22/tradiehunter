import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
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
        // v1.7: matching no longer routes to a match-result screen — a
        // matched status pushes the booked job detail (and payment stays a
        // detail-screen action), so only those destinations are mounted.
        for (final path in [
          '/jobs/:id/payment',
          '/jobs/:id/detail',
          '/jobs/:id/tradies',
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
    testWidgets('request-sent v2 renders server offer facts and actions', (
      tester,
    ) async {
      final repo = MatchRepo()
        ..pendingOffer = JobOffer(
          id: 'offer-42',
          jobId: '42',
          tradieId: 't1',
          offeredAtUtc: DateTime.now().toUtc(),
          expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          response: 'Pending',
          stage: 'Direct',
          kind: 'Direct',
          hourlyRateSnapshot: Decimal.parse('85.50'),
          message: 'Please call before arriving',
          tradieName: 'Aroha Plumbing',
        );
      await mount(
        tester,
        const MatchingScreen(
          jobId: '42',
          mode: MatchingScreenMode.requestSent,
          gstLabel: 'Incl. GST',
        ),
        repo: repo,
        hub: MatchHub(),
        disableAnimations: true,
      );

      expect(find.text('You asked Aroha Plumbing'), findsOneWidget);
      expect(find.textContaining('\$85.50'), findsOneWidget);
      expect(find.text('Please call before arriving'), findsOneWidget);
      expect(find.byKey(const Key('pick_someone_else_button')), findsOneWidget);
      expect(find.byKey(const Key('cancel_request_button')), findsOneWidget);
      expect(
        find.textContaining(
          "Aroha Plumbing's rate for this job",
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

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
    }

    testWidgets('large text scale 2.0 has no overflow', (tester) async {
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: MatchRepo(),
        hub: MatchHub(),
        scale: 2.0,
        disableAnimations: true,
      );
      expect(find.text('Finding tradies near you…'), findsOneWidget);
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

    testWidgets(
      'match status event routes to the booked job detail (v1.7: no match-result screen)',
      (tester) async {
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
        expect(find.text('Destination /jobs/42/detail'), findsOneWidget);
      },
    );

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

    testWidgets('radar animation keeps headline text vertically stable', (
      tester,
    ) async {
      final repo = MatchRepo();
      final hub = MatchHub();
      await mount(
        tester,
        const MatchingScreen(jobId: '42'),
        repo: repo,
        hub: hub,
        settle: false,
      );

      hub.offerEvents.add(
        const OfferLifecycleEvent(
          jobId: '42',
          offerId: 'off-1',
          tradieId: 'tr-1',
          eventType: OfferEventType.created,
          offerIndex: 1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Contacting Tradie 1…'), findsOneWidget);

      final initialY = tester.getTopLeft(find.text('Contacting Tradie 1…')).dy;

      // Pump 60 frames across a full 2-second animation cycle (~33ms per frame)
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        final currentY = tester
            .getTopLeft(find.text('Contacting Tradie 1…'))
            .dy;
        expect(
          (currentY - initialY).abs(),
          lessThanOrEqualTo(0.5),
          reason:
              'Headline shifted vertically at frame $i from $initialY to $currentY',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
