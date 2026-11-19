#!/usr/bin/env python3
"""v2 brand poster in the style of the v1 Play feature graphic: glowing lotus
(from the app icon) over an aurora sky, gold serif title, feature checklist.
Usage: poster.py icon.png out_dir"""
import sys, pathlib, subprocess

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

TEXT = {
    "en": dict(title="EKADASHI<br>CALENDAR", tag="Every Ekadashi of 2027, for your city",
               items=["Fasting &amp; Parana times", "Full Panchang &amp; festivals", "Vrat Journey &amp; badges",
                      "Widgets &amp; reminders", "6 Indian languages"],
               tfont="'Cinzel', 'Trajan Pro', serif", bfont="'Inter', -apple-system, sans-serif"),
    "hi": dict(title="एकादशी<br>कैलेंडर", tag="आपके शहर के लिए 2027 की हर एकादशी",
               items=["व्रत और पारण का सही समय", "पूरा पंचांग और त्योहार", "व्रत यात्रा और बैज",
                      "विजेट और रिमाइंडर", "6 भारतीय भाषाएँ"],
               tfont="'Tiro Devanagari Hindi', 'Noto Serif Devanagari', serif",
               bfont="'Noto Sans Devanagari', -apple-system, sans-serif"),
}

def page(w, h, icon_uri, t):
    s = h / 500  # design units are for 1024x500
    lw = 470 * s  # lotus box
    return f"""<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@700&family=Inter:wght@500&family=Tiro+Devanagari+Hindi&family=Noto+Sans+Devanagari:wght@500&display=block" rel="stylesheet">
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{w}px;height:{h}px;overflow:hidden}}
body{{position:relative;background:
 radial-gradient({380*s}px {300*s}px at 22% 10%, rgba(40,170,90,.45), transparent 70%),
 radial-gradient({420*s}px {260*s}px at 62% 0%, rgba(30,140,120,.35), transparent 70%),
 radial-gradient({520*s}px {360*s}px at 100% 100%, rgba(120,40,140,.55), transparent 70%),
 radial-gradient({500*s}px {400*s}px at 0% 100%, rgba(20,60,110,.6), transparent 70%),
 linear-gradient(160deg,#08222a 0%,#0c2c3a 40%,#1a1f3d 75%,#2a1840 100%)}}
.halo{{position:absolute;left:{(w*0.27)-lw*0.55}px;top:{h/2-lw*0.55}px;width:{lw*1.1}px;height:{lw*1.1}px;border-radius:50%;
 background:radial-gradient(circle,rgba(255,236,190,.5) 0%,rgba(255,206,120,.22) 42%,rgba(255,206,120,0) 68%)}}
.lotus{{position:absolute;left:{(w*0.27)-lw/2}px;top:{h/2-lw/2}px;width:{lw}px;height:{lw}px;
 
 filter:saturate(1.1) brightness(1.04)}}
.txt{{position:absolute;left:{w*0.53}px;right:{30*s}px;top:50%;transform:translateY(-50%);color:#fff}}
h1{{font-family:{t['tfont']};font-weight:700;font-size:{46*s}px;line-height:1.08;letter-spacing:{1*s}px;
 background:linear-gradient(180deg,#ffe6a6,#e8b24a 60%,#c98b2c);-webkit-background-clip:text;color:transparent;
 filter:drop-shadow(0 {2*s}px {6*s}px rgba(0,0,0,.45))}}
.tag{{font-family:{t['bfont']};font-size:{19*s}px;color:#f3d38a;margin-top:{6*s}px}}
ul{{list-style:none;margin-top:{20*s}px}}
li{{font-family:{t['bfont']};font-size:{19.5*s}px;line-height:1.75;display:flex;align-items:center;gap:{12*s}px;color:#f4f1ea}}
li i{{display:inline-flex;align-items:center;justify-content:center;width:{20*s}px;height:{20*s}px;border-radius:50%;
 background:linear-gradient(180deg,#f6cf6a,#cf9531);color:#3a2604;font-style:normal;font-size:{13*s}px;font-weight:700}}
</style></head><body>
<div class="halo"></div><img class="lotus" src="{icon_uri}">
<div class="txt"><h1>{t['title']}</h1><div class="tag">{t['tag']}</div>
<ul>{''.join(f'<li><i>✓</i>{x}</li>' for x in t['items'])}</ul></div>
</body></html>"""

def render(path, w, h, html):
    hp = path.with_suffix(".html"); hp.write_text(html, encoding="utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={path.parent}/.chrome",
                    "--virtual-time-budget=6000", f"--window-size={w},{h}", f"--screenshot={path}", hp.as_uri()],
                   check=True, capture_output=True)
    hp.unlink(); print("wrote", path.name)

if __name__ == "__main__":
    icon = pathlib.Path(sys.argv[1]).resolve().as_uri(); out = pathlib.Path(sys.argv[2]).resolve(); out.mkdir(parents=True, exist_ok=True)
    for lang, t in TEXT.items():
        render(out / f"feature-graphic-1024x500-{lang}.png", 1024, 500, page(1024, 500, icon, t))
        render(out / f"banner-1920x1080-{lang}.png", 1920, 1080, page(1920, 1080, icon, t))
