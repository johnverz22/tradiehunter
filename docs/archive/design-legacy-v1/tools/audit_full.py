#!/usr/bin/env python3
"""Comprehensive design-system audit for TradieHunter HTML mockups.

Runs Playwright-based runtime probes (overflow, truncation, contrast, tap
targets, small text, orange count, a11y) plus static probes (broken sprite
refs, missing assets, unresolved placeholders, hardcoded inline colors,
undefined CSS classes/vars).

Usage: python3 audit_full.py <design_root> <out_json>
  <design_root> = directory containing html/*.html
"""
import sys, json, glob, os, re
from urllib.parse import unquote
from playwright.sync_api import sync_playwright

# ---------------- static checks ----------------
def static_checks(root):
    out = []
    html_files = sorted(glob.glob(os.path.join(root, 'html', '*.html')))
    kit = os.path.join(root, 'html', 'kit.css')
    css = open(kit, encoding='utf-8').read() if os.path.exists(kit) else ''
    defined_classes = set(re.findall(r'\.([a-zA-Z][\w-]*)', css))
    defined_vars = set(re.findall(r'--([\w-]+)\s*:', css))
    for f in html_files:
        src = open(f, encoding='utf-8').read()
        name = os.path.basename(f)
        # 1. unresolved build placeholders
        for m in re.finditer(r'%%(\w+)%%', src):
            out.append(dict(file=name, check='placeholder', detail=f'unresolved %%{m.group(1)}%% in source html'))
        # 2. img/link refs to missing files
        for m in re.finditer(r'(?:src|href)="([^"#][^"]*)"', src):
            ref = m.group(1)
            if ref.startswith(('http', 'data:', 'javascript')):
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(f), unquote(ref)))
            if not os.path.exists(target):
                out.append(dict(file=name, check='missing_asset', detail=ref))
        # 3. sprite use refs
        used_ids = set(re.findall(r'<use[^>]+href="#([\w-]+)"', src)) | set(re.findall(r'<use[^>]+xlink:href="#([\w-]+)"', src))
        defined_ids = set(re.findall(r'id="([\w-]+)"', src))
        for uid in sorted(used_ids - defined_ids):
            out.append(dict(file=name, check='missing_sprite_id', detail=f'use #{uid} has no target'))
        # 4. classes used but not defined anywhere in file or kit
        local_styles = ''.join(re.findall(r'<style[^>]*>(.*?)</style>', src, re.S))
        local = set(re.findall(r'\.([\w-]+)', local_styles))
        seen = set()
        for m in re.finditer(r'class="([^"]+)"', src):
            for cls in m.group(1).split():
                if cls in seen: continue
                seen.add(cls)
                if cls not in defined_classes and cls not in local and not re.match(r'^(w\d+|h\d+|c\d+|fs\d+|op\d+|on-dark|on-amber|light|dark|outdoor)$', cls):
                    out.append(dict(file=name, check='undefined_class', detail=cls))
        # 5. var(--x) custom props not defined
        for m in set(re.findall(r'var\(--([\w-]+)', src)):
            if m not in defined_vars and m not in local:
                out.append(dict(file=name, check='undefined_var', detail=f'--{m}'))
    return out

