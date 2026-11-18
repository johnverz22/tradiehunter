#!/usr/bin/env node
// Ratchet guard for the web design-system migration (docs/web_design_system_migration_plan.md).
// Counts uses of legacy (v1.7) variables, Tailwind colour names and component classes per file.
// A file may never gain uses; a file with no baseline entry must have zero. Phase 6 target: all zero.
//   node scripts/check-legacy-names.mjs           check against scripts/legacy-baseline.json
//   node scripts/check-legacy-names.mjs --update  lower the baseline (refuses to raise any count)
//   node scripts/check-legacy-names.mjs --init    (re)create the baseline from the current tree
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const srcDir = path.join(root, 'src');
const baselinePath = path.join(here, 'legacy-baseline.json');
const EXEMPT = new Set(['src/theme/legacy-compat.css']);

const PATTERNS = [
  // variables
  /var\(--(?:brand-(?:900|700|500|300|100)|paper-line|amber(?:-dark|-ink)?|green(?:-ink)?|red(?:-ink)?|radius|shadow-card|shadow-pop|space-\d+|hue|text-(?:body|display|h2|h3|mono)|font-(?:display|body|mono))\)/g,
  // tailwind colour utilities built on legacy names
  /\b(?:bg|text|border|ring|fill|stroke|from|to|via|divide|outline|shadow|accent|decoration|caret)-(?:brand-(?:900|700|500|300|100)|amber-brand|amber-dark|paper-line)\b/g,
  // component classes with no kit equivalent
  /(?<![\w-])(?:pill(?:-(?:lg|green|amber|red|blue|gray|brand))?|stat-pill|card-title|card-pop|table-container|th-sortable|detail-(?:row|label|value)|action-link|cell-muted|field-(?:invalid|multiline|search)|select-field|step-(?:line|dot|label|sublabel|updated-caption)|timeline-(?:item|time|event|meta))(?![\w-])/g,
];

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = path.join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(tsx?|css)$/.test(name)) out.push(p);
  }
  return out;
}

const counts = {};
for (const file of walk(srcDir)) {
  const rel = path.relative(root, file).split(path.sep).join('/');
  if (EXEMPT.has(rel)) continue;
  const text = readFileSync(file, 'utf8');
  const n = PATTERNS.reduce((sum, re) => sum + (text.match(re)?.length ?? 0), 0);
  if (n > 0) counts[rel] = n;
}
const total = (o) => Object.values(o).reduce((a, b) => a + b, 0);
const sorted = (o) => Object.fromEntries(Object.entries(o).sort(([a], [b]) => a.localeCompare(b)));

if (process.argv.includes('--init')) {
  writeFileSync(baselinePath, JSON.stringify(sorted(counts), null, 2) + '\n');
  console.log(`legacy baseline created: ${Object.keys(counts).length} files, ${total(counts)} uses`);
  process.exit(0);
}

const base = existsSync(baselinePath) ? JSON.parse(readFileSync(baselinePath, 'utf8')) : {};
const raised = Object.entries(counts).filter(([f, n]) => n > (base[f] ?? 0));

if (process.argv.includes('--update')) {
  if (raised.length) {
    console.error('Refusing to raise the legacy baseline:');
    raised.forEach(([f, n]) => console.error(`  ${f}: ${base[f] ?? 0} -> ${n}`));
    process.exit(1);
  }
  writeFileSync(baselinePath, JSON.stringify(sorted(counts), null, 2) + '\n');
  console.log(`legacy baseline lowered: ${Object.keys(counts).length} files, ${total(counts)} uses (was ${total(base)})`);
  process.exit(0);
}

if (raised.length) {
  console.error('legacy-name guard FAILED. New or increased uses of legacy design names (use the new tokens/kit, see COMPONENTS.md and DESIGN_GUIDE.md §10):');
  raised.forEach(([f, n]) => console.error(`  ${f}: ${base[f] ?? 0} -> ${n}`));
  process.exit(1);
}
const stale = Object.keys(base).filter((f) => (counts[f] ?? 0) < base[f]);
console.log(`legacy-name guard ok: ${total(counts)} uses in ${Object.keys(counts).length} files (baseline ${total(base)})`);
if (stale.length) console.log(`  ${stale.length} file(s) are below baseline; run \`npm run design:legacy:update\` to ratchet it down.`);
