#!/usr/bin/env python3
"""App Store frames, 1320x2868, dark, one continuous aurora across the set.
Usage: compose2.py spec.json raw_dir out_dir [names...]"""
import json, sys, subprocess, pathlib, math

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1320, 2868
RAW_W, RAW_H = 1320, 2868

HUES = {  # glow colours per accent
    "teal":   ("#12b5ae", "#0a6e6a"),
    "gold":   ("#f3b23d", "#b9671a"),
    "lotus":  ("#e86aa6", "#7d3aa8"),
    "indigo": ("#6f7cf5", "#2b3aa0"),
}

def petal_ring(cx, cy, r, n, color, op):
    out = []
    for i in range(n):
        a = 360 / n * i
        out.append(f'<ellipse cx="{cx}" cy="{cy - r}" rx="{r*0.16:.0f}" ry="{r*0.42:.0f}" '
                   f'transform="rotate({a:.1f} {cx} {cy})" fill="none" stroke="{color}" stroke-opacity="{op}" stroke-width="3"/>')
    return "".join(out)

def background(i, n, hue):
    """Each slide is a 1320-wide window into a shared panorama."""
    a, b = HUES[hue]
    off = -i * W
    pw = n * W
    # Flowing ribbons across the whole panorama (continuous between slides).
    ribbons = []
    for k, (amp, y0, col, op, wdt) in enumerate([(260, 1500, "#12b5ae", .22, 220), (200, 1900, "#f3b23d", .12, 160), (320, 1150, "#6f7cf5", .10, 260)]):
        pts = []
        for x in range(0, pw + 1, 60):
            y = y0 + amp * math.sin(x / 900 + k * 1.7) + 90 * math.sin(x / 310 + k)
            pts.append(f"{x},{y:.0f}")
        ribbons.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{col}" stroke-opacity="{op}" '
                       f'stroke-width="{wdt}" stroke-linecap="round" filter="url(#blur)"/>')
    stars = "".join(f'<circle cx="{(j*137)%pw}" cy="{(j*251)%1100+40}" r="{1.5+(j%3)}" fill="#fff" fill-opacity="{0.08+(j%5)*0.05:.2f}"/>'
                    for j in range(60 * n))
    return f'''<svg class="pano" width="{pw}" height="{H}" style="left:{off}px" xmlns="http://www.w3.org/2000/svg">
<defs><filter id="blur" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="90"/></filter></defs>
<rect width="{pw}" height="{H}" fill="#040706"/>{"".join(ribbons)}{stars}</svg>
<div class="glow" style="background:radial-gradient(900px 760px at 50% 6%, {a}66 0%, {b}22 45%, transparent 70%)"></div>
<svg class="mandala" width="1400" height="1400" viewBox="0 0 1400 1400">{petal_ring(700,700,520,24,a,.10)}{petal_ring(700,700,380,16,a,.08)}{petal_ring(700,700,250,12,a,.07)}</svg>'''

def phone_html(src, p, screen=None):
    w = p.get("w", 980)
    r = w / RAW_W
    rot = p.get("rotate", 0)
    if screen:
        h = int(w * RAW_H / RAW_W)
        return (f'<div class="phone" style="left:{p.get("x", (W - w)//2 - 24)}px;top:{p["y"]}px;width:{w + 48}px;'
                f'transform:rotate({rot}deg)"><div class="screen" style="width:{w}px;height:{h}px;border-radius:{int(150*r)}px">{screen}</div></div>')
    return (f'<div class="phone" style="left:{p.get("x", (W - w)//2 - 24)}px;top:{p["y"]}px;width:{w + 48}px;'
            f'transform:rotate({rot}deg)"><img src="{src}" style="width:{w}px;border-radius:{int(150*r)}px"></div>')

def callout_html(src, c):
    x0, y0, cw, ch = c["crop"]
    s = c["w"] / cw
    return (f'<div class="call" style="left:{c["x"]}px;top:{c["y"]}px;width:{c["w"]}px;height:{int(ch*s)}px;'
            f'transform:rotate({c.get("rotate",0)}deg);border-radius:{c.get("radius",44)}px">'
            f'<img src="{src}" style="width:{int(RAW_W*s)}px;left:{-int(x0*s)}px;top:{-int(y0*s)}px"></div>')

