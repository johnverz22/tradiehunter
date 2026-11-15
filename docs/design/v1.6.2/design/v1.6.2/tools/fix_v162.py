#!/usr/bin/env python3
"""v1.6.2 fixes — implements every remediation in docs/design/v1.6.1/FIX_SPECIFICATION.md.

Run from the v1.6.2 root:  python3 tools/fix_v162.py
Idempotent: safe to re-run. Each fix is tagged with its finding ID.
"""
import re, glob, os, sys
from bs4 import BeautifulSoup

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HTML = os.path.join(ROOT, 'html')
stats = {}


def bump(key, n=1):
    stats[key] = stats.get(key, 0) + n


# ── kit.css fixes (F-101/102/103/106/107/109/113/116) ─────────────────────────
def fix_kit():
    p = os.path.join(HTML, 'kit.css')
    css = open(p, encoding='utf-8').read()
    orig = css

    # F-106 outdoor line typo: 255,57,87 (pink) -> 25,57,87 (navy) per design_tokens.dart
    css, n = re.subn(r'--line:\s*rgba\(255,\s*57,\s*87,\s*\.28\)', '--line: rgba(25,57,87,.28)', css)
    bump('F-106_line_typo', n)

    # F-101 row-direction master-detail must be allowed to shrink
    if '.md { display: flex; flex: 1; min-height: 0; }' in css:
        css = css.replace('.md { display: flex; flex: 1; min-height: 0; }',
                          '.md { display: flex; flex: 1; min-height: 0; min-width: 0; }')
        bump('F-101_md_minw')

    # F-102 status-strip pills: strip is navy in BOTH themes -> fixed light ink
    css, n = re.subn(r'\.status-strip \.pill \{ background: rgba\(255,255,255,\.16\); color: var\(--on-brand\); \}',
                     '.status-strip .pill { background: rgba(255,255,255,.16); color: #fff; }', css)
    bump('F-102_strip_pill', n)

    # F-103 + F-116 dark overrides appended near the existing .dark pill rules
    if '.dark .status-strip .pill-problem' not in css:
        css = css.replace('.dark .pill-problem { background: rgba(232,150,142,.14); color: var(--ink-danger-d); }',
                          '.dark .pill-problem { background: rgba(232,150,142,.14); color: var(--ink-danger-d); }\n'
                          '.dark .status-strip .pill-problem { color: var(--ink-danger-d); }   /* F-103 */\n'
                          '.dark .badge.good { background: rgba(143,201,168,.16); color: var(--ink-success-d); }  /* F-116 */')
        bump('F-103_F-116_dark_overrides')

    # F-109 map back button 44 -> 48 (48dp tap floor, matches every other back)
    css, n = re.subn(r'(\.maphead \.appbar \.back, \.maphead \.appbar \.ico-btn \{[^}]*?)width: 44px; height: 44px;',
                     r'\g<1>width: 48px; height: 48px;', css)
    bump('F-109_map_back_48', n)

    # F-107 promote shared component classes into the kit (single source of truth)
    promo = """
/* ═════════ v1.6.2 — shared components promoted from per-file styles (F-107) ═════════ */
.ill-card { border-radius: 24px; background: var(--surface); border: 1px solid var(--line); overflow: hidden; display: grid; place-items: center; }
.listitem { padding: 14px 16px; border-bottom: 1px solid var(--line); }
.herotile { background: var(--surface); border-radius: 16px; padding: 12px 14px; color: var(--text-brand); }
.svc { height: 56px; border-radius: 14px; background: var(--surface); border: 1px solid var(--line); display: flex; align-items: center; padding: 0 14px; gap: 10px; font: 500 15px var(--fb); }
.svc .rate { margin-left: auto; color: var(--text-soft); font-size: 13px; }
.blob-blue, .blob-peach { /* decorative blobs carry their fill in the SVG (F-107: named for transpiler mapping) */ }

/* F-113 keyboard focus (web preview a11y; Flutter maps to Focus highlight) */
.back:focus-visible, .ico-btn:focus-visible, .ibtn:focus-visible, .btn:focus-visible,
.chip:focus-visible, .seg48 .o:focus-visible, .cell:focus-visible, .tab:focus-visible {
  outline: 2px solid var(--brand); outline-offset: 2px; }

/* F-114 hero glass text tokens (were inline rgba on navy heroes) */
:root  { --on-hero-soft: rgba(255,255,255,.75); --on-hero-faint: rgba(255,255,255,.55); --hero-track: rgba(255,255,255,.25); }
.dark  { --on-hero-soft: rgba(255,255,255,.75); --on-hero-faint: rgba(255,255,255,.55); --hero-track: rgba(255,255,255,.25); }
.outdoor{ --on-hero-soft: rgba(255,255,255,.78); --on-hero-faint: rgba(255,255,255,.60); --hero-track: rgba(255,255,255,.28); }

/* F-118 avatar ink: --av-tradie is blue700 in light, blue300 in dark — ink flips with it */
:root { --on-av-tradie: #FFFFFF; }
.dark { --on-av-tradie: var(--navy); }
.outdoor { --on-av-tradie: #FFFFFF; }
"""
    if 'v1.6.2 — shared components promoted' not in css:
        css += promo
        bump('F-107_promote')

    # F-118 avatar ink tokens (appended independently so re-runs never skip it)
    if '--on-av-tradie' not in css:
        css += ('\n/* F-118 avatar ink: --av-tradie is blue700 in light, blue300 in dark — ink flips with it */\n'
                ':root { --on-av-tradie: #FFFFFF; }\n'
                '.dark { --on-av-tradie: var(--navy); }\n'
                '.outdoor { --on-av-tradie: #FFFFFF; }\n')
        bump('F-118_tokens')

    if css != orig:
        open(p, 'w', encoding='utf-8').write(css)


