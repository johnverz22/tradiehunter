// E5.3b — FCM notification permission on first login.
//
// Run with: patrol test --device-id <id> --dart-define FIXO_API_URL=...
//     (NOTE: do NOT pass FIXO_DISABLE_PUSH=true; this test needs the prompt)
//
// This test launches the app with push notifications ENABLED (default),
// grants the native FCM permission dialog, then logs in as homeowner.
//
// Flow:
//   1. app.main() — launch the full Fixo app with push ENABLED.
//   2. Grant native FCM permission (alert, badge, sound) if dialog appears.
//   3. Log in as homeowner using Keys.
//   4. Verify we reach the homeowner dashboard.

import 'package:fixo/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest(
    'E5.3b — FCM notification permission on first login',
    ($) async {
      // ── 1. Launch the app (push ENABLED by default) ─────────────────────
      app.main();

      // ── 2. Grant native FCM permission if dialog appears ────────────────
      // The prompt is fire-and-forget from main(), so wait briefly for it.
      await Future<void>.delayed(const Duration(seconds: 2));

      if (await $.platform.mobile.isPermissionDialogVisible()) {
        await $.platform.mobile.grantPermissionWhenInUse();
      }

      // ── 3. Log in as homeowner (Keys from auth/sign_in screen) ──────────
      await $(const Key('email_field')).enterText('homeowner-a@fixo.test');
      await $(const Key('password_field')).enterText('Test1234!');
      await $(const Key('login_button')).tap();

      // ── 4. Verify we reach the homeowner dashboard ──────────────────────
      await $(const Key('homeowner_dashboard')).waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
    },
  );
}