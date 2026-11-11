// Screen-recording tour of the mobile points of view (homeowner + tradie).
//
// Not a pass/fail regression suite — it is one scripted walkthrough per
// persona, choreographed by `scripts/e2e-demo.py` through the signal server
// (see helpers/demo_helper.dart). Run it via that script, not directly:
//
//   python3 scripts/e2e-demo.py
//
// Updated for sprint Tasks 0–8 (v1.7 UI):
//   Task 2 — Matching screen (H10) radar animation beat
//   Task 3 — Match result screen (H11) clean Flex layout
//   Task 6 — Tradie request detail: OfferCountdown, photo gallery, sticky bar
//   Task 7 — Tradie active job: StatusStrip timeline, job-code long-press
//   Task 8 — FixoNotice appearances during check-in, check-out, confirm
//
// Every UI step that cannot be driven natively (photo picker, LINZ address
// lookup when no key is configured) falls back to the API and is reported with
// Demo.note so the final summary lists exactly what was and wasn't UI-driven.
// ignore_for_file: avoid_print

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/api_helper.dart';
import 'helpers/auth_helper.dart';
import 'helpers/demo_helper.dart';
import 'helpers/fixture_helper.dart';
import 'helpers/test_config.dart';

const _persona =
    String.fromEnvironment('FIXO_PERSONA', defaultValue: 'homeowner');
const _theme = String.fromEnvironment('DEMO_THEME', defaultValue: 'light');

/// When true, the homeowner skips the dispute sub-flow so the demo ends at the
/// review step (one clean, uninterrupted success story).  Set by passing
/// `--single-flow` to `scripts/e2e-demo.py`.
const _singleFlow =
    String.fromEnvironment('DEMO_SINGLE_FLOW', defaultValue: 'false') == 'true';

const _ho = 'homeowner';
const _tr = 'tradie';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'demo tour — $_persona',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _theme == 'dark' ? 2 : 1);
      app.main();
      await pumpFor(tester, const Duration(seconds: 2));

      if (_persona == 'tradie') {
        await _tradieTour(tester);
      } else {
        await _homeownerTour(tester);
      }
      print('__DEMO_DONE__ $_persona');
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );
}

// ── Homeowner ────────────────────────────────────────────────────────────────

