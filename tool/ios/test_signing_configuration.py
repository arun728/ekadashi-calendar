"""Guard the generated iOS project's Apptinel identity and widget sharing.

Run with python3 tool/ios/test_signing_configuration.py (requires XcodeGen).
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import unittest


IOS = Path(__file__).resolve().parents[2] / "ios-native"
GROUP = "group.com.apptinel.ekadashi-calendar"
BUNDLE = "com.apptinel.ekadashi-calendar"


class SigningConfigurationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads(subprocess.check_output(
            ["xcodegen", "dump", "--type", "json", "--no-env"], cwd=IOS
        ))

    def test_generated_app_and_widget_use_apptinel_bundle_identifiers(self):
        for name, expected in [("EkadashiCalendar", BUNDLE),
                               ("EkadashiWidgets", BUNDLE + ".widgets")]:
            with self.subTest(target=name):
                target = self.spec["targets"][name]
                self.assertEqual(target["settings"]["base"]["PRODUCT_BUNDLE_IDENTIFIER"], expected)

    def test_runtime_app_group_matches_both_entitlements_after_regeneration(self):
        config = (IOS / "Config/App.xcconfig").read_text()
        group = re.search(r"^APP_GROUP\s*=\s*(\S+)", config, re.MULTILINE).group(1)
        self.assertEqual(group, GROUP, "Runtime UserDefaults suite must match signed entitlements")
        for name in ["EkadashiCalendar", "EkadashiWidgets"]:
            with self.subTest(target=name):
                target = self.spec["targets"][name]
                self.assertEqual(target["info"]["properties"]["EkadashiAppGroup"], "$(APP_GROUP)")
                generated = target["entitlements"]["properties"]["com.apple.security.application-groups"]
                self.assertEqual([value.replace("$(APP_GROUP)", group) for value in generated], [GROUP])
                with (IOS / name / (name + ".entitlements")).open("rb") as file:
                    signed = plistlib.load(file)["com.apple.security.application-groups"]
                self.assertEqual([value.replace("$(APP_GROUP)", group) for value in signed], [GROUP])


if __name__ == "__main__":
    unittest.main()
