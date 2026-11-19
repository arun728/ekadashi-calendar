import sys
from PIL import Image, ImageDraw
out=sys.argv[1]; files=sys.argv[2:]
tiles=[]
for f in files:
    im=Image.open(f).convert("RGB"); d=ImageDraw.Draw(im)
    for x in range(0,im.width,100):
        d.line([(x,0),(x,im.height)],fill=(255,0,0) if x%500==0 else (255,80,80),width=3 if x%500==0 else 1)
        d.text((x+4,4),str(x),fill=(255,255,0))
    for y in range(0,im.height,100):
        d.line([(0,y),(im.width,y)],fill=(255,0,0) if y%500==0 else (255,80,80),width=3 if y%500==0 else 1)
        d.text((4,y+4),str(y),fill=(255,255,0))
    tiles.append(im.resize((im.width//2,im.height//2)))
w=sum(t.width for t in tiles); h=tiles[0].height
sheet=Image.new("RGB",(w,h)); x=0
for t in tiles: sheet.paste(t,(x,0)); x+=t.width
sheet.save(out)
