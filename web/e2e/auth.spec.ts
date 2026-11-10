// Admin login and role-gate smoke tests.
// These run WITHOUT the staff auth state (separate project config).

import { test, expect } from '@playwright/test';

test.use({ storageState: { cookies: [], origins: [] } }); // no auth state

test.describe('Admin Auth', () => {

  test('login page renders email and password fields', async ({ page }) => {
    await page.goto('/login');
    await expect(page.getByLabel('Email Address')).toBeVisible();
    await expect(page.getByLabel('Password', { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
  });

  test('unauthenticated access to /dashboard redirects to /login', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForURL('**/login');
    await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
  });

  test('wrong credentials shows error message', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email Address').fill('staff@fixo.test');
    await page.getByLabel('Password', { exact: true }).fill('WrongPassword!');
    await page.getByRole('button', { name: 'Sign In' }).click();
    await expect(page.getByRole('alert')).toBeVisible({ timeout: 8_000 });
  });

});
