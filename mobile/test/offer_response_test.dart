// V15-14: unified offer response + prominent countdown — shared command path
// dedup, fake-clock countdown, stale/rejected/expired handling, and
// resume/reconnect reconciliation.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/offer_responder.dart';
import 'package:fixo/views/tradie/request_detail_screen.dart';
import 'package:fixo/views/widgets/offer_countdown.dart';
import 'package:fixo/widgets/fixo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _Repo extends JobsRepository {
  _Repo() : super(Dio(), const FlutterSecureStorage());

  final calls = <({String jobId, String offerId, String response})>[];
  int offerFetches = 0;
  JobOffer? offer;
  bool respondOk = true;
  Completer<bool>? respondGate;
  bool jobReturnsNull = false;
  Job? jobOverride;

  @override
  Future<Job?> getJobById(String id) async => jobReturnsNull
      ? null
      : (jobOverride ??
          Job(
            id: id,
            title: 'Repair kitchen tap',
            category: 'Plumbing',
            suburb: 'Ponsonby',
            status: 'Requested',
            stage: 0,
            hours: 2,
            hourlyRate: Decimal.parse('85.50'),
            totalAmount: Decimal.parse('171.00'),
            description: 'Fix the tap.',
          ));

  @override
  Future<JobOffer?> getPendingOffer(String jobId) async {
    offerFetches++;
    return offer;
  }

  @override
  Future<bool> respondToOffer(
    String jobId,
    String offerId, {
    required String response,
  }) async {
    calls.add((jobId: jobId, offerId: offerId, response: response));
    final gate = respondGate;
    if (gate != null) return gate.future;
    return respondOk;
  }
}

class _Hub extends JobHubClient {
  _Hub() : super(const FlutterSecureStorage());

  @override
  Stream<OfferLifecycleEvent> get onOfferLifecycle => const Stream.empty();
  @override
  Stream<JobStatusEvent> get onJobStatusChanged => const Stream.empty();
  @override
  Stream<void> get onReconnected => const Stream.empty();
  @override
  Future<void> connect({required String baseUrl}) async {}
}