# ── HTML fixes ─────────────────────────────────────────────────────────────────
ARIA = {'i-bell': 'Notifications', 'i-send': 'Send message', 'i-cam': 'Attach photo',
        'i-more': 'More options', 'i-search': 'Search', 'i-call': 'Call', 'i-gear': 'Settings'}


def fix_html_file(path):
    src = open(path, encoding='utf-8').read()
    orig = src
    fname = os.path.basename(path)

    # F-105 kill the surface override on completed segments (dark killer)
    src, n = re.subn(r'(<div class="seg on") style="background:var\(--surface\)(">)', r'\g<1>\g<2>', src)
    bump('F-105_seg_inline', n)

    # F-104 hero stat tiles: raw palette -> semantic tokens (swaps in dark)
    src, n1 = re.subn(r'color:var\(--navy\);letter-spacing:-\.02em', 'color:var(--text-brand);letter-spacing:-.02em', src)
    src, n2 = re.subn(r'color:var\(--ink-success\);letter-spacing', 'color:var(--success-text);letter-spacing', src)
    bump('F-104_stat_tiles', n1 + n2)

    # F-108 tonal button back to 48dp
    src, n = re.subn(r'<div class="btn btn-tonal" style="height:44px;font-size:14px;width:100%">',
                     '<div class="btn btn-tonal" style="width:100%">', src)
    bump('F-108_tonal_48', n)

    # F-115 pill-waiting inline light tint defeats the dark override
    src, n = re.subn(r'(<div class="pill pill-waiting" style="[^"]*?)background:rgba\(60,117,170,\.12\);?([^"]*")', r'\g<1>\g<2>', src)
    bump('F-115_pill_inline', n)

    # F-114 tokenise the frequent inline colors (whitelisted: #fff text on navy heroes stays)
    subs = [
        (r'background:rgba\(60,117,170,\.12\)', 'background:var(--tint-brand)'),
        (r'background:#3C75AA', 'background:var(--av-tradie)'),
        (r'background:rgba\(25,57,87,\.06\)', 'background:var(--press)'),
        (r'background:rgba\(25,57,87,\.12\)', 'background:var(--track)'),
        (r'color:rgba\(255,255,255,\.75\)', 'color:var(--on-hero-soft)'),
        (r'color:rgba\(255,255,255,\.65\)', 'color:var(--on-hero-soft)'),
        (r'color:rgba\(255,255,255,\.55\)', 'color:var(--on-hero-faint)'),
        (r'background:rgba\(255,255,255,\.25\)', 'background:var(--hero-track)'),
        (r'border-top:rgba\(255,255,255,\.25\)', 'border-top:var(--hero-track)'),
    ]
    for pat, rep in subs:
        src, n = re.subn(pat, rep, src)
        bump(f'F-114_{rep.split("(")[0][:22]}', n)

    # F-118 dark avatar ink: av-tradie fill flips to blue300 in dark, so its white ink must flip too
    src, n = re.subn(r'(background:var\(--av-tradie\);)color:#fff', r'\g<1>color:var(--on-av-tradie)', src)
    bump('F-118_avatar_ink', n)

    # F-112 orange budget (raw pass): keep ONE urgency element per screen
    # H07 notification dot: amber -> blue300 (the pill + CTA stay the two permitted ambers)
    src, n = re.subn(r'width:8px;height:8px;border-radius:50%;background:var\(--amber\);border:2px solid var\(--navy\)',
                     'width:8px;height:8px;border-radius:50%;background:var(--blue300);border:2px solid var(--navy)', src)
    bump('F-112_h07_dot', n)
    # H17 rating histogram bars are data, not urgency — brand blue keeps amber for the CTA only
    src, n = re.subn(r'(height:6px;border-radius:3px;background:var\(--track\)"><div style="width:\d+%;height:100%;border-radius:3px;)background:var\(--amber\)',
                     r'\g<1>background:var(--brand)', src)
    bump('F-112_h17_bars', n)

    soup = BeautifulSoup(src, 'html.parser')

    # F-101 remove the phantom statusbar column in row-layout iPad frames
    for fr in soup.select('[data-frame]'):
        if not fr.get('data-frame', '').startswith('IPAD-messages'):
            continue
        for sb in fr.select(':scope > .statusbar'):
            sb.decompose()
            bump('F-101_ipad_statusbar')

    # F-110 aria-labels on remaining icon-only buttons
    for sel in ('.ico-btn', '.ibtn'):
        for el in soup.select(sel):
            if el.get('aria-label'):
                continue
            use = el.find('use')
            icon = (use.get('href') or '').lstrip('#') if use else ''
            label = ARIA.get(icon)
            if not label and el.get('class'):
                # fall back to semantic class names (send/cam carry inline SVG paths)
                cls = set(el.get('class'))
                if 'send' in cls:
                    label = 'Send message'
                elif 'cam' in cls:
                    label = 'Attach photo'
            if label and not el.get_text(strip=True):
                el['aria-label'] = label
                el['role'] = 'button'
                bump('F-110_aria')

    # F-111 alt attributes
    for img in soup.find_all('img'):
        if img.has_attr('alt'):
            continue
        src_attr = img.get('src', '')
        base = os.path.basename(src_attr)
        if re.match(r'^(rings|blob|noise|grid|contours|route|bpdots)', base):
            img['alt'] = ''                      # decorative
        elif base.startswith('il-'):
            img['alt'] = 'Illustration'          # placeholder for authored alt text
        else:
            img['alt'] = ''
        bump('F_111_alt')

    # F-112 orange budget (soup pass): H07 second action pill -> waiting pill
    for fr in soup.select('[data-frame]'):
        name = fr.get('data-frame', '')
        if name in ('H07-light', 'H07-dark'):
            pills = fr.select('.pill.pill-action')
            for p in pills[1:]:                  # keep only the first ("Action needed")
                p['class'] = ['pill', 'pill-waiting']
                bump('F-112_h07_pill')
        if name.startswith('IPAD-tradie-dark'):
            for cap in fr.select('.cap'):
                st = cap.get('style', '')
                if 'var(--accent-text)' in st or 'var(--amber)' in st:
                    cap['style'] = st.replace('var(--accent-text)', 'var(--text-soft)').replace('var(--amber)', 'var(--text-soft)')
                    bump('F-112_ipad_caps')

    out = str(soup)
    open(path, 'w', encoding='utf-8').write(out)


