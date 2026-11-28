import { defineConfig } from '@playwright/test';
import base from './playwright.config';

// Local override: host port 5173 is occupied by another project's dev server,
// and the API's CORS allow-list only covers :3000/:5173 — so tests run against
// the dockerized admin web (fixo-web) on :3000 instead of a local Vite.
export default defineConfig({
  ...base,
  use: { ...base.use, baseURL: 'http://localhost:3000' },
  webServer: undefined,
});
