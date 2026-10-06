# Worldwide Panchang and fasting rules

Extension of PR #11 on `feature/panchang-location-details`, created from
`feature/panchang-engine`. The October 5 user instructions supersede the
first-release IST/eight-city restriction. The engine remains offline, now takes
an explicit civil date, coordinates and IANA timezone, and supports both
Smarta and Gaudiya/ISKCON fasting profiles. 2026 and 2027 are validation targets;
there is no year-specific daily-data download.

## What the comparison apps actually document

- Drik Panchang's official Android and iOS listings explicitly describe a native
  app that does not need internet connectivity, worldwide locations and automatic
  DST. They list detailed daily Panchang, auspicious yogas, Choghadiya, Hora,
  Udaya Lagna, festival calendars, birth charts and horoscope matching.
  Sources: https://play.google.com/store/apps/details?id=com.drikp.core&hl=en-US
  and https://apps.apple.com/us/app/hindu-calendar-drik-panchang/id1321271821.
  The exact proprietary ephemeris backend was not verified. Do not describe
  this implementation as using their private algorithm or guaranteeing identical
  output. No daily data, text or assets were scraped for this extension.
- Abhay Charan das's official listing is `com.acd.ekadashi`:
  https://play.google.com/store/apps/details?id=com.acd.ekadashi&hl=en.
  His documentation at https://ekadashireminder.blogspot.com/ describes Smarta
  sunrise and Vaishnava Arunodaya (96 minutes before sunrise), current-location
  and Mayapur-based modes, and comparison with GCAL 11. A separate post argues
  for a "celestial horizon" convention. That is an author-described convention,
  not a universal definition adopted silently here. Our profiles use the actual
  selected location and apparent upper-limb sunrise; no Mayapur override.
- Public Gaudiya reference: https://github.com/gopa810/gaurabda-calendar,
  especially `TCalendar.py` methods `MahadvadasiCalc`, `EkadasiCalc`,
  `CalculateEParana`, `IsMhd58`. The decision conditions were cross-reviewed
  while implementing a separate Dart rule layer. Preserve the MIT attribution
  in [GAURABDA_LICENSE.txt](references/GAURABDA_LICENSE.txt).
  This Python port is a useful comparison, not proof of every temple's practice.

## Calculation choices and numerical checks

Superseded by docs/PANCHANG_ACCURACY.md (VSOP87 Sun, ELP 2000-82B Moon,
IAU nutation, tabulated Delta T, Drik-validated Smarta rules and kala-based
festival rules). The paragraphs below describe the earlier implementation.
The inherited Meeus Sun/Moon series remain independently implemented. Orbital
formulas now receive terrestrial time, using the NASA/Espenak–Meeus Delta T
polynomials (UTC approximates UT1 to sub-second accuracy); Earth rotation still
uses UT. Source: https://eclipse.gsfc.nasa.gov/SEcat5/deltatpoly.html.
Lahiri uses the inherited J2000 plus precession approximation. Apparent Sun/Moon
positions are converted with a nutation-consistent apparent ayanamsa; the
displayed mean value and mean-horizon Lagna geometry remain explicitly distinct.
A 2027 Vijaya Mahadvadashi boundary fixture detects the former equinox mismatch.
No native
Swiss library or proprietary daily data is shipped in the app.

Independent geocentric apparent tropical Sun/Moon fixtures were generated using
Swiss Ephemeris 2.10.03 / Moshier for the first day of every month in 2026–2027.
Tests permit 0.01° solar and 0.003° lunar disagreement, rather than promising
second-level ephemeris accuracy. Ascendant geometry is checked at three 2027
locations/instants against independent house-angle fixtures (0.02° tolerance).
These tolerances are fixture checks, not global maximum-error guarantees.
Swiss Ephemeris is only a development comparator, not a runtime dependency.

Rise/set uses a level horizon and a nominal -0.833° apparent upper-limb event;
lunar altitude already includes parallax, so the previous additional positive
horizon threshold was corrected. USNO New York 2026-10-04 independently supplies
06:56 sunrise, 18:33 sunset, 15:30 moonset, and no moonrise, UTC-4. The Delhi
fixture from PR #11 remains. Terrain, elevation and weather are not modelled.
Source: https://aa.usno.navy.mil/api/rstt/oneday?date=2026-10-04&coords=40.7128,-74.006&tz=-4.

Civil boundaries are constructed in the selected zone, not by adding 24 hours.
Tests cover 23/25-hour New York dates, a 24.5-hour Lord Howe date, the date line,
no-rise polar days and solar days whose sunset is after midnight. No synthetic
sunrise is used for a muhurta or fasting recommendation. On no-sunrise days only,
limbs are explicitly labelled as a 06:00 local sample. Lagna intervals are
withheld at absolute latitude >=66° because the rising-sign sequence need not
be monotonic there.

## Traditional daily rules

