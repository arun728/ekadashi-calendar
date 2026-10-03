#!/usr/bin/env bash
# Dedicated emulator only: installs test APK and changes app permissions.
set -euo pipefail
package_name=com.applausestudios.ekadashi_calendar
mode=${1:-granted}
output_dir=build/android-evidence
mkdir -p "$output_dir"
adb wait-for-device
api_level=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
if [[ "$mode" == denied ]] && (( api_level < 33 )); then
  echo 'The deterministic denied-permission fixture requires API33+; use the API35 CI matrix.' >&2
  exit 2
fi
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant "$package_name" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$package_name" android.permission.ACCESS_COARSE_LOCATION
if (( api_level >= 33 )); then
  adb shell pm grant "$package_name" android.permission.POST_NOTIFICATIONS
fi
adb shell settings put secure location_mode 3
adb emu geo fix 80.2707 13.0827
if [[ "$mode" == denied ]]; then
  adb shell pm revoke "$package_name" android.permission.ACCESS_FINE_LOCATION
  adb shell pm revoke "$package_name" android.permission.ACCESS_COARSE_LOCATION
  adb shell pm set-permission-flags "$package_name" android.permission.ACCESS_FINE_LOCATION user-set user-fixed
  adb shell pm set-permission-flags "$package_name" android.permission.ACCESS_COARSE_LOCATION user-set user-fixed
  if (( api_level >= 33 )); then
    adb shell pm revoke "$package_name" android.permission.POST_NOTIFICATIONS
    adb shell pm set-permission-flags "$package_name" android.permission.POST_NOTIFICATIONS user-set user-fixed
  fi
elif [[ "$mode" == gps-off ]]; then
  adb shell settings put secure location_mode 0
elif [[ "$mode" != granted ]]; then
  echo "Unsupported mode: $mode" >&2
  exit 2
fi
adb logcat -c
# Always capture diagnostics, including when assertions fail.
trap 'adb logcat -d > "$output_dir/logcat.txt"; adb exec-out screencap -p > "$output_dir/final-screen.png"; adb shell dumpsys package "$package_name" > "$output_dir/package.txt"; adb shell getprop > "$output_dir/device.txt"' EXIT
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/android_app_test.dart --dart-define=TEST_PERMISSION_MODE="$mode" --keep-app-running -d emulator-5554
# Return from the actual Android launcher, then capture the restored activity.
adb shell input keyevent KEYCODE_HOME
adb shell am start -W -n "$package_name/.MainActivity" > "$output_dir/resume.txt"
sleep 3
adb exec-out screencap -p > "$output_dir/resume.png"
adb shell pidof "$package_name" > "$output_dir/process.txt"
