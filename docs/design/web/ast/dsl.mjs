// TradieHunter web screen AST: node builders. Every node is plain JSON { t, ...props, c?: [children] }.
// Add a node type in 3 places: here, the KNOWN set + H() switch in tools/build.mjs, and css/kit.css if it needs styles.
//
// Prop cheat-sheet (full table: DESIGN_GUIDE.md §6)
//   tone    badges/banners: neutral | info | ok | warn | danger        text: default | soft | brand | accent | ok | danger
//   k       buttons: accent | primary | secondary | ghost | danger | dangerOutline    sz: sm | lg
//   x       child grows to fill the remaining row space
const n = (t, p = {}, c = []) => ({ t, ...p, ...(c.length ? { c } : {}) });
const split = (a) => (a[0] && a[0].t === undefined && !Array.isArray(a[0]) ? [a[0], a.slice(1)] : [{}, a]);
const box = (t) => (...a) => { const [p, c] = split(a); return n(t, p, c.flat()); };

// ── Status → badge tone. This is the web StatusBadge contract (replaces green/amber/red/blue/gray/brand). ──
export const STATUS = {
  // Job
  Requested: 'info', AwaitingPayment: 'warn', PaymentReview: 'warn', Booked: 'ok', InProgress: 'info', AwaitingConfirmation: 'warn',
  Completed: 'neutral', Cancelled: 'danger', Expired: 'neutral', Disputed: 'danger',
  // Role
  Superadmin: 'info', Staff: 'info', Homeowner: 'neutral', Tradie: 'info',
  // Account
  Active: 'ok', Inactive: 'neutral', Verified: 'ok', Unverified: 'warn',
  // Dispute
  Open: 'warn', Resolved: 'ok', Escalated: 'danger', None: 'neutral',
};

export const stack = box('stack');
export const row = box('row');
export const grid = box('grid');
export const card = box('card');
export const hero = box('hero');
export const filterbar = box('filterbar');
export const text = (v, s = 'body', p = {}) => n('text', { v, s, ...p });
export const icon = (name, p = {}) => n('icon', { n: name, ...p });
export const btn = (v, k = 'primary', p = {}) => n('btn', { v, k, ...p });
export const ibtn = (ic, label, k = 'ghost', p = {}) => n('ibtn', { ic, label, k, ...p });
export const badge = (v, tone = 'neutral', p = {}) => n('badge', { v, tone, ...p });
export const status = (v, p = {}) => n('badge', { v, tone: STATUS[v] ?? 'neutral', dot: true, ...p });
export const avatar = (v, sz = 'md', p = {}) => n('avatar', { v, sz, ...p });
export const field = (label, v, p = {}) => n('field', { label, v, ...p });
export const search = (ph, p = {}) => n('search', { ph, ...p });
export const select = (v, p = {}) => n('select', { v, ...p });
export const choice = (kind, label, on = false, p = {}) => n('choice', { kind, label, on, ...p });
export const seg = (items, on = 0, p = {}) => n('seg', { items, on, ...p });
export const tabs = (items, on = 0, p = {}) => n('tabs', { items, on, ...p });
export const chips = (items, p = {}) => n('chips', { items, ...p });
export const drop = (ic, v, p = {}) => n('drop', { ic, v, ...p });
export const banner = (tone, title, v, p = {}) => n('banner', { tone, title, v, ...p });
export const toast = (tone, title, v, p = {}) => n('toast', { tone, title, v, ...p });
export const empty = (ic, title, v, action, p = {}) => n('empty', { ic, title, v, action, ...p });
export const skeleton = (rows = 3, p = {}) => n('skeleton', { rows, ...p });
export const stat = (label, value, p = {}) => n('stat', { label, value, ...p });
export const dl = (items, p = {}) => n('dl', { items, ...p });
export const stepper = (items, p = {}) => n('stepper', { items, ...p });
export const timeline = (items, p = {}) => n('timeline', { items, ...p });
export const table = (cols, rows, p = {}) => n('table', { cols, rows, ...p });
export const pager = (from, to, total, page, pages, p = {}) => n('pager', { from, to, total, page, pages, ...p });
export const modal = (title, body, foot, p = {}) => n('modal', { title, body, foot, ...p });
export const menu = (items, p = {}) => n('menu', { items, ...p });
export const money = (v, p = {}) => n('money', { v, ...p });
export const mono = (v, p = {}) => n('mono', { v, ...p });
export const wordmark = (p = {}) => n('wordmark', p);
export const tile = (ic, p = {}) => n('tile', { ic, ...p });
export const gap = (px) => n('gap', { n: px });
export const auth = (aside, main) => n('auth', {}, [n('stack', { slot: 'aside' }, [aside].flat()), n('stack', { slot: 'main' }, [main].flat())]);

// screen(meta, ...bodyNodes)
//   meta: id, title, route, nav (route key highlighted in the sidebar), crumbs [[label, href?]], h1, sub, badge (node),
//         actions [nodes], shell ('full' | 'rail' | 'phone' | 'none'), w (frame width px), h (frame height px), overlay (modal node)
export const screen = (meta, ...body) => ({ shell: 'full', w: 1280, h: 820, ...meta, body: body.flat() });
