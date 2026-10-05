# Panchang engine and tab

> **Active extension (5 October 2026):** The user requested a new branch from
> PR #11 with worldwide date/location calculation, fuller Drik-style daily
> coverage, Smarta and Vaishnava Ekadashi, Daily/Muhurta/Ekadashi/Rashi subtabs,
> and More tools. This supersedes the IST/eight-city and five-tab restrictions
> below. See [PANCHANG_RESEARCH.md](PANCHANG_RESEARCH.md) for the implemented
> profile, references, validation design and remaining parity gaps. The rest
> of this document records the original PR #11 scope.

Approved 4 October 2026 for `feature/panchang-engine`, from `dev`. This
document scopes the first release and records research before implementation.
The feature is English-only, fixed to IST (UTC+05:30), and offline. It does not
download daily data or scrape/copy Drik Panchang.

## Product placement

Use the fifth bottom-tab slot for Panchang, replacing Search while retaining
Today, Calendar, Vrat, and Settings. Keep Search discoverable from a magnifying
glass in the top app bar and preserve the existing `ekadashi://search` route.
Panchang is a date-and-observance workspace; Calendar remains the established
Ekadashi and personal-calendar view, and Vrat remains the user's fasting
history. This separation keeps the high-frequency daily almanac reachable
without burying existing tracker functions.

The screen should answer at a glance: which Indian city and date are selected,
what tithi is active at sunrise, which observances apply, and when the next
limb changes. A premium detail view can reveal all five limbs, rise/set, daily
periods, alternative month conventions, and browseable observances. Free users
get a useful current-day tithi/observance preview and a clear premium preview;
all current Ekadashi and Vrat functionality stays as it is. Use the existing
server-verified entitlement and purchase flow.

Visual direction: calm editorial hierarchy, precise numeric time typography,
subtle lunar/solar motifs, accessible contrast, compact date navigation, and
clear city/timezone context. This draws on common calendar app tasks without
reusing any app's visual identity, assets, wording, or screen composition.

## Research and calculation sources

- Drik Panchang's public city-month pages and official iOS/Android listings
  describe a location-specific almanac with sunrise/sunset, tithi, nakshatra,
  yoga, karana and observance/fast listings. These informed feature coverage
  only. Their daily data, text, brand, and assets are not inputs to this app.
  References: <https://www.drikpanchang.com/> and
  <https://www.drikpanchang.com/apps/apps.html>.
- Drik Panchang's App Store listing describes city-based calendar and festival
  coverage: <https://apps.apple.com/us/app/hindu-calendar-drik-panchang/id1321271821>.
- Drik Panchang's Android listing highlights city-based festival and fasting
  calendars: <https://play.google.com/store/apps/details?id=com.drikp.core&hl=en-US>.
- MyPanchang is also published on iOS; its listing helped confirm the familiar
  need to browse a date and inspect its almanac:
  <https://apps.apple.com/in/app/mypanchang/id1567820028>. App listings are
  product descriptions, not independent verification of their calculations.
- Meeus, *Astronomical Algorithms*, 2nd ed., is the reference for Julian day,
  apparent solar longitude, lunar longitude, and phase calculations. The lunar
  periodic terms used here are independently implemented from published
  astronomical formulae; no runtime astronomy package is added because the
  available CI Dart SDK is 3.10.4 and the reviewed package releases require a
  newer SDK.
- NOAA's Solar Calculator documents an approximate sunrise/sunset method and
  its atmospheric/horizon limitations:
  <https://gml.noaa.gov/grad/solcalc/calcdetails.html>.
- USNO notes that rise/set depends on observer position and local horizon and
  provides public lunar phase data for independent comparison:
  <https://aa.usno.navy.mil/faq/rs_algor> and
  <https://aa.usno.navy.mil/calculated/moon/phases>.
  The Delhi rise/set regression fixture uses USNO's public one-day service at
  <https://aa.usno.navy.mil/api/rstt/oneday?date=2026-10-04&coords=28.6139%2C77.2090&tz=5.5>.
  Its October 3, 2026 last-quarter listing (18:55 at UTC+05:30) also provides a
  phase cross-check for the following sunrise tithi fixture.
