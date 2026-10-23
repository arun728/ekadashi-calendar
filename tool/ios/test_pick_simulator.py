"""Tests for pick_simulator.py: python3 -m unittest discover -s tool/ios -p 'test_*.py'"""
import io
import json
import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("pick_simulator.py")

DEVICES = {
    "devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-26-0": [
            {"name": "iPhone 17 Pro", "udid": "OLD-PRO", "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
            {"name": "iPhone 17", "udid": "NEW-PLAIN", "isAvailable": True},
            {"name": "iPhone 17 Pro", "udid": "NEW-PRO", "isAvailable": True},
            {"name": "iPhone Duo", "udid": "NEW-DUO", "isAvailable": True},
            {"name": "iPad Pro", "udid": "IPAD", "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.watchOS-12-0": [
            {"name": "iPhone Duo", "udid": "NOT-IOS", "isAvailable": True},
        ],
    }
}


def run(devices, *args):
    return subprocess.run([sys.executable, str(SCRIPT), *args], input=json.dumps(devices),
                          capture_output=True, text=True)


class PickSimulatorTest(unittest.TestCase):
    def test_default_is_the_newest_pro_iphone(self):
        result = run(DEVICES)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "NEW-PRO")

    def test_prefer_picks_the_named_model_on_the_newest_runtime(self):
        result = run(DEVICES, "--prefer", "iPhone Duo")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "NEW-DUO")

    def test_prefer_without_that_model_exits_with_3_and_prints_nothing(self):
        devices = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-0": [
            {"name": "iPhone 17 Pro", "udid": "OLD-PRO", "isAvailable": True}]}}
        result = run(devices, "--prefer", "iPhone Duo")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(result.stdout, "")

    def test_unavailable_devices_are_skipped(self):
        devices = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
            {"name": "iPhone Duo", "udid": "BROKEN", "isAvailable": False},
            {"name": "iPhone 17", "udid": "OK", "isAvailable": True}]}}
        self.assertEqual(run(devices, "--prefer", "iPhone Duo").returncode, 3)
        self.assertEqual(run(devices).stdout.strip(), "OK")


if __name__ == "__main__":
    unittest.main()
