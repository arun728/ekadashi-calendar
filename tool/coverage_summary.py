#!/usr/bin/env python3
"""Report instrumented Dart line coverage; no native coverage claim."""
import pathlib
import sys
covered = total = 0
rows = []
for section in pathlib.Path(sys.argv[1]).read_text().split('end_of_record'):
    name = next((line[3:] for line in section.splitlines() if line.startswith('SF:')), None)
    hits = [int(line.split(',')[1]) for line in section.splitlines() if line.startswith('DA:')]
    if name and hits:
        count = sum(hit > 0 for hit in hits)
        rows.append((name, count, len(hits)))
        covered += count
        total += len(hits)
for name, count, length in rows:
    print(f'{count:4}/{length:<4} {100*count/length:6.2f}% {name}')
print(f'TOTAL {covered}/{total} {100*covered/total if total else 0:.2f}% instrumented Dart lines')
