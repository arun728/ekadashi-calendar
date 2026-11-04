#!/usr/bin/env bash
# Reclaim unused SDKs only on disposable GitHub-hosted Android runners.
set -euo pipefail
if [[ ${GITHUB_ACTIONS:-} != true || ${RUNNER_OS:-} != Linux || ${RUNNER_ENVIRONMENT:-} != github-hosted ]]; then
  echo 'Cleanup requires a github-hosted Linux runner.' >&2
  exit 2
fi
workspace=${GITHUB_WORKSPACE:?Missing runner workspace}
available_kib() { df -Pk "$workspace" | awk 'NR == 2 { print $4 }'; }
# API 24 needs 7.4 GB for userdata, plus room for the system-image download.
minimum_kib=$((10 * 1024 * 1024))
available=$(available_kib)
if (( available < minimum_kib )); then
  # Android uses Java, Gradle, Flutter and the NDK; retain all four.
  sudo rm -rf /usr/share/dotnet /usr/local/.ghcup /opt/ghc /opt/hostedtoolcache/CodeQL
  available=$(available_kib)
fi
echo "Android runner available space: $available KiB"
if (( available < minimum_kib )); then
  echo 'At least 10 GiB is required before Android emulator setup.' >&2
  exit 1
fi
