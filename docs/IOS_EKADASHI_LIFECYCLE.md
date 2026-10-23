# Ekadashi lifecycle — iOS first, Android deferred (23 October 2026)

Approved behavior:

| Interval | Status | Ring |
| --- | --- | --- |
| Before fasting civil date | Nearest unfinished occurrence, days to go | None |
| Fasting date midnight until start | HH:mm:ss countdown | None |
| Fasting start until Parana start | Now | Completed fraction, fills 0–100% |
| Parana start until Parana end | Parana | Full, 100% |
| At/after Parana end | Passed for historical browsing; default advances | None |

`EkadashiLifecycle` compares absolute instants. The selected Home city's civil
calendar is used only for the countdown's day and calendar placement. DST and
non-whole-hour zones must not change elapsed progress. Percentage rounds down;
100% is reserved for Parana start. Missing or reversed timing intervals never
invent an active state or ring. A sub-minute Parana window can collapse to one
recorded minute in the existing schedule: the fast remains valid before that
instant, then passes at its recorded end, without inventing a longer window. The underlying astronomical schedule is unchanged.

Home launch and re-tap use the same unfinished-occurrence rule. A foreground
clock advances a displayed current occurrence at its end, including across enabled
years. Historical/future browsing is preserved. Resuming after the boundary must
also advance. Completed progress uses fasting start to Parana **start**; the
occurrence stays current until Parana **end**. Recording still opens at Parana
start; existing saved records remain editable.

Single Home/Lock Screen widgets and Settings previews share the lifecycle and
renderer. Upcoming-five uses actual future fasting-start instants, including a
same-day occurrence before sunrise, and removes it exactly at start. Cached
snapshots must retain an ongoing occurrence across midnight. Native countdowns
use system timer text rather than per-second WidgetKit reloads. State/progress
boundaries remain timeline entries, subject to system delivery scheduling.

Calendar keeps the original fasting-date entry, adds a linked Parana entry on
its actual civil date in the Home city, and retains the same occurrence UID.
Only the fasting date gets the green Ekadashi dot; the linked Parana entry
does not add a dot on the following day. It must not duplicate a Vrat record.
Calendar shows compact status/countdown;
Details has a dedicated ring/status row above its existing timings. Calendar's
Today button continues to mean the city's current date.

## Debug-only testing

The test session requires the explicit `-lifecycle-testing` launch argument in a
Debug build. It exposes a translated test-clock screen in Settings and a visible
test banner. Controls jump to midnight, immediately before/at fasting start,
halfway, next midnight, immediately before/at Parana, and immediately before/at
Parana end. The clock can pause, run at 1×, 60× or 3600×, or return to live time.
The phone's clock and schedule are not changed.

Settings/history are in memory and Calendar entries are isolated in memory.
Recording and notification scheduling are disabled. Widget snapshots use a
separate debug key shared with the Debug extension. Normal launches clear the
simulation. No release settings, remote billing or notification configuration
is rewritten by a simulated time.

All controls, translations, configuration payloads and environment parsing are
inside `#if DEBUG`. Release exposes only the real clock and normal snapshot key.
`tool/ios/test_release_clock.py` scans the built app and extension binaries for
forbidden test tokens; the Debug positive control must contain them and the
Release audit must contain none. Release was built and the audit passed.

UI tests can also pin `EKADASHI_UI_TEST_NOW` with `-ui-testing`, a pre-existing
Debug-only hook. The explicit lifecycle session additionally accepts
`EKADASHI_TEST_RATE`; it is absent from Release too.

## TDD and verification

`55d7a1e` first reproduced six failures: countdown selection before sunrise,
ascending progress, midnight/Parana retention, Home re-tap, cached snapshots and
Upcoming's actual start boundary. Expanded tests cover exact seconds, complete
real Chennai schedules in both traditions/all six languages, invalid timing,
DST, local-date mapping and automatic Home advancement without moving browsed
cards. Simulator rendering protects every widget family and large Home text.

The initial full Flutter run exposed a pre-existing date-dependent fixture bug:
Home uses calculated timings while `home_details_ios_parity_test.dart` still read
published timings. Its helper now reads the same Home engine schedule and saved
tradition. Android production source remains unchanged.

The expanded native sweep reproduced 14 Tamil status/Bengali Small glyph-bound failures before adding badge scaling and a two-point horizontal and three-point bottom Small-widget ink bearing. Release exclusion passed for both built binaries. Verification: the full Swift core suite passes **284 tests**, including the worldwide sample below; full Flutter passes **799 tests** and the analyzer reports no issues. All **36 native app/rendering tests** pass. All **39 current Simulator UI test methods** pass across the full run and targeted reruns, including live countdown/start, automatic end advancement, all-language Parana previews/Details, city-date selection and filtering. Debug positive-control and Release exclusion audits pass; Release contains neither the simulation payload nor its controls.

