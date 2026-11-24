#!/usr/bin/env python3
"""Assemble the App Store preview (886x1920, H.264 High L4.0, 30 fps, AAC 256k).
Each scene: a dark aurora card with a caption (rendered by Chrome) and a trimmed
clip of real app footage, rounded, inset below the caption. Scenes cross-fade.
Usage: vcompose.py scenes.json video_dir out.mp4 audio.wav"""
import json, sys, subprocess, pathlib, math

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FF = "/opt/homebrew/bin/ffmpeg"
import os
# Defaults are the iOS preview; Android sets VW_OUT=1080 VW_FOOT=680 SRC_W=1344 SRC_H=2992.
W, H = int(os.environ.get("VW_OUT", 886)), 1920
VW = int(os.environ.get("VW_FOOT", 700))  # footage width inside the card
VH = round(VW * int(os.environ.get("SRC_H", 2868)) / int(os.environ.get("SRC_W", 1320)))
VX, VY = (W - VW) // 2, 352
FPS = 30
XF = 0.35                      # cross-fade seconds

CARD = """<!doctype html><html><head><meta charset="utf-8"><style>
*{{margin:0;padding:0;box-sizing:border-box}}html,body{{width:{W}px;height:{H}px;overflow:hidden;background:#040706}}
body{{font-family:-apple-system,"SF Pro Display",sans-serif;color:#fff;position:relative}}
.g{{position:absolute;inset:0;background:radial-gradient(700px 520px at 50% 4%,{a}70 0%,{a}18 50%,transparent 72%),
 radial-gradient(600px 600px at 110% 80%,#12b5ae22 0%,transparent 60%),radial-gradient(600px 600px at -10% 60%,#f3b23d14 0%,transparent 60%)}}
.t{{position:absolute;top:{ty}px;left:0;right:0;text-align:center;padding:0 40px}}
.tag{{display:inline-block;font-size:25px;font-weight:700;letter-spacing:3.5px;text-transform:uppercase;padding:9px 22px;border-radius:999px;margin-bottom:20px}}
.free{{background:rgba(255,255,255,.08);color:#bff3ef;border:1.5px solid rgba(191,243,239,.35)}}
.prem{{background:linear-gradient(90deg,#ffd77a,#f29f3d);color:#2a1700}}
h1{{font-size:{fs}px;font-weight:800;letter-spacing:-1.6px;line-height:1.04}}
h1 em{{font-style:normal;color:{a}}}
.frame{{position:absolute;left:{fx}px;top:{fy}px;width:{fw}px;height:{fh}px;border-radius:66px;
 box-shadow:0 0 0 2px rgba(255,255,255,.14),0 40px 120px rgba(0,0,0,.8),0 0 110px {a}44;background:#000}}
.end{{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}}
.end img{{width:300px;height:300px;border-radius:68px;box-shadow:0 30px 100px rgba(0,0,0,.7),0 0 120px {a}55;margin-bottom:56px}}
.end h2{{font-size:76px;font-weight:800;letter-spacing:-1.5px}} .end p{{font-size:38px;color:rgba(255,255,255,.72);margin-top:22px;line-height:1.3}}
</style></head><body><div class="g"></div>{body}</body></html>"""

HUES = {"teal": "#2fd0c8", "gold": "#f6b94a", "lotus": "#ef7fb6", "indigo": "#8a95ff"}

def render_card(scene, out_png):
    a = HUES[scene.get("hue", "teal")]
    if scene.get("end"):
        body = (f'<div class="end"><img src="{pathlib.Path(scene["icon"]).resolve().as_uri()}">'
                f'<h2>{scene["title"]}</h2><p>{scene.get("sub","")}</p></div>')
    else:
        tag = {"free": '<span class="tag free">Free</span><br>', "premium": '<span class="tag prem">★ Premium</span><br>'}.get(scene.get("tag"), "")
        lines = scene["title"].count("<br>") + 1
        fs = 66 if lines == 1 else 60
        ty = 74 if lines == 1 else 52
        body = (f'<div class="t">{tag}<h1>{scene["title"]}</h1></div>'
                f'<div class="frame" style="left:{VX-10}px;top:{VY-10}px;width:{VW+20}px;height:{VH+20}px"></div>')
    if scene.get("end"):
        fs, ty = 66, 0
    page = CARD.format(W=W, H=H, a=a, body=body, ty=ty, fs=fs, fx=0, fy=0, fw=0, fh=0)
    hp = out_png.with_suffix(".html"); hp.write_text(page, encoding="utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--user-data-dir={out_png.parent.parent/'chrome-prof'}", f"--window-size={W},{H}",
                    "--virtual-time-budget=2000", f"--screenshot={out_png}", hp.as_uri()], check=True, capture_output=True)
    hp.unlink()

