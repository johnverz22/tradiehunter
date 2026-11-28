// Admin point of view for scripts/e2e-demo.py — a *headed* Chromium window
// driven at human speed (visible cursor, captions, typed input) so it can be
// screen-recorded next to the two iOS simulators.
//
// Not meant to be run directly. Env: E2E_MANIFEST (required: the persona-fabric
// manifest from scripts/e2e-personas.py; the admin logs in as its `staff`
// persona), DEMO_CTL, DEMO_WEB_URL, DEMO_API_URL, DEMO_PACE (seconds),
// DEMO_WINDOW (WxH+X+Y, default 1280x860+0+0),
// DEMO_SINGLE_FLOW ("true" = skip dispute / audit sub-flows, end after payout).
// Only credential rows whose file name contains "demo-tour-" (uploaded as the
// manifest tradie by the orchestrator) are ever touched, and every job, payment
// and dispute the admin acts on must be a job id recorded in the manifest.

import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const webRequire = createRequire(path.resolve(here, '../../web/package.json'));
const { chromium } = webRequire('@playwright/test');

const CTL = process.env.DEMO_CTL ?? 'http://127.0.0.1:5099';
const WEB = process.env.DEMO_WEB_URL ?? 'http://localhost:8090';
const API = process.env.DEMO_API_URL ?? 'http://localhost:5000/api';
const PACE = Number(process.env.DEMO_PACE ?? 3) * 1000;
const MANIFEST_PATH = process.env.E2E_MANIFEST;
if (!MANIFEST_PATH || !fs.existsSync(MANIFEST_PATH)) {
  console.error('admin_pov: E2E_MANIFEST is not set or the file is missing — run via scripts/e2e-demo.py');
  process.exit(2);
}
const readManifest = () => JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
const staff = readManifest().personas?.find((p) => p.role === 'staff');
if (!staff) {
  console.error('admin_pov: manifest has no staff persona (provision with e2e-personas.py --staff 1)');
  process.exit(2);
}
const EMAIL = staff.email;
const PASSWORD = staff.password;
const ACTOR = 'admin';
const SINGLE_FLOW = process.env.DEMO_SINGLE_FLOW === 'true';

/** The job must be one the fabric manifest knows (recorded by the orchestrator), never a hardcoded id. */
function assertManifestJob(id, what) {
  const jobs = readManifest().jobs ?? [];
  const hit = jobs.find((j) => Number(j.id) === Number(id) && String(j.scenario).startsWith('demo'));
  if (!hit) {
    throw new Error(`${what} job ${id} is not a demo job in the manifest (${jobs.map((j) => j.id).join(', ') || 'none'})`);
  }
  return hit;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const beat = (m = 1) => sleep(PACE * m);

async function ctl(method, p, body) {
  const res = await fetch(`${CTL}${p}`, {
    method,
    headers: { 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(10_000),
  });
  return res.json().catch(() => ({}));
}
const signal = (n) => ctl('POST', `/signal/${n}`);
const note = (message) => ctl('POST', '/note', { actor: ACTOR, message });

async function waitSignal(name, timeoutMs = 15 * 60_000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if ((await ctl('GET', '/state')).signals?.[name]) return;
    await sleep(500);
  }
  throw new Error(`timed out waiting for demo signal "${name}"`);
}
async function waitData(key, timeoutMs = 15 * 60_000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const v = (await ctl('GET', '/state')).data?.[key];
    if (v != null) return v;
    await sleep(500);
  }
  throw new Error(`timed out waiting for demo data "${key}"`);
}

