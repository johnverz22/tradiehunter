/**
 * parse.js — parse5 wrapper: HTML files -> normalised frame trees.
 * Walks the parse5 AST, extracts every [data-frame], and produces a compact
 * node tree (tag, classes, attrs, style, text, icon) that widgetMap consumes.
 * SVG <use> refs resolve to icon names; inline styles are parsed to numbers.
 */
'use strict';
const parse5 = require('parse5');
const fs = require('fs');
const path = require('path');

const ICON_ALIASES = {
  'i-back': 'Icons.arrow_back_ios_new', 'i-bell': 'Icons.notifications_none',
  'i-search': 'Icons.search', 'i-more': 'Icons.more_horiz', 'i-call': 'Icons.call_outlined',
  'i-send': 'Icons.near_me_outlined', 'i-cam': 'Icons.photo_camera_outlined',
  'i-gear': 'Icons.settings_outlined', 'i-pencil': 'Icons.edit_outlined', 'i-x': 'Icons.close',
  'i-star': 'Icons.star_rounded', 'i-check': 'Icons.check_rounded', 'i-check-c': 'Icons.verified_outlined',
  'i-shield': 'Icons.shield_outlined', 'i-doc': 'Icons.description_outlined', 'i-pin': 'Icons.place_outlined',
  'i-plus': 'Icons.add', 'i-home': 'Icons.home_outlined', 'i-jobs': 'Icons.work_outline',
  'i-msg': 'Icons.chat_bubble_outline', 'i-user': 'Icons.person_outline', 'i-excl': 'Icons.error_outline',
  'i-play': 'Icons.play_arrow', 'i-clock': 'Icons.schedule', 'i-cal': 'Icons.calendar_today_outlined',
  'i-nav': 'Icons.near_me_outlined', 'i-flag': 'Icons.flag_outlined', 'i-card': 'Icons.credit_card',
  'i-mail': 'Icons.mail_outline', 'i-lock': 'Icons.lock_outline', 'i-eye': 'Icons.visibility_outlined',
  'i-phone': 'Icons.phone_iphone', 'i-tools': 'Icons.handyman', 'i-wallet': 'Icons.account_balance_wallet_outlined',
};

function parseStyle(str) {
  const out = {};
  if (!str) return out;
  for (const decl of str.split(';')) {
    const i = decl.indexOf(':');
    if (i < 1) continue;
    const k = decl.slice(0, i).trim(), v = decl.slice(i + 1).trim();
    out[k] = v;
  }
  return out;
}

const px = v => { const m = /(-?\d+(?:\.\d+)?)px/.exec(v || ''); return m ? parseFloat(m[1]) : null; };
const pct = v => { const m = /(\d+(?:\.\d+)?)%/.exec(v || ''); return m ? parseFloat(m[1]) : null; };

/** node classes/attrs helpers over parse5 elements */
function attr(el, name) {
  const a = el.attrs.find(a => a.name === name);
  return a ? a.value : undefined;
}

function directText(el) {
  let txt = '';
  for (const c of el.childNodes || []) {
    if (c.nodeName === '#text') txt += c.value;
  }
  return txt.replace(/\s+/g, ' ').trim();
}

/** normalise one element into our compact node */
function normalise(el, parentHero) {
  const classes = (attr(el, 'class') || '').split(/\s+/).filter(Boolean);
  const style = parseStyle(attr(el, 'style'));
  const node = {
    tag: el.tagName,
    classes,
    attrs: { 'aria-label': attr(el, 'aria-label'), alt: attr(el, 'alt'), role: attr(el, 'role') },
    style: {},
    text: directText(el),
    children: [],
    icon: null,
    parentHero: !!parentHero,
    assetBase: null, sizePx: null,
  };
  // keep only the style keys the emitter needs
  for (const k of ['gap', 'padding', 'margin-top', 'margin-bottom', 'height', 'width', 'max-width',
                   'font-size', 'font-weight', 'font', 'border-radius', 'background', 'color', 'opacity',
                   'flex', 'text-align', 'justify-content']) {
    if (style[k] !== undefined) node.style[k] = style[k];
  }
  const h = px(style.height); if (h !== null) node.sizePx = h;
  // svg icon resolution: <use href="#i-x"> or inline path shape heuristics
  const uses = descendants(el).filter(d => d.tagName === 'use');
  if (uses.length) {
    const href = attr(uses[0], 'href') || attr(uses[0], 'xlink:href') || '';
    node.icon = ICON_ALIASES[href.replace('#', '')] || null;
  }
  if (el.tagName === 'img') {
    const src = attr(el, 'src') || '';
    node.assetBase = path.basename(src);
  }
  return node;
}

function descendants(el) {
  const out = [];
  for (const c of el.childNodes || []) {
    if (c.tagName) { out.push(c); out.push(...descendants(c)); }
  }
  return out;
}

/** collect text of a subtree (for buttons/pills made of icon+text) */
function subtreeText(el) {
  let txt = '';
  for (const c of el.childNodes || []) {
    if (c.nodeName === '#text') txt += c.value;
    else if (c.tagName && !['svg', 'defs'].includes(c.tagName)) txt += subtreeText(c);
  }
  return txt.replace(/\s+/g, ' ').trim();
}

