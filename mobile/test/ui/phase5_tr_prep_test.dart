// Phase 5.0 (tradie sub-plan): shared tradie logic in lib/ui/tradie.
//
// These started as v1-parity checks; Phase 6 deleted v1, so the v1 results are
// pinned as literals below.
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/tradie/tr_home_mapper.dart';
import 'package:fixo/ui/tradie/tr_job_status.dart';
import 'package:fixo/ui/tradie/tr_jobs_mapper.dart';
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

  group('thIsScheduledOnOrBeforeToday', () {
    final cases = <String, (DateTime?, bool)>{
      'unscheduled': (null, true),
      'yesterday': (DateTime(2026, 11, 24, 9), true),
      'earlier today': (DateTime(2026, 11, 25, 0, 1), true),
      'late tonight': (DateTime(2026, 11, 25, 23, 59), true),
      'midnight tomorrow': (DateTime(2026, 11, 26), false),
      'next week': (DateTime(2026, 12, 2, 9), false),
    };
    cases.forEach((name, c) {
      test(name, () {
        final job = _job('a', 'Booked', scheduledLocal: c.$1);
        expect(thIsScheduledOnOrBeforeToday(job, now), c.$2);
      });
    });
  });

  group('dashboard status sets are pinned', () {
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

  group('trDayGroups', () {
    final jobs = [
      _job('1', 'Booked', scheduledLocal: DateTime(2026, 11, 25, 15)),
      _job('2', 'Booked', scheduledLocal: DateTime(2026, 11, 25, 8)),
      _job('3', 'Booked', scheduledLocal: DateTime(2026, 11, 26, 9)),
      _job('4', 'Completed', scheduledLocal: DateTime(2026, 11, 24, 9)),
      _job('5', 'Booked', scheduledLocal: DateTime(2026, 12, 3, 9)),
      _job('6', 'Booked'),
    ];
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

  group('TrJobStatus', () {
    const expected = <String, (String, String, bool, String)>{
      // status: (label, tradieAction, actionRequired, dashboardAction)
      'Requested': ('Requested', 'View request', false, 'Open chat'),
      'AwaitingPayment': ('Payment due', 'View request', false, 'Open chat'),
      'PaymentReview': ('Under review', 'View request', false, 'Open chat'),
      'Booked': ('Booked', 'Check in', true, 'Open chat'),
      'InProgress': ('In progress', 'Check out', true, 'Open chat'),
      'AwaitingConfirmation': (
        'Action needed',
        'Mark complete',
        true,
        'Open chat',
      ),
      'Completed': (
        'Completed',
        'View job details',
        false,
        'View job details',
      ),
      'Cancelled': (
        'Cancelled',
        'View job details',
        false,
        'View job details',
      ),
      'Expired': ('Expired', 'View request', false, 'Open chat'),
      'Disputed': ('Disputed', 'View request', false, 'Open chat'),
    };
    expected.forEach((status, e) {
      test(status, () {
        final v = TrJobStatus.forStatus(status);
        expect(v.label, e.$1);
        expect(v.tradieAction, e.$2);
        expect(v.tradieActionRequired, e.$3);
        expect(v.tradieDashboardAction, e.$4);
      });
    });
    test('unknown status is total and never action-required', () {
      final v = TrJobStatus.forStatus('Mystery');
      expect(v.label, 'Status unavailable');
      expect(v.tradieActionRequired, isFalse);
      expect(v.tradieAction, 'View request');
    });
    test('covers every known status', () {
      expect(TrJobStatus.knownStatuses, containsAll(expected.keys));
    });
  });
}
