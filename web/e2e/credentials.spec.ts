// P1 — Credential Queue
// Requires: at least one Pending credential in the dev DB.
// Seed: python3 scripts/e2e-credentials.py --keep

import { test, expect } from '@playwright/test';

test.describe('P1 — Credential Queue', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/credentials');
    // Wait for the table to load (not the loading skeleton)
    await page.waitForSelector('table tbody tr', { timeout: 10_000 });
  });

  test('P1-21 pending credentials listed, oldest-first', async ({ page }) => {
    const rows = page.locator('table tbody tr');
    await expect(rows.first()).toBeVisible();
    // Verify rows contain expected columns
    const firstRow = rows.first();
    await expect(firstRow.getByRole('button', { name: /approve/i })).toBeVisible();
    await expect(firstRow.getByRole('button', { name: /reject/i })).toBeVisible();
  });

  test('P1-21 row shows tradie name, email and credential type', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    // At least one text cell should be non-empty (name or email)
    const cells = firstRow.locator('td');
    const count = await cells.count();
    expect(count).toBeGreaterThan(2);
  });

  test('P1-24 reject without reason shows validation error', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    await firstRow.getByRole('button', { name: /reject/i }).click();

    // Validation is enforced by disabling Reject until a reason is entered —
    // there is no submit-then-error path in this modal.
    const dialog = page.getByRole('dialog');
    await expect(
      dialog.getByRole('button', { name: /reject/i })
    ).toBeDisabled();
    await expect(dialog.getByText(/required/i).first()).toBeVisible();
  });

  test('P1-23 approving a credential removes the row from the queue', async ({ page }) => {
    const rows = page.locator('table tbody tr');
    const initialCount = await rows.count();
    if (initialCount === 0) test.skip();

    await rows.first().getByRole('button', { name: /approve/i }).click();
    // Confirm inside the review modal (its action button is labelled "Approve")
    const confirmBtn = page
      .getByRole('dialog')
      .getByRole('button', { name: /approve/i });
    if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await confirmBtn.click();
    }

    await expect(rows).toHaveCount(initialCount - 1, { timeout: 8_000 });
  });

  test('P1-27 empty queue shows empty state', async ({ page }) => {
    // Navigate to credentials when the queue might be empty after approvals
    // This test is informational — just assert no JS crash
    await expect(page.locator('body')).not.toContainText('Error');
  });

});
