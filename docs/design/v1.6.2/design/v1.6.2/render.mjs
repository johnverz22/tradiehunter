// Renders every element marked [data-frame] in a design HTML file to a PNG.
// Usage: node render.mjs <html-file> [out-dir]
// Frames are named via data-frame="name" -> <out-dir>/<name>.png
// Run from docs/design/v1.6/ with: node --experimental-vm-modules render.mjs ...
// Uses the repo's installed playwright (web/node_modules) + system Chrome.
import { chromium } from '../../../web/node_modules/playwright-core/index.mjs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const htmlFile = path.resolve(process.argv[2]);
const outDir = path.resolve(process.argv[3] ?? path.join(here, 'frames'));

const browser = await chromium.launch({ channel: 'chrome', headless: true });
try {
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.goto('file://' + htmlFile, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts?.ready);
  const frames = await page.$$('[data-frame]');
  for (const el of frames) {
    const name = await el.getAttribute('data-frame');
    await el.screenshot({ path: path.join(outDir, `${name}.png`) });
    console.log('rendered', name);
  }
  console.log(`${frames.length} frame(s) -> ${outDir}`);
} finally {
  await browser.close();
}
