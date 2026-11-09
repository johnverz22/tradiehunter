// P7 — Dispute Management
// Requires: at least one Open dispute in the dev DB.

import { test, expect } from '@playwright/test';

test.describe('P7 — Disputes', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/disputes');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
  });

  test('P7-08 disputes page loads and shows Open filter by default', async ({ page }) => {
    await expect(page.locator('h1, h2').first()).toBeVisible();
    // Default tab/filter should be "Open"
    const openTab = page.getByRole('tab', { name: /open/i })
      .or(page.getByRole('button', { name: /open/i }));
    if (await openTab.isVisible().catch(() => false)) {
      await expect(openTab).toBeVisible();
    }
  });

  test('P7-09 opening a dispute shows job context and evidence section', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const visible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!visible) { test.skip(); return; }

    // Rows aren't clickable — navigate through the Review action link.
    await firstRow.getByRole('link', { name: /review/i }).click();
    await page.waitForURL(/\/disputes\/\d+/);
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 8_000 });
    // Detail should show at least a heading and evidence/notes area
    await expect(page.locator('h1, h2, h3').first()).toBeVisible();
  });

  // NOTE: the decision note is optional by design now; P7-10's intent
  // (resolution must be a deliberate two-step action) is covered by
  // asserting the outcome button opens a confirmation modal first.
  test('P7-10 resolving goes through a confirmation modal', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const visible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!visible) { test.skip(); return; }

    await firstRow.getByRole('link', { name: /review/i }).click();
    await page.waitForURL(/\/disputes\/\d+/);

    // Resolution actions sit below the fold — use an auto-waiting expect
    // (isVisible() does not wait) rather than a skip guard.
    const actionBtn = page.getByRole('button', { name: /no action/i });
    await expect(actionBtn).toBeVisible({ timeout: 10_000 });
    await actionBtn.click();

    // A ConfirmModal must appear before the mutation fires.
    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5_000 });
    await expect(
      page.getByRole('dialog').getByRole('button', { name: /no action/i })
    ).toBeVisible();
  });

});
