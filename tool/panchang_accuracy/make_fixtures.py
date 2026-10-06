#!/usr/bin/env python3
"""Write test fixtures from Swiss Ephemeris (development only).

Usage: python make_fixtures.py EPHE_DIR
Writes test/fixtures/panchang/swiss_ephemeris_positions.json: apparent
geocentric tropical Sun and Moon longitudes (true equinox of date) and the
true Lahiri ayanamsa at 60 instants in 2000-2040 (Swiss Ephemeris 2.10,
JPL DE431-based sepl_18/semo_18 files).
"""
import datetime as dt
import json
import os
import random
import sys

import swisseph as swe

swe.set_ephe_path(sys.argv[1])
swe.set_sid_mode(swe.SIDM_LAHIRI)
random.seed(2026)
rows = []
start = dt.datetime(2000, 1, 1, tzinfo=dt.timezone.utc)
for _ in range(60):
    instant = start + dt.timedelta(seconds=round(random.uniform(0, 40 * 365.25 * 86400)))
    h = instant.hour + instant.minute / 60 + instant.second / 3600
    jd = swe.julday(instant.year, instant.month, instant.day, h)
    rows.append({
        "utc": instant.isoformat().replace("+00:00", "Z"),
        "sun": round(swe.calc_ut(jd, swe.SUN)[0][0], 8),
        "moon": round(swe.calc_ut(jd, swe.MOON)[0][0], 8),
        "lahiri": round(swe.get_ayanamsa_ex_ut(jd, swe.FLG_SWIEPH)[1], 8),
    })
root = os.path.join(os.path.dirname(__file__), "..", "..")
out = os.path.join(root, "test", "fixtures", "panchang", "swiss_ephemeris_positions.json")
json.dump({"source": f"Swiss Ephemeris {swe.version} (sepl_18/semo_18, JPL DE431); apparent, true equinox of date; Lahiri SE_SIDM_LAHIRI true ayanamsa",
           "samples": rows}, open(out, "w"), indent=1)
print(out, len(rows))

# Rise/set fixture: apparent upper limb, standard refraction (1013.25 hPa,
# 15 C), sea level, topocentric Moon - Swiss Ephemeris swe_rise_trans.
cities = [("new-delhi", 28.6139, 77.2090), ("london", 51.5074, -0.1278),
          ("sydney", -33.8688, 151.2093), ("new-york", 40.7128, -74.0060)]
events = []
for name, lat, lon in cities:
    for month in range(1, 13, 2):
        jd0 = swe.julday(2027, month, 10, 0) - lon / 360  # local midnight-ish
        for body, label in ((swe.SUN, "sun"), (swe.MOON, "moon")):
            for flag, kind in ((swe.CALC_RISE, "rise"), (swe.CALC_SET, "set")):
                res, t = swe.rise_trans(jd0, body, flag, (lon, lat, 0), 1013.25, 15, swe.FLG_SWIEPH)
                if res != 0:
                    continue
                y, m, d, h = swe.revjul(t[0])
                instant = dt.datetime(y, m, d, tzinfo=dt.timezone.utc) + dt.timedelta(hours=h)
                events.append({"city": name, "lat": lat, "lon": lon, "body": label, "event": kind,
                               "utc": instant.isoformat().replace("+00:00", "Z")})
out = os.path.join(root, "test", "fixtures", "panchang", "swiss_rise_set_2027.json")
json.dump({"source": f"Swiss Ephemeris {swe.version} swe_rise_trans: upper limb, refraction at 1013.25 hPa and 15 C, sea level",
           "events": events}, open(out, "w"), indent=1)
print(out, len(events))
