#!/usr/bin/env python3
"""Score Panchang engine output against independent references.

Usage:
  python compare.py ENGINE_GLOB REFERENCE.json GCAL.json OUT.json [--label NAME]

ENGINE_GLOB: JSON files written by export_engine.dart (quoted glob).
REFERENCE.json: build_reference.py output (Swiss Ephemeris + Drik-style rules).
GCAL.json: gcal_reference.py output.
Also reads ../../assets/calendar/<year>.json (published Drik-sourced Ekadashi
data) and festivals_reference.json (public festival dates).

Every check is pass/fail against a stated tolerance; category accuracy is the
pass rate and the overall score is the unweighted mean of category scores.
"""
import collections
import datetime as dt
import glob
import json
import os
import statistics
import sys

import reference as R

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
YEARS = (2026, 2027)  # overridden by --years

# Published data: inferred reference city per year/zone (sunrise fit, see
# docs/PANCHANG_ACCURACY.md).
PUBLISHED_CITY = {(2026, "IST"): "chennai", (2027, "IST"): "new-delhi",
                  (2026, "EST"): "new-york", (2027, "EST"): "new-york",
                  (2026, "CST"): "chicago", (2027, "CST"): "chicago",
                  (2026, "MST"): "denver", (2027, "MST"): "denver",
                  (2026, "PST"): "los-angeles", (2027, "PST"): "los-angeles"}
# Only 2027 IST reproduces Drik's published sunrise within a minute for every
# row, so only it is used for minute-level Parana comparison.
PRECISE_PARANA = {(2027, "IST")}

NAME_ALIASES = {"Devutthana": "Prabodhini", "Devshayani": "Devshayani"}


def parse(value):
    if value is None:
        return None
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(dt.timezone.utc)


def minutes(a, b):
    return abs((parse(a) - parse(b)).total_seconds()) / 60


def same_minute(a, b):
    """The app and Drik show h:mm; whole-minute zone offsets keep UTC
    truncation equivalent to local truncation."""
    return parse(a).replace(second=0, microsecond=0) == parse(b).replace(second=0, microsecond=0)


class Score:
    def __init__(self):
        self.cats = collections.OrderedDict()
        self.errors = collections.defaultdict(list)
        self.examples = collections.defaultdict(list)
        self.raw = {}
        self.excluded = []
        self.by_city = collections.defaultdict(collections.Counter)

    def check(self, category, ok, example=None):
        passed, total = self.cats.get(category, (0, 0))
        self.cats[category] = (passed + bool(ok), total + 1)
        if not ok and example and isinstance(example[0], str):
            self.by_city[example[0]][category] += 1
        if not ok and example is not None and len(self.examples[category]) < 12:
            self.examples[category].append(example)

    def error(self, category, value):
        self.errors[category].append(value)


def jd_of(value):
    return R.jd(parse(value))


def iso_of(value):
    return R.from_jd(value).isoformat()


def se_ekadashi_end(sunrise_iso):
    """Swiss Ephemeris end of the Ekadashi belonging to a fast whose day has
    the given sunrise (later that day on a Dashami fast, earlier on a
    Dwadashi fast)."""
    x = jd_of(sunrise_iso)
    step = 1 / 24 if R.fortnight(R.tithi_index(x)) == 10 else -1 / 24
    for _ in range(80):
        if R.fortnight(R.tithi_index(x)) == 11:
            return R.next_boundary(R.elongation, x, 12)
        x += step
    return None


def se_parana_event(g_iso, reason, sunrise_iso, sunset_iso):
    """Time GCAL's Parana boundary with Swiss Ephemeris, using the event GCAL
    names (EkadasiParanaType): 1 third of day, 2 Hari Vasara end,
    3 nakshatra end, 4 sunrise, 5 tithi end."""
    g = jd_of(g_iso)
    sunrise, sunset = jd_of(sunrise_iso), jd_of(sunset_iso)
    if reason == 4:
        return iso_of(sunrise)
    if reason == 1:
        return iso_of(sunrise + (sunset - sunrise) / 3)

    def boundaries(fn, width):
        found, x = [], g - 1
        while True:
            b = R.next_boundary(fn, x, width)
            if b is None or b > g + 1:
                return found
            found.append(b)
            x = b + 1e-6

    if reason == 3:
        return iso_of(min(boundaries(R.moon_sid, R.NAKSHATRA), key=lambda b: abs(b - g)))
    if reason == 5:
        return iso_of(min(boundaries(R.elongation, 12), key=lambda b: abs(b - g)))
    if reason == 2:
        ends = []
        for b in boundaries(R.elongation, 12):
            if R.fortnight(R.tithi_index(b - 1e-6)) == 11:
                d = R.next_boundary(R.elongation, b + 1e-6, 12)
                ends.append(b + (d - b) / 4)
        if ends:
            return iso_of(min(ends, key=lambda b: abs(b - g)))
    return g_iso


