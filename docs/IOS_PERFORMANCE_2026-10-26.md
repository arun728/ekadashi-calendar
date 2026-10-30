# iOS widget refresh and Panchang performance — 26 October 2026

Scope: native iOS only, on `feature/ios-widget-redesign`, draft PR #24.
The approved widget layouts and the app's instant language-selection flow
are unchanged. No Android production files or astronomical rules changed.

## Findings and changes

- Key days awaited `observanceCalendar(year:)` to show one month. The existing
  path measured 7,942 ms cold / 7,825 ms warm in Debug, versus 708–727 ms for
  just October. The displayed month's results match the year-filtered results.
  The year-first UI path dates to `0575829b` (8 October); history does not prove
  that a single recent commit caused the newly noticed delay.
- Native iOS now loads only the requested month. A bounded, actor-isolated
  calculation cache shares in-flight and completed work: Key days by month,
  Daily/Muhurta/Rashi by day, and Ekadashi by month and tradition. Location,
  coordinates, IANA timezone and date remain in the keys. Raw results have no
  translated labels, so language changes reuse astronomy. Failed Ekadashi
  calculations remain retryable; cancelled view waiters do not cancel another
  page's shared work. Cancelled/outdated views cannot apply stale results.
- Search and reminders still cover entire years. They use the same monthly
  cache without making Key days calculate a year first. Session caches are
  bounded to 24 entries per calculation type.
- WidgetKit previously received 25 quarter-hour entries over six hours, plus
  actual state/percentage boundaries. Static Next/Upcoming entries often
  rendered identical content. Now it receives the current entry, meaningful
  changes and the same six-hour reload horizon. Both widget kinds retain their
  own required updates: Upcoming skips the current fast's progress ticks;
  all Today/Next families keep every percentage and lifecycle transition.
  System timer text still handles second-by-second countdowns. Paused/scaled
  Debug clock behavior is retained. Render locale comes from the entry's
  snapshot, avoiding an extra shared snapshot decode per rendered entry.
- Quarter-hour scheduling dates to `417a73c5` (7 October). This removes measured
  avoidable work, but does not establish a sole recent regression commit or
  guarantee WidgetKit/SpringBoard's on-screen scheduling latency.
- Release matters: the unchanged year calculation took 2,686 ms cold in an
  optimized run, compared with 7,942 ms in Debug. The new month-only work took
  244 ms in Release. The prepared daily-use iPhone build is optimized Release.

## Measurements

All times are local benchmarks, not promises for every phone. Baselines use
26 October / Chennai; UI uses an isolated iPhone 16 Plus Simulator, New Delhi.
The UI timer includes XCTest event delivery and its polling overhead.

| Path | First calculation (Debug, coverage run) | Reuse |
| --- | ---: | ---: |
| Key days month | 764 ms | 0.008 ms |
| Daily | 36.8 ms | 0.011 ms |
| Muhurta, shared daily result | 0.006 ms | 0.003 ms |
| Rashi, shared daily result | 0.002 ms | 0.003 ms |
| Ekadashi, Smarta | 113.7 ms | 0.004 ms |
| Ekadashi, Vaishnava | 111.3 ms | 0.002 ms |

The all-language native render benchmark covers Small/Medium Today-or-Next,
circular/rectangular Lock Screen and Medium/Large Upcoming. For the static Next
state, 25 timeline entries become 2. Rendering all six families took 428–563 ms
with the old entry count, versus 29–47 ms with the new count (all six languages).
This is an ImageRenderer work comparison, **not** a measured SpringBoard language
refresh. Snapshot build/decode themselves take milliseconds, not 3–5 seconds.

Real navigation checks cover all five Panchang sub-tabs, first/repeat visits,
in English, Hindi, Tamil, Telugu, Gujarati and Bengali: **60 samples**, all
visible and loaded. Tap-to-content range: **1.504–1.903 seconds**. Thirty
screenshots are retained under `outputs/ios-performance/panchang/`; individual
measurements are in `outputs/ios-performance/panchang-ui-times.json`.

## TDD and validation

- Red commit `e5cc0a7`: new cache APIs and widget scheduling tests failed before
  implementation. Logs: `../panchang-cache-red.log`, `../widget-timeline-red.log`.
- Cache tests exercise same-month coalescing, reuse, full place/timezone/date
  keys, both traditions, retry after failure, cancellation, bounded eviction,
  leap-day/year reuse and direct month-engine parity for Chennai, Mumbai and
  New York. Existing astronomical parity/worldwide tests remain unchanged.
- Timeline tests cover static work reduction, every completed percent,
  fasting/Parana boundaries, local midnight, Upcoming removal at fast start,
  zero-length horizon, and midnight in India, New York and Auckland.
- Analyzer: no issues. Complete Flutter suite: **860 passed**.
- Complete Swift core Debug run: **298 passed**, then **15 passed** targeted
  including the final additional midnight test. Final complete Release suite: **299 passed**
  (`../performance-release-full.log`, 216.9 seconds).
- Complete native hosted suite on iOS 26.5: **47 executed, 46 passed, one known
  local StoreKit-catalog skip**. iOS 18.6 final hosted suite: **47 passed, no skips**
  (`/private/tmp/ekadashi-performance-hosted-final.xcresult`).
- iOS 18.6 full Panchang navigation audit: **1 test passed**, 60 page/language/
  visit checks, 30 retained screenshots. Successful bundle:
  `/private/tmp/ekadashi-panchang-sections.xcresult`.
- Earlier UI harness attempts had an incorrect purchase/gesture setup; those
  failed/empty bundles are not counted as successful navigation checks.
- LLVM coverage: new `PanchangDataStore.swift` **73/73 executable lines (100%)**;
  new `timelineDates` **16/16 lines (100%)**. Entire Swift core line coverage is
  **93.07%**, not 100% for the whole app.
- Debug and Release app/extension builds succeeded with Apptinel team
  `65HTQTRP96`; both share `group.com.apptinel.ekadashi-calendar` and keep the
  app/extension bundle identifiers. Release binaries contain none of the Debug
  clock keys/banner/environment strings. Google client/URL-scheme presence was
  verified without exposing configuration values.

No CI, merge, purchase on a real account, uninstall or user-data reset.
