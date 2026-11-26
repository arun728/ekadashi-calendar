#!/usr/bin/env python3
"""Original, synthesized devotional instrumental (no samples, no existing tune).
Tanpura drone + bansuri-like lead in Raga Bhupali (S R G P D) + temple bells.
Usage: synth.py out.wav [seconds]"""
import sys, wave
import numpy as np

SR = 48000
DUR = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0
N = int(SR * DUR)
rng = np.random.default_rng(108)
SA = 146.83  # D

def env_adsr(n, a, d, s, r, sustain_level=0.7):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    s = max(0, n - a - d - r)
    e = np.concatenate([np.linspace(0, 1, a, endpoint=False), np.linspace(1, sustain_level, d, endpoint=False),
                        np.full(s, sustain_level), np.linspace(sustain_level, 0, r)])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))

def tanpura_pluck(freq, length):
    t = np.arange(int(length * SR)) / SR
    out = np.zeros_like(t)
    for h in range(1, 15):
        # jawari: upper partials bloom slightly after the pluck and shimmer
        bloom = 1 - np.exp(-t * (1.5 + h * 0.15))
        amp = (1 / h ** 1.15) * (0.6 + 0.4 * bloom) * np.exp(-t * (0.5 + h * 0.13))
        shimmer = 1 + 0.25 * np.sin(2 * np.pi * (0.3 + 0.05 * h) * t + h)
        out += amp * shimmer * np.sin(2 * np.pi * freq * h * (1 + 0.0004 * np.sin(2*np.pi*0.2*t)) * t + rng.uniform(0, 6.28))
    out *= np.minimum(1, t / 0.03)
    return out

def bell(freq, length, strength=1.0):
    t = np.arange(int(length * SR)) / SR
    out = np.zeros_like(t)
    for ratio, amp, dec in [(1, 1, 0.9), (2.0, 0.45, 1.3), (2.76, 0.5, 1.6), (4.07, 0.25, 2.2), (5.4, 0.18, 2.8), (8.93, 0.08, 4.0)]:
        out += amp * np.exp(-t * dec) * np.sin(2 * np.pi * freq * ratio * t)
    return strength * out * np.minimum(1, t / 0.003)

def flute_note(f0, f1, length, glide=0.09):
    n = int(length * SR)
    t = np.arange(n) / SR
    g = np.clip(t / glide, 0, 1)
    f = f0 + (f1 - f0) * (0.5 - 0.5 * np.cos(np.pi * g))
    vib_depth = 0.0045 * np.clip((t - 0.35) / 0.6, 0, 1)
    f = f * (1 + vib_depth * np.sin(2 * np.pi * 5.2 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph) + 0.03 * np.sin(4 * ph)
    breath = rng.normal(0, 1, n)
    # crude band-pass of breath around the note
    k = np.exp(-np.linspace(0, 6, 64)); k /= k.sum()
    breath = np.convolve(breath, k, "same") - np.convolve(breath, np.ones(400) / 400, "same")
    e = env_adsr(n, 0.16, 0.25, length, min(0.45, length * 0.4), 0.8)
    return (tone + 0.10 * breath * (0.4 + 0.6 * e)) * e

# Bhupali: S R G P D (ratios), octave above middle
R = {"S": 1, "R": 9 / 8, "G": 5 / 4, "P": 3 / 2, "D": 5 / 3, "S'": 2, "R'": 9 / 4, "D,": 5 / 6, "P,": 3 / 4}
LEAD = SA * 2  # bansuri register

# (swara, beats) at ~60 bpm; slow alaap-like phrasing, original melody
PHRASE = [("S", 1.5), ("R", .5), ("G", 2), ("-", .5), ("P", 1), ("G", 1), ("R", 1), ("S", 2), ("-", .8),
          ("G", 1), ("P", 1), ("D", 1.5), ("S'", 2.5), ("-", .6), ("D", 1), ("P", 1), ("G", 1.2), ("R", .8),
          ("G", 1), ("P", 2.2), ("-", .6), ("D", 1), ("S'", 1), ("R'", 1), ("S'", 1.5), ("D", .8), ("P", 1.2),
          ("G", 1), ("R", 1), ("S", 3)]

def render():
    L = np.zeros(N); Rch = np.zeros(N)
    # tanpura: P, S', S', S (lower) repeating
    cycle = [SA * 3 / 4, SA, SA, SA / 2]
    t0, i = 0.4, 0
    while t0 < DUR:
        p = tanpura_pluck(cycle[i % 4], 5.0) * (0.16 if i % 4 else 0.19)
        s = int(t0 * SR); e = min(N, s + len(p)); seg = p[:e - s]
        pan = 0.5 + 0.18 * np.sin(i)
        L[s:e] += seg * (1 - pan) * 1.6; Rch[s:e] += seg * pan * 1.6
        t0 += 1.15; i += 1
    # lead
    beat = 0.95
    t0 = 2.6
    prev = None
    for sw, b in PHRASE:
        length = b * beat
        if sw == "-" or t0 > DUR - 2:
            t0 += length; prev = None; continue
        f1 = LEAD * R[sw]
        f0 = prev if prev else f1
        note = flute_note(f0, f1, length + 0.25) * 0.20
        s = int(t0 * SR); e = min(N, s + len(note)); seg = note[:e - s]
        L[s:e] += seg * 0.52; Rch[s:e] += seg * 0.48
        prev = f1; t0 += length
    # bells: opening, mid accent, closing
    for at, f, st in [(0.05, SA * 4, 0.35), (DUR * 0.52, SA * 4, 0.16), (DUR - 3.2, SA * 4, 0.28)]:
        b = bell(f, 6, st)
        s = int(at * SR); e = min(N, s + len(b))
        L[s:e] += b[:e - s] * 0.55; Rch[s:e] += b[:e - s] * 0.45
    return L, Rch

def reverb(x):
    out = x.copy()
    for d, g in [(0.0297, .55), (0.0371, .52), (0.0411, .5), (0.0437, .48), (0.061, .35), (0.083, .3)]:
        k = int(d * SR)
        y = np.zeros_like(x)
        for j in range(k, len(x), k):  # cheap comb via block feedback
            y[j:j + k] = (x[j - k:j] + y[j - k:j] * g)[:len(y[j:j + k])] * g
        out += y * 0.35
    return out

L, Rc = render()
L, Rc = reverb(L), reverb(Rc)
def lowpass(x, fc=3800.0):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / fc) ** 4)
    X *= np.where(f < 60, (f / 60) ** 2, 1)  # remove rumble
    return np.fft.irfft(X, len(x))
L, Rc = lowpass(L), lowpass(Rc)
fade_in = np.minimum(1, np.arange(N) / (1.2 * SR))
fade_out = np.minimum(1, (N - np.arange(N)) / (2.8 * SR))
L *= fade_in * fade_out; Rc *= fade_in * fade_out
peak = max(np.abs(L).max(), np.abs(Rc).max())
L, Rc = L / peak * 0.6, Rc / peak * 0.6  # about -4.4 dBFS peak, soft overall
pcm = (np.stack([L, Rc], 1) * 32767).astype("<i2")
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("wrote", sys.argv[1], f"{DUR}s")
