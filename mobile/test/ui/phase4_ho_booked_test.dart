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
    // Mockup ho_job_booked: no badges, no titled cards, no duplicate Message.
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Job details'), findsNothing);
    expect(find.text('Job timeline'), findsNothing);
    expect(
      find.text('Aroha Plumbing will check in on arrival.'),
      findsOneWidget,
    );
    expect(find.text('Estimate'), findsOneWidget);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('Request accepted'), findsOneWidget);
    expect(find.byKey(const Key('tradie_card_chat_button')), findsOneWidget);
    expect(find.byKey(const Key('cancellation_policy_tile')), findsNothing);
  });

  testWidgets('Booked action is the sticky bottom bar, not inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(HoBookedScreen(job: _job, tradie: _tradie, contact: null)),
    );
    final view = tester.getRect(find.byType(THScaffold));
    final message = tester.getRect(find.byKey(const Key('open_chat_button')));
    final cancel = tester.getRect(find.byKey(const Key('cancel_job_button')));
    expect(find.text('Message Aroha'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(THStickyBar),
        matching: find.byKey(const Key('open_chat_button')),
      ),
      findsOneWidget,
    );
    expect(message.bottom, lessThan(cancel.top));
    expect(cancel.bottom, lessThanOrEqualTo(view.bottom));
  });

  testWidgets('Booked cancellation action discloses fee and requires reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(HoBookedScreen(job: _job, tradie: null, contact: null)),
    );
    await tester.tap(find.byKey(const Key('cancel_job_button')));
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
