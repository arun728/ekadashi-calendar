#!/usr/bin/env bash
# Run one step of the device billing harness on a paired iPhone (App Store sandbox).
#   IOS_DEVICE=<id> tool/release/ios-device-step.sh ACTION
# ACTION: look, monthly, yearly, lifetime, restore, manage, manage-cancel,
#         manage-resub, settings, legal (see tool/release/ios/DeviceBillingUITests.swift).
# The harness is copied into the UI test target only for this run, then removed,
# so it never runs in the normal UI suite. It never types a password: Apple's
# purchase sheet and Face ID are confirmed by hand on the phone.
set -euo pipefail
action=${1:?usage: ios-device-step.sh ACTION}
if [[ -z "${IOS_DEVICE:-}" ]]; then
  echo "Set IOS_DEVICE to the iPhone's id (xcrun xctrace list devices)." >&2
  exit 2
fi
root=$(cd "$(dirname "$0")/../.." && pwd)
out=${OUT_DIR:-$root/build/device-steps}
derived=${DERIVED_DATA:-$root/build/ios-device-tests}
target="$root/ios-native/EkadashiCalendarUITests/DeviceBillingUITests.swift"
cleanup() { rm -f "$target"; (cd "$root/ios-native" && xcodegen generate --quiet) || true; }
trap cleanup EXIT
cp "$root/tool/release/ios/DeviceBillingUITests.swift" "$target"
cd "$root/ios-native"
xcodegen generate --quiet
mkdir -p "$out"
name="$action-$(date +%H%M%S)"
set +e
TEST_RUNNER_ACTION=$action xcodebuild test -project EkadashiCalendar.xcodeproj -scheme EkadashiCalendar \
  -destination "id=$IOS_DEVICE" -derivedDataPath "$derived" -allowProvisioningUpdates \
  -resultBundlePath "$out/$name.xcresult" \
  -only-testing:EkadashiCalendarUITests/DeviceBillingUITests > "$out/$name.log" 2>&1
status=$?
set -e
mkdir -p "$out/$name"
xcrun xcresulttool export attachments --path "$out/$name.xcresult" --output-path "$out/$name" > /dev/null 2>&1 || true
grep -E "DEVLOG" "$out/$name.log" | cut -c1-500 || true
echo "EXIT $status; screenshots in $out/$name"
exit $status