# ── documentation sheets (F-117) ───────────────────────────────────────────────
def fix_sheets():
    for fname in ('component-sheet.html', 'style-tile.html'):
        p = os.path.join(HTML, fname)
        if not os.path.exists(p):
            continue
        t = open(p, encoding='utf-8').read()
        # annotation labels to the 12px floor
        t, n1 = re.subn(r'font-size:\s*11px', 'font-size:12px', t)
        t, n2 = re.subn(r'font-size:\s*10px', 'font-size:12px', t)
        t, n3 = re.subn(r'font-size:\s*8\.3\d*px', 'font-size:12px', t)
        t, n4 = re.subn(r'(font:\s*\d+\s+)11px', r'\g<1>12px', t)
        t, n5 = re.subn(r'(font:\s*\d+\s+)10px', r'\g<1>12px', t)
        t, n6 = re.subn(r'(font:\s*\d+\s+)8\.3\d*px', r'\g<1>12px', t)
        # <small> scale captions default to 0.8em -> pin to the 12px floor
        t, n7 = re.subn(r'<small style="display:block;opacity:\.6">', '<small style="display:block;opacity:.6;font-size:12px">', t)
        # annotation ink: text-soft on the grey sheet page is 3.5:1 — documentation labels use full ink
        t, n8 = re.subn(r'\.cf \.lbl \{ font: 600 12px var\(--fm\); color: var\(--text-soft\);',
                        '.cf .lbl { font: 600 12px var(--fm); color: var(--text);', t)
        t, n9 = re.subn(r'\.src \{([^}]*)color: var\(--text-soft\)', r'.src {\g<1>color: var(--text)', t)
        bump(f'F-117_{fname}', n1 + n2 + n3 + n4 + n5 + n6 + n7 + n8 + n9)
        open(p, 'w', encoding='utf-8').write(t)


if __name__ == '__main__':
    fix_kit()
    for f in sorted(glob.glob(os.path.join(HTML, '*.html'))):
        if f.endswith('sprite.html'):
            continue
        fix_html_file(f)
    fix_sheets()
    for k in sorted(stats):
        print(f'{k}: {stats[k]}')
    print('DONE')
