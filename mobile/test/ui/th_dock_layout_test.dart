// THDock layout contract (dock revision): full-bleed bar flush with the bottom
// edge, equal-width slots, Post job in-line as the centred slot, content
// capped at Sizes.dockMaxContent on wide screens, nothing overflowing at 200%.
import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _height = 800.0;
const _inset = 34.0;

const _homeownerKeys = <Key>[
  Key('dock_home'),
  Key('dock_jobs'),
  Key('post_job_fab'),
  Key('dock_chat'),
  Key('dock_profile'),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required THDockRole role,
  double textScale = 1.0,
  double bottomInset = 0,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final inset = EdgeInsets.only(bottom: bottomInset);
  await tester.pumpWidget(
    MaterialApp(
      theme: THTheme.light,
      darkTheme: THTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: inset,
          viewPadding: inset,
        ),
        child: child!,
      ),
      home: Scaffold(
        // Same shape as ThShell: content fills the rest, the dock sits below.
        body: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            THDock(
              role: role,
              active: THDockTab.home,
              badges: const {THDockTab.chat: 120},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 744.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('homeowner dock at ${width.toInt()} px, ${scale}x text', (
        tester,
      ) async {
        await _pump(
          tester,
          width: width,
          role: THDockRole.homeowner,
          textScale: scale,
          bottomInset: _inset,
        );
        expect(tester.takeException(), isNull);

        // Full-bleed, flush with the bottom edge, opaque to the very bottom.
        final bar = tester.getRect(find.byType(THDock));
        expect(bar.left, 0);
        expect(bar.right, width);
        expect(bar.bottom, _height);
        expect(bar.height, Sizes.dock + Radii.hairline + _inset);

        // Five equal-width slots, Post job exactly centred.
        final rects = [
          for (final k in _homeownerKeys) tester.getRect(find.byKey(k)),
        ];
        for (final r in rects) {
          expect(r.width, closeTo(rects.first.width, 0.01));
          expect(r.height, greaterThanOrEqualTo(Sizes.tapMin));
          expect(r.width, greaterThanOrEqualTo(Sizes.tapMin));
        }
        final content = width < Sizes.dockMaxContent
            ? width
            : Sizes.dockMaxContent;
        final expectedSlot = content / 5;
        expect(rects.first.width, closeTo(expectedSlot, 0.01));
        expect(rects[2].center.dx, closeTo(width / 2, 0.01));

        // Slots stay inside the capped content area.
        expect(
          rects.first.left,
          closeTo((width - expectedSlot * 5) / 2, 0.01),
        );

        // Labels never wrap or break mid-word.
        for (final label in ['Home', 'Jobs', 'Post job', 'Chat', 'Profile']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 1, reason: label);
          expect(text.softWrap, isFalse, reason: label);
        }
      });
    }
  }

  testWidgets('post job tile is in the row, sized by token, with its label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await _pump(tester, width: 393, role: THDockRole.homeowner);
    final slot = tester.getRect(find.byKey(const Key('post_job_fab')));
    final tile = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('post_job_fab')),
        matching: find.byType(Container),
      ),
    );
    expect(tile.size, const Size.square(Sizes.dockPost));
    // Inside the bar: no overflow past its top edge.
    final bar = tester.getRect(find.byType(THDock));
    expect(tile.top, greaterThanOrEqualTo(bar.top));
    expect(slot.center.dx, closeTo(tile.center.dx, 0.01));
    // Same icon-area centre line as a regular item's icon.
    final homeIcon = tester.getCenter(find.byIcon(Icons.home_rounded));
    expect(tile.center.dy, closeTo(homeIcon.dy, 0.01));
    expect(find.text('Post job'), findsOneWidget);
    expect(find.bySemanticsLabel('New request'), findsOneWidget);
  });

  testWidgets('tradie dock keeps four equal slots and no Post job', (
    tester,
  ) async {
    await _pump(tester, width: 393, role: THDockRole.tradie);
    expect(find.byKey(const Key('post_job_fab')), findsNothing);
    final rects = [
      for (final k in const [
        Key('dock_home'),
        Key('dock_jobs'),
        Key('dock_chat'),
        Key('dock_profile'),
      ])
        tester.getRect(find.byKey(k)),
    ];
    for (final r in rects) {
      expect(r.width, closeTo(393 / 4, 0.01));
    }
    expect(tester.getRect(find.byType(THDock)).bottom, _height);
  });

  testWidgets('dock paints an opaque bar in dark mode too', (tester) async {
    await _pump(tester, width: 393, role: THDockRole.homeowner, dark: true);
    final bar = tester.widget<Material>(
      find
          .descendant(of: find.byType(THDock), matching: find.byType(Material))
          .first,
    );
    expect(bar.color!.a, 1.0);
  });
}
