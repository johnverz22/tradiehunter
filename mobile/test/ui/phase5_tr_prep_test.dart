// Phase 5.0 (tradie sub-plan): shared logic extracted out of v1 view files.
//
// The v2 copies in lib/ui/tradie must behave exactly like the v1 originals
// until Phase 6 deletes v1, so every rule is compared against the v1 symbol
// (test code may import v1; lib/ui may not).
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/tradie/tr_home_mapper.dart';
import 'package:fixo/ui/tradie/tr_job_status.dart';
import 'package:fixo/ui/tradie/tr_jobs_mapper.dart';
import 'package:fixo/views/jobs/jobs_list_screen.dart' as v1_jobs;
import 'package:fixo/views/tradie/tradie_dashboard_view.dart' as v1_dash;
import 'package:fixo/views/widgets/job_status_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

Job _job(String id, String status, {DateTime? scheduledLocal}) => Job(
  id: id,
  title: 'Job $id',
  category: 'Plumbing',
  suburb: 'Ponsonby',
  status: status,
  stage: Job.stageForStatus(status, flowVersion: Job.flowVersionV2),
  flowVersion: Job.flowVersionV2,
  scheduledStartUtc: scheduledLocal?.toUtc(),
);

void main() {
  final now = DateTime(2026, 11, 25, 12);

  group('thIsScheduledOnOrBeforeToday matches v1', () {
    final cases = <String, DateTime?>{
      'unscheduled': null,
      'yesterday': DateTime(2026, 11, 24, 9),
      'earlier today': DateTime(2026, 11, 25, 0, 1),
      'late tonight': DateTime(2026, 11, 25, 23, 59),
      'midnight tomorrow': DateTime(2026, 11, 26),
      'next week': DateTime(2026, 12, 2, 9),
    };
    cases.forEach((name, when) {
      test(name, () {
        final job = _job('a', 'Booked', scheduledLocal: when);
        expect(
          thIsScheduledOnOrBeforeToday(job, now),
          v1_dash.isScheduledOnOrBeforeToday(job, now),
        );
      });
    });
  });

  group('dashboard status sets are pinned to the v1 values', () {
    test('booked work statuses', () {
      expect(kBookedWorkStatuses, {
        'Booked',
        'InProgress',
        'AwaitingConfirmation',
      });
      expect(kTradieWorkStatuses, kBookedWorkStatuses);
    });
    test('awaiting payment statuses', () {
      expect(kAwaitingPaymentStatuses, {'AwaitingPayment', 'PaymentReview'});
      expect(kTradieAwaitingPaymentStatuses, kAwaitingPaymentStatuses);
    });
  });

  group('trDayGroups matches v1 tradieDayGroups', () {
    final jobs = [
      _job('1', 'Booked', scheduledLocal: DateTime(2026, 11, 25, 15)),
      _job('2', 'Booked', scheduledLocal: DateTime(2026, 11, 25, 8)),
      _job('3', 'Booked', scheduledLocal: DateTime(2026, 11, 26, 9)),
      _job('4', 'Completed', scheduledLocal: DateTime(2026, 11, 24, 9)),
      _job('5', 'Booked', scheduledLocal: DateTime(2026, 12, 3, 9)),
      _job('6', 'Booked'),
    ];
    for (final newestFirst in [true, false]) {
      test('newestFirst=$newestFirst', () {
        final v1 = v1_jobs.tradieDayGroups(jobs, now, newestFirst: newestFirst);
        final v2 = trDayGroups(jobs, now, newestFirst: newestFirst);
        expect(v2.map((g) => g.label), v1.map((g) => g.label));
        expect(
          v2.map((g) => g.jobs.map((j) => j.id).toList()),
          v1.map((g) => g.jobs.map((j) => j.id).toList()),
        );
      });
    }
    test('labels and trailing Unscheduled group', () {
      final labels = trDayGroups(
        jobs,
        now,
        newestFirst: false,
      ).map((g) => g.label).toList();
      expect(labels.take(3), ['Yesterday', 'Today', 'Tomorrow']);
      expect(labels.last, 'Unscheduled');
    });
    test('empty input yields no groups', () {
      expect(trDayGroups(const [], now, newestFirst: true), isEmpty);
    });
  });

  group('TrJobStatus parity with JobStatusPresentation', () {
    for (final status in TrJobStatus.knownStatuses) {
      test(status, () {
        final v1 = JobStatusPresentation.forStatus(status);
        final v2 = TrJobStatus.forStatus(status);
        expect(v2.label, v1.label);
        expect(v2.tradieAction, v1.tradieAction);
        expect(v2.tradieActionRequired, v1.tradieActionRequired);
        expect(v2.tradieDashboardAction, v1.tradieDashboardAction);
      });
    }
    test('unknown status is total and never action-required', () {
      final v1 = JobStatusPresentation.forStatus('Mystery');
      final v2 = TrJobStatus.forStatus('Mystery');
      expect(v2.label, v1.label);
      expect(v2.tradieActionRequired, isFalse);
      expect(v2.tradieAction, v1.tradieAction);
    });
    test('covers every status the v1 table knows', () {
      for (final s in const [
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
        expect(TrJobStatus.knownStatuses, contains(s));
      }
    });
  });
}
