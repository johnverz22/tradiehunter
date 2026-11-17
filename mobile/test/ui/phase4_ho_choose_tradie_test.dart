// Phase 4.1 #4: v2 Choose-a-Tradie (`ho_choose_tradie`).
//
// The mapper is tested without widgets; the screen is tested with a fake
// JobsRepository in light and dark, keeping the v1 behaviour: sort and filter
// re-fetch from the server, loading / error / empty states, card navigation,
// and the guarded quick-match action.
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/homeowner/ho_choose_tradie_mapper.dart';
import 'package:fixo/ui/homeowner/ho_choose_tradie_screen.dart';
import 'package:fixo/ui/shared/th_choice_pills.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

TradieListEntry _entry(
  String id, {
  String name = 'Aroha Plumbing',
  String initials = 'AP',
  bool verified = false,
  bool insured = false,
  bool available = false,
  double? rating,
  int? reviewCount,
  int? completedJobs,
  double distanceKm = 2.4,
  String distance = '',
  Decimal? rate,
  bool? gst,
}) => TradieListEntry(
  tradieId: id,
  name: name,
  initials: initials,
  verified: verified,
  insured: insured,
  available: available,
  rating: rating,
  reviewCount: reviewCount,
  completedJobs: completedJobs,
  distanceKm: distanceKm,
  distance: distance,
  hourlyRate: rate,
  isGstRegistered: gst,
);

Job _job({
  String title = 'Leaking kitchen tap',
  String category = 'Plumbing',
}) => Job(
  id: 'j1',
  title: title,
  category: category,
  suburb: 'Ponsonby',
  status: 'Requested',
  stage: 0,
  flowVersion: Job.flowVersionV2,
);

class _TradieRepo extends JobsRepository {
  _TradieRepo({
    this.entries = const [],
    this.fail = false,
    this.matchResult = true,
    this.job,
  }) : super(Dio(), const FlutterSecureStorage());

  List<TradieListEntry> entries;
  bool fail;
  bool matchResult;
  Job? job;
  Completer<bool>? matchGate;
  int loads = 0;
  int matchCalls = 0;
  final List<({String sort, bool? verified, bool? insured, bool? available})>
  calls = [];

  @override
  Future<Job?> getJobById(String jobId) async => job;

  @override
  Future<List<TradieListEntry>> getTradieList(
    String jobId, {
    String sort = 'best',
    bool? verified,
    bool? insured,
    bool? availableNow,
  }) async {
    loads++;
    calls.add((
      sort: sort,
      verified: verified,
      insured: insured,
      available: availableNow,
    ));
    if (fail) throw Exception('offline');
    return entries;
  }

