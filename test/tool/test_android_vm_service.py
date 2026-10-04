import json
import unittest
from unittest.mock import patch
from urllib.error import URLError
from tool.android_vm_service import verify_vm_service, may_retry_transport


class Response:
    def __init__(self, value):
        self.value = value

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self):
        return json.dumps({'result': self.value}).encode()


class VmServiceTests(unittest.TestCase):
    def check_root(self, uri):
        with patch('urllib.request.urlopen', side_effect=[
            Response({'isolates': [{'id': 'isolates/7', 'name': 'main'}]}),
            Response({'rootLib': {'uri': uri}}),
        ]):
            return verify_vm_service('http://127.0.0.1:1234/test/',
                                     'integration_test/premium_android_test.dart')

    def test_matching_test_entrypoint_is_live(self):
        self.assertTrue(self.check_root('file:///repo/integration_test/premium_android_test.dart'))

    def test_previous_production_vm_is_rejected(self):
        self.assertFalse(self.check_root('file:///repo/lib/main.dart'))

    def test_unreachable_vm_is_not_ready(self):
        with patch('urllib.request.urlopen', side_effect=URLError('Connection refused')):
            self.assertFalse(verify_vm_service('http://127.0.0.1:1234/test/', 'test.dart'))

    def test_remote_url_is_not_an_adb_vm(self):
        self.assertFalse(verify_vm_service('https://example.com/', 'test.dart'))

    def test_result_transport_loss_after_assertions_can_retry(self):
        self.assertTrue(may_retry_transport('All tests passed!\nDriverError: Service has disappeared'))

    def test_assertion_failure_never_retries(self):
        self.assertFalse(may_retry_transport('TestFailure: bad count\nAll tests passed!\nService has disappeared'))

    def test_app_crash_never_retries(self):
        self.assertFalse(may_retry_transport('All tests passed!\nFATAL EXCEPTION: main\nService has disappeared'))

    def test_started_test_timeout_never_retries(self):
        self.assertFalse(may_retry_transport('00:00 +0: premium test\nConnection refused\ntimeout'))


if __name__ == '__main__':
    unittest.main()
