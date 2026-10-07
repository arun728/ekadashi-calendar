#!/usr/bin/env bash
# Installs an APK on the emulator, retrying when adb install stalls or fails.
# CI emulators (notably API 24) sometimes hang an install until the timeout;
# restarting the adb server and waiting for the device lets a retry succeed.
# Usage: bash tool/adb-install-retry.sh path/to/app.apk
set -euo pipefail
apk=${1:?Pass the APK to install}
for attempt in 1 2 3; do
  if timeout 120 adb install --no-streaming -r "$apk"; then
    exit 0
  fi
  echo "adb install attempt $attempt of 3 failed or timed out: $apk" >&2
  if (( attempt < 3 )); then
    adb kill-server || true
    adb start-server
    timeout 120 adb wait-for-device
    timeout 120 bash -c 'until [[ "$(adb shell getprop sys.boot_completed | tr -d "\r")" == 1 ]]; do sleep 2; done'
  fi
done
exit 1
