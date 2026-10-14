#!/usr/bin/env bash
# Regenerates every checked-in generated file and fails when any differs from
# the commit: a translation or resource change without its regeneration.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/generate_localized_lookup.py
# The generator writes long lines; the checked-in file is dart-formatted.
dart format lib/l10n/localized_lookup.dart > /dev/null
flutter gen-l10n
python3 tool/ios/generate_core_resources.py > /dev/null
if ! git diff --exit-code --stat -- lib/l10n ios-native/EkadashiCore/Sources/EkadashiCore/Resources; then
  echo "::error::Generated files are out of date. Run tool/check-generated.sh and commit the result."
  git diff -- lib/l10n ios-native/EkadashiCore/Sources/EkadashiCore/Resources | head -200
  exit 1
fi
echo "Generated files are up to date."
