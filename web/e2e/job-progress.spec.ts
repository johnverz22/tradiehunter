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
  const rows = page.locator('table tbody tr:not([aria-hidden="true"])');
  const hasRows = await rows.first().waitFor({ state: 'visible', timeout: 10_000 }).then(() => true).catch(() => false);
  if (!hasRows) return false;

  // Try to find a row with the matching status badge text.
  const count = await rows.count().catch(() => 0);

  for (let i = 0; i < count; i++) {
    const row = rows.nth(i);
    const badgeText = await row.locator('[data-testid="status-badge"], .badge, .pill, .status-badge').first().textContent().catch(() => '');
    if (badgeText.trim().toLowerCase() === status.toLowerCase()) {
      await row.click();
      await page.waitForURL(/\/jobs\/\d+/);
      await stepper(page).waitFor({ state: 'visible', timeout: 10_000 });
      return true;
    }
  }
  return false;
}

/** The stepper list, found by role and accessible name (no class selectors). */
function stepper(page: Page) {
  return page.getByRole('list', { name: 'Job progress' });
}

/** The stepper's steps, in order. */
function steps(page: Page) {
  return stepper(page).getByRole('listitem');
}

/** The active step (aria-current="step"). */
function activeStep(page: Page) {
  return stepper(page).locator('[aria-current="step"]');
}

/** Return the aria-current="step" text from the stepper (label, plus sublabel if any). */
async function activeStepLabel(page: Page): Promise<string | null> {
  const activeLi = activeStep(page);
  await activeLi.waitFor({ state: 'visible', timeout: 10_000 }).catch(() => {});
  const visible = await activeLi.isVisible().catch(() => false);
  if (!visible) return null;
  return activeLi.textContent();
}

/** Return the step text for a step at the given 0-based index. */
async function stepLabelAt(page: Page, index: number): Promise<string | null> {
  const item = steps(page).nth(index);
  await item.waitFor({ state: 'visible', timeout: 10_000 }).catch(() => {});
  return item.textContent().catch(() => null);
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
    const firstRow = page.locator('table tbody tr:not([aria-hidden="true"])').first();
    const hasRow = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);
    await stepper(page).waitFor({ state: 'visible', timeout: 10_000 });

    // Expect exactly 4 steps in the stepper list.
    const items = steps(page);
    await expect(items).toHaveCount(4, { timeout: 8_000 });

    // Verify step labels match the mobile naming convention.
    await expect(items.nth(0)).toContainText('Requested');
    await expect(items.nth(1)).toContainText('Booked');
    await expect(items.nth(2)).toContainText('In progress');
    await expect(items.nth(3)).toContainText('Done');
  });

  // ── Booked job ───────────────────────────────────────────────────────────────

  test('Booked job: active step is Booked (index 1)', async ({ page }) => {
    const found = await openJobWithStatus(page, 'Booked');
    if (!found) { test.skip(); return; }

    const label = await activeStepLabel(page);
    expect(label?.trim()).toBe('Booked');

    // Step at index 0 (Requested) should be rendered as "done" — no aria-current.
    const step0 = steps(page).nth(0);
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

    // The sublabel "Awaiting confirmation" is rendered inside the active step.
    await expect(activeStep(page)).toContainText('Awaiting confirmation');
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
    await expect(activeStep(page)).toContainText('Cancelled');
  });

  // ── Accessibility ─────────────────────────────────────────────────────────────

  test('stepper has role="list" and aria-label', async ({ page }) => {
    const firstRow = page.locator('table tbody tr:not([aria-hidden="true"])').first();
    const hasRow = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);

    await expect(stepper(page)).toBeVisible({ timeout: 8_000 });
  });

  test('sr-only summary text is present', async ({ page }) => {
    const firstRow = page.locator('table tbody tr:not([aria-hidden="true"])').first();
    const hasRow = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);
    await stepper(page).waitFor({ state: 'visible', timeout: 10_000 });

    // The <span class="sr-only"> should contain "Step N of 4".
    const srOnly = page.locator('.sr-only');
    await expect(srOnly.first()).toContainText(/Step \d+ of 4/, { timeout: 5_000 });
  });

  // ── No manual refresh ─────────────────────────────────────────────────────────

  test('status updates on its own: no manual refresh button or "ago" caption', async ({ page }) => {
    const firstRow = page.locator('table tbody tr:not([aria-hidden="true"])').first();
    const hasRow = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);
    await stepper(page).waitFor({ state: 'visible', timeout: 10_000 });

    await expect(page.getByRole('button', { name: /refresh job status/i })).toHaveCount(0);
    await expect(page.getByText(/just now|\d+[smh] ago/)).toHaveCount(0);
  });

  // ── Connectors ───────────────────────────────────────────────────────────────

  test('first step draws no connector; each later step draws one back', async ({ page }) => {
    const firstRow = page.locator('table tbody tr:not([aria-hidden="true"])').first();
    const hasRow = await firstRow.waitFor({ state: 'visible', timeout: 8_000 }).then(() => true).catch(() => false);
    if (!hasRow) { test.skip(); return; }

    await firstRow.click();
    await page.waitForURL(/\/jobs\/\d+/);
    await stepper(page).waitFor({ state: 'visible', timeout: 10_000 });

    // The kit draws each connector as the ::before of the step it leads into
    // (horizontal layout, >= 768 px; the default test viewport is wider).
    const before = (index: number) =>
      steps(page).nth(index).evaluate((el) => window.getComputedStyle(el, '::before').display);
    await expect(steps(page)).toHaveCount(4, { timeout: 8_000 });
    expect(await before(0)).toBe('none');
    expect(await before(3)).not.toBe('none');
  });

});
