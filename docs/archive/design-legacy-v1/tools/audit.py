import sys, json, glob, os
from playwright.sync_api import sync_playwright
root = sys.argv[1]; out = sys.argv[2]
JS = r"""
() => {
  const parse = c => { const m = c.match(/rgba?\(([^)]+)\)/); if(!m) return [0,0,0,0]; const p=m[1].split(',').map(x=>parseFloat(x)); return [p[0],p[1],p[2],p.length>3?p[3]:1]; };
  const lin = v => { v/=255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); };
  const L = c => 0.2126*lin(c[0])+0.7152*lin(c[1])+0.0722*lin(c[2]);
  const cr = (a,b) => { const x=L(a),y=L(b); return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05); };
  const over = (f,b) => { const a=f[3]; return [f[0]*a+b[0]*(1-a), f[1]*a+b[1]*(1-a), f[2]*a+b[2]*(1-a), 1]; };
  const bgOf = el => { // composite stack of bgs up to frame
    const stack=[]; let e=el;
    while(e){ const cs=getComputedStyle(e); const c=parse(cs.backgroundColor); if(c[3]>0) stack.push(c); if(cs.backgroundImage && cs.backgroundImage!=='none'){ stack.hasImg=true; } if(e.hasAttribute('data-frame')) break; e=e.parentElement; }
    let base=[255,255,255,1]; for(let i=stack.length-1;i>=0;i--) base=over(stack[i],base); return {c:base,img:!!stack.hasImg};
  };
  const sel = e => { let s=e.tagName.toLowerCase(); if(e.className&&typeof e.className==='string') s+='.'+e.className.trim().split(/\s+/).slice(0,3).join('.'); return s; };
  const res=[];
  document.querySelectorAll('[data-frame]').forEach(fr=>{
    const name=fr.getAttribute('data-frame'); const fb=fr.getBoundingClientRect();
    const r={name, clip:[], trunc:[], tap:[], small:[], contrast:[], orange:0, orangeEls:[]};
    fr.querySelectorAll('*').forEach(el=>{
      const b=el.getBoundingClientRect(); if(b.width<1||b.height<1) return;
      const cs=getComputedStyle(el); if(cs.display==='none'||cs.visibility==='hidden') return;
      if(el.closest('svg') && el.tagName!=='svg') return;
      const hasText=[...el.childNodes].some(n=>n.nodeType===3&&n.textContent.trim().length>0);
      // clip vs frame
      if((b.right>fb.right+1||b.left<fb.left-1) && !el.closest('.blob,.heroband .rings,.rings,.grid,.route,[class*=bg]') && cs.position!=='absolute'){
        r.clip.push(sel(el)+(hasText?' "'+el.textContent.trim().slice(0,20)+'"':''));
      }
      // truncation
      if(hasText && (el.scrollWidth>el.clientWidth+1) && cs.overflow!=='visible'){ r.trunc.push(sel(el)+' "'+el.textContent.trim().slice(0,24)+'"'); }
      // tap targets
      if(el.matches('.btn,.chip,.ibtn,.tab,.input,.ico-btn,.back,.o,.opt,.cell')){
        const inRail=el.closest('.rail'); 
        if(b.height<47.5 || (el.matches('.btn,.ibtn,.ico-btn,.back')&&b.width<47.5)) r.tap.push(sel(el)+' '+Math.round(b.width)+'x'+Math.round(b.height)+(hasText?' "'+el.textContent.trim().slice(0,16)+'"':''));
      }
      // small text
      if(hasText){ const fs=parseFloat(cs.fontSize); if(fs<12) r.small.push(sel(el)+' '+fs+'px "'+el.textContent.trim().slice(0,16)+'"');
        // contrast
        const fg=parse(cs.color); const bg=bgOf(el); const fgc=over(fg,bg.c); const ratio=cr(fgc,bg.c);
        const large = fs>=24 || (fs>=18.66 && parseInt(cs.fontWeight)>=700);
        if(ratio < (large?3:4.5)) r.contrast.push({el:sel(el), t:el.textContent.trim().slice(0,22), ratio:Math.round(ratio*100)/100, fs, img:bg.img});
      }
      // orange
      const isOr = c => { const p=parse(c); return p[3]>0.5 && Math.abs(p[0]-227)<14&&Math.abs(p[1]-139)<14&&Math.abs(p[2]-41)<20; };
      const isOr2 = c => { const p=parse(c); return p[3]>0.5 && Math.abs(p[0]-235)<8&&Math.abs(p[1]-154)<8&&Math.abs(p[2]-63)<10; };
      let o = isOr(cs.backgroundColor)||isOr(cs.color)||isOr(cs.borderLeftColor)&&parseFloat(cs.borderLeftWidth)>0||/227, 139, 41|235, 154, 63/.test(cs.backgroundImage)&&!el.matches('.btn-primary');
      if(el.matches('.btn-primary')) o=true;
      if(o && !el.closest('svg')){ r.orange++; r.orangeEls.push(sel(el)); }
    });
    res.push(r);
  });
  return res;
}
"""
rows=[]
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(device_scale_factor=1)
    for f in sorted(glob.glob(f'{root}/build/frames-*.html')+glob.glob(f'{root}/build/component-sheet.html')):
        pg.goto('file://'+os.path.abspath(f)); pg.wait_for_timeout(300); pg.evaluate("document.fonts.ready")
        for r in pg.evaluate(JS): r['file']=os.path.basename(f); rows.append(r)
    b.close()
json.dump(rows,open(out,'w'),indent=1)
print(len(rows),'frames audited')
