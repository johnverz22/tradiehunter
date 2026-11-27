import { test, expect } from '@playwright/test';

// Staff (non-superadmin) sees the Quotes card but the PUT is refused (403).
// Runs under the default `chromium` project with the staff storage state.

const API = (process.env.VITE_API_URL ?? 'http://localhost:5000/api').replace(/\/+$/, '');

type QuoteSettings = { boardWindowHours: number; validityHours: number };

test.describe('Admin quote settings (staff is read-only)', () => {
  test('staff sees the card but saving is refused', async ({ page, request }) => {
    // Staff can read the settings (GET is open to admin-area roles).
    const res = await request.get(`${API}/admin/settings/quotes`);
    expect(res.ok()).toBeTruthy();
    const current = (await res.json()) as QuoteSettings;

    await page.goto('/settings');
    const region = page.getByRole('region', { name: 'Quotes' });
    await expect(region).toBeVisible();

    const board = region.getByLabel('Board window (hours)');
    const changed = current.boardWindowHours === 50 ? 51 : 50;
    await board.fill(String(changed));
    await region.getByRole('button', { name: 'Save quote settings' }).click();

    await expect(
      region.getByText('Failed to save quote settings. Only a Superadmin can change them.'),
    ).toBeVisible();
  });
});