def mask(path):
    # Rounded-rectangle alpha mask for the footage.
    from PIL import Image, ImageDraw
    m = Image.new("L", (VW, VH), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, VW - 1, VH - 1], radius=56, fill=255)
    m.save(path)

def scene_clip(scene, vdir, work, i):
    card = work / f"card{i}.png"
    render_card(scene, card)
    out = work / f"scene{i}.mp4"
    dur = scene["dur"]
    if scene.get("end"):
        cmd = [FF, "-y", "-loglevel", "error", "-loop", "1", "-t", str(dur), "-i", str(card),
               "-vf", f"fps={FPS},format=yuv420p,fade=t=in:st=0:d=0.4", "-c:v", "libx264", "-preset", "slow", "-crf", "16", str(out)]
    else:
        src = vdir / scene["clip"]
        speed = scene.get("speed", 1.0)
        fc = (f"[1:v]trim=start={scene['start']}:duration={dur*speed},setpts=(PTS-STARTPTS)/{speed},tpad=stop_mode=clone:stop_duration=4,fps={FPS},"
              f"scale={VW}:{VH}:flags=lanczos,format=rgba[v];[2:v]format=gray[m];[v][m]alphamerge[vm];"
              f"[0:v][vm]overlay={VX}:{VY}:shortest=1,format=yuv420p[o]")
        cmd = [FF, "-y", "-loglevel", "error", "-loop", "1", "-t", str(dur), "-i", str(card), "-i", str(src),
               "-loop", "1", "-t", str(dur), "-i", str(work / "mask.png"), "-filter_complex", fc, "-map", "[o]",
               "-t", str(dur), "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-r", str(FPS), str(out)]
    subprocess.run(cmd, check=True)
    return out, dur

def main():
    scenes = json.load(open(sys.argv[1])); vdir = pathlib.Path(sys.argv[2]).resolve()
    out = pathlib.Path(sys.argv[3]).resolve(); audio = pathlib.Path(sys.argv[4]).resolve()
    work = out.parent / "vwork"; work.mkdir(exist_ok=True)
    mask(work / "mask.png")
    clips = [scene_clip(s, vdir, work, i) for i, s in enumerate(scenes)]
    # Chain cross-fades.
    inputs, fc, prev, t = [], [], "[0:v]", 0.0
    for i, (c, d) in enumerate(clips):
        inputs += ["-i", str(c)]
    t = clips[0][1]
    for i in range(1, len(clips)):
        off = t - XF
        fc.append(f"{prev}[{i}:v]xfade=transition=fade:duration={XF}:offset={off:.3f}[x{i}]")
        prev = f"[x{i}]"; t = off + clips[i][1]
    total = t
    fc.append(f"{prev}format=yuv420p[v]")
    fc.append(f"[{len(clips)}:a]atrim=0:{total:.3f},afade=t=out:st={total-2.5:.3f}:d=2.5,aresample=48000[a]")
    cmd = [FF, "-y", "-loglevel", "error"] + inputs + ["-i", str(audio), "-filter_complex", ";".join(fc),
           "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p",
           "-r", str(FPS), "-b:v", "11M", "-minrate", "11M", "-maxrate", "11M", "-bufsize", "22M", "-x264-params", "nal-hrd=cbr", "-preset", "slow",
           "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart", "-t", f"{total:.3f}", str(out)]
    subprocess.run(cmd, check=True)
    print(f"wrote {out} {total:.2f}s")

if __name__ == "__main__":
    main()