async function apiToken(email, password) {
  const res = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
    signal: AbortSignal.timeout(10_000),
  });
  return (await res.json()).token;
}
async function apiGet(p, token) {
  const res = await fetch(`${API}${p}`, { headers: { authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(10_000) });
  return res.ok ? res.json() : null;
}

const OVERLAY = `
(() => {
  const mount = () => {
    if (document.getElementById('__demo_cursor')) return;
    const c = document.createElement('div');
    c.id = '__demo_cursor';
    c.style.cssText = 'position:fixed;z-index:2147483647;width:22px;height:22px;border-radius:50%;' +
      'background:rgba(255,160,0,.55);border:2px solid #ff9f00;pointer-events:none;left:-40px;top:-40px;' +
      'transform:translate(-50%,-50%);transition:left .05s linear,top .05s linear;';
    const cap = document.createElement('div');
    cap.id = '__demo_caption';
    cap.style.cssText = 'position:fixed;z-index:2147483647;left:50%;bottom:22px;transform:translateX(-50%);' +
      'background:rgba(15,23,42,.92);color:#fff;font:600 16px system-ui;padding:10px 20px;border-radius:999px;' +
      'pointer-events:none;display:none;box-shadow:0 6px 24px rgba(0,0,0,.35);';
    document.documentElement.append(c, cap);
    addEventListener('mousemove', (e) => { c.style.left = e.clientX + 'px'; c.style.top = e.clientY + 'px'; }, true);
    addEventListener('mousedown', () => { c.style.transform = 'translate(-50%,-50%) scale(.7)'; }, true);
    addEventListener('mouseup', () => { c.style.transform = 'translate(-50%,-50%)'; }, true);
  };
  if (document.documentElement) mount(); else addEventListener('DOMContentLoaded', mount);
  window.__demoCaption = (t) => { mount(); const cap = document.getElementById('__demo_caption');
    cap.textContent = t; cap.style.display = t ? 'block' : 'none'; };
})();`;

const [, , ...rest] = process.argv;
const win = (process.env.DEMO_WINDOW ?? '1280x860+0+0').match(/(\d+)x(\d+)\+(\d+)\+(\d+)/);
const [W, H, X, Y] = win ? win.slice(1).map(Number) : [1280, 860, 0, 0];

const browser = await chromium.launch({
  headless: false,
  args: [`--window-size=${W},${H}`, `--window-position=${X},${Y}`],
});
const context = await browser.newContext({ viewport: null });
await context.addInitScript(OVERLAY);
const page = await context.newPage();

async function caption(text) {
  console.log(`__DEMO_STEP__ ${ACTOR} | ${text}`);
  await ctl('POST', '/step', { actor: ACTOR, title: text });
  await page.evaluate((t) => window.__demoCaption?.(t), text).catch(() => {});
}

async function glide(locator) {
  await locator.scrollIntoViewIfNeeded();
  const box = await locator.boundingBox();
  if (box) await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 25 });
  await sleep(350);
}
async function click(locator) {
  await glide(locator);
  await locator.click();
  await beat(0.5);
}
async function type(locator, text) {
  await glide(locator);
  await locator.click();
  await locator.pressSequentially(text, { delay: 70 });
  await beat(0.4);
}
async function goto(p) {
  await page.goto(`${WEB}${p}`);
  await page.waitForLoadState('networkidle').catch(() => {});
  await beat();
}
/** Runs a UI scene; a failure is reported and the show goes on. */
async function scene(label, fn) {
  try {
    await fn();
  } catch (err) {
    const msg = String(err.message ?? err).split('\n')[0];
    console.error(`[admin] scene "${label}" failed: ${msg}`);
    await note(`scene "${label}" failed: ${msg}`);
  }
}

