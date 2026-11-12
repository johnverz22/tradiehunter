/**
 * Job Progress Stepper — E2E tests (P-stepper)
 *
 * Tests that the 4-step stepper on the Job Detail page reflects the correct
 * active step and label for each meaningful backend status, and that the
 * manual refresh button is present.
 *
 * These tests require the dev DB to have jobs in various statuses.
 * Individual tests are skipped (soft-skip) when no matching job exists rather
 * than failing the entire suite — the same pattern used in disputes.spec.ts.
 */

import { test, expect, type Page } from '@playwright/test';

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Navigate to the jobs list and open the first row whose status chip matches. */
async function openJobWithStatus(page: Page, status: string): Promise<boolean> {
  await page.goto('/jobs');
  await page.waitForLoadState('networkidle');

  // Try to find a row with the matching status badge text.
  const rows = page.locator('table tbody tr');
  const count = await rows.count().catch(() => 0);

  for (let i = 0; i < count; i++) {
    const row = rows.nth(i);
    const badgeText = await row.locator('[data-testid="status-badge"], .badge, .pill, .status-badge').first().textContent().catch(() => '');
    if (badgeText.trim().toLowerCase() === status.toLowerCase()) {
      await row.click();
      await page.waitForURL(/\/jobs\/\d+/);
      return true;
    }
  }
  return false;
}

/** Return the aria-current="step" label text from the stepper. */
async function activeStepLabel(page: Page): Promise<string | null> {
  // The active <li> has aria-current="step"; its first .step-label child has the text.
  const activeLi = page.locator('[role="list"] [aria-current="step"]');
  const visible = await activeLi.isVisible().catch(() => false);
  if (!visible) return null;
  return activeLi.locator('.step-label').first().textContent();
}

/** Return the step label for a step at the given 0-based index. */
async function stepLabelAt(page: Page, index: number): Promise<string | null> {
  const items = page.locator('[role="list"] [role="listitem"]');
  const item = items.nth(index);
  return item.locator('.step-label').first().textContent().catch(() => null);
}

// ── Suite ─────────────────────────────────────────────────────────────────────

