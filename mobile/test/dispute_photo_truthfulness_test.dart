import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/dispute_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/views/jobs/dispute_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profile_truthfulness_test.dart' show JobsFixture;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final dark in [false, true]) {
    for (final result in ['cancel', 'error', 'selected']) {
      testWidgets(
        'dispute photos use actual selection result=$result dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(390, 2000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var calls = 0;
          const path = 'assets/illustrations/onboarding_chat.png';
          const channel = MethodChannel('plugins.flutter.io/image_picker');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              calls++;
              if (result == 'error') {
                throw PlatformException(code: 'permission_denied');
              }
              return result == 'selected' ? path : null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          final container = ProviderContainer(
            overrides: [
              jobsRepositoryProvider.overrideWithValue(JobsFixture([])),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? FixoTheme.dark() : FixoTheme.light(),
                home: const DisputeScreen(jobId: '42'),
              ),
            ),
          );
          await tester.scrollUntilVisible(
            find.byIcon(Icons.add_a_photo_outlined),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(
            container.read(disputeProvider).photoPaths,
            result == 'selected' ? [path] : isEmpty,
          );
          if (result == 'error') {
            expect(
              find.text('Could not open photos. Try again.'),
              findsOneWidget,
            );
          }
          if (result == 'selected') {
            await tester.tap(find.byIcon(Icons.close));
            await tester.pumpAndSettle();
            expect(container.read(disputeProvider).photoPaths, isEmpty);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
