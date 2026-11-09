# Brand + app-icon assets, generated from one geometry so every export matches. Run: python3 tools/make_brand.py assets/brand
import sys, math
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
out = sys.argv[1]; FONT = sys.argv[2] if len(sys.argv) > 2 else 'fonts/space-grotesk-latin-700-normal.woff2'
NAVY, BLUE, AMBER, ON_AMBER, CREAM = '#193957', '#3C75AA', '#E38B29', '#241300', '#F6F4EE'
PIN = 'M512 214c-104 0-188 80-188 182 0 134 188 306 188 306s188-172 188-306c0-102-84-182-188-182Z'
def hexa(cx, cy, r): return 'M' + 'L'.join(f'{cx + r*math.cos(math.radians(60*i+30)):.1f} {cy + r*math.sin(math.radians(60*i+30)):.1f}' for i in range(6)) + 'Z'
NUT = hexa(512, 396, 92); HOLE = (512, 396, 36)
def mark(pin='#FFFFFF', nut=AMBER, hole=NAVY):
    return f'<path d="{PIN}" fill="{pin}"/><path d="{NUT}" fill="{nut}" stroke="{nut}" stroke-width="14" stroke-linejoin="round"/><circle cx="{HOLE[0]}" cy="{HOLE[1]}" r="{HOLE[2]}" fill="{hole}"/>'
BIG = lambda: '<g transform="translate(512 470) scale(1.25) translate(-512 -470)">' + mark() + '</g>'
GRAD = f'<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{NAVY}"/><stop offset="1" stop-color="{BLUE}"/></linearGradient></defs>'
def svg(body, w=1024, h=1024, vb='0 0 1024 1024'): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{vb}">{body}</svg>\n'
w = lambda n, s: open(f'{out}/{n}.svg', 'w').write(s)
# iOS: full-bleed square (OS masks the corners)
w('app-icon-ios-1024', svg(GRAD + f'<rect width="1024" height="1024" fill="url(#g)"/>' + BIG()))
w('app-icon-preview-rounded', svg(GRAD + f'<rect width="1024" height="1024" rx="230" fill="url(#g)"/>' + BIG()))
# Android adaptive: 108dp canvas, 66dp safe zone => mark scaled to 0.62 about centre
w('app-icon-android-background', svg(GRAD + '<rect width="1024" height="1024" fill="url(#g)"/>'))
w('app-icon-android-foreground', svg(f'<g transform="translate(512 512) scale(.85) translate(-512 -512)">{mark()}</g>'))
w('app-icon-android-monochrome', svg(f'<g transform="translate(512 512) scale(.85) translate(-512 -512)"><path fill-rule="evenodd" d="{PIN} {NUT}" fill="#000"/></g>'))
w('notification-icon-24', svg(f'<path fill-rule="evenodd" fill="#fff" d="{PIN} {NUT}"/>', 96, 96, '212 180 600 560'))
w('splash-logo', svg(mark(pin='#FFFFFF', nut=AMBER, hole=NAVY), 240, 240, '224 180 576 560'))
w('favicon', svg(GRAD + f'<rect width="1024" height="1024" rx="230" fill="url(#g)"/>' + mark(), 64, 64))
# map pins (in-app): job, tradie, selected
def mp(fill, inner, sel=False):
    r = 1.25 if sel else 1
    return svg(f'<g transform="translate(512 512) scale({r}) translate(-512 -512)"><path d="{PIN}" fill="{fill}" stroke="#FFFFFF" stroke-width="36" paint-order="stroke"/><circle cx="512" cy="396" r="92" fill="{inner}"/></g>', 48 if not sel else 60, 48 if not sel else 60, '180 150 664 700')
w('map-pin-job', mp(NAVY, '#FFFFFF')); w('map-pin-tradie', mp(BLUE, '#FFFFFF')); w('map-pin-selected', mp(NAVY, AMBER, True))
# wordmark as outlined paths (no font dependency in production)
f = TTFont(FONT); gs = f.getGlyphSet(); cmap = f.getBestCmap(); upm = f['head'].unitsPerEm; hmtx = f['hmtx']
def outline(text, size, x0=0, kern=-0.02):
    sc = size / upm; x = x0; parts = []
    for ch in text:
        g = cmap[ord(ch)]; pen = SVGPathPen(gs); tp = TransformPen(pen, (sc, 0, 0, -sc, x, size * 0.8)); gs[g].draw(tp)
        parts.append(pen.getCommands()); x += hmtx[g][0] * sc + kern * size
    return parts, x
a, xa = outline('Tradie', 120); b, xb = outline('Hunter', 120, xa)
def wm(c1, c2, name): w(name, svg(f'<path d="{" ".join(a)}" fill="{c1}"/><path d="{" ".join(b)}" fill="{c2}"/>', int(xb), 130, f'0 0 {int(xb)} 130'))
wm(NAVY, '#8F4F08', 'wordmark-on-light'); wm('#FFFFFF', AMBER, 'wordmark-on-navy'); wm('#ECEAE3', AMBER, 'wordmark-on-dark'); wm('#000000', '#000000', 'wordmark-mono')
print('brand assets written')
