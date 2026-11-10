import { test, expect } from '@playwright/test';

const ROUTES = [
  '/dashboard',
  '/users',
  '/jobs',
  '/credentials',
  '/payments',
  '/payouts',
  '/payouts/batches',
  '/refunds',
  '/disputes',
  '/audit-logs',
  '/settings',
];

test.describe('Responsive Layout & Interaction', () => {

  for (const route of ROUTES) {
    test(`no horizontal overflow on ${route}`, async ({ page }) => {
      await page.goto(route);
      await page.waitForLoadState('domcontentloaded');
      await page.waitForTimeout(600);

      const hasNoOverflow = await page.evaluate(() => {
        const root = document.documentElement;
        const scrolling = document.scrollingElement || root;
        // Allow 1px subpixel rendering rounding tolerance
        return scrolling.scrollWidth <= root.clientWidth + 1;
      });

      expect(hasNoOverflow).toBe(true);
    });
  }

  test('nav drawer opens and closes with keyboard and Esc, restores focus to menu button', async ({ page }) => {
    await page.goto('/dashboard');
    const menuButton = page.getByRole('button', { name: /open navigation menu/i });
    
    // Only present on mobile / tablet (<1024px)
    if (await menuButton.isVisible({ timeout: 2000 }).catch(() => false)) {
      await menuButton.click();
      const drawer = page.getByRole('dialog', { name: /navigation menu/i });
      await expect(drawer).toBeVisible();

      // Press Escape to close
      await page.keyboard.press('Escape');
      await expect(drawer).not.toBeVisible({ timeout: 3000 });

      // Focus returns to the menu button
      await expect(menuButton).toBeFocused();
    }
  });

  test('primary actions are reachable across queues', async ({ page }) => {
    // Check credentials queue
    await page.goto('/credentials');
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(500);
    const approveBtn = page.getByRole('button', { name: /approve/i }).first();
    const emptyCreds = page.getByText(/no credentials awaiting review/i);
    await expect(approveBtn.or(emptyCreds)).toBeVisible({ timeout: 8000 });

    // Check payments queue
    await page.goto('/payments');
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(500);
    const verifyBtn = page.getByRole('button', { name: /^verify$/i }).first();
    const emptyPayments = page.getByText(/no payments awaiting review/i);
    await expect(verifyBtn.or(emptyPayments)).toBeVisible({ timeout: 8000 });

    // Check payouts queue
    await page.goto('/payouts');
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(500);
    const processPayoutBtn = page.getByRole('button', { name: /^process$/i }).first();
    const emptyPayouts = page.getByText(/no payouts awaiting payout/i);
    await expect(processPayoutBtn.or(emptyPayouts)).toBeVisible({ timeout: 8000 });

    // Check refunds queue
    await page.goto('/refunds');
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(500);
    const processRefundBtn = page.getByRole('button', { name: /^process$/i }).first();
    const emptyRefunds = page.getByText(/no pending refunds/i);
    await expect(processRefundBtn.or(emptyRefunds)).toBeVisible({ timeout: 8000 });
  });

  test('modal action: review payment modal opens and has reachable verify button', async ({ page }) => {
    await page.goto('/payments');
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(500);

    const verifyBtn = page.getByRole('button', { name: /^verify$/i }).first();
    if (await verifyBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await verifyBtn.click();
      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible();
      const confirmBtn = dialog.getByRole('button', { name: /verify payment/i });
      await expect(confirmBtn).toBeVisible();

      // Close modal
      const cancelBtn = dialog.getByRole('button', { name: /cancel/i });
      await cancelBtn.click();
      await expect(dialog).not.toBeVisible({ timeout: 3000 });
    }
  });

  test('modal action: credential reject flow can enter reason and action on mobile', async ({ page }) => {
    await page.goto('/credentials');
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(500);

    const rejectBtn = page.getByRole('button', { name: /reject/i }).first();
    if (await rejectBtn.isVisible({ timeout: 4000 }).catch(() => false)) {
      await rejectBtn.click();
      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible();

      const reasonInput = page.getByLabel(/reason for rejection/i);
      await expect(reasonInput).toBeVisible();
      await reasonInput.fill('Licence is unreadable in current upload.');

      const submitRejectBtn = dialog.getByRole('button', { name: /^reject$/i });
      await expect(submitRejectBtn).toBeEnabled();

      // Cancel to avoid modifying test state
      const cancelBtn = dialog.getByRole('button', { name: /cancel/i });
      await cancelBtn.click();
      await expect(dialog).not.toBeVisible({ timeout: 3000 });
    }
  });

});
