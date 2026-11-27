#!/usr/bin/env python3
"""SHOTS-ONLY: record the Play video scenes from a profile build with real touches.
Positions are measured (uiautomator) before each scene, never during recording.
Only ever talks to emulator-5554. Usage: rec_video.py out_dir [scene ...]"""
import subprocess, sys, time, re, html, pathlib
OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
ONLY = set(sys.argv[2:])
A = ["adb", "-s", "emulator-5554"]; PKG = "com.applausestudios.ekadashi_calendar"
def sh(*a): return subprocess.run(A + ["shell", *a], capture_output=True, text=True).stdout
def tap(p): sh("input", "tap", str(p[0]), str(p[1]))
def swipe(x1, y1, x2, y2, ms): sh("input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))
def back(): sh("input", "keyevent", "BACK")
W = time.sleep
def nodes():
    sh("uiautomator", "dump", "/sdcard/ui.xml")
    xml = subprocess.run(A + ["exec-out", "cat", "/sdcard/ui.xml"], capture_output=True, text=True).stdout
    out = []
    for m in re.finditer(r'<node [^>]*>', xml):
        n = m.group(0)
        lab = html.unescape(re.search(r' text="([^"]*)"', n).group(1) or re.search(r'content-desc="([^"]*)"', n).group(1))
        b = list(map(int, re.findall(r'\d+', re.search(r'bounds="([^"]*)"', n).group(1))))
        if lab: out.append((lab, ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2), b))
    return out
def find(label, exact=False, first_line=False):
    for lab, c, b in nodes():
        l = lab.split("\n")[0] if first_line else lab
        if (l == label) if exact else (label in l):
            return c
    raise SystemExit(f"not found: {label}")
def tabp(name): return find(f"{name}, Tab")
rec = None
def start(name):
    global rec
    rec = subprocess.Popen(A + ["shell", "screenrecord", "--size", "720x1604", "--bit-rate", "16000000", f"/sdcard/rec-{name}.mp4"])
    W(1.0)
def stop(name):
    sh("pkill", "-INT", "screenrecord"); rec.wait(); W(0.8)
    subprocess.run(A + ["pull", f"/sdcard/rec-{name}.mp4", str(OUT / f"{name}.mp4")], capture_output=True)
    sh("rm", f"/sdcard/rec-{name}.mp4"); print("saved", name, flush=True)
def want(n): return not ONLY or n in ONLY

# Fresh launch in New Delhi; wait for detection so Home and Panchang show it.
subprocess.run(A + ["emu", "geo", "fix", "77.2090", "28.6139"], capture_output=True)
def demo(*a): sh("am", "broadcast", "-a", "com.android.systemui.demo", "-e", "command", *a)
sh("settings", "put", "global", "sysui_demo_allowed", "1")
demo("exit"); W(0.5); demo("enter"); demo("clock", "-e", "hhmm", "1000")
demo("battery", "-e", "level", "100", "-e", "plugged", "false"); demo("network", "-e", "mobile", "hide")
demo("network", "-e", "wifi", "show", "-e", "level", "4", "-e", "fully", "true"); demo("notifications", "-e", "visible", "false")
sh("am", "force-stop", PKG); sh("am", "start", "-W", "-n", f"{PKG}/.MainActivity"); W(16)
assert any("New Delhi" in l for l, _, _ in nodes()), "Home is not in New Delhi"

if want("home"):
    nxt, prv = (1270, 1707), (72, 1707)  # unlabeled arrows beside the card
    start("home"); W(1.5); tap(nxt); W(1.9); tap(prv); W(1.4); stop("home")
if want("language"):
    lang = find("English", first_line=True); tap(lang); W(1.3)
    hindi = find("हिंदी", exact=True); back(); W(1.2)
    start("language"); W(1.0); tap(lang); W(1.5); tap(hindi); W(5.0); stop("language")
    tap(find("हिंदी", first_line=True)); W(1.3); tap(find("English", exact=True)); W(3)
if want("share"):
    sp = (899, 2479)  # unlabeled share icon
    start("share"); W(1.0); tap(sp); W(2.8); stop("share"); back(); W(1.5)
if want("calendar"):
    cal = tabp("Calendar")
    start("calendar"); W(0.8); tap(cal); W(2.6); tap((1035, 1152)); W(2.6); stop("calendar")
if want("festivals") or want("panchang"):
    tap(tabp("Panchang")); W(4); tap(find("Key days", exact=True)); W(2.5)
    fest, daily = find("Festivals", exact=True), find("Daily", exact=True)
    if want("festivals"):
        start("festivals"); W(1.2); swipe(672, 2400, 672, 1300, 2600); W(1.4); stop("festivals")
    if want("panchang"):
        start("panchang"); W(0.6); tap(daily); W(1.6); swipe(672, 2300, 672, 1300, 2000); W(1.0); stop("panchang")
if want("journey") or want("journey-share"):
    tap(tabp("Journey")); W(2.5); tap(find("Overview", exact=True)); W(1.5)
    labs = [l for l, _, _ in nodes()]
    if not any("Your 2026 Journey" in l for l in labs):
        tap((1168, 628)); W(1.3); tap((1128, 1068)); W(1.8)  # year chip, then 2026
    if want("journey"):
        start("journey"); W(1.0); swipe(672, 2300, 672, 1500, 2200); W(1.2); stop("journey")
    if want("journey-share"):
        sp = None
        for _ in range(8):
            try: sp = find("Share your", first_line=False); break
            except SystemExit:
                swipe(672, 2300, 672, 1300, 400); W(0.8)
        if sp is None: sp = find("Share")
        start("journey-share"); W(0.8); tap(sp); W(2.8); stop("journey-share"); back(); W(1.5)
if want("widgets"):
    tap(tabp("Settings")); W(2)
    wp = (672, 1237)  # the Widget Preview row (its label spans the whole group)
    tap(wp); W(2.5); tap(find("Medium", exact=True)); W(1.2)
    sm, up = find("Small", exact=True), find("Upcoming Ekadashis", exact=True)
    start("widgets"); W(1.2); tap(sm); W(1.3); tap(up); W(1.2)
    tap(find("Large", exact=True)); W(1.8); stop("widgets")
print("done")
