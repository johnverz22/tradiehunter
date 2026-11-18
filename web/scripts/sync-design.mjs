#!/usr/bin/env node
// Keeps web/ in sync with the web design system in docs/design/web.
// Generated/hand-written design files are COPIED, never edited in web/.
//   node scripts/sync-design.mjs           copy files into web/
//   node scripts/sync-design.mjs --check   fail (exit 1) if web/ differs from docs/design/web
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const web = path.resolve(here, '..');
const src = path.resolve(web, '../docs/design/web');
const check = process.argv.includes('--check');

const pairs = [
  ['tokens/tokens.css', 'src/theme/tokens.css'],
  ['tokens/theme.css', 'src/theme/theme.css'],
  ['css/kit.css', 'src/theme/components.css'],
  ...readdirSync(path.join(src, 'fonts')).map((f) => [`fonts/${f}`, `public/fonts/${f}`]),
];

const diffs = [];
for (const [from, to] of pairs) {
  const a = readFileSync(path.join(src, from));
  const dest = path.join(web, to);
  const same = existsSync(dest) && a.equals(readFileSync(dest));
  if (same) continue;
  diffs.push(to);
  if (!check) {
    mkdirSync(path.dirname(dest), { recursive: true });
    writeFileSync(dest, a);
  }
}

if (check) {
  if (diffs.length) {
    console.error(`design sync check FAILED: ${diffs.length} file(s) differ from docs/design/web:`);
    diffs.forEach((d) => console.error(`  - web/${d}`));
    console.error('Run `npm run design:sync` in web/ and commit the result. Never edit these files by hand.');
    process.exit(1);
  }
  console.log(`design sync check ok: ${pairs.length} files identical to docs/design/web`);
} else {
  console.log(`design sync: ${diffs.length} file(s) updated, ${pairs.length - diffs.length} unchanged`);
}
