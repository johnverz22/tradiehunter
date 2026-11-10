// Dashboard redesign widget tests — v1.7 spec verification.
//
// Covers:
// 1. Equal tile sizes at 1.0x and 1.3x text scale.
// 2. Availability pill button states: online, offline, loading, error/snackbar.
// 3. StatusChip tone mapping for every status (light + dark).
// 4. Today card shows CTA only for action-required statuses.
// 5. Today cards sorted: action-required first, then by schedule time.
// 6. Today empty state adapts to online/offline.
// 7. Progress bar caption shows "Step X of 4" without status suffix.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/tradie/tradie_dashboard_view.dart';
import 'package:fixo/views/widgets/job_status_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

class _JobsFixture extends JobsRepository {
  final List<Job> jobs;
  _JobsFixture(this.jobs) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<Job>> getTradieJobs() async => jobs;

  @override
  Future<JobOffer?> getPendingOffer(String jobId) async => null;
}

class _ProfileFixture extends ProfileRepository {
  final bool isAvailable;
  final bool throwOnToggle;
  bool toggleCalled = false;

  _ProfileFixture({
    this.isAvailable = true,
    this.throwOnToggle = false,
    Map<String, dynamic> extra = const {},
  }) : _extra = extra,
       super(Dio(), const FlutterSecureStorage());

  final Map<String, dynamic> _extra;

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
        'id': 'tradie-1',
        'firstName': 'Jay',
        'role': 1,
        'isVerified': true,
        'isAvailable': isAvailable,
        ..._extra,
      };

  @override
  Future<TradieEarnings> getEarnings() async => TradieEarnings(
        periodStartUtc: DateTime.utc(2026, 7, 5),
        periodEndUtc: DateTime.utc(2026, 7, 12),
        asOfUtc: DateTime.utc(2026, 7, 8),
        timeZone: 'Pacific/Auckland',
        earnedNet: Decimal.parse('1196.96'),
        pendingNet: Decimal.parse('2693.16'),
      );

  @override
  Future<void> updateAvailability(bool value) async {
    toggleCalled = true;
    if (throwOnToggle) throw Exception('Network error');
  }
}

class _HubFixture extends JobHubClient {
  _HubFixture() : super(const FlutterSecureStorage());
  @override
  Stream<JobStatusEvent> get onJobStatusChanged => const Stream.empty();
  @override
  Stream<OfferLifecycleEvent> get onOfferLifecycle => const Stream.empty();
  @override
  Future<void> connect({required String baseUrl}) async {}
}

Job _job(
  String status, {
  DateTime? scheduled,
  Decimal? total,
  String title = '',
  String category = 'Plumbing',
  String suburb = 'Ponsonby',
}) =>
    Job(
      id: status,
      title: title.isEmpty ? 'Job $status' : title,
      category: category,
      suburb: suburb,
      status: status,
      stage: 0,
      totalAmount: total,
      scheduledStartUtc: scheduled,
      hours: 2,
    );