# ---------------- runtime probe ----------------
JS = r"""
() => {
  const parse = c => { const m = c.match(/rgba?\(([^)]+)\)/); if(!m) return [0,0,0,0]; const p=m[1].split(',').map(x=>parseFloat(x)); return [p[0],p[1],p[2],p.length>3?p[3]:1]; };
  const lin = v => { v/=255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); };
  const L = c => 0.2126*lin(c[0])+0.7152*lin(c[1])+0.0722*lin(c[2]);
  const cr = (a,b) => { const x=L(a),y=L(b); return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05); };
  const over = (f,b) => { const a=f[3]; return [f[0]*a+b[0]*(1-a), f[1]*a+b[1]*(1-a), f[2]*a+b[2]*(1-a), 1]; };
  const bgOf = el => {
    const stack=[]; let e=el, hasImg=false;
    while(e){ const cs=getComputedStyle(e); const c=parse(cs.backgroundColor); if(c[3]>0) stack.push(c); if(cs.backgroundImage && cs.backgroundImage!=='none') hasImg=true; if(e.hasAttribute('data-frame')) break; e=e.parentElement; }
    let base=[255,255,255,1]; for(let i=stack.length-1;i>=0;i--) base=over(stack[i],base); return {c:base,img:hasImg};
  };
  const sel = e => { let s=e.tagName.toLowerCase(); if(e.className&&typeof e.className==='string') s+='.'+e.className.trim().split(/\s+/).slice(0,3).join('.'); return s; };
  const res=[];
  document.querySelectorAll('[data-frame]').forEach(fr=>{
    const name=fr.getAttribute('data-frame'); const fb=fr.getBoundingClientRect();
    const r={name, clip:[], trunc:[], tap:[], small:[], contrast:[], a11y:[], orange:0, orangeEls:[], inlineColor:[], fixedH:[]};
    fr.querySelectorAll('*').forEach(el=>{
      const b=el.getBoundingClientRect(); if(b.width<1||b.height<1) return;
      const cs=getComputedStyle(el); if(cs.display==='none'||cs.visibility==='hidden') return;
      if(el.closest('svg') && el.tagName!=='svg') return;
      const hasText=[...el.childNodes].some(n=>n.nodeType===3&&n.textContent.trim().length>0);
      const decorative = !!el.closest('.blob,.rings,.grid,.route,.bpdots,.noise');
      const inFadeRow = !!el.closest('.faderow');   // intentional scroller: last chip visibly cut (spec F-05)
      // clip vs frame
      if((b.right>fb.right+1||b.left<fb.left-1) && !decorative && !inFadeRow && cs.position!=='absolute'){
        r.clip.push(sel(el)+(hasText?' "'+el.textContent.trim().slice(0,24)+'"':''));
      }
      // truncation
      if(hasText && (el.scrollWidth>el.clientWidth+1) && cs.overflow!=='visible' && !el.closest('.faderow')){
        r.trunc.push(sel(el)+' "'+el.textContent.trim().slice(0,24)+'"');
      }
      // tap targets (48dp); .o alone is the wordmark accent span (NOT interactive — probe collision),
      // segmented options are .seg48 .o and are 48dp by construction
      if(el.matches('.btn,.chip,.ibtn,.tab,.back,.opt,.cell,.ico-btn,.nav a,.navitem,.linkrow,.seg48 .o')){
        const isChip = el.matches('.chip'); // chips pad to 48 via ::after
        if((b.height<47.5 && !isChip) || (el.matches('.btn,.ibtn,.back,.ico-btn')&&b.width<47.5)) {
          r.tap.push(sel(el)+' '+Math.round(b.width)+'x'+Math.round(b.height)+(hasText?' "'+el.textContent.trim().slice(0,16)+'"':''));
        }
      }
      // small text
      if(hasText){ const fs=parseFloat(cs.fontSize); if(fs<12) r.small.push(sel(el)+' '+fs+'px "'+el.textContent.trim().slice(0,16)+'"');
        const fg=parse(cs.color); const bg=bgOf(el); const fgc=over(fg,bg.c); const ratio=cr(fgc,bg.c);
        const large = fs>=24 || (fs>=18.66 && parseInt(cs.fontWeight)>=700);
        if(ratio < (large?3:4.5) && !bg.img) r.contrast.push({el:sel(el), t:el.textContent.trim().slice(0,22), ratio:Math.round(ratio*100)/100, fs});
      }
      // a11y: icon-only interactive without name
      if(el.matches('.ibtn,.back,.ico-btn') && !el.getAttribute('aria-label') && !el.textContent.trim()){
        r.a11y.push(sel(el)+' icon-only interactive, no aria-label');
      }
      // images without alt
      if(el.tagName==='IMG' && !el.hasAttribute('alt')) r.a11y.push(sel(el)+' img without alt');
      // orange count — a .countdown urgency widget (text + fill) counts as ONE element (spec gate 4)
      const isOr = c => { const p=parse(c); return p[3]>0.5 && Math.abs(p[0]-227)<14&&Math.abs(p[1]-139)<14&&Math.abs(p[2]-41)<20; };
      let o = isOr(cs.backgroundColor)||isOr(cs.color);
      if(el.matches('.btn-primary')) o=true;
      if(/227, ?139, ?41/.test(cs.backgroundImage)&&!el.matches('.btn-primary')) o=true;
      if(o && !el.closest('svg')){
        const cd = el.closest('.countdown');
        if (cd) { r._cdSeen = r._cdSeen || new Set(); if (!r._cdSeen.has(cd)) { r._cdSeen.add(cd); r.orange++; r.orangeEls.push('countdown(urgent)'); } }
        else { r.orange++; r.orangeEls.push(sel(el)); }
      }
      // inline hardcoded colors
      if(el.hasAttribute('style')){
        const st=el.getAttribute('style');
        const hexm = st.match(/#[0-9a-fA-F]{3,8}\b/g);
        if(hexm) r.inlineColor.push(sel(el)+' '+hexm.join(','));
        else {
          const rg = st.match(/\brgba?\([^)]*\)/);
          if(rg && rg[0] && !rg[0].includes('var(')) r.inlineColor.push(sel(el)+' '+rg[0]);
        }
      }
      // fixed height on text-bearing containers (text-scale overflow risk)
      if(hasText && /^\\d+px$/.test(cs.height) && parseInt(cs.height)>0 && el.children.length<=3){
        const exempt = el.matches('.badge,.pill,.chip,.stepnode,.avatar,.dot,.sep,.tab,.frame,.appbar,.statusbar,.input,.btn,.ico-btn,.ibtn,.cell,.tileimg,.art,.bar,.kpi,.mono,.nav,.appbtn,.logo,.seg,.otp,.fab,.cpb,.back,.rail,.footnote-num');
        if(!exempt) r.fixedH.push(sel(el)+' height:'+cs.height);
      }
    });
    res.push(r);
  });
  return res;
}
"""

