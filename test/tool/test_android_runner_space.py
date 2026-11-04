"""Exercise hosted-runner cleanup without touching real system directories."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class AndroidRunnerSpaceTests(unittest.TestCase):
    def run_cleanup(self, *, hosted=True, recovered=True, available_kib="2724660"):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "available").write_text(available_kib)
            binaries = root / "bin"
            binaries.mkdir()
            df = binaries / "df"
            df.write_text(
                "#!/usr/bin/env python3\n"
                "import os\nfrom pathlib import Path\n"
                "root = Path(os.environ['SPACE_TEST_ROOT'])\n"
                "print('Filesystem 1024-blocks Used Available Capacity Mounted')\n"
                "print('disk 99999999 0 ' + (root/'available').read_text() + ' 0% /')\n"
            )
            sudo = binaries / "sudo"
            sudo.write_text(
                "#!/usr/bin/env python3\n"
                "import os, sys\nfrom pathlib import Path\n"
                "root = Path(os.environ['SPACE_TEST_ROOT'])\n"
                "(root/'removed').write_text('\\n'.join(sys.argv[1:]))\n"
                "if os.environ['SPACE_TEST_RECOVERS'] == 'yes':\n"
                "    (root/'available').write_text('12582912')\n"
            )
            df.chmod(0o755)
            sudo.chmod(0o755)
            result = subprocess.run(
                ["bash", "tool/android-runner-space.sh"],
                cwd=ROOT,
                env={
                    **os.environ,
                    "PATH": f"{binaries}:{os.environ['PATH']}",
                    "GITHUB_ACTIONS": "true",
                    "RUNNER_OS": "Linux",
                    "RUNNER_ENVIRONMENT": "github-hosted" if hosted else "self-hosted",
                    "GITHUB_WORKSPACE": str(root),
                    "SPACE_TEST_ROOT": str(root),
                    "SPACE_TEST_RECOVERS": "yes" if recovered else "no",
                },
                capture_output=True,
                text=True,
            )
            removed = root / "removed"
            return result, removed.read_text().splitlines() if removed.exists() else []

    def test_only_unused_hosted_tools_are_removed_and_capacity_is_recovered(self):
        result, removed = self.run_cleanup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(removed, [
            "rm", "-rf", "/usr/share/dotnet", "/usr/local/.ghcup",
            "/opt/ghc", "/opt/hostedtoolcache/CodeQL",
        ])

    def test_self_hosted_or_local_machines_are_not_cleaned(self):
        result, removed = self.run_cleanup(hosted=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("github-hosted Linux runner", result.stderr)
        self.assertEqual(removed, [])

    def test_sufficient_capacity_does_not_remove_any_tools(self):
        result, removed = self.run_cleanup(available_kib="12582912")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(removed, [])

    def test_insufficient_capacity_fails_before_emulator_boot(self):
        result, _ = self.run_cleanup(recovered=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("10 GiB", result.stderr)

    def test_workflow_reclaims_space_before_the_emulator_download_and_boot(self):
        workflow = (ROOT / ".github/workflows/android-tests.yml").read_text()
        android = workflow.split("  android-tests:\n", 1)[1].split("  ios-tests:\n", 1)[0]
        self.assertLess(android.index("bash tool/android-runner-space.sh"),
                        android.index("uses: reactivecircus/android-emulator-runner"))


if __name__ == "__main__":
    unittest.main()
