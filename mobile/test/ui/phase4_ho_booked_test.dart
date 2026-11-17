import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/ui/homeowner/ho_booked_screen.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Booked detail renders scheduled data, progress, and contact', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(HoBookedScreen(job: _job, tradie: _tradie, contact: null)),
    );

    expect(find.text('Booked'), findsWidgets);
    expect(find.textContaining('Booked for'), findsOneWidget);
    expect(find.text('Aroha Plumbing'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Insured'), findsNothing);
    expect(find.text('Job timeline'), findsOneWidget);
    expect(find.byKey(const Key('open_chat_button')), findsOneWidget);
    expect(find.byKey(const Key('cancellation_policy_tile')), findsOneWidget);
  });

  testWidgets('Booked cancellation action discloses fee and requires reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(HoBookedScreen(job: _job, tradie: null, contact: null)),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel job'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cancelling a booked job incurs a 10% platform fee.'),
      findsOneWidget,
    );
    expect(find.text('Confirm cancellation'), findsOneWidget);
    final cancelButton = find.ancestor(
      of: find.text('Confirm cancellation'),
      matching: find.byType(THButton),
    );
    expect(tester.widget<THButton>(cancelButton).onPressed, isNull);
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
  status: 'Booked',
  stage: 2,
  address: '14 Marine Parade',
  matchedTradieId: 'tradie-1',
  matchedTradieName: 'Aroha Plumbing',
  scheduledStartUtc: DateTime.utc(2026, 11, 18, 21),
  hours: 2,
  timingPreference: 'SpecificDate',
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
