// S-01 (fix plan): the floating dock must not let list rows show through, and
// lists must clear it including the home-indicator inset.
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  ThemeMode mode,
  Widget body, {
  EdgeInsets inset = EdgeInsets.zero,
}) => MaterialApp(
    theme: THTheme.light,
    darkTheme: THTheme.dark,
    themeMode: mode,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: inset,
        viewPadding: inset,
      ),
      child: child!,
    ),
    home: Scaffold(body: body),
  );

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('dock surface is fully opaque (${mode.name})', (tester) async {
      await tester.pumpWidget(
        _app(
          mode,
          const Align(
            alignment: Alignment.bottomCenter,
            child: THDock(role: THDockRole.homeowner, active: THDockTab.home),
          ),
        ),
      );

      final dockBox = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(THDock),
              matching: find.byType(Container),
            )
            .first,
      );
      final fill = (dockBox.decoration! as BoxDecoration).color!;
      expect(fill.a, 1.0, reason: 'glass alpha must not leak page content');
    });
  }

  testWidgets('thDockClearance adds the bottom inset to the base clearance', (
    tester,
  ) async {
    late double none;
    late double notched;

    Widget probe(void Function(double) sink) => Builder(
      builder: (context) {
        sink(thDockClearance(context));
        return const SizedBox();
      },
    );

    await tester.pumpWidget(_app(ThemeMode.light, probe((v) => none = v)));
    expect(none, Sizes.dockClearance);

    await tester.pumpWidget(
      _app(
        ThemeMode.light,
        probe((v) => notched = v),
        inset: const EdgeInsets.only(bottom: 34),
      ),
    );
    expect(notched, Sizes.dockClearance + 34);
  });
}