def date_line_shift(info):
    """True when the civil offset differs from local mean time by > 12 h."""
    if not info:
        return False
    from zoneinfo import ZoneInfo
    offset = dt.datetime(2026, 1, 15, 12, tzinfo=ZoneInfo(info["tz"])).utcoffset().total_seconds() / 3600
    return abs(offset - info["lon"] / 15) > 12


def in_years(date):
    return int(date[:4]) in YEARS


def load_engine(pattern):
    merged = {}
    for path in sorted(glob.glob(pattern)):
        merged.update(json.load(open(path)))
    return merged


def score(engine, reference, gcal, festivals):
    s = Score()
    city_info = {}
    for name in ("cities.json", "cities_world.json"):
        path = os.path.join(HERE, name)
        if os.path.exists(path):
            city_info.update({c["id"]: c for c in json.load(open(path))})
    expected_ingress = {}
    for city, ref_days in reference.items():
        for i, ref in enumerate(ref_days):
            ing = ref.get("ingress")
            if not ing:
                continue
            day = ref["date"]
            if ing["sign"] == 9 and ref["sunset"] and parse(ing["at"]) >= parse(ref["sunset"]) and i + 1 < len(ref_days):
                day = ref_days[i + 1]["date"]
            expected_ingress[(city, day)] = True
    # --- 1. Rise/set ---------------------------------------------------------
    for city, ref_days in reference.items():
        eng_days = {d["date"]: d for d in engine[city]["days"]}
        for ref in ref_days:
            if not in_years(ref["date"]) or ref["date"] not in eng_days:
                continue
            eng = eng_days[ref["date"]]
            for key, cat in (("sunrise", "Sunrise"), ("sunset", "Sunset"),
                             ("moonrise", "Moonrise"), ("moonset", "Moonset")):
                a, b = eng.get(key), ref.get(key)
                if a is None or b is None:
                    s.check(cat, a is None and b is None, (city, ref["date"], key, a, b))
                    continue
                err = minutes(a, b)
                s.error(cat, err)
                s.check(cat, err <= 1.0, (city, ref["date"], round(err, 2)))
                s.check(f"{cat} (displayed minute)", same_minute(a, b), (city, ref["date"], a, b))
            # --- 2. Limbs at sunrise and their end instants ----------------
            for limb in ("tithi", "nakshatra", "yoga", "karana"):
                same = eng[limb]["index"] == ref[limb]["index"]
                s.check(f"{limb.title()} at sunrise", same,
                        (city, ref["date"], eng[limb]["index"], ref[limb]["index"]))
                if same and eng[limb]["end"] and ref[limb]["end"]:
                    err = minutes(eng[limb]["end"], ref[limb]["end"])
                    s.error(f"{limb.title()} end time", err)
                    s.check(f"{limb.title()} end time", err <= 1.0,
                            (city, ref["date"], round(err, 2)))
                    s.check(f"{limb.title()} end (displayed minute)",
                            same_minute(eng[limb]["end"], ref[limb]["end"]),
                            (city, ref["date"], eng[limb]["end"], ref[limb]["end"]))
            # --- 3. Month, rashis -------------------------------------------
            s.check("Lunar month (Amanta, Adhika)", eng["amanta"] == ref["amanta"],
                    (city, ref["date"], eng["amanta"], ref["amanta"]))
            s.check("Sun rashi", eng["sunRashi"] == ref["sunRashi"],
                    (city, ref["date"], eng["sunRashi"], ref["sunRashi"]))
            s.check("Moon rashi", eng["moonRashi"] == ref["moonRashi"],
                    (city, ref["date"], eng["moonRashi"], ref["moonRashi"]))
            # --- 4. Solar ingress (Sankranti) -------------------------------
            # The moment's civil date; Makar Sankranti is the festival day
            # (the next day when the ingress is after local sunset).
            ingress = [o for o in eng["observances"] if o["id"].startswith("sankranti-")]
            if expected_ingress.get((city, ref["date"])):
                s.check("Sankranti day", bool(ingress), (city, ref["date"], "missing"))
            elif ingress:
                s.check("Sankranti day", False, (city, ref["date"], "spurious"))
        # --- 5. Smarta Ekadashi vs Drik-style reference rules ------------------
        ref_fasts = {d["date"]: d for d in ref_days if d["smarta"] and in_years(d["date"])}
        eng_fasts = {d["date"]: d for d in engine[city]["ekadashi"]["smarta"] if in_years(d["date"])}
        for date in sorted(ref_fasts.keys() | eng_fasts.keys()):
            s.check("Smarta Ekadashi date (all cities, Drik rules)",
                    date in ref_fasts and date in eng_fasts, (city, date,
                    "engine-only" if date in eng_fasts else "reference-only"))
            if date in ref_fasts and date in eng_fasts:
                rp, ep = ref_fasts[date].get("parana"), eng_fasts[date]
                for key in ("start", "end"):
                    ev = ep["paranaStart" if key == "start" else "paranaEnd"]
                    if rp and rp[key] is None and ev is None:
                        # Both: after Hari Vasara only, no bounded window.
                        s.check("Smarta Parana (all cities)", True)
                    elif rp and rp[key] and ev:
                        err = minutes(ev, rp[key])
                        s.error("Smarta Parana (all cities)", err)
                        s.check("Smarta Parana (all cities)", err <= 2.0, (city, date, key, round(err, 1)))
                    else:
                        s.check("Smarta Parana (all cities)", False, (city, date, key, "missing"))
        # --- 6. Gaudiya vs GCAL ------------------------------------------------
        ref_g = (gcal.get(city) or {}).get("corrected") if not any(
            d["sunrise"] is None for d in ref_days) else None
        if ref_g and date_line_shift(city_info.get(city)):
            # GCAL dates by longitude: west of 180 degrees on a UTC+12..+14
            # civil date it is one day early (verified for every fast).
            s.excluded.append((city, "all", "GCAL dates locations across the date line by longitude"))
            ref_g = None
        if ref_g:
            ref_map = {r["date"]: r for r in ref_g if in_years(r["date"])}
            eng_map = {d["date"]: d for d in engine[city]["ekadashi"]["gaudiya"] if in_years(d["date"])}
            sunrise_of = {d["date"]: d["sunrise"] for d in ref_days}

            def knife_edge(date):
                # A tithi boundary within 2 minutes of a nearby sunrise or
                # Arunodaya (JPL):
                # GCAL's choice then rests on its own astronomy.
                day = dt.date.fromisoformat(date)
                for k in range(-1, 3):
                    sr = sunrise_of.get((day + dt.timedelta(days=k)).isoformat())
                    if not sr:
                        continue
                    # Sunrise and Arunodaya (96 minutes earlier) both decide.
                    for x in (jd_of(sr), jd_of(sr) - 96 / 1440):
                        nb = R.next_boundary(R.elongation, x - 2 / 1440, 12)
                        if nb is not None and abs(nb - x) <= 2 / 1440:
                            return True
                return False

            for date in sorted(ref_map.keys() | eng_map.keys()):
                ok = date in ref_map and date in eng_map
                if not ok and knife_edge(date):
                    s.excluded.append((city, date, "Gaudiya date decided within 2 min of sunrise or Arunodaya"))
                    continue
                s.check("Gaudiya Ekadashi date (GCAL)", ok,
                        (city, date, "engine-only" if date in eng_map else "reference-only"))
                if date in ref_map and date in eng_map:
                    following = (dt.date.fromisoformat(date) + dt.timedelta(days=1)).isoformat()
                    next_day = next((d for d in ref_days if d["date"] == following), None)
                    for key, ekey in (("start", "paranaStart"), ("end", "paranaEnd")):
                        if ref_map[date].get(key) and eng_map[date][ekey]:
                            raw = minutes(eng_map[date][ekey], ref_map[date][key])
                            s.raw.setdefault("Gaudiya Parana vs raw GCAL times", []).append(raw)
                            reason = ref_map[date].get(f"{key}Reason")
                            timed = se_parana_event(ref_map[date][key], reason, next_day["sunrise"], next_day["sunset"])
                            if key == "end" and reason == 5 and parse(timed) <= parse(next_day["sunrise"]):
                                # GCAL ends Parana at a tithi end that, with JPL
                                # timing, precedes sunrise: the decision itself
                                # rests on GCAL's own astronomy. Listed, not scored.
                                s.excluded.append((city, date, "GCAL Parana decision reverses under JPL timing"))
                                continue
                            err = minutes(eng_map[date][ekey], timed)
                            s.error("Gaudiya Parana (GCAL rule, JPL timing)", err)
                            s.check("Gaudiya Parana (GCAL rule, JPL timing)", err <= 2.0, (city, date, key, round(err, 1)))
    # --- 7. Published Drik-sourced Ekadashi data ------------------------------
    for year in YEARS:
        if not os.path.exists(os.path.join(ROOT, "assets", "calendar", f"{year}.json")):
            continue
        data = json.load(open(os.path.join(ROOT, "assets", "calendar", f"{year}.json")))
        for entry in data["ekadashis"]:
            for zone, timing in entry["timing"].items():
                city = PUBLISHED_CITY[(year, zone)]
                if city not in engine:
                    continue
                fasts = {d["date"]: d for d in engine[city]["ekadashi"]["smarta"]}
                date = timing["date"]
                ref_day = next(d for d in reference[city] if d["date"] == date)
                ek_end = se_ekadashi_end(ref_day["sunrise"])
                if ek_end is not None and jd_of(parse(timing["parana_start"]).isoformat()) < ek_end - 1 / 1440:
                    # Breaking the fast while Ekadashi still runs is wrong in
                    # every tradition: a data error, excluded for every engine.
                    s.excluded.append((year, zone, entry["name"]["en"], date, "Parana starts before Ekadashi ends"))
                    continue
                fast = fasts.get(date)
                s.check("Published Ekadashi date (Drik data)", fast is not None,
                        (year, zone, entry["name"]["en"], date,
                         [d for d in fasts if abs((dt.date.fromisoformat(d) - dt.date.fromisoformat(date)).days) <= 2]))
                if fast:
                    expected = entry["name"]["en"].replace(" Ekadashi", "")
                    actual = fast["name"].replace(" Ekadashi", "")
                    actual = NAME_ALIASES.get(actual, actual)
                    s.check("Published Ekadashi name", actual == expected, (year, zone, date, actual, expected))
                if (year, zone) in PRECISE_PARANA and fast:
                    for key, ekey in (("parana_start", "paranaStart"), ("parana_end", "paranaEnd")):
                        if fast[ekey]:
                            err = minutes(fast[ekey], parse(timing[key]).isoformat())
                            s.error("Published Parana (Drik, Delhi 2027)", err)
                            s.check("Published Parana (Drik, Delhi 2027)", err <= 2.0,
                                    (year, date, key, round(err, 1)))
                        else:
                            s.check("Published Parana (Drik, Delhi 2027)", False, (year, date, key, "missing"))
    # --- 8. Festivals -----------------------------------------------------------
    def festival_key(obs):
        if obs["id"] == "vinayaka-chaturthi":
            return "ganesh-chaturthi" if obs["name"] == "Ganesh Chaturthi" else None
        if obs["id"] == "sankranti-9":
            return "makar-sankranti"
        if obs["id"] == "sankranti-0":
            return "mesha-sankranti"
        return obs["id"]

    annual = set(festivals["festivals"])
    delhi = engine.get(festivals["city"], {"days": []})["days"]
    found = collections.defaultdict(set)
    for day in delhi:
        for obs in day["observances"]:
            key = festival_key(obs)
            if key in annual:
                found[key].add(day["date"])
    for key, accepted in festivals["festivals"].items():
        for year in YEARS:
            want = {d for d in accepted if d.startswith(str(year))}
            if not any(d.startswith(str(year)) for v in festivals["festivals"].values() for d in v):
                continue
            if not want:
                continue
            if not delhi:
                continue
            got = {d for d in found[key] if d.startswith(str(year))}
            s.check("Festival dates (India, public lists)", len(got) == 1 and got <= want,
                    (key, year, sorted(got), sorted(want)))
    months = festivals["lunar_month"]
    for city, ref_days in reference.items():
        ref_map = {d["date"]: d for d in ref_days}
        counts = collections.Counter()
        for day in engine[city]["days"]:
            if not in_years(day["date"]):
                continue
            for obs in day["observances"]:
                key = festival_key(obs)
                if key not in annual:
                    continue
                counts[(key, day["date"][:4])] += 1
                if key in months and day["date"] in ref_map:
                    month, tithi = months[key]
                    ref = ref_map[day["date"]]
                    following = ref_map.get((dt.date.fromisoformat(day["date"]) + dt.timedelta(days=1)).isoformat())

                    def fits(r):
                        return r is not None and r["amanta"] == month and min(
                            (r["tithi"]["index"] - tithi) % 30, (tithi - r["tithi"]["index"]) % 30) <= 1

                    # A tithi touching no sunrise is checked at the next one.
                    s.check("Festival lunar month/tithi (all cities)", fits(ref) or fits(following),
                            (city, key, day["date"], ref["amanta"], ref["tithi"]["index"]))
        polar = {y for y in YEARS if any(
            d["date"].startswith(str(y)) and (d["sunrise"] is None or d["sunset"] is None) for d in ref_days)}
        for key in annual:
            for year in YEARS:
                if year in polar:
                    # Without a sunrise and sunset every day, kala windows do
                    # not exist on some days; listed, not scored.
                    continue
                n = counts[(key, str(year))]
                s.check("Festival occurs once per year (all cities)", n == 1, (city, key, year, n))
    return s


