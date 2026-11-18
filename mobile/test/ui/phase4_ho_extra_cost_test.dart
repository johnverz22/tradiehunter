import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/homeowner/ho_extra_cost_screen.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'InProgress without a pending adjustment shows job guidance only',
    (tester) async {
      await tester.pumpWidget(
        _app(HoExtraCostScreen(job: _job, adjustment: null, tradie: _tradie)),
      );

      expect(find.text('Work is under way'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(
        find.text('Nothing is billed until you approve it.'),
        findsNothing,
      );
      expect(find.text('Extra cost request'), findsNothing);
      expect(find.text('Message tradie'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Insured'), findsNothing);
    },
  );

  testWidgets('pending extra is itemised and requires a decision sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(HoExtraCostScreen(job: _job, adjustment: _adjustment, tradie: null)),
    );

    expect(find.text('Extra cost request'), findsOneWidget);
    expect(find.text(r'$48.50'), findsOneWidget);
    expect(find.text('Replacement tap cartridge.'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Extra cost request'), findsNWidgets(2));
    expect(find.text('Approve this extra cost'), findsOneWidget);
    expect(find.text('Decline this extra cost'), findsNothing);
    expect(find.text('Estimate before this request'), findsOneWidget);
  });

  testWidgets('Booked jobs keep booked status while showing a pending extra', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        HoExtraCostScreen(
          job: _bookedJob,
          adjustment: _adjustment,
          tradie: null,
        ),
      ),
    );

    expect(find.text('Review an extra cost'), findsOneWidget);
    expect(find.text('Your tradie is booked for this job.'), findsOneWidget);
    expect(find.text('Extra cost request'), findsOneWidget);
  });

  testWidgets('pending adjustment header fits at 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: HoExtraCostScreen(
            job: _job,
            adjustment: _adjustmentWithExpiry,
            tradie: null,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Extra cost request'), findsOneWidget);
  });

  testWidgets('pending adjustment decision sheet uses the dark v2 theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.index,
    });
    await tester.pumpWidget(
      _app(HoExtraCostScreen(job: _job, adjustment: _adjustment, tradie: null)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    final sheetText = tester.element(find.text('Approve this extra cost'));
    expect(Theme.of(sheetText).brightness, Brightness.dark);
  });
}

Widget _app(Widget child) => ProviderScope(
  overrides: [themeModeProvider.overrideWith((ref) => ThemeModeNotifier())],
  child: MaterialApp(home: child),
);

final _job = Job(
  id: 'job-1',
  title: 'Leaking kitchen tap',
  category: 'Plumbing',
  suburb: 'Tauranga',
  status: 'InProgress',
  stage: 2,
  address: '14 Marine Parade',
  hours: 2,
  hourlyRate: Decimal.fromInt(85),
  estimatedTotal: Decimal.fromInt(170),
  description: 'Drips constantly.',
);

final _adjustment = JobAdjustment(
  id: 'adjustment-1',
  jobId: 'job-1',
  proposedByTradieId: 'tradie-1',
  proposedByTradieName: 'Aroha Plumbing',
  kind: JobAdjustment.kindMaterials,
  description: 'Replacement tap cartridge.',
  amount: Decimal.parse('48.50'),
  status: JobAdjustment.statusPending,
  createdAtUtc: DateTime.utc(2026, 11, 17),
);

final _adjustmentWithExpiry = JobAdjustment(
  id: 'adjustment-1',
  jobId: 'job-1',
  proposedByTradieId: 'tradie-1',
  proposedByTradieName: 'Aroha Plumbing',
  kind: JobAdjustment.kindMaterials,
  description: 'Replacement tap cartridge.',
  amount: Decimal.parse('48.50'),
  status: JobAdjustment.statusPending,
  createdAtUtc: DateTime.utc(2026, 11, 17),
  expiresAtUtc: DateTime.utc(2026, 12, 1),
);

final _bookedJob = Job(
  id: 'job-1',
  title: 'Leaking kitchen tap',
  category: 'Plumbing',
  suburb: 'Tauranga',
  status: 'Booked',
  stage: 2,
  address: '14 Marine Parade',
  matchedTradieName: 'Aroha Plumbing',
);

const _tradie = UserProfile(
  id: 'tradie-1',
  firstName: 'Aroha',
  lastName: 'Plumbing',
  role: 'Tradie',
  averageRating: null,
  reviewCount: null,
  isVerified: true,
  hasInsurance: false,
);