/** build the normalised tree for one frame element */
function buildTree(el, parentHero = false) {
  const node = normalise(el, parentHero);
  const hero = parentHero || node.classes.includes('heroband');
  for (const c of el.childNodes || []) {
    if (!c.tagName) continue;
    if (c.tagName === 'svg' || c.tagName === 'defs') continue;          // handled via icon resolution
    if (c.tagName === 'style' || c.tagName === 'script') continue;
    node.children.push(buildTree(c, hero));
  }
  node.text = subtreeText(el);  // richest text (buttons, pills, list rows)
  // per-class enrichment
  enrich(node, el);
  return node;
}

function enrich(node, el) {
  const cl = node.classes;
  if (cl.includes('input')) {
    node.inputState = cl.includes('error') ? 'error' : cl.includes('focused') ? 'focused'
      : cl.includes('filled') ? 'filled' : cl.includes('disabled') ? 'disabled' : 'default';
    node.placeholder = /…|\.\.\./.test(node.text) ? node.text : null;
  }
  if (cl.includes('cpb')) {
    const segs = descendants(el).filter(d => (attr(d, 'class') || '').includes('seg on'));
    node.step = segs.length || 1;
    const cap = descendants(el).find(d => (attr(d, 'class') || '').split(' ').includes('cap'));
    node.caption = cap ? subtreeText(cap) : null;
  }
  if (cl.includes('countdown')) {
    node.isUrgent = !!descendants(el).find(d => (attr(d, 'class') || '').includes('urgent'));
    const fill = descendants(el).find(d => (attr(d, 'class') || '').includes('fill'));
    node.progress = fill ? pct(attr(fill, 'style') || '') : null;
    const lab = descendants(el).find(d => (attr(d, 'class') || '').split(' ').includes('cap'));
    node.label = lab ? subtreeText(lab) : null;
  }
  if (cl.includes('field')) {
    const lab = descendants(el).find(d => d.tagName === 'label');
    node.label = lab ? subtreeText(lab) : null;
    node.error = cl.includes('error') || !!descendants(el).find(d => (attr(d, 'class') || '').includes('helper-err'));
  }
  if (cl.includes('av')) node.hasVbdg = !!descendants(el).find(d => (attr(d, 'class') || '').includes('vbdg'));
  if (cl.includes('maphead')) {
    const st = attr(el, 'style') || '';
    const m = /height:\s*([\d.]+)%/.exec(st);
    node.styleRatio = m ? parseFloat(m[1]) / 100 : null;
  }
  if (cl.includes('navbar') || cl.includes('rail')) {
    node.navItems = descendants(el)
      .filter(d => (attr(d, 'class') || '').split(' ').includes('tab'))
      .map(tb => ({
        label: subtreeText(tb),
        icon: (() => { const u = descendants(tb).find(x => x.tagName === 'use');
          const href = u ? (attr(u, 'href') || '').replace('#', '') : '';
          return ICON_ALIASES[href] || 'Icons.circle_outlined'; })(),
        selected: (attr(tb, 'class') || '').includes('on'),
      }));
  }
  if (cl.includes('seg48')) {
    node.options = descendants(el)
      .filter(d => (attr(d, 'class') || '').split(/\s+/).includes('o'))
      .map(o => ({ label: subtreeText(o), selected: (attr(o, 'class') || '').includes('on') }));
  }
  if (cl.includes('msgrow')) {
    const b = descendants(el).find(d => d.tagName === 'b');
    const cap = descendants(el).find(d => (attr(d, 'class') || '').split(' ').includes('cap'));
    const pv = descendants(el).find(d => (attr(d, 'class') || '').includes('pv'));
    node.name = b ? subtreeText(b) : null;
    node.time = cap ? subtreeText(cap) : null;
    node.preview = pv ? subtreeText(pv) : null;
    node.unread = !!descendants(el).find(d => (attr(d, 'class') || '').includes('udot'));
  }
  if (cl.includes('svc')) {
    const rate = descendants(el).find(d => (attr(d, 'class') || '').split(' ').includes('rate'));
    node.rate = rate ? subtreeText(rate) : null;
  }
  if (cl.includes('banner')) node.tone = cl.includes('warn') ? 'warning' : cl.includes('err') ? 'error' : 'info';
  if (cl.includes('otp')) node.digitCount = descendants(el).filter(d => (attr(d, 'class') || '').includes('cell')).length || 5;
}

/** parse a file, return [{ frame: 'H07-light', width, height, theme, tree }] */
function parseFile(file) {
  const html = fs.readFileSync(file, 'utf8');
  const doc = parse5.parse(html);
  const frames = [];
  const walk = el => {
    if (el.tagName && (attr(el, 'data-frame') !== undefined)) {
      const classes = (attr(el, 'class') || '').split(/\s+/);
      const w = px(attr(el, 'style')?.match(/width:\s*(\d+)px/)?.[1] + 'px');
      const wm = /width:\s*(\d+)px/.exec(attr(el, 'style') || '');
      const hm = /height:\s*(\d+)px/.exec(attr(el, 'style') || '');
      frames.push({
        frame: attr(el, 'data-frame'),
        theme: classes.includes('dark') ? 'dark' : classes.includes('outdoor') ? 'outdoor' : 'light',
        width: wm ? +wm[1] : (classes.includes('w834') ? 834 : classes.includes('w440') ? 440 : 402),
        height: hm ? +hm[1] : (classes.includes('w834') ? 1194 : classes.includes('w440') ? 956 : 874),
        tree: buildTree(el),
      });
    }
    for (const c of el.childNodes || []) { if (c.tagName) walk(c); }
  };
  walk(doc);
  return frames;
}

module.exports = { parseFile, ICON_ALIASES };