CSS = """*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1320px;height:2868px;overflow:hidden;background:#040706}
body{font-family:-apple-system,"SF Pro Display","Helvetica Neue",sans-serif;color:#fff;position:relative}
.pano{position:absolute;top:0}
.glow{position:absolute;inset:0}
.mandala{position:absolute;left:-40px;top:-420px;opacity:.9}
.top{position:absolute;left:0;right:0;top:170px;text-align:center;padding:0 80px;z-index:5}
.tag{display:inline-flex;align-items:center;gap:14px;font-size:38px;font-weight:700;letter-spacing:5px;text-transform:uppercase;
 padding:16px 34px;border-radius:999px;margin-bottom:46px}
.tag.free{background:rgba(255,255,255,.08);color:#bff3ef;border:2px solid rgba(191,243,239,.35)}
.tag.premium{background:linear-gradient(90deg,#ffd77a,#f29f3d);color:#2a1700}
h1{font-size:132px;line-height:1.02;font-weight:800;letter-spacing:-3.5px}
h1 em{font-style:normal;background:linear-gradient(90deg,var(--a),var(--b2));-webkit-background-clip:text;color:transparent}
p.sub{margin-top:38px;font-size:52px;line-height:1.28;color:rgba(255,255,255,.70);font-weight:500}
.phone{position:absolute;padding:24px;border-radius:170px;z-index:3;
 background:linear-gradient(150deg,#47524f 0%,#161c1b 30%,#0b0f0e 70%,#2a3331 100%);
 box-shadow:0 0 0 2px rgba(255,255,255,.12),0 80px 180px rgba(0,0,0,.75),0 0 160px var(--shadow)}
.phone img{display:block}
.screen{position:relative;overflow:hidden;background:radial-gradient(700px 600px at 30% 20%,#0f5a56 0%,transparent 70%),radial-gradient(700px 700px at 90% 70%,#3a2a6a 0%,transparent 70%),linear-gradient(180deg,#07211f,#060a12)}
.screen .sb{position:absolute;top:34px;left:70px;right:70px;display:flex;justify-content:space-between;font-size:38px;font-weight:600}
.screen .date{position:absolute;top:150px;width:100%;text-align:center;font-size:44px;font-weight:600;color:rgba(255,255,255,.85)}
.screen .clock{position:absolute;top:190px;width:100%;text-align:center;font-size:250px;font-weight:700;letter-spacing:-6px;color:rgba(255,255,255,.92)}
.screen .wg{position:absolute;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.45)}
.screen .wg img{display:block;width:100%}
.screen .lbl{position:absolute;left:0;right:0;text-align:center;font-size:30px;font-weight:700;letter-spacing:4px;text-transform:uppercase;color:rgba(255,255,255,.55)}
.call{position:absolute;overflow:hidden;z-index:6;
 box-shadow:0 0 0 3px rgba(255,255,255,.18),0 50px 120px rgba(0,0,0,.8),0 0 90px var(--shadow)}
.call img{position:absolute;display:block}
.chips{position:absolute;left:0;right:0;z-index:6;display:flex;flex-wrap:wrap;justify-content:center;gap:22px;padding:0 70px}
.chip{font-size:46px;font-weight:650;padding:20px 38px;border-radius:999px;background:rgba(10,20,19,.78);
 border:2px solid rgba(255,255,255,.16);backdrop-filter:blur(20px);box-shadow:0 20px 60px rgba(0,0,0,.5)}
"""

