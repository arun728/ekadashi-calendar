"""Offline diagnostics must finish and preserve the actual test result."""

import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class AndroidEvidenceTests(unittest.TestCase):
    def run_fixture(self, script, *, result=7, diagnostic="ok", deadline="1"):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            tools = root / "tool"
            tools.mkdir()
            shutil.copy2(ROOT / "tool" / script, tools / script)
            helper = ROOT / "tool/android-evidence.sh"
            if helper.exists():
                shutil.copy2(helper, tools / helper.name)
            (tools / "android-drive-installed.sh").write_text(f"exit {result}\n")
            (tools / "adb-install-retry.sh").write_text("exit 0\n")
            binaries = root / "bin"
            binaries.mkdir()
            for name in ["flutter", "sleep"]:
                path = binaries / name
                path.write_text("#!/bin/sh\nexit 0\n")
                path.chmod(0o755)
            adb = binaries / "adb"
            adb.write_text('''#!/usr/bin/env python3
import os, sys, time
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as file:
    file.write(' '.join(args) + '\\n')
diagnostic = args[:2] == ['logcat', '-d'] or args[:1] == ['exec-out'] or args[:2] == ['shell', 'dumpsys'] or args == ['shell', 'getprop']
if diagnostic:
    print('partial diagnostic', flush=True)
    if os.environ['DIAGNOSTIC'] == 'offline' and args[:2] == ['logcat', '-d']:
        time.sleep(30)
    if os.environ['DIAGNOSTIC'] == 'error':
        sys.exit(9)
elif args == ['shell', 'getprop', 'ro.build.version.sdk']:
    print('33')
elif args[:2] == ['shell', 'pidof']:
    print('123')
''')
            adb.chmod(0o755)
            calls = root / "calls"
            process = subprocess.Popen(
                ["bash", str(tools / script),
                 "integration_test/example.dart" if script == "android-feature-integration.sh" else "granted"], cwd=root,
                env={**os.environ, "PATH": f"{binaries}:{os.environ['PATH']}",
                     "CALLS": str(calls), "DIAGNOSTIC": diagnostic,
                     "ANDROID_EVIDENCE_TIMEOUT_SECONDS": deadline},
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, start_new_session=True,
            )
            try:
                stdout, stderr = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=2)
                self.fail(f"{script}: diagnostic capture hung after the test ended")
            return process.returncode, calls.read_text(), stdout + stderr

    def test_offline_logcat_is_bounded_and_original_failure_survives(self):
        for script in ["android-feature-integration.sh", "android-integration.sh"]:
            with self.subTest(script=script):
                result, calls, _ = self.run_fixture(script, diagnostic="offline")
                self.assertEqual(result, 7)
                self.assertIn("exec-out screencap -p", calls)
                self.assertIn("shell dumpsys package", calls)
                self.assertIn("shell getprop\n", calls)

    def test_diagnostic_errors_do_not_replace_the_test_failure(self):
        for script in ["android-feature-integration.sh", "android-integration.sh"]:
            with self.subTest(script=script):
                result, _, _ = self.run_fixture(script, diagnostic="error")
                self.assertEqual(result, 7)

    def test_passing_tests_still_require_successful_diagnostics(self):
        for script in ["android-feature-integration.sh", "android-integration.sh"]:
            with self.subTest(script=script):
                result, calls, _ = self.run_fixture(script, result=0)
                self.assertEqual(result, 0)
                self.assertIn("logcat -d", calls)
                result, _, _ = self.run_fixture(script, result=0, diagnostic="error")
                self.assertNotEqual(result, 0)

    def test_zero_timeout_cannot_disable_the_capture_deadline(self):
        result, _, output = self.run_fixture(
            "android-feature-integration.sh", diagnostic="offline", deadline="0",
        )
        self.assertEqual(result, 7)
        self.assertIn("capture timeout", output)


if __name__ == "__main__":
    unittest.main()
