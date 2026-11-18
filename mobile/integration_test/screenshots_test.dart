// Screenshot driver — walks every route per persona and emits __SHOT__
// markers. A host-side watcher captures `xcrun simctl io screenshot`
// on each marker while this test parks on the settled screen.
//
// Capture names follow docs/todos/02_design_system_fix_plan.md section 7.3 and
// are checked by `scripts/check-capture-names.py` against
// `docs/design/tools/capture-manifest.json`. A capture that cannot be taken
// prints `__SHOT_SKIPPED__ <name> | <reason>` instead of failing or vanishing.
// States that need special fixtures live in `screenshots_variants_test.dart`.
//
// Run through `scripts/run-shots.sh` (it passes SHOT_THEME, SHOT_TEXT_SCALE and
// UI_V2). By hand (homeowner):
//   flutter test integration_test/screenshots_test.dart \
//     --device-id <udid> --dart-define FIXO_PERSONA=homeowner \
//     --dart-define SHOT_MATCH_JOB=<requestedJobId>
//
// By hand (tradie):
//   flutter test integration_test/screenshots_test.dart \
//     --device-id <udid> --dart-define FIXO_PERSONA=tradie \
//     --dart-define SHOT_OFFER_JOB=<jobWithPendingOfferId>
//
// Optional fixture ids (default '0' = not provided, the capture is skipped):
//   SHOT_QUOTES_JOB         project job with quotes   -> homeowner/11_quotes
//   SHOT_QUOTE_REQUEST_JOB  project job for the tradie -> tradie/03_quote_form
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:fixo/widgets/notification_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/exception_log.dart';
import 'helpers/shot_env.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment(
  'FIXO_PERSONA',
  defaultValue: 'homeowner',
);

/// A `Requested` job owned by the homeowner — the matching screen
/// dispatches POST /jobs/:id/match itself on load.
const _matchJobId = String.fromEnvironment(
  'SHOT_MATCH_JOB',
  defaultValue: '64',
);

/// A job whose pending JobOffer targets the tradie persona.
const _offerJobId = String.fromEnvironment(
  'SHOT_OFFER_JOB',
  defaultValue: '64',
);

/// A job in `AwaitingPayment` matched to the tradie persona — feeds the
/// payment, payment-status and dispute shots.
const _paymentJobId = String.fromEnvironment(
  'SHOT_PAYMENT_JOB',
  defaultValue: '64',
);

/// A job in `Booked` matched to the tradie persona. Also the "not Requested"
/// job the radar error shot points at: POST /jobs/:id/match answers 409 for it
/// without changing anything.
const _bookedJobId = String.fromEnvironment(
  'SHOT_BOOKED_JOB',
  defaultValue: '65',
);

/// A job in `InProgress` matched to the tradie persona (also feeds chat).
const _inProgressJobId = String.fromEnvironment(
  'SHOT_INPROGRESS_JOB',
  defaultValue: '66',
);

/// A project job with at least one received quote (`homeowner/11_quotes`).
const _quotesJobId = String.fromEnvironment(
  'SHOT_QUOTES_JOB',
  defaultValue: '0',
);

/// A project job open for quotes, addressed to the tradie persona
/// (`tradie/03_quote_form`).
const _quoteRequestJobId = String.fromEnvironment(
  'SHOT_QUOTE_REQUEST_JOB',
  defaultValue: '0',
);

const _tradieUserId = 'a552097b-16b4-427b-92dd-497b6c1c1e2e';
const _homeownerUserId = 'ee759288-3421-4c43-992c-f87ea3a0e916';

/// How long the host has to fire simctl after the marker prints.
const _shotHold = Duration(seconds: 4);

const _short = Duration(seconds: 3);
const _brief = Duration(seconds: 2);

/// Parks on the current screen and prints the marker. [verify] checks the
/// forced theme and text scale first; the splash opts out because the theme
/// is not applied yet when it shows.
Future<void> _shot(
  WidgetTester tester,
  String name, {
  Duration settle = const Duration(seconds: 5),
  bool verify = true,
}) async {
  ExceptionLog.mark(name);
  await pumpFor(tester, settle);
  if (verify) expectShotEnvironment(tester);
  print('__SHOT__ $name');
  await Future<void>.delayed(_shotHold);
}

