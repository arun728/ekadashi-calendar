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

# Worldwide edge cases: polar day/night, date line, half/quarter-hour zones,
# DST transition days in both hemispheres. First event in each local civil
# day, as the engine reports it (None when the body does not rise or set).
import math
from zoneinfo import ZoneInfo

sys.path.insert(0, os.path.dirname(__file__))
import reference as R  # noqa: E402

R.init(sys.argv[1])
world = json.load(open(os.path.join(os.path.dirname(__file__), "cities_world.json")))
edge = [c for c in world if c["id"].startswith("x-")]
dates = ["2026-03-08", "2026-03-29", "2026-04-05", "2026-06-21", "2026-09-27",
         "2026-10-04", "2026-11-01", "2026-12-21"]
cases = []
for c in edge:
    zone = ZoneInfo(c["tz"])
    for d in dates:
        day = dt.date.fromisoformat(d)
        start = R.civil_midnight(day, zone)
        end = R.civil_midnight(day + dt.timedelta(days=1), zone)
        row = {"id": c["id"], "lat": c["lat"], "lon": c["lon"], "tz": c["tz"], "date": d}
        for key, body, rising in (("sunrise", swe.SUN, True), ("sunset", swe.SUN, False),
                                  ("moonrise", swe.MOON, True), ("moonset", swe.MOON, False)):
            v = R.rise_set(start, c["lon"], c["lat"], body, rising)
            row[key] = R.from_jd(v).isoformat().replace("+00:00", "Z") if v is not None and v < end else None
        sample = R.jd(dt.datetime.fromisoformat(row["sunrise"].replace("Z", "+00:00"))) if row["sunrise"] else None
        row["tithi"] = R.tithi_index(sample) if sample else None
        cases.append(row)
out = os.path.join(root, "test", "fixtures", "panchang", "swiss_world_edges_2026.json")
json.dump({"source": f"Swiss Ephemeris {swe.version}: first rise/set in each local civil day (upper limb, 1013.25 hPa, 15 C), tithi at that sunrise",
           "cases": cases}, open(out, "w"), indent=1)
print(out, len(cases))
