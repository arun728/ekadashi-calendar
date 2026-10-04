import json
import unittest
from unittest.mock import patch
from urllib.error import URLError

from tool.android_vm_service import may_retry_transport, verify_vm_service


class _Response:
    def __init__(self, value):
        self.value = value

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self):
        return json.dumps({"result": self.value}).encode()


class VmServiceTests(unittest.TestCase):
    def _check_root(self, uri):
        with patch(
            "urllib.request.urlopen",
            side_effect=[
                _Response({"isolates": [{"id": "isolates/7", "name": "main"}]}),
                _Response({"rootLib": {"uri": uri}}),
            ],
        ):
            return verify_vm_service(
                "http://127.0.0.1:1234/test/",
                "integration_test/premium_android_test.dart",
            )

    def test_matching_test_entrypoint_is_live(self):
        self.assertTrue(
            self._check_root("file:///repo/integration_test/premium_android_test.dart")
        )

    def test_previous_production_vm_is_rejected(self):
        self.assertFalse(self._check_root("file:///repo/lib/main.dart"))

    def test_unreachable_vm_is_not_ready(self):
        with patch(
            "urllib.request.urlopen", side_effect=URLError("Connection refused")
        ):
            self.assertFalse(
                verify_vm_service(
                    "http://127.0.0.1:1234/test/", "integration_test/test.dart"
                )
            )

    def test_non_loopback_vm_is_rejected(self):
        self.assertFalse(
            verify_vm_service("https://example.com/", "integration_test/test.dart")
        )

    def test_only_passed_request_data_transport_loss_can_retry(self):
        self.assertTrue(
            may_retry_transport(
                "All tests passed!\n"
                "DriverError: Failed to fulfill RequestData\n"
                "Service has disappeared"
            )
        )

    def test_assertion_failure_never_retries(self):
        self.assertFalse(
            may_retry_transport(
                "Some tests failed. TestFailure\n"
                "All tests passed!\n"
                "DriverError: Failed to fulfill RequestData\n"
                "Service has disappeared"
            )
        )

    def test_app_crash_never_retries(self):
        self.assertFalse(
            may_retry_transport(
                "All tests passed!\nFATAL EXCEPTION: main\n"
                "DriverError: Failed to fulfill RequestData\nService has disappeared"
            )
        )

    def test_other_driver_errors_never_retry(self):
        self.assertFalse(
            may_retry_transport("All tests passed!\nConnection refused")
        )


if __name__ == "__main__":
    unittest.main()
