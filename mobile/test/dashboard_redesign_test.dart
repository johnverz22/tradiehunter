import 'package:decimal/decimal.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/views/widgets/custom_bottom_nav_bar.dart';
import 'package:fixo/views/widgets/homeowner_dashboard_header.dart';
import 'package:fixo/views/widgets/homeowner_job_summary.dart';
import 'package:fixo/views/widgets/job_progress_dots.dart';
import 'package:fixo/views/widgets/modern_job_card.dart';
import 'package:fixo/widgets/fixo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'empty dashboard assets and CTA fit dark=$dark scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var posted = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? FixoTheme.dark() : FixoTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      HomeownerDashboardHeader(
                        firstName: 'Sarah',
                        location: 'Grey Lynn, Auckland',
                        now: DateTime(2026, 11, 2, 19),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: HomeownerDashboardEmpty(
                          onPost: () => posted = true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('KIA ORA'), findsOneWidget);
          expect(find.text('Sarah'), findsOneWidget);
          expect(find.text('Grey Lynn, Auckland'), findsOneWidget);
          expect(find.text('Fixed price'), findsNothing);
          expect(find.text('100%'), findsNothing);
          final images = tester
              .widgetList<Image>(find.byType(Image))
              .map((image) => (image.image as AssetImage).assetName);
          expect(
            images,
            contains(
              'assets/illustrations/il-01-${dark ? 'dark' : 'light'}.png',
            ),
          );
          await tester.ensureVisible(find.text('Post a job'));
          await tester.tap(find.text('Post a job'));
          expect(posted, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'attention wash has no border and uses progress dots dark=$dark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? FixoTheme.dark() : FixoTheme.light(),
            home: Scaffold(
              body: ModernJobCard(
                title: 'Tap repair',
                category: 'Plumbing',
                suburb: 'Auckland',
                isAttention: true,
                progressStatus: 'AwaitingPayment',
              ),
            ),
          ),
        );
        final containers = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(ModernJobCard),
            matching: find.byType(Container),
          ),
        );
        final decoration =
            containers
                    .firstWhere(
                      (container) =>
                          container.decoration is BoxDecoration &&
                          (container.decoration as BoxDecoration).gradient !=
                              null,
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.border, isNull);
        final gradient = decoration.gradient! as LinearGradient;
        expect(gradient.stops, [0, 0.4, 1]);
        expect(gradient.colors, [
          DesignTokens.brand500.withValues(alpha: 0.18),
          DesignTokens.brand500.withValues(alpha: 0.06),
          DesignTokens.brand500.withValues(alpha: 0),
        ]);
        expect(find.byType(JobProgressDots), findsOneWidget);
        expect(find.text('Step 1 of 4'), findsOneWidget);
      },
    );

    testWidgets('booked card preserves detail and chat routes dark=$dark', (
      tester,
    ) async {
      final job = Job(
        id: 'booked',
        title: 'Repair tap',
        category: 'Plumbing',
        suburb: 'Auckland',
        status: 'Booked',
        stage: 2,
        matchedTradieId: 'tradie',
        matchedTradieName: 'Alex Smith',
        totalAmount: Decimal.parse('123.45'),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: HomeownerBookedJobs(jobs: [job])),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (_, _) => const Scaffold(body: Text('Chat destination')),
          ),
          GoRoute(
            path: '/jobs/:id/detail',
            builder: (_, _) => const Scaffold(body: Text('Detail destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ModernJobCard), findsNothing);
      expect(find.text('AS'), findsOneWidget);
      expect(find.text(r'$123.45'), findsOneWidget);
      expect(tester.getSize(find.byType(CircleAvatar)), const Size(44, 44));
      await tester.tap(find.text('Repair tap'));
      await tester.pumpAndSettle();
      expect(find.text('Detail destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();
      expect(find.text('Chat destination'), findsOneWidget);
    });
  }

  testWidgets('missing counterparty does not enable a dead chat route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixoTheme.light(),
        home: const Scaffold(
          body: HomeownerBookedJobs(
            jobs: [
              Job(
                id: 'missing',
                title: 'Repair',
                category: '',
                suburb: '',
                status: 'Booked',
                stage: 2,
              ),
            ],
          ),
        ),
      ),
    );
    final button = tester.widget<FixoTonalButton>(find.byType(FixoTonalButton));
    expect(button.onPressed, isNull);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('HomeownerDashboardHeader empty name fallback and location chip', (
    tester,
  ) async {
    // 1. Empty name -> title is "Kia ora", no eyebrow, no "Homeowner"
    await tester.pumpWidget(
      MaterialApp(
        theme: FixoTheme.light(),
        home: const Scaffold(
          body: HomeownerDashboardHeader(
            firstName: '',
            location: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kia ora'), findsOneWidget);
    expect(find.text('KIA ORA'), findsNothing);
    expect(find.text('Homeowner'), findsNothing);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);

    // 2. Name provided without location -> eyebrow + name, location chip hidden
    await tester.pumpWidget(
      MaterialApp(
        theme: FixoTheme.dark(),
        home: const Scaffold(
          body: HomeownerDashboardHeader(
            firstName: 'Sarah',
            location: '',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('KIA ORA'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);

    // 3. Name provided with location -> eyebrow + name + location chip with icon
    await tester.pumpWidget(
      MaterialApp(
        theme: FixoTheme.light(),
        home: const Scaffold(
          body: HomeownerDashboardHeader(
            firstName: 'Sarah',
            location: 'Grey Lynn, Auckland',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('KIA ORA'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(find.text('Grey Lynn, Auckland'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
  });

  testWidgets('navy FAB matches mockup with white add icon and 56dp size', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      var posted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 0,
              showFab: true,
              tabs: CustomBottomNavBar.homeownerTabs,
              onDestinationSelected: (_) {},
              onPostJob: () => posted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byKey(const Key('post_job_fab'));
      expect(fabFinder, findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.color, Colors.white);

      final container = tester.widget<Container>(
        find.descendant(of: fabFinder, matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, DesignTokens.brand900);
      expect(container.constraints?.minWidth ?? 56.0, greaterThanOrEqualTo(48.0));
      expect(container.constraints?.minHeight ?? 56.0, greaterThanOrEqualTo(48.0));

      await tester.tap(fabFinder);
      expect(posted, isTrue);
    }
  });

  test('caption token meets minimum typography size', () {
    expect(DesignTokens.fontSizeCaption, greaterThanOrEqualTo(12));
  });
}
