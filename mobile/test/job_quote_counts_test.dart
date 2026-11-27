import 'package:fixo/models/marketplace.dart';
import 'package:flutter_test/flutter_test.dart';

// Plan 10 (Q2.1/Q2.2): quote progress on Job and the Quote status wire value.

Map<String, dynamic> _json({
  String jobType = 'Project',
  String status = 'Requested',
  Map<String, dynamic> extra = const {},
}) => {
  'id': 7,
  'title': 'Kitchen renovation',
  'category': 'Plumbing',
  'status': status,
  'jobType': jobType,
  ...extra,
};

void main() {
  test('quote counts are null when the server does not send them', () {
    final job = Job.fromJson(_json());
    expect(job.quotesRequested, isNull);
    expect(job.quotesReceived, isNull);
    expect(job.hasQuoteActivity, isFalse);
  });

  test('quote counts parse from ints (and doubles from lenient JSON)', () {
    final job = Job.fromJson(
      _json(extra: {'quotesRequested': 3, 'quotesReceived': 2.0}),
    );
    expect(job.quotesRequested, 3);
    expect(job.quotesReceived, 2);
    expect(job.hasQuoteActivity, isTrue);
  });

  test('hasQuoteActivity needs a Requested project with a request sent', () {
    bool activity(String type, String status, int? requested) =>
        Job.fromJson(
          _json(
            jobType: type,
            status: status,
            extra: {'quotesRequested': ?requested},
          ),
        ).hasQuoteActivity;

    expect(activity('Project', 'Requested', 1), isTrue);
    expect(activity('Project', 'Requested', 0), isFalse);
    expect(activity('Hourly', 'Requested', 3), isFalse);
    expect(activity('Project', 'Booked', 3), isFalse);
  });

  test('copyWith keeps quote counts', () {
    final job = Job.fromJson(
      _json(extra: {'quotesRequested': 3, 'quotesReceived': 1}),
    ).copyWith(status: 'Requested');
    expect(job.quotesRequested, 3);
    expect(job.quotesReceived, 1);
  });

  test('Quote.isOpen accepts the wire value and the legacy fixture value', () {
    Quote q(String status) => Quote(
      id: '1',
      jobId: '7',
      tradieId: 't',
      tradieName: 'Bay Builders',
      initials: 'BB',
      pricingModel: Quote.pricingFixed,
      status: status,
    );
    expect(Quote.statusPending, 'Submitted');
    expect(q('Submitted').isOpen, isTrue);
    expect(q('Pending').isOpen, isTrue);
    expect(q(Quote.statusAccepted).isOpen, isFalse);
    expect(q(Quote.statusDeclined).isOpen, isFalse);
    expect(q(Quote.statusWithdrawn).isOpen, isFalse);
    expect(q(Quote.statusExpired).isOpen, isFalse);
  });

  test('openToBoard and quotesCloseAtUtc parse and drive hasQuoteActivity', () {
    final closeAt = DateTime.utc(2026, 11, 30, 12);
    final openJob = Job.fromJson(
      _json(
        extra: {
          'openToBoard': true,
          'quotesCloseAtUtc': closeAt.toIso8601String(),
          'quotesReceived': 2,
        },
      ),
    );
    expect(openJob.openToBoard, isTrue);
    expect(openJob.quotesCloseAtUtc, closeAt);
    expect(openJob.quotesRequested, isNull);
    expect(openJob.quotesReceived, 2);
    expect(openJob.hasQuoteActivity, isTrue);
    expect(openJob.copyWith(status: 'Requested').openToBoard, isTrue);
    expect(openJob.copyWith(status: 'Requested').quotesCloseAtUtc, closeAt);
  });
}
