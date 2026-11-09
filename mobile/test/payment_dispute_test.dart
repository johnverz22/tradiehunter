// V15-18: manual payment instructions/status and dispute form.
//
// Truthfulness gates covered here:
// - the breakdown shows only what the server charges (hours × rate when the
//   job supplies them, never an invented line);
// - sentinel/missing bank details block transfer guidance;
// - "receipt sent" is never presented as "payment verified";
// - dispute limits mirror the server (4,000-char text evidence, 5 photos);
// - server error messages reach the user verbatim;
// - no escrow/protected-funds/surcharge/SLA copy anywhere.

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/models/payment.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/payments_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/dispute_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/viewmodels/payment_viewmodel.dart';
import 'package:fixo/views/jobs/dispute_screen.dart';
import 'package:fixo/views/payment/payment_screen.dart';
import 'package:fixo/views/payment/payment_status_screen.dart';
import 'package:fixo/widgets/fixo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'payment_test.dart' show payload;

class _PaymentsFixture extends PaymentsRepository {
  final Map<String, dynamic> _payload;
  _PaymentsFixture(this._payload) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<PaymentStatus> getPayment(String jobId) async =>
      PaymentStatus.fromJson(_payload);
}

class _JobsFixture extends JobsRepository {
  final Job? job;
  final String? disputeError;
  final List<String> opened = [];

  _JobsFixture({this.job, this.disputeError})
    : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Job?> getJobById(String jobId) async => job;

  @override
  Future<String> openDispute(
    String jobId,
    String reason,
    String details,
  ) async {
    opened.add('$reason|$details');
    if (disputeError != null) throw ProfileApiException(disputeError!);
    return '77';
  }

  @override
  Future<void> uploadDisputeEvidence(
    String disputeId,
    List<String> filePaths,
    String? textNotes,
  ) async {}
}

Job _job({int hours = 3, String rate = '57.00', String total = '171.00'}) =>
    Job(
      id: '42',
      title: 'Leaking kitchen tap',
      category: 'Plumbing',
      suburb: 'Grey Lynn',
      status: 'AwaitingPayment',
      stage: 1,
      hours: hours,
      hourlyRate: rate == '' ? null : Decimal.parse(rate),
      totalAmount: Decimal.parse(total),
    );

