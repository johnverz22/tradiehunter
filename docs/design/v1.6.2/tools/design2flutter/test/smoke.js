/**
 * smoke.js — end-to-end proof that the AST pipeline works on the real mockups.
 * Run: node test/smoke.js   (from tools/design2flutter)
 * Exits non-zero on any failure. No Flutter SDK required.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { parseFile } = require('../src/parse');
const { emitScreen, screenName } = require('../src/emit');

// design root: repo layout (docs/design/v1.6.2) or bundle layout (design/v1.6.2)
const CANDIDATES = [
  path.resolve(__dirname, '../../../docs/design/v1.6.2'),
  path.resolve(__dirname, '../../../design/v1.6.2'),
];
const DESIGN = CANDIDATES.find(p => fs.existsSync(p)) || CANDIDATES[0];
let failures = 0;
const ok = (cond, msg) => { console.log(`${cond ? 'ok  ' : 'FAIL'} ${msg}`); if (!cond) failures++; };

// 1. every frame file parses and yields frames
const htmlDir = path.join(DESIGN, 'html');
const files = fs.readdirSync(htmlDir).filter(f => /^frames-.*\.html$/.test(f));
let total = 0, byTheme = { light: 0, dark: 0, outdoor: 0 };
const all = [];
for (const f of files) {
  const frames = parseFile(path.join(htmlDir, f));
  ok(frames.length > 0, `${f}: parsed ${frames.length} frames`);
  for (const fr of frames) { fr.file = f; total++; byTheme[fr.theme]++; all.push(fr); }
}
ok(total === 141, `total frames = 141 (got ${total})`);
ok(byTheme.dark > 30 && byTheme.outdoor > 5, `themes present: ${JSON.stringify(byTheme)}`);

// 2. core screens emit lint-clean Dart (PoC set from the fix spec)
const POC = ['H07-light', 'H12-inprogress-dark', 'T21-light', 'S05-login-light', 'IPAD-messages-light'];
for (const id of POC) {
  const fr = all.find(f => f.frame === id);
  ok(!!fr, `PoC frame ${id} exists`);
  if (!fr) continue;
  const dart = emitScreen(fr);
  const bal = (() => { const s = dart.replace(/'(?:[^'\\]|\\.)*'|\/\/[^\n]*/g, ''); let d = 0;
    for (const c of s) { if ('([{'.includes(c)) d++; if (')]}'.includes(c)) d--; } return d; })();
  ok(bal === 0, `${id}: balanced Dart (${screenName(id)}Screen)`);
  ok(!/Color\(0x/.test(dart), `${id}: no raw color literals`);
  ok(/Space\.|Radii\.|THType\./.test(dart), `${id}: uses design tokens`);
}

// 3. token mapping spot checks
const h07 = emitScreen(all.find(f => f.frame === 'H07-light'));
ok(h07.includes('Space.gutter'), 'H07: gutter spacing tokenised');
ok(h07.includes('FixoPrimaryButton'), 'H07: primary button maps to Fixo widget');
ok(!/#[0-9a-fA-F]{6}/.test(h07.replace(/assets\/design\/[a-z0-9-.]+/g, '')), 'H07: no hex colors outside asset paths');

const t21 = emitScreen(all.find(f => f.frame === 'T21-light'));
ok(t21.includes('THMapHeader') || t21.includes('FixoGradientAppBar'), 'T21: map header mapped');

const s05 = emitScreen(all.find(f => f.frame === 'S05-login-light'));
ok(s05.includes('THField') || s05.includes('FixoInput') || s05.includes('THInput'), 'S05: form fields mapped');

// 4. CLI check mode passes over the generated tree
execFileSync(process.execPath, [path.join(__dirname, '..', 'src', 'index.js'), '--check', path.join(__dirname, '..', 'output')], { stdio: 'inherit' });

console.log(failures === 0 ? '\nSMOKE PASS' : `\nSMOKE FAIL (${failures})`);
process.exit(failures ? 1 : 0);
