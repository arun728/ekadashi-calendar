"""Development-only Swiss Ephemeris fixture; no Swiss library ships in the app.
Run: python birth_reference.py EPHE_DIR OUTPUT_JSON
Uses apparent geocentric ecliptic positions, true equinox of date, Lahiri.
Synthetic instants only; never supply personal birth records to this tool.
"""
import datetime as dt
import json
import math
import random
import sys
import swisseph as swe

swe.set_ephe_path(sys.argv[1])
swe.set_sid_mode(swe.SIDM_LAHIRI)
UTC = dt.timezone.utc

def position(instant):
    jd = swe.julday(instant.year, instant.month, instant.day,
                   instant.hour + instant.minute / 60 + instant.second / 3600)
    moon, mf = swe.calc_ut(jd, swe.MOON, swe.FLG_SWIEPH)
    sun, sf = swe.calc_ut(jd, swe.SUN, swe.FLG_SWIEPH)
    assert mf & swe.FLG_SWIEPH and sf & swe.FLG_SWIEPH, 'Independent data files required'
    aya = swe.get_ayanamsa_ex_ut(jd, swe.FLG_SWIEPH)[1]
    sid = (moon[0] - aya) % 360
    elong = (moon[0] - sun[0]) % 360
    return dict(utc=instant.strftime('%Y-%m-%dT%H:%M:%SZ'), moon=moon[0], sun=sun[0], lahiri=aya,
                rashi=int(sid // 30) + 1, nakshatra=int(sid / (360 / 27)) + 1,
                pada=int(sid / (360 / 108)) % 4 + 1, tithi=int(elong // 12) + 1)

rng = random.Random(42)
start, end = dt.datetime(1900, 1, 1, tzinfo=UTC), dt.datetime(2026, 10, 18, tzinfo=UTC)
instants = [start, dt.datetime(1904, 2, 29, tzinfo=UTC), dt.datetime(2000, 2, 29, tzinfo=UTC), end]
instants += [start + dt.timedelta(seconds=rng.randrange(int((end-start).total_seconds()))) for _ in range(160)]
# Find real changes and bracket them on either side, independent of app code.
for field in ['rashi', 'nakshatra', 'pada', 'tithi']:
    cursor = dt.datetime(1990, 1, 1, tzinfo=UTC)
    for _ in range(4):
        before = position(cursor)[field]
        high = cursor + dt.timedelta(hours=1)
        while position(high)[field] == before:
            high += dt.timedelta(hours=1)
        low = high - dt.timedelta(hours=1)
        while (high-low).total_seconds() > 1:
            mid = low + (high-low)/2
            if position(mid)[field] == before: low = mid
            else: high = mid
        instants += [low-dt.timedelta(minutes=2), high+dt.timedelta(minutes=2)]
        cursor = high + dt.timedelta(hours=1)
rows = [position(i.replace(microsecond=0)) for i in sorted(instants)]
with open(sys.argv[2], 'w') as out:
    json.dump({'source': 'Swiss Ephemeris 2.10.03; DE431 sepl_18/semo_18; FLG_SWIEPH; Lahiri apparent ayanamsa',
               'documentation': 'https://www.astro.com/swisseph/swisseph.htm', 'samples': rows}, out, indent=2)
    out.write('\n')
print(f'{len(rows)} independent reference samples written')
