#!/bin/bash
# Rebuild lib/services/time_zone_data.dart from an IANA tz release.
# Usage: tool/time_zones/update.sh 2026b
# Needs curl, make, zic, gpg and Dart. Uses the timezone package's own
# encoder (tool/encode_tzf.dart) so the format matches the package.
set -euo pipefail
release=${1:?release, for example 2026b}
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
curl -sSfL -o tzdata.tar.gz "https://data.iana.org/time-zones/releases/tzdata$release.tar.gz"
curl -sSfL -o tzdata.tar.gz.asc "https://data.iana.org/time-zones/releases/tzdata$release.tar.gz.asc"
export GNUPGHOME="$work/gnupg"; mkdir -m 700 "$GNUPGHOME"
curl -sSfL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x7E3792A9D8ACF7D633BC1588ED97E90E62AA7E34" | gpg --import
gpg --verify tzdata.tar.gz.asc tzdata.tar.gz   # Paul Eggert, tz coordinator
mkdir src && tar -xzf tzdata.tar.gz -C src
make -C src rearguard.zi >/dev/null
mkdir zoneinfo && zic -d zoneinfo -b fat src/rearguard.zi
package=$(cd "$root" && dart pub deps --json | python3 -c "import json,sys; d=json.load(sys.stdin); print([p for p in d['packages'] if p['name']=='timezone'][0]['version'])")
cp -r "$HOME/.pub-cache/hosted/pub.dev/timezone-$package" pkg
(cd pkg && dart pub get >/dev/null && dart tool/encode_tzf.dart --zoneinfo "$work/zoneinfo" >/dev/null)
python3 "$root/tool/time_zones/embed.py" "$release" pkg/lib/data/latest_all.tzf "$root/lib/services/time_zone_data.dart"
