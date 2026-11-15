import sys, glob, os, json
from playwright.sync_api import sync_playwright
JS = r"""
() => {
 const out=[];
 document.querySelectorAll('[data-frame]').forEach(fr=>{
  const name=fr.getAttribute('data-frame'), fb=fr.getBoundingClientRect();
  const r={name,missingIcon:[],backBtn:[],pillOverflow:[],clip:[],tap:[]};
  const sel=e=>{let s=e.tagName.toLowerCase(); if(typeof e.className==='string'&&e.className.trim()) s+='.'+e.className.trim().split(/\s+/).slice(0,3).join('.'); return s};
  fr.querySelectorAll('svg').forEach(s=>{
    const u=s.querySelector('use'); const b=s.getBoundingClientRect(); if(b.width<1) return;
    let empty=false, why='';
    if(u){ const h=(u.getAttribute('href')||u.getAttribute('xlink:href')||'').replace('#',''); const t=h&&document.getElementById(h); if(!t){empty=true;why='unresolved #'+h;} }
    else if(!s.children.length){empty=true;why='empty svg'}
    if(empty) r.missingIcon.push(sel(s.parentElement)+' '+why+' @'+Math.round(b.width)+'x'+Math.round(b.height));
  });
  fr.querySelectorAll('.appbar .back, .appbar [aria-label*=ack i]').forEach(e=>{const b=e.getBoundingClientRect();
    const svg=e.querySelector('svg'); const sb=svg?svg.getBoundingClientRect():null;
    const u=e.querySelector('use'); const resolved=u?!!document.getElementById((u.getAttribute('href')||'').replace('#','')):!!svg&&svg.children.length>0;
    r.backBtn.push({size:Math.round(b.width)+'x'+Math.round(b.height),hasIcon:!!svg,resolved,left:Math.round(b.left-fb.left)});});
  fr.querySelectorAll('.pill,.chip,.badge,.tag').forEach(e=>{ if(e.closest('.faderow')) return;
    const b=e.getBoundingClientRect(); if(b.width<1) return; const cs=getComputedStyle(e);
    const over = e.scrollWidth>e.clientWidth+1;
    const parent=e.parentElement.getBoundingClientRect();
    const out = b.right>fb.right-1 || b.left<fb.left-1;
    const outParent = b.right>parent.right+1 && !/scroll|auto/.test(getComputedStyle(e.parentElement).overflowX);
    const wrap = b.height>34 && e.matches('.pill');
    if(over||out||outParent||wrap) r.pillOverflow.push(sel(e)+' "'+e.textContent.trim().slice(0,28)+'" '+Math.round(b.width)+'x'+Math.round(b.height)+(over?' scrollW>clientW':'')+(out?' beyondFrame':'')+(outParent?' beyondParent':'')+(wrap?' wraps':''));
  });
  fr.querySelectorAll('*').forEach(e=>{ if(e.closest('svg')) return; const b=e.getBoundingClientRect(); if(b.width<1||b.height<1) return; const cs=getComputedStyle(e);
    if(cs.position==='absolute') return;
    if((b.right>fb.right+1||b.left<fb.left-1)&&!e.closest('.blob,.rings,.faderow')) r.clip.push(sel(e)+' '+e.textContent.trim().slice(0,20)); });
  out.push(r);
 });
 return out;
}
"""
mode=sys.argv[1]; files=sys.argv[2:]
res={}
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(device_scale_factor=1)
    for f in files:
        pg.goto('file://'+os.path.abspath(f)); pg.wait_for_timeout(400)
        res[os.path.basename(f)]=pg.evaluate(JS)
json.dump(res,open(f'probe-{mode}.json','w'),indent=1)
for f,fr in res.items():
    print(f, len(fr),'frames | missing-icon frames',sum(1 for x in fr if x['missingIcon']),'| pill-overflow frames',sum(1 for x in fr if x['pillOverflow']),'| clip frames',sum(1 for x in fr if x['clip']), '| back w/o icon',sum(1 for x in fr for bb in x['backBtn'] if not bb['resolved']))
