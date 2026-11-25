#!/usr/bin/env python3
"""Phase 6.2 helper: static import graph of mobile/lib (no Flutter needed).

Run from anywhere:  python3 scripts/v1-cutover-inventory.py
Prints (1) files unreachable from lib/main.dart, (2) the non-v1 files that
still import lib/views/**. v1 can only be deleted once (2) is empty, i.e.
after 6.1 removes the _pick(...) conditionals in app_router.dart. Parses
import/export/part lines only; it does not see conditional imports of
generated code or test usage (grep test/ and integration_test/ separately).
"""
import os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'mobile'))
import re,os,sys,collections
root='.'
pkg=re.search(r'^name:\s*(\S+)',open('pubspec.yaml').read(),re.M).group(1)
files=[os.path.join(d,f) for d,_,fs in os.walk('lib') for f in fs if f.endswith('.dart')]
fs=set(files)
def res(src,imp):
    m=re.match(r'package:%s/(.*)'%pkg,imp)
    if m: p='lib/'+m.group(1)
    elif imp.startswith('package:') or imp.startswith('dart:'): return None
    else: p=os.path.normpath(os.path.join(os.path.dirname(src),imp))
    return p if p in fs else None
rx=re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""",re.M)
out=collections.defaultdict(set); inn=collections.defaultdict(set)
for f in files:
    for i in rx.findall(open(f).read()):
        t=res(f,i)
        if t: out[f].add(t); inn[t].add(f)
# reachability from lib/main.dart
seen=set(); st=['lib/main.dart']
while st:
    n=st.pop()
    if n in seen: continue
    seen.add(n); st+=list(out[n])
dead=[f for f in files if f not in seen]
print('total',len(files),'reachable',len(seen),'unreachable',len(dead))
for f in sorted(dead): print('DEAD',f)
v1=[f for f in files if f.startswith('lib/views/')]
ext=collections.Counter()
for f in v1:
    for s in inn[f]:
        if not s.startswith('lib/views/') and s in seen: ext[s]+=1
print('v1 files',len(v1),'; non-v1 reachable importers:')
for s,c in ext.most_common(): print(c,s)
