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
result=0
bash tool/android-integration.sh "$mode" || result=$?
if [[ "$mode" == granted ]]; then
  while read -r target; do
    if bash tool/android-feature-integration.sh "$target"; then
      if [[ "$target" == integration_test/multi_year_android_test.dart ]]; then
        bash tool/android-launcher-widgets.sh || result=$?
      fi
    else
      result=$?
    fi
  done < <(targets)
fi
exit "$result"
