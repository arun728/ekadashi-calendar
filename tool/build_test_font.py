#!/usr/bin/env python3
"""Optional regeneration: pip install fonttools; generated TTF is checked in.
Combine licensed test-only Latin/Tamil/Devanagari fonts into one family.
"""
from pathlib import Path
from tempfile import TemporaryDirectory
from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
root = Path(__file__).resolve().parent.parent / 'test/fonts'
with TemporaryDirectory() as temporary:
    inputs = []
    for name in ('Roboto-Regular.ttf', 'NotoSansTamil.ttf', 'NotoSansDevanagari.ttf', 'NotoSansTelugu.ttf'):
        font = TTFont(root / name)
        scale_upem(font, 1000)
        target = Path(temporary) / name
        font.save(target)
        inputs.append(str(target))
    font = Merger().merge(inputs)
    for record in font['name'].names:
        if record.nameID in (1, 3, 4, 6, 16):
            record.string = 'EkadashiTestFont'.encode(record.getEncoding())
    font.save(root / 'EkadashiTestFont.ttf')
