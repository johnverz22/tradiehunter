// E5.3a — Photo picker on ho_post_job.
//
// Run with: patrol test --device-id <id> --dart-define FIXO_API_URL=...
//
// This test uses the same Keys from lib/ui/** as the integration_test suite,
// so they must stay in sync. If a Key is missing from the app widget, the
// test will fail until the key is added to the corresponding widget.
//
// Flow:
//   1. app.main() — launch the full Fixo app (Firebase, FCM, Riverpod).
//   2. Grant native image-picker permission (camera/gallery).
//   3. Log in as homeowner using Keys (email_field, password_field, login_button).
//   4. Tap the FAB to navigate to /jobs/new (post_job_screen).
//   5. Open the photos source sheet ("Add photos" Key).
//   6. Choose "Choose from gallery" from the source sheet (text finder).
//   7. Wait for the photo count badge to update ("1/5 photos added").
//   8. Tap the sign-out button.

import 'package:fixo/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('E5.3a — photo picker on ho_post_job', ($) async {
    // ── 1. Launch the app ──────────────────────────────────────────────
    app.main();

    // ── 2. Grant native image-picker permission ────────────────────────
    await $.platform.mobile.grantPermissionWhenInUse();

    // ── 3. Log in as homeowner (Keys from auth/sign_in screen) ─────────
    // Using the default test accounts from test_config.dart.
    $(const Key('email_field')).enterText('homeowner-a@fixo.test');
    $(const Key('password_field')).enterText('Test1234!');
    $(const Key('login_button')).tap();
    $(const Key('homeowner_dashboard')).waitUntilVisible();

    // ── 4. Navigate to Post Job screen ─────────────────────────────────
    await $(const Key('post_job_fab')).tap();
    await $(const Key('post_job_screen')).waitUntilVisible();

    // ── 5. Open photos source sheet ────────────────────────────────────
    await $(const Key('post_job_photos_add')).tap();

    // ── 6. Choose from gallery (native ImagePicker) ────────────────────
    await $('Choose from gallery').tap();

    // ── 7. Verify photo count badge updated ────────────────────────────
    await $('1/5 photos added')
        .waitUntilVisible(timeout: const Duration(seconds: 5));

    // ── 8. Log out ─────────────────────────────────────────────────────
    await $(const Key('sign_out_button')).tap();
  });
}
