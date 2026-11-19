import sys, glob
from PIL import Image, ImageDraw
out, files = sys.argv[1], sys.argv[2:]
ims = [Image.open(f).convert("RGB") for f in files]
w = 520; h = int(ims[0].height * w / ims[0].width)
cols = min(6, len(ims)); rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * (h + 34)), "white")
d = ImageDraw.Draw(sheet)
for i, (f, im) in enumerate(zip(files, ims)):
    x, y = (i % cols) * w, (i // cols) * (h + 34)
    sheet.paste(im.resize((w, h)), (x, y + 34)); d.text((x + 8, y + 8), f.split("/")[-1], fill="black")
sheet.save(out)