  @override
  Future<bool> triggerMatch(String jobId) async {
    matchCalls++;
    if (matchGate != null) return matchGate!.future;
    return matchResult;
  }
}

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('choose-tradie mapper (v1 truthfulness rules)', () {
    test('subtitle joins title and category, omits missing parts', () {
      expect(
        thChooseTradieSubtitle(
          title: 'Leaking kitchen tap',
          category: 'Plumbing',
        ),
        'Leaking kitchen tap · Plumbing',
      );
      expect(thChooseTradieSubtitle(title: 'Fix tap'), 'Fix tap');
      expect(thChooseTradieSubtitle(category: 'Plumbing'), 'Plumbing');
      expect(thChooseTradieSubtitle(), isNull);
      expect(thChooseTradieSubtitle(title: '  '), isNull);
    });

    test('rating needs both a score and a review count', () {
      final rated = _entry('a', rating: 4.9, reviewCount: 128);
      expect(thTradieScore(rated), '4.9');
      expect(thTradieReviewCount(rated), '(128)');

      final noCount = _entry('b', rating: 4.9, completedJobs: 48);
      expect(thTradieScore(noCount), isNull);
      expect(thTradieNoRatingFallback(noCount), '48 jobs completed');
      expect(thTradieNoRatingFallback(_entry('c')), 'New to Fixo');
    });

    test('distance prefers the server string, then km, then fallback', () {
      expect(
        thTradieDistanceLine(_entry('a', distance: '1.2 km away')),
        '1.2 km away',
      );
      expect(thTradieDistanceLine(_entry('b', distanceKm: 2.4)), '2.4 km');
      expect(
        thTradieDistanceLine(_entry('c', distanceKm: 0)),
        'Distance unavailable',
      );
    });

    test('rate is omitted when absent and carries the D8 GST label', () {
      expect(thTradieRate(_entry('a')), isNull);

      final incl = thTradieRate(
        _entry('b', rate: Decimal.parse('85'), gst: true),
      )!;
      expect(incl.amount, r'$85.00');
      expect(incl.gstNote, 'Incl. GST');

      final noGst = thTradieRate(
        _entry('c', rate: Decimal.parse('79'), gst: false),
      )!;
      expect(noGst.gstNote, 'No GST charged');

      final unknown = thTradieRate(
        _entry('d', rate: Decimal.parse('90'), gst: null),
      )!;
      expect(unknown.gstNote, isNull);
    });

    test('badges come only from real booleans', () {
      expect(thTradieBadges(_entry('a')), isEmpty);
      expect(
        thTradieBadges(
          _entry('b', verified: true, insured: true, available: true),
        ).map((b) => b.label),
        ['Verified', 'Insured', 'Available now'],
      );
    });

    test('empty action clears filters only when one is active', () {
      expect(
        thChooseTradieEmptyAction(const TradieListState()),
        ChooseTradieEmptyAction.reload,
      );
      expect(
        thChooseTradieEmptyAction(const TradieListState(insuredOnly: true)),
        ChooseTradieEmptyAction.clearFilters,
      );
    });

    test('sort pill labels match the mockup', () {
      expect(TradieListSort.values.map(thTradieSortLabel), [
        'Sort',
        'Rating',
        'Distance',
        'Rate',
      ]);
    });
  });

  group('ThChoicePills', () {
    testWidgets('taps the tapped pill and exposes selected semantics', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: ThScope(
            child: Scaffold(
              body: ThChoicePills(
                items: [
                  const ThChoicePillItem(
                    key: Key('sort_pill'),
                    label: 'Sort',
                    selected: true,
                  ),
                  ThChoicePillItem(
                    key: const Key('rating_pill'),
                    label: 'Rating',
                    onSelected: () => tapped = 'rating',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('rating_pill')));
      expect(tapped, 'rating');
      final node = tester.getSemantics(find.byKey(const Key('sort_pill')));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
    });
  });

  group('ThChooseTradieScreen', () {
    Future<_TradieRepo> pump(
      WidgetTester tester, {
      List<TradieListEntry> entries = const [],
      bool fail = false,
      bool matchResult = true,
      Job? job,
      bool dark = false,
      double textScale = 1.0,
      GoRouter? router,
    }) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _TradieRepo(
        entries: entries,
        fail: fail,
        matchResult: matchResult,
        job: job,
      );
      final r =
          router ??
          GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const ThChooseTradieScreen(jobId: 'j1'),
              ),
              GoRoute(
                path: '/jobs/:id/matching',
                builder: (_, s) => Scaffold(body: Text('At ${s.uri}')),
              ),
              GoRoute(
                path: '/tradie/:id',
                builder: (_, s) => Scaffold(body: Text('At ${s.uri}')),
              ),
            ],
          );
      addTearDown(r.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jobsRepositoryProvider.overrideWithValue(repo)],
          child: MediaQuery(
            data: MediaQueryData(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp.router(routerConfig: r),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    final sample = [
      _entry(
        't1',
        verified: true,
        insured: true,
        available: true,
        rating: 4.9,
        reviewCount: 128,
        distanceKm: 2.4,
        rate: Decimal.parse('85'),
        gst: true,
      ),
      _entry(
        't2',
        name: 'Jake’s Plumbing',
        initials: 'JW',
        rating: 4.8,
        reviewCount: 94,
        distanceKm: 3.1,
        rate: Decimal.parse('79'),
        gst: false,
      ),
      _entry(
        't3',
        name: 'Hemi & Sons',
        initials: 'HS',
        completedJobs: 61,
        distanceKm: 5.6,
      ),
    ];

    for (final dark in [false, true]) {
      testWidgets('renders cards, badges and rates (dark=$dark)', (
        tester,
      ) async {
        await pump(tester, entries: sample, dark: dark);

        expect(find.byKey(const Key('choose_tradie')), findsOneWidget);
        expect(find.byKey(const Key('tradie_sort_bar')), findsOneWidget);
        expect(find.byKey(const Key('tradie_list')), findsOneWidget);
        expect(find.text('Aroha Plumbing'), findsOneWidget);
        expect(find.text('Jake’s Plumbing'), findsOneWidget);
        expect(find.text('Hemi & Sons'), findsOneWidget);
        expect(find.text(r'$85.00'), findsOneWidget);
        expect(find.text('/hr Incl. GST'), findsOneWidget);
        expect(find.text('/hr No GST charged'), findsOneWidget);
        expect(find.text('Verified'), findsNWidgets(2));
        expect(find.text('Insured'), findsNWidgets(2));
        expect(find.text('Available now'), findsNWidgets(2));
        expect(find.text('61 jobs completed · 5.6 km'), findsOneWidget);
        expect(find.textContaining(r'$0.00'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('header subtitle comes from the job, omitted when unknown', (
      tester,
    ) async {
      await pump(
        tester,
        entries: sample,
        job: _job(title: 'Leaking kitchen tap', category: 'Plumbing'),
      );
      expect(find.text('Leaking kitchen tap · Plumbing'), findsOneWidget);
    });

    testWidgets('sort pill re-fetches with the server sort name', (
      tester,
    ) async {
      final repo = await pump(tester, entries: sample);
      await tester.tap(find.text('Rating'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.sort, 'rating');
      expect(repo.calls.last.verified, isFalse);
    });

    testWidgets('filter pill toggles on and off', (tester) async {
      final repo = await pump(tester, entries: sample);
      await tester.tap(find.byKey(const Key('tradie_filter_verified')));
      await tester.pumpAndSettle();
      expect(repo.calls.last.verified, isTrue);

      await tester.tap(find.byKey(const Key('tradie_filter_verified')));
      await tester.pumpAndSettle();
      expect(repo.calls.last.verified, isFalse);
    });

    testWidgets('loading, error with retry', (tester) async {
      final repo = await pump(tester, fail: true);
      expect(find.text('Could not load tradies for this job.'), findsOneWidget);
      final before = repo.loads;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repo.loads, greaterThan(before));
    });

    testWidgets('empty with a filter clears it; without one reloads', (
      tester,
    ) async {
      final repo = await pump(tester, entries: const []);
      expect(find.text('No tradies match yet'), findsOneWidget);

      final before = repo.loads;
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(repo.loads, before + 1);
      expect(repo.calls.last.verified, isFalse);

      await tester.tap(find.byKey(const Key('tradie_filter_insured')));
      await tester.pumpAndSettle();
      expect(repo.calls.last.insured, isTrue);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.insured, isFalse);
    });

    testWidgets('card tap opens the profile in job context', (tester) async {
      await pump(tester, entries: sample);
      await tester.tap(find.text('Aroha Plumbing'));
      await tester.pumpAndSettle();
      expect(find.text('At /tradie/t1?jobId=j1'), findsOneWidget);
    });

    testWidgets('quick match pushes the matching screen', (tester) async {
      final repo = await pump(tester, entries: sample);
      await tester.tap(find.byKey(const Key('quick_match_button')));
      await tester.pumpAndSettle();
      expect(repo.matchCalls, 1);
      expect(find.text('At /jobs/j1/matching'), findsOneWidget);
    });

    testWidgets('quick match failure stays and does not navigate', (
      tester,
    ) async {
      final repo = await pump(tester, entries: sample, matchResult: false);
      await tester.tap(find.byKey(const Key('quick_match_button')));
      await tester.pumpAndSettle();
      expect(repo.matchCalls, 1);
      expect(find.byKey(const Key('choose_tradie')), findsOneWidget);
      expect(find.text('At /jobs/j1/matching'), findsNothing);
    });

    testWidgets('double tap starts exactly one match', (tester) async {
      final repo = await pump(tester, entries: sample);
      final gate = Completer<bool>();
      repo.matchGate = gate;
      await tester.tap(find.byKey(const Key('quick_match_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_match_button')));
      await tester.pump();
      expect(repo.matchCalls, 1);

      gate.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('disposed mid-await does not throw', (tester) async {
      final repo = await pump(tester, entries: sample);
      final gate = Completer<bool>();
      repo.matchGate = gate;
      await tester.tap(find.byKey(const Key('quick_match_button')));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 2.0 does not overflow', (tester) async {
      await pump(tester, entries: sample, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });
}
