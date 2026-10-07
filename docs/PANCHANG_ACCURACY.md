# Panchang accuracy

Branch `feature/panchang-accuracy` (from PR #14). The engine was measured
against independent references, corrected, and measured again. No new
features were added; existing calculations were made more accurate.

## How accuracy is measured

`tool/panchang_accuracy` (development only; nothing here ships in the app)
scores the engine for 16 cities on every continent (New Delhi, Mumbai,
Chennai, Kolkata, Ujjain, Kathmandu, Dubai, Singapore, London,
Johannesburg, New York, Chicago, Denver, Los Angeles, Sydney, Auckland) and
every civil day of 2026-2027 in each city's own IANA timezone, 277,808
checks in all, then extended to 396 locations worldwide (below). Every check is pass/fail with a stated tolerance; the overall
score is the unweighted mean of the category pass rates.

References, all independent of the engine:

| Reference | Used for |
|---|---|
| Swiss Ephemeris 2.10 with the JPL DE431-based `sepl_18`/`semo_18` files | Sunrise, sunset, moonrise, moonset; tithi, nakshatra, yoga, karana at sunrise and their end times; Amanta month and Adhika; Sun/Moon rashi; Sankranti |
| Drik-style Smarta rules (below), evaluated with Swiss Ephemeris | Smarta Ekadashi dates and Parana in all 16 cities |
| GCAL (`gaurabda` 0.8.4, ISKCON calendar) | Gaudiya fasting dates; its Parana decision (sunrise, tithi end, Hari Vasara, nakshatra end, third of the day) timed with Swiss Ephemeris, because GCAL's own tithi times differ from JPL by up to about 2.5 minutes |
| Published Drik-sourced Ekadashi data in `assets/calendar` | Fasting dates, names and (Delhi 2027) Parana windows |
| ISKCON Bangalore's published Ekadashi calendar, March 2026 to March 2027 | Gaudiya fasting dates and their special cases, independent of GCAL |
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

## Smarta and Vaishnava (Gaudiya/ISKCON) Ekadashi

Both traditions were measured with the same harness, before and after,
worldwide (396 locations, 2026-2027), in the first 16 cities, and in the
held-out years 2029-2030 that were never used for tuning.

| Check | Worldwide before → after | 16 cities before → after | Held-out 2029-30 before → after |
|---|---|---|---|
| Smarta fasting date (Drik rules) | 79.40% → 100.00% | 79.41% → 100.00% | 80.85% → 100.00% |
| Smarta Parana within 2 minutes | 47.99% → 100.00% | 47.91% → 100.00% | 48.36% → 100.00% |
| Smarta Parana, displayed minute | 45.61% → 99.99% | 46.27% → 100.00% | 45.50% → 100.00% |
| Smarta Parana mean / max error (min) | 60.60 / 563.59 → 0.00 / 0.01 | 62.45 / 452.05 → 0.00 / 0.01 | 61.50 / 411.08 → 0.00 / 0.01 |
| Published Drik fasting dates (232) | | 90.52% → 99.57% | |
| Published Drik Parana, Delhi 2027 (48 limits) | | 40.48% → 100.00% (mean 104.80 → 0.28 min) | |
| Gaudiya fasting date (GCAL) | 99.94% → 99.92% | 100.00% → 100.00% | 99.86% → 100.00% |
| Gaudiya Parana within 2 minutes (GCAL decision, JPL timing) | 100.00% → 100.00% | 100.00% → 100.00% | 100.00% → 100.00% |
| Gaudiya Parana, displayed minute | 94.53% → 99.94% | 94.86% → 99.93% | 92.81% → 99.79% |
| Gaudiya Parana mean / max error (min) | 0.07 / 1.90 → 0.00 / 2.42 | 0.07 / 1.90 → 0.00 / 1.92 | 0.07 / 1.09 → 0.00 / 0.72 |
| ISKCON Bangalore published calendar, Mar 2026-Mar 2027 (26 fasts) | | 26/26 → 26/26 | |

The two "displayed minute" Parana rows were added for this comparison and
count in the overall score; they lower the earlier "before" totals
(worldwide 89.96% → 88.85%, 16 cities 90.01% → 88.93%, held-out 91.44% →
90.05%) and leave the "after" totals unchanged.

**Smarta** needed new rules. The old engine always fasted on the first
day with Ekadashi at sunrise (and on the Dwadashi day when Ekadashi touched
no sunrise), and ended Parana at the first third of the day. That gave the
wrong day for about one fast in five (Prabodhini 2026 among them) and a
Parana window about an hour off on average. The rules now follow Drik's
published practice (see "What changed").

**Vaishnava** needed no rule changes. The Gaudiya logic was checked line by
line against GCAL, the program ISKCON calendars are generated with (the
`EkadasiCalc`, `MahadvadasiCalc` and `CalculateEParana` routines of the
`gaurabda` port and the decision tables in GCAL's
*Vaisnava Calculation* notes): Arunodaya (96 minutes before sunrise)
Dashami-viddha shifts, Unmilani, Vyanjuli, Trisprisha, Pakshavardhini and
the nakshatra Mahadvadashis (Jaya, Jayanti, Papanashini, Vijaya), and the
seven Parana cases (sunrise, Ekadashi end, Hari Vasara, nakshatra end,
first third of the day). Where GCAL's notes and program differ, the engine
follows the program: nakshatra Mahadvadashis also need Dvadashi at sunset.
The independent ISKCON Bangalore calendar
(https://www.iskconbangalore.org/ekadashi-calendar/) agrees on all 26 dates
before and after, including its five special cases: Viddha 11 July 2026,
Vyanjuli Mahadvadashi 24 August 2026, Trisprisha 21 November 2026 and
19 January 2027, Unmilani 4 March 2027. This is now a unit test
(`panchang_accuracy_test.dart`). The unmodified GCAL port gets 25/26: its
`IsMhd58` returns a sentinel (256) that makes it fast on 23 August; the
corrected port, like the engine, gives 24 August.

Vaishnava gains come from the astronomy. Arunodaya, sunrise and the tithi
and nakshatra end times that decide the Gaudiya fast and Parana are now
within seconds of JPL, so the Parana shown (h:mm) matches the
GCAL decision timed with JPL 99.94% of the time instead of 94.53%. GCAL's own
times differ from JPL by up to about 2.5 minutes, so the agreement with
GCAL's raw Parana times within 2 minutes fell from 99.99% to 98.28%; that
is GCAL's error, not the engine's, which is why its decisions are scored
with JPL times. The worldwide date rate moved from 99.94% to 99.92% (7
fasts of about 8,600): each depends on a tithi boundary 0.2-2.4 minutes
from a sunrise or Arunodaya, where GCAL decides with its own clock. The
one Parana limit more than 2 minutes out (Pitcairn, 14 April 2026) is the
same kind: GCAL ends Parana at the first third of the day because its
Dwadashi ends later, while with JPL times Dwadashi ends 2.4 minutes before
the third, so GCAL's own rule (the earlier of the two) gives the engine's
time. The engine was not tuned to reproduce GCAL's astronomy.

## Worldwide robustness (396 locations, every time zone)

The engine is meant for devotees anywhere, so the harness was scaled from 16
cities to 396 locations: one in each of the 356 IANA time zones in the
bundled GeoNames catalogue, the original 16 cities, and 24 deliberate edge
cases: polar day and night (Longyearbyen 78°N, Utqiagvik, Tromso, Murmansk,
Fairbanks, Reykjavik, McMurdo 78°S), the date line (Kiritimati UTC+14, Apia,
Pago Pago UTC-11, Tarawa, Suva), quarter- and half-hour zones (Chatham
+12:45 with DST, Eucla +8:45, Marquesas -9:30, St John's, Tehran, Kabul,
Yangon, Adelaide), Lord Howe's 30-minute DST, Ushuaia and Mayapur. Every
civil day of 2026-2027 in each location's own zone: 6,845,233 checks.

| Check | Before | After | Error before → after (mean / max, min) |
|---|---:|---:|---|
| Sunrise | 99.99% | 100.00% | 0.03 / 3.00 → 0.00 / 0.01 |
| Sunrise (displayed minute) | 96.96% | 100.00% |  |
| Sunset | 99.99% | 100.00% | 0.07 / 3.07 → 0.00 / 0.01 |
| Sunset (displayed minute) | 92.67% | 100.00% |  |
| Moonrise | 99.93% | 100.00% | 0.08 / 1415.38 → 0.00 / 0.05 |
| Moonrise (displayed minute) | 92.64% | 99.98% |  |
| Moonset | 99.92% | 100.00% | 0.10 / 7.21 → 0.00 / 0.05 |
| Moonset (displayed minute) | 90.47% | 99.98% |  |
| Tithi at sunrise | 99.98% | 100.00% |  |
| Tithi end time | 96.79% | 100.00% | 0.32 / 1.30 → 0.00 / 0.02 |
| Tithi end (displayed minute) | 71.84% | 99.86% |  |
| Nakshatra at sunrise | 99.99% | 100.00% |  |
| Nakshatra end time | 100.00% | 100.00% | 0.15 / 0.36 → 0.00 / 0.02 |
| Nakshatra end (displayed minute) | 84.54% | 99.87% |  |
| Yoga at sunrise | 99.96% | 100.00% |  |
| Yoga end time | 94.73% | 100.00% | 0.48 / 1.30 → 0.00 / 0.02 |
| Yoga end (displayed minute) | 53.06% | 99.74% |  |
| Karana at sunrise | 99.96% | 100.00% |  |
| Karana end time | 96.74% | 100.00% | 0.32 / 1.30 → 0.00 / 0.02 |
| Karana end (displayed minute) | 70.55% | 99.74% |  |
| Lunar month (Amanta, Adhika) | 100.00% | 100.00% |  |
| Sun rashi | 99.99% | 100.00% |  |
| Moon rashi | 99.99% | 100.00% |  |
| Sankranti day | 94.48% | 100.00% |  |
| Smarta Ekadashi date (all cities, Drik rules) | 79.40% | 100.00% |  |
| Smarta Parana (all cities) | 47.99% | 100.00% | 60.60 / 563.59 → 0.00 / 0.01 |
| Smarta Parana (displayed minute) | 45.61% | 99.99% |  |
| Gaudiya Ekadashi date (GCAL) | 99.94% | 99.92% |  |
| Gaudiya Parana (GCAL rule, JPL timing) | 100.00% | 100.00% | 0.07 / 1.90 → 0.00 / 2.42 |
| Gaudiya Parana (displayed minute) | 94.53% | 99.94% |  |
| Published Ekadashi date (Drik data) | 90.52% | 99.57% |  |
| Published Ekadashi name | 100.00% | 100.00% |  |
| Published Parana (Drik, Delhi 2027) | 40.48% | 100.00% | 104.80 / 390.91 → 0.28 / 1.21 |
| Festival dates (India, public lists) | 74.47% | 100.00% |  |
| Festival lunar month/tithi (all cities) | 100.00% | 100.00% |  |
| Festival occurs once per year (all cities) | 90.65% | 100.00% |  |
| **Overall (mean of categories)** | **88.85%** | **99.96%** | |
| Overall (all 6,845,233 checks pooled) | 92.65% | 99.96% | |


Found and fixed at world scale (failing tests first):

- **Outdated time zone data.** The timezone package bundles IANA 2025b
  (its newest release has 2025c). IANA 2026b records that British Columbia
  stays on UTC-7 from 1 November 2026, so every Panchang time and Ekadashi
  reminder in BC would have been an hour off from that date. The app now
  ships IANA 2026b, built from the signed release with the package's own
  encoder (`tool/time_zones/update.sh`), used by Panchang, the reminder
  scheduler and the splash screen alike. Rerun the script for future IANA
  releases (Alberta and the Northwest Territories are expected next).
- **Sunset after local midnight.** In Reykjavik in mid-June the Sun sets at
  00:00:52; the engine found no sunset in the civil day and dropped the
  sunset-based periods. The solar day's sunset is now searched after its
  sunrise.
- **Polar days.** The Sankranti moment is reported even without sunrise or
  sunset; Smarta fasts are recommended only when sunrises exist from two days
  before to three days after (otherwise none is offered, never a guess).
- Positions stay accurate across the date picker's whole range: worst Sun
  0.34″ and Moon 0.66″ in each 50-year band from 1900 to 2100 (the old
  engine reached 35″ and 72″); Delta T is now tabulated through 2100.

Reference corrections, applied to every engine version: rise/set are solved
exactly on Swiss Ephemeris positions (`swe_rise_trans` stops up to 13″ short
when the Sun grazes the horizon, 8 seconds at 65°N); the reference sunset is
the one after sunrise; events seconds after midnight are not skipped.

Listed, not scored (same rules for both versions): 6 locations where GCAL
dates by longitude across the date line (its dates there are one day early
for all 49 fasts, while the engine matches the Swiss Ephemeris reference);
GCAL days whose decision rests on a tithi ending within 2 minutes of sunrise
or Arunodaya, where GCAL's own ~2.5-minute tithi error decides; 8
self-contradictory published rows. The 7 Gaudiya dates still scored as
disagreements (of about 8,600 fasts) all have a deciding tithi boundary
within 0.2-2.4 minutes of a sunrise or Arunodaya, mostly in the
Pakshavardhini full-moon test.

## Results, 2026-2027 (first 16 cities)

| Check | baseline | final | Error before → after (mean / max, min) |
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
| Smarta Parana (displayed minute) | 46.27% | 100.00% |  |
| Gaudiya Ekadashi date (GCAL) | 100.00% | 100.00% |  |
| Gaudiya Parana (GCAL rule, JPL timing) | 100.00% | 100.00% | 0.07 / 1.90 → 0.00 / 1.92 |
| Gaudiya Parana (displayed minute) | 94.86% | 99.93% |  |
| Published Ekadashi date (Drik data) | 90.52% | 99.57% |  |
| Published Ekadashi name | 100.00% | 100.00% |  |
| Published Parana (Drik, Delhi 2027) | 40.48% | 100.00% | 104.80 / 390.91 → 0.28 / 1.21 |
| Festival dates (India, public lists) | 74.47% | 100.00% |  |
| Festival lunar month/tithi (all cities) | 100.00% | 100.00% |  |
| Festival occurs once per year (all cities) | 88.54% | 100.00% |  |
| **Overall (mean of categories)** | **88.93%** | **99.97%** | |
| Overall (all 277,808 checks pooled) | 92.80% | 99.97% | |

Held-out check, 2029-2030, not used for any tuning: **90.05% → 99.92%**
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
