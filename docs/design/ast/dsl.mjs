// TradieHunter screen AST — node builders.
// Every node is plain JSON: { t: <type>, ...props, c?: [children] }.
// Add a new node type in 4 places: here, build.mjs (html + dart emitters), th_widgets.dart.
//
// Prop cheat-sheet (see DESIGN_GUIDE.md §6 for the full table):
//   x: true            child fills remaining space (Flutter: Expanded)
//   gap / pad          px values, must exist in tokens.space
//   tone               default | soft | brand | accent | ok | danger | onHero | onHeroSoft | gold
//   k (kind)           buttons: primary | accent | secondary | inverse | ghost | danger
//                      badges:  brand | ok | accent | danger | glass
const n = (t, p = {}, c = []) => ({ t, ...p, ...(c.length ? { c } : {}) });
const split = (a) => (a[0] && a[0].t === undefined && !Array.isArray(a[0]) ? [a[0], a.slice(1)] : [{}, a]);
const box = (t) => (...a) => { const [p, c] = split(a); return n(t, p, c.flat()); };

export const col = box('col');
export const row = box('row');
export const card = box('card');
export const hero = box('hero');
export const grid = box('grid');
export const text = (v, s = 'body', p = {}) => n('text', { v, s, ...p });
export const icon = (name, p = {}) => n('icon', { n: name, ...p });
export const btn = (v, k = 'primary', p = {}) => n('btn', { v, k, ...p });
export const ibtn = (ic, k = 'secondary', p = {}) => n('ibtn', { ic, k, ...p });
export const badge = (v, k = 'brand', p = {}) => n('badge', { v, k, ...p });
export const avatar = (v, sz = 'md', p = {}) => n('avatar', { v, sz, ...p });
export const field = (l, v, p = {}) => n('field', { l, v, ...p });
export const pills = (items, p = {}) => n('pills', { items, ...p });
export const seg = (items, on = 0, p = {}) => n('seg', { items, on, ...p });
export const kv = (l, v, p = {}) => n('kv', { l, v, ...p });
export const prog = (steps, done, p = {}) => n('prog', { steps, done, ...p });
export const dots = (count, on, p = {}) => n('dots', { count, on, ...p });
export const dash = (ic, v, sub, p = {}) => n('dash', { ic, v, sub, ...p });
export const ring = (v, sub, pct, p = {}) => n('ring', { v, sub, pct, ...p });
export const sw = (on = true, p = {}) => n('sw', { on, ...p });
export const bubble = (v, mine = false, time = '', p = {}) => n('bubble', { v, mine, time, ...p });
export const tile = (ic, v, p = {}) => n('tile', { ic, v, ...p });
export const illus = (ic, p = {}) => n('illus', { ic, ...p });
export const otp = (count, v, p = {}) => n('otp', { count, v, ...p });
export const bars = (vals, labels, p = {}) => n('bars', { vals, labels, ...p });
export const mapv = (p = {}) => n('map', p);
export const stars = (v, p = {}) => n('stars', { v, ...p });
export const listrow = (ic, v, sub, p = {}) => n('listrow', { ic, v, sub, ...p });
export const photos = (count = 3, p = {}) => n('photos', { count, ...p });
export const timeline = (items, p = {}) => n('timeline', { items, ...p });
export const gap = (px) => n('gap', { n: px });
export const spacer = () => n('spacer');
export const divider = (label) => n('divider', label ? { v: label } : {});
export const bar = (v, sub, p = {}) => n('bar', { v, sub, ...p });

// screen(meta, ...bodyNodes)
//   meta.id, title, route, role (shared|homeowner|tradie)
//   meta.nav   = 'home'|'jobs'|'chat'|'profile'   (omit for no dock)
//   meta.dock  = 'homeowner' (5 slots with edge FAB) | 'tradie' (4 slots)
//   meta.bar   = bar(...)        meta.sticky = [nodes]    meta.bg = 'hero'
export const screen = (meta, ...body) => ({ ...meta, body: body.flat() });
