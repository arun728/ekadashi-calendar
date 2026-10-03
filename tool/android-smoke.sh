#!/usr/bin/env bash
# Run only on a dedicated emulator/test device. Requires a debug APK and adb.
# Checks process health and captures evidence; it does not assert rendered content.
set -euo pipefail
apk_path=${1:?Usage: android-smoke.sh debug.apk [output-directory]}
output_dir=${2:-android-smoke-evidence}
package_name=com.applausestudios.ekadashi_calendar
mkdir -p "$output_dir"
adb wait-for-device
adb install -r "$apk_path"
# Prevent initial permission dialogs from blocking the smoke run.
adb shell pm grant "$package_name" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$package_name" android.permission.ACCESS_COARSE_LOCATION
api_level=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
if (( api_level >= 33 )); then
  adb shell pm grant "$package_name" android.permission.POST_NOTIFICATIONS
fi
adb logcat -c
adb shell am force-stop "$package_name"
adb shell am start -W -n "$package_name/.MainActivity" > "$output_dir/launch.txt"
# Allow native GPS timeout/fallback and Flutter startup to complete.
for ((tick=0; tick<40; tick++)); do
  if ! adb shell pidof "$package_name" >/dev/null; then
    adb logcat -d > "$output_dir/logcat.txt"
    echo 'App process exited during startup' >&2
    exit 1
  fi
  sleep 1
done
adb exec-out screencap -p > "$output_dir/cold-start.png"
adb shell input keyevent KEYCODE_HOME
adb shell am start -W -n "$package_name/.MainActivity" > "$output_dir/resume.txt"
sleep 2
adb exec-out screencap -p > "$output_dir/resume.png"
adb logcat -d > "$output_dir/logcat.txt"
adb shell dumpsys activity activities > "$output_dir/activities.txt"
adb shell dumpsys package "$package_name" > "$output_dir/package.txt"
if ! adb shell pidof "$package_name" >/dev/null; then
  echo 'App process exited after resume' >&2
  exit 1
fi
if rg -q 'FATAL EXCEPTION|Unhandled Exception|EXCEPTION CAUGHT BY (WIDGETS|RENDERING) LIBRARY' "$output_dir/logcat.txt"; then
  echo 'Runtime exception found; inspect logcat.txt' >&2
  exit 1
fi
echo "Process smoke passed; review screenshots in $output_dir. UI correctness remains a separate gate."
