// Phase 5.2: v2 tradie request detail (`tr_lead`).
//
// Pure rules (price block, location, schedule, received label, bar variant,
// quote payload) are tested without widgets; the screen runs against faked
// repositories + SignalR, keeping the preserved v1 Keys and copy.
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/feedback/fixo_notice_controller.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/tradie/tr_lead_mapper.dart';
import 'package:fixo/ui/tradie/tr_lead_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

Job _job({
  String id = 'r1',
  String suburb = 'Ponsonby',
  int hours = 0,
  Decimal? rate,
  Decimal? total,
  DateTime? scheduled,
  List<String> photos = const [],
  String? description,
  String? referenceCode,
}) => Job(
  id: id,
  title: 'Leaking tap',
  category: 'Plumbing',
  suburb: suburb,
  status: 'Requested',
  stage: 0,
  description: description,
  photoUrls: photos,
  hours: hours,
  hourlyRate: rate,
  totalAmount: total,
  scheduledStartUtc: scheduled?.toUtc(),
  referenceCode: referenceCode,
);

JobOffer _offer({
  Duration left = const Duration(minutes: 10),
  String kind = 'Auto',
  Duration age = const Duration(minutes: 2),
}) {
  final now = DateTime.now().toUtc();
  return JobOffer(
    id: 'offer-r1',
    jobId: 'r1',
    tradieId: 't1',
    offeredAtUtc: now.subtract(age),
    expiresAtUtc: now.add(left),
    response: 'Pending',
    stage: 'Auto',
    kind: kind,
  );
}

class _JobsRepo extends JobsRepository {
  _JobsRepo({this.job, this.offer, this.respondOk = true})
    : super(Dio(), const FlutterSecureStorage());
  final Job? job;
  final JobOffer? offer;
  final bool respondOk;
  final List<String> responses = [];
  final List<Map<String, dynamic>> quotes = [];

  @override
  Future<Job?> getJobById(String jobId) async => job;

  @override
  Future<JobOffer?> getPendingOffer(String jobId) async => offer;

  @override
  Future<bool> respondToOffer(
    String jobId,
    String offerId, {
    required String response,
  }) async {
    responses.add('$jobId:$response');
    return respondOk;
  }

  @override
  Future<void> createQuote(String jobId, Map<String, dynamic> payload) async {
    quotes.add(payload);
  }
}

class _ProfileRepo extends ProfileRepository {
  _ProfileRepo() : super(Dio(), const FlutterSecureStorage());
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

  group('price block', () {
    test('total and breakdown from real fields', () {
      final job = _job(
        hours: 3,
        rate: Decimal.parse('85'),
        total: Decimal.parse('255'),
      );
      expect(trPriceTotal(job), r'$255.00');
      expect(trPriceBreakdown(job), r'3 h × $85.00/h');
    });

    test('no total shows a dash, never a zero', () {
      expect(trPriceTotal(_job()), '—');
    });

    test('hours without a rate, and no hours at all', () {
      expect(trPriceBreakdown(_job(hours: 2)), '2h');
      expect(trPriceBreakdown(_job()), isNull);
    });
  });

  group('location and schedule', () {
    test('suburb, then address, then fallback', () {
      expect(trLocationLabel(_job()), 'Ponsonby');
      expect(trLocationLabel(_job(suburb: '')), 'Location on file');
    });

    test('schedule only when a start is set, with hours appended', () {
      expect(trScheduleLabel(_job()), isNull);
      final label = trScheduleLabel(
        _job(scheduled: DateTime(2026, 11, 30, 9, 30), hours: 3),
      );
      expect(label, 'Monday 30 November · 9:30 AM · 3h');
    });

    test('relative photo URLs resolve against the base URL', () {
      expect(
        trResolvePhotoUrl('/api/photos/1', 'https://h'),
        'https://h/api/photos/1',
      );
      expect(
        trResolvePhotoUrl('https://x/y.jpg', 'https://h'),
        'https://x/y.jpg',
      );
    });
  });