Future<void> _homeownerTour(WidgetTester tester) async {
  // Pre-roll (before the recording starts): build a Booked job to dispute later.
  final disputeJob = await FixtureHelper.bookedJob(tag: 'demo-dispute');
  await Demo.setData('dispute_job', '$disputeJob');
  await gotoLogin(tester);
  await Demo.signal('homeowner_ready');
  await Demo.waitSignal(tester, 'tradie_intro_done');

  // 1. First-run screens, then sign in.
  await Demo.step(_ho, 'Homeowner: onboarding, sign-up form and login');
  appRouter.go('/onboarding');
  await Demo.beat(tester, 1.5);
  appRouter.go('/signup');
  await Demo.beat(tester, 1.5);
  appRouter.go('/auth');
  await Demo.beat(tester);
  await Demo.type(tester, find.byKey(const Key('email_field')), kHomeownerEmail);
  await tester.enterText(
      find.byKey(const Key('password_field')), kHomeownerPassword);
  await Demo.beat(tester, 0.5);
  await tester.tap(find.byKey(const Key('login_button')));
  await pumpFor(tester, kNetworkSettle);
  await Demo.beat(tester);

  // 2. Browse the shell — homeowner dashboard (H07) hero band.
  await Demo.step(_ho, 'Homeowner: dashboard, jobs, messages, profile');
  for (final route in ['/home', '/jobs', '/messages', '/profile']) {
    appRouter.go(route);
    await Demo.beat(tester);
    // Scroll to reveal below-fold content, then scroll back so the top of the
    // screen is visible for the next beat.
    await Demo.scrollScreen(tester);
  }

  // 3. Post a job.
  await Demo.step(_ho, 'Homeowner: posts a new job');
  appRouter.go('/jobs/new');
  await Demo.beat(tester);
  final jobId = await _postJob(tester);
  await Demo.setData('job', '$jobId');
  await Demo.signal('job_posted');

  // 4. Matching screen (H10) — 3-ring pulsing radar animation.
  //    Hold for 2.5 beats so the radar completes a full cycle on camera before
  //    waiting for the tradie to accept the offer.
  await Demo.step(_ho, 'Homeowner: matching — radar animation, contacting nearest tradie');
  appRouter.go('/jobs/$jobId/matching');
  await Demo.beat(tester, 2.5);
  await Demo.waitSignal(tester, 'offer_accepted');

  // 5a. Match result (H11) — clean Flex layout: avatar overlap, price, tradie details.
  await Demo.step(_ho, 'Homeowner: tradie matched — reviews hourly rate and schedule');
  appRouter.go('/jobs/$jobId/match');
  await Demo.beat(tester, 2);

  // 5b. Payment instructions and bank-transfer receipt upload.
  await Demo.step(_ho, 'Homeowner: pays by bank transfer — payment instructions');
  appRouter.go('/jobs/$jobId/payment');
  await Demo.beat(tester, 2);
  // Scroll down to show payment reference details, then scroll back up.
  await Demo.scrollScreen(tester, pixels: 350);
  final homeowner = await ApiHelper.homeownerToken;
  await Demo.note(_ho,
      'receipt uploaded via API (native photo picker cannot be driven)');
  await ApiHelper.getPayment(jobId, homeowner);
  await ApiHelper.uploadReceipt(jobId, homeowner);
  await Demo.step(_ho, 'Homeowner: receipt submitted — awaiting admin verification');
  appRouter.go('/jobs/$jobId/payment/status');
  await Demo.beat(tester, 2);
  // Scroll to reveal the full payment-status card and any action buttons.
  await Demo.scrollScreen(tester, pixels: 300);
  await Demo.signal('receipt_uploaded');
  await Demo.waitSignal(tester, 'payment_verified');

  // 5c. Job detail — progress banner with on-dark StatusBadge and step nodes.
  await Demo.step(_ho, 'Homeowner: payment verified — job detail and progress banner');
  appRouter.go('/jobs/$jobId/detail');
  await Demo.beat(tester, 2);
  // Scroll to show the progress timeline nodes and job description.
  await Demo.scrollScreen(tester, pixels: 450);
  await Demo.waitSignal(tester, 'checked_out');

  // 6. Work done: chat reply, confirm completion (triggers FixoNotice.success), review.
  await Demo.step(_ho, 'Homeowner: tradie checked out — reviews chat');
  appRouter.go('/chat/$jobId');
  await Demo.beat(tester, 2);
  // Scroll up to reveal the full chat history (messages load from the bottom).
  await Demo.scrollScreen(tester, pixels: 350, scrollBack: false);
  await Demo.step(_ho, 'Homeowner: confirms job completion');
  appRouter.go('/jobs/$jobId/detail');
  await Demo.beat(tester);
  if (!await Demo.tapKey(tester, 'confirm_completion_button')) {
    await Demo.note(_ho, 'confirm button not found; confirmed via API');
    await ApiHelper.confirmCompletion(jobId, homeowner);
  }
  // Let a FixoNotice.success animate in and be visible on camera.
  await Demo.beat(tester, 0.75);
  await Demo.until(
      tester,
      () async =>
          await ApiHelper.getJobStatus(jobId, homeowner) == 'Completed');
  await pumpFor(tester, const Duration(seconds: 3));
  await Demo.step(_ho, 'Homeowner: leaves a review for the tradie');
  await _leaveReview(tester, 'Fast, tidy and friendly. Highly recommend!');
  await Demo.signal('completed');
  await Demo.waitSignal(tester, 'tradie_done');

  if (_singleFlow) {
    // Happy-path only: skip the dispute sub-flow and signal completion.
    appRouter.go('/home');
    await Demo.beat(tester);
    await Demo.signal('homeowner_done');
    return;
  }

  // 7. Dispute on the pre-built Booked job.
  await Demo.step(_ho, 'Homeowner: opens a dispute on a booked job');
  appRouter.push('/jobs/$disputeJob/detail');
  await Demo.beat(tester);
  appRouter.push('/jobs/$disputeJob/dispute');
  await Demo.beat(tester);
  final reason = find.byKey(const Key('dispute_reason_Poor Quality'));
  if (reason.evaluate().isNotEmpty) {
    await tester.ensureVisible(reason);
    await tester.tap(reason);
    await Demo.beat(tester, 0.5);
  }
  await Demo.type(tester, find.byKey(const Key('dispute_details_field')),
      'Work was left unfinished and the area was not cleaned up.');
  await Demo.tapKey(tester, 'open_dispute_button');
  await Demo.beat(tester, 2);
  await Demo.signal('dispute_opened');
  await Demo.waitSignal(tester, 'admin_done');
  appRouter.go('/home');
  await Demo.beat(tester);
}

