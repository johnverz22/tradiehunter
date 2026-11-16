# html/*.html -> build/*.html. Sources are now self-contained (sprite inlined by tools/inline_sprite.py), so this is a copy step.
import sys, os, glob, shutil
root = sys.argv[1]
os.makedirs(f'{root}/build', exist_ok=True)
shutil.copy(f'{root}/html/kit.css', f'{root}/build/kit.css')
for f in glob.glob(f'{root}/html/*.html'):
    shutil.copy(f, f'{root}/build/{os.path.basename(f)}')
