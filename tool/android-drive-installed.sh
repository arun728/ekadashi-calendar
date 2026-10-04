#!/usr/bin/env bash
# Attach to the exact APK already installed/granted by the dedicated-emulator runner.
# Flutter drive otherwise installs it again, which can stall streamed installs on API24.
set -euo pipefail
test_target=${1:?Pass the installed integration-test target}
output_dir=${2:?Pass the evidence directory}
package_name=com.applausestudios.ekadashi_calendar
mkdir -p "$output_dir"
attempts=${ANDROID_VM_WAIT_ATTEMPTS:-90}
[[ "$attempts" =~ ^[0-9]+$ ]] && (( attempts >= 1 && attempts <= 300 ))
timeout 30 adb shell am force-stop "$package_name"
timeout 15 adb logcat -c
# Start paused without -W: Android's first-frame wait cannot complete until the
# integration driver resumes Dart. Poll the VM service below for readiness.
timeout 60 adb shell am start -n "$package_name/.MainActivity" \
  --ez enable-checked-mode true --ez verify-entry-points true --ez start-paused true \
  > "$output_dir/driver-launch.txt"
endpoint=''
for ((attempt=0; attempt<attempts; attempt++)); do
  timeout 15 adb logcat -d -s flutter:I FlutterJNI:I > "$output_dir/driver-vm-logcat.txt"
  endpoint=$(python3 - "$output_dir/driver-vm-logcat.txt" <<'PY'
import re,sys
from pathlib import Path
matches=re.findall(r'http://127\.0\.0\.1:(\d+)(/[^\s]*)',Path(sys.argv[1]).read_text())
if matches:print(*matches[-1])
PY
  )
  if [[ -n "$endpoint" ]]; then break; fi
  if ((attempt+1<attempts)); then sleep 1; fi
 done
if [[ -z "$endpoint" ]]; then
  echo 'Installed app did not expose a Dart VM service before the deadline.' >&2
  exit 1
fi
read -r device_port device_path <<< "$endpoint"
host_port=$(timeout 15 adb forward tcp:0 "tcp:$device_port" | tr -d '\r')
[[ "$host_port" =~ ^[0-9]+$ ]]
trap 'timeout 10 adb forward --remove "tcp:$host_port" >/dev/null 2>&1 || true' EXIT
# The standard integration driver still receives every assertion and screenshot.
# Preserve nonzero results; a timeout is a failed gate, never a passing retry.
timeout --kill-after=10s 900s flutter drive \
  --driver=test_driver/integration_test.dart --target="$test_target" \
  --use-existing-app="http://127.0.0.1:$host_port$device_path" \
  --keep-app-running -d emulator-5554