def screen_html(item, raw):
    if item.get("screen") != "widgets":
        return None
    u = lambda n: (raw.parent / "widgets" / (n + ".png")).resolve().as_uri()
    return (f'<img src="{u("statusbar")}" style="position:absolute;top:0;left:0;width:100%">'
            f'<div class="date">Friday, 1 January</div><div class="clock">9:41</div>'
            f'<div class="wg" style="left:150px;top:500px;width:680px;border-radius:60px;background:rgba(0,0,0,.25);backdrop-filter:blur(10px)"><img src="{u("w-lock")}" style="opacity:.95"></div>'
            f'<div class="lbl" style="top:700px">Lock Screen</div>'
            f'<div class="lbl" style="top:790px">Home Screen</div>'
            f'<div class="wg" style="left:50px;top:850px;width:880px;border-radius:70px"><img src="{u("w-medium-dark")}"></div>'
            f'<div class="wg" style="left:50px;top:1300px;width:420px;border-radius:70px"><img src="{u("w-small-dark")}"></div>'
            f'<div class="wg" style="left:510px;top:1300px;width:420px;border-radius:70px"><img src="{u("w-small-light")}"></div>'
            f'<div class="wg" style="left:50px;top:1760px;width:880px;border-radius:70px"><img src="{u("w-upcoming")}"></div>')

def render(i, n, item, raw, out):
    hue = item.get("hue", "teal")
    a, b = HUES[hue]
    src = (raw / item["src"]).resolve().as_uri()
    tag = ""
    if item.get("tag") == "free":
        tag = '<div><span class="tag free">Free</span></div>'
    elif item.get("tag") == "premium":
        tag = '<div><span class="tag premium">★ Premium</span></div>'
    sub = f'<p class="sub">{item["sub"]}</p>' if item.get("sub") else ""
    ph = item.get("phone", {"y": 900})
    pw = ph.get("w", 980); r = pw / RAW_W
    img_left = ph.get("x", (W - pw) // 2 - 24) + 24; img_top = ph["y"] + 24
    for c in item.get("callouts", []):
        if c.get("pop"):
            x0, y0, cw, ch = c["crop"]; k = c["pop"]
            c["w"] = int(cw * r * k)
            cx, cy = img_left + (x0 + cw / 2) * r, img_top + (y0 + ch / 2) * r
            c["x"] = int(cx - c["w"] / 2) + c.get("dx", 0); c["y"] = int(cy - ch * r * k / 2) + c.get("dy", 0)
    calls = "".join(callout_html((raw / c.get("src", item["src"])).resolve().as_uri(), c) for c in item.get("callouts", []))
    if item.get("pair"):
        # Two phones side by side, each with a label pill (e.g. Free vs Premium).
        prs = []
        for k, pr in enumerate(item["pair"]):
            pw2 = pr.get("w", 600); x = pr["x"]; y = pr["y"]
            prs.append(phone_html((raw / pr["src"]).resolve().as_uri(), {"x": x, "y": y, "w": pw2, "rotate": pr.get("rotate", 0)}))
            cls = "free" if pr["label"] == "Free" else "premium"
            txt = "Free" if cls == "free" else "★ Premium"
            prs.append(f'<div style="position:absolute;left:{x}px;width:{pw2+48}px;top:{y-110}px;text-align:center;z-index:7">'
                       f'<span class="tag {cls}" style="margin:0">{txt}</span></div>')
        calls += "".join(prs)
    chips = ""
    if item.get("chips"):
        chips = f'<div class="chips" style="top:{item["chips"]["y"]}px">' + "".join(
            f'<span class="chip">{t}</span>' for t in item["chips"]["items"]) + "</div>"
    page = (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head>'
            f'<body style="--a:{a};--b2:{"#ffffff" if hue!="gold" else "#ffe3a3"};--shadow:{a}40">'
            f'{background(i, n, hue)}<div class="top">{tag}<h1>{item["title"]}</h1>{sub}</div>'
            f'{"" if item.get("pair") else phone_html(src, item.get("phone", {"y": 900}), screen_html(item, raw))}{calls}{chips}</body></html>')
    hp = out / (item["out"] + ".html")
    hp.write_text(page, encoding="utf-8")
    png = out / (item["out"] + ".png")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--user-data-dir={out.parent/'chrome-prof'}", f"--window-size={W},{H}", "--virtual-time-budget=3000",
                    f"--screenshot={png}", hp.as_uri()], check=True, capture_output=True)
    hp.unlink()
    print("wrote", png.name)

if __name__ == "__main__":
    spec, raw, out = json.load(open(sys.argv[1])), pathlib.Path(sys.argv[2]).resolve(), pathlib.Path(sys.argv[3]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[4:])
    for i, it in enumerate(spec):
        if not only or it["out"] in only:
            render(i, len(spec), it, raw, out)
