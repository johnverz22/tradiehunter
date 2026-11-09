import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/views/tradie/request_detail_screen.dart';
import 'package:fixo/views/tradie/tradie_job_detail_screen.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/widgets/fixo_buttons.dart';
import 'package:fixo/widgets/fixo_cards.dart';
import 'package:fixo/widgets/fixo_states.dart';
import 'package:fixo/views/widgets/custom_bottom_nav_bar.dart';
import 'package:fixo/views/widgets/modern_job_card.dart';
import 'package:fixo/views/widgets/job_info_grid.dart';
import 'package:fixo/views/widgets/job_status_presentation.dart';
import 'package:fixo/views/widgets/sticky_action_bar.dart';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/views/homeowner/homeowner_job_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fonts = [
    for (final family in ['SpaceGrotesk', 'IBMPlexSans'])
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        '$family-$weight.ttf',
  ];
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final asset = const StringCodec().decodeMessage(message);
          if (asset == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage({
              for (final font in fonts)
                font: [
                  {'asset': font},
                ],
            });
          }
          return ByteData(0);
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  for (final dark in [false, true]) {
    for (final status in [
      'Booked',
      'InProgress',
      'AwaitingConfirmation',
      'Completed',
      'Cancelled',
    ]) {
      testWidgets('tradie active detail shared layout: $status dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _ActiveJobsRepository(status);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [jobsRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              theme: dark ? FixoTheme.dark() : FixoTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const TradieJobDetailScreen(jobId: '42'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text(
            status == 'Cancelled'
                ? 'Test suburb'
                : '123 Long Street, Test suburb, Test city',
          ),
          150,
        );
        expect(
          find.text(
            status == 'Cancelled' ? 'Approximate Location' : 'Full Address',
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(find.byType(JobInfoGrid), 150);
        expect(find.byType(JobInfoGrid), findsOneWidget);
        await tester.scrollUntilVisible(find.text('2 hours'), 150);
        if (status == 'Completed') {
          expect(find.text('Agreed Price'), findsNothing);
          await tester.scrollUntilVisible(find.text('Not set'), -150);
        } else {
          await tester.scrollUntilVisible(find.text('\$171.25'), 150);
          expect(
            tester.widget<Text>(find.text('\$171.25')).style?.fontSize,
            DesignTokens.fontSizeAmount,
          );
        }
        expect(tester.takeException(), isNull);
        if (status == 'Booked' || status == 'InProgress') {
          final key = Key(
            status == 'Booked' ? 'check_in_button' : 'check_out_button',
          );
          expect(find.byType(StickyActionBar), findsOneWidget);
          expect(
            tester.getRect(find.byKey(key)).bottom,
            lessThanOrEqualTo(852),
          );
          await tester.tap(find.byKey(key));
          await tester.pumpAndSettle();
          expect(repo.calls, [status == 'Booked' ? 'check in' : 'check out']);
        } else if (status == 'Completed') {
          expect(
            find.byKey(const Key('rate_homeowner_button')),
            findsOneWidget,
          );
          expect(find.byType(StickyActionBar), findsOneWidget);
        } else {
          expect(find.byType(StickyActionBar), findsNothing);
          expect(repo.calls, isEmpty);
        }
        expect(tester.takeException(), isNull);
      });
    }
    for (final response in ['Accepted', 'Declined', 'Expired', 'Gone']) {
      testWidgets('request shared layout: $response dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _RequestJobsRepository(response);
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
              jobHubClientProvider.overrideWithValue(_RequestHub()),
            ],
            child: MaterialApp.router(
              theme: dark ? FixoTheme.dark() : FixoTheme.light(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Price + countdown sit above the detail sections
        expect(find.text('—'), findsOneWidget);
        if (response != 'Gone') {
          expect(
            response == 'Expired'
                ? find.text('Offer expired')
                : find.textContaining('Respond within'),
            findsOneWidget,
          );
        }
        expect(find.text('Plumbing and maintenance'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('No description provided.'),
          150,
        );
        expect(find.text('No description provided.'), findsOneWidget);
        expect(find.byType(StickyActionBar), findsOneWidget);
        if (response == 'Expired') {
          expect(find.text('This offer has expired.'), findsOneWidget);
          expect(find.byType(FixoPrimaryButton), findsNothing);
          expect(repo.responses, isEmpty);
        } else if (response == 'Gone') {
          // No pending offer — the truthful "unavailable" state replaces the
          // old legacy accept path, which could report a false success.
          expect(
            find.text('This offer is no longer available.'),
            findsOneWidget,
          );
          expect(find.byType(FixoPrimaryButton), findsNothing);
          expect(repo.responses, isEmpty);
        } else {
          final accept = response != 'Declined';
          final action = find.text(accept ? 'Accept Job' : 'Decline');
          expect(tester.getRect(action).bottom, lessThanOrEqualTo(852));
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(repo.responses, [response]);
          expect(find.text('Tradie dashboard'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    for (final status in [
      'Booked',
      'InProgress',
      'AwaitingConfirmation',
      'Completed',
      'Cancelled',
      'Expired',
      'Disputed',
      'FutureState',
    ]) {
      testWidgets('homeowner detail uses shared layout: $status dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final job = Job(
          id: '42',
          title: 'Repair kitchen tap',
          category: 'Plumbing',
          suburb: 'Test suburb',
          status: status,
          stage: status == 'InProgress' ? 3 : 2,
          hours: 2,
          matchedTradieId: 't-1',
          address: status == 'Completed'
              ? null
              : '123 Long Street, Test suburb, Test city',
          totalAmount: status == 'Completed' ? null : Decimal.parse('171.25'),
        );
        final router = GoRouter(
          initialLocation: '/jobs/42',
          routes: [
            GoRoute(
              path: '/jobs/:id',
              builder: (_, _) => const HomeownerJobDetailScreen(jobId: '42'),
            ),
            GoRoute(
              path: '/chat/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('Chat ${state.pathParameters['id']}')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              jobsRepositoryProvider.overrideWithValue(
                _DetailJobsRepository(job),
              ),
              reviewsRepositoryProvider.overrideWithValue(_DetailReviews()),
              localeConfigProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp.router(
              theme: dark ? FixoTheme.dark() : FixoTheme.light(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final progress = JobStatusPresentation.forStatus(status);
        expect(find.text(progress.label), findsWidgets);
        if (progress.progressLabel != null) {
          expect(find.text(progress.progressLabel!), findsOneWidget);
        } else {
          expect(find.textContaining('Step '), findsNothing);
          expect(find.text('Done'), findsNothing);
        }
        await tester.scrollUntilVisible(find.byType(JobInfoGrid), 200);
        expect(find.byType(JobInfoGrid), findsOneWidget);
        if (job.totalAmount != null) {
          await tester.scrollUntilVisible(find.text('\$171.25'), 200);
          expect(
            tester.widget<Text>(find.text('\$171.25')).style?.fontSize,
            DesignTokens.fontSizeAmount,
          );
          await tester.scrollUntilVisible(find.text(job.address!), 200);
        } else {
          await tester.scrollUntilVisible(find.text('Job Description'), 200);
          expect(find.text('Total Price'), findsNothing);
          expect(find.text('Address'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        if (['Cancelled', 'Expired', 'FutureState'].contains(status)) {
          expect(find.byType(StickyActionBar), findsNothing);
          expect(find.byKey(const Key('open_chat_button')), findsNothing);
        } else if (status == 'Disputed') {
          expect(find.byType(StickyActionBar), findsOneWidget);
          expect(find.byKey(const Key('view_dispute_button')), findsOneWidget);
          expect(find.byKey(const Key('open_chat_button')), findsNothing);
        } else if (status == 'AwaitingConfirmation' || status == 'Completed') {
          expect(find.byType(StickyActionBar), findsOneWidget);
          final action = find.byKey(
            Key(
              status == 'Completed'
                  ? 'leave_review_button'
                  : 'confirm_completion_button',
            ),
          );
          expect(action, findsOneWidget);
          expect(tester.getRect(action).bottom, lessThanOrEqualTo(852));
          expect(find.byKey(const Key('open_chat_button')), findsNothing);
        } else {
          expect(find.byType(StickyActionBar), findsOneWidget);
          await tester.tap(find.byKey(const Key('open_chat_button')));
          await tester.pumpAndSettle();
          expect(find.text('Chat 42'), findsOneWidget);
        }
      });
    }
    testWidgets('shared states work inside a parent list in dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          home: Scaffold(
            body: ListView(
              children: const [
                FixoLoading(label: 'Loading jobs'),
                FixoEmptyState(icon: Icons.work_outline, title: 'No jobs yet'),
                FixoErrorState(message: 'Connection unavailable'),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Loading jobs'), findsOneWidget);
      expect(find.text('No jobs yet'), findsOneWidget);
      expect(find.text('Connection unavailable'), findsOneWidget);
      expect(find.byType(FixoPrimaryButton), findsNothing);
      expect(find.byType(FixoGhostButton), findsNothing);
    });
    for (final state in ['empty', 'error', 'loading']) {
      testWidgets('$state state scrolls at large text in dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 240);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        final message = List.filled(
          8,
          'Please check your connection and try again.',
        ).join(' ');
        final child = switch (state) {
          'empty' => FixoEmptyState(
            icon: Icons.work_outline,
            title: 'No jobs available',
            subtitle: message,
            actionLabel: 'Post a job',
            onAction: () => calls++,
          ),
          'error' => FixoErrorState(message: message, onRetry: () => calls++),
          _ => FixoLoading(label: message),
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? FixoTheme.dark() : FixoTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(body: child),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        if (state != 'loading') {
          final button = find.text(
            state == 'empty' ? 'Post a job' : 'Try again',
          );
          await tester.ensureVisible(button);
          await tester.pump();
          await tester.tap(button);
          expect(calls, 1);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  test('semantic dimensions preserve the v1.5 contract and legacy radius', () {
    expect(DesignTokens.hue, 209);
    expect(DesignTokens.radius, 4);
    expect(DesignTokens.radiusCard, 20);
    expect(DesignTokens.radiusControl, 14);
    expect(DesignTokens.radiusInput, 14);
    expect(DesignTokens.radiusTile, 16);
    expect(DesignTokens.radiusSheet, 28);
    expect(DesignTokens.targetMinimum, 48);
    expect(DesignTokens.heightPrimary, 56);
    expect(DesignTokens.heightSecondary, 52);
    expect(DesignTokens.heightInput, 56);
  });

  for (final isDark in [false, true]) {
    final label = isDark ? 'dark' : 'light';
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('$label controls at 320px and $scale text scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = isDark ? FixoTheme.dark() : FixoTheme.light();
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(DesignTokens.pageMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () => taps++,
                        child: const Text('Continue'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Go back'),
                      ),
                      const TextField(
                        decoration: InputDecoration(labelText: 'Address'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(DesignTokens.heightPrimary),
        );
        expect(
          tester.getSize(find.byType(OutlinedButton)).height,
          greaterThanOrEqualTo(DesignTokens.heightSecondary),
        );
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }

    for (final showFab in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$label shared components scale $scale homeowner $showFab',
          (tester) async {
            tester.view.physicalSize = const Size(320, 1400);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final theme = isDark ? FixoTheme.dark() : FixoTheme.light();
            await tester.runAsync(() => GoogleFonts.pendingFonts());
            var primary = 0;
            var decline = 0;
            var selected = -1;
            var posts = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 1400),
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(bottom: 24),
                  ),
                  child: Scaffold(
                    appBar: const FixoGradientAppBar(
                      title: 'My jobs',
                      subtitle: 'Your current work',
                      showBack: false,
                    ),
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          FixoPrimaryButton(
                            label: 'Continue with this job',
                            onPressed: () => primary++,
                          ),
                          FixoGhostButton(
                            label: 'Decline',
                            onPressed: () => decline++,
                          ),
                          const FixoCard(child: Text('Job details')),
                          ModernJobCard(
                            title: 'Repair the leaking kitchen tap and inspect the pipes',
                            category: 'Plumbing',
                            suburb: 'A long suburb name in Auckland',
                            priceLabel: '\$171.00',
                            identityLabel: 'Alex Smith',
                            status: 'Awaiting payment',
                            actionLabel: 'View job',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    bottomNavigationBar: CustomBottomNavBar(
                      currentIndex: 0,
                      tabs: showFab
                          ? CustomBottomNavBar.homeownerTabs
                          : CustomBottomNavBar.tradieTabs,
                      showFab: showFab,
                      onDestinationSelected: (i) => selected = i,
                      onPostJob: () => posts++,
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            expect(
              tester.getSize(find.byType(FilledButton)).height,
              greaterThanOrEqualTo(56),
            );
            expect(
              tester.getSize(find.byType(OutlinedButton)).height,
              greaterThanOrEqualTo(52),
            );
            await tester.tap(find.text('Continue with this job'));
            await tester.tap(find.text('Decline'));
            await tester.tap(find.text('Messages'));
            expect(primary, 1);
            expect(decline, 1);
            expect(selected, 2);
            expect(find.text('3'), findsNothing);
            if (showFab) {
              await tester.tap(find.byKey(const Key('post_job_fab')));
              expect(posts, 1);
            } else {
              expect(find.byKey(const Key('post_job_fab')), findsNothing);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final width in [320.0, 430.0]) {
      testWidgets('$label info grid and sticky action at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = isDark ? FixoTheme.dark() : FixoTheme.light();
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 932),
                textScaler: TextScaler.linear(width == 320 ? 2 : 1),
                viewInsets: const EdgeInsets.only(bottom: 250),
                padding: const EdgeInsets.only(bottom: 24),
              ),
              child: Scaffold(
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: JobInfoGrid(
                    tiles: [
                      JobInfoTile(
                        icon: Icons.schedule,
                        label: 'Scheduled',
                        value: 'Tomorrow at 10:30 am',
                      ),
                      JobInfoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: 'A long street address in Auckland',
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: StickyActionBar(
                  child: FixoPrimaryButton(label: 'Continue', onPressed: () {}),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getBottomLeft(find.byType(FilledButton)).dy,
          lessThanOrEqualTo(932 - 250),
        );
        final tiles = find.byType(JobInfoTile);
        expect(
          tester.getSize(tiles.at(0)).width,
          tester.getSize(tiles.at(1)).width,
        );
        if (width == 430) {
          expect(
            tester.getSize(tiles.at(0)).height,
            tester.getSize(tiles.at(1)).height,
          );
        }
      });
    }

    test('$label semantic foregrounds meet AA contrast', () {
      final paper = isDark ? DesignTokens.paperDark : DesignTokens.paperLight;
      final pairs = [
        (DesignTokens.foreground(isDark), paper),
        (DesignTokens.inkSoft(isDark), paper),
        (DesignTokens.foreground(isDark), DesignTokens.surfaceCard(isDark)),
        (DesignTokens.inkSoft(isDark), DesignTokens.surfaceCard(isDark)),
        (DesignTokens.foregroundBrand(isDark), paper),
        (
          DesignTokens.foregroundStatus(isDark),
          DesignTokens.surfaceStatus(isDark),
        ),
        (DesignTokens.onAmber, DesignTokens.amber),
      ];
      for (final (foreground, background) in pairs) {
        final a = foreground.computeLuminance();
        final b = background.computeLuminance();
        final ratio = a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }
    });

    test('$label theme applies semantic type and geometry', () async {
      final theme = isDark ? FixoTheme.dark() : FixoTheme.light();
      await GoogleFonts.pendingFonts();
      expect(theme.textTheme.headlineLarge?.fontSize, DesignTokens.fontSizeH1);
      expect(theme.textTheme.titleLarge?.fontSize, DesignTokens.fontSizeH2);
      expect(theme.textTheme.titleMedium?.fontSize, DesignTokens.fontSizeH3);
      expect(theme.textTheme.bodyLarge?.fontSize, DesignTokens.fontSizeBody);
      expect(theme.textTheme.bodyMedium?.fontSize, DesignTokens.fontSizeBody);
      expect(
        theme.textTheme.bodySmall?.fontSize,
        DesignTokens.fontSizeSecondary,
      );
      expect(
        theme.textTheme.labelSmall?.fontSize,
        DesignTokens.fontSizeCaption,
      );
      expect(theme.textTheme.bodySmall?.fontFamily, contains('IBMPlexSans'));
      final primary = theme.filledButtonTheme.style!;
      expect(
        primary.minimumSize?.resolve({})?.height,
        DesignTokens.heightPrimary,
      );
      expect(primary.foregroundColor?.resolve({}), DesignTokens.onAmber);
      expect(
        primary.backgroundColor?.resolve({WidgetState.disabled}),
        DesignTokens.surfaceDisabled(isDark),
      );
      expect(
        theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.height,
        DesignTokens.heightSecondary,
      );
      expect(
        (theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
            .borderRadius,
        BorderRadius.circular(DesignTokens.radiusInput),
      );
      expect(
        theme.inputDecorationTheme.constraints?.minHeight,
        DesignTokens.heightInput,
      );
      expect(
        (theme.bottomSheetTheme.shape! as RoundedRectangleBorder).borderRadius,
        const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
      );
    });
  }
}

class _RequestHub implements JobHubClient {
  @override
  Stream<OfferLifecycleEvent> get onOfferLifecycle => const Stream.empty();

  @override
  Stream<JobStatusEvent> get onJobStatusChanged => const Stream.empty();

  @override
  Stream<void> get onReconnected => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RequestJobsRepository implements JobsRepository {
  _RequestJobsRepository(this.mode);

  final String mode;
  final responses = <String>[];

  @override
  Future<Job?> getJobById(String id) async => const Job(
    id: '42',
    title: 'Repair kitchen tap',
    category: 'Plumbing and maintenance',
    suburb: 'Test suburb',
    status: 'Requested',
    stage: 0,
  );

  @override
  Future<JobOffer?> getPendingOffer(String id) async => mode == 'Gone'
      ? null
      : JobOffer(
          id: 'offer-1',
          jobId: '42',
          tradieId: 'tradie-1',
          offeredAtUtc: DateTime.now().toUtc(),
          expiresAtUtc: DateTime.now().toUtc().add(
            Duration(minutes: mode == 'Expired' ? -5 : 5),
          ),
          response: 'Pending',
          stage: 'Auto',
        );

  @override
  Future<bool> respondToOffer(
    String jobId,
    String offerId, {
    required String response,
  }) async {
    expect(jobId, '42');
    expect(offerId, 'offer-1');
    responses.add(response);
    return true;
  }

  @override
  Future<void> acceptJob(String id) async {
    expect(id, '42');
    responses.add('legacy accept');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ActiveJobsRepository implements JobsRepository {
  _ActiveJobsRepository(this.status);

  String status;
  final calls = <String>[];

  @override
  Future<Job?> getJobById(String id) async {
    expect(id, '42');
    return Job(
      id: '42',
      title: 'Repair kitchen tap',
      category: 'Plumbing',
      suburb: 'Test suburb',
      status: status,
      stage: 2,
      hours: 2,
      urgency: 'Emergency',
      homeownerId: 'homeowner-1',
      address: '123 Long Street, Test suburb, Test city',
      scheduledStartUtc: status == 'Completed'
          ? null
          : DateTime.utc(2030, 1, 15, 10),
      totalAmount: status == 'Completed' ? null : Decimal.parse('171.25'),
    );
  }

  @override
  Future<bool> checkIn(String id) async {
    expect(id, '42');
    calls.add('check in');
    status = 'InProgress';
    return true;
  }

  @override
  Future<bool> checkOut(String id) async {
    expect(id, '42');
    calls.add('check out');
    status = 'AwaitingConfirmation';
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DetailJobsRepository implements JobsRepository {
  _DetailJobsRepository(this.job);

  final Job job;

  @override
  Future<Job?> getJobById(String id) async => job;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DetailReviews extends ReviewsRepository {
  _DetailReviews() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<UserProfile?> getProfile(String userId) async => null;
}
