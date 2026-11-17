#!/usr/bin/env node
// TradieHunter web design build. Zero dependencies (Node >= 18).
//   node tools/build.mjs            generate everything
//   node tools/build.mjs --check    generate to memory; fail on contrast, unresolved tokens, kit.css lint, unknown nodes or stale outputs
// Colour, fonts, space, radii and motion are inherited from ../mobile/tokens/tokens.json (see tokens/tokens.json "extends").
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CHECK = process.argv.includes('--check');
const read = (p) => fs.readFileSync(p, 'utf8');
const web = JSON.parse(read(`${ROOT}/tokens/tokens.json`));
const base = JSON.parse(read(path.resolve(ROOT, 'tokens', web.extends)));
const { screens } = await import(pathToFileURL(`${ROOT}/ast/screens.mjs`).href);
const { sheet } = await import(pathToFileURL(`${ROOT}/ast/sheet.mjs`).href);
const { STATUS } = await import(pathToFileURL(`${ROOT}/ast/dsl.mjs`).href);
const out = {};
const errors = [];

// ───────────────────────── 1. resolve tokens (mobile master + web layer) ─────────────────────────
const dig = (o, p) => p.split('.').reduce((a, k) => (a == null ? a : a[k]), o);
const fromBase = (v, where) => {
  if (typeof v !== 'string' || !v.startsWith('=')) return v;
  const r = dig(base, v.slice(1));
  if (r === undefined) errors.push(`${where}: mobile token "${v.slice(1)}" does not exist`);
  return r;
};
const resolveGroup = (g, name) => Object.fromEntries(Object.entries(g).map(([k, v]) => [k, fromBase(v, `${name}.${k}`)]));
const T = {
  font: resolveGroup(web.font, 'font'),
  space: { ...base.space, ...web.space },
  radii: resolveGroup(web.radii, 'radii'),
  size: resolveGroup(web.size, 'size'),
  motion: resolveGroup(web.motion, 'motion'),
  breakpoint: web.breakpoint, easing: web.easing, shadow: web.shadow, type: web.type,
  color: {},
};
for (const mode of ['light', 'dark']) {
  const merged = { ...base.color[mode], ...web.color[mode] };
  const res = {};
  for (const [k, v] of Object.entries(merged)) {
    let val = v;
    if (typeof val === 'string' && val.startsWith('@')) {
      val = merged[val.slice(1)];
      if (val === undefined) errors.push(`color.${mode}.${k}: alias ${v} not found`);
    }
    res[k] = val;
  }
  T.color[mode] = res;
}
const colorKeys = Object.keys(T.color.light);
for (const k of colorKeys) if (!(k in T.color.dark)) errors.push(`color "${k}" missing in dark`);
const kebab = (s) => s.replace(/([A-Z])/g, '-$1').toLowerCase();
const cn = (k) => web.rename[k] ?? kebab(k);
const px = (v) => `${v}px`;

