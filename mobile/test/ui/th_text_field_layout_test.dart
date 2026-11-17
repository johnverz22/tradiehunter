// THTextField geometry vs the mockup `.fld` (docs/design/mockups/index.html):
// bordered surface, min-height 56, label on top, then ONE row where the icon
// and the value/hint share a vertical centre. Regression test for the
// "icon drops below the hint / field grows past 56" mismatch.
import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase3_test_setup.dart';

Widget _host(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
  home: ThScope(
    themeMode: mode,
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [child]),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadPhase3Fixtures);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('THTextField (${mode.name})', () {
      testWidgets('email field is 56 high with icon and hint on one row', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const THTextField(
              key: Key('email'),
              label: 'Email',
              hint: 'e.g. kiaora@example.co.nz',
              icon: Icons.mail_outline,
            ),
            mode: mode,
          ),
        );
        await tester.pumpAndSettle();

        final box = tester.getRect(find.byKey(const Key('email')));
        expect(box.height, closeTo(Sizes.input, 3));

        // Label is upper-cased like the mockup's small-caps eyebrow.
        expect(find.text('EMAIL'), findsOneWidget);

        final icon = tester.getCenter(find.byIcon(Icons.mail_outline));
        final hint = tester.getCenter(find.text('e.g. kiaora@example.co.nz'));
        expect(
          (icon.dy - hint.dy).abs(),
          lessThan(2),
          reason: 'icon and hint must share the value row',
        );
        // Value row sits under the label, inside the border.
        final label = tester.getCenter(find.text('EMAIL'));
        expect(label.dy, lessThan(icon.dy));
        expect(icon.dx - box.left, lessThan(14 + 18 + 1));
      });

      testWidgets('password field with trailing toggle keeps 56 high, 44 tap', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            THTextField(
              key: const Key('pw'),
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
              trailing: IconButton(
                key: const Key('eye'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: Sizes.buttonSm,
                  height: Sizes.buttonSm,
                ),
                onPressed: () {},
                icon: const Icon(Icons.visibility_outlined, size: 18),
              ),
            ),
            mode: mode,
          ),
        );
        await tester.pumpAndSettle();

        final box = tester.getRect(find.byKey(const Key('pw')));
        expect(box.height, closeTo(Sizes.input, 3));

        final eye = tester.getSize(find.byKey(const Key('eye')));
        expect(eye.width, greaterThanOrEqualTo(44));
        expect(eye.height, greaterThanOrEqualTo(44));

        final eyeRect = tester.getRect(find.byKey(const Key('eye')));
        expect(eyeRect.bottom, lessThanOrEqualTo(box.bottom + 0.5));
        expect(eyeRect.top, greaterThanOrEqualTo(box.top - 0.5));

        final lock = tester.getCenter(find.byIcon(Icons.lock_outline));
        final vis = tester.getCenter(find.byIcon(Icons.visibility_outlined));
        expect((lock.dy - vis.dy).abs(), lessThan(3));
      });
    });
  }
}
