#!/usr/bin/env python3
"""Text-free artwork for In-App Events (1920x1080 card, 1080x1920 details) and
in-app purchase promotional images (1024x1024). Rendered with headless Chrome.
Usage: art.py out_dir"""
import sys, math, pathlib, subprocess, random

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

def petals(cx, cy, r, n, w, h, fill, op, rot=0, stroke=None):
    s = []
    for i in range(n):
        a = rot + 360 / n * i
        st = f' stroke="{stroke}" stroke-width="3"' if stroke else ""
        s.append(f'<ellipse cx="{cx}" cy="{cy - r}" rx="{w}" ry="{h}" transform="rotate({a:.2f} {cx} {cy})" '
                 f'fill="{fill}" fill-opacity="{op}"{st}/>')
    return "".join(s)

def lotus(cx, cy, s, c1, c2):
    """A front-facing lotus built from layered petals."""
    out = [f'<g transform="translate({cx} {cy}) scale({s})">']
    for k, (spread, ry, rx, col, op) in enumerate([(70, 150, 46, c2, .55), (45, 175, 50, c1, .8), (20, 195, 52, c1, .95), (0, 205, 54, "#ffe9b0", 1)]):
        for sgn in ([-1, 1] if spread else [0]):
            ang = sgn * spread
            out.append(f'<ellipse cx="0" cy="-{ry*0.55}" rx="{rx}" ry="{ry*0.6}" transform="rotate({ang})" fill="{col}" fill-opacity="{op}"/>')
    out.append(f'<ellipse cx="0" cy="18" rx="150" ry="26" fill="{c2}" fill-opacity=".55"/>')
    out.append("</g>")
    return "".join(out)

def moon(cx, cy, r, phase, glow="#fff4d6"):
    """phase 0..1 of lit fraction; waxing lit on the right."""
    k = 1 - 2 * phase
    rx = abs(k) * r
    lit = f'M {cx} {cy - r} A {r} {r} 0 0 1 {cx} {cy + r} A {rx} {r} 0 0 {0 if k > 0 else 1} {cx} {cy - r} Z'
    return (f'<circle cx="{cx}" cy="{cy}" r="{r*2.2}" fill="url(#mglow)"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#1b2633"/>'
            f'<path d="{lit}" fill="{glow}"/>')

def stars(w, h, n, seed):
    rnd = random.Random(seed)
    return "".join(f'<circle cx="{rnd.random()*w:.0f}" cy="{rnd.random()*h*0.7:.0f}" r="{rnd.random()*2.4+0.6:.1f}" '
                   f'fill="#fff" fill-opacity="{rnd.random()*0.6+0.15:.2f}"/>' for _ in range(n))

def waves(w, y0, col, op, amp, n=3):
    out = []
    for i in range(n):
        y = y0 + i * 55
        pts = " ".join(f"{x},{y + amp*math.sin(x/120 + i):.1f}" for x in range(0, w + 40, 40))
        out.append(f'<polyline points="{pts}" fill="none" stroke="{col}" stroke-opacity="{op - i*0.08:.2f}" stroke-width="5" stroke-linecap="round"/>')
    return "".join(out)

def diya(cx, cy, s):
    return (f'<g transform="translate({cx} {cy}) scale({s})">'
            f'<ellipse cx="0" cy="-70" rx="70" ry="110" fill="url(#flame)"/>'
            f'<path d="M -22 -10 Q 0 -120 22 -10 Q 0 10 -22 -10 Z" fill="#ffd36b"/>'
            f'<path d="M -110 0 Q 0 90 110 0 Q 60 -18 0 -14 Q -60 -18 -110 0 Z" fill="#c8742a"/>'
            f'<path d="M -110 0 Q 0 60 110 0" fill="none" stroke="#ffcf8a" stroke-width="5" stroke-opacity=".7"/></g>')

