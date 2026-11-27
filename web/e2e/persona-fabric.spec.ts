// Plan 08 P4 — Persona Fabric web admin verification.
// Consumes E2E_MANIFEST (written by scripts/e2e-personas.py + e2e-journey.py),
// logs in as the manifest staff persona, and asserts job, payment, dispute, and
// user state in the rendered React admin UI matches the API tier.

import fs from 'node:fs';
import path from 'node:path';
import { test, expect } from '@playwright/test';

interface ManifestPersona {
  role: string;
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  userId: string;
}

interface ManifestJob {
  id: number;
  scenario: string;
}

interface Manifest {
  runId: string;
  apiUrl: string;
  personas: ManifestPersona[];
  jobs?: ManifestJob[];
}

function loadManifest(): Manifest | null {
  const rawPath = process.env.E2E_MANIFEST;
  if (!rawPath) return null;
  const resolved = path.isAbsolute(rawPath)
    ? rawPath
    : path.resolve(process.cwd(), rawPath);
  if (!fs.existsSync(resolved)) return null;
  return JSON.parse(fs.readFileSync(resolved, 'utf-8')) as Manifest;
}

const manifest = loadManifest();

test.use({ storageState: { cookies: [], origins: [] } });

test.describe('P4 — Persona Fabric Admin Verification', () => {
  test.skip(!manifest, 'E2E_MANIFEST not set or file missing');

  test('staff logs in and verifies API-created jobs, payment, dispute, and users', async ({ page }) => {
    const staff = manifest!.personas.find((p) => p.role === 'staff');
    const homeowner = manifest!.personas.find((p) => p.role === 'homeowner');
    const happyJob = [...(manifest!.jobs ?? [])]
      .reverse()
      .find((j) => j.scenario === 'happy-path');
    const disputeJob = [...(manifest!.jobs ?? [])]
      .reverse()
      .find((j) => j.scenario === 'dispute-attachments-reviews');

    expect(staff, 'manifest missing staff persona').toBeTruthy();
    expect(happyJob, 'manifest missing happy-path job').toBeTruthy();

    // P4.3: Staff persona logs into admin.
    await page.goto('/login');
    await page.getByLabel('Email Address').fill(staff!.email);
    await page.getByLabel('Password', { exact: true }).fill(staff!.password);
    await page.getByRole('button', { name: 'Sign In' }).click();
    await page.waitForURL((url) => !url.pathname.endsWith('/login'), { timeout: 15_000 });

    // P4.3 / P4.4: Verify happy-path job detail matches API state, personas, and chat.
    await page.goto(`/jobs/${happyJob!.id}`);
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
    await expect(page.locator('body')).toContainText('Completed', { timeout: 10_000 });
    await expect(page.locator('body')).toContainText(`${homeowner!.firstName} ${homeowner!.lastName}`, { timeout: 10_000 });
    await expect(page.locator('body')).toContainText('Chat transcript (2)', { timeout: 10_000 });

    // P4.3: Payment queue loads cleanly for this staff user.
    await page.goto('/payments');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
    await expect(page.locator('h1, h2').first()).toBeVisible();

    // P4.5: Disputes queue + resolved dispute detail (if present in manifest).
    await page.goto('/disputes');
    await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
    if (disputeJob) {
      await page.goto(`/disputes/${disputeJob.id}`);
      await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
      await expect(page.locator('body')).toContainText(/Resolved/i, { timeout: 10_000 });
    }

    // P4.4: User detail page shows the manifest homeowner.
    if (homeowner) {
      await page.goto(`/users/${homeowner.userId}`);
      await expect(page.locator('body')).not.toContainText('Error', { timeout: 10_000 });
      await expect(page.locator('body')).toContainText(homeowner.email, { timeout: 10_000 });
    }

    // N8.3: Staff sees the notification bell badge (unread count from receipt/dispute uploads).
    const bell = page.getByRole('button', { name: /Notifications \(\d+ unread\)/i });
    await expect(bell).toBeVisible({ timeout: 10_000 });
  });
});
