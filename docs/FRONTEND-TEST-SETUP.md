# Frontend Automated Testing Setup Guide

Covers two layers:

- **Flutter mobile** → `integration_test` (official Flutter E2E framework)
- **React admin web** → Playwright

Both target the test cases defined in `docs/QA-functional-testing-guide.md` and the spec files
under `docs/specs/v1.2/`. The backend stack (API + DB) must be running for any integration test
that makes real API calls.

---

## Prerequisites

| Requirement | Check |
|---|---|
| Docker / OrbStack running with `docker compose up` | `docker compose ps` — api, db, redis, azurite all healthy |
| Flutter SDK on host | `/Users/john/Develop/flutter/bin/flutter --version` |
| Node.js ≥ 20 on host | `node --version` |
| An iOS simulator or Android emulator available | `flutter devices` |

---

## Part 1 — Flutter Mobile (`integration_test`)

`integration_test` is the officially maintained Flutter E2E package. Tests run on a real
emulator/simulator or device; they drive the actual app UI, not a headless widget tree.

### 1.1 Add the dependency

`integration_test` ships with the Flutter SDK — no pub.dev package needed. Add it to
`mobile/pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:        # add this
    sdk: flutter
  # ... existing entries
```

Then fetch:

```sh
cd mobile
/Users/john/Develop/flutter/bin/flutter pub get
```

### 1.2 Directory layout

```
mobile/
├── integration_test/
│   ├── helpers/
│   │   ├── test_config.dart      # API base URL, test account credentials
│   │   └── auth_helper.dart      # shared login/logout steps
│   ├── auth_test.dart            # P1 — registration, OTP, login
│   ├── job_request_test.dart     # P2 — post a job
│   ├── matching_test.dart        # P3 — offer accept/decline
│   ├── payment_test.dart         # P4 — upload receipt, status screen
│   ├── job_lifecycle_test.dart   # P5 — check-in → confirm → review
│   ├── cancellation_test.dart    # P6 — cancel flows
│   └── dispute_test.dart         # P7 — open dispute, evidence
└── test/                         # existing unit/widget tests (unchanged)
```

Create the directory:

```sh
mkdir -p mobile/integration_test/helpers
```

### 1.3 Minimal test scaffold

**`mobile/integration_test/helpers/test_config.dart`**

```dart
// Adjust the base URL to match your local API.
// The emulator reaches the host machine via 10.0.2.2 (Android) or localhost (iOS sim).
const String kApiBaseUrl = 'http://10.0.2.2:5000'; // Android emulator
// const String kApiBaseUrl = 'http://localhost:5000'; // iOS simulator

// Test accounts — mirror the accounts created in QA-functional-testing-guide.md §1
// Do NOT use production credentials here.
const testHomeownerEmail    = 'homeowner-a@fixo.test';
const testHomeownerPassword = 'Test1234!';
const testTradieEmail       = 'tradie-verified@fixo.test';
const testTradiePassword    = 'Test1234!';
const testStaffEmail        = 'staff@fixo.test';
const testStaffPassword     = 'Test1234!';
```

**`mobile/integration_test/helpers/auth_helper.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

/// Taps the email field, types [email], then the password field, types
/// [password], then taps the login button. Waits for the home screen.
Future<void> loginAs(WidgetTester tester, String email, String password) async {
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('email_field')), email);
  await tester.enterText(find.byKey(const Key('password_field')), password);
  await tester.tap(find.byKey(const Key('login_button')));

  // Wait up to 10 s for the dashboard to appear.
  await tester.pumpAndSettle(const Duration(seconds: 10));
}
```

> **Key naming convention:** Add `key: const Key('...')` to interactive widgets in the app where
> they are missing. This is the primary mechanism `integration_test` uses to find widgets reliably.
> Prefer semantic names like `Key('login_button')` over positional finders.

**`mobile/integration_test/auth_test.dart`** — example P1 smoke test

```dart
import 'package:fixo/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers/test_config.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('P1 — Auth', () {
    testWidgets('P1-06 unverified account is blocked from dashboard', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Attempt login with an account whose email is not verified.
      await loginAs(tester, 'unverified@fixo.test', 'Test1234!');

      // Should land on OTP verification screen, not the dashboard.
      expect(find.byKey(const Key('otp_screen')), findsOneWidget);
      expect(find.byKey(const Key('homeowner_dashboard')), findsNothing);
    });

    testWidgets('P1-02 verified login reaches dashboard', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await loginAs(tester, testHomeownerEmail, testHomeownerPassword);

      expect(find.byKey(const Key('homeowner_dashboard')), findsOneWidget);
    });
  });
}
```

### 1.4 Running the tests

**Single test file on a connected emulator:**

```sh
cd mobile
/Users/john/Develop/flutter/bin/flutter test \
  integration_test/auth_test.dart \
  --device-id <emulator_id>
```

