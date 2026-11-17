import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/homeowner/ho_job_detail_state.dart';
import 'package:fixo/ui/homeowner/ho_job_status.dart';
import 'package:fixo/views/widgets/job_status_presentation.dart';

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
  group('ThJobStatus parity', () {
    test('known status labels and stages match the v1 table', () {
      for (final status in <String>[
        'Requested',
        'AwaitingPayment',
        'PaymentReview',
        'Booked',
        'InProgress',
        'AwaitingConfirmation',
        'Completed',
        'Cancelled',
        'Expired',
        'Disputed',
      ]) {
        expect(
          HoJobStatus.forStatus(status).label,
          JobStatusPresentation.forStatus(status).label,
          reason: status,
        );
        expect(
          HoJobStatus.forStatus(status).stage,
          JobStatusPresentation.forStatus(status).progressStage,
          reason: status,
        );
      }
    });

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

    test('pending adjustment selects extra cost only for InProgress', () {
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
        HoJobDetailView.booked,
      );
    });

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
