"""Exercise the runner with fake tools; real app assertions remain emulator gates."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class InstalledAndroidDriverTests(unittest.TestCase):
    def run_driver(self, *, vm=True, fail=False):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)
            log = p / 'calls'
            adb = p / 'adb'
            adb.write_text('''#!/usr/bin/env python3
import os,sys
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['CALLS'],'a') as f:f.write('adb '+ ' '.join(args)+'\\n')
if args[:2]==['logcat','-d']:
 if os.environ['VM']=='yes':print('I/flutter: The Dart VM service is listening on http://127.0.0.1:4567/test-token=/')
elif args==['forward','tcp:0','tcp:4567']:print('3456')
''')
            flutter = p / 'flutter'
            flutter.write_text('''#!/usr/bin/env python3
import os,sys
with open(os.environ['CALLS'],'a') as f:f.write('flutter '+ ' '.join(sys.argv[1:])+'\\n')
sys.exit(7 if os.environ['FAIL']=='yes' else 0)
''')
            adb.chmod(0o755)
            flutter.chmod(0o755)
            env = dict(os.environ, PATH=f'{p}:'+os.environ['PATH'], CALLS=str(log), VM='yes' if vm else 'no', FAIL='yes' if fail else 'no', ANDROID_VM_WAIT_ATTEMPTS='1')
            result = subprocess.run(['bash', str(ROOT/'tool/android-drive-installed.sh'), 'integration_test/example.dart', str(p)], env=env, capture_output=True, text=True, timeout=10)
            return result, log.read_text() if log.exists() else ''

    def test_attaches_to_installed_binary_without_reinstalling(self):
        result, log = self.run_driver()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--use-existing-app=http://127.0.0.1:3456/test-token=/', log)
        self.assertIn('--keep-app-running', log)
        self.assertIn('start-paused true', log)
        self.assertNotIn(' install ', log)
        self.assertIn('forward --remove tcp:3456', log)

    def test_paused_vm_launch_does_not_wait_for_a_rendered_frame(self):
        result, log = self.run_driver()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('adb shell am start -n ', log)
        self.assertNotIn('am start -W', log)

    def test_driver_failure_is_preserved_and_forward_is_cleaned(self):
        result, log = self.run_driver(fail=True)
        self.assertEqual(result.returncode, 7)
        self.assertIn('forward --remove tcp:3456', log)

    def test_missing_vm_service_fails_before_calling_flutter(self):
        result, log = self.run_driver(vm=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('VM service', result.stderr)
        self.assertNotIn('flutter drive', log)

if __name__ == '__main__':
    unittest.main()
