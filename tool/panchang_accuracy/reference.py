"""Independent Panchang reference built on Swiss Ephemeris.

Development tool for the accuracy harness only; the app never ships it.
Positions come from the Swiss Ephemeris data files (JPL DE431-derived,
sepl_18.se1/semo_18.se1), not from the app's Meeus series. Skyfield with
JPL DE440s cross-checks the tropical positions (see compare.py).

Conventions match docs/PANCHANG_ACCURACY.md:
- sunrise/sunset: apparent upper limb with standard refraction, sea level;
- moonrise/moonset: topocentric upper limb with refraction;
- sidereal longitudes: Lahiri (SE_SIDM_LAHIRI), true positions;
- tithi from the tropical Moon-Sun elongation (ayanamsa cancels).
"""
import datetime as dt
import math
import os

import swisseph as swe

UTC = dt.timezone.utc
NAKSHATRA = 360 / 27


def init(ephe_path):
    swe.set_ephe_path(ephe_path)
    swe.set_sid_mode(swe.SIDM_LAHIRI)


def jd(instant):
    instant = instant.astimezone(UTC)
    hour = instant.hour + instant.minute / 60 + (instant.second + instant.microsecond / 1e6) / 3600
    return swe.julday(instant.year, instant.month, instant.day, hour)


def from_jd(value):
    y, m, d, h = swe.revjul(value)
    return dt.datetime(y, m, d, tzinfo=UTC) + dt.timedelta(hours=h)


def tropical(body, value):
    return swe.calc_ut(value, body, swe.FLG_SWIEPH)[0][0]


def sidereal(body, value):
    return swe.calc_ut(value, body, swe.FLG_SWIEPH | swe.FLG_SIDEREAL)[0][0]


def elongation(value):
    return (tropical(swe.MOON, value) - tropical(swe.SUN, value)) % 360


def moon_sid(value):
    return sidereal(swe.MOON, value)


def sun_sid(value):
    return sidereal(swe.SUN, value)


def yoga_angle(value):
    return (moon_sid(value) + sun_sid(value)) % 360


def lahiri(value):
    return swe.get_ayanamsa_ex_ut(value, swe.FLG_SWIEPH)[1]


def _progress(fn, start, value):
    return (fn(value) - start) % 360


def next_boundary(fn, value, width, limit_days=40):
    """First instant after `value` when fn crosses the next multiple of width."""
    start = fn(value)
    distance = width - (start % width)
    low, high = value, None
    step = 1 / 48
    probe = value + step
    while probe <= value + limit_days:
        if _progress(fn, start, probe) >= distance:
            high = probe
            break
        low = probe
        probe += step
    if high is None:
        return None
    for _ in range(40):
        middle = (low + high) / 2
        if _progress(fn, start, middle) >= distance:
            high = middle
        else:
            low = middle
    return high


def previous_boundary(fn, value, width):
    index = math.floor(fn(value) / width)
    high = value
    low = value - 1 / 48
    while math.floor(fn(low) / width) == index:
        high = low
        low -= 1 / 48
    for _ in range(40):
        middle = (low + high) / 2
        if math.floor(fn(middle) / width) == index:
            high = middle
        else:
            low = middle
    return high


REFRACTION = 0.5599  # degrees at the horizon, 1013.25 hPa and 15 C (SE)


def _limb_altitude(value, lon, lat, body):
    """Topocentric true altitude of the upper limb plus horizon refraction;
    zero at apparent rise/set of the upper limb."""
    x = swe.calc_ut(value, body, swe.FLG_SWIEPH | swe.FLG_EQUATORIAL | swe.FLG_TOPOCTR)[0]
    _, true_alt, _ = swe.azalt(value, swe.EQU2HOR, (lon, lat, 0), 0, 0, (x[0], x[1], x[2]))
    if body == swe.MOON:
        sd = math.degrees(math.asin(1737.4 / (x[2] * 149597870.7)))
    else:
        sd = 959.63 / x[2] / 3600
    return true_alt + sd + REFRACTION


def rise_set(value, lon, lat, body, rising, hindu=False):
    flags = swe.CALC_RISE if rising else swe.CALC_SET
    if hindu:
        flags |= swe.BIT_HINDU_RISING
    res, tret = swe.rise_trans(value, body, flags, (lon, lat, 0), 1013.25, 15, swe.FLG_SWIEPH)
    if res != 0:
        return None
    if hindu:
        return tret[0]
    # swe_rise_trans converges to a few arcseconds, which is seconds of time
    # when the body grazes the horizon at high latitude. Solve exactly on
    # Swiss Ephemeris positions with the same refraction and semidiameter.
    swe.set_topo(lon, lat, 0)
    sign = 1 if rising else -1
    low, high = tret[0] - 10 / 1440, tret[0] + 10 / 1440
    if sign * _limb_altitude(low, lon, lat, body) > 0 or sign * _limb_altitude(high, lon, lat, body) < 0:
        return tret[0]
    for _ in range(40):
        middle = (low + high) / 2
        if sign * _limb_altitude(middle, lon, lat, body) < 0:
            low = middle
        else:
            high = middle
    return high