def main():
    root, out = sys.argv[1], sys.argv[2]
    rows = []
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(device_scale_factor=1, viewport={'width': 1400, 'height': 1000})
        for f in sorted(glob.glob(os.path.join(root, 'html', '*.html'))):
            pg.goto('file://' + os.path.abspath(f))
            pg.wait_for_timeout(250)
            pg.evaluate("document.fonts.ready")
            for r in pg.evaluate(JS):
                r['file'] = os.path.basename(f)
                rows.append(r)
        b.close()
    static = static_checks(root)
    json.dump({'frames': rows, 'static': static}, open(out, 'w'), indent=1)
    n_clip = sum(len(r['clip']) for r in rows)
    n_trunc = sum(len(r['trunc']) for r in rows)
    n_tap = sum(len(r['tap']) for r in rows)
    n_small = sum(len(r['small']) for r in rows)
    n_con = sum(len(r['contrast']) for r in rows)
    n_a11y = sum(len(r['a11y']) for r in rows)
    n_orange = sum(1 for r in rows if r['orange'] > 2)
    n_inline = sum(len(r['inlineColor']) for r in rows)
    n_fixedh = sum(len(r['fixedH']) for r in rows)
    print(f'frames={len(rows)} clip={n_clip} trunc={n_trunc} tap={n_tap} small={n_small} contrast={n_con} a11y={n_a11y} orange>2={n_orange} inlineColors={n_inline} fixedH={n_fixedh} static={len(static)}')

if __name__ == '__main__':
    main()
