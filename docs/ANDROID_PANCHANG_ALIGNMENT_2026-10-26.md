# Android Panchang performance and alignment; iOS Home feedback

Same branch `feature/ios-widget-redesign`, draft PR #24. User approved porting
Panchang performance only to Android, three Android alignment fixes, and the
iOS Home blocked-recording message appearance. Android widget code, all widget
designs, timing rules, translations, purchases and stored history are unchanged.

## Changes

- Key days now loads only the displayed month rather than calculating a year.
  Search/reminders still cover complete years and reuse monthly results.
- Daily/Muhurta/Rashi share cached raw days calculated off the UI isolate.
  Ekadashi caches months independently for each tradition. The bounded caches
  coalesce in-flight work; completed values return a new Future in the caller's
  zone. Keys include the full location, coordinates, timezone and civil date.
  Raw results are independent of language. Errors can be retried, disposed
  pages ignore results, and generation guards prevent an older date replacing
  the selected date. Month results match the existing engine, including leap
  years; astronomical calculations are unchanged.
- Home and Details status badges meet the right content edge, matching the
  existing iOS placement. An active ring keeps a separate left position with
  a 12-point gap. Long labels wrap within their available space. Calendar's
  Ekadashi-filter empty text is centered.
- iOS Home's blocked-observance message explicitly uses the existing Glass Off
  surface in both modes. Other toast appearances retain their existing policy.
  Message duration, translations, button state and action-row clearance remain.

## TDD and regressions

- Red commits: `c070588` (missing cache APIs, right-alignment failures, old
  Calendar alignment and missing standard-toast option) and `d13b027` (async
  day loading injection, stale dates, retry and disposal).
- Logs before implementation: `../android-panchang-layout-red.log`,
  `../android-status-red.log`, `../ios-toast-readability-red.log`,
  `../android-panchang-async-red.log`.
- Complete Flutter suite: **887 passed** with coverage. Final cache-only test
  rerun after adding a seeded-year reuse assertion: **7 passed**.
  The three calculation services have **93/93 executable lines covered**
  (combined complete-suite and final targeted coverage; not whole-app coverage).
- Analyzer including the integration target: no issues; final post-assertion
  gate recorded with the build logs.
- Complete Swift core suite: **299 passed** (Release).
- Native hosted suite: iOS 18.6 **48 passed**, including all widget regressions
  and all-language/dark/light toast surface comparisons. iOS 26.5 hosted suite
  also passed, with its known local StoreKit catalog skip.
- Native iOS 26.5 Home feedback UI audit: **passed** for all six languages in
  both Glass modes; 12 retained screenshots. The test queries action geometry
  before showing the deliberately short-lived message; unrelated accessibility
  lookups must not consume its four-second lifetime.
- Android emulator integration: **passed**. Home future/passed and Details
  badges, Calendar empty text in all six languages/both Glass modes; all five
  Panchang sections in first/repeat visits. **90 screenshots**, **60 Panchang
  UI samples**. Real-isolate transport is also checked in unit tests.
- Narrow/large-text tests cover 320/390-point widths, 1x/2x text, every language
  and scheduled/countdown/fasting/Parana/passed states. Both Home traditions
  remain covered by the existing six-language Home tests.
- Two existing fake-clock widget-test fixtures now opt into inline calculations
  as the other Panchang fixtures already do. Production calculations use
  isolates. Two Home golden images changed only for the approved badge movement
  (0.85% pixel difference reviewed before updating the baselines).

## Emulator measurements

Debug ARM64 emulator, actual Dart engine, October 2026 / Chennai; measured
separately from screenshot/test-report serialization.

| Work | First result | Repeat |
| --- | ---: | ---: |
| Previous complete year for Key days | 4,259 ms | — |
| Displayed Key days month | 400 ms | <1 ms |
| Daily | 45 ms | <1 ms |
| Muhurta/Rashi shared day | <1 ms | <1 ms |
| Smarta Ekadashi month | 160 ms | <1 ms |
| Vaishnava Ekadashi month | 124 ms | <1 ms |

All 60 sub-tab UI visits took **499–599 ms**, including test frame waits.
These are emulator measurements, not a guarantee for every phone. The test
transfers 90 screenshots at teardown; teardown serialization is not a user
Panchang calculation. Complete logs: `../android-port-integration-drive.log`.
Screenshots and sample timings: `outputs/android-panchang-port/SCREENSHOTS.md`
and `panchang-times.json` in that directory (local evidence, ignored by Git).

## Build/install safeguards

- iPhone: optimized Apptinel Release build, normal launch, no Debug clock.
- Android: normal `lib/main.dart` Release entry point, existing project signing
  credentials read locally into the already-ignored configuration. No secret
  values or keystore files are committed. Verify the installed M52 certificate
  before updating; never uninstall/reset the physical phone's app.
- Emulator-only integration installation replaced an older differently signed
  test installation. No physical phone data was cleared.
- Android Release APK built successfully (normal entry point, integration-test
  markers absent). Its public signing certificate matches the previously
  installed M52 APK. In-place M52 install succeeded and normal launch returned
  `Status: ok`; no uninstall/reset occurred on the phone.
- iPhone Apptinel Release install succeeded. App/extension signing and shared
  App Group verified; Debug-clock strings absent from both Release binaries.
  Normal device launch is recorded in `/private/tmp/ekadashi-toast-device-launch.json`.
- No CI, merge, production purchase or changes to Android widgets.
