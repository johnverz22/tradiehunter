#!/usr/bin/env node
// Renders every mockup frame in docs/design/mobile/mockups/index.html to a PNG so it
// can be compared with an app capture (fix plan P-06, task 0.4).
//
//   node docs/design/mobile/tools/mockup-shots.mjs [--out <dir>] [--scale 3] [--only id[,id]] [--list]
//
// Output: <out>/<screen-id>-light.png and <out>/<screen-id>-dark.png
// (default out: docs/design/mobile/mockups/png). Screen ids come from the
// `data-screen` attribute build.mjs writes on each <figure> (same ids as
// ast/screens.mjs), so regenerate the mockup first if it is stale:
//   node docs/design/mobile/tools/build.mjs
//
// Needs Playwright, which is deliberately not a dependency of this package:
//   npm i --no-save playwright && npx playwright install chromium
// The mockup loads Lexend + Source Sans 3 from Google Fonts, so run this with
// network access or the frames render in a fallback font.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : dflt;
};
const OUT = path.resolve(opt('out', `${ROOT}/mockups/png`));
const SCALE = Number(opt('scale', '3')); // 390 pt wide frame x3 = 1170 px, close to a 1206 px phone capture
const ONLY = opt('only', '') ? new Set(opt('only', '').split(',').map((s) => s.trim())) : null;
const HTML = path.join(ROOT, 'mockups', 'index.html');
const THEMES = ['light', 'dark'];

if (!fs.existsSync(HTML)) {
  console.error(`missing ${HTML}; run: node docs/design/mobile/tools/build.mjs`);
  process.exit(1);
}
if (!fs.readFileSync(HTML, 'utf8').includes('data-screen="')) {
  console.error('mockups/index.html has no data-screen ids; run: node docs/design/mobile/tools/build.mjs');
  process.exit(1);
}

let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  console.error('Playwright is not installed.\n  npm i --no-save playwright && npx playwright install chromium');
  process.exit(1);
}

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1000, height: 1000 }, deviceScaleFactor: SCALE });
  await page.goto(pathToFileURL(HTML).href, { waitUntil: 'networkidle' });
  const fontsOk = await page.evaluate(async () => {
    await document.fonts.ready;
    return document.fonts.check("16px 'Lexend'") && document.fonts.check("16px 'Source Sans 3'");
  });
  if (!fontsOk) console.warn('warning: Lexend / Source Sans 3 did not load (offline?); frames use fallback fonts');

  const ids = await page.$$eval('figure[data-screen]', (els) => els.map((e) => e.getAttribute('data-screen')));
  if (args.includes('--list')) { console.log(ids.join('\n')); process.exit(0); }

  let n = 0;
  for (const id of ids) {
    if (ONLY && !ONLY.has(id)) continue;
    for (const theme of THEMES) {
      const frame = page.locator(`figure[data-screen="${id}"] .ph[data-t="${theme}"]`);
      await frame.screenshot({ path: path.join(OUT, `${id}-${theme}.png`), animations: 'disabled' });
      n++;
    }
  }
  console.log(`wrote ${n} PNGs to ${path.relative(process.cwd(), OUT) || '.'} (scale ${SCALE}, fonts ${fontsOk ? 'ok' : 'FALLBACK'})`);
  if (ONLY) {
    const missing = [...ONLY].filter((id) => !ids.includes(id));
    if (missing.length) { console.error(`unknown screen id(s): ${missing.join(', ')}`); process.exitCode = 1; }
  }
} finally {
  await browser.close();
}
