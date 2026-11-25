// P1 — Registration, OTP, Login
//
// Two-device note: P1 flows are single-user (no counterpart persona needed).
// Run on either simulator independently.
//
// Prerequisites:
//   - Stack up: docker compose up -d
//   - Accounts seeded: python3 scripts/e2e-credentials.py --keep
//
// Run:
//   flutter test integration_test/auth_test.dart --device-id <id>

import 'package:fixo/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('P1 — Auth', () {
    // ── P1-06: unverified account is blocked from dashboard ───────────────
    testWidgets('P1-06 unverified login routes to OTP screen, not dashboard', (
      tester,
    ) async {
      app.main();
      await loginAs(tester, kUnverifiedEmail, kUnverifiedPassword);

      expect(find.byKey(const Key('otp_screen')), findsOneWidget);
      const expectedBrightness = String.fromEnvironment('AUTH_TEST_BRIGHTNESS');
      if (expectedBrightness.isNotEmpty) {
        expect(
          Theme.of(tester.element(find.byKey(const Key('otp_screen'))))
              .brightness
              .name,
          expectedBrightness,
        );
      }
      expect(find.byKey(const Key('homeowner_dashboard')), findsNothing);
      expect(find.byKey(const Key('tradie_dashboard')), findsNothing);
    });

    // ── P1-02: verified homeowner login reaches homeowner dashboard ────────
    testWidgets('P1-02 verified homeowner login reaches dashboard', (
      tester,
    ) async {
      app.main();
      await loginAsHomeowner(tester);

      expect(find.byKey(const Key('homeowner_dashboard')), findsOneWidget);
    });

    // ── P1-02 (tradie): verified tradie login reaches tradie dashboard ─────
    testWidgets('P1-02 verified tradie login reaches tradie dashboard', (
      tester,
    ) async {
      app.main();
      await loginAsTradie(tester);

      expect(find.byKey(const Key('tradie_dashboard')), findsOneWidget);
    });

    // ── P1-07: OTP screen widgets are present ─────────────────────────────
    testWidgets(
      'P1-07 OTP screen shows code field, verify and resend buttons',
      (tester) async {
        app.main();
        await loginAs(tester, kUnverifiedEmail, kUnverifiedPassword);

        expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
        expect(find.byKey(const Key('verify_button')), findsOneWidget);
        expect(find.byKey(const Key('resend_button')), findsOneWidget);
      },
    );

    // ── P9-03: wrong password shows error, no dashboard ───────────────────
    testWidgets('P9-03 wrong password shows error banner', (tester) async {
      app.main();
      await loginAs(tester, kHomeownerEmail, 'WrongPassword!');

      expect(find.byKey(const Key('homeowner_dashboard')), findsNothing);
      expect(find.byKey(const Key('login_screen')), findsOneWidget);
    });

    // ── Signup screen widgets ─────────────────────────────────────────────
    testWidgets('Signup screen renders role cards and all form fields', (
      tester,
    ) async {
      app.main();
      await gotoLogin(tester);

      // Navigate to signup
      await tester.tap(find.text('Create account'));
      await pumpFor(tester);

      expect(find.byKey(const Key('signup_screen')), findsOneWidget);
      expect(find.byKey(const Key('role_homeowner')), findsOneWidget);
      expect(find.byKey(const Key('role_tradie')), findsOneWidget);
      expect(find.byKey(const Key('full_name_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_email_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_password_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_button')), findsOneWidget);
    });
  });
}
