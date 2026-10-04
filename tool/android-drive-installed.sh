#!/usr/bin/env bash
# Attach to the exact APK installed and permission-granted by the emulator job.
# Never reinstall it or accept a stale VM service from a previous test process.
set -euo pipefail
test_target=${1:?Pass the installed integration-test target}
output_dir=${2:?Pass the evidence directory}
package_name=com.applausestudios.ekadashi_calendar
mkdir -p "$output_dir"
wait_attempts=${ANDROID_VM_WAIT_ATTEMPTS:-90}
[[ "$wait_attempts" =~ ^[0-9]+$ ]] && (( wait_attempts >= 1 && wait_attempts <= 300 ))
vm_host_port=''
cleanup_forward() {
  if [[ -n "$vm_host_port" ]]; then
    timeout 10 adb forward --remove "tcp:$vm_host_port" >/dev/null 2>&1 || true
    vm_host_port=''
  fi
}
trap cleanup_forward EXIT

for drive_attempt in 1 2; do
  # A short emulator disconnect after Flutter's VM transport closes is recoverable.
  timeout 120 adb wait-for-device
  timeout 30 adb shell am force-stop "$package_name"
  timeout 15 adb logcat -c
  # -W waits for the first frame, but the entry isolate is paused until driven.
  timeout 60 adb shell am start -n "$package_name/.MainActivity" \
    --ez enable-checked-mode true --ez verify-entry-points true --ez start-paused true \
    > "$output_dir/driver-launch-$drive_attempt.txt"

  vm_ready=false
  for ((vm_wait=0; vm_wait<wait_attempts; vm_wait++)); do
    app_pid=$(timeout 5 adb shell pidof "$package_name" 2>/dev/null || true)
    app_pid=${app_pid%% *}
    if [[ "$app_pid" =~ ^[0-9]+$ ]]; then
      timeout 15 adb logcat -d --pid="$app_pid" -s flutter:I FlutterJNI:I \
        > "$output_dir/driver-vm-logcat-$drive_attempt.txt"
      vm_endpoint=$(python3 - "$output_dir/driver-vm-logcat-$drive_attempt.txt" <<'PY'
import re
import sys
from pathlib import Path

matches = re.findall(
    r'http://127\.0\.0\.1:(\d+)(/[^\s]*)',
    Path(sys.argv[1]).read_text(errors='replace'),
)
if matches:
    print(*matches[-1])
PY
      )
      if [[ -n "$vm_endpoint" ]]; then
        read -r device_port device_path <<< "$vm_endpoint"
        cleanup_forward
        vm_host_port=$(timeout 15 adb forward tcp:0 "tcp:$device_port" | tr -d '\r')
        [[ "$vm_host_port" =~ ^[0-9]+$ ]]
        vm_url="http://127.0.0.1:$vm_host_port$device_path"
        if python3 tool/android_vm_service.py ready "$vm_url" "$test_target"; then
          vm_ready=true
          break
        fi
        cleanup_forward
      fi
    fi
    if (( vm_wait+1 < wait_attempts )); then sleep 1; fi
  done
  if [[ "$vm_ready" != true ]]; then
    echo 'Installed test did not expose a live matching Dart VM service before the deadline.' >&2
    exit 1
  fi

  drive_log="$output_dir/driver-$drive_attempt.txt"
  if timeout --kill-after=10s 900s flutter drive \
    --driver=test_driver/integration_test.dart --target="$test_target" \
    --use-existing-app="$vm_url" --keep-app-running -d emulator-5554 \
    2>&1 | tee "$drive_log"; then
    cleanup_forward
    exit 0
  else
    drive_result=${PIPESTATUS[0]}
  fi
  cleanup_forward
  if (( drive_attempt == 1 )) && python3 tool/android_vm_service.py retry "$drive_log"; then
    echo 'Test assertions passed but result transport closed; relaunching once to verify them again.'
  else
    exit "$drive_result"
  fi
done
