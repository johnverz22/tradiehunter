import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/job_hub_client.dart';
import 'package:fixo/ui/feedback/notice_copy.dart';
import 'package:fixo/ui/homeowner/ho_request_sent_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';

void main() {
  group('P1 OfferEventType parsing', () {
    test('parses withdrawn, superseded, and closed', () {
      expect(OfferEventType.parse('OfferWithdrawn'), OfferEventType.withdrawn);
      expect(
        OfferEventType.parse('OfferSuperseded'),
        OfferEventType.superseded,
      );
      expect(OfferEventType.parse('OfferClosed'), OfferEventType.closed);
    });
  });

  group('P1 NoticeCopy error mapping', () {
    test('maps offer error codes to user-friendly copy', () {
      expect(
        NoticeCopy.forOfferError('offer_expired', accept: true),
        'This offer has expired.',
      );
      expect(
        NoticeCopy.forOfferError('job_already_booked', accept: true),
        'Another tradie already took this job.',
      );
      expect(
        NoticeCopy.forOfferError('job_not_requestable', accept: true),
        'This job is no longer open.',
      );
      expect(
        NoticeCopy.forOfferError('offer_not_pending', accept: false),
        NoticeCopy.offerNoLongerAvailable,
      );
      expect(
        NoticeCopy.forOfferError(null, accept: true),
        NoticeCopy.offerAcceptFailed,
      );
      expect(
        NoticeCopy.forOfferError(null, accept: false),
        NoticeCopy.offerDeclineFailed,
      );
    });

    test('maps direct-request error codes', () {
      expect(
        NoticeCopy.forRequestError('tradie_already_declined'),
        'This tradie already declined — pick another.',
      );
      expect(
        NoticeCopy.forRequestError('pending_request_exists'),
        'You already have a pending request for this job.',
      );
      expect(
        NoticeCopy.forRequestError('tradie_unreachable'),
        'That tradie just went offline — pick another.',
      );
    });
  });

  group('P1 MatchingProgressNotifier', () {
    test('handles withdrawn and superseded events', () {
      final notifier = MatchingProgressNotifier('42');
      notifier.applyOfferEvent(
        const OfferLifecycleEvent(
          eventType: OfferEventType.withdrawn,
          jobId: '42',
          offerId: '1',
          tradieId: 't1',
        ),
      );
      expect(notifier.state.offersMade, 1);

      notifier.applyOfferEvent(
        const OfferLifecycleEvent(
          eventType: OfferEventType.superseded,
          jobId: '42',
          offerId: '2',
          tradieId: 't2',
        ),
      );
      expect(notifier.state.phase, MatchingPhase.matched);
    });
  });

  group('P1 ThRequestSentScreen', () {
    testWidgets('shows Withdraw request label for live offer', (tester) async {
      final now = DateTime.now().toUtc();
      final offer = JobOffer(
        id: '10',
        jobId: '42',
        tradieId: 't1',
        tradieName: 'Sam',
        offeredAtUtc: now,
        expiresAtUtc: now.add(const Duration(minutes: 10)),
        response: 'Pending',
        stage: 'Direct',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ThRequestSentScreen(
            requestChecked: true,
            reconnecting: false,
            request: offer,
            gstLabel: null,
            onPickSomeoneElse: () {},
            onCancelRequest: () {},
            onExpired: () {},
          ),
        ),
      );
      expect(find.text('Withdraw request'), findsOneWidget);
      expect(find.byKey(const Key('cancel_request_button')), findsOneWidget);
    });
  });
}
