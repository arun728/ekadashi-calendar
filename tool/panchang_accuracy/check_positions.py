#!/usr/bin/env python3
"""Compare engine Sun/Moon/ayanamsa with Swiss Ephemeris at random instants.

Usage: python check_positions.py EPHE_DIR "dart run tool/panchang_accuracy/positions.dart"
"""
import datetime as dt
import json
import os
import random
import subprocess
import sys
import tempfile

import swisseph as swe

swe.set_ephe_path(sys.argv[1])
swe.set_sid_mode(swe.SIDM_LAHIRI)
random.seed(7)
first, last = (int(y) for y in os.environ.get("YEARS", "2000-2040").split("-"))
start = dt.datetime(first, 1, 1, tzinfo=dt.timezone.utc)
span = (last - first) * 365.25 * 86400
instants = [start + dt.timedelta(seconds=random.uniform(0, span)) for _ in range(400)]
with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
    f.write("\n".join(i.isoformat().replace("+00:00", "Z") for i in instants))
    path = f.name
engine = json.loads(subprocess.check_output(sys.argv[2], shell=True, env={**os.environ, "POSITIONS_IN": path}))


def diff(a, b):
    return ((a - b + 180) % 360 - 180) * 3600


rows = {"sun": [], "moon": [], "ayanamsa": []}
for instant, (sun, moon, aya) in zip(instants, engine):
    h = instant.hour + instant.minute / 60 + (instant.second + instant.microsecond / 1e6) / 3600
    jd = swe.julday(instant.year, instant.month, instant.day, h)
    rows["sun"].append(diff(sun, swe.calc_ut(jd, swe.SUN)[0][0]))
    rows["moon"].append(diff(moon, swe.calc_ut(jd, swe.MOON)[0][0]))
    rows["ayanamsa"].append(diff(aya, swe.get_ayanamsa_ex_ut(jd, swe.FLG_SWIEPH)[1]))
for key, values in rows.items():
    a = sorted(abs(v) for v in values)
    print(f"{key:9s} mean |err| {sum(a)/len(a):7.3f}\"  p95 {a[int(.95*len(a))]:7.3f}\"  max {a[-1]:7.3f}\"")
