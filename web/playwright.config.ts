import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,   // admin flows are stateful — run sequentially
  retries: 1,
  workers: 1,
  reporter: [['html', { open: 'never' }], ['list']],

  use: {
    baseURL: 'http://localhost:5173',
    headless: true,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'on-first-retry',
  },

  projects: [
    // Run auth setup first, once — saves cookie state to e2e/.auth/staff.json
    {
      name: 'setup',
      testMatch: /auth\.setup\.ts/,
    },
    {
      name: 'setup-superadmin',
      testMatch: /superadmin\.setup\.ts/,
    },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: './e2e/.auth/staff.json',
      },
      // The superadmin-only spec has its own project/identity.
      testIgnore: /admin-quotes-settings\.spec\.ts$/,
      dependencies: ['setup'],
    },
    {
      name: 'chromium-superadmin',
      use: {
        ...devices['Desktop Chrome'],
        storageState: './e2e/.auth/superadmin.json',
      },
      testMatch: /admin-quotes-settings\.spec\.ts$/,
      dependencies: ['setup-superadmin'],
    },
    {
      name: 'tablet',
      use: {
        ...devices['iPad Pro 11'],
        defaultBrowserType: 'chromium',
        storageState: './e2e/.auth/staff.json',
      },
      dependencies: ['setup'],
      testMatch: /responsive\.spec\.ts/,
    },
    {
      name: 'tablet-landscape',
      use: {
        ...devices['iPad Pro 11 landscape'],
        defaultBrowserType: 'chromium',
        storageState: './e2e/.auth/staff.json',
      },
      dependencies: ['setup'],
      testMatch: /responsive\.spec\.ts/,
    },
    {
      name: 'phone',
      use: {
        ...devices['Pixel 7'],
        defaultBrowserType: 'chromium',
        storageState: './e2e/.auth/staff.json',
      },
      dependencies: ['setup'],
      testMatch: /responsive\.spec\.ts/,
    },
  ],

  // Start vite dev server automatically before tests.
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
