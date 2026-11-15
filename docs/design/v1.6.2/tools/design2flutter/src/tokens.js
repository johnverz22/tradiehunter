/**
 * tokens.js — design token dictionary: CSS values (from kit.css / tokens.json)
 * -> Dart theme expressions. The transpiler may NEVER emit a raw literal that
 * exists here; unknown values fail loudly instead of falling back to a hardcode.
 */
'use strict';

// CSS custom property -> Dart expression (theme-aware unless noted constant).
const CSS_VARS = {
  // semantic (swap per theme) — read through THColors extension
  '--paper': 'theme.paper', '--surface': 'theme.surface', '--line': 'theme.line',
  '--text': 'theme.text', '--text-soft': 'theme.textSoft', '--text-brand': 'theme.textBrand',
  '--brand': 'theme.brand', '--on-brand': 'theme.onBrand',
  '--accent-text': 'theme.accentText', '--success-text': 'theme.success',
  '--danger-text': 'theme.danger',
  '--tint-brand': 'theme.tintBrand', '--track': 'theme.track',
  '--av-tradie': 'theme.avTradie', '--on-av-tradie': 'theme.onAvTradie',
  // raw palette — constants (Theme-agnostic); only for cases the spec marks constant
  '--navy': 'THPalette.navy', '--blue': 'THPalette.blue', '--blue300': 'THPalette.blue300',
  '--blue700': 'THPalette.blue700', '--blue100': 'THPalette.blue100',
  '--amber': 'THPalette.amber', '--amber-dark': 'THPalette.amberDark',
  '--on-amber': 'THPalette.onAmber', '--green': 'THPalette.green', '--red': 'THPalette.red',
  '--cream': 'THPalette.cream', '--ink': 'THPalette.ink',
  // hero glass — constants (heroes are navy in every theme; FIX_SPECIFICATION §F-114)
  '--on-hero-soft': 'THHeroGlass.soft', '--on-hero-faint': 'THHeroGlass.faint',
  '--hero-track': 'THHeroGlass.track',
  '#fff': 'Colors.white', '#ffffff': 'Colors.white',
};

// spacing: px -> Space token (4px grid; 20px gutter)
function space(px) {
  const grid = { 0: '0', 2: '1', 4: 'Space.s1', 8: 'Space.s2', 12: 'Space.s3', 16: 'Space.s4',
    20: 'Space.gutter', 24: 'Space.s6', 28: 'Space.s7', 32: 'Space.s7', 40: 'Space.s8' };
  if (px === 20) return 'Space.gutter';
  if (grid[px]) return grid[px];
  if (px % 4 === 0) return `${px / 4} * Space.s1`; // composed, still token-derived
  return null;                                      // off-grid -> caller decides
}

// radii: px -> Radii token
function radius(px) {
  const r = { 2: '2', 3: '3', 8: 'Radii.control / 1.75', 10: 'Radii.control - 4', 11: 'Radii.control - 3',
    12: 'Radii.control + -2', 14: 'Radii.control', 16: 'Radii.tile', 20: 'Radii.card',
    24: 'Radii.sheet - 4', 28: 'Radii.sheet', 32: 'Radii.sheet + 4', 999: 'Radii.pill', 9999: 'Radii.pill' };
  if (r[px] !== undefined) return r[px];
  return null;
}

// sizes: px -> Sizes token or named constant
function size(px) {
  const s = { 24: '24', 26: '26', 28: '28', 32: '32', 36: 'Sizes.avatarSm', 40: '40', 44: 'Sizes.tapMin - 4',
    48: 'Sizes.tapMin', 52: 'Sizes.buttonSecondary', 56: 'Sizes.button', 68: 'Sizes.nav' };
  if (s[px] !== undefined) return s[px];
  return null;
}

// typography scale: [family, weight, px] -> THType style name
const TYPE = {
  '700/40/fd': 'THType.hero', '700/28/fd': 'THType.display', '600/20/fd': 'THType.section',
  '700/24/fb': 'THType.price', '600/18/fb': 'THType.cardTitle', '600/22/fb': 'THType.cardTitle',
  '400/16/fb': 'THType.body', '500/16/fb': 'THType.body', '400/14/fb': 'THType.secondary',
  '500/14/fb': 'THType.secondary', '500/15/fb': 'THType.body', '600/14/fb': 'THType.secondaryW600',
  '500/13/fb': 'THType.secondary', '400/13/fb': 'THType.secondary', '600/13/fb': 'THType.secondaryW600',
  '500/12/fb': 'THType.caption', '600/12/fb': 'THType.caption', '500/12/fm': 'THType.mono',
  '500/13/fm': 'THType.mono', '700/16/fd': 'THType.cardTitle',
};

// font shorthand families used in kit
const FAMILY = { 'var(--fd)': 'fd', 'var(--fb)': 'fb', 'var(--fm)': 'fm' };

module.exports = { CSS_VARS, space, radius, size, TYPE, FAMILY };
