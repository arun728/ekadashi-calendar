"""Validate the generated targets, including XcodeGen's device defaults."""

import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
IPAD_ORIENTATIONS = {
    "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
    "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight",
}


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("xcodegen"),
                     "Requires macOS and XcodeGen")
class IOSDeviceConfigurationTests(unittest.TestCase):
    def test_generated_app_device_families_match_supported_orientations(self):
        with tempfile.TemporaryDirectory() as temp:
            ios = Path(temp) / "ios-native"
            shutil.copytree(ROOT / "ios-native", ios, ignore=shutil.ignore_patterns(
                ".build", ".swiftpm", "*.xcodeproj", "build"))
            subprocess.run(["xcodegen", "generate", "--spec", str(ios / "project.yml")],
                           cwd=ios, check=True, capture_output=True, text=True)
            project = json.loads(subprocess.check_output([
                "plutil", "-convert", "json", "-o", "-",
                str(ios / "EkadashiCalendar.xcodeproj/project.pbxproj")]))
            objects = project["objects"]
            app = next(o for o in objects.values()
                       if o.get("isa") == "PBXNativeTarget" and o["name"] == "EkadashiCalendar")
            configurations = objects[app["buildConfigurationList"]]["buildConfigurations"]
            info = plistlib.loads((ios / "EkadashiCalendar/Info.plist").read_bytes())
            for identifier in configurations:
                config = objects[identifier]
                families = str(config["buildSettings"]["TARGETED_DEVICE_FAMILY"]).split(",")
                with self.subTest(configuration=config["name"], families=families):
                    self.assertEqual(set(families), {"1", "2"})
                    self.assertEqual(info["UISupportedInterfaceOrientations"],
                                     ["UIInterfaceOrientationPortrait"])
                    if "2" in families:
                        orientations = info.get("UISupportedInterfaceOrientations~ipad",
                                                info["UISupportedInterfaceOrientations"])
                        self.assertEqual(set(orientations), IPAD_ORIENTATIONS,
                                         "iPad multitasking requires all four orientations (ITMS-90474)")


if __name__ == "__main__":
    unittest.main()
