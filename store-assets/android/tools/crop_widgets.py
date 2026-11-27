#!/usr/bin/env python3
"""Cut each widget out of its Settings > Widget Preview capture (1344 x 2992).
Usage: crop_widgets.py raw/widgets out_dir"""
import sys, pathlib
import numpy as np
from PIL import Image
src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
names = {"w-ekadashi-small": "ekadashi-small", "w-ekadashi-medium": "ekadashi-medium",
         "w-upcoming-medium": "upcoming-medium", "w-upcoming-large": "upcoming-large"}
for f, n in names.items():
    im = Image.open(src / f"{f}.png").convert("RGBA"); a = np.asarray(im).astype(int)
    band = a[950:2500, :, :3]
    bg = np.median(band[:, :40].reshape(-1, 3), axis=0)
    # Widget cards are dark teal: more green/blue than the neutral page background.
    teal = (band[:, :, 1] - band[:, :, 0] > 12) & (np.abs(band - bg).sum(2) > 18)
    rows, cols = np.where(teal)
    y0, y1 = rows.min() + 950, rows.max() + 950; x0, x1 = cols.min(), cols.max()
    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    # Round the corners to match the launcher's widget radius.
    r = int(0.075 * crop.width) if "small" not in n else int(0.12 * crop.width)
    m = Image.new("L", crop.size, 0)
    from PIL import ImageDraw
    ImageDraw.Draw(m).rounded_rectangle((0, 0, crop.width - 1, crop.height - 1), r, fill=255)
    crop.putalpha(m); crop.save(out / f"{n}.png")
    print(n, (x0, y0, x1, y1), crop.size)
