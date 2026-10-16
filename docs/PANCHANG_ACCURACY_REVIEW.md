# Panchang accuracy audit and implemented improvements

Audit date: 15 October 2026. Source: `feature/engine-ekadashi` at
`c15bce71a753d0ca36da5b704d6edc3f106a6919`. Implementation branch:
`feature/panchang-accuracy-boundaries`, created directly from that source.
PR target: **dev**, as most recently requested. No merge or CI run is part of this audit.
The source feature branch is 56 commits ahead of the fetched dev base; the PR
therefore includes its inherited feature work. Audit changes are the commits
after c15bce7, which reviewers can also compare separately.

## What the accuracy numbers mean

The source already has very good astronomical positions. It does **not** have
100% demonstrated accuracy across the full Panchang product. A percentage from
a selected test suite cannot establish that claim. This audit found real,
user-visible errors that the previous percentage did not measure, and fixes them
in both calculation implementations and their Home/widget consumers.

The previous report's **99.96% worldwide** describes its 396-location benchmark.
That entire historical run was not repeated here. This audit independently
reran the existing comparison for **41 locations**, scoring **29,930 city-days**
in 2026–2027, using padded calculation ranges of 790 days per location.
There are **700,242 original checks**: 277,808 for the original 16 cities and
422,434 for 25 edge locations. Those include polar regions, southern latitudes,
DST, fractional offsets and the international date line.

Across all 41 audited locations, the expanded 37-category average is
**99.5810% before → 99.9662% after**, with **728,492 checks**.
This is a measured improvement under the expanded test definition.

The table below separates identical-test comparisons from newly measured fields.
Scores are pass rates at explicit tolerances, not a probability that every
answer the app gives is correct.

| Measured aspect | Source branch | Implemented branch |
|---|---:|---:|
| Original 16-city benchmark, same 277,808 checks | 99.97% | 99.97% |
| 25-edge-location benchmark, same 422,434 checks | 99.97% | 99.97% |
| Expanded 16-city average, adds Anandadi (37 categories) | 99.5818% | 99.9668% |
| Expanded edge-location average, adds Anandadi (33 categories) | 99.5421% | 99.9740% |
| Anandadi labels, 16 cities, 11,680 sunrise samples | 85.7534% | 100.0000% |
| Anandadi labels, edge cities, 16,570 sunrise samples | 85.7453% | 100.0000% |
| Lagna mean / maximum angular error, 1,000 samples | 12.425″ / 51.330″ | 0.04846″ / 0.70187″ |
| Stored starts early by more than 1 ms, 2,960 fixture boundaries | 2,960 | 0 (inward serialization) |

The new Anandadi sweep excludes 1,680 edge-city days without actual sunrise.
Expanded pooled scores are 99.3951% → 99.9699% (16 cities) and
99.4339% → 99.9720% (edge cities).
The original mean's unchanged rounding is expected: it never scored Anandadi,
Lagna geometry or schedule serialization.

Raw category counts, errors and exclusions are in
[`review/panchang-accuracy`](review/panchang-accuracy/). The existing score is an
unweighted mean of category pass rates; pooled checks are reported separately.
An expanded average adds exactly one equally weighted category, independently
scored Anandadi labels at actual sunrise. It does not add schedule regression
assertions or angular samples to a mixed denominator. Neither average certifies
unmeasured features.

## Comparison with recognized reference systems

There is no independently established league table of the “top Panchang engines.”
The useful comparison is against astronomical authorities and established
religious calendars, with the comparison's scope recorded.

