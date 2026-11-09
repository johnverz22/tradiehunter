import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { fileURLToPath } from 'url';

const dirname = path.dirname(fileURLToPath(import.meta.url));
export const STAFF_AUTH_FILE = path.join(dirname, '../.auth/staff.json');

setup('authenticate as staff', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email Address').fill('staff@fixo.test');
  await page.getByLabel('Password').fill('Test1234!');
  await page.getByRole('button', { name: 'Sign In' }).click();

  await page.waitForURL('**/dashboard', { timeout: 15_000 });
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // Save authenticated cookie state for all subsequent tests.
  await page.context().storageState({ path: STAFF_AUTH_FILE });
});