DEFS = """<defs>
<radialGradient id="mglow"><stop offset="0" stop-color="#fff1c4" stop-opacity=".55"/><stop offset="1" stop-color="#fff1c4" stop-opacity="0"/></radialGradient>
<radialGradient id="flame"><stop offset="0" stop-color="#ffd36b" stop-opacity=".9"/><stop offset=".5" stop-color="#ff9a3c" stop-opacity=".35"/><stop offset="1" stop-color="#ff7a1a" stop-opacity="0"/></radialGradient>
<radialGradient id="sun"><stop offset="0" stop-color="#fff2c8"/><stop offset=".35" stop-color="#ffc35a"/><stop offset="1" stop-color="#ff8a2a" stop-opacity="0"/></radialGradient>
<filter id="soft"><feGaussianBlur stdDeviation="40"/></filter>
</defs>"""

def scene(kind, w, h):
    """Return SVG body for a theme. Key art sits in the upper-middle."""
    cx, cy = w / 2, h * (0.40 if h > w else 0.42)
    u = min(w, h)
    bg = {
        "newyear": ("#071a1a", "#0f3a36", "#c27a1c"),
        "nirjala": ("#04141f", "#0b3a52", "#5fc7e8"),
        "devshayani": ("#0a0a1f", "#1d1d52", "#8f8cf0"),
        "prabodhini": ("#1a0d06", "#5a2a0c", "#ffb347"),
        "mokshada": ("#0d0a14", "#3b2340", "#f1c27d"),
    }[kind]
    s = [DEFS, f'<rect width="{w}" height="{h}" fill="{bg[0]}"/>',
         f'<ellipse cx="{cx}" cy="{cy}" rx="{w*0.75}" ry="{h*0.7}" fill="{bg[1]}" fill-opacity=".85" filter="url(#soft)"/>',
         stars(w, h, 140, kind)]
    if kind == "newyear":
        s.append(f'<circle cx="{cx}" cy="{cy}" r="{u*0.42}" fill="url(#sun)" fill-opacity=".55"/>')
        s.append(petals(cx, cy, u * 0.30, 24, u * 0.035, u * 0.085, "#2fd0c8", .85, stroke="#9ff2ec"))
        s.append(petals(cx, cy, u * 0.30, 24, u * 0.035, u * 0.085, "#f3b23d", .9, rot=0) if False else "")
        s.append(lotus(cx, cy + u * 0.05, u / 900, "#f6c453", "#e07a2a"))
    elif kind == "nirjala":
        s.append(moon(cx, cy - u * 0.12, u * 0.11, 0.86))
        s.append(waves(w, cy + u * 0.18, "#7fd8ef", .55, 14))
        for i, (x, y, r) in enumerate([(-0.22, 0.02, 22), (0.2, -0.05, 16), (0.3, 0.1, 12), (-0.32, 0.12, 14)]):
            s.append(f'<path d="M {cx + x*u} {cy + y*u - r*2.2} Q {cx + x*u + r} {cy + y*u} {cx + x*u} {cy + y*u + r} Q {cx + x*u - r} {cy + y*u} {cx + x*u} {cy + y*u - r*2.2} Z" fill="#bff0ff" fill-opacity=".7"/>')
        s.append(lotus(cx, cy + u * 0.16, u / 1100, "#e9f8ff", "#58b9d8"))
    elif kind == "devshayani":
        s.append(moon(cx + u * 0.22, cy - u * 0.18, u * 0.07, 0.86, "#e8e6ff"))
        for i in range(5):
            r = u * (0.12 + i * 0.055)
            s.append(f'<ellipse cx="{cx}" cy="{cy + u*0.12}" rx="{r*1.6}" ry="{r*0.42}" fill="none" stroke="#8f8cf0" stroke-opacity="{0.55 - i*0.08:.2f}" stroke-width="{12 - i*1.5:.1f}"/>')
        s.append(petals(cx, cy - u * 0.02, u * 0.13, 7, u * 0.03, u * 0.075, "#b9b6ff", .55))
        s.append(lotus(cx, cy + u * 0.08, u / 1000, "#d9d6ff", "#6f6ad8"))
    elif kind == "prabodhini":
        s.append(f'<circle cx="{cx}" cy="{cy}" r="{u*0.45}" fill="url(#sun)"/>')
        s.append(petals(cx, cy, u * 0.27, 16, u * 0.012, u * 0.12, "#ffd27a", .5))
        for k, x in enumerate([-0.36, -0.2, 0.2, 0.36]):
            s.append(diya(cx + x * u, cy + u * 0.27, u / 1500))
        s.append(lotus(cx, cy + u * 0.12, u / 950, "#ffd27a", "#d9692a"))
    elif kind == "mokshada":
        s.append(moon(cx, cy - u * 0.15, u * 0.09, 0.86))
        # chariot wheel (Gita Jayanti)
        R = u * 0.2
        spokes = "".join(f'<line x1="{cx}" y1="{cy + u*0.05}" x2="{cx + R*math.cos(math.radians(a))}" y2="{cy + u*0.05 + R*math.sin(math.radians(a))}" stroke="#f1c27d" stroke-opacity=".5" stroke-width="6"/>' for a in range(0, 360, 30))
        s.append(f'<circle cx="{cx}" cy="{cy + u*0.05}" r="{R}" fill="none" stroke="#f1c27d" stroke-opacity=".6" stroke-width="10"/>{spokes}')
        s.append(lotus(cx, cy + u * 0.12, u / 1000, "#f7d9a0", "#b06a3a"))
    return "".join(s)