| Reference | Work actually performed | Limits |
|---|---|---|
| [Swiss Ephemeris 2.10.03](https://www.astro.com/swisseph/swisseph.htm), [primary source and ephemeris files](https://github.com/aloistr/swisseph) | Recomputed rise/set, limbs, month, rashis, ingress and reference-rule Ekadashi checks; 10,000 random positional samples; 1,000 independent ascendants | SWIEPH flags checked in the random-position audit to prevent silent Moshier fallback. Reference rules still need independent religious authority |
| [JPL DE440s](https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de440s.bsp) via Skyfield | 10,000 geocentric apparent Sun/Moon samples over 1900–2100 | Matched the engine's TT explicitly to isolate orbital-model accuracy; this does not independently certify UTC-to-TT or future ΔT |
| [GCAL/Gaurabda](https://github.com/gopa810/gaurabda-calendar), Python port 0.8.4 | Existing raw and corrected GCAL references, fasting dates and named Parana decisions; read calculation routines and Hari Vasara time-quarter calculation | The corrected port is not the official Windows executable. Raw GCAL timing and Swiss retiming are different comparisons; polar/date-line/knife-edge exclusions remain visible |
| [Official GCAL Windows source](https://github.com/gopaladasa/GCAL-for-Windows), [calculation notes](https://gopal.home.sk/gcal/docs/GCalVaisnavaCalculation.pdf) | Source/documentation review | Windows binary not executed |
| [Drik Panchang](https://www.drikpanchang.com/vrats/ekadashidates.html?geoname-id=1261481&year=2027) and [Ekadashi FAQ](https://www.drikpanchang.com/faq/ekadashi/about-ekadashi-timings.html) | Existing published date/timing fixtures, Delhi 2027 listing, fasting/Parana rule documentation | Published minute precision, inferred reference city for older packs; not an authenticated exhaustive API comparison |
| [ISKCON Bangalore](https://www.iskconbangalore.org/ekadashi-calendar/) | Existing independent published-calendar regression: 26/26 dates for March 2026–March 2027, including special Mahadvadashi cases | One institution and year range; “Vaishnava” in this engine means the selected Gaudiya/ISKCON rule profile |
| [AstroSage Amalaki 2027](https://panchang.astrosage.com/festival/ekadashi/amalaki-ekadashi?date=2027&language=en) | Actual Delhi spot check: March 18 fast; March 19 Parana 07:14:21–08:51:55, versus engine 07:13:12.418–08:51:51.643 | Opening differs by 68.6 seconds. Quarter-of-time versus quarter-of-angle accounts for only about 8.7 seconds here; backend/convention difference remains unresolved. One example is not an engine-wide score |
| [IMD Rashtriya Panchang](https://mausam.imd.gov.in/responsive/rashtriyPanchang.php) / [Positional Astronomy Centre](https://packolkata.imd.gov.in/panchang/en) | Reviewed primary-source scope through indexed documentation | Pages timed out in this environment; no numerical comparison claimed |
| [Prokerala API](https://api.prokerala.com/docs/) | Documentation review for calculation settings and coverage | No API credentials or numerical benchmark; no accuracy ranking claimed |

### Astronomical position results

The 10,000-sample audit uses seed 271828 and dates from 1900-01-01 through
2100-12-31. Maximum absolute longitude errors:

| Quantity | Swiss | JPL DE440s, matched TT |
|---|---:|---:|
| Sun apparent longitude | 0.3543 arcseconds | 0.3551 arcseconds |
| Moon apparent longitude | 0.7597 arcseconds | 0.7642 arcseconds |
| Apparent Lahiri ayanamsa | 0.0181 arcseconds | Not independently scored |

Mean Swiss errors are 0.1410″ Sun, 0.1111″ Moon and 0.00577″ Lahiri.
The orbital series were retained; the fixes concern geometry, event detection,
religious-data presentation and cache identity. Distance diagnostics in the
raw JSON compare different geometric/apparent conventions and must **not** be
interpreted as equivalent distance-error measurements.

Lagna uses seed 314159, 1,000 instants in 2000–2040, latitude ±65° and longitude
±180°, compared with Swiss sidereal ascendants. This PR reduces mean error
from **12.425″ to 0.04846″**, p95 **19.813″ to 0.12734″**, and maximum
**51.330″ to 0.70187″**. The five frozen independent boundary fixtures also
check the production caller, rather than only the underlying geometry helper.

## Defects fixed in this PR

### 1. Tuesday Anandadi starts at the wrong nakshatra

Tuesday used Pushya as the start of the 28-star cycle. The weekday sequence in
[Muhurta Chintamani 1.25](https://vedicpupil.in/library/books/muhurta-chintamani/chapter-1/verse-25)
starts Tuesday at **Ashlesha**. January 6, 2026, Chennai is a concrete failure:
Ashlesha should produce **Ananda**, but the source produces **Kaladanda**.
The Tuesday offset changes from zero-based 7 to 8. The Abhijit interval and
other weekday starts are retained.

Every Tuesday was affected: for a simple 730-day 2026–2027 calendar, the
field's previous agreement is only **626/730 = 85.7534%**, even while the
old aggregate is about 99.97%. The new independent Swiss label sweep measures
actual sunrise locations separately from polar fallback dates.

### 2. A complete sunrise/sunset pair can fall between scan samples

A five-minute sign-change scan loses a short excursion above the horizon.
At latitude **67.39139224084514°**, longitude **−1.15°**, on December 21, 2026,
Swiss gives sunrise **12:01:55.649Z** and sunset **12:03:23.595Z**.
The source reports neither event. The new solver checks local extrema between
samples, refines the extremum, then brackets each crossing. It also checks
shorter-than-five-minute ranges and the final partial scan interval.
Frozen independent roots pass within three seconds. This improves the
mathematical standard-horizon calculation; local mountains, elevation and
weather are not observations this engine can promise to predict exactly.
[USNO's definitions](https://aa.usno.navy.mil/faq/RST_defs) explain these limits.

### 3. Stored openings are rounded before their allowed time

The schedule converted calculated instants to whole minutes. On January 15,
2026, Chennai's raw Parana opens at **06:35:07.443** local time, but Home stores
**06:35:00**, over seven seconds early.

Across the existing 60-entry parity dataset—10 cities, two traditions,
2026–2028, **1,480 fasts**—all **2,960 fasting/Parana start boundaries** move
forward when seconds are restored. The mean discarded duration was
**29.980 seconds**, maximum **59.963 seconds**. This is a serialization audit
against the newly preserved roots, not another independent astronomical oracle.

Starts now round **up** to milliseconds; bounded ends round **down**. Relative
to the engine's root, storage adds less than one millisecond of inward rounding.
Home, the Panchang Ekadashi panel and widgets share boundary-aware formatting:
ceil opening seconds, floor closing seconds, and milliseconds when seconds
would collapse a subsecond interval. Legacy whole-minute data retains its
existing display. Raw precision is not a claim of millisecond physical accuracy.

A Delhi Gaudiya fast on September 12, 2027 has Parana September 13 at
**06:04:56.373–06:05:09.097** local, only **12.724 seconds**. The new display
is **06:04:57–06:05:09**. The New York Smarta July 24, 2026 case has only
about **2.56 seconds**. A whole-minute display cannot safely represent those windows.

### 4. After-only Parana acquires an invented deadline

When the rule engine returns an opening without a bounded end, the schedule
substituted sunset. New York Smarta December 19, 2026 is one example.
At polar latitudes that substituted sunset can even precede the opening.

The schedule now preserves the missing ritual end. It says **“after …”** and
never shows an end countdown. An independent optional `contextExpiresAt`
(next local midnight after opening) controls Home/widget rollover only. It is
**not** a ritual deadline and is never displayed as one. Eleven fabricated
ends disappear from the 1,480-event parity dataset. Flutter, native Swift
widgets and Kotlin's model/timeline/refresh path carry the separate expiry.

### 5. Lagna mixes mean and apparent reference frames

The source combines apparent sidereal time with mean obliquity, then subtracts
mean Lahiri ayanamsa. Both ports now use true obliquity and apparent Lahiri
consistently. The independent 1,000-sample results above quantify the improvement.

### 6. The month convention changes with the legacy data year

The schedule calculates Amanta month/paksha, then overwrites it from legacy
published packs. The 2026 and 2027 packs use different month conventions.
The schedule now retains its calculated Amanta labels in every year, while
reusing published IDs and descriptive content. The parity corpus corrects
**260 month labels**. Notification IDs, occurrence IDs and stored observance
history identities are preserved.

### 7. Cache identity discards location precision and timezone version

Four-decimal coordinate rounding can reuse a different location's result
near a religious decision boundary. Cache keys now retain round-trip coordinate
precision and the bundled timezone-data release. Calculation and schedule
versions advance to `current-location-v3` / `schedule-3`, invalidating stale
computed schedules without deleting history.

## Coverage of the full Panchang

| Aspect | Assessment after this change |
|---|---|
| Tithi, nakshatra, yoga, karana indices and transitions | Strong independent Swiss coverage; near-boundary displayed-minute disagreements remain. Finite floating-point/ephemeris errors can cross a categorical boundary |
| Vara and local civil date | Deterministic bundled IANA timezone behavior; existing timezone/DST tests. Historical second offsets and every 1900–2100 political transition are not certified |
| Sun/Moon rise and set | Existing global comparisons plus newly fixed grazing events; standard sea-level horizon convention, not terrain/weather prediction |
| Lahiri, rashis, lunar months, Adhika, Sankranti | Swiss coverage; consistent Amanta schedule labels now. Kshaya-month religious handling and all regional solar-calendar mappings need additional authority-backed fixtures |
| Lagna | Measured improvement against independent geometry; frozen sign-boundary tests. Latitude range ±65° in the random audit is explicit |
| Smarta Ekadashi and Parana | Reference-rule and published comparisons pass their stated tolerances in the 16-city suite. The rule reference resembles production logic and is weaker evidence than a separate published decision table |
| Gaudiya/ISKCON Ekadashi, Mahadvadashi, Hari Vasara | GCAL and independent ISKCON fixtures; not certification for Sri Vaishnava, Madhva or every other lineage. Existing exclusions and a Pitcairn decision disagreement remain reported |
| Anandadi yoga | Tuesday defect fixed and newly measured independently; polar no-sunrise dates are excluded from this sunrise-only label sweep, with count reported |
| Rahukala, Yamaganda, Gulika, Abhijit, Dur Muhurta, Brahma Muhurta, Hora, Choghadiya | Existing formula/regression/parity tests; no exhaustive independent global interval oracle. Correct sunrise geometry helps, but is not separate religious-rule certification |
| Varjyam, Amrit Kalam, nakshatra pada and special yogas | Existing fixtures/formulas; full interval semantics and regional convention review still required |
| Monthly and annual festivals | Existing accepted-date and once-per-year checks are useful but insufficient: some fixtures accept multiple conflicting dates, and rules omit important regional/Bhadra/eclipse distinctions |
| Home, reminders, notifications, widgets, history | Exact schedule boundaries and after-only lifecycle improved; parity and regression coverage added. Device/native UI validation limits are listed below |

## Remaining discrepancies and work needed for a stricter accuracy contract

1. **Define named regional/lineage profiles and supported ranges.** Publish
   ayanamsa, sunrise/refraction/elevation convention, Amanta/Purnimanta choice,
   religious decision rules, timezone release and no-sunrise policy for each.
   “100% Panchang” without these definitions is not a testable specification.
2. **Replace permissive festival acceptance with authority-specific fixtures.**
   For example, the current Varalakshmi rule gives August 28, 2026, whereas
   [TTD's official notice](https://news.tirumala.org/elaborate-arrangements-for-varalakshmi-vratam-on-august-21-_-%E0%B0%86%E0%B0%97%E0%B0%B8%E0%B1%8D%E0%B0%9F%E0%B1%81-21%E0%B0%A8-%E0%B0%B5%E0%B0%B0%E0%B0%B2%E0%B0%95%E0%B1%8D%E0%B0%B7%E0%B1%8D%E0%B0%AE/)
   and [Kanchi's calendar](https://www.kamakoti.org/kamakoti/news/2026/--6897-20260708.html)
   give **August 21**. This is an unresolved profile/rule discrepancy, not a
   reason to silently change every regional calendar. Holika needs a fuller
   Bhadra decision tree; eclipse and regional festival rules need explicit review.
3. **Retain unresolved comparison failures.** Published fasting-date agreement
   remains **231/232 (99.57%)**: the legacy EST Saphala row gives January 3,
   2027, while the calculated New York Smarta date is January 2. Resolve this
   against a confirmed city/profile-specific publication before changing data.
   The edge suite's Pitcairn
   April 13, 2026 Gaudiya fast differs by **2.419 minutes** at the Parana end.
   GCAL selects one-third of daylight; Swiss places Dvadashi's end about
   2.4 minutes earlier and production chooses that earlier end. GCAL's older
   astronomy can change the selected constraint. This PR does not distort the
   engine or exclude the row to make a score reach 100%.
4. **Fix reference civil-time fallback before claiming polar limb perfection.**
   The existing reference samples `local midnight + 6 elapsed hours` when
   sunrise is absent; production samples local wall-clock 06:00. On a DST
   transition those differ. Longyearbyen October 31, 2027 gives nakshatra
   reference 16 versus production 17. There is no sunrise that day. The frozen
   benchmark remains unchanged here; report this as a policy/reference mismatch,
   not proof of an orbital error.
5. **Track uncertainty at religious decision boundaries.** Preserve full raw
   precision, specify a tolerance budget, and mark cases where accepted models
   disagree on the fasting day. The source's `nearBoundary` flag is useful but
   does not certify every future rule predicate or uncertainty source. Run
   independent published fixtures around every decision branch, including
   skipped/repeated tithis, nakshatra Mahadvadashis and very short Parana.
6. **Add independent interval coverage.** Validate every auspicious/inauspicious
   interval and special yoga against a reviewed textual definition and a separate
   implementation. Cross-platform parity alone only proves agreement.
7. **Review date-browsing labels and historical time assumptions.** Some header
   timezone abbreviations are based on “now,” so a browsed winter date can carry
   a summer abbreviation. The instant calculation and label need separate tests.
   Long-range ΔT and historical/future civil-time rules need a bounded support policy.

The appropriate release goal is **zero known failures for a named profile and
supported range**, with 100% of its explicit acceptance cases passing. This PR
improves measured accuracy but does **not** achieve full-product zero-known-error
status: the regional festival and unresolved comparison gaps above remain.
No scientifically honest audit can turn subarcsecond approximation, future
civil-time uncertainty and differing traditions into universal exactness.

## Verification and reproducibility

New Swift regressions were committed and run red before the iOS implementation;
six initial tests produced 17 failed assertions. Integration regressions then
exposed the widget, month and cache paths. The iOS stage passed 62 selected tests
and was pushed before the Flutter port. Nine Flutter precision regressions were
separately committed and all nine failed before implementation, then passed.
The export-schema regression likewise failed before the export was extended.

| Final check | Result |
|---|---|
| Full Flutter test suite | **736 passed, 0 failed**, one deliberate opt-in audit-export skip |
| Flutter analyzer | **No issues** |
| Changed Dart files formatting | 13 files checked, no changes required |
| Full Swift package tests, release | **262 passed, 0 failed** |
| Isolated Kotlin model JUnit tests | **2 passed**; same tests **2 failed** against c15bce7 |
| Separate original/edge audit exports | Both completed; all 41 locations re-scored against frozen references |
| New SwiftUI/RemoteViews UI regressions | Written, **not run**; required native toolchains unavailable |

The bulk export is opt-in (`AUDIT_OUT`) so ordinary Flutter tests do not repeat
an eight-minute research job. It was run separately for both audited city sets.
The first full local run exposed a missing SQLite development-library name and
one stale cache-version expectation; the local library link and version test
were corrected, and the final full runs above passed. No production assertions
were removed to obtain these results. Red/green and final logs are committed in
`docs/review/panchang-accuracy/`.

The native Gradle wrapper could not download Gradle 8.14 (`Connection refused`),
and this environment has no Android SDK. To still verify executable Kotlin
behavior, the actual `WidgetData.kt` and `WidgetTimeline.kt` sources were compiled
with Kotlin 2.3.20 and run against the same two JUnit model tests, using JVM
`org.json` and removing only the Robolectric runner/configuration annotations in
a temporary test copy. Both tests fail against source commit c15bce7 and pass
against the new source. This verifies model/serialization behavior, **not**
Android integration. The actual RemoteViews regression is written but unrun;
full Android unit/UI/emulator checks remain required. Linux also cannot build
the SwiftUI app/WidgetKit target or run XCUITests; the Swift package tests exercise
shared logic only. A new `PanchangPrecisionUITests` case checks seconds in the
actual SwiftUI Parana panel and is written but unrun. Changed SwiftUI files
pass syntax parsing; this is not a native typecheck or simulator test.

The Delhi 2027 schedule regression now uses the already established **two-minute
raw published-reference tolerance** rather than one minute after truncation.
Retaining seconds exposes an existing maximum difference of 1.21 minutes;
no oracle rows were changed to conceal it. The raw independent comparison and
its two-minute gate are unchanged. Cross-platform precise timestamps compare
within 2 ms, with the same offset and identical missing-end semantics; exact
identity/content/month/rule comparisons remain. Parity fixtures were regenerated
from the changed Dart engine and are not independent astronomical references.

Toolchain: Flutter 3.38.5 / Dart 3.10.4, Swift 6.0.3 Linux release build,
Python with pyswisseph 2.10.3.2, Skyfield and gaurabda 0.8.4; Kotlin 2.3.20
for isolated model tests. The separate pure-position runner used Dart 3.13.5. On this Linux image the
Flutter database tests require `libsqlite3.so`; the system provides only
`libsqlite3.so.0`, so an external local symlink plus `LD_LIBRARY_PATH` supplied
the expected name. This is test-environment setup, not an app change.

Reproduce the original-city calculation export with the Flutter runtime (the
old standalone `dart compile` command in `PANCHANG_ACCURACY.md` is no longer
sufficient because the city's localization import depends on Flutter):

```sh
flutter pub get
AUDIT_OUT=/tmp/engine.json flutter test test/tool/export_accuracy_audit_test.dart --no-pub
python tool/panchang_accuracy/build_reference.py tool/panchang_accuracy/cities.json 2025-12-01 790 EPHE_DIR /tmp/reference.json
python tool/panchang_accuracy/gcal_reference.py tool/panchang_accuracy/cities.json 2026,2027 /tmp/gcal.json
SE_EPHE_PATH=EPHE_DIR python tool/panchang_accuracy/compare.py /tmp/engine.json /tmp/reference.json /tmp/gcal.json /tmp/score.json
flutter analyze --no-pub
flutter test --no-pub --concurrency 2
swift test --package-path ios-native/EkadashiCore -c release -j 2
```

Use `AUDIT_CITIES=docs/review/panchang-accuracy/edge-cities.json` for the 25-edge
export; pass the same city file to both reference generators. Hold references,
exclusions, dates and tolerances constant for before/after comparisons.
Development-only scripts used for the extended audit are archived under
[`review/panchang-accuracy/reproduce`](review/panchang-accuracy/reproduce/);
see its README for input layout. Large per-day engine/reference JSON and
third-party ephemeris binaries are not committed.
