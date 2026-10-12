#!/usr/bin/env bash
# Run from the matching isolated feature checkout on a dedicated emulator.
set -euo pipefail
test_target=${1:?Pass the integration_test target for this candidate}
package_name=com.applausestudios.ekadashi_calendar
apk_path=build/app/outputs/flutter-apk/app-debug.apk
output_dir=build/android-feature-evidence/$(basename "$test_target" .dart)
mkdir -p "$output_dir"
flutter build apk --debug --target-platform android-x64 --target "$test_target"
timeout 120 adb wait-for-device
bash tool/adb-install-retry.sh "$apk_path"
adb shell pm grant "$package_name" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$package_name" android.permission.ACCESS_COARSE_LOCATION
api_level=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
if (( api_level >= 33 )); then
  adb shell pm grant "$package_name" android.permission.POST_NOTIFICATIONS
fi
adb shell settings put secure location_mode 3
adb emu geo fix 80.2707 13.0827
adb logcat -c
trap 'adb logcat -d > "$output_dir/logcat.txt"; adb exec-out screencap -p > "$output_dir/final-screen.png"; adb shell getprop > "$output_dir/device.txt"; adb shell dumpsys package "$package_name" > "$output_dir/package.txt"' EXIT
# Attach to the exact pre-granted binary without a second streamed install.
# Retries clear app data and restore the grants above (see the drive script).
ANDROID_FRESH_RETRY=granted bash tool/android-drive-installed.sh "$test_target" "$output_dir"
