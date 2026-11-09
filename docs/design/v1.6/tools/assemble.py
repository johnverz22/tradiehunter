# assemble html/*.html -> build/*.html (inline icon sprite at %%SPRITE%%, copy kit.css)
import sys, os, glob, shutil
root = sys.argv[1]
sprite = open(f'{root}/html/sprite.html').read()
os.makedirs(f'{root}/build', exist_ok=True)
shutil.copy(f'{root}/html/kit.css', f'{root}/build/kit.css')
for f in glob.glob(f'{root}/html/*.html'):
    b = os.path.basename(f)
    s = open(f).read()
    if b != 'sprite.html': s = s.replace('%%SPRITE%%', sprite)
    open(f'{root}/build/{b}', 'w').write(s)