- NASA's lunar phase explainer provides a second independent reference for the
  new/full-quarter phase cycle: <https://svs.gsfc.nasa.gov/5587>.

Rise/set outputs are estimates, not survey-grade horizon events. Tests compare
against independent published values with realistic tolerances and exercise
known new/full moon instants. Tithi and limb transitions are computed from
continuous longitudes; labels and dates are determined at local sunrise or the
relevant observance window in IST.

## Engine boundaries

The pure calculation layer owns Julian-day conversion, Sun/Moon apparent
geocentric longitudes, optional Lahiri sidereal offset, tithi, nakshatra, yoga,
karana, phase/transition instants, approximate sunrise/sunset/moonrise, and
daylight segments. It accepts an explicit date and city coordinates and does
not read device timezone, network, Flutter widgets, or subscription state.
Dates and displayed event times are converted using the fixed UTC+05:30 offset.

City coordinates are selected from a small, documented Indian-city catalog.
The default is New Delhi; the Panchang city selector never asks for location
permission and never silently uses GPS. For a single timezone, observance dates
still vary by longitude/latitude because sunrise and sunset vary by city.

Astronomy and religious rules remain separate. Each observance rule names its
paksha/tithi and its decision window (sunrise, Madhyahna, Aparahna,
sunset/pradosh, moonrise, or Nishita), with its month convention and tie-break
made inspectable. Amanta month names are derived from the preceding new moon
and sidereal solar sign; the adjacent Purnimanta name is shown as an alternate.
The starter registry uses sunrise for ordinary tithi observances, Madhyahna for
Ganesh Chaturthi and Rama Navami, Aparahna for Vijayadashami, Nishita for
Janmashtami and Shivaratri, sunset for Pradosham and Deepavali, and moonrise for
Sankashti/Karwa Chauth. Bright-fortnight rules use the Amanta name; dark-fortnight
rules use the Purnimanta name, with Maha Shivaratri and Deepavali handled by
their named rules. These are stated starter conventions, not a claim that every
sect or region selects the same date. Sankranti is based on solar ingress rather
than lunar tithi. The engine must never override the existing published
Ekadashi fast and parana schedule in the Vrat/calendar surfaces.

## First release observance scope

The rules registry is designed to add reviewed regional profiles. First release
targets commonly observed monthly items: both Ekadashis, Dwadashi, Purnima,
Amavasya, both Chaturthis (including moonrise-dependent Sankashti), monthly
Pradosham/Trayodashi, Masik Shivaratri, and Ashtami/Navami tithis. Annual rules
target Makar Sankranti and the principal widely observed lunar festivals:
Vasant Panchami, Maha Shivaratri, Holi, Chaitra/Vaishakha Navaratri, Rama
Navami, Hanuman Jayanti, Akshaya Tritiya, Guru Purnima, Krishna Janmashtami,
Ganesh Chaturthi, Sharad Navaratri, Vijayadashami, Karwa Chauth, Dhanteras,
Naraka Chaturdashi, Deepavali/Amavasya, Govardhan Puja, Bhai Dooj, and Chhath.

This is a reviewed mainstream starter set, not a claim that a single rule set
covers every Hindu community. Several dates have regional calendar, month,
sunrise, moonrise, Smarta/Vaishnava, or multi-day observance differences. Each
rule must say which convention it uses. Unsupported regional rules should be
clearly marked as not yet available instead of guessed. The rule list and
known convention limits belong in the product documentation and tests.

## TDD and delivery gates

Add red tests before implementation for astronomical fixtures, IST date/time
boundaries, limb transitions, representative rule dates, city differences,
offline determinism, and premium/free screen states. Verify tab placement,
top-bar search and old search deep links. Then implement and keep the test suite
passing. Run formatting, static analysis, all existing Flutter tests, screenshot
tests, available Android emulator/native/UI workflows and hosted CI. Capture
the relevant screenshots and logs as review evidence. Open the PR against
`dev`, mark it ready for review, and do not merge it.