JobOffer liveOffer({Duration remaining = const Duration(minutes: 5)}) =>
    JobOffer(
      id: 'offer-1',
      jobId: '42',
      tradieId: 'tradie-1',
      offeredAtUtc: DateTime.now().toUtc(),
      expiresAtUtc: DateTime.now().toUtc().add(remaining),
      response: 'Pending',
      stage: 'Auto',
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('OfferResponder', () {
    test('success dispatches exactly one command', () async {
      final repo = _Repo();
      final responder = OfferResponder(repo);
      final outcome = await responder.respond(
        jobId: '42',
        offer: liveOffer(),
        accept: true,
      );
      expect(outcome, OfferResponseOutcome.success);
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.response, 'Accepted');
      expect(repo.calls.single.offerId, 'offer-1');
    });

    test('rejected response surfaces as rejected, not success', () async {
      final repo = _Repo()..respondOk = false;
      final responder = OfferResponder(repo);
      final outcome = await responder.respond(
        jobId: '42',
        offer: liveOffer(),
        accept: false,
      );
      expect(outcome, OfferResponseOutcome.rejected);
      expect(repo.calls.single.response, 'Declined');
    });

    test('a concurrent duplicate never dispatches a second command', () async {
      final repo = _Repo()..respondGate = Completer<bool>();
      final responder = OfferResponder(repo);

      final first = responder.respond(
        jobId: '42',
        offer: liveOffer(),
        accept: true,
      );
      // First command is in flight — a second call must be refused.
      final second = await responder.respond(
        jobId: '42',
        offer: liveOffer(),
        accept: true,
      );
      expect(second, OfferResponseOutcome.alreadyInFlight);
      expect(responder.isResponding('42'), isTrue);

      repo.respondGate!.complete(true);
      expect(await first, OfferResponseOutcome.success);
      expect(repo.calls, hasLength(1));
      expect(responder.isResponding('42'), isFalse);
    });

    test('a response may dispatch again once the first completes', () async {
      final repo = _Repo();
      final responder = OfferResponder(repo);
      await responder.respond(jobId: '42', offer: liveOffer(), accept: true);
      await responder.respond(jobId: '42', offer: liveOffer(), accept: false);
      expect(repo.calls, hasLength(2));
    });
  });

  group('OfferCountdown formatting', () {
    test('formatClock renders mm:ss under an hour, h:mm:ss above it', () {
      expect(OfferCountdown.formatClock(const Duration(seconds: 59)), '0:59');
      expect(OfferCountdown.formatClock(const Duration(minutes: 5)), '5:00');
      expect(
        OfferCountdown.formatClock(
          const Duration(hours: 1, minutes: 5, seconds: 3),
        ),
        '1:05:03',
      );
      // Clamped — never negative.
      expect(OfferCountdown.formatClock(const Duration(minutes: -2)), '0:00');
    });

    test('compactLabel is coarse above an hour', () {
      expect(
        OfferCountdown.compactLabel(const Duration(hours: 2, minutes: 14)),
        'Expires in 2h 14m',
      );
      expect(
        OfferCountdown.compactLabel(const Duration(minutes: 12, seconds: 5)),
        'Expires in 12:05',
      );
      expect(OfferCountdown.compactLabel(Duration.zero), 'Offer expired');
    });

    test('clampedRemaining never returns a negative duration', () {
      final base = DateTime.utc(2026, 7, 8, 12);
      final offer = JobOffer(
        id: 'o',
        jobId: 'j',
        tradieId: 't',
        offeredAtUtc: base,
        expiresAtUtc: base.add(const Duration(minutes: 5)),
        response: 'Pending',
        stage: 'Auto',
      );
      expect(
        OfferCountdown.clampedRemaining(offer, () => base),
        const Duration(minutes: 5),
      );
      expect(
        OfferCountdown.clampedRemaining(
          offer,
          () => base.add(const Duration(hours: 1)),
        ),
        Duration.zero,
      );
    });
  });

  group('OfferCountdown widget (fake clock)', () {
    DateTime fakeNow = DateTime.utc(2026, 7, 8, 12);

    JobOffer fakeClockOffer(Duration remaining) => JobOffer(
      id: 'o',
      jobId: 'j',
      tradieId: 't',
      offeredAtUtc: fakeNow,
      expiresAtUtc: fakeNow.add(remaining),
      response: 'Pending',
      stage: 'Auto',
    );

    Widget mount(JobOffer offer, {VoidCallback? onExpired}) => ProviderScope(
      child: MaterialApp(
        theme: FixoTheme.light(),
        home: Scaffold(
          body: OfferCountdown(
            offer: offer,
            clock: () => fakeNow,
            onExpired: onExpired,
          ),
        ),
      ),
    );

    testWidgets('counts down against expiresAtUtc and clamps at zero', (
      tester,
    ) async {
      fakeNow = DateTime.utc(2026, 7, 8, 12);
      var expiredCalls = 0;
      await tester.pumpWidget(
        mount(
          fakeClockOffer(const Duration(seconds: 90)),
          onExpired: () => expiredCalls++,
        ),
      );
      expect(find.text('Respond within 1:30'), findsOneWidget);

      fakeNow = fakeNow.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Respond within 1:00'), findsOneWidget);

      // Past the deadline — clamps at zero, never negative.
      fakeNow = fakeNow.add(const Duration(seconds: 65));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Offer expired'), findsOneWidget);
      expect(find.textContaining('-'), findsNothing);
      expect(expiredCalls, 1);

      // The expiry edge fires exactly once.
      await tester.pump(const Duration(seconds: 2));
      expect(expiredCalls, 1);
    });

    testWidgets('an already-expired offer starts in the expired state', (
      tester,
    ) async {
      fakeNow = DateTime.utc(2026, 7, 8, 12);
      var expiredCalls = 0;
      await tester.pumpWidget(
        mount(
          fakeClockOffer(const Duration(minutes: -5)),
          onExpired: () => expiredCalls++,
        ),
      );
      await tester.pump();
      expect(find.text('Offer expired'), findsOneWidget);
      expect(expiredCalls, 1);
    });

    testWidgets('expiry colour thresholds: > 2 min brand, <= 2 min amber, <= 30s danger', (
      tester,
    ) async {
      fakeNow = DateTime.utc(2026, 7, 8, 12);
      const colors = THColors.light;

      // 1. > 2 min -> brand colour
      await tester.pumpWidget(mount(fakeClockOffer(const Duration(minutes: 3))));
      final ind1 = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect((ind1.valueColor as AlwaysStoppedAnimation<Color>).value, colors.brand);

      // 2. <= 2 min -> amber colour (colors.accent)
      await tester.pumpWidget(mount(fakeClockOffer(const Duration(seconds: 90))));
      final ind2 = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect((ind2.valueColor as AlwaysStoppedAnimation<Color>).value, colors.accent);

      // 3. <= 30s -> danger colour (DesignTokens.inkDanger(false))
      await tester.pumpWidget(mount(fakeClockOffer(const Duration(seconds: 25))));
      final ind3 = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect((ind3.valueColor as AlwaysStoppedAnimation<Color>).value, DesignTokens.inkDanger(false));
    });
  });

  group('RequestDetailScreen offer flow', () {
    Future<void> mountDetail(WidgetTester tester, _Repo repo) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hub = _Hub();
      final router = GoRouter(
        initialLocation: '/request',
        routes: [
          GoRoute(
            path: '/request',
            builder: (_, _) => const RequestDetailScreen(requestId: '42'),
          ),
          GoRoute(
            path: '/tradie',
            builder: (_, _) => const Scaffold(body: Text('Tradie dashboard')),
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
            theme: FixoTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('price and countdown sit above the detail sections', (
      tester,
    ) async {
      final repo = _Repo()..offer = liveOffer();
      await mountDetail(tester, repo);
      expect(find.text(r'$171.00'), findsOneWidget);
      expect(find.text(r'2 h × $85.50/h'), findsOneWidget);
      expect(find.textContaining('Respond within'), findsOneWidget);
      // Price and countdown come before the description.
      final priceTop = tester.getTopLeft(find.text(r'$171.00')).dy;
      final descTop = tester.getTopLeft(find.text('Fix the tap.')).dy;
      expect(priceTop, lessThan(descTop));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('address fallback stays truthful before booking', (
      tester,
    ) async {
      final repo = _Repo()..offer = liveOffer();
      await mountDetail(tester, repo);
      expect(find.text('Ponsonby'), findsWidgets);
      expect(
        find.text('Exact address is shared after the job is booked.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('accept dispatches one command and leaves', (tester) async {
      final repo = _Repo()..offer = liveOffer();
      await mountDetail(tester, repo);
      await tester.tap(find.text('Accept Job'));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.response, 'Accepted');
      expect(find.text('Tradie dashboard'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('double-tap while busy still dispatches once', (tester) async {
      final repo = _Repo()
        ..offer = liveOffer()
        ..respondGate = Completer<bool>();
      await mountDetail(tester, repo);
      await tester.tap(find.text('Accept Job'));
      await tester.pump();
      // Button is busy; a second tap reaches nothing, and the shared
      // responder would refuse it anyway.
      await tester.tap(find.byType(FixoPrimaryButton), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.byType(FixoPrimaryButton), warnIfMissed: false);
      repo.respondGate!.complete(true);
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('a rejected response reconciles the offer from the server', (
      tester,
    ) async {
      final repo = _Repo()
        ..offer = liveOffer()
        ..respondOk = false;
      await mountDetail(tester, repo);
      final fetchesBefore = repo.offerFetches;
      await tester.tap(find.text('Accept Job'));
      await tester.pumpAndSettle();
      // Stays on screen, refetches the offer, and shows truthful copy.
      expect(find.text('Tradie dashboard'), findsNothing);
      expect(repo.offerFetches, greaterThan(fetchesBefore));
      expect(
        find.textContaining('Could not respond to this offer'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('a stale offer disappears after the reconciled refetch', (
      tester,
    ) async {
      final repo = _Repo()
        ..offer = liveOffer()
        ..respondOk = false;
      await mountDetail(tester, repo);
      // Server now says the offer is gone (answered elsewhere / timed out).
      repo.offer = null;
      await tester.tap(find.text('Accept Job'));
      await tester.pumpAndSettle();
      expect(find.text('This offer is no longer available.'), findsOneWidget);
      expect(find.byType(FixoPrimaryButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('expired offer disables actions — no dispatch', (tester) async {
      final repo = _Repo()
        ..offer = liveOffer(remaining: const Duration(minutes: -2));
      await mountDetail(tester, repo);
      expect(find.text('This offer has expired.'), findsOneWidget);
      expect(find.byType(FixoPrimaryButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
    });

    testWidgets('no pending offer is truthful, never a silent legacy accept', (
      tester,
    ) async {
      final repo = _Repo()..offer = null;
      await mountDetail(tester, repo);
      expect(find.text('This offer is no longer available.'), findsOneWidget);
      expect(find.byType(FixoPrimaryButton), findsNothing);
      expect(repo.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('offer fetch failure offers a retry, not a dead end', (
      tester,
    ) async {
      final repo = _Repo()..offer = liveOffer();
      var fail = true;
      // Override fetch behavior through a fresh repo subclass instance.
      final flaky = _FlakyRepo(repo, () => fail);
      await mountDetail(tester, flaky);
      expect(find.text('Could not check this offer.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Respond within'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('app resume refetches the pending offer', (tester) async {
      final repo = _Repo()..offer = liveOffer();
      await mountDetail(tester, repo);
      final fetchesBefore = repo.offerFetches;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.offerFetches, greaterThan(fetchesBefore));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('request not found shows friendly recovery with view open leads', (
      tester,
    ) async {
      final repo = _Repo()..jobReturnsNull = true;
      await mountDetail(tester, repo);
      expect(find.text('This request expired'), findsOneWidget);
      expect(find.text('View open leads'), findsOneWidget);
      await tester.tap(find.text('View open leads'));
      await tester.pumpAndSettle();
      expect(find.text('Tradie dashboard'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('photo gallery renders thumbnails and opens InteractiveViewer on tap', (
      tester,
    ) async {
      final repo = _Repo()
        ..offer = liveOffer()
        ..jobOverride = Job(
          id: '42',
          title: 'Repair kitchen tap',
          category: 'Plumbing',
          suburb: 'Ponsonby',
          status: 'Requested',
          stage: 0,
          hours: 2,
          hourlyRate: Decimal.parse('85.50'),
          totalAmount: Decimal.parse('171.00'),
          description: 'Fix the tap.',
          photoUrls: const ['https://example.com/tap.jpg'],
        );
      await mountDetail(tester, repo);
      expect(find.byType(InteractiveViewer), findsNothing);
      final thumbFinder = find.byKey(const ValueKey('photo_thumb_0'));
      await tester.scrollUntilVisible(
        thumbFinder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(thumbFinder);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Photo 1 of 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Close photo viewer'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('sticky action bar has 1/3 Decline and 2/3 Accept Job button ratio', (
      tester,
    ) async {
      final repo = _Repo()..offer = liveOffer();
      await mountDetail(tester, repo);
      final declineExpanded = tester.widget<Expanded>(
        find.ancestor(
          of: find.widgetWithText(FixoGhostButton, 'Decline'),
          matching: find.byType(Expanded),
        ),
      );
      expect(declineExpanded.flex, 1);
      final acceptExpanded = tester.widget<Expanded>(
        find.ancestor(
          of: find.widgetWithText(FixoPrimaryButton, 'Accept Job'),
          matching: find.byType(Expanded),
        ),
      );
      expect(acceptExpanded.flex, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}

/// Wraps a repo so the pending-offer fetch can be made to fail on demand.
class _FlakyRepo extends _Repo {
  _FlakyRepo(this.inner, this.shouldFail);
  final _Repo inner;
  final bool Function() shouldFail;

  @override
  Future<Job?> getJobById(String id) => inner.getJobById(id);

  @override
  Future<JobOffer?> getPendingOffer(String jobId) {
    if (shouldFail()) {
      throw DioException(
        requestOptions: RequestOptions(path: '/offers/pending'),
      );
    }
    return inner.getPendingOffer(jobId);
  }

  @override
  Future<bool> respondToOffer(
    String jobId,
    String offerId, {
    required String response,
  }) => inner.respondToOffer(jobId, offerId, response: response);
}