def promo(kind):
    w = h = 1024; cx, cy = 512, 470
    bg = {"monthly": ("#06201f", "#0e4a46"), "yearly": ("#141005", "#4a3608"), "lifetime": ("#1a0a05", "#5a1f0c")}[kind]
    s = [DEFS, f'<rect width="{w}" height="{h}" fill="{bg[0]}"/>',
         f'<circle cx="{cx}" cy="{cy}" r="620" fill="{bg[1]}" filter="url(#soft)"/>', stars(w, h, 70, kind)]
    if kind == "monthly":
        s.append(moon(cx, cy - 60, 150, 0.5, "#d8fffb"))
        s.append(lotus(cx, cy + 250, 0.8, "#9ff2ec", "#1a8f89"))
    elif kind == "yearly":
        s.append(f'<circle cx="{cx}" cy="{cy}" r="360" fill="url(#sun)" fill-opacity=".5"/>')
        s.append(petals(cx, cy, 250, 24, 26, 64, "#f3b23d", .9, stroke="#ffe0a0"))
        s.append(f'<circle cx="{cx}" cy="{cy}" r="120" fill="#2fd0c8" fill-opacity=".85"/><circle cx="{cx}" cy="{cy}" r="120" fill="none" stroke="#bff3ef" stroke-width="6"/>')
    else:
        s.append(f'<circle cx="{cx}" cy="{cy}" r="420" fill="url(#sun)" fill-opacity=".75"/>')
        s.append(petals(cx, cy, 300, 36, 9, 120, "#ffd27a", .45))
        s.append(lotus(cx, cy + 110, 1.25, "#ffd36b", "#d9692a"))
    return w, h, "".join(s)

def render(path, w, h, body):
    html = (f'<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;width:{w}px;height:{h}px;overflow:hidden;background:#000}}</style></head>'
            f'<body><svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg">{body}</svg></body></html>')
    hp = path.with_suffix(".html"); hp.write_text(html, encoding="utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={path.parent}/.chrome",
                    f"--window-size={w},{h}", f"--screenshot={path}", hp.as_uri()], check=True, capture_output=True)
    hp.unlink()
    print("wrote", path.name)

if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1]).resolve()
    (out / "in-app-events").mkdir(parents=True, exist_ok=True); (out / "iap-promo").mkdir(parents=True, exist_ok=True)
    for k in ["newyear", "nirjala", "devshayani", "prabodhini", "mokshada"]:
        render(out / "in-app-events" / f"{k}-card-1920x1080.png", 1920, 1080, scene(k, 1920, 1080))
        render(out / "in-app-events" / f"{k}-details-1080x1920.png", 1080, 1920, scene(k, 1080, 1920))
    for k in ["monthly", "yearly", "lifetime"]:
        w, h, b = promo(k); render(out / "iap-promo" / f"{k}-1024x1024.png", w, h, b)
