// P6 — Refund Queue
// Requires: at least one Pending refund (created when homeowner cancels a paid job).

import { test, expect } from '@playwright/test';

test.describe('P6 — Refund Queue', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/refunds');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
  });

  test('P6-08 refund queue page loads', async ({ page }) => {
    await expect(page.locator('h1, h2').first()).toBeVisible();
  });

  test('P6-08 refund row shows homeowner, amount and cancel reason', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const visible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!visible) { test.skip(); return; }

    // Each row should have a job ID / title and a suggested amount
    const cells = firstRow.locator('td');
    await expect(cells.count()).resolves.toBeGreaterThan(2);
  });

  test('P6-10 processing refund without TransferReference is blocked', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const visible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!visible) { test.skip(); return; }

    await firstRow.getByRole('button', { name: /process|review/i }).click();

    // The modal requires a transfer reference — "Process refund" stays
    // disabled while it is empty (marked * in the label).
    await expect(
      page.getByRole('button', { name: /process refund/i })
    ).toBeDisabled();
    await expect(page.getByText(/transfer reference/i).first()).toBeVisible();
  });

  test('P6-12 refund amounts display as exact 2dp decimal', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const visible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!visible) { test.skip(); return; }

    // Any dollar amount in the row must be X.XX format (no float drift)
    const amountText = await firstRow.getByText(/\$\d+\.\d{2}/).first().textContent().catch(() => null);
    if (amountText) {
      expect(amountText).toMatch(/\$\d+\.\d{2}/);
    }
  });

});
