#!/bin/bash
# Materialize the entire supported range before encoding into TZF, whose
# format has no POSIX recurring-rule footer. Pad both ends for Panchang's
# neighbouring-day calculations. The lower cutoff also supplies an explicit
# initial offset, preserving history through the timezone encoder's filter.
set -euo pipefail
source_file=${1:?IANA source file, for example rearguard.zi}
output_dir=${2:?output zoneinfo directory}
mkdir -p "$output_dir"
"${ZIC:-zic}" -b fat -r @-2240524800/@4165516800 -d "$output_dir" "$source_file"
