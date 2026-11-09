// ignore_for_file: avoid_print

/// Test configuration for integration tests.
///
/// iOS simulator shares the host network — use localhost.
/// Android emulator uses 10.0.2.2 as the host alias.
/// Override by setting FIXO_API_URL before running tests.
const String kApiBaseUrl = String.fromEnvironment(
  'FIXO_API_URL',
  defaultValue: 'http://localhost:5000', // iOS simulator default
);
// const String kApiBaseUrl = 'http://10.0.2.2:5000'; // Android emulator

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
