#!/usr/bin/env node
// Guard against the legacy (v1.7) admin theme names: variables, Tailwind colour names and
// component classes that the design system (docs/design/web) replaced. Any use in src/ fails.
//   node scripts/check-legacy-names.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const srcDir = path.join(root, 'src');

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
  const text = readFileSync(file, 'utf8');
  const n = PATTERNS.reduce((sum, re) => sum + (text.match(re)?.length ?? 0), 0);
  if (n > 0) counts[rel] = n;
}
if (Object.keys(counts).length) {
  console.error('legacy-name guard FAILED. Legacy (v1.7) design names are not allowed; use the new tokens and kit classes (COMPONENTS.md, DESIGN_GUIDE.md §10):');
  Object.entries(counts).sort(([a], [b]) => a.localeCompare(b)).forEach(([f, n]) => console.error(`  ${f}: ${n}`));
  process.exit(1);
}
console.log('legacy-name guard ok: 0 uses of legacy design names');
