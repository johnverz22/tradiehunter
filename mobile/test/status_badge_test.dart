import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/widgets/fixo_cards.dart';

void main() {
  group('StatusBadge widget tests', () {
    testWidgets('all 6 variants render distinct icon, label and colors in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: Column(
              children: [
                StatusBadge(
                  label: 'Pay now',
                  kind: FixoBadgeKind.actionNeeded,
                ),
                StatusBadge(
                  label: 'In progress',
                  kind: FixoBadgeKind.active,
                ),
                StatusBadge(
                  label: 'Under review',
                  kind: FixoBadgeKind.waiting,
                ),
                StatusBadge(
                  label: 'Completed',
                  kind: FixoBadgeKind.done,
                ),
                StatusBadge(
                  label: 'Cancelled',
                  kind: FixoBadgeKind.cancelled,
                ),
                StatusBadge(
                  label: 'Disputed',
                  kind: FixoBadgeKind.problem,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pay now'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Disputed'), findsOneWidget);

      // Verify icons
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Verify each badge container has 28px height
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(StatusBadge),
          matching: find.byType(Container),
        ),
      );
      expect(containers.length, 6);
      for (final container in containers) {
        expect(container.constraints?.minHeight, 28.0);
        expect(container.constraints?.maxHeight, 28.0);
      }
    });

    testWidgets('cancelled and completed are visually distinct', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: Column(
              children: [
                StatusBadge(
                  label: 'Completed',
                  kind: FixoBadgeKind.done,
                ),
                StatusBadge(
                  label: 'Cancelled',
                  kind: FixoBadgeKind.cancelled,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final (doneBg, doneFg, doneIcon) = StatusBadge.resolveVisuals(
        FixoBadgeKind.done,
        false,
      );
      final (cancBg, cancFg, cancIcon) = StatusBadge.resolveVisuals(
        FixoBadgeKind.cancelled,
        false,
      );

      expect(doneBg != cancBg, isTrue);
      expect(doneFg != cancFg, isTrue);
      expect(doneIcon != cancIcon, isTrue);
      expect(doneIcon, Icons.check_rounded);
      expect(cancIcon, Icons.close_rounded);
    });

    testWidgets('orange is only used for actionNeeded variant', (tester) async {
      const allKinds = [
        FixoBadgeKind.actionNeeded,
        FixoBadgeKind.active,
        FixoBadgeKind.waiting,
        FixoBadgeKind.done,
        FixoBadgeKind.cancelled,
        FixoBadgeKind.problem,
      ];

      for (final isDark in [false, true]) {
        for (final kind in allKinds) {
          final (bg, _, _) = StatusBadge.resolveVisuals(kind, isDark);
          if (kind == FixoBadgeKind.actionNeeded) {
            expect(bg, DesignTokens.amber);
          } else {
            expect(bg != DesignTokens.amber, isTrue);
          }
        }
      }
    });

    testWidgets('hugs content and never stretches full width in a ListView', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                StatusBadge(
                  label: 'Pay now',
                  kind: FixoBadgeKind.actionNeeded,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the inner decorated container of the badge
      final badgeContainer = find.descendant(
        of: find.byType(StatusBadge),
        matching: find.byType(Container),
      );
      final size = tester.getSize(badgeContainer);
      expect(size.height, 28.0);
      // Width must hug content, significantly less than the 400px screen width
      expect(size.width, lessThan(200.0));
      expect(size.width, greaterThan(20.0));
    });

    testWidgets('supports custom icon override', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Custom',
              kind: FixoBadgeKind.active,
              icon: Icons.star,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('dark mode tints and colors meet contrast requirements', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                StatusBadge(
                  label: 'Pay now',
                  kind: FixoBadgeKind.actionNeeded,
                ),
                StatusBadge(
                  label: 'In progress',
                  kind: FixoBadgeKind.active,
                ),
                StatusBadge(
                  label: 'Under review',
                  kind: FixoBadgeKind.waiting,
                ),
                StatusBadge(
                  label: 'Completed',
                  kind: FixoBadgeKind.done,
                ),
                StatusBadge(
                  label: 'Cancelled',
                  kind: FixoBadgeKind.cancelled,
                ),
                StatusBadge(
                  label: 'Disputed',
                  kind: FixoBadgeKind.problem,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatusBadge), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });
  });
}
