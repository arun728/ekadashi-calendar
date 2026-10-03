# Test and review status

The local merge candidate is based on `origin/dev` at `51abe88` and contains
the PR #6 revert followed by PR #4's tracker/achievement changes. It also
contains the fixes and test harness described below. GitHub currently shows
PR #5 (widgets/search) merged, PR #6 (Ragul's revert) open and cleanly
mergeable, and PR #4 open but conflicting against the current `dev` base.
This candidate is local; no remote branch or pull request was changed.

## Results on this candidate

| Gate | Result |
| --- | --- |
| Flutter unit, widget, acceptance and regression suite | 95 passed, 0 failed |
| Instrumented Dart line coverage | 1,945 / 2,753 (70.65%) |
| Flutter analyzer | No issues found |
| Android native Robolectric tests | 13 passed, 0 failed |
| Android API 24 tracker/achievement UI integration | Passed; 7 screenshots captured |
| Android API 24 Home, Calendar, Settings and localization integration | Passed; screenshots and log captured |
| Android debug APK build | Passed |
| `git diff --check` | Passed |

Coverage counts executed/imported Dart source lines. It excludes Kotlin, Swift,
and Dart files that the test run did not import; it is not whole-repository
coverage. The API 24 emulator uses software rendering and is unusually slow.
Its geocoder cannot resolve network locations, so the integration test uses its
cached Chennai coordinates. The test still exercises the app and native
notification channel. The simulator is useful for assertions and flow checks,
not performance measurements.

## Fixes made for the candidate

- PR #4's record flow now closes the record sheet before presenting an unlocked
  achievement, removing the competing-dialog race.
- Tracker services reject writes and achievement progress changes when
  tracking is disabled, reject future-date records, and preserve a coherent
  year selection when statistics/history have no entries for the current year.
- Achievement text reads the active app language.
- Notification opt-out is read from the same native preferences used by
  Android settings. Language changes no longer re-schedule notifications after
  the user disables reminders; the native scheduler uses the shared preference
  file and keys.
- Android build tooling is checked in, so a clean checkout can invoke the
  declared Gradle wrapper instead of depending on an untracked local Gradle
  installation.

## Run the checks

```sh
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --coverage --reporter expanded
python3 tool/coverage_summary.py coverage/lcov.info
(cd android && ./gradlew app:testDebugUnitTest --console=plain)
flutter build apk --debug --target-platform android-x64
```

On an Android emulator named `emulator-5554` with Android SDK and Java 17:

```sh
bash tool/android-feature-integration.sh integration_test/tracker_android_test.dart
bash tool/android-feature-integration.sh integration_test/android_app_test.dart
```

The integration driver saves screen captures in
`build/ui-screenshots/android/` and device details/logs in
`build/android-feature-evidence/`. These scripts change app state and emulator
permissions; use a dedicated test emulator.

## Remaining validation before a production release

The combined candidate has passed its current automated gates on API 24. The
configured CI workflow adds Android API 33/35 and denied-permission/GPS-off
jobs, but has not run remotely. Samsung M52 and Z Flip 5 checks are still
needed for Samsung background restrictions, real location/geocoding, and
OEM-specific behavior. A Play Store v1-to-v2 upgrade and release-signed build
also require a device. No iOS or launcher-widget validation is claimed.

These limits do not block a controlled merge to `dev` for further testing;
they do block treating this as release validation. The separate
`feature/2027-telugu` redesign remains planning-only and is not included.

## PR conflict finding

GitHub shows PR #4 as conflicting because PR #5's widgets/search changes are
still on `dev`; the open PR #6 is the revert of PR #5. The local candidate
applies PR #6 first and then PR #4, which applies cleanly. This matches the
intended integration order. The accidental feature merge was PR #5; PR #6 is
Ragul's revert. Do not reintroduce PR #5's widgets/search change as part of
this integration; it has separate unresolved acceptance issues.