/// Fills the Post Job form; returns the new job's id. Falls back to the API
/// when a required field can't be completed through the UI.
Future<int> _postJob(WidgetTester tester) async {
  const title = 'Leaking kitchen tap — demo';
  await Demo.type(tester, find.byKey(const Key('title_field')), title);
  await Demo.type(tester, find.byKey(const Key('description_field')),
      'Tap drips constantly and the washer looks worn out.');
  final hours = find.byKey(const Key('hours_field'));
  if (hours.evaluate().isNotEmpty) {
    await Demo.type(tester, hours, '2');
  }
  final address = find.byKey(const Key('address_search_field'));
  if (address.evaluate().isNotEmpty) {
    await Demo.type(tester, address, '70 Symonds Street Auckland');
    await pumpFor(tester, kNetworkSettle);
    final candidate = find.text('70 Symonds Street, Grafton, Auckland');
    if (candidate.evaluate().isNotEmpty) {
      await tester.ensureVisible(candidate);
      await tester.tap(candidate);
      await Demo.beat(tester);
    }
  }

  final before = appRouter.state.uri.path;
  final post = find.byKey(const Key('post_job_button'));
  if (post.evaluate().isNotEmpty) {
    await tester.ensureVisible(post);
    await tester.tap(post);
    await pumpFor(tester, const Duration(seconds: 8));
  }
  final match = RegExp(r'/jobs/(\d+)/matching').firstMatch(
      appRouter.state.uri.path);
  if (match != null && appRouter.state.uri.path != before) {
    return int.parse(match.group(1)!);
  }

  await Demo.note(_ho,
      'job created via API (post-job form not submittable through the UI — address lookup needs LINZ_API_KEY)');
  return ApiHelper.createJob(await ApiHelper.homeownerToken,
      title: title);
}

Future<void> _leaveReview(WidgetTester tester, String text) async {
  if (!await Demo.tapKey(tester, 'leave_review_button')) {
    await Demo.note(_ho, 'review button not shown');
    return;
  }
  final stars = find.byIcon(Icons.star);
  if (stars.evaluate().length >= 5) {
    await tester.tap(stars.at(4));
    await Demo.beat(tester, 0.5);
  }
  final comment = find.byType(TextField);
  if (comment.evaluate().isNotEmpty) {
    await Demo.type(tester, comment, text);
  }
  await Demo.tapText(tester, 'Submit Review');
  await Demo.beat(tester, 1.5);
}

// ── Tradie ───────────────────────────────────────────────────────────────────