Get emulator IDs with:

```sh
/Users/john/Develop/flutter/bin/flutter devices
```

**All integration tests:**

```sh
/Users/john/Develop/flutter/bin/flutter test integration_test/ --device-id <emulator_id>
```

**iOS simulator (macOS host):**

```sh
/Users/john/Develop/flutter/bin/flutter test \
  integration_test/auth_test.dart \
  --device-id "iPhone 16 Pro"
```

> The API base URL in `test_config.dart` should be `http://localhost:5000` for the iOS simulator
> since it shares the host network. Use `http://10.0.2.2:5000` for the Android emulator.

### 1.5 Tips

- **`pumpAndSettle` timeout** — network calls take time. Pass a duration:
  `await tester.pumpAndSettle(const Duration(seconds: 15))`. If the test still times out, the
  API may be unreachable or a loading state never resolves.
- **Test isolation** — each test should start from a known DB state. The simplest approach:
  run `scripts/e2e-credentials.py --keep` once to seed base accounts, then have each test log
  out in `tearDown`.
- **Finding widgets** — prefer `find.byKey` over `find.text` for interactive elements so locale
  changes don't break tests. Use `find.text` only for asserting visible copy.
- **`freezed` models** — no impact; `integration_test` drives the compiled app directly.

---

## Part 2 — React Admin Web (Playwright)

Playwright tests the compiled Vite app in a real Chromium browser. It's the upgrade path already
flagged in `docs/ai-tooling.md`.

### 2.1 Install Playwright

From the `web/` directory:

```sh
cd web
npm install --save-dev @playwright/test@1.49.1
npx playwright install chromium
```

This installs:
- `@playwright/test` — the test runner + assertion library
- Chromium browser binary (only Chromium needed for this project)

> Pinned to `1.49.1` for reproducibility. Update deliberately.

### 2.2 Playwright config

