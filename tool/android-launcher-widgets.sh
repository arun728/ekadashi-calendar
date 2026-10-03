#!/usr/bin/env bash
# Dedicated stock-launcher emulator only: clears Launcher3, never personal devices.
# Run after multi_year_android_test.dart creates databases/widget-fixture-{en,ta,hi,te}.json.
set -euo pipefail
output_dir=build/android-widget-evidence
package_name=com.applausestudios.ekadashi_calendar
mkdir -p "$output_dir"
flutter build apk --debug --target-platform android-x64 --target lib/main.dart
adb install -r build/app/outputs/flutter-apk/app-debug.apk
./android/gradlew -p android app:assembleDebugAndroidTest -Ptarget-platform=android-x64 -Ptarget=lib/main.dart --console=plain
adb install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb logcat -c
trap 'adb logcat -d > "$output_dir/logcat.txt"; adb pull "/sdcard/Android/data/$package_name/files/widget-evidence/." "$output_dir/" >/dev/null || true' EXIT
adb shell am instrument -w "$package_name.test/androidx.test.runner.AndroidJUnitRunner" | tee "$output_dir/instrumentation.txt"
# adb shell can return exit zero even when AndroidJUnit reports failures.
rg -q 'OK \(3 tests\)' "$output_dir/instrumentation.txt"
! rg -q 'FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed' "$output_dir/instrumentation.txt"