Future<void> _tradieTour(WidgetTester tester) async {
  await gotoLogin(tester);
  await Demo.signal('tradie_ready');
  await Demo.waitSignal(tester, 'admin_creds_done');

  // Intro: dashboard, shell navigation, onboarding wizard.
  await Demo.step(_tr, 'Tradie: login, dashboard, profile and onboarding wizard');
  await Demo.type(tester, find.byKey(const Key('email_field')), kTradieEmail);
  await tester.enterText(
      find.byKey(const Key('password_field')), kTradiePassword);
  await Demo.beat(tester, 0.5);
  await tester.tap(find.byKey(const Key('login_button')));
  await pumpFor(tester, kNetworkSettle);
  await Demo.beat(tester);
  for (final route in ['/tradie', '/jobs', '/messages', '/profile', '/tradie/onboarding']) {
    appRouter.go(route);
    await Demo.beat(tester);
    // Scroll each shell tab to reveal below-fold content.
    await Demo.scrollScreen(tester);
  }
  appRouter.go('/tradie');
  await Demo.beat(tester);
  await Demo.signal('tradie_intro_done');

  // Incoming offer: request detail screen (T21) with OfferCountdown.
  final jobId = int.parse(await Demo.waitData(tester, 'job'));
  await Demo.step(_tr, 'Tradie: receives a job offer — request detail with live countdown');
  final tradie = await ApiHelper.tradieToken;
  Map<String, dynamic>? offer;
  await Demo.until(tester, () async {
    offer = await ApiHelper.getPendingOffer(jobId, tradie);
    return offer != null;
  }, timeout: const Duration(seconds: 120));
  // Dashboard first — shows the incoming offer notification card; scroll to
  // reveal any below-fold offer cards.
  appRouter.go('/tradie');
  await Demo.beat(tester, 2);
  await Demo.scrollScreen(tester, pixels: 300);
  // Request detail — OfferCountdown (>2 min = brand, ≤2 min = amber, ≤30s = danger),
  // display price, photo gallery, sticky Accept/Decline bar.
  appRouter.go('/tradie/requests/$jobId');
  await Demo.beat(tester, 3);
  // Scroll to show the address card and photo gallery before accepting.
  await Demo.scrollScreen(tester, pixels: 400, multiplierBeforeBack: 1.5);
  await Demo.step(_tr, 'Tradie: accepts the job');
  await Demo.tapText(tester, 'Accept Job');
  var accepted = await Demo.until(tester,
      () async => await ApiHelper.getJobStatus(jobId, tradie) == 'AwaitingPayment',
      timeout: const Duration(seconds: 25));
  if (!accepted && offer != null) {
    await Demo.note(_tr, 'offer accepted via API (Accept button not tappable)');
    await ApiHelper.respondToOffer(jobId, offer!['id'] as int, 'Accepted', tradie);
    await Demo.until(tester,
        () async => await ApiHelper.getJobStatus(jobId, tradie) == 'AwaitingPayment');
  }
  // FixoNotice.success briefly appears after acceptance — hold for visibility.
  await Demo.beat(tester, 0.75);
  await Demo.signal('offer_accepted');
  await Demo.waitSignal(tester, 'payment_verified');

  // Active job screen (tradie_job_detail_screen): StatusStrip, timeline, notices.
  await Demo.step(_tr, 'Tradie: payment verified — active job and status timeline');
  appRouter.go('/tradie/jobs/$jobId');
  await Demo.beat(tester, 2);
  // Scroll to reveal the job description and check-in button below the fold.
  await Demo.scrollScreen(tester, pixels: 350);
  // Tap the status strip to expand/collapse the timeline if available.
  final statusStrip = find.byKey(const Key('status_strip_toggle'));
  if (statusStrip.evaluate().isNotEmpty) {
    await Demo.tapKey(tester, 'status_strip_toggle');
    await Demo.beat(tester, 1.5);
    await Demo.tapKey(tester, 'status_strip_toggle');
    await Demo.beat(tester);
  }
  // Check in — FixoNotice.info appears confirming the check-in.
  await Demo.step(_tr, 'Tradie: checks in — job moves to In Progress');
  if (!await Demo.tapKey(tester, 'check_in_button')) {
    await Demo.note(_tr, 'checked in via API (button not found)');
    await ApiHelper.checkIn(jobId, tradie);
  }
  await Demo.until(tester,
      () async => await ApiHelper.getJobStatus(jobId, tradie) == 'InProgress');
  // Allow FixoNotice to animate in and be visible.
  await Demo.beat(tester, 1.5);

  // Chat — tradie replies with tokenised send button (paper-plane icon).
  await Demo.step(_tr, 'Tradie: chats with the homeowner');
  appRouter.go('/chat/$jobId');
  await Demo.beat(tester);
  await ApiHelper.sendMessage(jobId, await ApiHelper.homeownerToken,
      'Hi! The tap is under the sink — spare key is with the neighbour.');
  await Demo.beat(tester, 2);
  // Scroll up to reveal the full chat history (messages load from the bottom).
  await Demo.scrollScreen(tester, pixels: 300, scrollBack: false);
  final composer = find.byType(TextField);
  if (composer.evaluate().isNotEmpty) {
    await Demo.type(tester, composer.last, 'Thanks, on it now!');
    final send = find.byKey(const Key('send_message_button'));
    if (send.evaluate().isNotEmpty) {
      await tester.tap(send.first);
    } else {
      await tester.testTextInput.receiveAction(TextInputAction.send);
    }
    await Demo.beat(tester, 2);
  }

  // Check out — job code monospace label visible in StatusStrip;
  // FixoNotice.success briefly appears.
  await Demo.step(_tr, 'Tradie: checks out — work complete, awaiting homeowner confirmation');
  appRouter.go('/tradie/jobs/$jobId');
  await Demo.beat(tester);
  // Scroll to reveal the check-out button at the bottom of the screen.
  await Demo.scrollScreen(tester, pixels: 350, scrollBack: false);
  if (!await Demo.tapKey(tester, 'check_out_button')) {
    await Demo.note(_tr, 'checked out via API (button not found)');
    await ApiHelper.checkOut(jobId, tradie);
  }
  await Demo.until(
      tester,
      () async =>
          await ApiHelper.getJobStatus(jobId, tradie) == 'AwaitingConfirmation');
  // FixoNotice visible.
  await Demo.beat(tester, 1.5);
  await Demo.signal('checked_out');
  await Demo.waitSignal(tester, 'completed');

  // Completed — rate the homeowner.
  await Demo.step(_tr, 'Tradie: job completed — rates the homeowner');
  appRouter.go('/tradie/jobs/$jobId');
  await Demo.beat(tester, 2);
  // Scroll to show the completed job summary and ratings prompt.
  await Demo.scrollScreen(tester, pixels: 350);
  if (await Demo.tapKey(tester, 'rate_homeowner_button')) {
    final stars = find.byIcon(Icons.star);
    if (stars.evaluate().length >= 5) {
      await tester.tap(stars.at(4));
      await Demo.beat(tester, 0.5);
    }
    await Demo.tapText(tester, 'Submit Review');
    await Demo.beat(tester, 1.5);
  }
  appRouter.go('/tradie');
  await Demo.beat(tester, 2);
  await Demo.signal('tradie_done');
  await Demo.waitSignal(tester, 'admin_done');
}
