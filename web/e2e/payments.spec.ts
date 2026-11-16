// P4 — Payment Queue
// Requires: at least one payment in PaymentReview state.
// Seed: run matching → payment upload flow first, or use scripts/p4-smoke.sh

import { test, expect } from '@playwright/test';

test.describe('P4 — Payment Queue', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/payments');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
  });

  test('P4-14 payment queue page loads without error', async ({ page }) => {
    // Basic smoke — if no payments are present the empty state should render
    await expect(page.locator('h1, h2').first()).toBeVisible();
  });

  test('P4-14 payment row shows dollar amount and FIXO- reference', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const rowVisible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!rowVisible) {
      test.skip();
      return;
    }
    await expect(firstRow.getByText(/\$\d+\.\d{2}/)).toBeVisible();
    await expect(firstRow.getByText(/FIXO-/)).toBeVisible();
  });

  test('P4-08 reject without reason is blocked', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const rowVisible = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!rowVisible) {
      test.skip();
      return;
    }

    // Rows carry inline Verify/Reject buttons; the review modal gates
    // submission by disabling "Reject payment" until a reason is entered.
    await firstRow.getByRole('button', { name: /reject/i }).click();
    const dialog = page.getByRole('dialog');
    await expect(
      dialog.getByRole('button', { name: /reject payment/i })
    ).toBeDisabled();
    await expect(dialog.getByText(/required/i).first()).toBeVisible();
  });

  test('P4-07 verifying a payment removes the row', async ({ page }) => {
    const rows = page.locator('table tbody tr');
    await rows.first().waitFor({ state: 'visible', timeout: 8_000 }).catch(() => {});
    // Data rows carry a Verify button; the loading/empty states don't, so
    // they double as the "queue is empty" check too.
    const verifyButtons = page.getByRole('button', { name: /^verify$/i });
    const count = await verifyButtons.count();
    if (count === 0) {
      test.skip();
      return;
    }

    await verifyButtons.first().click();
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /verify payment/i })
      .click();

    await expect(verifyButtons).toHaveCount(count - 1, { timeout: 8_000 });
  });

});

// P12-16 — v1.7 rewires payments to the end of the flow: rows are finished work,
// verifying completes the job, and an overdue view lists past-due payments.
test.describe('P12-16 — Overdue payments view', () => {

  test('overdue page loads and renders rows or the empty state', async ({ page }) => {
    await page.goto('/payments/overdue');
    await expect(page.locator('h1').first()).toHaveText(/overdue/i, { timeout: 10_000 });

    // Either overdue rows or the defensive empty state — never a crash screen.
    const rows = page.locator('table tbody tr');
    const hasRows = await rows.first().waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!hasRows) {
      await expect(page.locator('body')).toContainText(/no overdue payments|isn't available/i);
    }
  });

  test('payment queue links to the overdue view', async ({ page }) => {
    await page.goto('/payments');
    const link = page.getByRole('link', { name: /overdue payments/i }).first();
    await link.waitFor({ state: 'visible', timeout: 10_000 });
    await link.click();
    await expect(page.locator('h1').first()).toHaveText(/overdue/i);
  });

});
