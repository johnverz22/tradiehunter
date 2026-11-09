#!/usr/bin/env python3
"""Render every [data-frame] element of the given build HTML files to PNG (1x).
Usage: python3 render.py build/frames-entry.html [more.html ...] [--out frames] [--scale 1]
Requires: pip install playwright && playwright install chromium"""
import sys, os, argparse
from playwright.sync_api import sync_playwright
ap = argparse.ArgumentParser(); ap.add_argument('files', nargs='+'); ap.add_argument('--out', default='frames'); ap.add_argument('--scale', type=float, default=1)
a = ap.parse_args(); os.makedirs(a.out, exist_ok=True); n = 0
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(device_scale_factor=a.scale)
    for f in a.files:
        pg.goto('file://' + os.path.abspath(f)); pg.evaluate('document.fonts.ready'); pg.wait_for_timeout(250)
        for el in pg.query_selector_all('[data-frame]'):
            el.screenshot(path=os.path.join(a.out, el.get_attribute('data-frame') + '.png')); n += 1
    b.close()
print(n, 'frames ->', a.out)
