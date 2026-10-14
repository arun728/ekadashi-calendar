"""The CI workflows match the agreed gates (docs/TESTING.md, October 2026).

Plain-text checks, so the test needs nothing beyond the standard library.
"""

from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
APP = (ROOT / ".github/workflows/android-tests.yml").read_text()
BACKEND = ROOT / ".github/workflows/backend-tests.yml"


def job(name):
    """The text of one job in the app workflow."""
    start = APP.index(f"\n  {name}:\n")
    rest = APP[start + 1 :]
    lines = rest.split("\n")
    body = [lines[0]]
    for line in lines[1:]:
        if line.startswith("  ") and not line.startswith("   ") and line.strip():
            break
        body.append(line)
    return "\n".join(body)


class WorkflowTests(unittest.TestCase):
    def test_superseded_runs_are_cancelled_and_docs_only_changes_skip_ci(self):
        self.assertIn("concurrency:", APP)
        self.assertIn("cancel-in-progress: true", APP)
        self.assertIn("paths-ignore:", APP)
        self.assertIn("'docs/**'", APP)
        self.assertIn("'**/*.md'", APP)

    def test_the_glass_preview_build_for_old_branches_is_gone(self):
        self.assertNotIn("glass-preview:", APP)
        self.assertNotIn("feature/android-glass-navigation", APP)

    def test_the_dormant_backend_runs_only_when_it_changes(self):
        self.assertNotIn("billing-backend:", APP)
        self.assertNotIn("billing-backend", job("android-tests"))
        self.assertTrue(BACKEND.exists())
        backend = BACKEND.read_text()
        self.assertIn("'backend/**'", backend)
        self.assertIn("pytest backend/tests", backend)

    def test_flutter_gates(self):
        flutter = job("flutter-tests")
        # Warnings fail the build; infos (style lints) are reported only.
        self.assertIn("flutter analyze --no-fatal-infos", flutter)
        self.assertNotIn("--no-fatal-warnings", flutter)
        self.assertIn("dart format --output=none --set-exit-if-changed lib test integration_test", flutter)
        self.assertIn("tool/check-generated.sh", flutter)
        self.assertIn("flutter test", flutter)

    def test_android_lint_runs(self):
        self.assertIn("lintDebug", job("android-tests"))


class DeviceTestDiscoveryTests(unittest.TestCase):
    def test_every_android_device_test_is_run_and_none_is_missing(self):
        listed = subprocess.run(
            ["bash", "tool/android-all-integration.sh", "--list"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.split()
        expected = sorted(
            str(path.relative_to(ROOT))
            for path in (ROOT / "integration_test").glob("*_android_test.dart")
            if path.name != "android_app_test.dart"
        )
        self.assertEqual(sorted(listed), expected)
        self.assertEqual(len(listed), len(set(listed)))
        self.assertNotIn("integration_test/search_android_test.dart", listed)
        for target in listed:
            self.assertTrue((ROOT / target).exists(), target)


class GeneratedFilesTests(unittest.TestCase):
    def test_the_drift_check_regenerates_every_generated_file(self):
        script = (ROOT / "tool/check-generated.sh").read_text()
        for step in (
            "tool/generate_localized_lookup.py",
            "dart format lib/l10n/localized_lookup.dart",
            "flutter gen-l10n",
            "tool/ios/generate_core_resources.py",
            "git diff --exit-code",
        ):
            self.assertIn(step, script)


if __name__ == "__main__":
    unittest.main()
