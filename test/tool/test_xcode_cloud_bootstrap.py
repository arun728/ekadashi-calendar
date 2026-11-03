"""Exercise Xcode Cloud's post-clone hook against an isolated checkout."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / "ios-native/ci_scripts/ci_post_clone.sh"


class XcodeCloudBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.checkout = self.base / "checkout with spaces"
        self.ios = self.checkout / "ios-native"
        self.ios.mkdir(parents=True)
        (self.ios / "project.yml").write_text("name: EkadashiCalendar\n")
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.log = self.base / "commands.jsonl"
        self.generator = self.base / "generator"
        self.generator.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, sys\n"
            "with open(os.environ['TEST_COMMAND_LOG'], 'a') as log:\n"
            "    log.write(json.dumps({'command': 'xcodegen', 'cwd': os.getcwd(), "
            "'args': sys.argv[1:]}) + '\\n')\n"
            "if os.environ.get('TEST_GENERATOR_FAILURE'): sys.exit(23)\n"
            "if os.environ.get('TEST_NO_PROJECT'): sys.exit(0)\n"
            "project = pathlib.Path('EkadashiCalendar.xcodeproj')\n"
            "project.mkdir(exist_ok=True)\n"
            "(project / 'project.pbxproj').write_text('generated')\n"
            "if not os.environ.get('TEST_NO_SCHEME'):\n"
            "    schemes = project / 'xcshareddata/xcschemes'\n"
            "    schemes.mkdir(parents=True, exist_ok=True)\n"
            "    (schemes / 'EkadashiCalendar.xcscheme').write_text('shared')\n"
        )
        self.generator.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "CI_PRIMARY_REPOSITORY_PATH": str(self.checkout),
            "TEST_COMMAND_LOG": str(self.log),
        }
        for name in ("TEST_GENERATOR_FAILURE", "TEST_NO_PROJECT", "TEST_NO_SCHEME"):
            self.env.pop(name, None)

    def install_generator(self):
        (self.bin / "xcodegen").symlink_to(self.generator)

    def run_hook(self):
        return subprocess.run(
            [str(HOOK)], cwd=self.base, env=self.env,
            text=True, capture_output=True, check=False,
        )

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_generates_project_and_shared_scheme_from_cloud_checkout(self):
        self.install_generator()
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        command, = self.commands()
        self.assertEqual(command["cwd"], str(self.ios))
        self.assertEqual(command["args"], ["generate", "--spec", "project.yml"])
        self.assertTrue((self.ios / "EkadashiCalendar.xcodeproj/project.pbxproj").is_file())
        self.assertTrue((self.ios / "EkadashiCalendar.xcodeproj/xcshareddata/xcschemes/EkadashiCalendar.xcscheme").is_file())

    def test_installs_missing_generator_before_generation(self):
        brew = self.bin / "brew"
        brew.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, sys\n"
            "with open(os.environ['TEST_COMMAND_LOG'], 'a') as log:\n"
            "    log.write(json.dumps({'command': 'brew', 'args': sys.argv[1:]}) + '\\n')\n"
            f"pathlib.Path({str(self.bin / 'xcodegen')!r}).symlink_to({str(self.generator)!r})\n"
        )
        brew.chmod(0o755)
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        commands = self.commands()
        self.assertEqual(commands[0], {"command": "brew", "args": ["install", "xcodegen"]})
        self.assertEqual(commands[1]["command"], "xcodegen")

    def test_local_run_finds_checkout_relative_to_the_hook(self):
        self.install_generator()
        local_hook = self.ios / "ci_scripts/ci_post_clone.sh"
        local_hook.parent.mkdir()
        local_hook.write_bytes(HOOK.read_bytes())
        local_hook.chmod(0o755)
        self.env.pop("CI_PRIMARY_REPOSITORY_PATH")
        result = subprocess.run(
            [str(local_hook)], cwd=self.base, env=self.env,
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.commands()[0]["cwd"], str(self.ios))

    def test_generator_failure_stops_the_hook(self):
        self.install_generator()
        self.env["TEST_GENERATOR_FAILURE"] = "1"
        self.assertEqual(self.run_hook().returncode, 23)

    def test_missing_spec_fails_before_install_or_generation(self):
        self.install_generator()
        (self.ios / "project.yml").unlink()
        result = self.run_hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("project.yml", result.stderr)
        self.assertFalse(self.log.exists())

    def test_successful_tool_without_project_is_rejected(self):
        self.install_generator()
        self.env["TEST_NO_PROJECT"] = "1"
        result = self.run_hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("project.pbxproj", result.stderr)

    def test_missing_shared_scheme_is_rejected(self):
        self.install_generator()
        self.env["TEST_NO_SCHEME"] = "1"
        result = self.run_hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EkadashiCalendar.xcscheme", result.stderr)

    def test_missing_generator_and_homebrew_has_actionable_error(self):
        result = self.run_hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Homebrew", result.stderr)


if __name__ == "__main__":
    unittest.main()
