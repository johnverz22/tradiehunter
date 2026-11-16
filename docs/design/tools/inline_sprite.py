"""Keep the icon sprite INSIDE every html/*.html (between markers) so the sources render standalone.
   Before v1.6.1 sources carried a %%SPRITE%% placeholder that only build/ replaced => every icon blank when html/ was opened."""
import sys, glob, re, os
root = sys.argv[1]
sprite = open(f'{root}/html/sprite.html').read()
blk = '<!--SPRITE-->' + sprite + '<!--/SPRITE-->'
n = 0
for f in glob.glob(f'{root}/html/*.html'):
    if f.endswith('sprite.html'): continue
    s = open(f).read(); o = s
    s = s.replace('%%SPRITE%%', blk)
    s = re.sub(r'<!--SPRITE-->.*?<!--/SPRITE-->', lambda m: blk, s, flags=re.S)
    if s != o: open(f, 'w').write(s); n += 1
print('sprite inlined in', n, 'files')
