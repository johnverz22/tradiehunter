const { chromium } = require('../web/node_modules/playwright');
const { readFileSync } = require('node:fs');
const path = require('node:path');

(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'chrome' });
  try {
    const page = await browser.newPage({ deviceScaleFactor: 3 });
    for (const name of ['il-01-light', 'il-01-dark', 'rings-3-navy']) {
      const base = path.resolve(__dirname, '../mobile/assets/illustrations', name);
      await page.setContent(`<style>body{margin:0;background:transparent}svg{display:block}</style>${readFileSync(`${base}.svg`, 'utf8')}`);
      await page.locator('svg').screenshot({ path: `${base}.png`, omitBackground: true });
    }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
