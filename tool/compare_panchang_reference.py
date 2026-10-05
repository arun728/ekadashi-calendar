#!/usr/bin/env python3
"""Compare an audit JSON with raw GCAL and an explicitly labelled diagnostic.

Development only: pip install gaurabda==0.8.4 (or record the version used).
Run: python tool/compare_panchang_reference.py candidate.json [--diagnostic]
No application data or stored fixtures are changed. Results are not religious
certification; see docs/PANCHANG_RESEARCH.md.
"""
import argparse
import datetime as dt
import importlib.metadata
import io
import json


def main():
    import gaurabda as gcal

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate")
    parser.add_argument("--diagnostic", action="store_true")
    args = parser.parse_args()
    if args.diagnostic:
        original = gcal.TCalendar.IsMhd58

        def corrected_no_match(self, index):
            value = original(self, index)
            return 0 if value == 256 else value

        gcal.TCalendar.IsMhd58 = corrected_no_match
    candidate = json.load(open(args.candidate, encoding="utf-8"))
    year = candidate["year"]
    report = {"reference_version": importlib.metadata.version("gaurabda"),
              "diagnostic_no_match_sentinel": args.diagnostic,
              "year": year, "locations": {}}
    locations = [("new-delhi", 28.6139, 77.209, "Asia/Calcutta"),
                 ("new-york", 40.7128, -74.006, "America/New_York"),
                 ("london", 51.5074, -.1278, "Europe/London"),
                 ("sydney", -33.8688, 151.2093, "Australia/Sydney")]
    for name, latitude, longitude, zone in locations:
        timezone = next(z for z in gcal.GetTimeZones() if z.endswith(" " + zone))
        location = gcal.GCLocation(data={"name": name, "latitude": latitude,
                                        "longitude": longitude, "tzname": timezone})
        calendar = gcal.TCalendar()
        calendar.CalculateCalendar(location, gcal.GCGregorianDate(year=year, month=1, day=1), 366)
        buffer = io.StringIO()
        calendar.write(buffer, format="json")
        days = json.loads(buffer.getvalue())["days"]
        reference = {}
        for index, day in enumerate(days[:-1]):
            d = day["date"]
            if day["fast"] != 518 or d["year"] != year:
                continue
            date = f'{d["year"]:04d}-{d["month"]:02d}-{d["day"]:02d}'
            reference[date] = days[index + 1]
        actual = {d["date"]: d for d in candidate["locations"][name]["gaudiya"]}
        errors = []
        for date in actual.keys() & reference.keys():
            row, ref = actual[date], reference[date]
            parana = ref.get("ekadashiParana")
            if not parana:
                continue
            for actual_key, ref_key in [("paranaStartUtc", "startTime"), ("paranaEndUtc", "endTime")]:
                if row[actual_key] and parana[ref_key] >= 0:
                    expected = dt.datetime.fromisoformat(date) + dt.timedelta(
                        days=1, hours=parana[ref_key] - ref["date"]["offset"] - ref["hasDST"])
                    value = dt.datetime.fromisoformat(row[actual_key]).replace(tzinfo=None)
                    errors.append(abs((value - expected).total_seconds()) / 60)
        report["locations"][name] = {
            "candidate_count": len(actual), "reference_count": len(reference),
            "candidate_only_dates": sorted(actual.keys() - reference.keys()),
            "reference_only_dates": sorted(reference.keys() - actual.keys()),
            "max_parana_difference_minutes_on_matching_dates": max(errors, default=None)}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