/// Mounts the dashboard with the given fixtures and text scale.
Future<void> mountDashboard(
  WidgetTester tester,
  _JobsFixture jobs,
  _ProfileFixture profile, {
  bool dark = false,
  double scale = 1.0,
  double width = 375,
  double height = 1600,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final hub = _HubFixture();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const TradieDashboardView()),
      for (final path in [
        '/tradie/requests/:id',
        '/tradie/jobs/:id',
        '/tradie/onboarding',
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
        jobsRepositoryProvider.overrideWithValue(jobs),
        profileRepositoryProvider.overrideWithValue(profile),
        jobHubClientProvider.overrideWithValue(hub),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dark ? FixoTheme.dark() : FixoTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  // Pump a fixed duration to let async loads and animations settle.
  // We do NOT call pumpAndSettle here — the online dot's repeating pulse
  // animation never fully settles and causes pumpAndSettle to time out.
  await tester.pump(); // first frame
  await tester.pump(const Duration(milliseconds: 100)); // let microtasks run
  await tester.pump(const Duration(milliseconds: 500)); // async loads
  await tester.pump(const Duration(milliseconds: 500)); // any remaining frames
}

/// Pump enough frames for async operations (futures, setState, navigation)
/// to complete without running [pumpAndSettle] — which times out on screens
/// that have repeating animations (the online-dot pulse).
Future<void> pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── 1. Equal tile sizes ────────────────────────────────────────────────────

  group('stat tiles equal size', () {
    for (final scale in [1.0, 1.3]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Pending and Rating tiles have same height — scale=$scale dark=$dark',
          (tester) async {
            await mountDashboard(
              tester,
              _JobsFixture([]),
              _ProfileFixture(
                extra: {'reviewCount': 3, 'averageRating': 4.8},
              ),
              dark: dark,
              scale: scale,
            );

            // Locate tiles by their semantic keys added to _HeroStatTile.
            final pendingSize =
                tester.getSize(find.byKey(const Key('stat_tile_pending')));
            final ratingSize =
                tester.getSize(find.byKey(const Key('stat_tile_rating')));

            expect(
              pendingSize.height,
              closeTo(ratingSize.height, 1.0),
              reason:
                  'Pending height ${pendingSize.height} ≈ Rating height ${ratingSize.height}',
            );
            expect(
              pendingSize.width,
              closeTo(ratingSize.width, 1.0),
              reason: 'tiles have equal width',
            );
          },
        );
      }
    }

    testWidgets(
      'tiles match at 0-reviews (caption reserved space)',
      (tester) async {
        await mountDashboard(
          tester,
          _JobsFixture([]),
          _ProfileFixture(extra: {'reviewCount': 0, 'averageRating': 0}),
        );
        expect(find.text('No reviews yet'), findsOneWidget);
        expect(find.text('0.0'), findsNothing);

        final pH = tester
            .getSize(find.byKey(const Key('stat_tile_pending')))
            .height;
        final rH = tester
            .getSize(find.byKey(const Key('stat_tile_rating')))
            .height;
        expect(pH, closeTo(rH, 1.0),
            reason: 'heights match even with no-review state');
      },
    );
  });

  // ── 2. Availability pill button states ────────────────────────────────────

  group('availability pill button', () {
    testWidgets('shows Online when isAvailable=true', (tester) async {
      await mountDashboard(
        tester,
        _JobsFixture([]),
        _ProfileFixture(isAvailable: true),
      );
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('shows Offline when isAvailable=false', (tester) async {
      await mountDashboard(
        tester,
        _JobsFixture([]),
        _ProfileFixture(isAvailable: false),
      );
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('has availability_button key', (tester) async {
      await mountDashboard(
        tester,
        _JobsFixture([]),
        _ProfileFixture(isAvailable: true),
      );
      expect(find.byKey(const Key('availability_button')), findsOneWidget);
    });

    testWidgets('tapping Online calls updateAvailability', (tester) async {
      final profile = _ProfileFixture(isAvailable: true);
      await mountDashboard(tester, _JobsFixture([]), profile);
      await tester.tap(find.byKey(const Key('availability_button')));
      await pumpAsync(tester);
      expect(profile.toggleCalled, isTrue);
    });

    testWidgets('tapping Offline calls updateAvailability', (tester) async {
      final profile = _ProfileFixture(isAvailable: false);
      await mountDashboard(tester, _JobsFixture([]), profile);
      await tester.tap(find.byKey(const Key('availability_button')));
      await pumpAsync(tester);
      expect(profile.toggleCalled, isTrue);
    });

    testWidgets('error shows snackbar with Retry', (tester) async {
      final profile =
          _ProfileFixture(isAvailable: false, throwOnToggle: true);
      await mountDashboard(tester, _JobsFixture([]), profile);
      await tester.tap(find.byKey(const Key('availability_button')));
      await pumpAsync(tester);
      expect(find.text('Could not update availability. Try again.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'going offline with active jobs shows confirm sheet',
      (tester) async {
        final now = DateTime.now();
        final profile = _ProfileFixture(isAvailable: true);
        await mountDashboard(
          tester,
          _JobsFixture([
            _job(
              'InProgress',
              scheduled: DateTime.utc(now.year, now.month, now.day, 9),
            ),
          ]),
          profile,
        );
        await tester.tap(find.byKey(const Key('availability_button')));
        await pumpAsync(tester);
        // Confirm sheet should appear.
        expect(find.text('Go offline?'), findsOneWidget);
        // Tapping Cancel should dismiss without toggling.
        await tester.tap(find.text('Cancel'));
        await pumpAsync(tester);
        expect(profile.toggleCalled, isFalse);
      },
    );
  });

  // ── 3. StatusChip tone mapping ────────────────────────────────────────────

  group('StatusChip chip tone', () {
    const toneMap = {
      'Requested':            ChipTone.neutral,
      'AwaitingPayment':      ChipTone.warning,
      'PaymentReview':        ChipTone.neutral,
      'Booked':               ChipTone.info,
      'InProgress':           ChipTone.brand,
      'AwaitingConfirmation': ChipTone.warning,
      'Completed':            ChipTone.success,
      'Cancelled':            ChipTone.neutral,
      'Expired':              ChipTone.neutral,
      'Disputed':             ChipTone.danger,
    };

    for (final entry in toneMap.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(
          JobStatusPresentation.forStatus(entry.key).chipTone,
          entry.value,
        );
      });
    }

    for (final dark in [false, true]) {
      testWidgets(
        'StatusChip renders all statuses without overflow — dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(375, 100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          for (final status in toneMap.keys) {
            final p = JobStatusPresentation.forStatus(status);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? FixoTheme.dark() : FixoTheme.light(),
                home: Scaffold(
                  body: Center(
                    child: StatusChip(
                      label: p.label,
                      tone: p.chipTone,
                      icon: p.chipIcon,
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull,
                reason: '$status dark=$dark no exception');
            expect(find.text(p.label), findsOneWidget,
                reason: '$status label visible');
          }
        },
      );
    }

    testWidgets('chip background is tinted — not solid amber', (tester) async {
      for (final status in toneMap.keys) {
        final p = JobStatusPresentation.forStatus(status);
        await tester.pumpWidget(
          MaterialApp(
            theme: FixoTheme.light(),
            home: Scaffold(
              body: Center(
                child: StatusChip(
                    label: p.label, tone: p.chipTone, icon: p.chipIcon),
              ),
            ),
          ),
        );
        final chipContainers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(StatusChip),
                matching: find.byType(Container),
              ),
            )
            .where((c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).color != null)
            .toList();
        expect(chipContainers, isNotEmpty,
            reason: '$status chip has a decoration container');
        final bg = (chipContainers.first.decoration! as BoxDecoration).color!;
        expect(bg.a, lessThan(1.0),
            reason: '$status chip bg is tinted (alpha < 1)');
        expect(bg, isNot(DesignTokens.amber),
            reason: '$status chip bg is not solid amber');
      }
    });

    testWidgets('StatusChip.forStatus convenience ctor renders correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FixoTheme.light(),
          home: Scaffold(
            body: Center(child: StatusChip.forStatus('InProgress')),
          ),
        ),
      );
      expect(find.text('In progress'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Status: In progress'),
        findsOneWidget,
      );
    });
  });

  // ── 4. Today card CTA logic ───────────────────────────────────────────────

  group('Today card CTA', () {
    // All statuses in _bookedWorkStatuses (which appear in Today) have
    // tradieActionRequired=true, so every Today card shows an amber CTA.
    // The CTA label varies per status.
    const ctaByStatus = {
      'Booked':              'Check in',
      'InProgress':          'Check out',
      'AwaitingConfirmation': 'Mark complete',
    };

    for (final entry in ctaByStatus.entries) {
      testWidgets(
        '${entry.key} card shows CTA with label "${entry.value}"',
        (tester) async {
          final now = DateTime.now();
          await mountDashboard(
            tester,
            _JobsFixture([
              _job(
                entry.key,
                scheduled: DateTime.utc(now.year, now.month, now.day, 9),
                total: Decimal.parse('450.00'),
              ),
            ]),
            _ProfileFixture(),
          );
          expect(find.byKey(const Key('today_card_cta')), findsOneWidget,
              reason: '${entry.key} should show CTA');
          expect(find.text(entry.value), findsOneWidget,
              reason: '${entry.key} CTA label is "${entry.value}"');
        },
      );
    }

    testWidgets(
      'CTA button tap navigates to job detail',
      (tester) async {
        final now = DateTime.now();
        await mountDashboard(
          tester,
          _JobsFixture([
            _job(
              'InProgress',
              scheduled: DateTime.utc(now.year, now.month, now.day, 9),
            ),
          ]),
          _ProfileFixture(),
        );
        await tester.tap(find.byKey(const Key('today_card_cta')));
        await pumpAsync(tester);
        expect(
          find.text('Destination /tradie/jobs/InProgress'),
          findsOneWidget,
        );
      },
    );
  });

  // ── 5. Sort order ─────────────────────────────────────────────────────────

  testWidgets('Today cards sorted by schedule time when same action tier',
      (tester) async {
    final now = DateTime.now();
    // Both are action-required, so sort is purely by schedule time.
    // InProgress at 8am should appear above Booked at 10am.
    await mountDashboard(
      tester,
      _JobsFixture([
        _job('Booked',
            title: 'B Booked',
            scheduled: DateTime.utc(now.year, now.month, now.day, 10)),
        _job('InProgress',
            title: 'A InProgress',
            scheduled: DateTime.utc(now.year, now.month, now.day, 8)),
      ]),
      _ProfileFixture(),
    );

    final inProgressPos =
        tester.getTopLeft(find.text('A InProgress')).dy;
    final bookedPos =
        tester.getTopLeft(find.text('B Booked')).dy;
    expect(inProgressPos, lessThan(bookedPos),
        reason: 'InProgress at 8am renders above Booked at 10am');
  });

  // ── 6. Today empty state ──────────────────────────────────────────────────

  group('Today empty state', () {
    testWidgets("online shows \"You're online\" message", (tester) async {
      await mountDashboard(
        tester,
        _JobsFixture([]),
        _ProfileFixture(isAvailable: true),
      );
      expect(find.text("You're online"), findsOneWidget);
      expect(find.text('Go online'), findsNothing);
    });

    testWidgets('offline shows "Go online" button', (tester) async {
      await mountDashboard(
        tester,
        _JobsFixture([]),
        _ProfileFixture(isAvailable: false),
      );
      // The offline empty-state card shows this text. The leads section may
      // also show a similar message, so use findsAtLeastNWidgets.
      expect(
        find.textContaining('Online tradies get offers first'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Go online'), findsOneWidget);
    });

    testWidgets('Go online button in empty state toggles availability',
        (tester) async {
      final profile = _ProfileFixture(isAvailable: false);
      await mountDashboard(tester, _JobsFixture([]), profile);
      await tester.scrollUntilVisible(find.text('Go online'), 200);
      await tester.tap(find.text('Go online'));
      await pumpAsync(tester);
      expect(profile.toggleCalled, isTrue);
    });
  });

  // ── 7. Progress bar caption has no status suffix ──────────────────────────

  testWidgets(
    'Today card progress bar caption is "Step X of 4" without status suffix',
    (tester) async {
      final now = DateTime.now();
      await mountDashboard(
        tester,
        _JobsFixture([
          _job(
            'InProgress',
            scheduled: DateTime.utc(now.year, now.month, now.day, 9),
          ),
        ]),
        _ProfileFixture(),
      );
      // "Step 3 of 4" (InProgress = stage 2, so step 3) must be present.
      expect(find.text('Step 3 of 4'), findsOneWidget);
      // The old "In progress" suffix must NOT appear in the caption.
      // Note: the StatusChip still shows "In progress" — we check only that
      // the progress bar caption alone doesn't repeat it.
      final progressBarCaptionFinder = find.textContaining('Step 3 of 4 ·');
      expect(progressBarCaptionFinder, findsNothing,
          reason: 'progress bar caption must not have a status suffix');
    },
  );

  // ── 8. No Online tile in stats row ────────────────────────────────────────

  testWidgets('hero stats row has exactly two tiles (Pending and Rating)',
      (tester) async {
    await mountDashboard(
      tester,
      _JobsFixture([]),
      _ProfileFixture(
        extra: {'reviewCount': 5, 'averageRating': 4.9},
      ),
    );
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    // The old Online tile label must not appear inside the stats row.
    // (The word 'Online' may still appear in the pill button, but the tile
    // heading 'Online' as a separate stat label should be gone.)
    final onlineTileLabels = tester
        .widgetList<Text>(find.text('Online'))
        .where((t) =>
            t.style?.fontSize == DesignTokens.fontSizeTiny &&
            t.style?.letterSpacing == Tracking.wide)
        .toList();
    expect(onlineTileLabels, isEmpty,
        reason: 'no Online stat tile label in hero');
  });

  // ── 9. Overflow safety at 1.3x text scale ────────────────────────────────

  for (final dark in [false, true]) {
    testWidgets(
      'dashboard fits 320px at 1.3x text scale — dark=$dark',
      (tester) async {
        final now = DateTime.now();
        await mountDashboard(
          tester,
          _JobsFixture([
            _job(
              'InProgress',
              title: 'Repair all the kitchen plumbing fixtures and fittings',
              scheduled: DateTime.utc(now.year, now.month, now.day, 9),
              total: Decimal.parse('12345.00'),
            ),
            _job(
              'Booked',
              title: 'Short title',
              scheduled: DateTime.utc(now.year, now.month, now.day, 14),
              total: Decimal.parse('99.00'),
            ),
          ]),
          _ProfileFixture(
            extra: {'reviewCount': 0, 'averageRating': 0},
          ),
          dark: dark,
          scale: 1.3,
          width: 320,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
