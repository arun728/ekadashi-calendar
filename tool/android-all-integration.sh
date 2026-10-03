#!/usr/bin/env bash
# Collect every present candidate's evidence; preserve any failed release gate.
set -euo pipefail
mode=${1:-granted}
result=0
bash tool/android-integration.sh "$mode" || result=$?
if [[ "$mode" == granted ]]; then
  for target in integration_test/tracker_android_test.dart integration_test/search_android_test.dart; do
    if [[ -f "$target" ]]; then
      bash tool/android-feature-integration.sh "$target" || result=$?
    fi
  done
fi
exit "$result"
