import { defineConfig, devices } from '@playwright/test';

// Local-only variant: serves the app on :8090 with an /api proxy (see
// vite.e2e.config.ts) because the canonical ports 5173/3000 are occupied
// by other dev servers on this machine.
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,   // admin flows are stateful — run sequentially
  retries: 1,
  workers: 1,
  reporter: [['html', { open: 'never' }], ['list']],

  use: {
    baseURL: 'http://localhost:8090',
    headless: true,
    channel: 'chromium',
    screenshot: 'only-on-failure',
    video: 'off',
    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: './e2e/.auth/staff.json',
      },
      dependencies: ['setup'],
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

  webServer: {
    command: 'VITE_API_URL=/api npx vite --port 8090 --strictPort --config vite.e2e.config.ts',
    url: 'http://localhost:8090',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
