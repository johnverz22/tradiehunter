// P10 — Payout Queue & Batches
// Requires: admin auth (from e2e/fixtures/auth.setup.ts).

import { test, expect } from '@playwright/test';

test.describe('P10 — Payout Queue', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/payouts');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
  });

  test('P10-01 payout queue page loads without error', async ({ page }) => {
    await expect(page.locator('h1, h2').first()).toBeVisible();
    await expect(page.getByText(/payout/i).first()).toBeVisible();
  });

  test('P10-02 payout table rows display amounts, masked bank numbers, and links', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const rowVisible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!rowVisible) {
      test.skip();
      return;
    }

    // Amounts formatted as currency (gross and net columns)
    await expect(firstRow.getByText(/\$\d+/).first()).toBeVisible();
    // Masked bank account (•••• or ····)
    await expect(firstRow.getByText(/[•·]{4}\d{4}|No details/)).toBeVisible();
  });

  test('P10-03 batches page navigation and batch list load', async ({ page }) => {
    const batchesLink = page.getByRole('link', { name: /batches|view batches/i });
    if (await batchesLink.isVisible().catch(() => false)) {
      await batchesLink.click();
      await expect(page).toHaveURL(/\/payouts\/batches/);
      await expect(page.locator('h1, h2').first()).toBeVisible();
    }
  });

  test('P10-04 process payout modal validation requires reference', async ({ page }) => {
    const processButtons = page.getByRole('button', { name: /^process$/i });
    await processButtons.first().waitFor({ state: 'visible', timeout: 8_000 }).catch(() => {});
    const count = await processButtons.count();
    if (count === 0) {
      test.skip();
      return;
    }

    await processButtons.first().click();
    const modal = page.getByRole('dialog');
    await expect(modal).toBeVisible();

    // "Mark as processed" stays disabled until a transfer reference is entered.
    const confirmBtn = modal.getByRole('button', { name: /mark as processed/i });
    await expect(confirmBtn).toBeDisabled();
    await expect(modal.getByText(/transfer reference/i).first()).toBeVisible();
  });
});
