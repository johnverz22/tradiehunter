import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/ui/homeowner/ho_dispute_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';

void main() {
  testWidgets('v2 dispute form keeps selectable reason and details limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobsRepositoryProvider.overrideWithValue(_JobsFixture())],
        child: const MaterialApp(
          home: ThScope(child: HoDisputeScreen(jobId: '42')),
        ),
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
}

class _JobsFixture extends JobsRepository {
  _JobsFixture() : super(Dio(), const FlutterSecureStorage());
}
