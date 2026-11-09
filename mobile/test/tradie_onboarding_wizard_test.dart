// V15-19: regrouped tradie onboarding wizard (D7 sections: Where you work /
// Trades / Verification / Payout).
//
// Truthfulness and preservation gates covered here:
// - every previously required field still exists and still saves — the
//   regroup only moved fields between sections;
// - local validation errors return to the specific field that failed, and
//   editing a field clears its own message only;
// - profile fields are re-sent on every PUT so earlier answers are never
//   dropped by a later step;
// - the bank format gate and the rate range gate are unchanged;
// - money stays Decimal through the rate inputs.

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/tradie_onboarding.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/viewmodels/tradie_onboarding_viewmodel.dart';
import 'package:fixo/views/tradie/tradie_onboarding_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _ProfileRepo extends ProfileRepository {
  _ProfileRepo() : super(Dio(), const FlutterSecureStorage());

  int profilePuts = 0;
  Map<String, dynamic>? lastProfilePayload;
  int schedulePosts = 0;
  int ratesPosts = 0;
  List<TradieRateEntry>? lastRates;
  List<TradieScheduleSlot>? lastSchedule;

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'id': 't1',
    'role': 1,
  };

  @override
  Future<List<TradieService>> getServiceCatalog() async => const [
    TradieService(id: 1, name: 'Leak repair', category: 'Plumber'),
    TradieService(id: 2, name: 'Pipe install', category: 'Plumber'),
    TradieService(id: 3, name: 'Wiring', category: 'Electrician'),
  ];

  @override
  Future<List<TradieRateEntry>> getRates() async => const [];

  @override
  Future<List<TradieScheduleSlot>> getSchedule() async => const [];

  @override
  Future<List<TradieCredential>> getCredentials() async => const [];

  @override
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    profilePuts++;
    lastProfilePayload = profileData;
  }

  @override
  Future<List<TradieScheduleSlot>> updateSchedule(
    List<TradieScheduleSlot> slots,
  ) async {
    schedulePosts++;
    lastSchedule = slots;
    return slots;
  }

  @override
  Future<List<TradieRateEntry>> updateRates(List<TradieRateEntry> rates) async {
    ratesPosts++;
    lastRates = rates;
    return rates;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mountWizard(
    WidgetTester tester,
    _ProfileRepo repo, {
    bool dark = false,
    double scale = 1,
    double width = 390,
    double height = 2400,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TradieOnboardingWizard()),
        GoRoute(
          path: '/tradie',
          builder: (_, _) => const Scaffold(body: Text('dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          localeConfigProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  /// Drives the wizard from step 1 to the payout step through the UI.
  Future<void> advanceToPayout(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, 'Jamie'), 'Jamie');
    await tester.enterText(find.widgetWithText(TextField, 'Ngata'), 'Ngata');
    await tester.enterText(
      find.widgetWithText(TextField, '12 Queen Street, Auckland CBD'),
      '12 Queen Street',
    );
    await tapContinue(tester);

    await tester.tap(find.text('Choose your primary trade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plumber').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leak repair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leak repair'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '85.00'), '85.50');
    await tapContinue(tester);
    await tapContinue(tester); // verification → payout
  }

  group('section regrouping (D7)', () {
    testWidgets('step 1 is Where you work: details, area and availability', (
      tester,
    ) async {
      final repo = _ProfileRepo();
      await mountWizard(tester, repo);

      expect(find.text('Where you work'), findsOneWidget);
      expect(find.text('First name'.toUpperCase()), findsOneWidget);
      expect(find.text('Phone'.toUpperCase()), findsOneWidget);
      expect(find.text('Base address'.toUpperCase()), findsOneWidget);
      expect(find.text('Service radius'.toUpperCase()), findsOneWidget);
      expect(find.text('Weekly availability'.toUpperCase()), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);

      // Bank and trade moved out of step 1.
      expect(find.text('Account number'.toUpperCase()), findsNothing);
      expect(find.text('Primary trade'.toUpperCase()), findsNothing);
    });

    testWidgets('progress rail shows all four section labels', (tester) async {
      await mountWizard(tester, _ProfileRepo());
      for (final label in ['Work', 'Trades', 'Verify', 'Payout']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('Step 1 of 4'), findsOneWidget);
    });
  });

  group('validation returns to the field', () {
    testWidgets('empty continue marks each missing field inline', (
      tester,
    ) async {
      final repo = _ProfileRepo();
      await mountWizard(tester, repo);

      await tapContinue(tester);

      expect(find.text('Enter your first name.'), findsOneWidget);
      expect(find.text('Enter your last name.'), findsOneWidget);
      expect(find.text('Enter the address you work from.'), findsOneWidget);
      // Nothing was sent.
      expect(repo.profilePuts, 0);
      expect(repo.schedulePosts, 0);
    });

    testWidgets('editing a field clears only its own error', (tester) async {
      await mountWizard(tester, _ProfileRepo());
      await tapContinue(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Jamie'), 'Jamie');
      await tester.pump();

      expect(find.text('Enter your first name.'), findsNothing);
      expect(find.text('Enter your last name.'), findsOneWidget);
    });
  });

  group('save flow', () {
    testWidgets(
      'full walkthrough saves profile, schedule, rates and bank in order',
      (tester) async {
        final repo = _ProfileRepo();
        await mountWizard(tester, repo);

        // ── Step 1: where you work ──
        await tester.enterText(
          find.widgetWithText(TextField, 'Jamie'),
          'Jamie',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Ngata'),
          'Ngata',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '12 Queen Street, Auckland CBD'),
          '12 Queen Street',
        );
        // Enable a weekday so the schedule POST carries a slot.
        await tester.ensureVisible(find.byType(Switch).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch).first);
        await tapContinue(tester);

        expect(repo.profilePuts, 1);
        expect(repo.schedulePosts, 1);
        expect(repo.lastSchedule, isNotEmpty);
        expect(find.text('Your trades'), findsOneWidget);
        expect(find.textContaining('Step 2 of 4'), findsOneWidget);

        // ── Step 2: trades ──
        await tapContinue(tester); // nothing picked yet
        expect(find.text('Choose your primary trade.'), findsOneWidget);
        expect(
          find.text('Pick at least one service you offer.'),
          findsOneWidget,
        );
        expect(repo.ratesPosts, 0);

        await tester.tap(find.text('Choose your primary trade'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plumber').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Leak repair'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leak repair'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, '85.00'),
          '85.50',
        );
        await tapContinue(tester);

        expect(repo.profilePuts, 2);
        expect(repo.lastProfilePayload?['tradeType'], 'Plumber');
        expect(repo.lastProfilePayload?['firstName'], 'Jamie');
        expect(repo.ratesPosts, 1);
        expect(repo.lastRates!.single.hourlyRate, Decimal.parse('85.50'));
        expect(find.text('Verification'), findsOneWidget);

        // ── Step 3: verification (uploads save inline) ──
        await tapContinue(tester);
        // 'Payout' matches the progress label and the step title.
        expect(find.text('Payout'), findsNWidgets(2));
        expect(find.text('Account number'.toUpperCase()), findsOneWidget);

        // ── Step 4: payout ──
        await tester.enterText(
          find.widgetWithText(TextField, 'Jamie Ngata'),
          'Jamie Ngata',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '12-3456-7890123-45'),
          '12-3456-7890123-45',
        );
        await tester.tap(find.text('Finish setup'));
        await tester.pumpAndSettle();

        expect(repo.profilePuts, 3);
        expect(
          repo.lastProfilePayload?['bankAccountNumber'],
          '12-3456-7890123-45',
        );
        // Earlier answers were re-sent, not dropped.
        expect(repo.lastProfilePayload?['firstName'], 'Jamie');
        expect(find.text('dashboard'), findsOneWidget);
      },
    );

    testWidgets('bad bank format blocks finish with a field error', (
      tester,
    ) async {
      final repo = _ProfileRepo();
      await mountWizard(tester, repo);
      await advanceToPayout(tester);

      // 'Payout' matches the progress label and the step title.
      expect(find.text('Payout'), findsNWidgets(2));
      final putsBefore = repo.profilePuts;

      await tester.enterText(
        find.widgetWithText(TextField, '12-3456-7890123-45'),
        '123',
      );
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('XX-XXXX-XXXXXXX-XX'), findsOneWidget);
      // Still on the payout step — no save, no navigation.
      expect(repo.profilePuts, putsBefore);
      expect(find.text('Payout'), findsNWidgets(2));
    });

    testWidgets('going back preserves entered answers', (tester) async {
      final repo = _ProfileRepo();
      await mountWizard(tester, repo);

      await tester.enterText(find.widgetWithText(TextField, 'Jamie'), 'Jamie');
      await tester.enterText(find.widgetWithText(TextField, 'Ngata'), 'Ngata');
      await tester.enterText(
        find.widgetWithText(TextField, '12 Queen Street, Auckland CBD'),
        '12 Queen Street',
      );
      await tapContinue(tester);
      expect(find.text('Your trades'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Where you work'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Jamie').first)
            .controller!
            .text,
        'Jamie',
      );
    });
  });

  group('notifier validation', () {
    Future<TradieOnboardingNotifier> seededNotifier(_ProfileRepo repo) async {
      final notifier = TradieOnboardingNotifier(repo);
      await notifier.load();
      notifier
        ..setFirstName('Jamie')
        ..setLastName('Ngata')
        ..setAddress('12 Queen Street');
      return notifier;
    }

    test('a reversed day range errors on that day only', () async {
      final notifier = await seededNotifier(_ProfileRepo());
      notifier.setDayEnabled(1, true);
      notifier.setDayTimes(
        1,
        start: const TimeOfDay(hour: 17, minute: 0),
        end: const TimeOfDay(hour: 8, minute: 0),
      );

      expect(await notifier.saveStepAndAdvance(), isFalse);
      expect(notifier.state.fieldErrors['day:1'], contains('Monday'));
      expect(notifier.state.fieldErrors.containsKey('day:2'), isFalse);
    });

    test('rate range violations land on the specific service field', () async {
      final notifier = await seededNotifier(_ProfileRepo());
      const service = TradieService(
        id: 1,
        name: 'Leak repair',
        category: 'Plumber',
      );
      notifier
        ..setTradeType('Plumber')
        ..toggleService(service)
        ..setRateInput(service, '0')
        ..goToStep(1);

      expect(await notifier.saveStepAndAdvance(), isFalse);
      expect(notifier.state.fieldErrors['rate:1'], contains('Leak repair'));
    });

    test('the profile payload always re-sends every profile field', () async {
      final repo = _ProfileRepo();
      final notifier = await seededNotifier(repo);
      const service = TradieService(
        id: 1,
        name: 'Leak repair',
        category: 'Plumber',
      );
      notifier
        ..setTradeType('Plumber')
        ..toggleService(service)
        ..setRateInput(service, '85')
        ..setBankAccountNumber('12-3456-7890123-45')
        ..goToStep(1);

      expect(await notifier.saveStepAndAdvance(), isTrue);
      // The trades-step PUT re-sends the bank number typed for a later step.
      expect(
        repo.lastProfilePayload?['bankAccountNumber'],
        '12-3456-7890123-45',
      );
      expect(repo.lastProfilePayload?['tradeType'], 'Plumber');
    });
  });

  group('responsive', () {
    testWidgets('320px × 2.0 text shows only the current progress label', (
      tester,
    ) async {
      await mountWizard(tester, _ProfileRepo(), scale: 2, width: 320);

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Trades'), findsNothing);
      expect(find.text('Verify'), findsNothing);
      expect(find.text('Payout'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme renders the work step', (tester) async {
      await mountWizard(tester, _ProfileRepo(), dark: true);
      expect(find.text('Where you work'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
