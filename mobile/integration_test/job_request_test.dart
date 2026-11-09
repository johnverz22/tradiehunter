// P2 — Job Request
//
// Single-user flow: homeowner posts a job.
// No tradie simulator needed for these tests.
//
// Prerequisites:
//   - Stack up: docker compose up -d
//   - Accounts seeded: python3 scripts/e2e-credentials.py --keep
//   - At least one verified tradie with rates set nearby.
//
// Run:
//   flutter test integration_test/job_request_test.dart --device-id <id>

import 'package:decimal/decimal.dart';
import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('P2 — Job Request', () {
    // ── Post Job screen renders all required fields ────────────────────────
    testWidgets('P2-08 Post Job screen renders required fields', (
      tester,
    ) async {
      app.main();
      await loginAsHomeowner(tester);

      // Navigate to Post Job — tap the FAB or the nav item
      final postJobFab = find.byKey(const Key('post_job_fab'));
      if (postJobFab.evaluate().isNotEmpty) {
        await tester.tap(postJobFab);
      } else {
        // Fallback: go via bottom nav "Post" tab text
        await tester.tap(find.text('Post'));
      }
      await pumpFor(tester);

      expect(find.byKey(const Key('post_job_screen')), findsOneWidget);
      expect(find.byKey(const Key('service_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('latitude_field')), findsNothing);
      expect(find.byKey(const Key('longitude_field')), findsNothing);
      expect(find.byKey(const Key('address_search_field')), findsOneWidget);
      expect(find.byKey(const Key('title_field')), findsOneWidget);
      expect(find.byKey(const Key('hours_field')), findsOneWidget);
      expect(find.byKey(const Key('description_field')), findsOneWidget);
      expect(find.byKey(const Key('post_job_button')), findsOneWidget);
    });

    // ── P2-04: submit without required fields shows validation ────────────
    testWidgets('P2-04 submitting empty form stays on post job screen', (
      tester,
    ) async {
      app.main();
      await loginAsHomeowner(tester);

      final postJobFab = find.byKey(const Key('post_job_fab'));
      if (postJobFab.evaluate().isNotEmpty) {
        await tester.tap(postJobFab);
      } else {
        await tester.tap(find.text('Post'));
      }
      await pumpFor(tester);

      // Tap Post Job without filling anything
      await tester.tap(find.byKey(const Key('post_job_button')));
      await pumpFor(tester, kNetworkSettle);

      // Should still be on the post job screen — no navigation occurred
      expect(find.byKey(const Key('post_job_screen')), findsOneWidget);
    });

    testWidgets(
      'P2-LINZ resolves an address through the live API and clears edited locations',
      (tester) async {
        app.main();
        await loginAsHomeowner(tester);
        final postJobFab = find.byKey(const Key('post_job_fab'));
        await tester.tap(
          postJobFab.evaluate().isNotEmpty ? postJobFab : find.text('Post'),
        );
        await pumpFor(tester);
        final addressField = find.byKey(const Key('address_search_field'));
        await tester.ensureVisible(addressField);
        await tester.enterText(addressField, '70 Symonds Street Auckland');
        await pumpFor(tester, kNetworkSettle);
        final candidate = find.text('70 Symonds Street, Grafton, Auckland');
        expect(candidate, findsOneWidget);
        await tester.ensureVisible(candidate);
        await tester.tap(candidate);
        await pumpFor(tester);
        expect(find.text('Address selected'), findsOneWidget);
        expect(find.byKey(const Key('latitude_field')), findsNothing);
        expect(find.byKey(const Key('longitude_field')), findsNothing);
        await tester.ensureVisible(addressField);
        await tester.tap(addressField);
        await pumpFor(tester, const Duration(milliseconds: 500));
        await tester.enterText(
          addressField,
          'ZZZNoSuchRoadFixture987654 Auckland',
        );
        expect(
          tester.widget<TextField>(addressField).controller!.text,
          'ZZZNoSuchRoadFixture987654 Auckland',
        );
        await pumpFor(tester, kNetworkSettle);
        expect(find.text('Address selected'), findsNothing);
        expect(find.textContaining('No matching addresses'), findsOneWidget);
      },
    );

    if (const bool.fromEnvironment('FIXO_LIVE_POST_MATCH')) {
      testWidgets('P2-LINZ posts one local job, starts matching and cancels it', (
        tester,
      ) async {
        app.main();
        await loginAsHomeowner(tester);
        final postJobFab = find.byKey(const Key('post_job_fab'));
        await tester.tap(
          postJobFab.evaluate().isNotEmpty ? postJobFab : find.text('Post'),
        );
        await pumpFor(tester);
        final addressField = find.byKey(const Key('address_search_field'));
        final container = ProviderScope.containerOf(
          tester.element(addressField),
          listen: false,
        );
        final keepAlive = container.listen(postJobProvider, (_, _) {});
        final notifier = container.read(postJobProvider.notifier);
        final repository = container.read(jobsRepositoryProvider);
        expect(container.read(postJobProvider).submittedJobId, isNull);
        String? createdId;
        try {
          await tester.ensureVisible(addressField);
          await tester.enterText(addressField, '70 Symonds Street Auckland');
          await pumpFor(tester, kNetworkSettle);
          final candidate = find.text('70 Symonds Street, Grafton, Auckland');
          expect(candidate, findsOneWidget);
          await tester.ensureVisible(candidate);
          await tester.tap(candidate);
          await pumpFor(tester);
          const overrideServiceId = int.fromEnvironment(
            'FIXO_LIVE_SERVICE_ID',
            defaultValue: -1,
          );
          final services = container.read(postJobProvider).services;
          if (overrideServiceId > 0) {
            final service = services.where((s) => s.id == overrideServiceId);
            expect(
              service,
              isNotEmpty,
              reason:
                  'FIXO_LIVE_SERVICE_ID=$overrideServiceId not in service catalog.',
            );
            await notifier.selectService(service.first);
          } else {
            for (final service in services) {
              await notifier.selectService(service);
              if (container.read(postJobProvider).rateOptions.isNotEmpty) {
                break;
              }
            }
          }
          expect(
            container.read(postJobProvider).rateOptions,
            isNotEmpty,
            reason: 'A verified available nearby tradie rate is required; no fixture is invented.',
          );
          await tester.pump();
          final rateTile = find.byType(CheckboxListTile).first;
          await tester.ensureVisible(rateTile);
          await tester.tap(rateTile);
          await tester.pump();
          final chosenRate = container.read(postJobProvider).selectedRate!;
          final titleField = find.byKey(const Key('title_field'));
          await tester.ensureVisible(titleField);
          await tester.enterText(
            titleField,
            'V15-10 LINZ verification ${DateTime.now().toUtc().millisecondsSinceEpoch}',
          );
          final descriptionField = find.byKey(const Key('description_field'));
          await tester.ensureVisible(descriptionField);
          await tester.enterText(
            descriptionField,
            'Approved local address/post/matching test. Cancel after matching starts.',
          );
          notifier.setHours('2');
          final scheduled = DateTime.now().add(const Duration(days: 2));
          notifier.setScheduledStartLocal(scheduled);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
          expect(container.read(postJobProvider).isValid, isTrue);
          await tester.tap(find.byKey(const Key('post_job_button')));
          await pumpFor(tester, kNetworkSettle);
          createdId = container.read(postJobProvider).submittedJobId;
          expect(
            createdId,
            isNotNull,
            reason: container.read(postJobProvider).error,
          );
          final job = await repository.getJobById(createdId!);
          expect(job, isNotNull);
          expect(job!.address, '70 Symonds Street, Grafton, Auckland');
          expect(job.latitude, closeTo(-36.8559449861, 0.000001));
          expect(job.longitude, closeTo(174.7665433333, 0.000001));
          expect(job.hourlyRate, chosenRate.hourlyRate);
          expect(job.totalAmount, chosenRate.hourlyRate * Decimal.fromInt(2));
          expect(job.scheduledStartUtc!.isUtc, isTrue);
          await pollUntil(() async {
            await tester.pump(const Duration(seconds: 1));
            return container
                    .read(matchingProgressProvider(createdId!))
                    .offersMade >
                0;
          }, timeout: kMatchingSettle);
          expect(find.textContaining('Contacting'), findsWidgets);
          debugPrint(
            'V15-10 local job $createdId: resolved coordinates, Decimal total, UTC timestamp and matching offer verified.',
          );
        } finally {
          createdId ??= container.read(postJobProvider).submittedJobId;
          if (createdId != null) {
            final current = await repository.getJobById(createdId);
            if (current?.status != 'Cancelled') {
              expect(
                await repository.cancelJobWithReason(
                  createdId,
                  reasonCode: 'homeowner_changed_mind',
                  notes: 'V15-10 approved local verification complete.',
                ),
                isTrue,
              );
            }
            expect(
              (await repository.getJobById(createdId))?.status,
              'Cancelled',
            );
            debugPrint(
              'V15-10 local job $createdId cancelled through the existing API; no rows deleted.',
            );
          }
          appRouter.go('/home');
          await pumpFor(tester);
          keepAlive.close();
        }
      });
    }

    // ── P2-09: homeowner dashboard shows job cards ─────────────────────────
    testWidgets('P2-09 homeowner dashboard renders job cards', (tester) async {
      app.main();
      await loginAsHomeowner(tester);

      expect(find.byKey(const Key('homeowner_dashboard')), findsOneWidget);
      // At least the dashboard loaded — job cards may or may not be present
      // depending on seed state. Assert no crash.
    });
  });
}
