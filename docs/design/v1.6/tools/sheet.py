import sys
from PIL import Image, ImageDraw
def sheet(root, names, out, scale=0.5, cols=6):
    ims=[Image.open(f'{root}/frames/{n}.png').convert('RGB') for n in names]
    ims=[i.resize((int(i.width*scale),int(i.height*scale))) for i in ims]
    w=max(i.width for i in ims); h=max(i.height for i in ims); rows=(len(ims)+cols-1)//cols
    S=Image.new('RGB',(cols*(w+8),rows*(h+20)),'#888'); d=ImageDraw.Draw(S)
    for k,(n,i) in enumerate(zip(names,ims)):
        x=(k%cols)*(w+8); y=(k//cols)*(h+20); S.paste(i,(x,y+16)); d.text((x+2,y+2),n,fill='white')
    S.save(out)
