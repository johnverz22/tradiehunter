import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixo/router/app_router.dart';

import 'test_config.dart';

// ── Login ─────────────────────────────────────────────────────────────────────

/// Drives the login screen for [email]/[password] and waits for either a
/// dashboard or the OTP screen to appear (up to [kNetworkSettle]).
///
/// Call after `app.main()` + `pumpFor(tester)`.
Future<void> loginAs(
  WidgetTester tester,
  String email,
  String password,
) async {
  await gotoLogin(tester);

  await tester.enterText(find.byKey(const Key('email_field')), email);
  await tester.enterText(find.byKey(const Key('password_field')), password);
  await tester.tap(find.byKey(const Key('login_button')));

  await pumpFor(tester, kNetworkSettle);
}

/// Reach the login form (/auth) from whatever the app booted into:
/// first-launch onboarding (Skip), the splash while a stale-token role fetch
/// resolves, a leftover OTP screen, or a dashboard from an earlier test's
/// login (signs out first). Returns once `email_field` exists or times out.
Future<void> gotoLogin(WidgetTester tester) async {
  await pumpFor(tester, kNetworkSettle);

  final deadline = DateTime.now().add(kNetworkSettle);
  while (find.byKey(const Key('email_field')).evaluate().isEmpty) {
    var acted = true;
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
    } else if (find
            .byKey(const Key('homeowner_dashboard'))
            .evaluate()
            .isNotEmpty ||
        find.byKey(const Key('tradie_dashboard')).evaluate().isNotEmpty) {
      // Stale session from an earlier test's login — clear it and jump
      // straight to /auth rather than driving the settings/sign-out UI.
      await const FlutterSecureStorage().deleteAll();
      appRouter.go('/auth');
    } else if (appRouter.state.uri.path == '/verify-email') {
      // Leftover OTP screen from a previous test — appRouter is a global
      // singleton and keeps its last location across app.main() re-runs.
      appRouter.go('/auth');
    } else if (appRouter.state.uri.path != '/auth') {
      // TH-TEST-001: Leftover non-shell route (e.g. /chat, /matching, /jobs/:id)
      // Clear session storage and jump to /auth.
      await const FlutterSecureStorage().deleteAll();
      appRouter.go('/auth');
    } else {
      acted = false;
    }
    // Only enforce the deadline when no progress action ran this pass —
    // logout() carries its own waits and may legitimately exceed it.
    if (!acted && DateTime.now().isAfter(deadline)) break;
    await tester.pump(const Duration(milliseconds: 500));
  }

  assert(find.byKey(const Key('email_field')).evaluate().isNotEmpty,
      'gotoLogin: failed to reach login screen from state ${appRouter.state.uri.path}');
}

/// Convenience wrapper — logs in as the default homeowner test account.
Future<void> loginAsHomeowner(WidgetTester tester) =>
    loginAs(tester, kHomeownerEmail, kHomeownerPassword);

/// Convenience wrapper — logs in as the default tradie test account.
Future<void> loginAsTradie(WidgetTester tester) =>
    loginAs(tester, kTradieEmail, kTradiePassword);

/// Bounded `pumpAndSettle` replacement: pumps in small steps for the whole
/// [timeout] (default [kNetworkSettle]). Two reasons it can't early-exit:
/// screens with looping animations (onboarding blobs, matching spinner) never
/// settle, and a static screen mid-flight on a timer shows no scheduled frame —
/// both would break a naive settle check either way.
Future<void> pumpFor(WidgetTester tester, [Duration? timeout]) async {
  final wait = timeout ?? kNetworkSettle;
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < wait) {
    await tester.pump(step);
    elapsed += step;
  }
}

// ── Logout ────────────────────────────────────────────────────────────────────

/// Navigates to the Settings screen (tab index 3 on both role layouts,
/// route `/settings`) and taps the sign-out button.
/// Used in tearDown to return the app to the login screen between tests.
Future<void> logout(WidgetTester tester) async {
  // Both role shells expose /settings — route there directly rather than
  // hunting UI affordances (the profile→settings link has moved before).
  if (find.byKey(const Key('sign_out_button')).evaluate().isEmpty) {
    appRouter.go('/settings');
    await pumpFor(tester);
  }

  final signOutButton = find.byKey(const Key('sign_out_button'));
  if (signOutButton.evaluate().isNotEmpty) {
    await tester.tap(signOutButton);
    await pumpFor(tester, kNetworkSettle);
  }
}

// ── API helper ────────────────────────────────────────────────────────────────

/// Polls [condition] every [interval] until it returns true or [timeout]
/// elapses. Used to wait for backend state changes driven by the other
/// simulator in two-device cross-persona flows.
///
/// Example:
/// ```dart
/// await pollUntil(() async {
///   final status = await ApiHelper.getJobStatus(jobId, token);
///   return status == 'AwaitingPayment';
/// });
/// ```
Future<void> pollUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  Duration interval = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future.delayed(interval);
  }
  throw TimeoutException(
    'pollUntil timed out after ${timeout.inSeconds}s',
    timeout,
  );
}