// ───────────────────────── 2. contrast gate ─────────────────────────
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255);
const alpha = (h) => (h.length === 9 ? parseInt(h.slice(7, 9), 16) / 255 : 1);
const over = (fg, bg) => { const a = alpha(fg); const f = rgb(fg), b = rgb(bg); return '#' + f.map((c, i) => Math.round((c * a + b[i] * (1 - a)) * 255).toString(16).padStart(2, '0')).join(''); };
const lum = (h) => { const [r, g, b] = rgb(h).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
// [foreground, background, composite-background-over?]  Semi-transparent colours are flattened before measuring.
const TEXT = [
  ['text', 'paper'], ['text', 'surface'], ['text', 'surfaceAlt'], ['text', 'tintBrand'], ['text', 'accentTint'], ['text', 'successTint'], ['text', 'dangerTint'],
  ['textSoft', 'paper'], ['textSoft', 'surface'], ['textSoft', 'surfaceAlt'],
  ['textBrand', 'paper'], ['textBrand', 'surface'], ['textBrand', 'surfaceAlt'], ['textBrand', 'tintBrand'], ['brand', 'surface'],
  ['onBrand', 'brand'], ['onAccent', 'accent'], ['onDanger', 'danger'],
  ['accentText', 'surface'], ['accentText', 'paper'], ['accentText', 'accentTint'],
  ['successInk', 'paper'], ['successInk', 'surface'], ['successInk', 'surfaceAlt'], ['successInk', 'tintBrand'], ['successInk', 'successTint'], ['successInk', 'dangerTint'], ['successInk', 'accentTint'],
  ['danger', 'paper'], ['danger', 'surface'], ['danger', 'surfaceAlt'], ['danger', 'tintBrand'], ['danger', 'dangerTint'], ['surface', 'text'], ['text', 'glass', 'paper'],
  ['onAvTradie', 'avTradie'], ['onHero', 'heroStart'], ['onHero', 'heroEnd'], ['heroGold', 'heroStart'], ['heroGold', 'heroEnd'],
  ['onSidebar', 'sidebar'], ['onSidebarSoft', 'sidebar'], ['onSidebarSoft', 'heroEnd'], ['onSidebar', 'sidebarActive', 'sidebar'], ['onSidebarSoft', 'sidebarHover', 'sidebar'], ['onSidebarSoft', 'sidebarActive', 'sidebar'], ['heroStart', 'heroGold'],
];
const NONTEXT = [
  ['lineStrong', 'paper'], ['lineStrong', 'surface'], ['lineStrong', 'surfaceAlt'], ['focus', 'paper'], ['focus', 'surface'],
  ['brand', 'surface'], ['accent', 'surface'], ['success', 'surface'], ['danger', 'surface'],
  ['textBrand', 'tintBrand'], ['success', 'successTint'], ['accentText', 'accentTint'], ['danger', 'dangerTint'], ['success', 'surface'],
  ['lineStrong', 'surface'], ['accent', 'accentTint'],
];
const report = ['Contrast gate: text pairs must reach 5.0:1 (WCAG AA is 4.5:1; the extra 0.5 is margin for antialiasing and small sizes), non-text UI pairs 3:1 (WCAG 2.2 SC 1.4.11)'];
let passed = 0, total = 0;
for (const [label, list, min] of [['text', TEXT, 5], ['non-text', NONTEXT, 3]]) {
  for (const mode of ['light', 'dark']) {
    for (const [f, b, ov] of list) {
      const c = T.color[mode];
      if (c[f] === undefined || c[b] === undefined) { errors.push(`contrast pair ${f}/${b} uses an unknown colour`); continue; }
      const bg = ov ? over(c[b], c[ov]) : c[b];
      const r = ratio(over(c[f], bg), bg);
      total++; if (r >= min) passed++;
      report.push(`  ${r >= min ? 'PASS' : 'FAIL'}  ${label.padEnd(8)} ${mode.padEnd(5)} ${f} on ${b}${ov ? ` (over ${ov})` : ''}  ${r.toFixed(2)}  (min ${min})`);
      if (r < min) errors.push(`contrast ${label} ${mode} ${f}/${b} ${r.toFixed(2)} < ${min}`);
    }
  }
}
out['tokens/contrast-report.txt'] = report.join('\n') + '\n';

// ───────────────────────── 3. tokens -> css ─────────────────────────
const cssColor = (h) => (h.length === 9 ? `rgba(${rgb(h).map((v) => Math.round(v * 255)).join(', ')}, ${alpha(h).toFixed(2)})` : h);
const spaceName = (k) => `--sp-${String(T.space[k] / 4).replace('.', '_')}`;
const modeVars = (m) => [...colorKeys.map((k) => `  --${cn(k)}: ${cssColor(T.color[m][k])};`), ...Object.entries(T.shadow[m]).map(([k, v]) => `  --sh-${k}: ${v};`)].join('\n');
const typeCss = Object.entries(T.type).map(([k, v]) => `  --ty-${kebab(k)}: ${v.weight} ${v.size}px/${v.height} var(--ff-${v.font});\n  --ty-${kebab(k)}-ls: ${v.tracking}px;`).join('\n');
const typeClasses = Object.keys(T.type).map((k) => `.t-${k} { font: var(--ty-${kebab(k)}); letter-spacing: var(--ty-${kebab(k)}-ls); }`).join('\n');
out['tokens/tokens.css'] = `/* GENERATED by tools/build.mjs from tokens/tokens.json (v${web.version}), extending ../mobile/tokens/tokens.json (v${base.version}). Do not edit. */
:root, [data-theme="light"] {
  color-scheme: light;
${modeVars('light')}
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) {
    color-scheme: dark;
${modeVars('dark').replace(/^/gm, '  ')}
  }
}
[data-theme="dark"] {
  color-scheme: dark;
${modeVars('dark')}
}
:root {
  --ff-display: '${T.font.display}', system-ui, sans-serif;
  --ff-body: '${T.font.body}', system-ui, sans-serif;
  --ff-mono: ${T.font.mono};
${Object.keys(T.space).map((k) => `  ${spaceName(k)}: ${px(T.space[k])};`).join('\n')}
${Object.entries(T.radii).map(([k, v]) => `  --r-${kebab(k)}: ${px(v)};`).join('\n')}
${Object.entries(T.size).map(([k, v]) => `  --sz-${kebab(k)}: ${px(v)};`).join('\n')}
${typeCss}
${Object.entries(T.motion).map(([k, v]) => `  --dur-${k}: ${v}ms;`).join('\n')}
${Object.entries(T.easing).map(([k, v]) => `  --ease-${k}: ${v};`).join('\n')}
}
${typeClasses}
`;

out['tokens/theme.css'] = `/* GENERATED by tools/build.mjs. Tailwind v4 mapping for tokens.css. Import both: @import './tokens.css'; @import './theme.css'; */
@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));

@theme inline {
${colorKeys.map((k) => `  --color-${cn(k)}: var(--${cn(k)});`).join('\n')}
  --font-display: var(--ff-display);
  --font-body: var(--ff-body);
  --font-mono: var(--ff-mono);
${Object.keys(T.radii).map((k) => `  --radius-${kebab(k)}: var(--r-${kebab(k)});`).join('\n')}
${Object.keys(T.shadow.light).map((k) => `  --shadow-${k}: var(--sh-${k});`).join('\n')}
${Object.entries(T.easing).map(([k, v]) => `  --ease-${k}: ${v};`).join('\n')}
${Object.entries(T.breakpoint).map(([k, v]) => `  --breakpoint-${k}: ${px(v)};`).join('\n')}
}

${Object.keys(T.type).map((k) => `@utility t-${k} {\n  font: var(--ty-${kebab(k)});\n  letter-spacing: var(--ty-${kebab(k)}-ls);\n}`).join('\n')}
`;

out['tokens/tokens.resolved.json'] = JSON.stringify({
  version: web.version, extends: { path: web.extends, version: base.version },
  color: Object.fromEntries(['light', 'dark'].map((m) => [m, Object.fromEntries(colorKeys.map((k) => [cn(k), T.color[m][k]]))])),
  space: T.space, radii: T.radii, size: T.size, breakpoint: T.breakpoint, motion: T.motion, easing: T.easing, shadow: T.shadow, font: T.font,
  type: T.type,
}, null, 1) + '\n';

// ───────────────────────── 3b. self-hosted fonts ─────────────────────────
// woff2 files in fonts/ come from @fontsource (Lexend 5.3.0, Source Sans 3 5.3.1), SIL OFL 1.1. latin-ext carries Māori macrons (U+0100 and up).
const RANGES = {
  latin: 'U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD',
  'latin-ext': 'U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF',
};
const FACES = [[T.font.display, 'lexend', [400, 500, 600, 700, 800]], [T.font.body, 'source-sans-3', [400, 500, 600, 700]]];
const faceCss = [];
for (const [family, slug, weights] of FACES) for (const w of weights) for (const sub of ['latin-ext', 'latin']) {
  const file = `${slug}-${sub}-${w}-normal.woff2`;
  if (!fs.existsSync(`${ROOT}/fonts/${file}`)) errors.push(`fonts/${file} is missing`);
  faceCss.push(`@font-face { font-family: '${family}'; font-style: normal; font-weight: ${w}; font-display: swap; src: url('${file}') format('woff2'); unicode-range: ${RANGES[sub]}; }`);
}
out['fonts/fonts.css'] = `/* GENERATED by tools/build.mjs. Self-hosted ${FACES.map((f) => f[0]).join(' and ')} (SIL OFL 1.1, licences beside the files). Keep this file next to the woff2 files. */\n${faceCss.join('\n')}\n`;

// ───────────────────────── 4. kit.css lint ─────────────────────────
const KIT = read(`${ROOT}/css/kit.css`);
const kitCode = KIT.replace(/\/\*[\s\S]*?\*\//g, '');
for (const m of kitCode.matchAll(/#[0-9a-fA-F]{3,8}\b/g)) if (!/%23/.test(kitCode.slice(Math.max(0, m.index - 3), m.index))) errors.push(`kit.css: raw colour ${m[0]} (use a token)`);
for (const m of kitCode.matchAll(/\b(rgba?|hsla?)\(/g)) errors.push(`kit.css: ${m[0]} literal (use a token)`);
const defined = new Set([...out['tokens/tokens.css'].matchAll(/(--[\w-]+):/g), ...kitCode.matchAll(/(--[\w-]+):/g)].map((m) => m[1])); // tokens + component-local custom properties
for (const m of kitCode.matchAll(/var\((--[\w-]+)/g)) if (!defined.has(m[1])) errors.push(`kit.css: undefined variable ${m[1]}`);

// ───────────────────────── 5. icons and nodes ─────────────────────────
// [24px stroke path, lucide-react export used by the app]
const ICONS = {
  dashboard: ['M3 3h7v9H3zM14 3h7v5h-7zM14 12h7v9h-7zM3 16h7v5H3z', 'LayoutDashboard'], users: ['M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20M10 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM20 20v-1.5a3.5 3.5 0 0 0-2.5-3.3M15.5 5.2a3.5 3.5 0 0 1 0 6.6', 'Users'],
  jobs: ['M3 8h18v12H3zM9 8V5h6v3M3 13h18', 'Briefcase'], shield: ['M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM8.5 12l2.5 2.5 4.5-5', 'ShieldCheck'],
  wallet: ['M3 7h16a2 2 0 0 1 2 2v10H5a2 2 0 0 1-2-2zM3 7l2-3h12M16 14h2', 'Wallet'], bank: ['M3 7h18v10H3zM12 14.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM6.5 10v.01M17.5 14v.01', 'Banknote'],
  refund: ['M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5', 'RotateCcw'], alert: ['M12 4l9 16H3zM12 10v4M12 17.5v.01', 'AlertTriangle'], log: ['M7 3h8l4 4v14H7zM14 3v5h5M10 13h6M10 17h6', 'ScrollText'],
  settings: ['M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M18.4 5.6l-2.1 2.1M7.7 16.3l-2.1 2.1', 'Settings'],
  search: ['M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4', 'Search'], bell: ['M6 17v-6a6 6 0 1 1 12 0v6l2 2H4zM10 21h4', 'Bell'], menu: ['M4 6h16M4 12h16M4 18h16', 'Menu'],
  theme: ['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 3v18', 'SunMoon'], logout: ['M10 4H5v16h5M15 8l4 4-4 4M19 12H9', 'LogOut'], user: ['M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21c1-4 4-6 8-6s7 2 8 6', 'User'],
  chev: ['M9 5l7 7-7 7', 'ChevronRight'], chevl: ['M15 5l-7 7 7 7', 'ChevronLeft'], check: ['M5 12l5 5 9-10', 'Check'], x: ['M6 6l12 12M18 6L6 18', 'X'], plus: ['M12 5v14M5 12h14', 'Plus'],
  info: ['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 11v6M12 8h.01', 'Info'], ok: ['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM8.5 12l2.5 2.5 4.5-5', 'CheckCircle'], bad: ['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9 9l6 6M15 9l-6 6', 'XCircle'],
  mail: ['M3 6h18v12H3zM3 7l9 6 9-6', 'Mail'], lock: ['M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3', 'Lock'], up: ['M12 16V4M7 9l5-5 5 5M4 20h16', 'Upload'], cam: ['M4 8h4l2-3h4l2 3h4v11H4zM12 17a3 3 0 1 0 0-6 3 3 0 0 0 0 6z', 'Camera'],
  inbox: ['M3 13l3-8h12l3 8v6H3zM3 13h5l1 3h6l1-3h5', 'Inbox'], sort: ['M8 4v16M4 8l4-4 4 4M16 20V4M12 16l4 4 4-4', 'ArrowUpDown'],
};
const KNOWN = new Set(['stack', 'row', 'grid', 'card', 'hero', 'filterbar', 'text', 'icon', 'btn', 'ibtn', 'badge', 'avatar', 'field', 'search', 'select', 'choice', 'seg', 'tabs', 'chips', 'drop', 'banner', 'toast', 'empty', 'skeleton', 'stat', 'dl', 'stepper', 'timeline', 'table', 'pager', 'modal', 'menu', 'money', 'mono', 'wordmark', 'tile', 'gap', 'auth']);
const ic = (name) => { if (!ICONS[name]) { errors.push(`unknown icon "${name}"`); return ['', '']; } return ICONS[name]; };
const svg = (name, s = 20) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${ic(name)[0]}"/></svg>`;
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const spVar = (pxv) => { const k = Object.keys(T.space).find((x) => T.space[x] === pxv); if (!k) { errors.push(`gap/pad ${pxv}px is not in the space scale`); return `${pxv}px`; } return `var(${spaceName(k)})`; };
const BK = { dangerOutline: 'danger-outline' };

// ───────────────────────── 6. HTML emitter ─────────────────────────
let uid = 0;
const isNode = (v) => v && typeof v === 'object' && !Array.isArray(v) && v.t;
const cell = (v) => (Array.isArray(v) ? v.map(H).join('') : isNode(v) ? H(v) : esc(v));
function H(n) {
  if (!KNOWN.has(n.t)) { errors.push(`unknown node "${n.t}"`); return ''; }
  const kids = () => (n.c || []).map(H).join('');
  switch (n.t) {
    case 'stack': return `<div class="stack"${n.gap != null ? ` style="gap:${spVar(n.gap)}"` : ''}>${kids()}</div>`;
    case 'row': return `<div class="row${n.between ? ' between' : ''}${n.end ? ' end' : ''}${n.nowrap ? ' nowrap' : ''}"${n.align === 'start' ? ' style="align-items:flex-start"' : ''}>${kids()}</div>`;
    case 'grid': return `<div class="grid ${n.cols === 'side' ? 'side' : `c${n.cols}`}">${kids()}</div>`;
    case 'card': return `<section class="card${n.tone ? ` tone-${n.tone}` : ''}${n.flush ? ' flush' : ''}">${n.title ? `<div class="card-head"><h2>${esc(n.title)}</h2>${n.action ? H(n.action) : ''}</div>` : ''}<div class="card-body">${kids()}</div></section>`;
    case 'hero': return `<div class="hero">${kids()}</div>`;
    case 'filterbar': return `<div class="filterbar" role="search">${kids()}</div>`;
    case 'text': { const tag = n.s === 'h1' ? 'h1' : n.s === 'h2' ? 'h2' : 'div'; return `<${tag} class="t-${n.s}${n.tone && n.tone !== 'default' ? ` c-${n.tone}` : ''}">${esc(n.v)}</${tag}>`; }
    case 'icon': return svg(n.n, n.size || 20);
    case 'btn': return `<button type="button" class="btn btn-${BK[n.k] || n.k}${n.sz ? ` btn-${n.sz}` : ''}${n.w === 'block' ? ' btn-block' : ''}${n.loading ? ' is-loading' : ''}"${n.disabled ? ' disabled' : ''}${n.loading ? ' aria-busy="true"' : ''}>${n.ic ? svg(n.ic, 18) : ''}${esc(n.v)}</button>`;
    case 'ibtn': return `<button type="button" class="btn btn-${BK[n.k] || n.k} btn-icon" aria-label="${esc(n.label)}">${svg(n.ic, 20)}</button>`;
    case 'badge': return `<span class="badge badge-${n.tone}${n.dot ? ' dot' : ''}${n.lg ? ' badge-lg' : ''}">${esc(n.v)}</span>`;
    case 'avatar': return `<span class="avatar${n.sz === 'sm' ? ' avatar-sm' : n.sz === 'lg' ? ' avatar-lg' : ''}" aria-hidden="true">${esc(n.v)}</span>`;
    case 'field': {
      const id = `f${++uid}`, kind = n.kind || 'input', inv = n.err ? ' aria-invalid="true"' : '';
      const desc = n.err || n.help ? ` aria-describedby="${id}-d"` : '';
      const common = `id="${id}"${inv}${desc}${n.disabled ? ' disabled' : ''}`;
      let ctl;
      if (kind === 'select') ctl = `<span class="select-wrap"><select class="select" ${common}><option>${esc(n.v)}</option></select></span>`;
      else if (kind === 'textarea') ctl = `<textarea class="textarea" ${common}${n.ph ? ` placeholder="${esc(n.ph)}"` : ''}>${esc(n.v)}</textarea>`;
      else { const input = `<input class="field${n.focus ? ' is-focus' : ''}" ${common} value="${esc(n.v)}"${n.ph ? ` placeholder="${esc(n.ph)}"` : ''}>`; ctl = n.ic ? `<span class="input-icon">${svg(n.ic, 20)}${input}</span>` : input; }
      return `<div class="form-row"><label class="label" for="${id}">${esc(n.label)}${n.opt ? '<span class="opt">Optional</span>' : ''}</label>${ctl}${n.err ? `<div class="error" id="${id}-d">${svg('bad', 16)}<span>${esc(n.err)}</span></div>` : n.help ? `<div class="help" id="${id}-d">${esc(n.help)}</div>` : ''}</div>`;
    }
    case 'search': return `<label class="input-icon"><span class="sr-only">${esc(n.ph)}</span>${svg('search', 20)}<input type="search" class="field" placeholder="${esc(n.ph)}"></label>`;
    case 'select': return `<span class="select-wrap"><select class="select" aria-label="${esc(n.v)}"><option>${esc(n.v)}</option></select></span>`;
    case 'choice': return `<label class="choice"><input type="${n.kind === 'radio' ? 'radio' : 'checkbox'}" class="${n.kind}"${n.kind === 'switch' ? ' role="switch"' : ''}${n.on ? ' checked' : ''}>${esc(n.label)}</label>`;
    case 'seg': return `<div class="segmented" role="group">${n.items.map((s, i) => `<button type="button" aria-pressed="${i === n.on}">${esc(s)}</button>`).join('')}</div>`;
    case 'tabs': return `<div class="tabs" role="tablist">${n.items.map((s, i) => `<button type="button" role="tab" aria-selected="${i === n.on}">${esc(s)}</button>`).join('')}</div>`;
    case 'chips': return `<div class="row">${n.items.map((c) => `<button type="button" class="chip" aria-pressed="${!!c.on}">${esc(c.v)}</button>`).join('')}</div>`;
    case 'drop': return `<div class="dropzone">${svg(n.ic, 22)}<span>${esc(n.v)}</span></div>`;
    case 'banner': {
      const icn = { info: 'info', ok: 'ok', warn: 'alert', danger: 'bad' }[n.tone], tl = { info: '', ok: ' tile-ok', warn: ' tile-warn', danger: ' tile-danger' }[n.tone];
      return `<div class="banner banner-${n.tone}" role="${n.tone === 'danger' ? 'alert' : 'status'}"><span class="tile tile-xs${tl}">${svg(icn, 18)}</span><div class="banner-body"><div class="banner-title">${esc(n.title)}</div><div class="banner-text">${esc(n.v)}</div></div>${n.action || n.dismiss ? `<div class="banner-actions">${n.action ? H(n.action) : ''}${n.dismiss ? `<button type="button" class="btn btn-ghost btn-sm btn-icon" aria-label="Dismiss">${svg('x', 18)}</button>` : ''}</div>` : ''}</div>`;
    }
    case 'toast': {
      const icn = { info: 'info', ok: 'ok', warn: 'alert', danger: 'bad' }[n.tone], tl = { info: '', ok: ' tile-ok', warn: ' tile-warn', danger: ' tile-danger' }[n.tone];
      return `<div class="toast toast-${n.tone}" role="${n.tone === 'danger' ? 'alert' : 'status'}"><span class="tile tile-xs${tl}">${svg(icn, 18)}</span><div class="toast-body"><div class="toast-title">${esc(n.title)}</div><div class="toast-text">${esc(n.v)}</div></div><button type="button" class="btn btn-ghost btn-sm btn-icon" aria-label="Dismiss">${svg('x', 18)}</button></div>`;
    }
    case 'empty': return `<div class="empty"><span class="tile">${svg(n.ic, 26)}</span><h3>${esc(n.title)}</h3><p>${esc(n.v)}</p>${n.action ? H(n.action) : ''}</div>`;
    case 'skeleton': return `<div class="stack" aria-hidden="true">${Array.from({ length: n.rows }, (_, i) => `<span class="skeleton" style="width:${[92, 70, 84, 56][i % 4]}%"></span>`).join('')}</div>`;
    case 'stat': { const body = `<div class="stat-top"><span class="tile tile-sm${n.tone ? ` tile-${n.tone}` : ''}">${svg(n.ic, 20)}</span><span class="stat-label grow">${esc(n.label)}</span></div><div class="row between nowrap"><div class="stat-value">${esc(n.value)}</div>${n.hint ? `<span class="badge badge-warn dot">${esc(n.hint)}</span>` : ''}</div>`; return `<a class="card stat${n.attention ? ' tone-accent' : ''}" href="#">${body}</a>`; }
    case 'dl': return `<dl class="dl">${n.items.map((i) => `<div${i.total ? ' class="total"' : ''}><dt>${esc(i.l)}</dt><dd>${i.badge ? H(i.badge) : i.link ? `<a class="cell-link" href="#">${esc(i.v)}</a>` : `<span class="${i.money ? 'money' : i.mono ? 'mono' : i.soft ? 'muted' : ''}">${esc(i.v)}</span>`}</dd></div>`).join('')}</dl>`;
    case 'stepper': { const ol = `<ol class="stepper" aria-label="Job progress">${n.items.map((i) => `<li class="${i.s === 'todo' ? '' : i.s}"${i.s === 'current' ? ' aria-current="step"' : ''}><span class="dot">${i.s === 'done' ? svg('check', 12) : i.s === 'halt' ? svg('x', 12) : ''}</span><span>${esc(i.v)}${i.sub ? `<small>${esc(i.sub)}</small>` : ''}</span></li>`).join('')}</ol>`; return n.card ? `<section class="card"><div class="card-body">${ol}</div></section>` : ol; }
    case 'timeline': return `<ol class="timeline">${n.items.map((i) => `<li class="${i.s || ''}"><time>${esc(i.t)}</time><div><div class="ev">${esc(i.v)}</div>${i.meta ? `<div class="meta">${esc(i.meta)}</div>` : ''}</div></li>`).join('')}</ol>`;
    case 'table': {
      const th = n.cols.map((c) => `<th scope="col"${c.k === 'num' || c.k === 'money' ? ' class="num"' : ''}>${c.sr ? `<span class="sr-only">${esc(c.h)}</span>` : esc(c.h)}</th>`).join('');
      const tr = n.rows.map((r) => `<tr>${r.map((v, i) => {
        const c = n.cols[i];
        if (!c) { errors.push('table row has more cells than columns'); return ''; }
        if (c.k === 'link') return `<td><a class="cell-link" href="#">${esc(isNode(v) || typeof v === 'string' ? v.v ?? v : v.v)}</a>${v.sub ? `<span class="cell-sub">${esc(v.sub)}</span>` : ''}</td>`;
        if (c.k === 'status') return `<td>${typeof v === 'string' ? H({ t: 'badge', v, tone: STATUS[v] ?? 'neutral', dot: true }) : cell(v)}</td>`;
        if (c.k === 'actions') return `<td class="actions">${cell(v)}</td>`;
        return `<td${c.k === 'money' ? ' class="money"' : c.k === 'mono' ? ' class="mono"' : c.k === 'num' ? ' class="num"' : ''}>${cell(v)}</td>`;
      }).join('')}</tr>`).join('');
      return `<div class="table-wrap"><table class="table${n.compact ? ' table--compact' : ''}">${n.caption ? `<caption>${esc(n.caption)}</caption>` : ''}<thead><tr>${th}</tr></thead><tbody>${tr}</tbody></table>${n.pager ? H(n.pager) : ''}</div>`;
    }
    case 'pager': { const nums = [1, 2, 3].filter((p) => p <= n.pages); return `<nav class="pagination" aria-label="Pagination"><span>Showing ${n.from}–${n.to} of ${n.total}</span><div class="page-buttons"><button type="button" class="page-btn" aria-label="Previous page" disabled>${svg('chevl', 16)}</button>${nums.map((p) => `<button type="button" class="page-btn"${p === n.page ? ' aria-current="page"' : ''}>${p}</button>`).join('')}${n.pages > 3 ? `<span aria-hidden="true">…</span><button type="button" class="page-btn">${n.pages}</button>` : ''}<button type="button" class="page-btn" aria-label="Next page">${svg('chev', 16)}</button></div></nav>`; }
    case 'modal': {
      const id = `m${++uid}`;
      const box = `<div class="modal${n.size ? ` modal-${n.size}` : ''}" role="dialog" aria-modal="true" aria-labelledby="${id}"><div class="modal-head"><h2 id="${id}">${esc(n.title)}</h2><button type="button" class="btn btn-ghost btn-sm btn-icon" aria-label="Close">${svg('x', 18)}</button></div><div class="modal-body">${n.body.map(H).join('')}</div><div class="modal-foot">${n.foot.map(H).join('')}</div></div>`;
      return n.inline ? box : `<div class="scrim">${box}</div>`;
    }
    case 'menu': return `<div class="menu" role="menu">${n.items.map((i) => `<button type="button" role="menuitem">${svg(i.ic, 18)}${esc(i.v)}</button>`).join('')}</div>`;
    case 'money': return `<span class="money">${esc(n.v)}</span>`;
    case 'mono': return `<span class="mono">${esc(n.v)}</span>`;
    case 'wordmark': return `<span class="wordmark${n.lg ? ' wordmark-lg' : ''}">Tradie<span>Hunter</span></span>`;
    case 'tile': return `<span class="tile${n.tone ? ` tile-${n.tone}` : ''}">${svg(n.ic, 24)}</span>`;
    case 'gap': return `<div style="height:${spVar(n.n)}"></div>`;
    case 'auth': return `<div class="auth"><aside class="hero auth-aside">${n.c[0].c.map(H).join('')}</aside><main class="auth-main"><div class="auth-card">${n.c[1].c.map(H).join('')}</div></main></div>`;
    default: return '';
  }
}

const NAV = [['dashboard', 'Dashboard', 'dashboard'], ['users', 'Users', 'users'], ['jobs', 'Jobs', 'jobs'], ['credentials', 'Credentials', 'shield', 5], ['payments', 'Payments', 'wallet', 3], ['payouts', 'Payouts', 'bank'], ['refunds', 'Refunds', 'refund'], ['disputes', 'Disputes', 'alert'], ['audit-logs', 'Audit Logs', 'log'], ['settings', 'Settings', 'settings']];
function page(s) {
  const head = `${s.crumbs ? `<nav class="breadcrumb" aria-label="Breadcrumb">${s.crumbs.map(([l, h], i) => (i < s.crumbs.length - 1 ? `<a href="#">${esc(l)}</a>${svg('chev', 14)}` : `<span aria-current="page">${esc(l)}</span>`)).join('')}</nav>` : ''}<div class="page-header"><div><div class="row">${`<h1>${esc(s.h1)}</h1>`}${s.badge ? H(s.badge) : ''}</div>${s.sub ? `<div class="sub">${esc(s.sub)}</div>` : ''}</div>${s.actions ? `<div class="page-actions">${s.actions.map(H).join('')}</div>` : ''}</div>`;
  return `<main class="page" id="main">${head}${s.body.map(H).join('')}</main>`;
}
function frameBody(s) {
  uid = 0;
  if (s.shell === 'none') return s.body.map(H).join('');
  const drawer = s.shell === 'drawer';
  const navHtml = NAV.map(([key, label, icn, count]) => `<a class="nav-item" href="#"${s.nav === key ? ' aria-current="page"' : ''}>${svg(icn, 20)}<span class="nav-label">${label}</span>${count ? `<span class="nav-count" aria-label="${count} waiting">${count}</span>` : ''}</a>`).join('');
  const side = `<aside class="sidebar${s.shell === 'rail' ? ' is-rail' : ''}${drawer ? ' is-drawer' : ''}" aria-label="Admin navigation"><div class="sidebar-brand"><span class="wordmark wordmark-lg">Tradie<span>Hunter</span></span><span class="monogram" aria-hidden="true">TH</span></div><nav class="sidebar-nav">${navHtml}</nav><div class="sidebar-foot"><a class="nav-item" href="#"><span class="avatar avatar-sm" aria-hidden="true">SH</span><span class="nav-label">Sam Harris<small>Staff</small></span></a></div></aside>`;
  const top = `<header class="topbar"><button type="button" class="btn btn-ghost btn-icon menu-btn" aria-label="Open navigation">${svg('menu', 20)}</button><span class="wordmark phone-only">Tradie<span>Hunter</span></span><span class="grow"></span><button type="button" class="btn btn-ghost btn-icon" aria-label="Switch colour theme">${svg('theme', 20)}</button></header>`;
  return `<div class="app">${drawer ? '<div class="scrim" aria-hidden="true"></div>' : ''}${side}<div class="app-main">${top}${page(s)}</div></div>${s.overlay ? H(s.overlay) : ''}`;
}
const fontsLink = (rel) => `<link rel="stylesheet" href="${rel}fonts/fonts.css">`;
const THEME_JS = `<script>(function(){var t=new URLSearchParams(location.search).get('theme');if(t==='light'||t==='dark')document.documentElement.setAttribute('data-theme',t)})()</script>`;
const head = (title, rel) => `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"><title>${esc(title)}</title>${fontsLink(rel)}<link rel="stylesheet" href="${rel}tokens/tokens.css"><link rel="stylesheet" href="${rel}css/kit.css">`;
for (const s of screens) out[`mockups/frames/${s.id}.html`] = `${head(`${s.title} · TradieHunter web`, '../../')}${THEME_JS}</head><body>${frameBody(s)}</body></html>\n`;
out['ast/screens.ast.json'] = JSON.stringify({ version: web.version, screens }, null, 1) + '\n';

// ───────────────────────── 7. gallery + system sheet ─────────────────────────
const GALLERY_CSS = `body{padding:var(--sp-8) var(--sp-6) var(--sp-11)}h1{font:var(--ty-h1);margin:0}h2{font:var(--ty-h2);margin:var(--sp-10) 0 var(--sp-1)}.lead{color:var(--ink-soft);max-width:72ch;margin:var(--sp-2) 0 var(--sp-4)}.bar{display:flex;gap:var(--sp-4);flex-wrap:wrap;align-items:center;margin:var(--sp-4) 0}.gal{display:flex;flex-wrap:wrap;gap:var(--sp-8) var(--sp-6);align-items:flex-start}figure{margin:0}.fr{display:flex;gap:var(--sp-5);zoom:var(--zoom,.5)}iframe{border:1px solid var(--line-strong);border-radius:12px;background:var(--paper);flex:none}figcaption{margin-top:var(--sp-2);font:var(--ty-title)}figcaption small{display:block;font:var(--ty-meta);color:var(--ink-soft)}body[data-show=light] iframe[data-t=dark],body[data-show=dark] iframe[data-t=light]{display:none}`;
const sections = [['Entry', ['login', 'forbidden']], ['Overview', ['dashboard']], ['People', ['users', 'user_detail']], ['Jobs', ['jobs', 'job_detail']], ['Queues', ['credentials', 'payments', 'payouts']], ['Disputes and records', ['disputes', 'dispute_detail', 'audit_logs', 'settings']], ['Responsive', ['dashboard_rail', 'dashboard_phone', 'nav_drawer', 'job_detail_phone']]];
const byId = Object.fromEntries(screens.map((s) => [s.id, s]));
const covered = new Set(sections.flatMap(([, ids]) => ids));
for (const s of screens) if (!covered.has(s.id)) errors.push(`screen ${s.id} is not listed in a gallery section`);
const figure = (s) => `<figure><div class="fr">${['light', 'dark'].map((m) => `<iframe data-t="${m}" loading="lazy" src="frames/${s.id}.html?theme=${m}" title="${esc(s.title)}, ${m}" width="${s.w}" height="${s.h}"></iframe>`).join('')}</div><figcaption>${esc(s.title)}<small>${esc(s.route)} · ${s.w}px</small></figcaption></figure>`;
out['mockups/index.html'] = `${head('TradieHunter web design v1', '../')}<style>${GALLERY_CSS}</style></head><body data-show="light">
<h1>TradieHunter · web admin design v1</h1>
<p class="lead">${screens.length} frames generated from the same AST and the same <code>css/kit.css</code> the app will use. Colour, type, space and radii inherit from the mobile system. Sample names, ids and amounts are illustrative. Open <a href="system.html">foundations and components</a> for tokens and every component state.</p>
<div class="bar" role="group" aria-label="Preview controls"><div class="segmented" id="theme"><button type="button" data-v="light" aria-pressed="true">Light</button><button type="button" data-v="dark" aria-pressed="false">Dark</button><button type="button" data-v="both" aria-pressed="false">Both</button></div><div class="segmented" id="zoom"><button type="button" data-v=".4" aria-pressed="false">40%</button><button type="button" data-v=".5" aria-pressed="true">50%</button><button type="button" data-v=".75" aria-pressed="false">75%</button><button type="button" data-v="1" aria-pressed="false">100%</button></div></div>
${sections.map(([t, ids]) => `<h2>${t}</h2><div class="gal">${ids.map((id) => figure(byId[id])).join('')}</div>`).join('')}
<script>function wire(id,fn){var g=document.getElementById(id);g.onclick=function(e){var b=e.target.closest('button');if(!b)return;g.querySelectorAll('button').forEach(function(x){x.setAttribute('aria-pressed',x===b)});fn(b.dataset.v)}}wire('theme',function(v){document.body.setAttribute('data-show',v)});wire('zoom',function(v){document.documentElement.style.setProperty('--zoom',v)});</script>
</body></html>\n`;

const SYS_CSS = `body{padding:var(--sp-8) var(--sp-6) var(--sp-11);max-width:1180px;margin:0 auto}h1{font:var(--ty-h1);margin:0}h2{font:var(--ty-h2);margin:var(--sp-10) 0 var(--sp-1)}h3{font:var(--ty-title);margin:var(--sp-5) 0 var(--sp-2)}.note{color:var(--ink-soft);margin:0 0 var(--sp-4);max-width:72ch;font:var(--ty-bodySm)}.top{display:flex;gap:var(--sp-4);align-items:center;justify-content:space-between;flex-wrap:wrap}.sw{display:grid;grid-template-columns:repeat(auto-fill,minmax(168px,1fr));gap:var(--sp-3)}.sw div{border:1px solid var(--line);border-radius:var(--r-card);overflow:hidden;background:var(--surface);font:var(--ty-meta)}.sw i{display:block;height:48px;border-bottom:1px solid var(--line)}.sw b{display:block;padding:var(--sp-2) var(--sp-3) 0;font:var(--ty-label)}.sw span{display:block;padding:0 var(--sp-3) var(--sp-2);color:var(--ink-soft)}.spec{display:grid;grid-template-columns:150px 1fr;gap:var(--sp-4);align-items:baseline;padding:var(--sp-2) 0;border-top:1px dashed var(--line)}.spec small{color:var(--ink-soft);font:var(--ty-meta)}.bars{display:flex;flex-direction:column;gap:var(--sp-1_5)}.bars div{display:flex;gap:var(--sp-3);align-items:center;font:var(--ty-meta)}.bars i{display:block;height:var(--sp-3);background:var(--brand);border-radius:2px}.boxes{display:flex;gap:var(--sp-4);flex-wrap:wrap}.boxes div{width:112px;height:72px;background:var(--surface);border:1px solid var(--line);display:flex;align-items:flex-end;padding:var(--sp-2);font:var(--ty-meta)}.demo{display:flex;flex-direction:column;gap:var(--sp-4);padding:var(--sp-5);background:var(--paper);border:1px dashed var(--line-strong);border-radius:var(--r-panel)}`;
const groups = [['Surfaces', ['paper', 'surface', 'surfaceAlt']], ['Text', ['text', 'textSoft', 'textBrand']], ['Brand', ['brand', 'onBrand', 'tintBrand']], ['Accent (gold)', ['accent', 'onAccent', 'accentText', 'accentTint']], ['Status', ['success', 'successInk', 'successTint', 'danger', 'dangerTint', 'onDanger']], ['Lines and focus', ['line', 'lineStrong', 'track', 'focus']], ['Shell', ['sidebar', 'onSidebar', 'onSidebarSoft', 'sidebarHover', 'sidebarActive', 'heroStart', 'heroEnd', 'heroGold', 'scrim', 'glass']], ['Avatar', ['avTradie', 'onAvTradie']]];
const grouped = new Set(groups.flatMap(([, k]) => k));
for (const k of colorKeys) if (!grouped.has(k) && k !== 'onHero' && k !== 'heroGlow') errors.push(`colour "${k}" is not shown in system.html groups`);
const swatches = groups.map(([t, ks]) => `<h3>${t}</h3><div class="sw">${ks.map((k) => `<div><i style="background:var(--${cn(k)})"></i><b>${cn(k)}</b><span>${T.color.light[k]} / ${T.color.dark[k]}</span></div>`).join('')}</div>`).join('');
const typeRows = Object.entries(T.type).map(([k, v]) => `<div class="spec"><div><b>t-${k}</b><br><small>${T.font[v.font].split(',')[0]} ${v.weight} · ${v.size}/${v.height}</small></div><div class="t-${k}">Verify the payment before processing the payout</div></div>`).join('');
const spaceRows = Object.keys(T.space).map((k) => `<div><code style="width:140px">${spaceName(k)} (${k})</code><i style="width:${T.space[k]}px"></i>${T.space[k]}px</div>`).join('');
out['mockups/system.html'] = `${head('TradieHunter web design system', '../')}<style>${SYS_CSS}</style></head><body>
<div class="top"><div><h1>TradieHunter · web design system v1</h1><p class="note">Foundations and components. Colour is inherited from the mobile v2 master (Trust Navy and Gold). Toggle the theme to check both.</p></div><div class="segmented" id="theme"><button type="button" data-v="light" aria-pressed="false">Light</button><button type="button" data-v="dark" aria-pressed="false">Dark</button></div></div>
<h2>Colour</h2><p class="note">Hex shown as light / dark. Swatches follow the selected theme.</p>${swatches}
<h2>Type</h2><p class="note">Lexend for headings, controls and big numbers. Source Sans 3 for reading text and money in tables. System monospace for ids and references.</p>${typeRows}
<h2>Space</h2><p class="note">The mobile 4pt scale, extended with 64 and 80 for page-level rhythm. CSS names follow Tailwind (px / 4).</p><div class="bars">${spaceRows}</div>
<h2>Radii and elevation</h2><p class="note">The mobile radii, one step tighter in role: controls use the mobile small (10), cards the mobile control (16), panels the mobile card (20).</p><div class="boxes">${Object.entries(T.radii).map(([k, v]) => `<div style="border-radius:${px(v)}">r-${kebab(k)}<br>${v}</div>`).join('')}${Object.keys(T.shadow.light).map((k) => `<div style="box-shadow:var(--sh-${k});border-radius:var(--r-card)">sh-${k}</div>`).join('')}</div>
${sheet.map((sec) => { uid = 0; return `<h2>${esc(sec.title)}</h2><p class="note">${esc(sec.note)}</p><div class="demo">${sec.nodes.map(H).join('')}</div>`; }).join('')}
<script>(function(){var r=document.documentElement,g=document.getElementById('theme');function set(v){r.setAttribute('data-theme',v);g.querySelectorAll('button').forEach(function(b){b.setAttribute('aria-pressed',b.dataset.v===v)})}set(matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light');g.onclick=function(e){var b=e.target.closest('button');if(b)set(b.dataset.v)}})();</script>
</body></html>\n`;

// ───────────────────────── 8. write / check ─────────────────────────
if (errors.length) { console.error('BUILD FAILED\n - ' + [...new Set(errors)].join('\n - ')); process.exit(1); }
let stale = 0;
if (CHECK) {
  for (const dir of ['mockups/frames']) for (const f of fs.existsSync(`${ROOT}/${dir}`) ? fs.readdirSync(`${ROOT}/${dir}`) : []) if (!(`${dir}/${f}` in out)) { console.error(`STALE (orphan) ${dir}/${f}`); stale++; }
}
for (const [rel, content] of Object.entries(out)) {
  const file = path.join(ROOT, rel);
  if (CHECK) { if (!fs.existsSync(file) || read(file) !== content) { console.error('STALE ' + rel); stale++; } continue; }
  fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, content);
}
if (CHECK && stale) process.exit(1);
console.log(`${CHECK ? 'check ok' : 'built'}: ${screens.length} frames, ${Object.keys(out).length} files, contrast ${passed}/${total} pass`);
