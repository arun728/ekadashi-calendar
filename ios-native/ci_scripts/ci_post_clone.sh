#!/bin/sh
# Xcode Cloud starts here after cloning and before resolving/building the project.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$script_dir/../.." && pwd)}
ios_dir="$repo_root/ios-native"

if [ ! -f "$ios_dir/project.yml" ]; then
    echo "Xcode Cloud bootstrap: missing $ios_dir/project.yml" >&2
    exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Xcode Cloud bootstrap: install XcodeGen or provide Homebrew." >&2
        exit 1
    fi
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install xcodegen
fi

cd "$ios_dir"
xcodegen generate --spec project.yml

for generated_file in \
    EkadashiCalendar.xcodeproj/project.pbxproj \
    EkadashiCalendar.xcodeproj/xcshareddata/xcschemes/EkadashiCalendar.xcscheme
do
    if [ ! -f "$generated_file" ]; then
        echo "Xcode Cloud bootstrap: missing generated $generated_file" >&2
        exit 1
    fi
done