  group('received label and subtitle (G-16)', () {
    final now = DateTime.utc(2026, 11, 25, 12);
    JobOffer offered(Duration ago) => JobOffer(
      id: 'o',
      jobId: 'r1',
      tradieId: 't',
      offeredAtUtc: now.subtract(ago),
      expiresAtUtc: now.add(const Duration(minutes: 5)),
      response: 'Pending',
      stage: 'Auto',
    );

    test('buckets', () {
      expect(
        trReceivedLabel(offered(const Duration(seconds: 20)), now),
        'Received just now',
      );
      expect(
        trReceivedLabel(offered(const Duration(minutes: 2)), now),
        'Received 2 min ago',
      );
      expect(
        trReceivedLabel(offered(const Duration(hours: 3)), now),
        'Received 3 h ago',
      );
      expect(
        trReceivedLabel(offered(const Duration(days: 2)), now),
        'Received 2 d ago',
      );
      expect(trReceivedLabel(null, now), isNull);
    });

    test('subtitle uses only real fields', () {
      final o = offered(const Duration(minutes: 2));
      expect(
        trLeadSubtitle(_job(referenceCode: 'TH-4821'), o, now),
        'Received 2 min ago · Job #TH-4821',
      );
      expect(trLeadSubtitle(_job(), o, now), 'Received 2 min ago');
      expect(trLeadSubtitle(_job(), null, now), isNull);
    });
  });

  group('bar variant', () {
    test('gone, expired, accept, quote', () {
      expect(trLeadBar(null), TrLeadBar.gone);
      expect(
        trLeadBar(_offer(left: const Duration(seconds: -5))),
        TrLeadBar.expired,
      );
      expect(trLeadBar(_offer()), TrLeadBar.accept);
      expect(trLeadBar(_offer(kind: 'QuoteRequest')), TrLeadBar.quote);
    });
  });

  group('quote payload (v1 contract #12 rules)', () {
    test('fixed price', () {
      const draft = TrQuoteDraft(amount: '450');
      expect(draft.toPayload(), {
        'pricingModel': 'Fixed',
        'amount': '450',
        'materialsIncluded': false,
        'gstIncluded': false,
      });
    });

    test('estimate range with optional fields', () {
      final draft = TrQuoteDraft(
        pricingModel: Quote.pricingEstimateRange,
        min: '300',
        max: '500',
        inclusions: '  parts  ',
        duration: '3',
        materialsIncluded: true,
        gstIncluded: true,
        proposedStart: DateTime.utc(2026, 12, 1, 9),
      );
      expect(draft.toPayload(), {
        'pricingModel': 'EstimateRange',
        'minAmount': '300',
        'maxAmount': '500',
        'inclusions': 'parts',
        'materialsIncluded': true,
        'gstIncluded': true,
        'proposedStartUtc': '2026-12-01T09:00:00.000Z',
        'estimatedDurationDays': 3,
      });
    });

    test('hourly with cap', () {
      const draft = TrQuoteDraft(
        pricingModel: Quote.pricingHourlyWithCap,
        rate: '85',
        cap: '600',
      );
      expect(draft.toPayload(), {
        'pricingModel': 'HourlyWithCap',
        'amount': '85',
        'cap': '600',
        'materialsIncluded': false,
        'gstIncluded': false,
      });
    });

    test('invalid forms produce no payload', () {
      expect(const TrQuoteDraft().toPayload(), isNull);
      expect(const TrQuoteDraft(amount: '0').toPayload(), isNull);
      expect(const TrQuoteDraft(amount: '-5').toPayload(), isNull);
      const inverted = TrQuoteDraft(
        pricingModel: Quote.pricingEstimateRange,
        min: '500',
        max: '300',
      );
      expect(inverted.rangeInverted, isTrue);
      expect(inverted.toPayload(), isNull);
      expect(
        const TrQuoteDraft(
          pricingModel: Quote.pricingHourlyWithCap,
          rate: '85',
        ).toPayload(),
        isNull,
      );
    });

    test('GST helper copy', () {
      expect(
        trGstHelper(fromProfile: true, included: true),
        contains('GST-registered'),
      );
      expect(
        trGstHelper(fromProfile: false, included: false),
        contains('not GST-registered'),
      );
      expect(
        trGstHelper(fromProfile: null, included: false),
        contains('Tick only'),
      );
    });
  });

