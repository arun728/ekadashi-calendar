"""Reproduce archive signing of the core's copied SwiftPM resource bundle."""

import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "ios-native/EkadashiCore"
SOURCE = PACKAGE / "Sources/EkadashiCore"


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("swift"),
                     "Requires macOS codesign and the Swift toolchain")
class IOSResourceBundleSigningTests(unittest.TestCase):
    def test_copied_resources_preserve_data_and_form_a_signable_ios_bundle(self):
        manifest = json.loads(subprocess.check_output(
            ["swift", "package", "dump-package"], cwd=PACKAGE, text=True))
        target = next(t for t in manifest["targets"] if t["name"] == "EkadashiCore")
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "EkadashiCore_EkadashiCore.bundle"
            bundle.mkdir()
            # SwiftPM supplies this flat iOS bundle metadata during Xcode builds.
            with (bundle / "Info.plist").open("wb") as output:
                plistlib.dump({
                    "CFBundleIdentifier": "ekadashicore.EkadashiCore.resources",
                    "CFBundleName": "EkadashiCore_EkadashiCore",
                    "CFBundlePackageType": "BNDL",
                    "CFBundleInfoDictionaryVersion": "6.0",
                }, output)
            for resource in target["resources"]:
                self.assertIn("copy", resource["rule"],
                              "Core data must remain byte-for-byte copies")
                source = SOURCE / resource["path"]
                shutil.copytree(source, bundle / source.name)

            # CoreResources supports either the original Resources/ prefix or
            # direct subdirectories; every source file must stay readable.
            for source in (SOURCE / "Resources").rglob("*"):
                if source.is_file():
                    relative = source.relative_to(SOURCE / "Resources")
                    candidates = [bundle / "Resources" / relative, bundle / relative]
                    destination = next((p for p in candidates if p.is_file()), None)
                    self.assertIsNotNone(destination, str(relative))
                    self.assertEqual(source.read_bytes(), destination.read_bytes())

            result = subprocess.run(
                ["/usr/bin/codesign", "--force", "--sign", "-", str(bundle)],
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(bundle)],
                           check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