def summarize(s, label):
    cats = collections.OrderedDict()
    for cat, (passed, total) in s.cats.items():
        errs = s.errors.get(cat, [])
        cats[cat] = {
            "passed": passed, "total": total,
            "accuracy": round(100 * passed / total, 2) if total else None,
            "mean_error_min": round(statistics.mean(errs), 3) if errs else None,
            "p95_error_min": round(sorted(errs)[int(0.95 * (len(errs) - 1))], 3) if errs else None,
            "max_error_min": round(max(errs), 3) if errs else None,
            "examples": s.examples.get(cat, []),
        }
    scores = [c["accuracy"] for c in cats.values() if c["accuracy"] is not None]
    passed = sum(c["passed"] for c in cats.values())
    total = sum(c["total"] for c in cats.values())
    raw = {k: {"mean_error_min": round(statistics.mean(v), 3), "within_2_min": round(100 * sum(x <= 2 for x in v) / len(v), 2), "n": len(v)} for k, v in s.raw.items()}
    worst = sorted(s.by_city.items(), key=lambda kv: -sum(kv[1].values()))[:25]
    return {"label": label, "categories": cats, "supplementary": raw, "excluded_published_rows": s.excluded,
            "worst_locations": [(city, dict(c)) for city, c in worst],
            "failures_by_location": {city: sum(c.values()) for city, c in s.by_city.items()},
            "overall_category_mean": round(statistics.mean(scores), 2),
            "overall_pooled": round(100 * passed / total, 2), "checks": total}


