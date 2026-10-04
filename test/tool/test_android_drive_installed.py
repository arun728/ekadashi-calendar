"""Exercise the runner with fake tools; real app assertions remain emulator gates."""
import os
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class InstalledAndroidDriverTests(unittest.TestCase):
    def run_driver(self, *, vm=True, fail=False, stale=False, transport=False):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)
            log = p / 'calls'
            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    value = ({'isolates': [{'id': 'isolates/1', 'name': 'main'}]}
                             if 'getVM' in self.path else
                             {'rootLib': {'uri': 'file:///repo/' + ('main.dart' if stale else 'example.dart')}})
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(json.dumps({'result': value}).encode())
                def log_message(self, *args):
                    pass
            server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            adb = p / 'adb' 
            adb.write_text('''#!/usr/bin/env python3
import os,sys
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['CALLS'],'a') as f:f.write('adb '+ ' '.join(args)+'\\n')
if args[:2]==['logcat','-d']:
 if os.environ['VM']=='yes':print('I/flutter: The Dart VM service is listening on http://127.0.0.1:4567/test-token=/')
elif args==['shell','pidof','com.applausestudios.ekadashi_calendar']:print('1234')
elif args==['forward','tcp:0','tcp:4567']:print(os.environ['VM_PORT'])
''')
            flutter = p / 'flutter'
            flutter.write_text('''#!/usr/bin/env python3
import os,sys
with open(os.environ['CALLS'],'a') as f:f.write('flutter '+ ' '.join(sys.argv[1:])+'\\n')
if os.environ['TRANSPORT']=='yes':
 from pathlib import Path
 count=Path(os.environ['CALLS']+'.attempt')
 if not count.exists():
  count.write_text('1')
  print('All tests passed!\\nDriverError: Service has disappeared')
  sys.exit(7)
if os.environ['FAIL']=='yes':print('Some tests failed. TestFailure')
sys.exit(7 if os.environ['FAIL']=='yes' else 0)
''')
            adb.chmod(0o755)
            flutter.chmod(0o755)
            env = dict(os.environ, PATH=f'{p}:'+os.environ['PATH'], CALLS=str(log), VM='yes' if vm else 'no', FAIL='yes' if fail else 'no', TRANSPORT='yes' if transport else 'no', VM_PORT=str(server.server_port), ANDROID_VM_WAIT_ATTEMPTS='1')
            result = subprocess.run(['bash', str(ROOT/'tool/android-drive-installed.sh'), 'integration_test/example.dart', str(p)], env=env, capture_output=True, text=True, timeout=10)
            server.shutdown()
            server.server_close()
            return result, (log.read_text() if log.exists() else '').replace(str(server.server_port), '3456')

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
        self.assertEqual(log.count('flutter drive'), 1)

    def test_stale_entry_point_is_rejected(self):
        result, log = self.run_driver(stale=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('flutter drive', log)
        self.assertIn('forward --remove tcp:3456', log)

    def test_result_transport_loss_relaunches_once(self):
        result, log = self.run_driver(transport=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.count('flutter drive'), 2)
        self.assertEqual(log.count('adb shell am force-stop'), 2)

    def test_missing_vm_service_fails_before_calling_flutter(self):
        result, log = self.run_driver(vm=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('VM service', result.stderr)
        self.assertNotIn('flutter drive', log)

if __name__ == '__main__':
    unittest.main()
