#!/usr/bin/env bash
# Separate package/data sandbox: this cannot replace the Play Store installation.
set -euo pipefail
ORG_GRADLE_PROJECT_glassPreview=true flutter build apk --profile --target-platform android-arm64
mkdir -p build/glass-preview
cp build/app/outputs/flutter-apk/app-profile.apk build/glass-preview/ekadashi-glass-preview-arm64.apk
