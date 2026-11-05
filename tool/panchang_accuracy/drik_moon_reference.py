"""Rewrites the Moon rise/set references of the Swiss Ephemeris fixtures with
Drik Panchang's convention (docs/PANCHANG_ACCURACY.md, "Drik time base"):
the centre of the disc without refraction, the first moonrise and moonset
after the day's sunrise and before the next sunrise (the civil day when the
Sun does not rise). Sun rows are left as they are.

Usage (pyswisseph and the Swiss Ephemeris files):
  python drik_moon_reference.py EPHE_DIR test/fixtures/panchang
"""
import datetime as dt
import json
import sys
from zoneinfo import ZoneInfo

import swisseph as swe

ZONES = {'new-delhi': 'Asia/Kolkata', 'london': 'Europe/London',
         'sydney': 'Australia/Sydney', 'new-york': 'America/New_York'}
MOON = swe.BIT_DISC_CENTER | swe.BIT_NO_REFRACTION


def jd(instant):
    u = instant.astimezone(dt.timezone.utc)
    return swe.julday(u.year, u.month, u.day, u.hour + u.minute / 60 + (u.second + u.microsecond / 1e6) / 3600)


def iso(j):
    y, m, d, h = swe.revjul(j)
    base = dt.datetime(y, m, d, tzinfo=dt.timezone.utc) + dt.timedelta(hours=h)
    return base.isoformat().replace('+00:00', 'Z')


def event(start, end, body, flag, lat, lon):
    try:
        res, t = swe.rise_trans(start, body, flag, (lon, lat, 0), 1013.25, 15, swe.FLG_SWIEPH)
    except swe.Error:
        return None
    t = t[0]
    return t if res == 0 and start <= t < end else None


def moon_day(date, lat, lon, zone):
    """(moonrise, moonset) Julian days of Drik's day for a civil date."""
    tz = ZoneInfo(zone)
    midnight = jd(dt.datetime(date.year, date.month, date.day, tzinfo=tz))
    next_midnight = jd(dt.datetime.combine(date + dt.timedelta(days=1), dt.time(), tz))
    sunrise = event(midnight, next_midnight, swe.SUN, swe.CALC_RISE, lat, lon)
    if sunrise is None:
        start, end = midnight, next_midnight
    else:
        start = sunrise
        sunset = event(sunrise, sunrise + 2, swe.SUN, swe.CALC_SET, lat, lon)
        after = jd(dt.datetime.combine(date + dt.timedelta(days=2), dt.time(), tz))
        following = event(sunset, after, swe.SUN, swe.CALC_RISE, lat, lon) if sunset else None
        end = following if following else start + 1
    return (event(start, end, swe.MOON, swe.CALC_RISE | MOON, lat, lon),
            event(start, end, swe.MOON, swe.CALC_SET | MOON, lat, lon))


def note(data):
    text = '; Moon rows: disc centre without refraction, first after sunrise (Drik).'
    if text not in data['source']:
        data['source'] += text


def main(ephe, folder):
    swe.set_ephe_path(ephe)
    path = f'{folder}/swiss_rise_set_2027.json'
    data = json.load(open(path))
    for row in data['events']:
        if row['body'] != 'moon':
            continue
        zone = ZONES[row['city']]
        old = dt.datetime.fromisoformat(row['utc'].replace('Z', '+00:00')).astimezone(ZoneInfo(zone))
        date = dt.date.fromisoformat(row.get('date', old.date().isoformat()))
        rise, set_ = moon_day(date, row['lat'], row['lon'], zone)
        value = rise if row['event'] == 'rise' else set_
        row['date'] = date.isoformat()
        row['utc'] = iso(value) if value else None
    note(data)
    json.dump(data, open(path, 'w'), indent=1)

    path = f'{folder}/swiss_world_edges_2026.json'
    data = json.load(open(path))
    for row in data['cases']:
        rise, set_ = moon_day(dt.date.fromisoformat(row['date']), row['lat'], row['lon'], row['tz'])
        row['moonrise'] = iso(rise) if rise else None
        row['moonset'] = iso(set_) if set_ else None
    note(data)
    json.dump(data, open(path, 'w'), indent=1)


if __name__ == '__main__':
    main(*sys.argv[1:3])
