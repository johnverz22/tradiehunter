// ignore_for_file: avoid_print

import 'dart:io' show Platform;

/// Test configuration for integration tests.
///
/// Set FIXO_API_URL (--dart-define) to override. Default is
/// http://localhost:5000; on an Android emulator "localhost"/"127.0.0.1" are
/// rewritten to 10.0.2.2 (the host alias), mirroring the app's own rule in
/// viewmodels/auth_viewmodel.dart. iOS simulators share the host network.
const String _kApiUrlDefine = String.fromEnvironment(
  'FIXO_API_URL',
  defaultValue: 'http://localhost:5000',
);

final String kApiBaseUrl = Platform.isAndroid
    ? _kApiUrlDefine
        .replaceFirst('localhost', '10.0.2.2')
        .replaceFirst('127.0.0.1', '10.0.2.2')
    : _kApiUrlDefine;

// ── Test accounts ─────────────────────────────────────────────────────────────
// Mirror the accounts seeded by scripts/e2e-credentials.py --keep
// and DemoSeedService. Do NOT use production credentials here.

const kHomeownerEmail    = 'homeowner-a@fixo.test';
const kHomeownerPassword = 'Test1234!';

const kTradieEmail    = 'tradie-verified@fixo.test';
const kTradiePassword = 'Test1234!';

const kStaffEmail    = 'staff@fixo.test';
const kStaffPassword = 'Test1234!';

/// Unverified account — used to assert OTP gate (P1-06).
const kUnverifiedEmail    = 'unverified@fixo.test';
const kUnverifiedPassword = 'Test1234!';

/// Demo tradie (DemoSeedService) — competes with kTradieEmail for offers.
/// Fixtures park it (IsAvailable=false) so the test tradie wins matching.
const kDemoTradieEmail    = 'tradie@fixo.nz';
const kDemoTradiePassword = 'Demo1!Fixo';

// ── Timing ────────────────────────────────────────────────────────────────────

/// Default settle duration for screens that make network calls on load.
const kNetworkSettle = Duration(seconds: 10);

/// Longer wait for matching/offer flows where Hangfire fires jobs and cross-persona
/// switching occurs (TH-TEST-002d: increased from 20s to 60s for CI headroom).
const kMatchingSettle = Duration(seconds: 60);
