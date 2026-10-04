#!/usr/bin/env bash
# Collect every present candidate's evidence; preserve any failed release gate.
set -euo pipefail
mode=${1:-granted}
result=0
bash tool/android-integration.sh "$mode" || result=$?
if [[ "$mode" == granted ]]; then
  for target in integration_test/tracker_android_test.dart integration_test/multi_year_android_test.dart integration_test/search_android_test.dart integration_test/premium_android_test.dart; do
    if [[ -f "$target" ]]; then
      if bash tool/android-feature-integration.sh "$target"; then
        if [[ "$target" == integration_test/multi_year_android_test.dart ]]; then
          bash tool/android-launcher-widgets.sh || result=$?
        fi
      else
        result=$?
      fi
    fi
  done
fi
bash tool/android-feature-integration.sh integration_test/daily_devotion_android_test.dart "$mode" || result=$?
exit "$result"
