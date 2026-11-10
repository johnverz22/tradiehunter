import 'package:fixo/models/marketplace.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/views/widgets/job_navigation.dart';
import 'package:fixo/views/widgets/job_status_presentation.dart';
import 'package:fixo/views/widgets/modern_job_card.dart';
import 'package:fixo/widgets/fixo_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const expectedStatuses = {
    'Requested': ('Requested', FixoBadgeKind.waiting),
    'AwaitingPayment': ('Payment due', FixoBadgeKind.actionNeeded),
    'PaymentReview': ('Under review', FixoBadgeKind.waiting),
    'Booked': ('Booked', FixoBadgeKind.active),
    'InProgress': ('In progress', FixoBadgeKind.active),
    'AwaitingConfirmation': ('Action needed', FixoBadgeKind.actionNeeded),
    'Completed': ('Completed', FixoBadgeKind.done),
    'Cancelled': ('Cancelled', FixoBadgeKind.cancelled),
    'Expired': ('Expired', FixoBadgeKind.cancelled),
    'Disputed': ('Disputed', FixoBadgeKind.problem),
  };

  for (final entry in expectedStatuses.entries) {
    test('${entry.key} has semantic status and kind', () {
      final presentation = JobStatusPresentation.forStatus(entry.key);
      expect(presentation.label, entry.value.$1);
      expect(presentation.kind, entry.value.$2);
    });
  }

  test('unknown status is cancelled/fallback and does not invent an action', () {
    for (final status in ['', 'FutureServerState']) {
      final presentation = JobStatusPresentation.forStatus(status);
      expect(presentation.label, 'Status unavailable');
      expect(presentation.kind, FixoBadgeKind.cancelled);
      expect(presentation.homeownerAction, 'Open chat');
      expect(presentation.tradieAction, 'View request');
    }
  });

  // ── Chip tone mapping ─────────────────────────────────────────────────────
  //
  // Every status must map to a tinted ChipTone — never solid fills.
  // The amber CTA is the only solid-fill element in the hierarchy.

  const expectedTones = {
    'Requested':           ChipTone.neutral,
    'AwaitingPayment':     ChipTone.warning,
    'PaymentReview':       ChipTone.neutral,
    'Booked':              ChipTone.info,
    'InProgress':          ChipTone.brand,
    'AwaitingConfirmation': ChipTone.warning,
    'Completed':           ChipTone.success,
    'Cancelled':           ChipTone.neutral,
    'Expired':             ChipTone.neutral,
    'Disputed':            ChipTone.danger,
  };

  for (final entry in expectedTones.entries) {
    test('${entry.key} chip maps to tone ${entry.value}', () {
      expect(
        JobStatusPresentation.forStatus(entry.key).chipTone,
        entry.value,
      );
    });
  }

  // ── tradieActionRequired ──────────────────────────────────────────────────
  //
  // Only statuses where the tradie must physically act now should trigger a CTA.

  const actionRequired = {
    'Booked':              true,
    'InProgress':          true,
    'AwaitingConfirmation': true,
    'Requested':           false,
    'AwaitingPayment':     false,
    'PaymentReview':       false,
    'Completed':           false,
    'Cancelled':           false,
    'Expired':             false,
    'Disputed':            false,
  };

  for (final entry in actionRequired.entries) {
    test('${entry.key} tradieActionRequired=${entry.value}', () {
      expect(
        JobStatusPresentation.forStatus(entry.key).tradieActionRequired,
        entry.value,
      );
    });
  }

  // ── Tradie CTA labels ────────────────────────────────────────────────────

  test('action-required statuses have specific tradie CTA labels', () {
    expect(
      JobStatusPresentation.forStatus('Booked').tradieAction,
      'Check in',
    );
    expect(
      JobStatusPresentation.forStatus('InProgress').tradieAction,
      'Check out',
    );
    expect(
      JobStatusPresentation.forStatus('AwaitingConfirmation').tradieAction,
      'Mark complete',
    );
  });

  // ── Homeowner actions ──────────────────────────────────────────────────────

  test('homeowner actions match expected destinations', () {
    const actions = {
      'Requested':           'View matching',
      'AwaitingPayment':     'Payment details',
      'PaymentReview':       'View payment status',
      'Booked':              'View job details',
      'InProgress':          'View job details',
      'AwaitingConfirmation': 'Review completion',
      'Completed':           'View job details',
      'Cancelled':           'Open chat',
      'Expired':             'Open chat',
      'Disputed':            'Open chat',
    };
    for (final entry in actions.entries) {
      final presentation = JobStatusPresentation.forStatus(entry.key);
      expect(presentation.homeownerAction, entry.value,
          reason: '${entry.key} homeownerAction');
    }
  });

  // ── StatusChip renders for every status ──────────────────────────────────
  //
  // Checks light AND dark, at 1.0x and 1.3x text scale.

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'StatusChip renders for all statuses — dark=$dark scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(400, 200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          for (final entry in expectedTones.entries) {
            final status = entry.key;
            final presentation = JobStatusPresentation.forStatus(status);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? FixoTheme.dark() : FixoTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: StatusChip(
                      label: presentation.label,
                      tone: presentation.chipTone,
                      icon: presentation.chipIcon,
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull,
                reason: '$status dark=$dark scale=$scale');
            expect(find.text(presentation.label), findsOneWidget,
                reason: '$status label visible');
            // Semantics label must be "Status: <label>".
            expect(
              find.bySemanticsLabel('Status: ${presentation.label}'),
              findsOneWidget,
              reason: '$status semantics',
            );
          }
        },
      );
    }
  }

  // ── StatusChip tint vs solid check ────────────────────────────────────────
  //
  // The chip background must be a tinted (alpha < 1) fill, never solid amber.

  testWidgets('StatusChip uses tinted bg, not solid amber fill', (tester) async {
    for (final tone in ChipTone.values) {
      final pres = JobStatusPresentation.forStatus(
        expectedTones.entries
            .firstWhere((e) => e.value == tone,
                orElse: () => const MapEntry('Requested', ChipTone.neutral))
            .key,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: FixoTheme.light(),
          home: Scaffold(
            body: Center(
              child: StatusChip(
                label: pres.label,
                tone: pres.chipTone,
                icon: pres.chipIcon,
              ),
            ),
          ),
        ),
      );
      // Find the chip Container and verify its color is semi-transparent.
      final containers = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(StatusChip),
              matching: find.byType(Container),
            ),
          )
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).color != null)
          .toList();
      expect(containers, isNotEmpty, reason: 'chip has a decoration container');
      final bg = (containers.first.decoration! as BoxDecoration).color!;
      expect(bg.a, lessThan(1.0),
          reason: 'chip bg is tinted (alpha < 1), not solid for tone $tone');
      // Must not be raw amber.
      expect(bg, isNot(DesignTokens.amber),
          reason: 'chip bg is not solid amber for tone $tone');
    }
  });

  // ── ModernJobCard wraps at 320px/2x ──────────────────────────────────────

  for (final dark in [false, true]) {
    testWidgets('mapped cards wrap at 320px/2x, dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(320, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      for (final status in expectedStatuses.keys) {
        final presentation = JobStatusPresentation.forStatus(status);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? FixoTheme.dark() : FixoTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ModernJobCard(
                    title: 'Repair leaking kitchen plumbing',
                    category: 'Plumbing',
                    suburb: 'A long suburb name',
                    status: presentation.label,
                    progressStatus: status,
                    statusKind: presentation.kind,
                    actionLabel: presentation.homeownerAction,
                    onTap: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(presentation.label), findsWidgets);
        final action = find.widgetWithText(
          TextButton,
          presentation.homeownerAction,
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(taps, expectedStatuses.length);
    });
  }

  // ── Homeowner route table ─────────────────────────────────────────────────

  testWidgets('homeowner actions retain canonical routes for every state', (
    tester,
  ) async {
    const paths = {
      'Requested':           '/jobs/42/matching',
      'AwaitingPayment':     '/jobs/42/payment',
      'PaymentReview':       '/jobs/42/payment/status',
      'Booked':              '/jobs/42/detail',
      'InProgress':          '/jobs/42/detail',
      'AwaitingConfirmation': '/jobs/42/detail',
      'Completed':           '/jobs/42/detail',
      'Cancelled':           '/jobs/42/detail',
      'Expired':             '/jobs/42/detail',
      'Disputed':            '/jobs/42/detail',
      'FutureServerState':   '/chat/42',
    };
    for (final entry in paths.entries) {
      final job = Job(
        id: '42',
        title: 'Repair',
        category: 'Plumbing',
        suburb: 'Suburb',
        status: entry.key,
        stage: 0,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => openHomeownerJob(context, job),
                child: Text(
                  JobStatusPresentation.forStatus(job.status).homeownerAction,
                ),
              ),
            ),
          ),
          for (final path in paths.values.toSet())
            GoRoute(
              path: path,
              builder: (_, _) => const Scaffold(body: Text('Destination')),
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        entry.value,
      );
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    }
  });
}
