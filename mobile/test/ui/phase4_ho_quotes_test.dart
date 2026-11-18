import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/homeowner/ho_quotes_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _pump({required JobsRepository repo, String jobId = 'job-1'}) =>
    ProviderScope(
      overrides: [
        jobsRepositoryProvider.overrideWithValue(repo),
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
      ],
      child: MaterialApp(home: HoQuotesScreen(jobId: jobId)),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('quotes render server pricing, scope and acceptance action', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(repo: _JobsFixture()));
    await tester.pumpAndSettle();

    expect(find.text('Bay Builders'), findsOneWidget);
    expect(find.text(r'$18,400.00'), findsOneWidget);
    expect(find.text('Incl. GST'), findsOneWidget);
    expect(find.text('Cabinetry and benchtop replacement'), findsOneWidget);
    expect(find.byKey(const Key('accept_quote_quote-1')), findsOneWidget);
    expect(
      find.text('Pay only when the job is done and you approve the total.'),
      findsOneWidget,
    );
  });

  testWidgets('subtitle includes job title when getJobById succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(repo: _JobsFixture()));
    await tester.pumpAndSettle();

    // "Kitchen renovation · 1 received" — title from getJobById + count.
    expect(find.text('Kitchen renovation · 1 received'), findsOneWidget);
  });

  testWidgets(
    'subtitle falls back to count-only when getJobById returns null',
    (tester) async {
      await tester.pumpWidget(_pump(repo: _NoTitleFixture()));
      await tester.pumpAndSettle();

      expect(find.text('1 received'), findsOneWidget);
      // Must NOT show a "null ·" prefix.
      expect(find.textContaining('null'), findsNothing);
    },
  );

  testWidgets(
    'written-contract gate: Confirm & accept is disabled until checkbox is ticked',
    (tester) async {
      final repo = _ContractRequiredFixture();
      await tester.pumpWidget(_pump(repo: repo));
      await tester.pumpAndSettle();

      // Tap Accept on the quote that will return requiresWrittenContract.
      await tester.tap(find.byKey(const Key('accept_quote_quote-1')));
      await tester.pumpAndSettle();

      // The contract sheet should now be visible.
      expect(find.text('Written contract required'), findsOneWidget);

      // Confirm & accept must be disabled until the checkbox is ticked.
      final confirmButton = find.byKey(const Key('contract_confirm_button'));
      expect(confirmButton, findsOneWidget);

      // The THButton is disabled (onPressed == null) so a tap does nothing.
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      // Sheet is still open (dismiss not received).
      expect(find.text('Written contract required'), findsOneWidget);

      // Tick the checkbox.
      await tester.tap(find.byKey(const Key('written_contract_checkbox')));
      await tester.pumpAndSettle();

      // Now Confirm & accept should be enabled.
      // We won't navigate (repo returns failure after confirm) but the button
      // must be tappable, i.e. not throw.
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
    },
  );
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _baseQuote = Quote(
  id: 'quote-1',
  jobId: 'job-1',
  tradieId: 'tradie-1',
  tradieName: 'Bay Builders',
  businessName: 'Bay Builders',
  initials: 'BB',
  verified: true,
  rating: 4.9,
  reviewCount: 6,
  pricingModel: Quote.pricingFixed,
  amount: Decimal.fromInt(18400),
  inclusions: 'Cabinetry and benchtop replacement',
  materialsIncluded: true,
  gstIncluded: true,
);

final _baseJob = Job(
  id: 'job-1',
  title: 'Kitchen renovation',
  category: 'Plumbing',
  suburb: 'Grey Lynn',
  status: 'Requested',
  stage: 0, // Requested
  jobType: Job.jobTypeProject,
);

class _JobsFixture extends JobsRepository {
  _JobsFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<Quote>> getQuotes(String jobId) async => [_baseQuote];

  @override
  Future<Job?> getJobById(String jobId) async => _baseJob;
}

/// Simulates a slow or failed job fetch so the subtitle degrades gracefully.
class _NoTitleFixture extends JobsRepository {
  _NoTitleFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<Quote>> getQuotes(String jobId) async => [_baseQuote];

  @override
  Future<Job?> getJobById(String jobId) async => null;
}

/// Returns requiresWrittenContract on the first acceptQuote call.
class _ContractRequiredFixture extends JobsRepository {
  _ContractRequiredFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<Quote>> getQuotes(String jobId) async => [_baseQuote];

  @override
  Future<Job?> getJobById(String jobId) async => _baseJob;

  @override
  Future<QuoteAcceptResult> acceptQuote(
    String jobId,
    String quoteId, {
    bool confirmWrittenContract = false,
  }) async {
    if (!confirmWrittenContract) {
      return const QuoteAcceptResult.needsWrittenContract(
        message: 'A written contract is legally required for jobs at or above the statutory threshold.',
      );
    }
    // After confirmation, simulate a network failure — the UI shows an error
    // notice but doesn't crash.
    return const QuoteAcceptResult.failure('Could not accept the quote.');
  }
}
