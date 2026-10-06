# Panchang accuracy

Branch `feature/panchang-accuracy` (from PR #14). The engine was measured
against independent references, corrected, and measured again. No new
features were added; existing calculations were made more accurate.

## How accuracy is measured

`tool/panchang_accuracy` (development only; nothing here ships in the app)
scores the engine for 16 cities on every continent (New Delhi, Mumbai,
Chennai, Kolkata, Ujjain, Kathmandu, Dubai, Singapore, London,
Johannesburg, New York, Chicago, Denver, Los Angeles, Sydney, Auckland) and
every civil day of 2026-2027 in each city's own IANA timezone, 274,783
checks in all. Every check is pass/fail with a stated tolerance; the overall
score is the unweighted mean of the category pass rates.

References, all independent of the engine:

| Reference | Used for |
|---|---|
| Swiss Ephemeris 2.10 with the JPL DE431-based `sepl_18`/`semo_18` files | Sunrise, sunset, moonrise, moonset; tithi, nakshatra, yoga, karana at sunrise and their end times; Amanta month and Adhika; Sun/Moon rashi; Sankranti |
| Drik-style Smarta rules (below), evaluated with Swiss Ephemeris | Smarta Ekadashi dates and Parana in all 16 cities |
| GCAL (`gaurabda` 0.8.4, ISKCON calendar) | Gaudiya fasting dates; its Parana decision (sunrise, tithi end, Hari Vasara, nakshatra end, third of the day) timed with Swiss Ephemeris, because GCAL's own tithi times differ from JPL by up to about 2.5 minutes |
| Published Drik-sourced Ekadashi data in `assets/calendar` | Fasting dates, names and (Delhi 2027) Parana windows |
| Public Indian festival lists (Government of India holiday list, CalendarLabs, Hindu Blog, HinduPad, Calendarific; see `festivals_reference.json`) | 24 annual festivals in 2026 and 2027; all dates the lists give are accepted |

Tolerances: one minute for rise/set and limb end times, two minutes for
Parana, exact dates and names, and an extra "displayed minute" check because
the app shows h:mm. Rows are listed rather than scored when they are
self-contradictory or undecidable: 8 published US/IST rows whose Parana starts
before Ekadashi ends (wrong in every tradition) and 5 GCAL days whose
decision rests on a tithi ending within two minutes of sunrise. The same
exclusions apply to every engine version.

Reproduce (Python 3 with `pyswisseph`, `skyfield`, `gaurabda==0.8.4`; the
Swiss Ephemeris files from https://github.com/aloistr/swisseph/tree/master/ephe):

```sh
dart compile exe tool/panchang_accuracy/export_engine.dart -o /tmp/export
/tmp/export tool/panchang_accuracy/cities.json 2025-12-01 790 /tmp/engine.json
cd tool/panchang_accuracy
python build_reference.py cities.json 2025-12-01 790 EPHE_DIR /tmp/reference.json
python gcal_reference.py cities.json 2026,2027 /tmp/gcal.json
SE_EPHE_PATH=EPHE_DIR python compare.py /tmp/engine.json /tmp/reference.json /tmp/gcal.json /tmp/score.json
python check_positions.py EPHE_DIR /tmp/positions   # compiled positions.dart
```

## Results, 2026-2027 (16 cities)

| Check | baseline | iteration3 | Error before → after (mean / max, min) |
|---|---:|---:|---|
| Sunrise | 100.00% | 100.00% | 0.03 / 0.10 → 0.00 / 0.00 |
| Sunrise (displayed minute) | 97.60% | 100.00% |  |
| Sunset | 100.00% | 100.00% | 0.07 / 0.16 → 0.00 / 0.00 |
| Sunset (displayed minute) | 93.11% | 100.00% |  |
| Moonrise | 100.00% | 100.00% | 0.07 / 0.26 → 0.00 / 0.00 |
| Moonrise (displayed minute) | 93.53% | 100.00% |  |
| Moonset | 100.00% | 100.00% | 0.09 / 0.28 → 0.00 / 0.00 |
| Moonset (displayed minute) | 91.71% | 99.97% |  |
| Tithi at sunrise | 99.97% | 100.00% |  |
| Tithi end time | 96.79% | 100.00% | 0.32 / 1.30 → 0.00 / 0.02 |
| Tithi end (displayed minute) | 71.82% | 99.87% |  |
| Nakshatra at sunrise | 99.98% | 100.00% |  |
| Nakshatra end time | 100.00% | 100.00% | 0.15 / 0.36 → 0.00 / 0.02 |
| Nakshatra end (displayed minute) | 84.51% | 99.86% |  |
| Yoga at sunrise | 99.97% | 100.00% |  |
| Yoga end time | 94.75% | 100.00% | 0.48 / 1.30 → 0.00 / 0.02 |
| Yoga end (displayed minute) | 52.93% | 99.74% |  |
| Karana at sunrise | 99.95% | 100.00% |  |
| Karana end time | 96.71% | 100.00% | 0.32 / 1.30 → 0.00 / 0.02 |
| Karana end (displayed minute) | 71.09% | 99.81% |  |
| Lunar month (Amanta, Adhika) | 100.00% | 100.00% |  |
| Sun rashi | 100.00% | 100.00% |  |
| Moon rashi | 100.00% | 100.00% |  |
| Sankranti day | 94.43% | 100.00% |  |
| Smarta Ekadashi date (all cities, Drik rules) | 79.41% | 100.00% |  |
| Smarta Parana (all cities) | 47.91% | 100.00% | 62.45 / 452.05 → 0.00 / 0.01 |
| Gaudiya Ekadashi date (GCAL) | 100.00% | 100.00% |  |
| Gaudiya Parana (GCAL rule, JPL timing) | 100.00% | 100.00% | 0.07 / 1.90 → 0.00 / 1.92 |
| Published Ekadashi date (Drik data) | 90.52% | 99.57% |  |
| Published Ekadashi name | 100.00% | 100.00% |  |
| Published Parana (Drik, Delhi 2027) | 40.48% | 100.00% | 104.80 / 390.91 → 0.28 / 1.21 |
| Festival dates (India, public lists) | 74.47% | 100.00% |  |
| Festival lunar month/tithi (all cities) | 100.00% | 100.00% |  |
| Festival occurs once per year (all cities) | 88.54% | 100.00% |  |
| **Overall (mean of categories)** | **90.01%** | **99.97%** | |
| Overall (all 274,783 checks pooled) | 93.02% | 99.97% | |

Held-out check, 2029-2030, not used for any tuning: **91.44% → 99.92%**
(the published and festival-list categories do not exist for those years).

Positions at 400 random instants in 2000-2040 against Swiss Ephemeris
(absolute error, arcseconds):

| | Before (mean / max) | After (mean / max) |
|---|---|---|
| Sun apparent longitude | 10.8 / 32.9 | 0.04 / 0.13 |
| Moon apparent longitude | 3.0 / 12.5 | 0.10 / 0.49 |
| Lahiri ayanamsa | 1.21 / 1.50 | 0.006 / 0.017 |

One Panchang day now takes about 9 ms instead of 17 ms (Dart, desktop).

## What changed

Astronomy (`astronomy_calculator.dart`, generated `ephemeris_series.dart`
and `lunar_series.dart`):

- Sun: VSOP87D Earth series (Bretagnon & Francou 1988, CDS VI/81), FK5
  frame, annual aberration, replacing the low-precision Meeus solar formula.
- Moon: ELP 2000-82B (Chapront-Touzé & Chapront, CDS VI/79), 769 terms,
  following the authors' `elp82b.f`, with light time. Its mean longitude,
  fitted to DE200, drifts from JPL by 0.12″ + 0.68″T + 0.97″T²; this was
  refitted to JPL DE431 over 1900-2100 (held-out error 0.11″), the same kind
  of secular refit as ELP/MPP02.
- Full IAU 1980 nutation (ERFA table, 106 terms); apparent sidereal time.
- Delta T: yearly observed and predicted values instead of a polynomial that
  was 6 seconds too high in 2026 and diverging.
- Lahiri: 23°51′25.53″ at J2000 plus IAU 2006 general precession, matching
  Swiss Ephemeris `SE_SIDM_LAHIRI` to 0.02″.
- Rise/set: apparent upper limb with 33.6′ standard refraction and the actual
  semidiameter, rigorous topocentric parallax with the Earth's flattening.
  Published Drik sunrise times (Delhi 2027) match this convention to 0.25
  minutes on average, so Drik uses astronomical, not centre-of-disc, sunrise.
- Sun and nutation are cached at 6-hour nodes and the Moon at hourly nodes
  with quadratic interpolation (error below 0.002″).

Smarta Ekadashi (`calculated_ekadashi.dart`). Inferred from the published
Drik dates and verified on all 24 Delhi 2027 fasts and 48 Parana limits
(within 1.2 minutes):

- one Ekadashi sunrise followed by Dwadashi: that day;
- Ekadashi at two sunrises: the second day if Dwadashi also reaches the next
  sunrise, otherwise the first;
- Ekadashi touching no sunrise, or Dwadashi touching no sunrise after the
  Ekadashi day: the Dashami day, so that Parana falls in Dwadashi
  (Prabodhini 2026 is 20 November, as published, not the 21st);
- Parana after sunrise and Hari Vasara within Pratahkala (first fifth of the
  day); if Hari Vasara outlasts Pratahkala, after Madhyahna until the end of
  Aparahna; never after Dwadashi ends unless it ended before sunrise.

Festivals (`panchang_engine.dart`). Each tithi occurrence keeps its own
Amanta month and is observed on the civil day whose prescribed window
(kala) it covers: sunrise (Ugadi, Navaratri, Hanuman Jayanti, Guru Purnima),
Purvahna (Vasant Panchami), Madhyahna (Ganesh/Vinayaka Chaturthi, Rama
Navami), Aparahna (Vijayadashami, Bhai Dooj), Pratahkala (Govardhan Puja),
Pradosh, the first fifth of the night (Pradosham, Dhanteras, Deepavali,
Holika Dahan), Nishita, the eighth fifteenth of the night (Shivaratri,
Janmashtami with the Rohini preference), Arunodaya (Naraka Chaturdashi),
moonrise (Sankashti, Karwa Chauth) and sunset (Chhath). When both days
qualify the longer coverage wins (first day for moonrise and sunset); a
tithi touching no window is observed on the day it begins. Akshaya Tritiya
takes the sunrise tithi only if it lasts through Pratahkala. Holi is the day
after Holika Dahan; Makar Sankranti and Pongal move to the next day when
the ingress is after sunset. This removes the duplicate Ganesh Chaturthi and
Vijayadashami days of 2026 and the missing Ugadi (2026), Sharad Navaratri
and Karwa Chauth (2027). The monthly Shukla Chaturthi is labelled
"Vinayaka Chaturthi (monthly)" so it is not mistaken for Ganesh Chaturthi.

## Known limits

- Published US Ekadashi data in `assets/calendar` contains rows that
  contradict themselves (Parana before Ekadashi ends) and 2027 rows with
  approximate sunrise tables; 2026 "IST" timings match Chennai, not Delhi.
  The app's published schedule is unchanged and still authoritative.
- EST Saphala 2027 is published for 3 January; the validated rule gives
  2 January for New York (the IST date appears to have been carried over).
- Knife-edge days (a tithi ending within seconds of sunrise) depend on the
  sunrise convention and are flagged as near a boundary.
- Holika Dahan ignores Bhadra; regional festival variants, eclipses and
  personal charts remain out of scope, as before.
