// Screenshot sweep for the admin web app — logs in as staff and captures
// every main page across desktop, tablet, and phone viewports in light and dark themes.
//
// Viewports:
//   - desktop: 1440x900
//   - tablet:  820x1180 (iPad Air / Pro portrait)
//   - phone:   390x844 (iPhone 14)
//
// Run with:
//   node e2e/admin-shots.mjs
// Output: ../docs/runs/e2e-2026-11-09/screenshots/admin/

import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE = process.env.SHOTS_BASE_URL || 'http://localhost:5173';
const OUT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../docs/runs/e2e-2026-11-09/screenshots/admin',
);
mkdirSync(OUT, { recursive: true });

const VIEWPORTS = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'tablet',  width: 820,  height: 1180 },
  { name: 'phone',   width: 390,  height: 844 },
];

const THEMES = ['light', 'dark'];

const browser = await chromium.launch({ headless: true, channel: 'chromium' });
const consoleErrors = [];

const AUTH_FILE = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '.auth/staff.json',
);

for (const vp of VIEWPORTS) {
  for (const theme of THEMES) {
    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      colorScheme: theme,
      storageState: AUTH_FILE,
    });
    const page = await context.newPage();

    page.on('console', (m) => {
      if (m.type() === 'error') consoleErrors.push(`[${vp.name}-${theme}] ${page.url()} :: ${m.text()}`);
    });
    page.on('pageerror', (e) => consoleErrors.push(`[${vp.name}-${theme}] ${page.url()} :: ${e.message}`));

    async function shot(name, settleMs = 1200) {
      await page.waitForTimeout(settleMs);
      const filename = `${name}_${vp.name}_${theme}.png`;
      await page.screenshot({ path: path.join(OUT, filename), fullPage: false });
      console.log(`captured ${filename}`);
    }

    // Set theme in localStorage before navigation
    await page.addInitScript((t) => {
      localStorage.setItem('fixo-theme', t);
      if (document.documentElement) {
        document.documentElement.setAttribute('data-theme', t);
      }
    }, theme);

    // ── Login ────────────────────────────────────────────────────────────────
    await page.goto(`${BASE}/login`);
    await shot('01_login', 1500);

    const emailInput = page.getByLabel('Email Address');
    if (await emailInput.isVisible().catch(() => false)) {
      await emailInput.fill('staff@fixo.test');
      await page.getByLabel('Password').fill('Test1234!');
      await page.getByRole('button', { name: 'Sign In' }).click();
      await page.waitForURL('**/dashboard', { timeout: 10_000 }).catch(() => {});
    }

    await shot('02_dashboard', 1800);

    // ── Main queues ──────────────────────────────────────────────────────────
    const pages = [
      ['/credentials', '03_credentials'],
      ['/payments', '04_payments'],
      ['/refunds', '05_refunds'],
      ['/disputes', '06_disputes'],
      ['/users', '07_users'],
      ['/payouts', '08_payouts'],
      ['/payouts/batches', '09_payout_batches'],
      ['/audit-logs', '10_audit_logs'],
      ['/settings', '11_settings'],
    ];

    for (const [route, name] of pages) {
      await page.goto(`${BASE}${route}`);
      await shot(name, 1200);
    }

    // ── Detail views ─────────────────────────────────────────────────────────
    for (const [route, name] of [
      ['/disputes', '12_dispute_detail'],
      ['/users', '13_user_detail'],
    ]) {
      await page.goto(`${BASE}${route}`);
      await page.waitForTimeout(1000);
      const row = page.locator('table tbody tr, ul[role="list"] li').first();
      const link = row.getByRole('link').first();
      if (await link.isVisible().catch(() => false)) {
        await link.click();
        await shot(name, 1200);
      }
    }

    // ── Long-content stress test on users / payments ─────────────────────────
    if (vp.name === 'phone' && theme === 'light') {
      await page.goto(`${BASE}/users`);
      await page.waitForTimeout(1000);
      await page.evaluate(() => {
        // Inject long strings into first card
        const cardTitle = document.querySelector('ul[role="list"] li .font-medium');
        if (cardTitle) {
          cardTitle.textContent = 'Dr. Alexandria Montgomery-Fitzgerald III of Lower Hutt Region (Master Certified Electrician & Gasfitter)';
        }
      });
      await shot('14_stress_long_content', 800);
    }

    await context.close();
  }
}

console.log('\nConsole errors seen:', consoleErrors.length);
for (const e of consoleErrors.slice(0, 20)) console.log('  ' + e);
await browser.close();