def civil_midnight(date, zone):
    local = dt.datetime(date.year, date.month, date.day, tzinfo=zone)
    return jd(local)


def tithi_index(value):
    return math.floor(elongation(value) / 12) + 1


def nakshatra_index(value):
    return math.floor(moon_sid(value) / NAKSHATRA) + 1


def yoga_index(value):
    return math.floor(yoga_angle(value) / NAKSHATRA) + 1


def karana_index(value):
    return math.floor(elongation(value) / 6) + 1


LIMBS = {
    "tithi": (tithi_index, elongation, 12),
    "nakshatra": (nakshatra_index, moon_sid, NAKSHATRA),
    "yoga": (yoga_index, yoga_angle, NAKSHATRA),
    "karana": (karana_index, elongation, 6),
}

MONTHS = ["Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
          "Ashvina", "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna"]


def previous_new_moon(value):
    """Latest conjunction at or before `value` (elongation wraps 360 -> 0)."""
    high = value
    low = value - 0.5
    while not (elongation(low) > 300 and elongation(high) < 60):
        high = low
        low -= 0.5
    for _ in range(40):
        middle = (low + high) / 2
        if elongation(middle) > 180:
            low = middle
        else:
            high = middle
    return high


def amanta_month(value):
    """Amanta month containing `value`: named for the solar sign entered in it.

    A lunation with no sidereal solar ingress is Adhika and takes the next
    month's name. (Kshaya months do not occur in 2020-2035.)
    """
    start = previous_new_moon(value)
    end = next_boundary(elongation, start + 0.5, 360)
    sign_start = math.floor(sun_sid(start) / 30)
    sign_end = math.floor(sun_sid(end) / 30)
    adhika = sign_start == sign_end
    index = (sign_start + 1) % 12
    return MONTHS[index], adhika, start, end


def solar_ingress_between(start, end):
    a = math.floor(sun_sid(start) / 30)
    b = math.floor(sun_sid(end) / 30)
    if a == b:
        return None
    return next_boundary(sun_sid, start, 30, limit_days=2), b % 12


def ephe_path():
    return os.environ.get("SE_EPHE_PATH", "")


# --- Drik-style Smarta Ekadashi (inferred from published Drik dates) -------

def fortnight(index):
    return (index - 1) % 15 + 1


def smarta_ekadashi(sunrises, i):
    """Return True when civil day i is the Smarta fast.

    sunrises: list of sunrise JD per consecutive civil day. Rules:
    - one Ekadashi sunrise and Dwadashi at the next sunrise: that day;
    - Dwadashi skips the next sunrise: the previous (Dashami) day, so that
      Parana can be made in Dwadashi;
    - Ekadashi touches no sunrise: the day it begins (Dashami at sunrise);
    - Ekadashi at two sunrises: the second day when Dwadashi also reaches
      the following sunrise, otherwise the first day.
    """
    t = [fortnight(tithi_index(s)) for s in sunrises]

    def day_for(j):
        # j: first index with Ekadashi or skipped-Ekadashi Dwadashi at sunrise
        if t[j] == 12:
            return j - 1
        if t[j + 1] == 11:
            return j + 1 if t[j + 2] == 12 else j
        if t[j + 1] != 12:
            return j - 1
        return j

    # Day i can only be decided from j = i-1, i or i+1 (needs t[i-2..i+3]).
    for j in range(max(1, i - 1), min(len(t) - 2, i + 2)):
        if (t[j] == 11 and t[j - 1] != 11) or (t[j] == 12 and t[j - 1] == 10):
            if day_for(j) == i:
                return True
    return False


def smarta_parana(fast_sunrise_next, sunset_next, ekadashi_end, dwadashi_end):
    """Drik Parana: after sunrise and Hari Vasara, preferably in Pratahkala
    (first fifth of daylight), never in Madhyahna (third fifth); within
    Dwadashi unless Dwadashi ends before sunrise."""
    sunrise, sunset = fast_sunrise_next, sunset_next
    fifth = (sunset - sunrise) / 5
    hari_vasara_end = ekadashi_end + (dwadashi_end - ekadashi_end) / 4
    begin = max(sunrise, hari_vasara_end, ekadashi_end)
    limit = dwadashi_end if dwadashi_end > sunrise else None
    if begin < sunrise + fifth:
        end = sunrise + fifth
    else:
        begin = max(begin, sunrise + 3 * fifth)
        end = sunrise + 4 * fifth
    if limit is not None and limit < end:
        end = limit
    # No bounded window left (Dwadashi or Aparahna ends first): after-only.
    return begin, (end if end > begin else None)
