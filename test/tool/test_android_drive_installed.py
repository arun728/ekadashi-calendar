"""Exercise the installed Android driver wrapper with fake adb/flutter tools."""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
from threading import Thread
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class InstalledAndroidDriverTests(unittest.TestCase):
    def run_driver(
        self,
        *,
        vm=True,
        fail=False,
        stale=False,
        transport=False,
        early_transport=False,
        chained_transport=False,
        offline=False,
    ):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            calls = directory / "calls"

            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    value = (
                        {"isolates": [{"id": "isolates/1", "name": "main"}]}
                        if "getVM" in self.path
                        else {
                            "rootLib": {
                                "uri": "file:///repo/"
                                + ("main.dart" if stale else "example.dart")
                            }
                        }
                    )
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(json.dumps({"result": value}).encode())

                def log_message(self, *args):
                    pass

            server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            adb = directory / "adb"
            adb.write_text(
                """#!/usr/bin/env python3
import os,sys
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['CALLS'],'a') as f:f.write('adb '+ ' '.join(args)+'\\n')
if args==['wait-for-device']:
 Path(os.environ['CALLS']+'.online').write_text('1')
elif args[:4]==['shell','am','force-stop','com.applausestudios.ekadashi_calendar'] and os.environ['OFFLINE']=='yes' and Path(os.environ['CALLS']+'.attempt').exists() and not Path(os.environ['CALLS']+'.online').exists():
 print('adb: device offline',file=sys.stderr)
 sys.exit(1)
elif args[:2]==['logcat','-d']:
 if os.environ['VM']=='yes':print('I/flutter: The Dart VM service is listening on http://127.0.0.1:4567/test-token=/')
elif args[:3]==['shell','pidof','com.applausestudios.ekadashi_calendar']:print('1234')
elif args[:2]==['forward','tcp:0']:print(os.environ['VM_PORT'])
"""
            )
            flutter = directory / "flutter"
            flutter.write_text(
                """#!/usr/bin/env python3
import os,sys
from pathlib import Path
with open(os.environ['CALLS'],'a') as f:f.write('flutter '+ ' '.join(sys.argv[1:])+'\\n')
if os.environ['EARLY_TRANSPORT']=='yes':
 marker=Path(os.environ['CALLS']+'.early')
 if not marker.exists():
  marker.write_text('1')
  print('VMServiceFlutterDriver: Isolate found with number: 123')
  print('Unhandled exception:\\ngetIsolate: (112) Service has disappeared')
  sys.exit(1)
if os.environ['CHAINED_TRANSPORT']=='yes':
 marker=Path(os.environ['CALLS']+'.attempt')
 count=int(marker.read_text()) if marker.exists() else 0
 marker.write_text(str(count+1))
 if count==0:
  print('01:16 +2: All tests passed!')
  print('DriverError: Failed to fulfill RequestData')
  print('Service has disappeared')
  sys.exit(7)
 if count==1:
  print('Exception attempting to connect to the VM Service: Connection refused')
  sys.exit(1)
if os.environ['TRANSPORT']=='yes':
 marker=Path(os.environ['CALLS']+'.attempt')
 if not marker.exists():
  marker.write_text('1')
  Path(os.environ['CALLS']+'.online').unlink(missing_ok=True)
  print('All tests passed!\\nDriverError: Failed to fulfill RequestData\\nService has disappeared')
  sys.exit(7)
if os.environ['FAIL']=='yes':print('Some tests failed. TestFailure')
sys.exit(7 if os.environ['FAIL']=='yes' else 0)
"""
            )
            adb.chmod(0o755)
            flutter.chmod(0o755)
            env = dict(
                os.environ,
                PATH=f"{directory}:{os.environ['PATH']}",
                CALLS=str(calls),
                VM="yes" if vm else "no",
                FAIL="yes" if fail else "no",
                TRANSPORT="yes" if transport else "no",
                EARLY_TRANSPORT="yes" if early_transport else "no",
                CHAINED_TRANSPORT="yes" if chained_transport else "no",
                OFFLINE="yes" if offline else "no",
                VM_PORT=str(server.server_port),
                ANDROID_VM_WAIT_ATTEMPTS="1",
            )
            try:
                result = subprocess.run(
                    [
                        "bash",
                        str(ROOT / "tool/android-drive-installed.sh"),
                        "integration_test/example.dart",
                        str(directory),
                    ],
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
            finally:
                server.shutdown()
                server.server_close()
            log = calls.read_text() if calls.exists() else ""
            return result, log.replace(str(server.server_port), "3456")

    def test_attaches_to_installed_binary_without_reinstalling(self):
        result, log = self.run_driver()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--use-existing-app=http://127.0.0.1:3456/test-token=/", log)
        self.assertIn("--keep-app-running", log)
        self.assertIn("start-paused true", log)
        self.assertNotIn(" install ", log)
        self.assertIn("forward --remove tcp:3456", log)

    def test_paused_vm_launch_does_not_wait_for_a_rendered_frame(self):
        result, log = self.run_driver()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("adb shell am start -n ", log)
        self.assertNotIn("am start -W", log)

    def test_driver_failure_is_preserved_and_forward_is_cleaned(self):
        result, log = self.run_driver(fail=True)
        self.assertEqual(result.returncode, 7)
        self.assertIn("forward --remove tcp:3456", log)
        self.assertEqual(log.count("flutter drive"), 1)

    def test_stale_entrypoint_is_rejected(self):
        result, log = self.run_driver(stale=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("flutter drive", log)
        self.assertIn("forward --remove tcp:3456", log)

    def test_result_transport_loss_reruns_all_assertions_once(self):
        result, log = self.run_driver(transport=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.count("flutter drive"), 2)
        self.assertEqual(log.count("adb shell am force-stop"), 2)

    def test_transport_retry_waits_for_offline_device_to_reconnect(self):
        result, log = self.run_driver(transport=True, offline=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.count("flutter drive"), 2)
        self.assertEqual(log.count("adb wait-for-device"), 2)

    def test_pretest_isolate_disconnect_relaunches_and_reruns_suite(self):
        result, log = self.run_driver(early_transport=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.count("flutter drive"), 2)
        self.assertEqual(log.count("adb shell am force-stop"), 2)

    def test_result_loss_then_refusal_gets_one_more_full_attempt(self):
        result, log = self.run_driver(chained_transport=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.count("flutter drive"), 3)
        self.assertEqual(log.count("adb shell am force-stop"), 3)

    def test_missing_vm_service_fails_before_running_flutter(self):
        result, log = self.run_driver(vm=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("VM service", result.stderr)
        self.assertNotIn("flutter drive", log)


if __name__ == "__main__":
    unittest.main()