Create `web/playwright.config.ts`:

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,        // admin flows are stateful — run sequentially
  retries: 1,                  // one retry on flaky network
  workers: 1,
  reporter: [['html', { open: 'never' }], ['list']],

  use: {
    baseURL: 'http://localhost:3000',
    headless: true,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Start the Vite dev server automatically before tests.
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
```

Add the test script to `web/package.json` (under `"scripts"`):

```json
"test:e2e": "playwright test",
"test:e2e:ui": "playwright test --ui"
```

### 2.3 Directory layout

```
web/
└── e2e/
    ├── fixtures/
    │   └── auth.setup.ts       # shared login state (re-used across test files)
    ├── auth.spec.ts            # admin login / role gating
    ├── credentials.spec.ts     # P1 — credential queue
    ├── payments.spec.ts        # P4 — payment queue
    ├── refunds.spec.ts         # P6 — refund queue
    ├── disputes.spec.ts        # P7 — dispute management
    └── users.spec.ts           # P7 — flagged accounts
```

Create the directory:

```sh
mkdir -p web/e2e/fixtures
```

### 2.4 Shared auth fixture

**`web/e2e/fixtures/auth.setup.ts`**

```ts
import { test as setup, expect } from '@playwright/test';
import path from 'path';

// Path where Playwright saves the authenticated browser state.
export const STAFF_AUTH_FILE = path.join(__dirname, '../.auth/staff.json');

setup('authenticate as staff', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email').fill('staff@fixo.test');
  await page.getByLabel('Password').fill('Test1234!');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Wait for the admin dashboard to load.
  await page.waitForURL('**/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // Save the auth cookies/localStorage so other tests skip the login step.
  await page.context().storageState({ path: STAFF_AUTH_FILE });
});
```

Add the setup to `playwright.config.ts` under `projects`:

```ts
projects: [
  // Run auth setup first, once.
  {
    name: 'setup',
    testMatch: /.*\.setup\.ts/,
  },
  {
    name: 'chromium',
    use: {
      ...devices['Desktop Chrome'],
      storageState: './e2e/.auth/staff.json',  // reuse auth state
    },
    dependencies: ['setup'],
  },
],
```

Add `.auth/` to `web/.gitignore`:

```
e2e/.auth/
```

### 2.5 Example test — P1 credential queue

**`web/e2e/credentials.spec.ts`**

```ts
import { test, expect } from '@playwright/test';

test.describe('P1 — Credential Queue', () => {

  test('P1-21 pending credentials listed oldest-first', async ({ page }) => {
    await page.goto('/credentials');

    // Table should have at least one row.
    const rows = page.locator('table tbody tr');
    await expect(rows).not.toHaveCount(0);
  });

  test('P1-24 reject without reason shows validation error', async ({ page }) => {
    await page.goto('/credentials');

    // Open the first row's reject modal.
    await page.locator('table tbody tr').first().getByRole('button', { name: 'Reject' }).click();

    // Submit without typing a reason.
    await page.getByRole('button', { name: 'Confirm' }).click();

    // Expect an inline validation message.
    await expect(page.getByText(/reason is required/i)).toBeVisible();
  });

  test('P1-23 approving a credential removes the row', async ({ page }) => {
    await page.goto('/credentials');

    const initialCount = await page.locator('table tbody tr').count();

    await page.locator('table tbody tr').first().getByRole('button', { name: 'Approve' }).click();
    await page.getByRole('button', { name: 'Confirm' }).click();

    // Row should disappear.
    await expect(page.locator('table tbody tr')).toHaveCount(initialCount - 1);
  });

});
```

### 2.6 Example test — P4 payment queue

**`web/e2e/payments.spec.ts`**

```ts
import { test, expect } from '@playwright/test';

test.describe('P4 — Payment Queue', () => {

  test('P4-14 payment queue renders job amount and reference', async ({ page }) => {
    await page.goto('/payments');

    // Each row should show a dollar amount and a FIXO- reference code.
    const firstRow = page.locator('table tbody tr').first();
    await expect(firstRow.getByText(/\$\d+\.\d{2}/)).toBeVisible();
    await expect(firstRow.getByText(/FIXO-/)).toBeVisible();
  });

  test('P4-08 reject without reason is blocked', async ({ page }) => {
    await page.goto('/payments');

    await page.locator('table tbody tr').first().getByRole('button', { name: /review/i }).click();
    await page.getByRole('button', { name: /reject/i }).click();
    await page.getByRole('button', { name: /confirm/i }).click();

    await expect(page.getByText(/reason.*required/i)).toBeVisible();
  });

});
```

### 2.7 Running the tests

**Prerequisites:** the backend stack must be running (`docker compose up`), and you need at least
one pending credential and one pending payment in the dev DB. Use the existing seed scripts:

```sh
docker compose up -d
python3 scripts/e2e-credentials.py --keep   # seeds credentials
```

**Run all E2E tests:**

```sh
cd web
npm run test:e2e
```

**Run with the Playwright UI (interactive, great for debugging):**

```sh
npm run test:e2e:ui
```

**Run a specific file:**

```sh
npx playwright test e2e/credentials.spec.ts
```

**View the HTML report after a run:**

```sh
npx playwright show-report
```

### 2.8 Tips

- **`storageState`** — the auth fixture saves cookies and `localStorage` once; subsequent test
  files skip login. If the token expires mid-run, re-run with `npx playwright test --headed` to
  watch what happens.
- **Flaky selectors** — prefer `getByRole`, `getByLabel`, and `getByText` over CSS selectors.
  They match visible, accessible elements and survive markup refactors.
- **API mocking** — Playwright's `page.route()` can intercept and stub API calls for tests that
  don't need a live backend. Use sparingly; tests against the real stack catch more bugs.
- **`webServer` in config** — the config above starts `vite dev` automatically. On CI, set
  `VITE_API_URL` before running so the app points at the correct API container.
- **`.auth/` in `.gitignore`** — already covered in step 2.4. Never commit auth state files.

---

## Part 3 — CI integration (GitHub Actions)

Once both setups are working locally, add them to `.github/workflows/ci.yml`:

```yaml
  flutter-integration:
    runs-on: macos-latest           # macOS runners have iOS simulators
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.13.4'
      - run: flutter pub get
        working-directory: mobile
      - run: flutter test integration_test/
        working-directory: mobile
        env:
          FIXO_API_URL: http://localhost:5000

  playwright:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
        working-directory: web
      - run: npx playwright install --with-deps chromium
        working-directory: web
      - run: npm run test:e2e
        working-directory: web
        env:
          VITE_API_URL: http://localhost:5000
          CI: true
```

---

## Quick-reference command cheatsheet

| What | Command |
|---|---|
| Run all Flutter integration tests | `cd mobile && flutter test integration_test/ --device-id <id>` |
| Run one Flutter test file | `flutter test integration_test/auth_test.dart --device-id <id>` |
| List available devices | `flutter devices` |
| Run all Playwright tests | `cd web && npm run test:e2e` |
| Run Playwright in interactive UI | `cd web && npm run test:e2e:ui` |
| Run one Playwright spec | `cd web && npx playwright test e2e/credentials.spec.ts` |
| View Playwright HTML report | `cd web && npx playwright show-report` |
| Seed dev DB (credentials) | `python3 scripts/e2e-credentials.py --keep` |
| Seed dev DB (offers/matching) | `bash scripts/p3-smoke.sh` |

---

## Related docs

- `docs/QA-functional-testing-guide.md` — full manual test case list (P0–P9), use as the source of truth when writing new tests
- `docs/ai-tooling.md` — MCP setup, existing smoke scripts, Puppeteer fallback
- `scripts/e2e-credentials.py` — API-level credential E2E (keep running alongside Playwright)
- `scripts/p3-smoke.sh` — offer/matching smoke (curl + psql)
