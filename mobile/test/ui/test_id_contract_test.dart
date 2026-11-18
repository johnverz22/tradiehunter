// E3 contract test — every interactive element the E2E suite locates by
// `Key` must also expose the same string as a `Semantics(identifier:)` so
// out-of-process drivers (Maestro) can find it. Flutter Keys are invisible
// outside the Dart isolate; identifiers are not read aloud by screen
// readers.
//
// Two layers:
//   1. Source scan: each contract id appears as a `Key('…')` under lib/ui
//      (dynamic families like accept_quote_<id> / dispute_reason_<r> are
//      matched by prefix).
//   2. Widget test: the shared TH* primitives mirror a ValueKey<String>
//      into Semantics.identifier automatically (th_test_id.dart), and
//      THTestId / .testId() provide explicit wrappers.

import 'dart:io';

import 'package:fixo/ui/design/th_tokens.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ids the integration_test suite relies on (see integration_test/**).
/// Screen-root ids on raw Scaffold are intentionally absent — they are not
/// interactive; THScaffold-keyed screens get identifiers for free.
const contractIds = <String>[
  // auth
  'email_field', 'password_field', 'login_button',
  'otp_code_field', 'verify_button', 'resend_button',
  'signup_button', 'full_name_field', 'signup_email_field',
  'signup_password_field', 'role_homeowner', 'role_tradie',
  'sign_out_button',
  // shell / dock
  'post_job_fab', 'dock_home', 'dock_jobs', 'dock_chat', 'dock_profile',
  // post job
  'service_dropdown', 'title_field', 'hours_field', 'description_field',
  'address_search_field', 'job_type_hourly', 'job_type_project',
  'scheduled_start_field', 'scheduled_end_field', 'budget_min_field',
  'budget_max_field', 'scope_notes_field', 'site_visit_switch',
  'post_job_button',
  // choose tradie
  'tradie_sort_bar', 'tradie_filter_verified', 'tradie_filter_insured',
  'tradie_filter_available', 'quick_match_button', 'tradie_list',
  // quotes / request sent
  'accept_quote_', 'written_contract_checkbox', 'contract_confirm_button',
  'pick_someone_else_button', 'cancel_request_button',
  // job detail (v2)
  'job_overflow_menu', 'cancel_confirm_button', 'cancel_dismiss_button',
  'approve_pay_button', 'dispute_amount_button',
  'leave_review_button', 'submit_review_button', 'cancellation_policy_tile',
  'open_chat_button', 'job_message_tradie',
  'adjustment_approve_button', 'adjustment_decline_button',
  'adjustment_decision_confirm',
  // tradie profile
  'request_this_tradie_button', 'request_tradie_button', 'send_request_button',
  // payment
  'upload_receipt_button',
  // dispute
  'dispute_reason_', 'dispute_details_field', 'open_dispute_button',
  // home
  'home_search',
  // review
  'star_',
  // quick-match radar (v2 N-03)
  'radar_try_again_button',
  'radar_cancel_button',
];

/// Dynamic id families — a contract entry ending in '_' is a prefix.
bool _covered(String id, Set<String> keyIds) {
  if (keyIds.contains(id)) return true;
  if (id.endsWith('_')) {
    return keyIds.any((k) => k.startsWith(id));
  }
  return false;
}

void main() {
  late Set<String> keyIds;

  setUpAll(() {
    keyIds = <String>{};
    final dir = Directory('lib/ui');
    final keyRe = RegExp("Key\\('([^']+)'");
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in keyRe.allMatches(src)) {
        keyIds.add(m.group(1)!);
      }
      // interpolated keys: Key('prefix_\$…') — capture the literal prefix
      final dynRe = RegExp("Key\\('([^']*\\\$)");
      for (final m in dynRe.allMatches(src)) {
        keyIds.add('${m.group(1)}X'); // marker; prefix match below
      }
    }
  });

  test('every contract id has a matching Key under lib/ui', () {
    final missing = <String>[
      for (final id in contractIds)
        if (!_covered(id, keyIds)) id,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'contract ids without a Key in lib/ui: $missing',
    );
  });

  test('every contract id is exposed to Semantics.identifier in lib/ui', () {
    final identIds = <String>{};
    final dir = Directory('lib/ui');
    final identRe = RegExp(
      "identifier:\\s*['\"]([^'\"]+)['\"]|testId\\(['\"]([^'\"]+)['\"]\\)",
    );
    final autoWidgets = [
      'THButton',
      'THIconButton',
      'THTextField',
      'THField',
      'THCard',
      'THScaffold',
      'THOtpInput',
      'ThChoicePills',
      'ThChoicePillItem',
      'thTestIdWrap',
      '_DatePickRow',
      'tab',
    ];
    final autoRe = RegExp(
      '(${autoWidgets.join('|')})\\b[^;{}]{0,300}?Key\\([\'"]([^\'"]+)[\'"]',
    );
    final dockRe = RegExp(r"'(dock_[a-z]+)'");

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in identRe.allMatches(src)) {
        identIds.add((m.group(1) ?? m.group(2))!);
      }
      for (final m in autoRe.allMatches(src)) {
        identIds.add(m.group(2)!);
      }
      for (final m in dockRe.allMatches(src)) {
        identIds.add(m.group(1)!);
      }
    }

    final missing = <String>[
      for (final id in contractIds)
        if (!_covered(id, identIds)) id,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'contract ids without a Semantics identifier in lib/ui: $missing',
    );
  });

  testWidgets(
    'TH primitives mirror ValueKey<String> into Semantics.identifier',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: THTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  THButton(
                    key: const Key('login_button'),
                    label: 'Sign in',
                    onPressed: () {},
                  ),
                  THTextField(key: const Key('email_field'), label: 'Email'),
                  const Text('Custom').testId('custom_test_id'),
                  const THTestId(
                    id: 'explicit_test_id',
                    child: Text('Explicit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      bool hasId(String id) => tester
          .widgetList<Semantics>(find.byWidgetPredicate((w) => w is Semantics))
          .any((s) => s.properties.identifier == id);

      expect(hasId('login_button'), isTrue);
      expect(hasId('email_field'), isTrue);
      expect(hasId('custom_test_id'), isTrue);
      expect(hasId('explicit_test_id'), isTrue);

      // A non-string key must not produce an identifier.
      expect(thTestId(const Key('x')), 'x');
      expect(thTestId(const ObjectKey(Object())), isNull);
      expect(thTestId(null), isNull);
    },
  );
}
