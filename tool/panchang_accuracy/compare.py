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

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
YEARS = (2026, 2027)

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

    def check(self, category, ok, example=None):
        passed, total = self.cats.get(category, (0, 0))
        self.cats[category] = (passed + bool(ok), total + 1)
        if not ok and example is not None and len(self.examples[category]) < 12:
            self.examples[category].append(example)

    def error(self, category, value):
        self.errors[category].append(value)


def in_years(date):
    return int(date[:4]) in YEARS


def load_engine(pattern):
    merged = {}
    for path in sorted(glob.glob(pattern)):
        merged.update(json.load(open(path)))
    return merged


def score(engine, reference, gcal, festivals):
    s = Score()
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
            ingress = [o for o in eng["observances"] if o["id"].startswith("sankranti-")]
            if ref.get("ingress"):
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
                    if rp and rp[key] and ev:
                        err = minutes(ev, rp[key])
                        s.error("Smarta Parana (all cities)", err)
                        s.check("Smarta Parana (all cities)", err <= 2.0, (city, date, key, round(err, 1)))
                    else:
                        s.check("Smarta Parana (all cities)", False, (city, date, key, "missing"))
        # --- 6. Gaudiya vs GCAL ------------------------------------------------
        ref_g = (gcal.get(city) or {}).get("corrected")
        if ref_g:
            ref_map = {r["date"]: r for r in ref_g if in_years(r["date"])}
            eng_map = {d["date"]: d for d in engine[city]["ekadashi"]["gaudiya"] if in_years(d["date"])}
            for date in sorted(ref_map.keys() | eng_map.keys()):
                s.check("Gaudiya Ekadashi date (GCAL)", date in ref_map and date in eng_map,
                        (city, date, "engine-only" if date in eng_map else "reference-only"))
                if date in ref_map and date in eng_map:
                    for key, ekey in (("start", "paranaStart"), ("end", "paranaEnd")):
                        if ref_map[date].get(key) and eng_map[date][ekey]:
                            err = minutes(eng_map[date][ekey], ref_map[date][key])
                            s.error("Gaudiya Parana (GCAL)", err)
                            s.check("Gaudiya Parana (GCAL)", err <= 2.0, (city, date, key, round(err, 1)))
    # --- 7. Published Drik-sourced Ekadashi data ------------------------------
    for year in YEARS:
        data = json.load(open(os.path.join(ROOT, "assets", "calendar", f"{year}.json")))
        for entry in data["ekadashis"]:
            for zone, timing in entry["timing"].items():
                city = PUBLISHED_CITY[(year, zone)]
                fasts = {d["date"]: d for d in engine[city]["ekadashi"]["smarta"]}
                date = timing["date"]
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
    delhi = engine[festivals["city"]]["days"]
    found = collections.defaultdict(set)
    for day in delhi:
        for obs in day["observances"]:
            key = festival_key(obs)
            if key in annual:
                found[key].add(day["date"])
    for key, accepted in festivals["festivals"].items():
        for year in YEARS:
            want = {d for d in accepted if d.startswith(str(year))}
            if not want:
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
                    ok = ref["amanta"] == month and min(
                        (ref["tithi"]["index"] - tithi) % 30, (tithi - ref["tithi"]["index"]) % 30) <= 1
                    s.check("Festival lunar month/tithi (all cities)", ok,
                            (city, key, day["date"], ref["amanta"], ref["tithi"]["index"]))
        for key in annual:
            for year in YEARS:
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
    return {"label": label, "categories": cats,
            "overall_category_mean": round(statistics.mean(scores), 2),
            "overall_pooled": round(100 * passed / total, 2), "checks": total}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--label")]
    label = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--label=")), "engine")
    engine = load_engine(args[0])
    reference = json.load(open(args[1]))
    gcal = json.load(open(args[2]))
    festivals = json.load(open(os.path.join(HERE, "festivals_reference.json")))
    result = summarize(score(engine, reference, gcal, festivals), label)
    json.dump(result, open(args[3], "w"), indent=1, default=str)
    width = max(len(c) for c in result["categories"])
    for cat, c in result["categories"].items():
        err = "" if c["mean_error_min"] is None else f"  mean {c['mean_error_min']:.2f}  p95 {c['p95_error_min']:.2f}  max {c['max_error_min']:.2f} min"
        print(f"{cat.ljust(width)}  {c['accuracy']:6.2f}%  ({c['passed']}/{c['total']}){err}")
    print(f"OVERALL (mean of categories): {result['overall_category_mean']}%   pooled: {result['overall_pooled']}%   checks: {result['checks']}")


if __name__ == "__main__":
    main()
