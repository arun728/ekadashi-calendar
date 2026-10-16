#!/usr/bin/env bash
# Collect every present candidate's evidence; preserve any failed release gate.
# Every integration_test/*_android_test.dart runs in granted mode, so a new
# device test cannot be forgotten. --list prints them without running.
set -euo pipefail
cd "$(dirname "$0")/.."
# App data carries over between targets: keep the proven order first.
first=(tracker multi_year premium)
targets() {
  for name in "${first[@]}"; do
    [[ -f "integration_test/${name}_android_test.dart" ]] && echo "integration_test/${name}_android_test.dart"
  done
  for target in integration_test/*_android_test.dart; do
    name=$(basename "$target" _android_test.dart)
    [[ "$name" == android_app || " ${first[*]} " == *" $name "* ]] || echo "$target"
  done | sort
}
if [[ "${1:-}" == --list ]]; then
  targets
  exit 0
fi
mode=${1:-granted}
# Overridable for test/tool/test_ci_workflow.py.
app_runner=${ANDROID_APP_RUNNER:-tool/android-integration.sh}
feature_runner=${ANDROID_FEATURE_RUNNER:-tool/android-feature-integration.sh}
widget_runner=${ANDROID_WIDGET_RUNNER:-tool/android-launcher-widgets.sh}
result=0
bash "$app_runner" "$mode" || result=$?
if [[ "$mode" == granted ]]; then
  # Read the list first: adb and flutter read stdin, so a `while read` loop
  # would lose every target after the first.
  mapfile -t all < <(targets)
  for target in "${all[@]}"; do
    if bash "$feature_runner" "$target"; then
      if [[ "$target" == integration_test/multi_year_android_test.dart ]]; then
        bash "$widget_runner" || result=$?
      fi
    else
      result=$?
    fi
  done
fi
exit "$result"
