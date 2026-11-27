import { test, expect } from '@playwright/test';

// Superadmin-only admin settings spec (project: chromium-superadmin, plan 10 Q7.2).
// State is stateful, so run serially and restore the original values in afterAll.

const API = (process.env.VITE_API_URL ?? 'http://localhost:5000/api').replace(/\/+$/, '');

type QuoteSettings = { boardWindowHours: number; validityHours: number };

test.describe.configure({ mode: 'serial' });

test.describe('Admin quote settings (superadmin)', () => {
  let original: QuoteSettings;

  test.beforeAll(async ({ request }) => {
    const res = await request.get(`${API}/admin/settings/quotes`);
    expect(res.ok(), `GET /admin/settings/quotes failed: ${res.status()}`).toBeTruthy();
    original = (await res.json()) as QuoteSettings;
  });

  test.afterAll(async ({ request }) => {
    if (!original) return;
    const res = await request.put(`${API}/admin/settings/quotes`, { data: original });
    expect(res.ok(), `restore PUT /admin/settings/quotes failed: ${res.status()}`).toBeTruthy();
  });

  test('renders the current values and disables Save', async ({ page }) => {
    const loaded = page.waitForResponse(
      (r) => r.url().includes('/api/admin/settings/quotes') && r.request().method() === 'GET',
    );
    await page.goto('/settings');
    const body = (await (await loaded).json()) as QuoteSettings;

    const region = page.getByRole('region', { name: 'Quotes' });
    await expect(region).toBeVisible();

    await expect(region.getByLabel('Board window (hours)')).toHaveValue(String(body.boardWindowHours));
    await expect(region.getByLabel('Quote validity (hours)')).toHaveValue(String(body.validityHours));
    await expect(region.getByRole('button', { name: 'Save quote settings' })).toBeDisabled();
  });

  test('saves a changed board window and persists it', async ({ page }) => {
    await page.goto('/settings');
    const region = page.getByRole('region', { name: 'Quotes' });
    await expect(region).toBeVisible();

    const board = region.getByLabel('Board window (hours)');
    // Guarantee a real change even if a prior run left 48 behind.
    const newBoard = original.boardWindowHours === 48 ? 49 : 48;

    const putPromise = page.waitForRequest(
      (r) => r.url().includes('/api/admin/settings/quotes') && r.method() === 'PUT',
    );
    await board.fill(String(newBoard));
    await region.getByRole('button', { name: 'Save quote settings' }).click();

    const sent = (await putPromise).postDataJSON() as QuoteSettings;
    expect(sent.boardWindowHours).toBe(newBoard);
    expect(typeof sent.validityHours).toBe('number');

    await expect(region.getByText('Quote settings saved.')).toBeVisible();

    await page.reload();
    await expect(
      page.getByRole('region', { name: 'Quotes' }).getByLabel('Board window (hours)'),
    ).toHaveValue(String(newBoard));
  });

  test('rejects invalid input without sending a request', async ({ page }) => {
    await page.goto('/settings');
    const region = page.getByRole('region', { name: 'Quotes' });
    await expect(region).toBeVisible();

    let putFired = false;
    page.on('request', (r) => {
      if (r.url().includes('/api/admin/settings/quotes') && r.method() === 'PUT') putFired = true;
    });

    const board = region.getByLabel('Board window (hours)');
    const save = region.getByRole('button', { name: 'Save quote settings' });

    await board.fill('0');
    await save.click();
    await expect(region.getByText('Minimum 1 hour')).toBeVisible();

    await board.fill('721');
    await save.click();
    await expect(region.getByText('Maximum 720 hours (30 days)')).toBeVisible();

    await board.fill('1.5');
    await save.click();
    await expect(region.getByText('Whole hours only')).toBeVisible();

    expect(putFired).toBe(false);
  });
});
