// Screenshot sweep for the admin web app — logs in as staff and captures
// every main page against the live API. Run with the e2e vite server up:
//   VITE_API_URL=/api npx vite --port 8090 --strictPort --config vite.e2e.config.ts
// then:
//   node e2e/admin-shots.mjs
// Output: ../docs/runs/e2e-2026-11-09/screenshots/admin/

import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE = process.env.SHOTS_BASE_URL || 'http://localhost:8090';
const OUT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../docs/runs/e2e-2026-11-09/screenshots/admin',
);
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ channel: 'chromium', headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const consoleErrors = [];
page.on('console', (m) => {
  if (m.type() === 'error') consoleErrors.push(`${page.url()} :: ${m.text()}`);
});
page.on('pageerror', (e) => consoleErrors.push(`${page.url()} :: ${e.message}`));

async function shot(name, settleMs = 1500) {
  await page.waitForTimeout(settleMs);
  await page.screenshot({ path: path.join(OUT, `${name}.png`), fullPage: false });
  console.log(`captured ${name}.png`);
}

// ── Login ────────────────────────────────────────────────────────────────────
await page.goto(`${BASE}/login`);
await shot('01_login', 2500);
await page.getByLabel('Email Address').fill('staff@fixo.test');
await page.getByLabel('Password').fill('Test1234!');
await page.getByRole('button', { name: 'Sign In' }).click();
await page.waitForURL('**/dashboard', { timeout: 15_000 });
await shot('02_dashboard', 2500);

// ── Main queues ──────────────────────────────────────────────────────────────
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
  await shot(name, 2200);
}

// ── Detail views (navigate via the row's action link) ───────────────────────
for (const [route, name, linkRe] of [
  ['/disputes', '12_dispute_detail', /review/i],
  ['/users', '13_user_detail', /view|open|review|JOB-|@/i],
]) {
  await page.goto(`${BASE}${route}`);
  await page.waitForTimeout(2000);
  const firstRow = page.locator('table tbody tr').first();
  const link = firstRow.getByRole('link').first();
  if (await link.isVisible().catch(() => false)) {
    await link.click();
    await shot(name, 2000);
  } else {
    console.log(`skipped ${name} — no row links`);
  }
}

console.log('\nConsole errors seen:', consoleErrors.length);
for (const e of consoleErrors.slice(0, 20)) console.log('  ' + e);
await browser.close();
