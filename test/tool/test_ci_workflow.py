"""The CI workflows match the agreed gates (docs/TESTING.md, October 2026).

Plain-text checks, so the test needs nothing beyond the standard library.
"""

import os
from pathlib import Path
import subprocess
import tempfile
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

    def test_mac_only_ios_guards_run_on_the_mac_job(self):
        ios = job("ios-tests")
        generated = ios.index("xcodegen generate")
        guards = ios.index("python3 -m unittest discover -s test/tool -p 'test_ios_*.py'")
        app = ios.index("xcodebuild test")
        self.assertLess(generated, guards)
        self.assertLess(guards, app)
        self.assertIn("python3 tool/ios/test_signing_configuration.py", ios)
        self.assertNotIn("-only-testing:", ios)
        self.assertNotIn("-skip-testing:", ios)

    def test_failed_golden_comparisons_keep_their_visual_evidence(self):
        flutter = job("flutter-tests")
        upload = flutter[flutter.index("- uses: actions/upload-artifact@v4") :]
        self.assertIn("if: always()", upload)
        self.assertIn("test/**/failures/", upload)


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
            for path in (ROOT / "integration_test").glob("*_test.dart")
            if path.name != "android_app_test.dart"
        )
        self.assertEqual(sorted(listed), expected)
        self.assertEqual(len(listed), len(set(listed)))
        self.assertNotIn("integration_test/search_android_test.dart", listed)
        for target in listed:
            self.assertTrue((ROOT / target).exists(), target)


class DeviceTestRunTests(unittest.TestCase):
    def test_launcher_widgets_use_the_dedicated_widget_parity_fixture(self):
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / "runs"
            feature = Path(folder) / "feature.sh"
            feature.write_text(f'echo "$*" >> "{log}"\n')
            widget = Path(folder) / "widget.sh"
            widget.write_text(
                f'[[ $(tail -1 "{log}") == integration_test/android_widget_parity_test.dart ]]\n'
            )
            env = dict(os.environ, ANDROID_APP_RUNNER=str(feature),
                       ANDROID_FEATURE_RUNNER=str(feature), ANDROID_WIDGET_RUNNER=str(widget))
            subprocess.run(
                ["bash", "tool/android-all-integration.sh", "granted"], cwd=ROOT,
                env=env, check=True, capture_output=True, text=True, timeout=60,
            )

    def test_app_feature_and_widget_failures_cannot_be_hidden_by_later_success(self):
        for phase in ["app", "feature", "widget"]:
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as folder:
                log = Path(folder) / "runs"
                env = dict(os.environ)
                for runner, key in [("app", "ANDROID_APP_RUNNER"),
                                    ("feature", "ANDROID_FEATURE_RUNNER"),
                                    ("widget", "ANDROID_WIDGET_RUNNER")]:
                    fake = Path(folder) / f"{runner}.sh"
                    fake.write_text(
                        f'echo "{runner} $*" >> "{log}"\n'
                        + ("exit 7\n" if runner == phase else "exit 0\n")
                    )
                    env[key] = str(fake)
                run = subprocess.run(
                    ["bash", "tool/android-all-integration.sh", "granted"], cwd=ROOT,
                    env=env, capture_output=True, text=True, timeout=60,
                )
                self.assertEqual(run.returncode, 7, run.stderr)
                # Keep collecting later feature evidence, while preserving red.
                lines = log.read_text().splitlines()
                self.assertTrue(any(line.startswith("app ") for line in lines))
                for target in (ROOT / "integration_test").glob("*_test.dart"):
                    if target.name != "android_app_test.dart":
                        self.assertIn(f"feature integration_test/{target.name}", lines)

    def test_every_device_test_runs_even_when_the_runner_reads_stdin(self):
        """adb and flutter read stdin; that must not swallow the next targets."""
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / "runs"
            fake = Path(folder) / "fake.sh"
            fake.write_text(f'cat > /dev/null\necho "$0 $*" >> "{log}"\n')
            env = dict(
                os.environ,
                ANDROID_APP_RUNNER=str(fake),
                ANDROID_FEATURE_RUNNER=str(fake),
                ANDROID_WIDGET_RUNNER=str(fake),
            )
            subprocess.run(
                ["bash", "tool/android-all-integration.sh", "granted"],
                cwd=ROOT, env=env, check=True, capture_output=True, text=True,
                stdin=subprocess.DEVNULL, timeout=60,
            )
            runs = log.read_text().split("\n")
        targets = subprocess.run(
            ["bash", "tool/android-all-integration.sh", "--list"],
            cwd=ROOT, check=True, capture_output=True, text=True,
        ).stdout.split()
        for target in targets:
            self.assertTrue(any(run.endswith(target) for run in runs), target)
        # The app test, each feature test, and the widgets after multi-year.
        self.assertEqual(len([r for r in runs if r]), len(targets) + 2)


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
