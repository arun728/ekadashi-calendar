#!/usr/bin/env python3
"""Build the independent Panchang reference for every harness city.

Usage: python build_reference.py cities.json START DAYS EPHE_DIR OUT.json

Per civil day (in the city's IANA zone): Swiss Ephemeris sunrise, sunset,
moonrise, moonset; the tithi/nakshatra/yoga/karana at sunrise with their end
instants; the Amanta month (Adhika flag) and sidereal Sun/Moon signs at
sunrise; sidereal solar ingress instants; and the Drik-style Smarta fast and
Parana. Gaudiya fasts come from gaurabda (GCAL) in gcal_reference.py.
"""
import datetime as dt
import json
import multiprocessing
import sys
from zoneinfo import ZoneInfo

import swisseph as swe

import reference as R

RASHI = ["Mesha", "Vrishabha", "Mithuna", "Karka", "Simha", "Kanya", "Tula",
         "Vrischika", "Dhanu", "Makara", "Kumbha", "Meena"]


def iso(value):
    return None if value is None else R.from_jd(value).isoformat().replace("+00:00", "Z")


def city_reference(args):
    city, start, count, ephe = args
    R.init(ephe)
    zone = ZoneInfo(city["tz"])
    lat, lon = city["lat"], city["lon"]
    first = dt.date.fromisoformat(start)
    # Pad both ends for neighbour-dependent fasting rules.
    dates = [first + dt.timedelta(days=k) for k in range(-4, count + 5)]
    mids = [R.civil_midnight(d, zone) for d in dates] + [R.civil_midnight(dates[-1] + dt.timedelta(days=1), zone)]

    def within(value, i):
        return value is not None and mids[i] <= value < mids[i + 1]

    def event(i, body, rising):
        value = R.rise_set(mids[i], lon, lat, body, rising)
        return value if within(value, i) else None

    sunrises = [event(i, swe.SUN, True) for i in range(len(dates))]
    sunsets = []
    for i in range(len(dates)):
        value = event(i, swe.SUN, False)
        if value is not None and sunrises[i] is not None and value < sunrises[i]:
            later = R.rise_set(sunrises[i], lon, lat, swe.SUN, False)
            value = later if later is not None and later < mids[i] + 2 else None
        sunsets.append(value)
    days = []
    month_cache = {}
    for i in range(4, len(dates) - 5):
        sunrise = sunrises[i]
        sample = sunrise if sunrise is not None else mids[i] + 0.25
        limbs = {}
        for name, (index_fn, angle_fn, width) in R.LIMBS.items():
            limbs[name] = {"index": index_fn(sample),
                           "end": iso(R.next_boundary(angle_fn, sample, width))}
        new_moon = round(R.previous_new_moon(sample), 3)
        if new_moon not in month_cache:
            month_cache[new_moon] = R.amanta_month(sample)
        month, adhika, _, _ = month_cache[new_moon]
        ingress = R.solar_ingress_between(mids[i], mids[i + 1])
        days.append({
            "date": dates[i].isoformat(),
            "sunrise": iso(sunrise),
            "sunset": iso(sunsets[i]),
            "moonrise": iso(event(i, swe.MOON, True)),
            "moonset": iso(event(i, swe.MOON, False)),
            **limbs,
            "amanta": ("Adhika " if adhika else "") + month,
            "adhika": adhika,
            "sunRashi": RASHI[int(R.sun_sid(sample) // 30) % 12],
            "moonRashi": RASHI[int(R.moon_sid(sample) // 30) % 12],
            "ingress": None if ingress is None else {"at": iso(ingress[0]), "sign": ingress[1]},
            "smarta": False,
        })
    # Smarta fasts and Parana (Drik-style rules validated in compare.py).
    for i in range(4, len(dates) - 5):
        if None in sunrises[i - 3:i + 4] or None in sunsets[i:i + 2]:
            continue
        if not R.smarta_ekadashi(sunrises[i - 3:i + 4], 3):
            continue
        day = days[i - 4]
        day["smarta"] = True
        probe = sunrises[i] - 1
        while R.fortnight(R.tithi_index(probe)) != 11:
            probe += 1 / 48
        ekadashi_end = R.next_boundary(R.elongation, probe, 12)
        dwadashi_end = R.next_boundary(R.elongation, ekadashi_end + 1e-6, 12)
        begin, end = R.smarta_parana(sunrises[i + 1], sunsets[i + 1], ekadashi_end, dwadashi_end)
        day["parana"] = {"start": iso(begin), "end": iso(end) if end else None}
    return city["id"], days


def main():
    cities = json.load(open(sys.argv[1]))
    start, count, ephe, out = sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
    with multiprocessing.Pool(4) as pool:
        result = dict(pool.map(city_reference, [(c, start, count, ephe) for c in cities]))
    json.dump(result, open(out, "w"))


if __name__ == "__main__":
    main()