Widget _wrap(Widget child, List<Override> overrides, {bool dark = false}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: dark ? FixoTheme.dark() : FixoTheme.light(),
        home: child,
      ),
    );

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('PaymentScreen instructions', () {
    for (final dark in [false, true]) {
      testWidgets('numbered steps + breakdown render, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _wrap(const PaymentScreen(jobId: '42'), [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentsFixture(
                payload(
                  bankDetails: {
                    'accountName': 'Fixo Ltd',
                    'accountNumber': '12-3456-7890123-00',
                  },
                ),
              ),
            ),
            jobsRepositoryProvider.overrideWithValue(_JobsFixture(job: _job())),
            localeConfigProvider.overrideWith((ref) async => null),
          ], dark: dark),
        );
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Copy the payment reference'));
        expect(find.text('Copy the payment reference'), findsOneWidget);
        await _scrollTo(tester, find.textContaining('Transfer 171.00'));
        expect(find.textContaining('Transfer 171.00 NZD'), findsOneWidget);
        await _scrollTo(tester, find.text('Upload your bank receipt'));
        expect(find.text('Upload your bank receipt'), findsOneWidget);

        // Authoritative breakdown: hours × rate from the job, total from the
        // payment — no invented fee lines.
        await _scrollTo(tester, find.text('Labour'));
        expect(find.text('Labour'), findsOneWidget);
        expect(find.text('3 hours × 57.00 NZD/h'), findsOneWidget);
        expect(find.text('Job total'), findsOneWidget);
        expect(find.text('171.00 NZD'), findsWidgets);

        // Factual review copy; no escrow/protection/SLA claims.
        expect(find.textContaining('our team can review'), findsWidgets);
        expect(find.textContaining('escrow'), findsNothing);
        expect(find.textContaining('protected'), findsNothing);
        expect(find.textContaining('surcharge'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('breakdown drops labour line when job has no hours', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(const PaymentScreen(jobId: '42'), [
          paymentsRepositoryProvider.overrideWithValue(
            _PaymentsFixture(
              payload(
                bankDetails: {
                  'accountName': 'Fixo Ltd',
                  'accountNumber': '12-3456-7890123-00',
                },
              ),
            ),
          ),
          jobsRepositoryProvider.overrideWithValue(
            _JobsFixture(job: _job(hours: 0)),
          ),
          localeConfigProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Job total'));
      expect(find.text('Labour'), findsNothing);
      expect(find.text('Job total'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing bank details block transfer steps but keep total', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(const PaymentScreen(jobId: '42'), [
          paymentsRepositoryProvider.overrideWithValue(
            _PaymentsFixture({...payload(), 'bankDetails': null}),
          ),
          jobsRepositoryProvider.overrideWithValue(_JobsFixture(job: _job())),
          localeConfigProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Refresh payment details'));
      expect(find.text('Copy the payment reference'), findsNothing);
      expect(find.textContaining('Transfer'), findsNothing);
      expect(find.text('Refresh payment details'), findsOneWidget);
      expect(find.text('Job total'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('copy reference writes clipboard', (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _wrap(const PaymentScreen(jobId: '42'), [
          paymentsRepositoryProvider.overrideWithValue(
            _PaymentsFixture(
              payload(
                bankDetails: {
                  'accountName': 'Fixo Ltd',
                  'accountNumber': '12-3456-7890123-00',
                },
              ),
            ),
          ),
          jobsRepositoryProvider.overrideWithValue(_JobsFixture(job: _job())),
          localeConfigProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Copy').first);
      await tester.tap(find.text('Copy').first);
      await tester.pumpAndSettle();
      expect(copied, 'FIXO-42');
      expect(tester.takeException(), isNull);
    });
  });

  group('PaymentStatusScreen', () {
    Widget mountStatus(Map<String, dynamic> p, {bool dark = false}) =>
        _wrap(const PaymentStatusScreen(jobId: '42'), [
          paymentsRepositoryProvider.overrideWithValue(_PaymentsFixture(p)),
          jobsRepositoryProvider.overrideWithValue(_JobsFixture(job: _job())),
          localeConfigProvider.overrideWith((ref) async => null),
        ], dark: dark);

    for (final dark in [false, true]) {
      testWidgets('submitted shows review timeline, not verified, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          mountStatus({
            ...payload(status: 'Submitted', canUploadReceipt: false),
            'submittedAtUtc': '2026-10-01T09:30:00Z',
          }, dark: dark),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.text('Review progress'));
        expect(find.text('Under review'), findsOneWidget);
        expect(find.text('Receipt sent'), findsWidgets);
        expect(find.text('Staff review'), findsOneWidget);
        expect(find.text('Receipt summary'), findsOneWidget);
        expect(find.byKey(const Key('back_to_job_button')), findsOneWidget);
        // Nothing claims the money already arrived.
        expect(find.text('Paid'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('verified shows distinct confirmed state', (tester) async {
      tester.view.physicalSize = const Size(320, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        mountStatus({
          ...payload(status: 'Verified', canUploadReceipt: false),
          'submittedAtUtc': '2026-10-01T09:30:00Z',
          'verifiedAtUtc': '2026-10-01T15:00:00Z',
          'bankDetails': null,
        }),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Verified'));
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Payment verified'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejected shows reason, send-back count and re-upload', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        mountStatus(
          payload(
            status: 'Rejected',
            rejectReason: 'The amount on the slip does not match.',
            reUploadCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('We need a different receipt'));
      expect(
        find.text('The amount on the slip does not match.'),
        findsOneWidget,
      );
      expect(find.text('Sent back'), findsOneWidget);
      expect(find.text('2 times'), findsOneWidget);
      expect(find.byKey(const Key('reupload_receipt_button')), findsOneWidget);
      expect(find.text('Back to job'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back to job navigates to job detail', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PaymentStatusScreen(jobId: '42'),
          ),
          GoRoute(
            path: '/jobs/:id/detail',
            builder: (context, state) =>
                const Scaffold(body: Text('JOB DETAIL MARKER')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentsRepositoryProvider.overrideWithValue(
              _PaymentsFixture(
                payload(status: 'Verified', canUploadReceipt: false)
                  ..['bankDetails'] = null,
              ),
            ),
            jobsRepositoryProvider.overrideWithValue(_JobsFixture(job: _job())),
            localeConfigProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            theme: FixoTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('back_to_job_button')));
      await tester.pumpAndSettle();
      expect(find.text('JOB DETAIL MARKER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DisputeScreen', () {
    Widget mountDispute(_JobsFixture jobs, {bool dark = false}) => _wrap(
      const DisputeScreen(jobId: '42'),
      [jobsRepositoryProvider.overrideWithValue(jobs)],
      dark: dark,
    );

    for (final dark in [false, true]) {
      testWidgets('reason picker, limits and next steps, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(mountDispute(_JobsFixture(), dark: dark));
        await tester.pumpAndSettle();

        // Standard header.
        expect(find.byType(FixoAppBar), findsOneWidget);
        expect(find.text('Open dispute'), findsOneWidget);

        // Radio picker is bound to state.
        await tester.tap(find.text('Overcharged'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DisputeScreen)),
        );
        expect(container.read(disputeProvider).reason, 'Overcharged');

        // Server-mirrored limits: 4,000-char text evidence, 5 photos.
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('dispute_details_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.maxLength, 4000);
        expect(find.text('Up to 5 photos.'), findsOneWidget);

        // Factual review next steps — no SLA or outcome promises.
        await _scrollTo(tester, find.textContaining('reviews the dispute'));
        expect(
          find.textContaining('A member of our team reviews the dispute'),
          findsOneWidget,
        );
        expect(find.textContaining('within'), findsNothing);
        expect(find.textContaining('escrow'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('submit sends reason and details to the open-dispute call', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final jobs = _JobsFixture();
      final router = GoRouter(
        initialLocation: '/dispute',
        routes: [
          GoRoute(
            path: '/dispute',
            builder: (context, state) => const DisputeScreen(jobId: '42'),
          ),
          GoRoute(
            path: '/jobs/:id/detail',
            builder: (context, state) =>
                const Scaffold(body: Text('JOB DETAIL MARKER')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jobsRepositoryProvider.overrideWithValue(jobs)],
          child: MaterialApp.router(
            theme: FixoTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Damage to Property'));
      await tester.enterText(
        find.byKey(const Key('dispute_details_field')),
        'The bench top was scratched while removing the vanity.',
      );
      await tester.tap(find.byKey(const Key('open_dispute_button')));
      await tester.pumpAndSettle();
      expect(jobs.opened, [
        'Damage to Property|The bench top was scratched while removing the vanity.',
      ]);
      // Success navigates back to the job.
      expect(find.text('JOB DETAIL MARKER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('server error message is surfaced verbatim', (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final jobs = _JobsFixture(
        disputeError: 'A dispute is already open for this job.',
      );
      await tester.pumpWidget(mountDispute(jobs));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('dispute_details_field')),
        'Details go here.',
      );
      await tester.tap(find.byKey(const Key('open_dispute_button')));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.text('A dispute is already open for this job.'),
      );
      expect(
        find.text('A dispute is already open for this job.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('blank details block submit before the API is called', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final jobs = _JobsFixture();
      await tester.pumpWidget(mountDispute(jobs));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dispute_button')));
      await tester.pumpAndSettle();
      expect(jobs.opened, isEmpty);
      expect(
        find.text('Please provide details for the dispute.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
