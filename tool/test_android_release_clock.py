#!/usr/bin/env python3
"""Check a built Android APK; the lifecycle test clock must not ship."""

import argparse
from pathlib import Path
from zipfile import ZipFile

TOKENS = (
    b"EKADASHI_ANDROID_TEST_CLOCK",
    b"Android lifecycle screenshots and exact boundaries",
    b"android-home-midnight-countdown",
)


def audit(path, debug=False):
    with ZipFile(path) as apk:
        blobs = [
            apk.read(name)
            for name in apk.namelist()
            if name.endswith((".so", ".dill", "kernel_blob.bin"))
        ]
    assert blobs, "No Dart app binaries found"
    found = {token for token in TOKENS if any(token in blob for blob in blobs)}
    if debug:
        assert found == set(TOKENS), f"Debug positive control missing {set(TOKENS) - found}"
    else:
        assert not found, f"Debug test clock leaked: {found}"
    label = "Debug positive control" if debug else "Release exclusion"
    print(f"{label} passed: {len(blobs)} binaries")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()
    audit(args.apk, args.debug)
