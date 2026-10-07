"""Prints the UDID of an available iPhone simulator on the newest iOS runtime.

Usage: xcrun simctl list devices available -j | python3 tool/ios/pick_simulator.py
"""
import json
import sys


def main() -> None:
    devices = json.load(sys.stdin)["devices"]
    best = None
    for runtime, entries in devices.items():
        if ".iOS-" not in runtime:
            continue
        version = tuple(int(part) for part in runtime.split(".iOS-")[1].split("-"))
        for device in entries:
            if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
                # Prefer the newest runtime, then a "Pro" model for screenshots.
                key = (version, "Pro" in device["name"])
                if best is None or key > best[0]:
                    best = (key, device["udid"])
    if best is None:
        sys.exit("No available iPhone simulator")
    print(best[1])


if __name__ == "__main__":
    main()
