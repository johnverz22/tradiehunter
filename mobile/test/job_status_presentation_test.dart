import 'package:fixo/models/marketplace.dart';
import 'package:fixo/views/widgets/job_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:fixo/views/widgets/job_status_presentation.dart';
import 'package:fixo/views/widgets/modern_job_card.dart';
import 'package:fixo/widgets/fixo_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedStatuses = {
    'Requested': ('Requested', FixoBadgeKind.waiting),
    'AwaitingPayment': ('Pay now', FixoBadgeKind.actionNeeded),
    'PaymentReview': ('Under review', FixoBadgeKind.waiting),
    'Booked': ('Booked', FixoBadgeKind.active),
    'InProgress': ('In progress', FixoBadgeKind.active),
    'AwaitingConfirmation': ('Review completion', FixoBadgeKind.actionNeeded),
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
  test(
    'actions describe existing destinations, not transition permissions',
    () {
      const actions = {
        'Requested': 'View matching',
        'AwaitingPayment': 'Payment details',
        'PaymentReview': 'View payment status',
        'Booked': 'View job details',
        'InProgress': 'View job details',
        'AwaitingConfirmation': 'Review completion',
        'Completed': 'View job details',
        'Cancelled': 'Open chat',
        'Expired': 'Open chat',
        'Disputed': 'Open chat',
      };
      for (final entry in actions.entries) {
        final presentation = JobStatusPresentation.forStatus(entry.key);
        expect(presentation.homeownerAction, entry.value);
        expect(
          presentation.tradieDashboardAction,
          [
                'Booked',
                'InProgress',
                'AwaitingConfirmation',
                'Completed',
                'Cancelled',
              ].contains(entry.key)
              ? 'View job details'
              : 'Open chat',
        );
        expect(
          presentation.tradieAction,
          [
                'Booked',
                'InProgress',
                'AwaitingConfirmation',
                'Completed',
                'Cancelled',
              ].contains(entry.key)
              ? 'View job details'
              : 'View request',
        );
      }
    },
  );
  testWidgets('homeowner actions retain canonical routes for every state', (
    tester,
  ) async {
    const paths = {
      'Requested': '/jobs/42/matching',
      'AwaitingPayment': '/jobs/42/payment',
      'PaymentReview': '/jobs/42/payment/status',
      'Booked': '/jobs/42/detail',
      'InProgress': '/jobs/42/detail',
      'AwaitingConfirmation': '/jobs/42/detail',
      'Completed': '/jobs/42/detail',
      'Cancelled': '/jobs/42/detail',
      'Expired': '/jobs/42/detail',
      'Disputed': '/jobs/42/detail',
      'FutureServerState': '/chat/42',
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
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
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
}
