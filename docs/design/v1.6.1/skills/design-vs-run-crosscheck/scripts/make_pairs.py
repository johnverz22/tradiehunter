#!/usr/bin/env python3
"""Side-by-side sheet: design frame | run screenshot, repeated. Usage:
 make_pairs.py --design frames --run docs/runs/v1.6/screenshots/light --out pairs.png --pair H07-light=homeowner/01_dashboard ..."""
import argparse
from PIL import Image
ap = argparse.ArgumentParser(); ap.add_argument('--design'); ap.add_argument('--run'); ap.add_argument('--out', default='pairs.png')
ap.add_argument('--pair', action='append', required=True); ap.add_argument('--h', type=int, default=900)
a = ap.parse_args()
def load(p):
    i = Image.open(p).convert('RGB'); return i.resize((int(i.width * a.h / i.height), a.h))
ims = []
for p in a.pair:
    d, r = p.split('=', 1); ims += [load(f'{a.design}/{d}.png'), load(f'{a.run}/{r}.png')]
w = max(i.width for i in ims); S = Image.new('RGB', (len(ims) * (w + 6), a.h + 10), 'white')
for k, i in enumerate(ims): S.paste(i, (k * (w + 6), 5))
S.save(a.out); print(a.out, S.size)
