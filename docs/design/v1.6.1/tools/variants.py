# Generates dark + outdoor frames from the (single-source) light frames so theme variants can never drift.
import glob, re, sys, copy
from bs4 import BeautifulSoup
root = sys.argv[1]; H=f'{root}/html'
OUTDOOR = ['S01','S02','S03','S04','H10','H11','H15-success','T19','E-empty-leads','E-first-run','E-job-not-found','E-job-unavailable','E-no-messages','E-payment-expired','E-request-expired']
def mk(base_names):
    pass
lights = []
for f in sorted(glob.glob(f'{H}/frames-*.html')):
    if f.endswith(('frames-dark.html','frames-outdoor.html')): continue
    s = BeautifulSoup(open(f).read(),'html.parser')
    # drop hand-made legacy variants (regenerated below)
    for fr in s.select('[data-frame]'):
        n = fr['data-frame']
        if n.endswith(('-dark','-outdoor')): fr.decompose()
    open(f,'w').write(str(s))
    for fr in s.select('[data-frame]'):
        if fr['data-frame'].endswith('-light'): lights.append(fr)
def variant(fr, suffix, cls):
    c = copy.copy(fr)
    n = fr['data-frame']; base = n[:-len('-light')]
    c['data-frame'] = base + suffix
    c['class'] = [x for x in c['class'] if x not in ('dark','outdoor')] + [cls]
    for img in c.select('img'):
        src = img.get('src','')
        if cls=='dark' and src.endswith('-light.svg'): img['src'] = src.replace('-light.svg','-dark.svg')
    return c, base
head = '''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>v1.7 frames — %s</title>
<link rel="stylesheet" href="../fonts/fonts.css"><link rel="stylesheet" href="kit.css">
<style>.pg { background:%s; padding:40px; display:flex; flex-wrap:wrap; gap:40px; font-family:var(--fb); }
.gradring { padding:2px;border-radius:50%%;background:linear-gradient(135deg,var(--navy),var(--blue)); }
.glowcta { box-shadow: var(--elev-cta), 0 0 12px rgba(227,139,41,.2); }
.stepnode { width:32px;height:32px;border-radius:50%%;background:var(--brand);color:var(--on-brand);display:grid;place-items:center;font:700 14px var(--fb);flex:none; }
.stitch { border-left:2px dashed var(--track);margin-left:15px;padding-left:22px; }
.checkburst { background:radial-gradient(circle,rgba(58,125,92,.12) 0%%,transparent 70%%); }
</style></head><body>
%%%%SPRITE%%%%
<div class="pg">
'''
dk=[];od=[]
for fr in lights:
    c,_=variant(fr,'-dark','dark'); dk.append(str(c))
    base = fr['data-frame'][:-6]
    if any(base==o or base.startswith(o+'-') and o in ('S01','S02','S03','S04','H10','H11','T19') and False for o in OUTDOOR) or base in OUTDOOR:
        c,_=variant(fr,'-outdoor','outdoor'); od.append(str(c))
open(f'{H}/frames-dark.html','w').write(head%('dark','#0B0E11')+'\n'.join(dk)+'\n</div></body></html>')
open(f'{H}/frames-outdoor.html','w').write(head%('outdoor','#DCD8CF')+'\n'.join(od)+'\n</div></body></html>')
print(len(dk),'dark',len(od),'outdoor')