Future<void> _go(
  WidgetTester tester,
  String location,
  String name, {
  Object? extra,
  Duration settle = const Duration(seconds: 5),
}) async {
  ExceptionLog.mark(name);
  appRouter.go(location, extra: extra);
  await _shot(tester, name, settle: settle);
}

/// push (not go) between same-pattern routes — go_router reuses the page
/// element on param-only changes, leaving initState-fetched data stale (the
/// prior job's screen renders again).
Future<void> _push(
  WidgetTester tester,
  String location,
  String name, {
  Duration settle = const Duration(seconds: 5),
}) async {
  ExceptionLog.mark(name);
  appRouter.push(location);
  await _shot(tester, name, settle: settle);
}

/// The feed is local and FCM-fed (no backend inbox), so a fresh simulator
/// shows only the empty state, which cannot be compared with the mockup's five
/// rows. Seed five capture-only samples (three read, two unread), take the
/// shot, then clear the feed so nothing persists in the simulator's prefs.
/// If the store cannot be reached the shot is skipped, never silently empty.
Future<void> _captureNotifications(WidgetTester tester) async {
  const name = 'homeowner/22_notifications';
  final NotificationCenter center;
  try {
    center = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
      listen: false,
    ).read(notificationCenterProvider);
    await center.ensureLoaded();
    await center.clear();
    final now = DateTime.now();
    const samples = [
      ('payments', 'Approve final amount', 'Final amount ready for approval.'),
      ('jobs', 'Extra cost request', 'A tradie asked to add an extra cost.'),
      ('jobs', 'Request accepted', 'A tradie accepted your job.'),
      ('jobs', 'Quote received', 'A new quote is waiting for you.'),
      ('reminders', 'Reminder', 'Your job is scheduled for tomorrow.'),
    ];
    // add() puts the newest first, so seed oldest to newest.
    for (var i = samples.length - 1; i >= 0; i--) {
      final (category, title, body) = samples[i];
      await center.add(
        FixoNotification(
          id: 'shot-$i',
          title: title,
          body: body,
          category: category,
          receivedAt: now.subtract(Duration(hours: i * 6)),
        ),
      );
    }
    for (var i = 2; i < samples.length; i++) {
      await center.markRead('shot-$i'); // rows 0 and 1 stay unread
    }
  } catch (e) {
    shotSkipped(name, 'could not seed the notification feed: $e');
    return;
  }
  try {
    await _go(tester, '/notifications', name);
  } finally {
    await center.clear();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture all $_persona screens', (tester) async {
    ExceptionLog.install();
    applyShotTextScale(tester);
    await seedShotPrefs();
    app.main();
    // Splash shows during the ~2s boot delay — catch it early.
    if (_persona == 'homeowner') {
      await _shot(
        tester,
        'shared/01_splash',
        settle: const Duration(milliseconds: 1500),
        verify: false,
      );
    } else {
      await pumpFor(tester, const Duration(seconds: 2));
    }

    // Pre-auth screens — capture once, on the homeowner pass.
    if (_persona == 'homeowner') {
      await _captureShared(tester);
    }

    // Land on the login form before loginAs — gotoLogin cannot converge
    // from arbitrary non-shell routes (role-select/verify-email).
    appRouter.go('/auth');
    final email = _persona == 'tradie' ? kTradieEmail : kHomeownerEmail;
    final password = _persona == 'tradie'
        ? kTradiePassword
        : kHomeownerPassword;
    // loginAs navigates to the persona home before the post_login shot marks
    // the screen — mark now or home-screen exceptions are misattributed to
    // the last shared capture (role_select).
    ExceptionLog.mark('$_persona/00_post_login');
    await loginAs(tester, email, password);
    await _shot(tester, '$_persona/00_post_login', settle: _brief);

    if (_persona == 'tradie') {
      await _captureTradie(tester);
    } else {
      await _captureHomeowner(tester);
    }

    ExceptionLog.finish();
    print('__SHOTS_DONE__');
  }, timeout: const Timeout(Duration(minutes: 15)));
}

