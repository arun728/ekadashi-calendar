# Combined v2 testing

Base: dev `2952ac951f62cffa06b98b75411f2d7d0480acfd`. This candidate restores
Search and the three PR #5 Android widgets alongside Vrat, 2026/2027 archives,
Telugu and custom/Google calendar integration. Main is outside this change.

## Gates

| Gate | Result |
| --- | --- |
| Flutter unit, regression, widget, acceptance and offscreen UI | 193 passed |
| Instrumented Dart line coverage | 5,264 / 6,696 (78.61%) |
| Flutter analyzer | No issues found |
| Translation-tool Python tests | 5 passed |
| Native JVM/Robolectric notification and widget tests | 31 passed (widget/preview SDK 28/35) |
| API 24 full app/multi-year/SQLite/Google reconciliation UI | Required; exact run result in PR validation/evidence |
| API 24 real launcher: three widget providers, four locales, taps | Required; exact run result in PR validation/evidence |
| Android debug APK / instrumentation build | Passed |

Coverage describes executed/imported Dart lines, includes generated localization
code, and excludes Kotlin, Swift and unimported files. It is not whole-repository
coverage. Individual file coverage is available from `coverage/lcov.info` and
`tool/coverage_summary.py`; aggregate coverage is not proof of correctness.

## Automated scenarios

- Immutable year-pack loading, invalid/missing data and retry, unique UIDs and
  native reminder IDs, 2026 history/2027 recycled-ID migration, retained unknown
  rows/backups, restart/idempotence, cross-year streaks and achievements.
- Disabled/future observance rejection, concurrent tracker writes, corrupt and
  failed storage, no false success/unlock, achievement dialog sequencing.
- Google account/calendar/year isolation, pagination, canceled/deleted events,
  empty snapshots, failed/partial fetch preserving cache, exclusive all-day and
  midnight boundaries, custom entry persistence and sign-out cleanup.
- Search Unicode, zero-match exclusion, exact/prefix/fuzzy ranking, one/two edits
  and transpositions, strict short tokens, language/year/category filters,
  explicit-submit-only recent history, asynchronous rebuild ordering and all
  five tabs remaining reachable after integration.
- Every UI key/placeholder/native script across ta/hi/te, hardcoded screen Text
  audit, all five official content fields plus month/paksha in both year packs.
  Home fasting and fast-breaking date labels are checked in all four locales.
  Four-language UI snapshots use complete Telugu/Tamil/Hindi test fonts.
  Flutter integration uses registered controlled text input to avoid stale native
  IME client IDs; native launcher tests use actual Android touch/accessibility.
- Native picker previews use all four locale resource labels, contain no invented
  dates, and fit the small minimum width without letter-by-letter wrapping.
- Native widget rollover through multiple expired entries, cross-year/offline
  timeline, no stale exhausted hero or duplicate list row, selected-location
  timezone/date boundaries, exclusive Parana end, localized labels and links.
- Native WorkManager reminder opt-out and two-year scheduling/cancellation.

## Commands

```sh
flutter pub get
python3 tool/generate_localized_lookup.py
flutter gen-l10n
flutter analyze
flutter test --coverage --concurrency=2 --reporter expanded
python3 tool/coverage_summary.py coverage/lcov.info
python3 -m unittest discover -s test/tool
./android/gradlew -p android app:testDebugUnitTest --console=plain
bash tool/android-feature-integration.sh integration_test/multi_year_android_test.dart
bash tool/android-launcher-widgets.sh
```

The Android scripts use a **dedicated test emulator** and alter app preferences,
permissions and launcher data. The launcher script must follow the multi-year
integration run, which writes four deterministic payload fixtures in the durable databases directory. It installs
the normal `lib/main.dart` app before widget taps; widgets never launch the
integration-test entrypoint. Keep-app-running preserves fixtures after Flutter
integration. Screenshots/logs are collected under `build/ui-screenshots/`,
`build/android-feature-evidence/` and `build/android-widget-evidence/`.

## Release/device boundaries

The local emulator is API 24, 320×640 dp, software-rendered without KVM. Timings
and frame-rate logs do not represent hardware performance. Robolectric covers
SDK 28/35 widget behavior. CI adds real API 33/35 emulator and denied/GPS-off
runs; configured jobs are not claimed passed until their results exist.

Google UI tests use fake authenticated responses and **real Android SQLite**.
They verify full-year windows, cache deletion reconciliation and preservation of
custom entries. Real OAuth consent and deleting an event on Google's servers
must be validated with the configured account. Read-only year import is not
background two-way sync.

Samsung M52 and Z Flip 5 checks remain for OEM launcher rendering, Doze/battery
restrictions, long background refresh, GPS/travel/folding and a release-signed
upgrade from Play Store v1. Linguistic quality requires native-speaker review.
No iOS build/widget result is claimed. Main needs separate release approval.
