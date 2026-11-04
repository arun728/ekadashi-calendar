#!/usr/bin/env bash
# Source this before installing the EXIT trap in an emulator test wrapper.
capture_android_evidence() {
  local test_result=$1 output_dir=$2 package_name=$3
  local deadline=${ANDROID_EVIDENCE_TIMEOUT_SECONDS:-10}
  local capture_result=0
  if [[ ! "$deadline" =~ ^([1-9]|[12][0-9]|30)$ ]]; then
    echo 'Invalid Android capture timeout; expected 1 to 30 seconds.' >&2
    if (( test_result != 0 )); then exit "$test_result"; else exit 2; fi
  fi
  # A disconnected emulator must not block every remaining suite while the
  # failure trap waits forever for adb. Retain partial output when possible.
  timeout --kill-after=2s "$deadline" adb logcat -d > "$output_dir/logcat.txt" || { echo 'Android diagnostic failed or timed out: logcat' >&2; capture_result=1; }
  timeout --kill-after=2s "$deadline" adb exec-out screencap -p > "$output_dir/final-screen.png" || { echo 'Android diagnostic failed or timed out: screenshot' >&2; capture_result=1; }
  timeout --kill-after=2s "$deadline" adb shell getprop > "$output_dir/device.txt" || { echo 'Android diagnostic failed or timed out: device properties' >&2; capture_result=1; }
  timeout --kill-after=2s "$deadline" adb shell dumpsys package "$package_name" > "$output_dir/package.txt" || { echo 'Android diagnostic failed or timed out: package' >&2; capture_result=1; }
  # Diagnostic errors must never replace an assertion/driver failure. A
  # passing suite still needs its diagnostic evidence to be collected.
  if (( test_result == 0 )); then test_result=$capture_result; fi
  exit "$test_result"
}