Future<void> _captureShared(WidgetTester tester) async {
  await _go(tester, '/onboarding', 'shared/02_onboarding_1', settle: _short);
  const later = ['shared/02_onboarding_2', 'shared/02_onboarding_3'];
  for (final name in later) {
    final next = find.text('Next');
    if (next.evaluate().isEmpty) {
      shotSkipped(name, 'no "Next" button on the previous slide');
      continue;
    }
    await tester.tap(next);
    await _shot(tester, name, settle: _brief);
  }
  await _go(tester, '/auth', 'shared/03_login', settle: _short);
  await _go(tester, '/signup', 'shared/04_signup', settle: _short);
  await _go(
    tester,
    '/verify-email',
    'shared/05_verify',
    extra: 'unverified@fixo.test',
    settle: _short,
  );
  await _go(
    tester,
    '/role-select',
    'shared/06_role_select',
    extra: (userId: 'stub', registrationToken: 'stub'),
    settle: _short,
  );
}

Future<void> _captureHomeowner(WidgetTester tester) async {
  await _go(tester, '/home', 'homeowner/01_home');
  await _captureJobsFilters(tester);
  await _go(tester, '/messages', 'homeowner/03_messages');
  await _go(tester, '/profile', 'homeowner/04_profile');
  await _go(tester, '/settings', 'homeowner/05_settings');
  await _capturePostJob(tester);
  await _go(
    tester,
    '/jobs/$_matchJobId/matching',
    'homeowner/07_radar',
    settle: const Duration(seconds: 6),
  );
  // The matching screen starts matching on load; for a job that is not
  // `Requested` the API answers 409 and nothing changes — that is the failure
  // state (fix plan N-03).
  await _push(
    tester,
    '/jobs/$_bookedJobId/matching',
    'homeowner/07b_radar_error',
    settle: const Duration(seconds: 6),
  );
  // v1.7 (P12-06): the match-result screen is retired — the
  // Choose-a-Tradie list is its homeowner-facing successor.
  await _go(tester, '/jobs/$_matchJobId/tradies', 'homeowner/08_choose');
  await _go(tester, '/tradie/$_tradieUserId', 'homeowner/09_tradie_profile');
  await _go(tester, '/jobs/$_offerJobId/request', 'homeowner/10_request_sent');
  if (hasFixture(_quotesJobId)) {
    await _go(tester, '/jobs/$_quotesJobId/quotes', 'homeowner/11_quotes');
  } else {
    shotSkipped(
      'homeowner/11_quotes',
      'SHOT_QUOTES_JOB not provided (needs a project job with quotes)',
    );
  }
  await _go(
    tester,
    '/jobs/$_inProgressJobId/detail',
    'homeowner/13_job_inprogress',
  );
  await _push(tester, '/jobs/$_bookedJobId/detail', 'homeowner/12_job_booked');
  await _go(tester, '/chat/$_inProgressJobId', 'homeowner/21_chat');
  await _go(tester, '/jobs/$_paymentJobId/payment', 'homeowner/15_payment');
  await _go(
    tester,
    '/jobs/$_paymentJobId/payment/status',
    'homeowner/15b_payment_status_awaiting',
  );
  await _go(tester, '/jobs/$_paymentJobId/dispute', 'homeowner/18_dispute');
  await _captureNotifications(tester);
  await _go(tester, '/find-tradie', 'homeowner/23_browse');
  await _go(tester, '/categories', 'homeowner/24_categories');
  await _go(
    tester,
    '/users/$_homeownerUserId',
    'homeowner/25_homeowner_profile',
  );
}

/// Jobs list in its three filter states (Active is the default).
Future<void> _captureJobsFilters(WidgetTester tester) async {
  await _go(tester, '/jobs', 'homeowner/02_jobs_active');
  final filter = find.byKey(const Key('jobs_filter'));
  const filters = [
    ('Completed', 'homeowner/02b_jobs_completed'),
    ('All', 'homeowner/02c_jobs_all'),
  ];
  for (final (label, name) in filters) {
    final segment = find.descendant(of: filter, matching: find.text(label));
    if (segment.evaluate().isEmpty) {
      shotSkipped(
        name,
        'no "$label" segment under jobs_filter (v1 list? run with UI_V2=all)',
      );
      continue;
    }
    await tester.tap(segment);
    await _shot(tester, name, settle: _brief);
  }
}