def main():
    global YEARS
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    years = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--years=")), None)
    if years:
        YEARS = tuple(int(y) for y in years.split(","))
    label = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--label=")), "engine")
    engine = load_engine(args[0])
    reference = json.load(open(args[1]))
    reference = {k: v for k, v in reference.items() if k in engine}
    R.init(os.environ["SE_EPHE_PATH"])
    gcal = json.load(open(args[2]))
    festivals = json.load(open(os.path.join(HERE, "festivals_reference.json")))
    result = summarize(score(engine, reference, gcal, festivals), label)
    json.dump(result, open(args[3], "w"), indent=1, default=str)
    width = max(len(c) for c in result["categories"])
    for cat, c in result["categories"].items():
        err = "" if c["mean_error_min"] is None else f"  mean {c['mean_error_min']:.2f}  p95 {c['p95_error_min']:.2f}  max {c['max_error_min']:.2f} min"
        print(f"{cat.ljust(width)}  {c['accuracy']:6.2f}%  ({c['passed']}/{c['total']}){err}")
    for k, v in result["supplementary"].items():
        print(f"(supplementary) {k}: {v}")
    print(f"listed, not scored: {len(result['excluded_published_rows'])}")
    for city, counts in result["worst_locations"][:12]:
        print(f"  most failures: {city}: {counts}")
    print(f"OVERALL (mean of categories): {result['overall_category_mean']}%   pooled: {result['overall_pooled']}%   checks: {result['checks']}")


if __name__ == "__main__":
    main()
