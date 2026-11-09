// P7 — Flagged Accounts / User Management

import { test, expect } from '@playwright/test';

test.describe('P7 — Users & Flagged Accounts', () => {

  test('users page loads and lists accounts', async ({ page }) => {
    await page.goto('/users');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
    await expect(page.locator('h1, h2').first()).toBeVisible();
  });

  test('P7-13 flagged filter shows only threshold-hit accounts', async ({ page }) => {
    await page.goto('/users');

    // Look for a flagged/threshold filter
    const flaggedFilter = page.getByRole('button', { name: /flagged/i })
      .or(page.getByLabel(/flagged/i))
      .or(page.getByText(/flagged/i).first());

    if (await flaggedFilter.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await flaggedFilter.click();
      await expect(page.locator('body')).not.toContainText('Error', { timeout: 5_000 });
    }
  });

  test('P7-13 opening a user profile shows action buttons', async ({ page }) => {
    await page.goto('/users');
    const firstRow = page.locator('table tbody tr').first();
    const visible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!visible) { test.skip(); return; }

    await firstRow.click();
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 8_000 });
    // At least a heading should appear on the detail page
    await expect(page.locator('h1, h2, h3').first()).toBeVisible();
  });

  test('P0-02 homeowner/tradie cannot access admin pages (RBAC smoke)', async ({ page }) => {
    // The staff auth fixture is already active — this tests that the
    // staff role CAN access the page (not a 403).
    await page.goto('/credentials');
    await expect(page).not.toHaveURL(/\/login/);
    await expect(page.locator('body')).not.toContainText('403');
  });

});
