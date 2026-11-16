// Visual smoke test: renders the homeowner bottom nav bar (glass + edge FAB)
// in light and dark to PNGs for eyeballing. Run:
//   flutter test test/render_check_test.dart --plain-name 'render nav'
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixo/views/widgets/custom_bottom_nav_bar.dart';

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final data = await file.readAsBytes();
  final buffer = data.buffer.asByteData();
  final loader = FontLoader(family)..addFont(Future.value(buffer));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont(
      'Roboto',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    );
  });

  testWidgets(
    'homeowner dock keeps the tradie dock height (edge FAB adds none)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 220);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      double barHeight(bool fab) {
        return tester.getSize(find.byType(CustomBottomNavBar).first).height;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 0,
              showFab: true,
              tabs: CustomBottomNavBar.homeownerTabs,
              onDestinationSelected: (_) {},
              onPostJob: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final homeownerHeight = barHeight(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 0,
              showFab: false,
              tabs: CustomBottomNavBar.tradieTabs,
              onDestinationSelected: (_) {},
              onPostJob: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tradieHeight = barHeight(false);

      // The edge FAB overlaps the bar, it must not inflate it.
      expect(homeownerHeight, tradieHeight);
    },
  );

  testWidgets('render homeowner nav bar light+dark', (tester) async {
    tester.view.physicalSize = const Size(390, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            useMaterial3: true,
          ),
          home: Scaffold(
            backgroundColor: dark
                ? const Color(0xFF14181B)
                : const Color(0xFFF6F4EE),
            body: const SizedBox.expand(),
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 0,
              showFab: true,
              tabs: CustomBottomNavBar.homeownerTabs,
              onDestinationSelected: (_) {},
              onPostJob: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FAB must poke above the bar's top edge: its center is below
      // the bar's top by exactly half its 56px height.
      final fab = tester.getTopLeft(find.byKey(const Key('post_job_fab')));
      final bar = tester.getTopLeft(find.byType(CustomBottomNavBar).first);
      // fab top should be ABOVE bar top (negative delta ≈ -26).
      final delta = fab.dy - bar.dy;
      expect(delta < -10, isTrue, reason: 'FAB top $fab vs bar top $bar');

      // Mockup .fab: horizontally centred, 56x56, radius 18.
      final size = tester.getSize(find.byKey(const Key('post_job_fab')));
      expect(size, const Size(56, 56));
      final centerX = fab.dx + 28;
      final barWidth = tester
          .getSize(find.byType(CustomBottomNavBar).first)
          .width;
      expect(
        (centerX - barWidth / 2).abs() < 2,
        isTrue,
        reason: 'FAB centre $centerX vs bar centre ${barWidth / 2}',
      );

      if (Platform.isLinux) {
        await expectLater(
          find.byType(CustomBottomNavBar).first,
          matchesGoldenFile(
            'goldens/nav_homeowner_${dark ? 'dark' : 'light'}.png',
          ),
        );
      }
    }
  });
}
