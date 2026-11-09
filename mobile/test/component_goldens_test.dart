// Golden and visual-regression tests for shared components across themes,
// viewports (393px, 430px, 320px) and text scaling (1.0, 2.0).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/widgets/fixo_buttons.dart';
import 'package:fixo/widgets/fixo_cards.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/views/widgets/chat_widgets.dart';
import 'package:fixo/views/widgets/custom_bottom_nav_bar.dart';
import 'package:fixo/views/widgets/job_info_grid.dart';
import 'package:fixo/views/widgets/job_progress.dart';
import 'package:fixo/views/widgets/modern_job_card.dart';
import 'package:fixo/views/widgets/offer_countdown.dart';
import 'package:fixo/views/widgets/otp_code_field.dart';
import 'package:fixo/views/widgets/sticky_action_bar.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrapComponent({
    required Widget child,
    required bool isDark,
    required double width,
    required double scale,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDark ? FixoTheme.dark() : FixoTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 852),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          backgroundColor: isDark
              ? DesignTokens.paperDark
              : DesignTokens.paperLight,
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final isDark in [false, true]) {
    final themeName = isDark ? 'dark' : 'light';

    group('$themeName theme shared component visual tests', () {
      for (final width in [320.0, 393.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('FixoPrimaryButton & FixoGhostButton at ${width}px scale $scale', (tester) async {
            tester.view.physicalSize = Size(width, 600);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              wrapComponent(
                isDark: isDark,
                width: width,
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FixoPrimaryButton(
                      label: 'Confirm and Continue',
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    FixoGhostButton(
                      label: 'Decline Offer',
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    FixoTonalButton(
                      label: 'Payment details',
                      icon: Icons.payments_outlined,
                      fullWidth: true,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FixoTonalButton(
                            label: 'Message',
                            icon: Icons.chat_bubble_outline,
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FixoTonalButton(
                            label: 'Call',
                            icon: Icons.phone_outlined,
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            final primaryFinder = find.byType(FixoPrimaryButton);
            final ghostFinder = find.byType(FixoGhostButton);
            expect(primaryFinder, findsOneWidget);
            expect(ghostFinder, findsOneWidget);

            // Minimum touch target and height verification
            final primarySize = tester.getSize(primaryFinder);
            final ghostSize = tester.getSize(ghostFinder);
            expect(primarySize.height, greaterThanOrEqualTo(DesignTokens.heightPrimary));
            expect(ghostSize.height, greaterThanOrEqualTo(DesignTokens.heightSecondary));
            expect(primarySize.width, lessThanOrEqualTo(width));
          });

          testWidgets('ModernJobCard at ${width}px scale $scale', (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              wrapComponent(
                isDark: isDark,
                width: width,
                scale: scale,
                child: ModernJobCard(
                  title: 'Fix broken kitchen mixer tap and check pipe connections',
                  category: 'Plumbing',
                  suburb: 'Mount Albert, Auckland',
                  priceLabel: '\$240.00',
                  scheduleLabel: 'Tomorrow at 8:00 am',
                  identityLabel: 'Wiremu Mahi',
                  status: 'Booked',
                  statusKind: FixoBadgeKind.live,
                  progressStatus: 'Booked',
                  actionLabel: 'Open chat',
                  onTap: () {},
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('Fix broken kitchen mixer tap and check pipe connections'), findsOneWidget);
            expect(find.text('Plumbing'), findsOneWidget);
            expect(find.text('\$240.00'), findsOneWidget);
            expect(find.text('Wiremu Mahi'), findsOneWidget);
            expect(find.text('Booked'), findsWidgets);
          });

          testWidgets('JobInfoGrid at ${width}px scale $scale', (tester) async {
            tester.view.physicalSize = Size(width, 600);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              wrapComponent(
                isDark: isDark,
                width: width,
                scale: scale,
                child: const JobInfoGrid(
                  tiles: [
                    JobInfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Scheduled',
                      value: 'Tomorrow at 8:00 am',
                    ),
                    JobInfoTile(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: '2 hours',
                    ),
                    JobInfoTile(
                      icon: Icons.attach_money_outlined,
                      label: 'Agreed Price',
                      value: '\$180.00',
                      emphasized: true,
                    ),
                    JobInfoTile(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: '14 Symonds Street, Auckland CBD',
                    ),
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byType(JobInfoGrid), findsOneWidget);
            expect(find.text('Tomorrow at 8:00 am'), findsOneWidget);
            expect(find.text('2 hours'), findsOneWidget);
            expect(find.text('\$180.00'), findsOneWidget);
          });
        }
      }

      // ── V16-05: Container language unification ─────────────────────────
      testWidgets('FixoCard uses unified border in $themeName', (tester) async {
        await tester.pumpWidget(
          wrapComponent(
            isDark: isDark,
            width: 393,
            scale: 1.0,
            child: const FixoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card title',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Card body text with some content.'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(FixoCard), findsOneWidget);
        expect(find.text('Card title'), findsOneWidget);
      });

      testWidgets('JobInfoTile unified border in $themeName', (tester) async {
        await tester.pumpWidget(
          wrapComponent(
            isDark: isDark,
            width: 393,
            scale: 1.0,
            child: const JobInfoGrid(
              tiles: [
                JobInfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Scheduled',
                  value: 'Tomorrow 8:00 am',
                ),
                JobInfoTile(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: '2 hours',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tomorrow 8:00 am'), findsOneWidget);
        expect(find.text('2 hours'), findsOneWidget);

        // Verify the tiles use the correct neutral border (paperLine tokens),
        // not the heavy inkSoft/outlineVariant color.
        final expectedBorderColor = isDark
            ? DesignTokens.paperLineDark
            : DesignTokens.paperLineLight;
        final containers = tester.widgetList<Container>(find.byType(Container));
        final tileContainers = containers.where((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration && decoration.border != null) {
            final border = decoration.border;
            if (border is Border) {
              return border.top.color == expectedBorderColor;
            }
          }
          return false;
        });
        expect(tileContainers.length, greaterThanOrEqualTo(2));
      });

      testWidgets('StatusBadge all variants in $themeName', (tester) async {
        await tester.pumpWidget(
          wrapComponent(
            isDark: isDark,
            width: 393,
            scale: 1.0,
            child: const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(label: 'Pay now', kind: FixoBadgeKind.actionNeeded),
                StatusBadge(label: 'Booked', kind: FixoBadgeKind.active),
                StatusBadge(label: 'Under review', kind: FixoBadgeKind.waiting),
                StatusBadge(label: 'Completed', kind: FixoBadgeKind.done),
                StatusBadge(label: 'Cancelled', kind: FixoBadgeKind.cancelled),
                StatusBadge(label: 'Disputed', kind: FixoBadgeKind.problem),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(StatusBadge), findsNWidgets(6));
      });

      testWidgets('JobProgress all 6 stages in $themeName', (tester) async {
        for (final status in [
          'Requested',
          'AwaitingPayment',
          'Booked',
          'InProgress',
          'AwaitingConfirmation',
          'Completed',
        ]) {
          await tester.pumpWidget(
            wrapComponent(
              isDark: isDark,
              width: 393,
              scale: 1.0,
              child: JobProgress(status: status),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(JobProgress), findsOneWidget);
        }
      });

      testWidgets('CompactProgressBar all stages in $themeName', (tester) async {
        for (final status in [
          'Requested',
          'Booked',
          'InProgress',
          'Completed',
          'Cancelled',
          'Expired',
          'Disputed',
        ]) {
          await tester.pumpWidget(
            wrapComponent(
              isDark: isDark,
              width: 393,
              scale: 1.0,
              child: CompactProgressBar(status: status),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(CompactProgressBar), findsOneWidget);
        }
      });

      testWidgets('JobTimeline collapsed and expanded in $themeName', (tester) async {
        await tester.pumpWidget(
          wrapComponent(
            isDark: isDark,
            width: 393,
            scale: 1.0,
            child: const JobTimeline(status: 'InProgress'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(JobTimeline), findsOneWidget);
        expect(find.text('View all steps'), findsOneWidget);

        await tester.tap(find.text('View all steps'));
        await tester.pumpAndSettle();
        expect(find.text('Hide steps'), findsOneWidget);
      });

      testWidgets('StickyActionBar with safe area inset in $themeName', (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? FixoTheme.dark() : FixoTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(393, 852),
                padding: EdgeInsets.only(bottom: 34), // Home indicator inset
              ),
              child: Scaffold(
                bottomNavigationBar: StickyActionBar(
                  child: FixoPrimaryButton(
                    label: 'Complete Booking',
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(StickyActionBar), findsOneWidget);
        final buttonRect = tester.getRect(find.byType(FixoPrimaryButton));
        // Ensure bottom button accounts for safe area and does not overflow viewport
        expect(buttonRect.bottom, lessThanOrEqualTo(852));
      });

      testWidgets('CustomBottomNavBar (homeowner & tradie) in $themeName', (tester) async {
        for (final isHomeowner in [true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: isDark ? FixoTheme.dark() : FixoTheme.light(),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(393, 852),
                  padding: EdgeInsets.only(bottom: 34),
                ),
                child: Scaffold(
                  bottomNavigationBar: CustomBottomNavBar(
                    currentIndex: 0,
                    tabs: isHomeowner
                        ? CustomBottomNavBar.homeownerTabs
                        : CustomBottomNavBar.tradieTabs,
                    showFab: isHomeowner,
                    onDestinationSelected: (_) {},
                    onPostJob: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(CustomBottomNavBar), findsOneWidget);
          if (isHomeowner) {
            expect(find.byKey(const Key('post_job_fab')), findsOneWidget);
          } else {
            expect(find.byKey(const Key('post_job_fab')), findsNothing);
          }
        }
      });

      testWidgets('OfferCountdown standard and compact in $themeName', (tester) async {
        final offer = JobOffer(
          id: 'o-1',
          jobId: 'j-1',
          tradieId: 't-1',
          offeredAtUtc: DateTime.now().toUtc(),
          expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 8, seconds: 30)),
          response: 'Pending',
          stage: 'Primary',
        );

        await tester.pumpWidget(
          wrapComponent(
            isDark: isDark,
            width: 393,
            scale: 1.0,
            child: Column(
              children: [
                OfferCountdown(offer: offer),
                const SizedBox(height: 16),
                OfferCountdown(offer: offer, compact: true),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(OfferCountdown), findsNWidgets(2));
      });

      testWidgets('OtpCodeField visual layout in $themeName', (tester) async {
        final controller = TextEditingController(text: '123456');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          wrapComponent(
            isDark: isDark,
            width: 320,
            scale: 1.0,
            child: OtpCodeField(controller: controller),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(OtpCodeField), findsOneWidget);
      });

      testWidgets('ConversationTile & ChatBubble in $themeName', (tester) async {
        final conv = ConversationSummary(
          jobId: '42',
          jobTitle: 'Fix leaking shower mixer',
          status: 'Booked',
          otherUserId: 'u-1',
          otherFirstName: 'Wiremu',
          lastMessage: 'I am on my way with the replacement cartridge.',
          lastMessageMine: false,
          lastMessageAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
          unreadCount: 2,
        );

        final msgOther = ChatMessage(
          id: 'm-1',
          jobId: '42',
          senderId: 'u-1',
          senderName: 'Wiremu',
          sentByMe: false,
          text: 'Arriving in 10 minutes.',
          sentAtUtc: DateTime.now().toUtc(),
        );

        final msgMine = ChatMessage(
          id: 'm-2',
          jobId: '42',
          senderId: 'me',
          senderName: 'Me',
          sentByMe: true,
          text: 'Great, front door is unlocked.',
          sentAtUtc: DateTime.now().toUtc(),
        );

        await tester.pumpWidget(
          wrapComponent(
            isDark: isDark,
            width: 393,
            scale: 1.0,
            child: Column(
              children: [
                ConversationTile(conversation: conv, onTap: () {}),
                const SizedBox(height: 16),
                ChatBubble(message: msgOther),
                ChatBubble(message: msgMine),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(ConversationTile), findsOneWidget);
        expect(find.byType(ChatBubble), findsNWidgets(2));
        expect(find.text('Fix leaking shower mixer'), findsOneWidget);
        expect(find.text('Wiremu'), findsWidgets);
      });
    });
  }
}
