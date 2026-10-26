#!/usr/bin/env python3
"""Audit built app/extension binaries: simulation controls must not ship."""
import argparse
from pathlib import Path

TOKENS = [b'EKADASHI_LIFECYCLE_TEST_CLOCK', b'EKADASHI_UI_TEST_NOW', b'EKADASHI_TEST_RATE',
          b'debug_lifecycle_snapshot', b'settings_test_clock', b'test_clock_before_end',
          b'Lifecycle test clock']

def audit(app: Path, debug: bool = False):
    binaries = [p for p in app.rglob('*') if p.is_file() and
                (p.name in ('EkadashiCalendar', 'EkadashiWidgets') or p.suffix == '.dylib')]
    assert binaries, f'No app binaries in {app}'
    found = set()
    for binary in binaries:
        data = binary.read_bytes()
        present = {token for token in TOKENS if token in data}
        found |= present
        if not debug:
            assert not present, f'Debug-only simulation leaked into {binary}: {present}'
    if debug:
        assert set(TOKENS) <= found, f'Debug positive control missing: {set(TOKENS) - found}'
    print(f'{"Debug positive control" if debug else "Release exclusion"} passed: {len(binaries)} binaries')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()
    audit(args.app, args.debug)
