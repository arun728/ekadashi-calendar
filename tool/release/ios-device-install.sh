#!/usr/bin/env bash
# Build the iOS app (Debug, App Store sandbox) and install it on a paired iPhone.
#   tool/release/ios-device-install.sh            first paired, available iPhone
#   IOS_DEVICE=<id> tool/release/ios-device-install.sh
# IOS_DEVICE is the xcodebuild destination id (`xcrun xctrace list devices`).
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
derived=${DERIVED_DATA:-$root/build/ios-device}
if [[ -z "${IOS_DEVICE:-}" ]]; then
  IOS_DEVICE=$(xcrun xctrace list devices 2>/dev/null | awk '/^== Devices ==/{d=1;next} /^==/{d=0} d && /iPhone/ && !/Simulator/' \
    | sed -E 's/.*\(([0-9A-Fa-f-]+)\)$/\1/' | head -1)
fi
if [[ -z "$IOS_DEVICE" ]]; then
  echo "No paired iPhone found; connect it or set IOS_DEVICE." >&2
  exit 2
fi
cd "$root/ios-native"
xcodebuild build -project EkadashiCalendar.xcodeproj -scheme EkadashiCalendar -configuration Debug \
  -destination "id=$IOS_DEVICE" -derivedDataPath "$derived" -allowProvisioningUpdates > "$derived.log" 2>&1 \
  || { grep -E "error:" "$derived.log" | head; echo "Build failed; see $derived.log" >&2; exit 1; }
xcrun devicectl device install app --device "$IOS_DEVICE" "$derived/Build/Products/Debug-iphoneos/EkadashiCalendar.app"
echo "Installed on $IOS_DEVICE"
