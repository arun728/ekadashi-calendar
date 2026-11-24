#!/usr/bin/env bash
# SHOTS-ONLY: run one capture session on the store emulator. Never targets a phone.
# Usage: rec-android.sh <session jan|oct> <ISO local time, IST> <out dir>
set -uo pipefail
export ANDROID_SERIAL=emulator-5554
S=$1; AT=$2; OUT=$3; mkdir -p "$OUT"
PKG=com.applausestudios.ekadashi_calendar
ms=$(python3 -c "import datetime as d;print(int(d.datetime.fromisoformat('$AT+05:30').timestamp()*1000))")
adb shell settings put global auto_time 0
adb shell cmd alarm set-time "$ms"
adb emu geo fix 77.2090 28.6139 >/dev/null
# Clean status bar: SystemUI demo mode.
adb shell settings put global sysui_demo_allowed 1
b() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
b enter; b clock -e hhmm "$(python3 -c "print('$AT'[11:13]+'$AT'[14:16])")"
b battery -e level 100 -e plugged false; b network -e wifi show -e level 4 -e fully true
b network -e mobile hide; b notifications -e visible false
adb uninstall $PKG >/dev/null 2>&1; adb logcat -c
LOG=$OUT/drive-$S.log
flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart \
  --target=integration_test/store_shots_android_test.dart --dart-define=SHOTS_PREMIUM=yearly \
  --dart-define=SHOTS_SESSION=$S --no-pub > "$LOG" 2>&1 &
DRIVE=$!
# flutter drive reinstalls the app, which drops grants: keep granting until held.
( for i in $(seq 1 180); do
    for perm in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS; do
      adb shell pm grant $PKG android.permission.$perm 2>/dev/null; done
    adb shell dumpsys package $PKG 2>/dev/null | grep -q "ACCESS_FINE_LOCATION: granted=true" && \
      adb shell dumpsys package $PKG 2>/dev/null | grep -q "POST_NOTIFICATIONS: granted=true" && [ -n "$(adb shell pidof $PKG | tr -d "\r")" ] && [ $i -gt 15 ] && break
    sleep 0.5; done ) &
seen=0
while kill -0 $DRIVE 2>/dev/null; do
  n=$(grep -c "SHOT:" "$LOG")
  while [ "$seen" -lt "$n" ]; do
    seen=$((seen+1)); name=$(grep -o "SHOT:[a-z0-9-]*" "$LOG" | sed -n "${seen}p" | cut -d: -f2)
    adb exec-out screencap -p > "$OUT/$name.png"; echo "captured $name"
  done
  sleep 0.3
done
grep -E "MISSING:|All tests passed|Some tests failed|EXCEPTION" "$LOG" | head -20
