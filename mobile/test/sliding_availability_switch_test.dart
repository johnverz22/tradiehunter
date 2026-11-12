import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/views/widgets/sliding_availability_switch.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget buildSwitch({
    required bool isOnline,
    required bool isLoading,
    bool hasError = false,
    required VoidCallback onToggle,
    bool dark = false,
  }) {
    return MaterialApp(
      theme: dark ? FixoTheme.dark() : FixoTheme.light(),
      home: Scaffold(
        body: Center(
          child: SlidingAvailabilitySwitch(
            key: const Key('availability_button'),
            isOnline: isOnline,
            isLoading: isLoading,
            hasError: hasError,
            onToggle: onToggle,
          ),
        ),
      ),
    );
  }

  group('SlidingAvailabilitySwitch states & interaction', () {
    testWidgets('online state: renders label Online and check icon',
        (tester) async {
      await tester.pumpWidget(buildSwitch(
        isOnline: true,
        isLoading: false,
        onToggle: () {},
      ));

      expect(find.text('Online'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('offline state: renders label Offline and power icon',
        (tester) async {
      await tester.pumpWidget(buildSwitch(
        isOnline: false,
        isLoading: false,
        onToggle: () {},
      ));

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loading state: renders spinner in thumb and ignores taps',
        (tester) async {
      bool toggled = false;
      await tester.pumpWidget(buildSwitch(
        isOnline: true,
        isLoading: true,
        onToggle: () => toggled = true,
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('availability_button')));
      await tester.pump();
      expect(toggled, isFalse);
    });

    testWidgets('tap triggers onToggle', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(buildSwitch(
        isOnline: true,
        isLoading: false,
        onToggle: () => toggled = true,
      ));

      await tester.tap(find.byKey(const Key('availability_button')));
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('drag past halfway commits toggle', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(buildSwitch(
        isOnline: false, // thumb starts on left (offline)
        isLoading: false,
        onToggle: () => toggled = true,
      ));

      // Drag right by 70 pixels (past halfway of track width ~112dp)
      await tester.drag(
        find.byKey(const Key('availability_button')),
        const Offset(70.0, 0.0),
      );
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('drag less than halfway reverts without commit',
        (tester) async {
      bool toggled = false;
      await tester.pumpWidget(buildSwitch(
        isOnline: false,
        isLoading: false,
        onToggle: () => toggled = true,
      ));

      // Drag right by 22 pixels (exceeds 18px touch-slop so gesture is recognized as drag,
      // but well below 34px halfway point of the track)
      await tester.drag(
        find.byKey(const Key('availability_button')),
        const Offset(22.0, 0.0),
      );
      await tester.pump();
      expect(toggled, isFalse);
    });

    testWidgets('hasError triggers shake animation without throw',
        (tester) async {
      await tester.pumpWidget(buildSwitch(
        isOnline: true,
        isLoading: false,
        hasError: false,
        onToggle: () {},
      ));

      // Update widget to hasError = true
      await tester.pumpWidget(buildSwitch(
        isOnline: true,
        isLoading: false,
        hasError: true,
        onToggle: () {},
      ));

      // Shake animation plays frames
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Semantics has toggled button with availability label',
        (tester) async {
      await tester.pumpWidget(buildSwitch(
        isOnline: true,
        isLoading: false,
        onToggle: () {},
      ));

      final semantics = tester.getSemantics(find.byKey(const Key('availability_button')));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isToggled.name, 'isTrue');
      expect(semantics.label, 'Availability');
      expect(semantics.value, 'Online');
      expect(semantics.hint, 'Double tap to go offline');
    });

    testWidgets('Offline Semantics has toggled=false and online hint',
        (tester) async {
      await tester.pumpWidget(buildSwitch(
        isOnline: false,
        isLoading: false,
        onToggle: () {},
      ));

      final semantics = tester.getSemantics(find.byKey(const Key('availability_button')));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isToggled.name, 'isFalse');
      expect(semantics.label, 'Availability');
      expect(semantics.value, 'Offline');
      expect(semantics.hint, 'Double tap to go online');
    });
  });
}
