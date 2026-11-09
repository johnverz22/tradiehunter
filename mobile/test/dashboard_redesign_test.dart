import 'package:decimal/decimal.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
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
          expect(find.text('GOOD EVENING'), findsOneWidget);
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

  test('caption token meets minimum typography size', () {
    expect(DesignTokens.fontSizeCaption, greaterThanOrEqualTo(12));
  });
}
