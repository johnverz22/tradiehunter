/**
 * widgetMap.js — structural HTML + kit.css classes -> Flutter widget descriptors.
 * Each rule consumes a parsed node (see parse.js for the normalised tree) and
 * returns a widget spec consumed by emit.js. Rules are ordered: the FIRST match
 * wins, so specific compound selectors precede generic ones.
 */
'use strict';

const t = require('./tokens');

const is = (node, ...cls) => cls.every(c => (node.classes || []).includes(c));
const has = (node, ...cls) => cls.some(c => (node.classes || []).includes(c));

/** inline style helpers */
function style(node) { return node.style || {}; }
function spacingExpr(px) { const e = t.space(px); return e === null ? null : e; }

// ─────────────────────────────────────────────────────────────────────────────
// Rule table. match(node) -> spec | null.  Spec shape:
// { widget: 'Name', props: {…}, children: […] | null, comment?: '…' }
// ─────────────────────────────────────────────────────────────────────────────
const RULES = [

  // ── chrome ────────────────────────────────────────────────────────────────
  { name: 'statusbar',
    match: n => is(n, 'statusbar') || is(n, 'hero-statusbar'),
    build: n => ({ widget: 'THStatusBand', props: { onDark: is(n, 'on-dark') || is(n, 'hero-statusbar') },
                   children: [], selfClosing: true }) },

  { name: 'homebar',
    match: n => is(n, 'homebar'),
    build: n => ({ widget: 'THHomeIndicator', props: {}, children: [], selfClosing: true }) },

  { name: 'appbar',
    match: n => is(n, 'appbar'),
    build: n => {
      const props = {};
      if (is(n, 'on-hero')) props.hero = true;
      if (has(n, 'glass', 'appbar-glass')) props.glass = true;
      if (n.parentHero) props.hero = true;
      return { widget: 'FixoAppBar', props, children: n.children };
    } },

  { name: 'back',
    match: n => is(n, 'back'),
    build: n => ({ widget: 'FixoBackButton', props: { label: n.attrs['aria-label'] || 'Back' },
                   children: [], selfClosing: true }) },

  { name: 'icon-button',
    match: n => (is(n, 'ico-btn') || is(n, 'ibtn')) && !n.text,
    build: n => ({ widget: 'THIconButton', props: { icon: n.icon || 'Icons.more_horiz',
                   label: n.attrs['aria-label'] || n.attrs.title || null },
                   children: [], selfClosing: true }) },

  { name: 'appbar-title',
    match: n => is(n, 'ttl'),
    build: n => ({ widget: 'THAppBarTitle', props: { text: n.text || '' }, children: [], selfClosing: true }) },

  { name: 'spacer/grow',
    match: n => is(n, 'grow') || is(n, 'spacer'),
    build: () => ({ widget: 'Spacer', props: {}, children: [], selfClosing: true }) },

  // ── hero / headers ────────────────────────────────────────────────────────
  { name: 'heroband',
    match: n => is(n, 'heroband'),
    build: n => ({ widget: 'THHeroBand', props: {}, children: n.children, markHero: true }) },

  { name: 'maphead',
    match: n => is(n, 'maphead'),
    build: n => ({ widget: 'THMapHeader', props: { heightRatio: n.styleRatio || null }, children: n.children }) },

  { name: 'status-strip',
    match: n => is(n, 'status-strip'),
    build: n => ({ widget: 'THStatusStrip', props: {}, children: n.children }) },

  // ── buttons ───────────────────────────────────────────────────────────────
  { name: 'button-primary',
    match: n => is(n, 'btn', 'btn-primary'),
    build: n => ({ widget: 'FixoPrimaryButton', props: { label: n.text || '', icon: n.icon || null,
                   onPressed: '__CLOSURE__' }, children: [], selfClosing: true }) },
  { name: 'button-secondary',
    match: n => is(n, 'btn', 'btn-secondary'),
    build: n => ({ widget: 'FixoSecondaryButton', props: { label: n.text || '' }, children: [], selfClosing: true }) },
  { name: 'button-danger',
    match: n => is(n, 'btn', 'btn-danger'),
    build: n => ({ widget: 'FixoDangerButton', props: { label: n.text || '' }, children: [], selfClosing: true }) },
  { name: 'button-ghost',
    match: n => is(n, 'btn', 'btn-ghost'),
    build: n => ({ widget: 'FixoGhostButton', props: { label: n.text || '' }, children: [], selfClosing: true }) },
  { name: 'button-navy',
    match: n => is(n, 'btn', 'btn-navy'),
    build: n => ({ widget: 'FixoNavyButton', props: { label: n.text || '' }, children: [], selfClosing: true }) },
  { name: 'button-tonal',
    match: n => is(n, 'btn', 'btn-tonal'),
    build: n => ({ widget: 'FixoTonalButton', props: { label: n.text || '', icon: n.icon || null },
                   children: [], selfClosing: true }) },
  { name: 'button-disabled',
    match: n => is(n, 'btn', 'disabled') || (is(n, 'btn') && n.attrs['aria-disabled'] === 'true'),
    build: n => ({ widget: 'FixoPrimaryButton', props: { label: n.text || '', onPressed: null },
                   children: [], selfClosing: true }) },
  { name: 'button-generic',
    match: n => is(n, 'btn'),
    build: n => ({ widget: 'FixoPrimaryButton', props: { label: n.text || '' }, children: [], selfClosing: true }) },
  { name: 'button-row',
    match: n => is(n, 'btnrow'),
    build: n => ({ widget: 'THButtonRow', props: {}, children: n.children }) },
  { name: 'fab',
    match: n => is(n, 'fab'),
    build: n => ({ widget: 'THFab', props: { icon: n.icon || 'Icons.add' }, children: [], selfClosing: true }) },

  // ── status / labels ───────────────────────────────────────────────────────
  { name: 'pill',
    match: n => is(n, 'pill'),
    build: n => {
      const kind = ['action', 'active', 'waiting', 'done', 'muted', 'problem']
        .find(k => (n.classes || []).includes(`pill-${k}`)) || 'neutral';
      return { widget: 'THStatusPill', props: { kind, label: n.text || '', icon: n.icon || null },
               children: [], selfClosing: true };
    } },
  { name: 'badge',
    match: n => is(n, 'badge'),
    build: n => ({ widget: 'THBadge', props: { label: n.text || '', good: is(n, 'good'), icon: n.icon || null },
                   children: [], selfClosing: true }) },
  { name: 'badges-wrap',
    match: n => is(n, 'badges'),
    build: n => ({ widget: 'Wrap', props: { spacing: 'Space.s2', runSpacing: 'Space.s2' }, children: n.children }) },
  { name: 'urg-tag',
    match: n => is(n, 'urg'),
    build: n => ({ widget: 'THUrgencyTag', props: { level: is(n, 'high') ? 'high' : (is(n, 'low') ? 'low' : 'normal'), label: n.text || '' },
                   children: [], selfClosing: true }) },
  { name: 'cpb',
    match: n => is(n, 'cpb'),
    build: n => ({ widget: 'THStepProgress', props: { step: n.step || 1, total: 4, caption: n.caption || null },
                   children: [], selfClosing: true }) },
  { name: 'countdown',
    match: n => is(n, 'countdown'),
    build: n => ({ widget: 'THCountdown', props: { urgent: n.isUrgent, progress: n.progress || null, label: n.label || null },
                   children: [], selfClosing: true }) },

  // ── scrollers / rows ──────────────────────────────────────────────────────
  { name: 'faderow',
    match: n => is(n, 'faderow'),
    build: n => ({ widget: 'THFadeRow', props: { fadeWidth: 'Space.s7' }, children: n.children,
                   comment: 'horizontal ListView + 32px fade (mockup rule: chip rows scroll)' }) },
  { name: 'chip',
    match: n => is(n, 'chip'),
    build: n => ({ widget: 'THFilterChip', props: { label: n.text || '', selected: is(n, 'sel'), outlined: is(n, 'outline') },
                   children: [], selfClosing: true }) },
  { name: 'seg48',
    match: n => is(n, 'seg48'),
    build: n => ({ widget: 'THSegmented', props: { options: n.options || [] }, children: [], selfClosing: true }) },
  { name: 'spread',
    match: n => is(n, 'spread'),
    build: n => ({ widget: 'Row', props: { mainAxisAlignment: 'MainAxisAlignment.spaceBetween', crossAxisAlignment: 'CrossAxisAlignment.center' },
                   children: n.children, spread: true }) },
  { name: 'row',
    match: n => is(n, 'row'),
    build: n => { const p = { };
      const g = style(n).gap; if (g) { const e = spacingExpr(g); if (e) p.spacing = e; }
      return { widget: 'Row', props: p, children: n.children }; } },
  { name: 'stack',
    match: n => has(n, 'stack', 'stack8', 'stack16', 'stack20'),
    build: n => ({ widget: 'Column', props: { crossAxisAlignment: 'CrossAxisAlignment.stretch',
                   spacing: is(n, 'stack8') ? 'Space.s2' : is(n, 'stack16') ? 'Space.s4' : is(n, 'stack20') ? 'Space.gutter' : 'Space.s3' },
                   children: n.children }) },
  { name: 'divider',
    match: n => is(n, 'divider'),
    build: () => ({ widget: 'THDivider', props: {}, children: [], selfClosing: true }) },

  // ── surfaces ──────────────────────────────────────────────────────────────
  { name: 'card',
    match: n => is(n, 'card') || is(n, 'attcard'),
    build: n => ({ widget: 'FixoCard', props: {}, children: n.children }) },
  { name: 'tile',
    match: n => is(n, 'tile'),
    build: n => ({ widget: 'FixoCard', props: { radius: 'Radii.tile' }, children: n.children }) },
  { name: 'list-group',
    match: n => is(n, 'list-group'),
    build: n => ({ widget: 'THListGroup', props: {}, children: n.children }) },
  { name: 'list-row',
    match: n => is(n, 'list-row') || is(n, 'listitem'),
    build: n => ({ widget: 'THListRow', props: { selected: is(n, 'sel') }, children: n.children }) },
  { name: 'sheet',
    match: n => is(n, 'sheet'),
    build: n => ({ widget: 'THSheet', props: {}, children: n.children }) },
  { name: 'sticky-cta',
    match: n => is(n, 'sticky'),
    build: n => ({ widget: 'THStickyCta', props: {}, children: n.children }) },
  { name: 'toast',
    match: n => is(n, 'toast'),
    build: n => ({ widget: 'THToast', props: { message: n.text || '' }, children: [], selfClosing: true }) },
  { name: 'banner',
    match: n => is(n, 'banner'),
    build: n => ({ widget: 'THBanner', props: { tone: n.tone || 'info' }, children: n.children }) },
  { name: 'skeleton',
    match: n => is(n, 'skel'),
    build: n => ({ widget: 'THSkeleton', props: { width: null, height: null }, children: [], selfClosing: true }) },

  // ── inputs ────────────────────────────────────────────────────────────────
  { name: 'field',
    match: n => is(n, 'field'),
    build: n => ({ widget: 'THField', props: { label: n.label || null, error: n.error || null },
                   children: n.children.filter(c => c.tag !== 'label') }) },
  { name: 'input',
    match: n => is(n, 'input'),
    build: n => ({ widget: 'THInput', props: { state: n.inputState || 'default', value: n.text || '',
                   icon: n.icon || null, placeholder: n.placeholder || null },
                   children: [], selfClosing: true }) },
  { name: 'otp',
    match: n => is(n, 'otp'),
    build: n => ({ widget: 'THOtpInput', props: { length: n.digitCount || 5 }, children: [], selfClosing: true }) },
  { name: 'switch',
    match: n => is(n, 'switch'),
    build: n => ({ widget: 'THSwitch', props: { value: is(n, 'on') }, children: [], selfClosing: true }) },

  // ── media / identity ──────────────────────────────────────────────────────
  { name: 'avatar',
    match: n => is(n, 'av'),
    build: n => {
      const sz = n.sizePx || 44;
      const sizeExpr = t.size(sz) || `${sz}.0`;
      return { widget: 'FixoAvatar', props: { initials: (n.text || '').trim(), size: sizeExpr,
        verified: !!n.hasVbdg }, children: [], selfClosing: true };
    } },
  { name: 'image',
    match: n => n.tag === 'img',
    build: n => ({ widget: 'THArt', props: { asset: n.assetBase ? `assets/design/${n.assetBase}` : null,
                   semanticLabel: n.attrs.alt || null }, children: [], selfClosing: true }) },
  { name: 'phototile',
    match: n => is(n, 'phototile'),
    build: n => ({ widget: 'THPhotoTile', props: {}, children: n.children }) },
  { name: 'cat-tile',
    match: n => is(n, 'cat-tile'),
    build: n => ({ widget: 'THCategoryTile', props: { label: n.text || '', icon: n.icon || null },
                   children: [], selfClosing: true }) },
  { name: 'icon-tile',
    match: n => is(n, 'icon-tile'),
    build: n => ({ widget: 'THIconTile', props: { icon: n.icon || null }, children: n.children }) },
  { name: 'svc-row',
    match: n => is(n, 'svc'),
    build: n => ({ widget: 'THServiceRow', props: { label: n.text || '', rate: n.rate || null },
                   children: [], selfClosing: true }) },

  // ── chat ──────────────────────────────────────────────────────────────────
  { name: 'bubble',
    match: n => is(n, 'bubble'),
    build: n => ({ widget: 'THChatBubble', props: { sent: is(n, 'sent'), text: n.text || '' },
                   children: [], selfClosing: true }) },
  { name: 'composer',
    match: n => is(n, 'composer'),
    build: n => ({ widget: 'THComposer', props: { placeholder: n.placeholder || 'Message…' },
                   children: [], selfClosing: true }) },
  { name: 'msgrow',
    match: n => is(n, 'msgrow'),
    build: n => ({ widget: 'THMessageRow', props: { name: n.name, time: n.time, preview: n.preview, unread: n.unread },
                   children: [], selfClosing: true }) },

  // ── nav ───────────────────────────────────────────────────────────────────
  { name: 'navbar',
    match: n => is(n, 'navbar') || is(n, 'rail'),
    build: n => ({ widget: 'THNavBar', props: { rail: is(n, 'rail'), items: n.navItems || [] },
                   children: [], selfClosing: true }) },

  // ── layout containers ─────────────────────────────────────────────────────
  { name: 'pad',
    match: n => is(n, 'pad'),
    build: n => ({ widget: 'Padding', props: { padding: 'const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.s4)' },
                   children: n.children }) },
  { name: 'scroll',
    match: n => is(n, 'scroll'),
    build: n => ({ widget: 'SingleChildScrollView', props: {}, children: n.children }) },
  { name: 'center',
    match: n => is(n, 'center'),
    build: n => ({ widget: 'Center', props: {}, children: n.children }) },
  { name: 'grid2',
    match: n => is(n, 'grid2'),
    build: n => ({ widget: 'GridView', props: { crossAxisCount: 2, spacing: 'Space.s3' }, children: n.children }) },
  { name: 'content-column',
    match: n => n.tag === 'div' && !n.text && !is(n, 'frame') && n.children.length > 0,
    build: n => ({ widget: 'Column', props: { crossAxisAlignment: 'CrossAxisAlignment.stretch' },
                   children: n.children }) },

  // ── text ──────────────────────────────────────────────────────────────────
  { name: 'heading1', match: n => is(n, 'h1') || is(n, 'title'),
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.display' }, textKind: 'display', children: [], selfClosing: true }) },
  { name: 'heading2', match: n => is(n, 'h2'),
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.section' }, textKind: 'section', children: [], selfClosing: true }) },
  { name: 'eyebrow', match: n => is(n, 'eyebrow'),
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.caption' }, textKind: 'caption', children: [], selfClosing: true }) },
  { name: 'secondary', match: n => is(n, 'sec'),
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.secondary' }, textKind: 'secondary', children: [], selfClosing: true }) },
  { name: 'caption', match: n => is(n, 'cap'),
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.caption' }, textKind: 'caption', children: [], selfClosing: true }) },
  { name: 'mono', match: n => is(n, 'mono') || is(n, 'cb'),
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.mono' }, textKind: 'mono', children: [], selfClosing: true }) },
  { name: 'price', match: n => is(n, 'price'),
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.price' }, textKind: 'price', children: [], selfClosing: true }) },
  { name: 'wordmark',
    match: n => is(n, 'wordmark'),
    build: n => ({ widget: 'FixoWordmark', props: { inverse: is(n, 'inv') }, children: [], selfClosing: true }) },
  { name: 'bare-text',
    match: n => n.tag === 'span' || n.tag === 'b' || n.tag === 'small' || n.tag === 'p',
    build: n => ({ widget: 'Text', props: { text: n.text || '', style: 'THType.body' },
                   textKind: 'body', children: [], selfClosing: true }) },

  // ── fallback: any text-bearing leaf becomes a Text widget ────────────────
  { name: 'text-fallback',
    match: n => !!n.text && !is(n, 'frame'),
    build: n => {
      let styleExpr = 'THType.body';
      const st = n.style || {};
      if (st.font) {
        const m = /(?:^|\s)(\d+)\s+(\d+(?:\.\d+)?)px\s+var\(--(fd|fb|fm)\)/.exec('' + st.font);
        if (m) {
          const weight = /\b700\b/.test(st.font) ? '700' : /\b600\b/.test(st.font) ? '600' : '500';
          const key = weight + '/' + m[2] + '/' + m[3];
          styleExpr = t.TYPE[key] || styleExpr;
        }
      }
      return { widget: 'Text', props: { text: n.text, style: styleExpr },
               textKind: 'inferred', children: [], selfClosing: true };
    } },
];

module.exports = { RULES, is, has };