/// Post job: quick form top, quick form bottom, then the Project segment.
Future<void> _capturePostJob(WidgetTester tester) async {
  await _go(tester, '/jobs/new', 'homeowner/06_post_quick');
  // Post-job is a long scrollable form — grab the bottom half too.
  final scrollable = find.byType(Scrollable).first;
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable, const Offset(0, -900));
    await _shot(tester, 'homeowner/06b_post_quick_bottom', settle: _brief);
    await tester.drag(scrollable, const Offset(0, 900));
    await pumpFor(tester, const Duration(seconds: 1));
  } else {
    shotSkipped(
      'homeowner/06b_post_quick_bottom',
      'no scrollable on the post-job screen',
    );
  }
  final project = find.text('Project');
  if (project.evaluate().isEmpty) {
    shotSkipped(
      'homeowner/06c_post_project',
      'no "Project" segment (v1 post-job screen? run with UI_V2=all)',
    );
    return;
  }
  await tester.tap(project.first);
  await _shot(tester, 'homeowner/06c_post_project', settle: _brief);
}

Future<void> _captureTradie(WidgetTester tester) async {
  await _go(tester, '/tradie', 'tradie/01_home_online');
  shotSkipped(
    'tradie/01b_home_offline',
    'going offline changes availability and needs a confirm sheet; capture it '
        'with the T-01 online switch',
  );
  await _go(tester, '/jobs', 'tradie/09_jobs');
  await _go(tester, '/tradie/requests/$_offerJobId', 'tradie/02_lead');
  if (hasFixture(_quoteRequestJobId)) {
    await _go(
      tester,
      '/tradie/requests/$_quoteRequestJobId',
      'tradie/03_quote_form',
    );
  } else {
    shotSkipped(
      'tradie/03_quote_form',
      'SHOT_QUOTE_REQUEST_JOB not provided (needs a project job for quotes)',
    );
  }
  await _go(
    tester,
    '/tradie/jobs/$_inProgressJobId',
    'tradie/05_job_inprogress',
  );
  await _captureExtraCostSheet(tester);
  shotSkipped(
    'tradie/07_complete',
    'v1 Check Out is a one-tap API call that changes the job state; capture '
        'the final-hours form after T-05',
  );
  await _push(tester, '/tradie/jobs/$_bookedJobId', 'tradie/04_job_booked');
  shotSkipped('tradie/08_earnings', 'no earnings screen or route until T-06');
  await _go(tester, '/chat/$_inProgressJobId', 'tradie/18_chat');
  await _go(tester, '/messages', 'tradie/19_messages');
  await _go(tester, '/profile', 'tradie/10_profile');
  await _go(tester, '/settings', 'tradie/11_settings');
  await _go(tester, '/tradie/onboarding', 'tradie/12_onboarding_1');
  await _go(tester, '/tradie/$_tradieUserId', 'tradie/13_public_profile');
  await _go(tester, '/users/$_homeownerUserId', 'tradie/17_homeowner_profile');
}

/// Opens the "Request extra cost" sheet on the in-progress job, captures it
/// and dismisses it through the barrier. Nothing is submitted.
Future<void> _captureExtraCostSheet(WidgetTester tester) async {
  const name = 'tradie/06_extra_cost';
  final button = find.byKey(const Key('request_extra_cost_button'));
  if (button.evaluate().isEmpty) {
    shotSkipped(name, 'no request_extra_cost_button on the in-progress job');
    return;
  }
  await tester.ensureVisible(button);
  await pumpFor(tester, const Duration(seconds: 1));
  await tester.tap(button);
  await _shot(tester, name, settle: _brief);
  await tester.tapAt(const Offset(200, 100));
  await pumpFor(tester, const Duration(seconds: 1));
}
