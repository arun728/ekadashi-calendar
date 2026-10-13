# Ekadashi dates and times from the Panchang engine

Status: iOS (`ios-native/`), branch `feature/engine-ekadashi`. Android follows
after Arun approves it on iOS (AGENTS.md "iOS first").

## What changed

Home, Calendar, reminders, widgets, Journey (Vrat) and search now take every
Ekadashi date, fasting start and Parana window from the Panchang engine
(`CalculatedEkadashiEngine`) for:

- **the Ekadashi city**: the city the user picked on Home, else the last
  detected location, else **Chennai**. Any of the 34,152 cities in
  `assets/panchang/cities.json` can be searched, as on the Panchang tab.
  Picking a city on Home also sets the Panchang location (not the other way
  round). "Use current location" goes back to detection.
- **the tradition** chosen on Home: Smarta (Drik rules) or Vaishnava
  (Gaudiya/ISKCON rules, the same as the Panchang tab's Ekadashi sub-tab).
- **the year** chosen on Home (2026 or 2027). Calendar opens on that year, and
  moving Calendar into another year moves Home with it.

The published IST/EST/CST/MST/PST times in `assets/calendar/<year>.json` are no
longer shown. The Panchang tab's own Ekadashi sub-tab is unchanged.

Home and Calendar stay free; Panchang's detailed pages stay Premium.

## Adding a year (2028 and later)

1. Append the year to `enabled_years` in `assets/calendar/ekadashi_years.json`
   (and copy it to `ios-native/EkadashiCore/Sources/EkadashiCore/Resources/calendar/`
   with `python3 tool/ios/generate_core_resources.py`).
2. Ship the release. Nothing else is needed:
   - the engine calculates the dates and times for every city and tradition;
   - names, significance, stories, fasting rules and benefits come from the
     year packs by Ekadashi (`content_id`), in all six languages. Every name the
     engine gives, including Padmini and Parama in Adhika years, has content
     (`EkadashiScheduleTests.testEveryEngineNameHasPublishedContent`).

A year pack is optional. Add one only to fix the identities of a year in
advance or to give a year its own texts.

## Identities (Vrat history, reminders, widgets)

- In a year with a pack, each calculated fast keeps the `occurrence_uid`,
  notification id and texts of the published row of the **same Ekadashi within
  three days**. A Vaishnava fast a day after the Smarta one, or a fast a day
  earlier in America, is the same occurrence, so records and reminders follow it.
- A fast the pack lacks gets the next number of its year. The 2027 pack has 24
  rows, but 2027 has 25 Ekadashis: Saphala on 23 Dec 2027 becomes
  `ekadashi:2027:25` (notification id 2027025).
- In a year without a pack, fasts are numbered in date order:
  `ekadashi:2028:01`, notification id 2028001, and so on.

## Accuracy against the published data

Checked by `EkadashiScheduleTests` and the comparison in the PR:

| Pack | Matches the engine for | Notes |
| --- | --- | --- |
| 2026 IST | Chennai, Smarta | All 24 dates and IDs. Varuthini (06:54) and Indira (06:14) fasting starts in the pack are typos; sunrise is 05:57 and 05:58. Three Parana windows (Yogini, Shravana Putrada, Prabodhini) in the pack follow a morning window; the engine's Smarta rule gives the afternoon window after Hari Vasara. |
| 2027 IST | New Delhi, Smarta | Every date and time within one minute, plus the missing 23 Dec Saphala. |
| US zones | — | 2026 had a wrong Mohini date (26 Apr; 27 Apr locally), PST January fasting starts set to the Parana time, and Parana ends hours off; 2027 fasting starts were up to 40 minutes off. The engine replaces them with the city's own times. |

Smarta dates are the same across India (18 cities checked, Port Blair to Bhuj);
only the times change. Vaishnava dates and anything outside India can differ by
a day between cities, which is why the schedule is per city, not per time zone.

## Implementation (iOS)

- `EkadashiCore/Calendar/EkadashiSchedule.swift`: calculation, identities,
  texts and a per-(city, tradition, year, rule version) cache, in memory and on
  disk (`Caches/ekadashi_schedule`). A city and year take about 0.7 s on the
  Linux test machine; the app calculates off the main thread and shows a
  progress state the first time.
- `CalculatedEkadashiEngine` reads a lightweight day (`EkadashiDay`: sunrise,
  sunset, tithi, nakshatra, month) instead of the full Panchang day. The
  Dart-parity tests prove the fasts are unchanged.
- Parana with no bounded end (rare) ends at that day's sunset, so reminders and
  widgets always have a window.
- Month labels: published rows keep their month; other fasts use the engine's
  amanta month. (The 2026 pack uses amanta names and the 2027 pack purnimanta
  names for Krishna paksha; that inconsistency is pre-existing.)
