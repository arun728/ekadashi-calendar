#!/usr/bin/env python3
"""Gaudiya/ISKCON reference fasts from gaurabda (GCAL Python port, MIT).

Usage: python gcal_reference.py cities.json YEAR[,YEAR...] OUT.json

pip install gaurabda==0.8.4. Two variants are written per city:
- "raw": the unmodified port;
- "corrected": only IsMhd58's no-match sentinel (256) is mapped to 0, the
  value MahadvadasiCalc expects (see docs/PANCHANG_RESEARCH.md).
Cities whose IANA zone gaurabda does not list are skipped and reported.
"""
import datetime as dt
import io
import json
import sys

import gaurabda as gcal

ALIASES = {"Asia/Kolkata": "Asia/Calcutta"}


def fasts(city, year):
    zone_name = ALIASES.get(city["tz"], city["tz"])
    zone = next((z for z in gcal.GetTimeZones() if z.endswith(" " + zone_name)), None)
    if zone is None:
        return None
    location = gcal.GCLocation(data={"name": city["id"], "latitude": city["lat"],
                                    "longitude": city["lon"], "tzname": zone})
    calendar = gcal.TCalendar()
    calendar.CalculateCalendar(location, gcal.GCGregorianDate(year=year, month=1, day=1), 368)
    buffer = io.StringIO()
    calendar.write(buffer, format="json")
    days = json.loads(buffer.getvalue())["days"]
    result = []
    for index, day in enumerate(days[:-1]):
        d = day["date"]
        if day["fast"] != 518 or d["year"] != year:
            continue
        date = dt.date(d["year"], d["month"], d["day"])
        entry = {"date": date.isoformat()}
        following = days[index + 1]
        parana = following.get("ekadashiParana")
        if parana:
            # GCAL EkadasiParanaType: 1 third of day, 2 Hari Vasara (quarter
            # of Dwadashi), 3 nakshatra end, 4 sunrise, 5 tithi end.
            entry["startReason"] = parana.get("startReason")
            entry["endReason"] = parana.get("endReason")
            for key, ref_key in (("start", "startTime"), ("end", "endTime")):
                if parana[ref_key] >= 0:
                    hours = parana[ref_key] - following["date"]["offset"] - following["hasDST"]
                    instant = dt.datetime(date.year, date.month, date.day) + dt.timedelta(days=1, hours=hours)
                    entry[key] = instant.isoformat() + "Z"
        result.append(entry)
    return result


def main():
    cities = json.load(open(sys.argv[1]))
    years = [int(y) for y in sys.argv[2].split(",")]
    output = {}
    original = gcal.TCalendar.IsMhd58
    for variant in ("raw", "corrected"):
        if variant == "corrected":
            def corrected(self, index):
                value = original(self, index)
                return 0 if value == 256 else value
            gcal.TCalendar.IsMhd58 = corrected
        for city in cities:
            rows = []
            for year in years:
                found = fasts(city, year)
                if found is None:
                    rows = None
                    break
                rows.extend(found)
            output.setdefault(city["id"], {})[variant] = rows
            print(variant, city["id"], "skipped" if rows is None else len(rows), file=sys.stderr)
    gcal.TCalendar.IsMhd58 = original
    json.dump(output, open(sys.argv[3], "w"), indent=1)


if __name__ == "__main__":
    main()
