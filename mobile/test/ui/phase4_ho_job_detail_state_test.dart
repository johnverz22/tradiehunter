import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/homeowner/ho_job_detail_state.dart';
import 'package:fixo/ui/homeowner/ho_job_status.dart';

Job _job(String status, {String? disputeStatus}) => Job(
  id: 'job-1',
  title: 'Repair',
  category: 'Plumbing',
  suburb: 'Auckland',
  status: status,
  stage: Job.stageForStatus(status),
  disputeStatus: disputeStatus,
);

void main() {
  group('HoJobStatus', () {
    test('unknown values have a safe presentation', () {
      expect(HoJobStatus.forStatus(null).label, 'Status unavailable');
      expect(HoJobStatus.forStatus('FutureStatus').stage, isNull);
    });
  });

  group('job detail selector', () {
    test('maps designed states and falls back for every other status', () {
      final expected = <String, HoJobDetailView>{
        'Booked': HoJobDetailView.booked,
        'InProgress': HoJobDetailView.inProgress,
        'AwaitingConfirmation': HoJobDetailView.reviewCompletion,
        'Completed': HoJobDetailView.review,
        'Requested': HoJobDetailView.fallback,
        'AwaitingPayment': HoJobDetailView.fallback,
        'PaymentReview': HoJobDetailView.fallback,
        'Cancelled': HoJobDetailView.fallback,
        'Expired': HoJobDetailView.fallback,
        'Disputed': HoJobDetailView.fallback,
        'Draft': HoJobDetailView.fallback,
        'Matching': HoJobDetailView.fallback,
        'FutureStatus': HoJobDetailView.fallback,
      };
      for (final entry in expected.entries) {
        final selection = thSelectJobDetailView(
          _job(entry.key),
          adjustments: const [],
          hasReview: false,
          hasTradie: false,
        );
        expect(selection.view, entry.value, reason: entry.key);
      }
    });

    test(
      'pending adjustments select the adjustment layout in active states',
      () {
        final adjustment = JobAdjustment(
          id: 'adj-1',
          jobId: 'job-1',
          proposedByTradieId: 'tradie-1',
          proposedByTradieName: 'Tradie',
          kind: JobAdjustment.kindMaterials,
          description: 'Parts',
          amount: Decimal.parse('12.00'),
          status: JobAdjustment.statusPending,
          createdAtUtc: DateTime.utc(2026),
        );
        expect(
          thSelectJobDetailView(
            _job('InProgress'),
            adjustments: [adjustment],
            hasReview: false,
            hasTradie: true,
          ).view,
          HoJobDetailView.extraCost,
        );
        expect(
          thSelectJobDetailView(
            _job('Booked'),
            adjustments: [adjustment],
            hasReview: false,
            hasTradie: true,
          ).view,
          HoJobDetailView.extraCost,
        );
      },
    );

    test('terminal states outrank disputes; active dispute outranks routine states', () {
      expect(
        thSelectJobDetailView(
          _job('Completed', disputeStatus: 'Open'),
          adjustments: const [],
          hasReview: false,
          hasTradie: false,
        ).view,
        HoJobDetailView.review,
      );
      expect(
        thSelectJobDetailView(
          _job('Booked', disputeStatus: 'UnderReview'),
          adjustments: const [],
          hasReview: false,
          hasTradie: false,
        ).fallback,
        HoJobDetailFallback.dispute,
      );
      expect(
        thSelectJobDetailView(
          _job('Cancelled', disputeStatus: 'Open'),
          adjustments: const [],
          hasReview: false,
          hasTradie: false,
        ).fallback,
        HoJobDetailFallback.cancelled,
      );
    });
  });
}