try {
  // Pre-roll: sit on the login page until everybody is ready.
  await page.goto(`${WEB}/login`);
  await signal('admin_ready');
  await waitSignal('go');

  await scene('login', async () => {
    await caption('Admin: signs in to the web console');
    await type(page.getByLabel('Email Address'), EMAIL);
    await type(page.getByLabel('Password', { exact: true }), PASSWORD);
    await click(page.getByRole('button', { name: 'Sign In' }));
    await page.waitForURL('**/dashboard', { timeout: 15_000 });
    await beat(2);
  });

  await scene('tour', async () => {
    await caption('Admin: platform overview — users and jobs');
    await goto('/users');
    await goto('/jobs');
    await goto('/dashboard');
  });

  await scene('credentials', async () => {
    await caption('Admin: reviews tradie credentials — approve one, reject one');
    await goto('/credentials');
    const rows = page.locator('table tbody tr', { hasText: /demo-tour-/ });
    await rows.first().waitFor({ state: 'visible', timeout: 10_000 });
    await click(rows.first().getByRole('button', { name: /approve/i }));
    await click(page.getByRole('dialog').getByRole('button', { name: /approve/i }));
    await beat(1.5);
    if ((await rows.count()) > 0) {
      await click(rows.first().getByRole('button', { name: /reject/i }));
      const dialog = page.getByRole('dialog');
      await type(dialog.getByRole('textbox').first(), 'Document is blurry — please re-upload a clear copy.');
      await click(dialog.getByRole('button', { name: /reject/i }));
      await beat(1.5);
    }
  });
  await signal('admin_creds_done');

  // Payment verification once the homeowner has uploaded a receipt.
  const jobId = Number(await waitData('job'));
  assertManifestJob(jobId, 'demo');
  await waitSignal('receipt_uploaded');
  await scene('payment', async () => {
    await caption('Admin: verifies the homeowner’s bank-transfer receipt');
    const token = await apiToken(EMAIL, PASSWORD);
    const pending = await apiGet('/admin/payments/pending?pageSize=100', token);
    const payment = (pending?.items ?? pending?.data ?? []).find((p) => p.jobId === jobId);
    if (!payment) throw new Error(`no pending payment for manifest job ${jobId} — refusing to verify another job's receipt`);
    await goto('/payments');
    const row = page.locator('table tbody tr', { hasText: payment.reference });
    await row.first().waitFor({ state: 'visible', timeout: 10_000 });
    await click(row.first().getByRole('button', { name: /^verify$/i }));
    await beat();
    await click(page.getByRole('dialog').getByRole('button', { name: /verify payment/i }));
    await beat(2);
  });
  await signal('payment_verified');

  // Job completed: show the job, then settle the tradie's payout.
  await waitSignal('completed');
  await scene('job', async () => {
    await caption('Admin: completed job — timeline and details');
    await goto(`/jobs/${jobId}`);
    await beat(2);
  });
  await scene('payout', async () => {
    await caption('Admin: processes the tradie payout');
    const token = await apiToken(EMAIL, PASSWORD);
    let item;
    for (let i = 0; i < 10 && !item; i++) {
      const q = await apiGet('/admin/payouts/pending?pageSize=100', token);
      item = (q?.items ?? q?.data ?? []).find((p) => p.jobId === jobId);
      if (!item) await sleep(1500);
    }
    await goto('/payouts');
    if (!item) {
      await note('no payout row for the demo job yet — payout step shown as queue only');
      return;
    }
    const row = page.locator('table tbody tr', { hasText: item.jobReferenceCode ?? item.jobTitle });
    const btn = row.first().getByRole('button', { name: /^process$/i });
    if (!(await btn.isVisible().catch(() => false)) || !(await btn.isEnabled().catch(() => false))) {
      await note(`payout for job ${jobId} not processable in the queue (missing or disabled) — queue shown as-is`);
      await beat(2);
      return;
    }
    await click(btn);
    const dialog = page.getByRole('dialog');
    // The input id is generated by <Field>, so target it by its label (placeholder as backup).
    const reference = dialog.getByLabel(/bank transfer reference/i).or(dialog.getByPlaceholder(/FP-2026/i));
    await type(reference.first(), `DEMO-${Date.now().toString().slice(-6)}`);
    await click(dialog.getByRole('button', { name: /mark as processed/i }));
    await beat(2);
  });

  // Dispute raised on the second job (skipped in --single-flow mode).
  if (!SINGLE_FLOW) {
    await waitSignal('dispute_opened');
    await scene('dispute', async () => {
      await caption('Admin: reviews and resolves the homeowner’s dispute');
      const disputeJob = await waitData('dispute_job');
      assertManifestJob(disputeJob, 'dispute');
      await goto('/disputes');
      await goto(`/disputes/${disputeJob}`);
      await beat(2);
      await page.mouse.wheel(0, 700);
      await beat();
      await click(page.getByRole('button', { name: /no action/i }));
      await click(page.getByRole('dialog').getByRole('button', { name: /no action/i }));
      await beat(2);
    });

    await scene('audit', async () => {
      await caption('Admin: audit log and settings — everything above is recorded');
      await goto('/audit-logs');
      await goto('/settings');
      await goto('/dashboard');
      await beat(2);
    });
  }
  await page.evaluate(() => window.__demoCaption?.('')).catch(() => {});
  await signal('admin_done');
  console.log('__DEMO_DONE__ admin');
} finally {
  await sleep(1500);
  await browser.close();
}
