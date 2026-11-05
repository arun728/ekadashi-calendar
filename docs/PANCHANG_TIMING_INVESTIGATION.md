# Panchang timing investigation — 24 October 2026

Research baseline: `dev` commit `c48ac07f9a27713d01b0698851d11b37f1672b69`,
on isolated branch `fix/panchang-drik-accuracy`.

The question is whether the engine has a timing error across locations, not
whether fasting dates can be made to agree with another calendar. The findings below were recorded before changing production behavior. The
subsequent timezone fix is described separately; astronomical formulas,
observance rules, display policy and published calendar data remain unchanged.

## Findings before a fix

There are at least two distinct reasons for a displayed one-minute discrepancy.
They must not be combined into a one-minute correction to the astronomy.

1. **Our display discards seconds.** For example, at Drik's Chennai coordinates,
   the Vaishnava Parana endpoint on 30 January 2026 is
   `10:26:37.274` IST. Our display says `10:26`; Drik says `10:27`.
   The latter is consistent with rounding to the nearest minute. This is a
   display-policy difference, not a 60-second error in the calculated endpoint.
   Repository instructions deliberately require truncation. Changing that
   policy would affect display and cached schedules, not improve astronomy.
2. **Some underlying astronomical timestamps differ.** For example, the
   Ekadashi tithi ends on 22 October 2026 at `14:48:35.446` IST in our engine
   and `14:48:35.747` in the independent Swiss Ephemeris calculation. Drik
   publishes `14:47`. Rounding our result cannot produce that time. The
   available evidence supports our raw astronomical result in this example.

Across all 98 published Ekadashi start/end boundaries in 2026–2027, our
calculated instants are 38.611–100.005 seconds later than the start of Drik's
published minute (mean 67.264 seconds). These are comparisons with minute-only
labels, **not measured second-level errors in Drik's private calculations**.
Our same 98 boundaries differ from Swiss Ephemeris by at most 0.933 seconds.
Nearest-minute rounding of our unmodified instants matches none of those 98
Drik tithi labels, so a display-only change cannot explain all discrepancies.

For the 98 observed Vaishnava Parana endpoints, truncation matches 40 of Drik's
minute labels and nearest-minute rounding matches 77. Endpoints controlled by
tithi endings or Hari Vasara also inherit the underlying lunar-timing
difference. These observations are diagnostic; they are not a date-parity gate
or a proposal to replace our rules with Drik's dates.

## Independent engine measurement

The **unchanged engine** was evaluated on every civil day of 2026 and 2027 in
16 locations: New Delhi, Mumbai, Chennai, Kolkata, Ujjain, Kathmandu, Dubai,
Singapore, London, Johannesburg, New York, Chicago, Denver, Los Angeles,
Sydney and Auckland. Each calculation used that location's coordinates and
IANA timezone, including DST.

Reference: Swiss Ephemeris 2.10.03, using the official `sepl_18.se1` and
`semo_18.se1` data files. The reference solves rise/set on Swiss positions
with the same explicitly stated sea-level, apparent-upper-limb convention.
It does not call our Sun, Moon or event-solving implementation.

11,680 city-days, with no mismatches in event availability or limb indices:

| Raw UTC event | Compared events | Mean absolute error | Maximum absolute error |
|---|---:|---:|---:|
| Sunrise | 11,680 | 0.002 s | 0.009 s |
| Sunset | 11,680 | 0.002 s | 0.008 s |
| Moonrise | 11,280 | 0.012 s | 0.088 s |
| Moonset | 11,296 | 0.011 s | 0.078 s |
| Tithi ending | 11,680 | 0.192 s | 0.933 s |
| Nakshatra ending | 11,680 | 0.187 s | 1.028 s |
| Yoga ending | 11,680 | 0.222 s | 1.068 s |
| Karana ending | 11,680 | 0.192 s | 0.977 s |

Machine-readable results: [independent metrics](research/independent_timing_metrics_2026_2027.json).

Two disputed tithi endpoints were additionally solved using **NASA JPL DE440s**
through Skyfield, with UTC converted independently to TT:

| Date | Our engine (IST) | Swiss (IST) | JPL DE440s (IST) | Drik published |
|---|---|---|---|---|
| 14 Jan 2026 | 17:53:15.946 | 17:53:15.930 | 17:53:15.647 | 17:52 |
| 22 Oct 2026 | 14:48:35.446 | 14:48:35.747 | 14:48:35.383 | 14:47 |

This independently supports the engine's timing rather than a one-minute
shift. Swiss and JPL differ by fractions of a second here, including their
UTC/UT1 handling. [JPL cross-check data](research/jpl_tithi_cross_check.json).

The existing independent position harness was also run at 400 deterministic
random instants spanning 1900–2100, including 2100, with seed 7:

| Quantity | Mean absolute difference | Maximum absolute difference |
|---|---:|---:|
| Apparent Sun longitude | 0.145 arcsec | 0.355 arcsec |
| Apparent Moon longitude | 0.112 arcsec | 0.531 arcsec |
| Apparent Lahiri ayanamsa | 0.006 arcsec | 0.018 arcsec |

These are measurements of those samples, not a proof of an error bound at
every possible instant, coordinate, horizon or future timezone rule.

## What was checked in the implementations

- Dart: `lib/services/panchang/astronomy_calculator.dart` and
  `panchang_engine.dart`; Swift: the corresponding files under
  `ios-native/EkadashiCore/Sources/EkadashiCore/Panchang/`.
- Sun: VSOP87D, FK5 correction, aberration and IAU 1980 nutation. Moon:
  ELP 2000-82B with light time and the existing DE431 secular refit.
- Terrestrial time receives Delta T once; Earth rotation uses universal time.
  The table contains 201 entries for 1900–2100. Its values were checked
  against Swiss Ephemeris; misleading decade comments are not shifted data.
- Rise/set uses topocentric parallax, actual semidiameter and 0.5599-degree
  standard horizon refraction. The solver refines each bracket; the five-minute
  search spacing is not the precision of the returned event.
- The city's IANA timezone, rather than the device timezone, determines civil
  days and the final wall-clock representation.
- Smarta and Gaudiya/ISKCON Parana depend on different morning windows and
  special-case rules. A difference between those profiles is not an ephemeris
  error. The common tithi calculation is independent of location and tradition;
  rise/set and the choice of observance window depend on location.
- Both `PanchangFormat` and the schedule serialization discard seconds. The
  schedule cache intentionally stores minute precision. A display change would
  require matching changes and tests in both platforms and a cache review.

## Drik reference settings and observations

Chennai was confirmed as the user's comparison location. Drik's location UI
showed approximately `13.08784 N, 80.27847 E`, timezone `Asia/Kolkata`.
The focused comparison used those coordinates, rather than our older static
Chennai constant (`13.0827, 80.2707`). The coordinate difference moves solar
events by seconds and can matter when displaying only whole minutes.

Drik's current settings page explicitly states that the default sunrise is the
**top edge**, and default elevation is **zero**. This agrees with the engine's
intended convention. Its older FAQ describes middle-limb, unrefracted Hindu
sunrise; that FAQ must not be used to infer the current default site settings.

The planetary-position page was also checked at **14 January 2026, 12:00:00
IST**, using tropical coordinates to remove ayanamsa as a confounder:

| Body | Drik displayed tropical longitude | Swiss apparent tropical longitude | Drik minus Swiss |
|---|---|---|---:|
| Sun | 294°05′27.05″ | 294.089991639° | +3.080 arcsec |
| Moon | 243°26′10.71″ | 243.427206975° | +32.765 arcsec |

Thus there is a difference in the reference's displayed planetary positions as
well as in its minute labels. A roughly one-Delta-T time displacement is one
possible hypothesis: subtracting about 67–69 seconds from our boundaries and
then rounding reproduces 96 of the 98 tithi labels. **That is a diagnostic
experiment, not proof that Drik applies Delta T twice, and not a legitimate
correction to apply to our engine.** Its proprietary implementation was not
available for inspection. A constant calibration would also be inappropriate
over 1900–2100, when Delta T changes substantially.

Public observations are preserved separately from shipping calendar data:
[49 timing rows](research/drik_chennai_timing_observations.csv) and
[196 endpoint comparisons](research/drik_chennai_timing_analysis.json).
The alignment date in the CSV only identifies the observed row; date matching
is not the objective of this investigation.

Further direct Drik browsing encountered its human-verification page. No
challenge was bypassed. The recorded values above were read before that
interruption; independent local measurements continued.

Sources:

- [Drik settings](https://www.drikpanchang.com/settings/drikpanchang-settings.html)
- [Drik sunrise FAQ](https://www.drikpanchang.com/faq/faq-ans2.html)
- [2026 Chennai reference](https://www.drikpanchang.com/iskcon/iskcon-ekadashi-list.html?geoname-id=1264527&year=2026)
- [2027 Chennai reference](https://www.drikpanchang.com/iskcon/iskcon-ekadashi-list.html?geoname-id=1264527&year=2027)
- [Fixed-instant tropical positions](https://www.drikpanchang.com/planet/position/planetary-positions-tropical.html?date=14/01/2026&time=12:00:00)
- [Swiss Ephemeris API: UT versus TT](https://www.astro.com/swisseph/swephprg.htm)
- [Official Swiss ephemeris files](https://github.com/aloistr/swisseph/tree/master/ephe)
- [JPL time-scale definitions and future UTC limitations](https://ssd.jpl.nasa.gov/horizons/manual.html)

## Confirmed worldwide defects and the scoped fix

The wider 396-location sweep at equinoxes/solstices in 1900, 1950, 2000,
2026, 2027, 2050 and 2100 exposed a **different, actual engine-input defect**:

- The original TZif files contained recurring future DST as a POSIX footer,
  but the shipping TZF format has no such footer. Without explicitly expanding
  it, London, New York, Oslo and many other zones stop changing clocks in 2037.
  Summer 2050/2100 is then displayed with a winter offset, one hour wrong.
- `filterTimeZoneData` in the timezone package replaces the first transition
  with a sentinel at the minimum representable date, using the *post-transition*
  offset. With unbounded TZif input this erases the earlier historical offset.
  For example, in 1900 the original data gives Luanda UTC instead of +00:13:35,
  and Detroit -06:00 instead of -05:32:11, under the pinned IANA definitions.
- These mistakes affect local wall-clock labels, civil-day boundaries and
  event availability around midnight. A polar no-sunrise sample at local
  06:00 can even get the wrong tithi: Tromso on 21 June 2100 sampled an hour
  late (tithi 15 instead of 14).

The fix compiles explicit TZif transitions from **1899-01-01 through
2102-01-01 exclusive**, before using the existing TZF encoder. The lower
cutoff supplies an explicit correct initial offset; the upper cutoff forces
recurring rules to be materialized instead of relying on an unrepresented
footer. The padding covers neighbouring-day calculations at both ends of
1900–2100. Both apps consume the same resulting database. Schedule cache
version 2 is retired so cached wall-clock results are recalculated.

This projects **IANA 2026b's published rules**, not knowledge of future changes
in law. The data still needs updating when IANA publishes rule changes.

TDD evidence: the new iOS regressions failed first with 22 assertions,
including **20,769 wrong offsets among 240,396 comparisons** (598 zones ×
402 January/July samples across every year from 1900 to 2100). Historical,
post-2037 DST, polar sampling and old-cache regressions all failed before
implementation. The build-helper regression also failed before the helper
existed. With the corrected iOS data, all five new iOS tests and both helper
tests pass. The corrected iOS binary additionally passed **131,760 transition
boundary checks** (one second before and at each transition through 2101).
All 62 affected city-days from the wider astronomical sweep were recomputed
with the iOS engine: event-availability mismatches fell from 53 to 0, limb-index
mismatches from 8 to 0, and the four wrong-day rise/set selections disappeared.
See [transition validation](research/timezone_transition_validation.json),
[world sweep before](research/world_range_before.json), and
[iOS recheck](research/world_range_ios_recheck.json).

Final local iOS validation: **257 Swift tests passed**, including the five new
regressions; both timezone compiler tests passed. Before production changes,
the full Flutter baseline had **725 passing tests and one existing failure**
in `home_details_ios_parity_test.dart` (its style lookup uses published
timings while Home displays calculated timings). Flutter analysis passed
with no issues. The complete Python tool suite also encountered ten existing
Android-driver checks that need GNU `timeout`, which is not installed on this
Mac; the two new compiler tests run successfully without it.

The iOS implementation is committed locally as `ad4491a`, following the separate
failing-test commit `aa2eb1a`. Flutter data and schedule cache have **not yet
been changed**. Repository instructions require pushing iOS before starting
the Flutter port. Automatic approval review rejected that feature-branch push
because publishing to GitHub was not explicitly authorized. The user has been
asked to choose between approving the isolated push/draft PR and overriding
the push requirement to finish both fixes locally. No remote changes, CI runs
or merges were performed.

The fixture was produced independently with Python `ZoneInfo` reading official
IANA TZif files, not either app's timezone reader. Its metadata records the
source archive SHA-256. The IANA archive's detached signature was verified
against the generator's pinned 4096-bit RSA key fingerprint
`7E3792A9D8ACF7D633BC1588ED97E90E62AA7E34` before producing shipping data.

## Fix criterion and TDD

The existing accuracy score allowed one minute for astronomical events and two
minutes for Parana; its high percentage was not a claim of exact displayed
minute parity with Drik. The advertised standalone Dart exporter also now pulls
in Flutter through `PanchangCity` localization; the research export was run
under Flutter's test runtime rather than treating a failed standalone compile
as an astronomical failure.

No astronomical-formula fix is justified solely by the observed disagreement with Drik.
First reproduce an actual engine defect against an independent reference with
the same inputs and conventions. Write and run a failing regression for that
defect before changing the implementation. Then validate the shared primitive
across locations and years, both traditions where applicable, platform parity,
and the existing complete test suites. Do not add date, city or year-specific
offsets to force a reference match.
