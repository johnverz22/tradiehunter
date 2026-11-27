import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { fileURLToPath } from 'url';

const dirname = path.dirname(fileURLToPath(import.meta.url));
export const SUPERADMIN_AUTH_FILE = path.join(dirname, '../.auth/superadmin.json');

// Superadmin defaults mirror scripts/e2e-personas.py and appsettings.Development.json.
const EMAIL = process.env.FIXO_ADMIN_EMAIL ?? 'admin@fixo.nz';
const PASSWORD = process.env.FIXO_ADMIN_PASSWORD ?? 'Admin1!Fixo';

setup('authenticate as superadmin', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email Address').fill(EMAIL);
  await page.getByLabel('Password').fill(PASSWORD);
  await page.getByRole('button', { name: 'Sign In' }).click();

  await page.waitForURL('**/dashboard', { timeout: 15_000 });
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // Save authenticated cookie state for the superadmin-only quote-settings spec.
  await page.context().storageState({ path: SUPERADMIN_AUTH_FILE });
});
