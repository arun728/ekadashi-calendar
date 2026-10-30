# Android lifecycle port — 23 October 2026

Arun authorized the Android port before reviewing iOS. Work remains on PR #24.
The existing Android Home Screen widget layouts, gradients, icons, linear
progress bars, sizes and collection list are retained.

The behavior follows [the shared lifecycle contract](IOS_EKADASHI_LIFECYCLE.md):

- Fasting-date midnight until start: HH:mm:ss on Home, no active ring or Now.
- Fasting start until Parana start: Now and completed progress filling 0–100%.
- Overnight retention; Parana start until end: Parana and 100%.
- At Parana end: default Home and single widgets advance to the next occurrence.
  Explicit historical browsing stays on its card; manual year browsing stays in
  that year. Home re-tap selects the current occurrence across enabled years.
- Native Upcoming-five compares actual fasting starts, including a same-day
  pre-start occurrence, and removes that occurrence when its fast starts.
- Calendar has a same-UID linked Parana entry on its actual local date; green
  dots remain only on the fasting date. The Parana filter has no contradictory
  empty message. Calendar's current date follows the Home city, not the device.
- Details has a dedicated status/progress row above the existing timings.
  Recording eligibility still opens at Parana start, with existing records editable.
- Settings previews use the same Kotlin renderer/selection as installed widgets.
  All six languages and both traditions use the same rules. Gallery descriptions
  reuse the approved iOS wording and native fallback labels are translated.

## Refresh and platform behavior

The app uses one-second refreshes only for a visible pre-start countdown,
minute progress updates and exact lifecycle boundary delays. Hidden tabs and
background scenes do not keep display countdowns running. Resuming catches up;
automatic selection uses the prior instant to preserve deliberate browsing.

Android native widgets use the host's Chronometer for a running pre-start
countdown, rather than waking a worker every second. Android chooses its timer
format (hours/minutes/seconds, or minutes/seconds for shorter durations).
WorkManager schedules midnight, fasting start, Parana start/end and progress
refreshes. Delivery remains subject to Android/OEM scheduling. KEYGUARD support
is still device/host-dependent; Settings describes it and does not add a picker
where the manufacturer's System UI has none.

## Isolated testing and Release exclusion

The separate `integration_test/android_lifecycle_test.dart` entrypoint installs a
Debug-only display clock in the existing isolated `.glasspreview` package. It
changes neither the phone clock nor the regular installation. Frame callbacks
use the same test instant. Normal main.dart never installs an override. The
`kDebugMode` branch, its marker and the integration entrypoint are absent from
Release. `tool/test_android_release_clock.py` audits the APK; the Debug test APK
is a positive control and must fail the Release exclusion check.

A Release audit APK is unsigned: no release keystore is present in this checkout.
A temporary external Gradle init script removes signing only for this local
artifact; no project signing configuration is changed or committed.

## TDD and verification

Red commits: `bba6fc1` (Dart lifecycle), `3f3a97d` (native widget selection),
`9d35928` (Home Now/completed UI), `e013986` (Debug display clock), `5b31971`
(hidden preview refreshes), `69cad37` (last fractional-second countdown),
and `11cacb9` (saved-record editing in Details, replayed before Parana).
Existing civil-date/remaining assertions were updated for the approved contract.
A saved observance stays editable in Details even when replayed before its
Parana time, matching Home. The Glass Off baseline images were updated only for Now/completed progress;
the design and the separate toggle round-trip protections remain unchanged.

The same seed `0x20261023` selects the same 20 cities/20 IANA zones as iOS:
eight timezone anchors and twelve stratified catalog draws. Actual schedules
for both traditions in 2026–2027 cover 1,960 occurrences in all six languages,
including the minute-collapsed New York/Chatham Parana windows. Native tests
cover both API 28 and 35, layout bounds, complete localized timings, cache
rollover, native preview links and exact boundary selection.

The emulator lifecycle flow captures midnight, 0%, 50%, following midnight,
Parana, next occurrence, Calendar, Details and every native preview size.
Screenshot review strengthened the end assertion to require Rama/21 of 24,
rather than merely accepting that the Parana label disappeared. Emulator
permissions must be pre-granted to prevent system dialogs pausing the app.

Final verification:

- Flutter analyzer: no issues; complete Flutter suite: **807 passed**.
- Native Kotlin/Robolectric suite: **89 passed** (API 28/35 coverage).
- Shared Swift core Release suite: **284 passed** after resource regeneration.
- Android 16 ARM64 lifecycle flow: passed; **14 screenshots**, with exact next-card
  assertions at Parana end. A separate regression proves automatic advancement
  without re-tapping Home.
- Native Settings preview/navigation flow: passed in all six languages;
  **31 screenshots**, including a real platform-view tap to the correct Home card.
- Android framework KEYGUARD host: **1 passed**, both providers in all six languages;
  **12 screenshots**. This is a framework test host, not manufacturer System UI.
- Debug test APK positive-control audit: passed; using it as a Release APK fails
  as intended. Final unsigned Release APK exclusion audit: passed.
- Formatting and whitespace: passed. Generated-resource verification runs against
  the final implementation commit.

No physical Android phone was connected during this port; Samsung
M52 and Z Flip 5 OEM checks remain separate device validation.
