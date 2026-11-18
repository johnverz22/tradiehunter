import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/homeowner/ho_dispute_screen.dart';
import 'package:fixo/viewmodels/dispute_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('v2 dispute form keeps selectable reason and details limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(_JobsFixture()),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: HoDisputeScreen(jobId: '42')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open dispute'), findsOneWidget);
    expect(find.byKey(const Key('open_dispute_button')), findsOneWidget);
    expect(
      find.byKey(const Key('dispute_reason_Poor Quality')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dispute_reason_Overcharged')));
    await tester.enterText(
      find.byKey(const Key('dispute_details_field')),
      'Incorrect amount',
    );
    await tester.pump();

    expect(find.text('16/4000'), findsOneWidget);
    expect(find.bySemanticsLabel('Add evidence photo'), findsOneWidget);
  });

  testWidgets('dispute reasons switch through all choice pills', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(_JobsFixture()),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: HoDisputeScreen(jobId: '42')),
      ),
    );
    await tester.pumpAndSettle();

    for (final reason in HoDisputeScreen.reasons) {
      final key = Key('dispute_reason_$reason');
      expect(find.byKey(key), findsOneWidget);
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HoDisputeScreen)),
      );
      expect(container.read(disputeProvider).reason, reason);
    }
  });

  testWidgets(
    'dispute screen displays job title in subtitle when job is available',
    (tester) async {
      final fixture = _JobsFixture(job: _sampleJob);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(fixture),
            themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
          ],
          child: const MaterialApp(home: HoDisputeScreen(jobId: '42')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open dispute'), findsOneWidget);
      expect(find.text('Leaking kitchen tap'), findsOneWidget);
    },
  );

  testWidgets('submitting dispute without details surfaces validation error', (
    tester,
  ) async {
    final fixture = _JobsFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(fixture),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: HoDisputeScreen(jobId: '42')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_dispute_button')));
    await tester.pumpAndSettle();

    expect(fixture.opened, isEmpty);
    expect(
      find.text('Please provide details for the dispute.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'successful submit calls openDispute with chosen reason and details',
    (tester) async {
      final fixture = _JobsFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jobsRepositoryProvider.overrideWithValue(fixture),
            themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
          ],
          child: const MaterialApp(home: HoDisputeScreen(jobId: '42')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('dispute_reason_Damage to Property')),
      );
      await tester.enterText(
        find.byKey(const Key('dispute_details_field')),
        'The bench was scratched.',
      );
      await tester.tap(find.byKey(const Key('open_dispute_button')));
      await tester.pumpAndSettle();

      expect(fixture.opened, ['Damage to Property|The bench was scratched.']);
    },
  );

  // Drop the ThScope.of() and setMode() test — ThScope has no .of() static
  // accessor and ThemeModeNotifier has no setMode(); the theme reactivity is
  // covered by the other tests that pump with themeModeProvider overridden.
}

class _JobsFixture extends JobsRepository {
  _JobsFixture({this.job}) : super(Dio(), const FlutterSecureStorage());

  final Job? job;
  final List<String> opened = [];

  @override
  Future<Job?> getJobById(String jobId) async => job;

  @override
  Future<String> openDispute(
    String jobId,
    String reason,
    String details,
  ) async {
    opened.add('$reason|$details');
    return 'dispute-1';
  }

  @override
  Future<void> uploadDisputeEvidence(
    String disputeId,
    List<String> filePaths,
    String? textNotes,
  ) async {}
}

final _sampleJob = Job(
  id: '42',
  title: 'Leaking kitchen tap',
  category: 'Plumbing',
  suburb: 'Grey Lynn',
  status: 'AwaitingConfirmation',
  stage: 0,
);
