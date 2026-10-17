# iOS widget redesign

Scope: native iOS only, based on `dev` at `d9d4cda`. Both installed widget
kinds are preserved. Each displays one occurrence in every supported family.

- Today's date is evaluated in the Home schedule's time zone. On an Ekadashi
  date the widget shows that occurrence and a ring for **percentage remaining**.
  The ring starts at 100%, counts down from fasting start to Parana start,
  and reaches 0% at that boundary. Before fasting starts it stays full.
- On a non-Ekadashi date it shows the single next Ekadashi, even if yesterday's
  Parana window is still open. Midnight is a scheduled timeline boundary.
- Home Screen: small, medium and large; brand teal `#00A19B`, charcoal `#121212`
  in dark appearance, ivory `#FAF5E8` in light appearance. Lock Screen circular
  and rectangular accessories follow the system's rendering mode.
- Complete times and dates come from the existing engine schedule, Home city,
  tradition and app language. Percentage changes and state boundaries are
  scheduled together; iOS still controls when widget timelines are delivered.
- Settings previews use the same renderer and real schedule with the real
  clock. Today shows an empty state if today is not Ekadashi. Next selects the
  next later date. No fabricated dates, sample schedules or simulated fasts.
  Each family can be previewed; both Home Screen appearances are shown.
- Preview taps push the displayed occurrence's existing detail screen and Back
  returns to the preview. Installed widget links carry its stable occurrence
  UID and open that exact detail screen, including after a cold launch.

## TDD evidence

Failing tests were committed separately in `114960d` before implementation.
The first targeted run executed seven tests with nine expected assertion
failures: elapsed rather than remaining fraction, an empty ring at start,
incorrect pre-sunrise selection, yesterday retained on the following day,
missing weekday, and unrecognised occurrence links. Additional tests cover
real preview selection, exact dates/times, percentage boundaries, localization,
midnight refreshes and UID round trips. App-level and UI navigation tests are
included for execution with Xcode.

The final verification results and environment limits are recorded in the PR.
No workflow runs are requested; commits use `[skip ci]` per repository policy.

## Verification (17 October 2026)

- Swift 6.0.3 on Linux: full `swift test -c release --jobs 4`: **264 passed**.
- Flutter 3.38.5: all 104 test files: **726 passed**. The main run passed 722;
  the four city-search tests passed separately with concurrency 1, to give
  their existing 100 ms performance threshold a stable measurement.
- `flutter analyze --no-fatal-infos`: **no issues**.
- All 16 changed Swift files pass syntax parsing; `git diff --check` passes.
- Native app/widget builds, XCTest rendering/app tests and XCUITest navigation
  checks are **not run**: Xcode and an iPhone runtime are unavailable here.
  Syntax parsing is not an iOS type check or runtime verification.
