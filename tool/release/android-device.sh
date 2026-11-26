#!/usr/bin/env bash
# Drive a real Android phone or emulator over adb.
#   ADB_SERIAL=<serial from `adb devices`> tool/release/android-device.sh shot NAME   screenshot (full and half size)
#   ADB_SERIAL=... tool/release/android-device.sh ui                                   labelled nodes with bounds
#   ADB_SERIAL=... tool/release/android-device.sh tap X Y
#   ADB_SERIAL=... tool/release/android-device.sh <any adb arguments>
# Screenshots go to OUT_DIR (default build/device-shots).
set -euo pipefail
if [[ -z "${ADB_SERIAL:-}" ]]; then
  echo "Set ADB_SERIAL to a serial from 'adb devices'." >&2
  exit 2
fi
here=$(cd "$(dirname "$0")" && pwd)
out=${OUT_DIR:-build/device-shots}
python=${PYTHON:-python3}
case "${1:-}" in
  shot)
    mkdir -p "$out"
    adb -s "$ADB_SERIAL" exec-out screencap -p > "$out/$2.png"
    "$python" -c "from PIL import Image; im=Image.open('$out/$2.png'); im.resize((im.width//2, im.height//2)).save('$out/$2-s.png')" 2>/dev/null \
      || cp "$out/$2.png" "$out/$2-s.png"
    echo "$out/$2-s.png" ;;
  ui)
    adb -s "$ADB_SERIAL" shell uiautomator dump /sdcard/ui.xml > /dev/null
    adb -s "$ADB_SERIAL" exec-out cat /sdcard/ui.xml | "$python" "$here/android_ui.py" ;;
  tap)
    adb -s "$ADB_SERIAL" shell input tap "$2" "$3" ;;
  *)
    adb -s "$ADB_SERIAL" "$@" ;;
esac