Rahu, Yamaganda and Gulika use weekday-selected eighths of daylight; the inherited
Sunday-indexed arrays are corrected for Dart's Monday-first weekday. Choghadiya
has distinct day and night sequences. Hora uses the Chaldean planetary sequence,
starting with the weekday ruler and dividing actual day/night into twelve each.
Abhijit is the central fifteenth of daylight, omitted on Wednesday. Brahma
Muhurta uses the fixed 96–48 minutes before sunrise convention. Dur Muhurta uses
the weekday fifteenths, including Tuesday night and the first two on Saturday.

Varjyam and Amrit Kalam use the traditional nakshatra ghati offsets, scaled by
the actual nakshatra duration; Mula has two Varjyam windows. Displayed intervals
are clipped to the sunrise-to-next-sunrise day. The traditional table values
were cross-checked against the publicly inspectable PyJHora tables, which cite
Karanam Ramakumar's *Panchangam Calculations* for Dur Muhurta:
https://github.com/naturalstupid/PyJHora/blob/main/src/jhora/const.py and
https://github.com/naturalstupid/PyJHora/blob/main/src/jhora/panchanga/drik.py.
No PyJHora implementation is included. Table conventions can differ by region;
this is an explicit profile, not a universal auspiciousness claim.

Special yoga labels are **at sunrise**, not falsely marked as all-day: Panchaka,
Ganda Moola, Bhadra, Vinchudo, Sarvartha Siddhi, Amrita Siddhi, Ravi, Ravi Pushya,
Guru Pushya, Dwipushkara and Tripushkara. Bhadra changes remain visible in the
Karana timeline. Anandadi uses the 28-star cycle including Abhijit. Ritu is based
on lunar months; Ayana is explicitly tropical. Shaka and Vikrama use a Chaitra
new-year convention; Gujarati/Kartika and regional solar eras are not implied.
Adhika months are detected by absence of solar ingress between conjunctions;
annual starter rules are not applied as though that month were ordinary.
Rare Kshaya month/year conventions require further reference work.

## Ekadashi profiles and replacement path

`CalculatedEkadashiEngine` is deliberately separate from the published model,
IDs, tracker, notification scheduler and widgets. It returns UTC instants, local
fast/parana dates, tradition, rule identifier, tithi interval, Hari Vasara and a
near-boundary flag. It searches neighbouring days across month/year boundaries.

- Smarta householders: Drik Panchang's rules, validated against all 24
  published Delhi 2027 fasts and Parana windows (see PANCHANG_ACCURACY.md).
  This is not the renunciate profile.
- Gaudiya/ISKCON: Arunodaya contamination, repeated Ekadashi (Unmilani), extended
  Dwadashi (Vyanjuli), skipped Dwadashi (Trisprisha and combined case), repeated
  next full/new moon (Pakshavardhini), and Jaya/Jayanti/Papanashini/Vijaya
  nakshatra Mahadvadashis. Parana considers the applicable tithi, nakshatra,
  Hari Vasara and one-third-day limits. If the calculated start exceeds the
  morning end, the result is shown as after-only, never as an inverted window.

The public Python port has a reproducible sentinel inconsistency: `IsMhd58`
returns `EV_NULL == 256` for no match, but `MahadvadasiCalc` tests `!= 0`.
On qualifying bright Dwadashis this can bypass Vyanjuli/Pakshavardhini. Raw
fixtures are retained unchanged. A separate diagnostic replacing **only** the
no-match return with zero explains Delhi differences on 2026-06-25/26,
2026-08-23/24 and 2027-06-14/15. Do not hide those differences, edit raw fixtures,
or claim this is a verified defect in Abhay's proprietary app or Drik Panchang.
See `tool/compare_panchang_reference.py` for a reproducible diagnostic.

The production replacement gate is still closed: first establish reviewed
tradition/horizon settings, validate a wider range of locations and rare cases,
resolve every discrepancy, and test ID/history/reminder migration. Current
calculated schedules are visibly marked as previews. Existing published
Ekadashi fast/parana dates remain authoritative in Today, Calendar and Vrat.

## Feature parity tracking

Implemented in this extension:

- Global offline city search, custom coordinates, opt-in GPS, saved location,
  IANA DST, correct civil-date bounds and after-midnight markers.
- Daily, Muhurta, Ekadashi and Rashi subtabs under Panchang.
- Five limbs and their next-sunrise timelines; Sun/Moon rise/set; month labels,
  Adhika detection, era/season labels; Sun/Moon rashis and transitions, pada,
  ayanamsa; traditional daily periods, yogas, Choghadiya, Hora and Udaya Lagna.
- Separate Smarta and Gaudiya/ISKCON calculated fasting and Parana previews.
- More tab with a location-based festival finder, tradition/calculation guides
  and source attribution; existing Calendar is retained rather than duplicated.

Not yet equivalent to the full Drik product: exhaustive regional/sect festival
registries and tie-breaks, regional solar calendars, special-yoga interval
intersection for every yoga, personal Janma Rashi/Kundali/divisional charts,
horoscope matching, eclipse contacts/visibility, comprehensive dedicated-event
muhurta search and all languages. These are visible limits, not guessed values
or placeholder claims. Full product parity and "more accurate than every other
app" cannot be inferred from the current test suite.