## Android port checklist — wait for explicit iOS approval

- Port the lifecycle and exact-boundary test vectors to Dart and Kotlin.
- Change Home current selection/re-tap/foreground and resume advancement.
- Replace Today with countdown/Now/Parana/Passed statuses; fill 0–100%, keep 100%
  through Parana; retain the current occurrence overnight.
- Make native single-widget selection and previews persist until Parana end;
  use start instants for Upcoming-five; preserve Android widget design.
- Update native widget refresh boundaries, timer accessibility and percentage
  wording. Keep native system refresh limitations explicit.
- Add Calendar's same-UID Parana entry/status on the city's actual Parana date,
  with the green dot only on the fasting date (no Parana dot);
  add Details status/ring without changing recording eligibility.
- Port all six translations and update gallery descriptions and accessibility.
- Reproduce every test boundary, timezone/DST/year rollover, cold/warm/cache
  case and translated layout case. Add Debug-only isolated testing and prove
  release exclusion independently on Android.
- Re-run full Flutter/JVM, emulator and Samsung checks after that approval.

## Update frequency and battery contract

The iOS app uses a lazy lifecycle schedule: seconds during the visible pre-start
countdown, minutes for active progress, and hourly while waiting for a later
date. Exact midnight/start/Parana/end boundaries are included regardless of that
cadence. Hidden pages and inactive scenes get a static render and no ticking
sequence. Home selection checks sleep until the next completion boundary (with
an hourly cap for clock changes) and stop while inactive. The prior instant is
retained for resume handling. No astronomy, location, network or storage work
is done by the UI countdown. Native widgets use Apple's system timer text.
Debug simulation may tick faster for test transitions; that branch is compiled
out of Release. These are scheduling guarantees, not a measured battery-drain
claim. The cadence test starts failing in `9561264` before implementation.

## Worldwide lifecycle sample requested 23 October

`EkadashiLifecycleWorldSampleTests` uses seed `0x20261023`: eight timezone-edge
anchors plus two catalog cities selected from each of Africa, America, Asia,
Australia, Europe and Pacific, with distinct IANA zones. This makes a failure
reproducible while avoiding a Chennai-only test. The sample covers 20 cities,
20 zones, both traditions, all 49 occurrences across 2026–2027 per city/tradition
(**1,960 occurrence/tradition/location cases**), in all six languages.

| City | IANA zone |
| --- | --- |
| Chennai | Asia/Kolkata |
| London | Europe/London |
| New York | America/New_York |
| Sydney | Australia/Sydney |
| Kathmandu | Asia/Kathmandu |
| Adelaide | Australia/Adelaide |
| Waitangi, Chatham Islands | Pacific/Chatham |
| Honolulu | Pacific/Honolulu |
| Comé, Benin | Africa/Porto-Novo |
| Tlokweng, Botswana | Africa/Gaborone |
| Midland, United States | America/Detroit |
| Alegre, Brazil | America/Sao_Paulo |
| Irkutsk, Russia | Asia/Irkutsk |
| Sühbaatar, Mongolia | Asia/Ulaanbaatar |
| Labrador, Australia | Australia/Brisbane |
| Officer, Australia | Australia/Melbourne |
| Dinslaken, Germany | Europe/Berlin |
| Ballincollig, Ireland | Europe/Dublin |
| Nggosi, Solomon Islands | Pacific/Guadalcanal |
| Manukau City, New Zealand | Pacific/Auckland |

Checks include local midnight/last-second countdown, start/halfway/last-second
fasting progress, Parana start/end, overnight retention, Home selection, cached
widget selection, Upcoming's exact start boundary and linked Calendar identity
with a green dot only on the fasting date. Full-year schedules include northern
and southern DST; dedicated synthetic tests also straddle a DST transition.
This validates lifecycle behavior using the app's existing calculated schedule;
it does not claim a new independent astronomical validation or polar-day policy.
Random catalog draws are limited to latitudes with normal sunrise/sunset.

The initial sample reproduced 18 assertions for three minute-collapsed windows
(New York Smarta on 24 July 2026; Chatham both traditions on 19 March 2027).
`07ee4ba` records the red sample and a focused five-failure regression. The
fix accepts equal Parana endpoints while still rejecting reversed intervals;
it preserves the original schedule and linked Calendar entry.

Simulator edge regressions also reproduce and fix first-open Calendar selection
using the device date instead of the Home city's date (New York is still on
22 October when Chennai is on 23 October), and a contradictory empty message
above a valid Parana entry under the Ekadashi filter. Port both fixes to Android.