  group('screen', () {
    late GoRouter router;
    late _JobsRepo repo;

    Future<void> pump(
      WidgetTester tester, {
      Job? job,
      JobOffer? offer,
      bool respondOk = true,
      bool dark = false,
      Size size = const Size(390, 1600),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = _JobsRepo(job: job, offer: offer, respondOk: respondOk);
      router = GoRouter(
        initialLocation: '/tradie/requests/r1',
        routes: [
          GoRoute(
            path: '/tradie/requests/:requestId',
            builder: (_, s) =>
                TradieLeadScreen(requestId: s.pathParameters['requestId']!),
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
            profileRepositoryProvider.overrideWithValue(_ProfileRepo()),
            jobHubClientProvider.overrideWithValue(_Hub()),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(TradieLeadScreen)),
        );

    for (final dark in [false, true]) {
      testWidgets('renders the request (dark=$dark)', (tester) async {
        await pump(
          tester,
          job: _job(
            hours: 3,
            rate: Decimal.parse('85'),
            total: Decimal.parse('255'),
            description: 'Drips constantly',
            referenceCode: 'TH-4821',
          ),
          offer: _offer(),
          dark: dark,
        );
        expect(find.text('Leaking tap'), findsOneWidget);
        expect(find.text('Drips constantly'), findsOneWidget);
        expect(find.text(r'$255.00'), findsOneWidget);
        expect(find.text('Accept Job'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);
        expect(find.textContaining('Respond within'), findsOneWidget);
        expect(find.textContaining('Job #TH-4821'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('accept posts once and leaves to /tradie', (tester) async {
      await pump(tester, job: _job(), offer: _offer());
      await tester.tap(find.text('Accept Job'));
      await tester.pumpAndSettle();
      expect(repo.responses, ['r1:Accepted']);
      expect(find.text('At /tradie'), findsOneWidget);
    });

    testWidgets('decline posts Declined', (tester) async {
      await pump(tester, job: _job(), offer: _offer());
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(repo.responses, ['r1:Declined']);
    });

    testWidgets('rejected response keeps the screen and raises a notice', (
      tester,
    ) async {
      await pump(tester, job: _job(), offer: _offer(), respondOk: false);
      await tester.tap(find.text('Accept Job'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container(tester).read(fixoNoticeProvider)?.message,
        'Could not respond to this offer — it may have expired.',
      );
      expect(find.text('Accept Job'), findsOneWidget);
    });

    testWidgets('no pending offer shows the gone state, no actions', (
      tester,
    ) async {
      await pump(tester, job: _job(), offer: null);
      expect(find.textContaining('no longer available'), findsWidgets);
      expect(find.text('Accept Job'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('expired offer disables actions', (tester) async {
      await pump(
        tester,
        job: _job(),
        offer: _offer(left: const Duration(seconds: -5)),
      );
      expect(find.text('This offer has expired.'), findsOneWidget);
      expect(find.text('Accept Job'), findsNothing);
    });

    testWidgets('missing job shows the expired-request state', (tester) async {
      await pump(tester, job: null, offer: null);
      expect(find.text('This request expired'), findsOneWidget);
      expect(find.text('View open leads'), findsOneWidget);
      await tester.tap(find.text('View open leads'));
      await tester.pumpAndSettle();
      expect(find.text('At /tradie'), findsOneWidget);
    });

    testWidgets('photo strip opens the viewer and closes', (tester) async {
      await pump(
        tester,
        job: _job(photos: const ['/api/photos/1', '/api/photos/2']),
        offer: _offer(),
      );
      expect(find.byKey(const ValueKey('photo_thumb_0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('photo_thumb_1')));
      await tester.pumpAndSettle();
      expect(find.text('Photo 2 of 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Close photo viewer'));
      await tester.pumpAndSettle();
      expect(find.text('Photo 2 of 2'), findsNothing);
    });

    testWidgets('quote request: submit opens the form and posts the payload', (
      tester,
    ) async {
      await pump(
        tester,
        job: _job(),
        offer: _offer(kind: 'QuoteRequest'),
      );
      expect(find.text('Accept Job'), findsNothing);
      await tester.tap(find.byKey(const Key('submit_quote_button')));
      await tester.pumpAndSettle();
      expect(find.text('Submit quote'), findsWidgets);

      await tester.enterText(
        find.byKey(const Key('quote_amount_field')),
        '450',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('quote_submit_button')));
      await tester.tap(find.byKey(const Key('quote_submit_button')));
      await tester.pumpAndSettle();

      expect(repo.quotes, [
        {
          'pricingModel': 'Fixed',
          'amount': '450',
          'materialsIncluded': false,
          'gstIncluded': false,
        },
      ]);
      expect(find.text('At /tradie'), findsOneWidget);
    });

    testWidgets('quote send stays disabled until the form is valid', (
      tester,
    ) async {
      await pump(
        tester,
        job: _job(),
        offer: _offer(kind: 'QuoteRequest'),
      );
      await tester.tap(find.byKey(const Key('submit_quote_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('quote_submit_button')));
      await tester.tap(find.byKey(const Key('quote_submit_button')));
      await tester.pumpAndSettle();
      expect(repo.quotes, isEmpty);
      expect(find.byKey(const Key('quote_amount_field')), findsOneWidget);
    });

    testWidgets('survives 200% text on a narrow phone', (tester) async {
      await pump(
        tester,
        job: _job(
          hours: 3,
          rate: Decimal.parse('85'),
          total: Decimal.parse('255'),
          description: 'Drips constantly, worse when the hot water is on.',
          scheduled: DateTime(2026, 11, 30, 9, 30),
        ),
        offer: _offer(),
        size: const Size(320, 900),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