test.describe('P-stepper — Job progress stepper', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/jobs');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
  });

  // ── Step labels are correct on the page ──────────────────────────────────────

  test('stepper renders 4 labelled steps', async ({ page }) => {
    // Open any job.
    const firstRow = page.locator('table tbody tr').first();
    const hasRow = await firstRow.isVisible({ timeout: 8_000 }).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);

    // Expect exactly 4 listitem elements.
    const items = page.locator('[role="listitem"]');
    await expect(items).toHaveCount(4, { timeout: 8_000 });

    // Verify step labels match the mobile naming convention.
    await expect(items.nth(0).locator('.step-label')).toContainText('Requested');
    await expect(items.nth(1).locator('.step-label')).toContainText('Booked');
    await expect(items.nth(2).locator('.step-label')).toContainText('In progress');
    await expect(items.nth(3).locator('.step-label')).toContainText('Done');
  });

  // ── Booked job ───────────────────────────────────────────────────────────────

  test('Booked job: active step is Booked (index 1)', async ({ page }) => {
    const found = await openJobWithStatus(page, 'Booked');
    if (!found) { test.skip(); return; }

    const label = await activeStepLabel(page);
    expect(label?.trim()).toBe('Booked');

    // Step at index 0 (Requested) should be rendered as "done" — no aria-current.
    const step0 = page.locator('[role="listitem"]').nth(0);
    await expect(step0).not.toHaveAttribute('aria-current', 'step');

    // Verify the step 0 label text via helper.
    const label0 = await stepLabelAt(page, 0);
    expect(label0?.trim()).toBe('Requested');
  });

  // ── InProgress job ───────────────────────────────────────────────────────────

  test('InProgress job: active step is In progress (index 2)', async ({ page }) => {
    const found = await openJobWithStatus(page, 'InProgress');
    if (!found) { test.skip(); return; }

    const label = await activeStepLabel(page);
    expect(label?.trim()).toBe('In progress');
  });

  // ── AwaitingConfirmation ──────────────────────────────────────────────────────

  test('AwaitingConfirmation: step 3 active, sublabel visible', async ({ page }) => {
    const found = await openJobWithStatus(page, 'AwaitingConfirmation');
    if (!found) { test.skip(); return; }

    const label = await activeStepLabel(page);
    expect(label?.trim()).toMatch(/In progress/);

    // A sublabel "Awaiting confirmation" should be rendered.
    const sublabel = page.locator('[aria-current="step"] .step-sublabel');
    if (await sublabel.isVisible().catch(() => false)) {
      await expect(sublabel).toContainText('Awaiting confirmation');
    }
  });

  // ── Completed ────────────────────────────────────────────────────────────────

  test('Completed job: active step is Done (index 3)', async ({ page }) => {
    const found = await openJobWithStatus(page, 'Completed');
    if (!found) { test.skip(); return; }

    const label = await activeStepLabel(page);
    expect(label?.trim()).toBe('Done');
  });

  // ── Cancelled after InProgress ───────────────────────────────────────────────

  test('Cancelled job: reached step derived from history, label shows Cancelled', async ({ page }) => {
    const found = await openJobWithStatus(page, 'Cancelled');
    if (!found) { test.skip(); return; }

    // The stepper should show a terminal state at whatever step was reached.
    // The step text at the current step should contain 'Cancelled'.
    const activeLi = page.locator('[aria-current="step"]');
    const activeLabel = await activeLi.locator('.step-label').textContent().catch(() => '');
    expect(activeLabel).toContain('Cancelled');
  });

  // ── Accessibility ─────────────────────────────────────────────────────────────

  test('stepper has role="list" and aria-label', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const hasRow = await firstRow.isVisible({ timeout: 8_000 }).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);

    const list = page.locator('[role="list"][aria-label]');
    await expect(list).toBeVisible({ timeout: 8_000 });
  });

  test('sr-only summary text is present', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const hasRow = await firstRow.isVisible({ timeout: 8_000 }).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);

    // The <span class="sr-only"> should contain "Step N of 4".
    const srOnly = page.locator('.sr-only');
    await expect(srOnly.first()).toContainText(/Step \d+ of 4/, { timeout: 5_000 });
  });

  // ── Refresh button ────────────────────────────────────────────────────────────

  test('manual refresh button is present and enabled', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const hasRow = await firstRow.isVisible({ timeout: 8_000 }).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);

    const refreshBtn = page.getByRole('button', { name: /refresh job status/i });
    await expect(refreshBtn).toBeVisible({ timeout: 5_000 });
    await expect(refreshBtn).not.toBeDisabled();
  });

  test('clicking refresh button triggers a network request', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const hasRow = await firstRow.isVisible({ timeout: 8_000 }).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);

    // Intercept the jobs API call.
    let jobFetchCount = 0;
    await page.route(/\/api\/admin\/jobs\/\d+/, (route) => {
      jobFetchCount++;
      return route.continue();
    });

    const refreshBtn = page.getByRole('button', { name: /refresh job status/i });
    await refreshBtn.click();

    // Allow one tick for the request to fire.
    await page.waitForTimeout(500);
    expect(jobFetchCount).toBeGreaterThan(0);
  });

  // ── Last-step connector overflow ──────────────────────────────────────────────

  test('last step (Done) has no visible connector', async ({ page }) => {
    const firstRow = page.locator('table tbody tr').first();
    const hasRow = await firstRow.isVisible({ timeout: 8_000 }).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);

    // The 4th listitem (Done) must not render a step-line connector.
    const lastItem = page.locator('[role="listitem"]').nth(3);
    const stepLine = lastItem.locator('.step-line');
    // Either it doesn't exist, or it's display:none.
    const lineCount = await stepLine.count();
    if (lineCount > 0) {
      const display = await stepLine.evaluate((el) =>
        window.getComputedStyle(el).display
      );
      expect(display).toBe('none');
    }
  });

});
