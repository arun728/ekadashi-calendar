# Ekadashi dates and times from the Panchang engine

Status: iOS (`ios-native/`) and Android (Flutter), branch
`feature/engine-ekadashi` (draft PR #22). Built on iOS first, then ported to
Android with the same behaviour, strings and tests (AGENTS.md "iOS first").

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
  (Gaudiya/ISKCON rules, the same as the Panchang tab's Ekadashi sub-tab). The
  app calls them only "Smarta" and "Vaishnava". Switching keeps the Ekadashi on
  screen.
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
- Times are the engine's instants cut to the minute (06:04:52 → 06:04), exactly
  as the Panchang tab's Ekadashi sub-tab shows them, so Home, Calendar,
  reminders, widgets and the share card read the same as that sub-tab
  (`testHomeTimesMatchThePanchangEkadashiSubTabWorldwide`: 10 cities in India,
  the US, Europe, Australia, Singapore and Dubai, both traditions, 2026–2027).
  The disk cache is versioned (`EkadashiSchedule.formatVersion`), so schedules
  cached with older rules are recalculated.
- Parana with no bounded end (rare) ends at that day's sunset, so reminders and
  widgets always have a window.
- The Home city search is never empty: recent picks first, then popular cities
  worldwide (`RecentCities`, `PanchangCityCatalog.popular()`).
- Month labels: published rows keep their month; other fasts use the engine's
  amanta month. (The 2026 pack uses amanta names and the 2027 pack purnimanta
  names for Krishna paksha; that inconsistency is pre-existing.)

## Implementation (Android)

The Flutter app follows the iOS design file by file:

- `lib/services/ekadashi_schedule.dart` (`EkadashiSchedule`,
  `EkadashiYears`, `ScheduledEkadashi`): the same calculation, identities,
  minute truncation, sunset fallback and `schedule-2` cache key, calculated
  in an isolate and cached in memory and in shared preferences. Two screens
  asking for the same city and year share one calculation.
- `lib/services/ekadashi_settings.dart` (`EkadashiSettings`, a provider):
  Home's city (picked, else last detected, else Chennai), tradition and year,
  with the same preference keys as iOS. Choosing a city on Home also sets the
  Panchang location (`panchangCityRevision`); the Panchang tab follows it.
- `lib/main.dart`: Home's four menus in a 2×2 grid
  (`lib/screens/widgets/home_controls.dart`: location over tradition, language
  over year, equal widths per column, equal heights), the "calculating" and
  dimmed states, the share button on each card. Every other tab, reminders,
  widgets and search use every enabled year from the engine.
- `lib/screens/widgets/city_picker_sheet.dart`: the one city picker for Home
  and every Panchang sub-tab (search, "Use current location", recent and
  popular cities, each with its time zone; Panchang adds coordinates typed by
  hand).
- `lib/services/place_name_resolver.dart`: any city in the app language: the
  shared table, then the phone's geocoder in that language (saved on the
  phone), and meanwhile `lib/l10n/transliterator.dart` (byte-for-byte the iOS
  `Transliterator`, checked against `test/fixtures/transliteration.json` for all
  34,152 cities in five languages).
- `lib/screens/share_card_screen.dart` and
  `lib/screens/widgets/ekadashi_share_card.dart`: Sakthi's PR #20 card (no
  location), Share with the Play Store link only (`lib/services/app_links.dart`)
  and Save to Gallery (`gal`; Android 10 and older need
  `WRITE_EXTERNAL_STORAGE`, declared with `maxSdkVersion="29"`, and
  `requestLegacyExternalStorage`, as the plugin's README asks). Free.
- Calendar opens on Home's year, moves Home's year when it changes year, shows
  "Smarta • Chennai (IN)" above the month and slides months in 350 ms for the
  arrows, swipes and the grid alike.

Tests: `test/unit/ekadashi_schedule_test.dart`,
`test/unit/transliterator_test.dart`, `test/widget/home_engine_test.dart`
(the 2×2 grid in every language at 393 and 320 dp and 2× text, tradition,
year, city search, share card), `test/widget/panchang_screen_test.dart` (the
city picker with time zones, following Home, the full date picker on every
sub-tab), `test/widget/share_card_screen_test.dart` (the same texts and
long date as iOS, no location, Play Store link only, Save to Gallery and
Share), `test/unit/ekadashi_settings_test.dart` (Chennai by default, a picked
city wins over detection, settings survive a restart, detection without the
city catalog) and `test/ui/no_english_ui_test.dart` (the new menus, pickers
and share card in all five other languages).

## The same schedule on both platforms

`test/tool/dump_ekadashi_schedule_parity_test.dart` writes every fast for ten
cities (Chennai, New Delhi, Mumbai, New York, Los Angeles, London, Sydney,
Singapore, Dubai, Kathmandu), both traditions and 2026-2028 to
`ios-native/EkadashiCore/Tests/EkadashiCoreTests/Fixtures/ekadashi_schedule_parity.json`
and fails when the Dart schedule no longer matches it.
`EkadashiScheduleParityTests` checks that Swift gives the same 1,480 fasts
field by field (identity, notification id, content, date, fasting start,
Parana window, paksha, month, rule). After a schedule, engine or rule change:

    UPDATE_IOS_FIXTURES=1 flutter test test/tool/dump_ekadashi_schedule_parity_test.dart
