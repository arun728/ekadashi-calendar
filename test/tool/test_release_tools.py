"""Release tools: Play Console and App Store Connect APIs, device helpers.

These run offline. Network calls go through a fake client, and the signing
tests run only where the `cryptography` package is installed.
"""

import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tool" / "release"
sys.path.insert(0, str(TOOLS))

import store_api  # noqa: E402
import play  # noqa: E402
import android_ui  # noqa: E402

HAS_CRYPTO = importlib.util.find_spec("cryptography") is not None


class FakeClient:
    """Records every call and answers like the Play Developer API."""

    def __init__(self, fail_on=None):
        self.calls = []
        self.fail_on = fail_on

    def call(self, method, url, body=None, data=None, ctype="application/json"):
        self.calls.append((method, url, body, data is not None))
        if self.fail_on and self.fail_on in url:
            raise RuntimeError("HTTP 500")
        if method == "POST" and url.endswith("/edits"):
            return {"id": "E1"}
        if "/bundles" in url:
            return {"versionCode": 13}
        if url.endswith("/tracks") and method == "GET":
            return {"tracks": [{"track": "internal", "releases": [
                {"status": "completed", "name": "2.0.0 (13)", "versionCodes": ["13"]}]}]}
        if "/tracks/" in url and method == "PUT":
            return {"track": "internal", "releases": [body["releases"][0]]}
        return {}


def pubspec(text):
    folder = tempfile.mkdtemp()
    path = Path(folder) / "pubspec.yaml"
    path.write_text(text)
    return path


class VersionTests(unittest.TestCase):
    def test_reads_name_and_code_from_pubspec(self):
        path = pubspec("name: app\nversion: 2.0.0+13\n")
        self.assertEqual(store_api.pubspec_version(path), ("2.0.0", 13))
        self.assertEqual(store_api.release_name(path), "2.0.0 (13)")

    def test_missing_version_is_a_clear_error(self):
        with self.assertRaisesRegex(SystemExit, "version"):
            store_api.pubspec_version(pubspec("name: app\n"))


class PlayUploadTests(unittest.TestCase):
    def test_upload_puts_the_bundle_on_the_track_and_commits(self):
        client = FakeClient()
        aab = Path(tempfile.mkdtemp()) / "app.aab"
        aab.write_bytes(b"bundle")
        result = play.upload(client, aab, pubspec("version: 2.0.0+13\n"),
                             track="internal", notes="Test build")
        methods = [(m, u.split("/applications/")[-1]) for m, u, _, _ in client.calls]
        self.assertEqual(methods[0][0], "POST")
        self.assertIn("upload/androidpublisher", client.calls[1][1])
        self.assertTrue(client.calls[1][3])
        put = client.calls[2]
        self.assertEqual(put[0], "PUT")
        self.assertTrue(put[1].endswith("/edits/E1/tracks/internal"))
        release = put[2]["releases"][0]
        self.assertEqual(release["name"], "2.0.0 (13)")
        self.assertEqual(release["versionCodes"], ["13"])
        self.assertEqual(release["status"], "completed")
        self.assertEqual(release["releaseNotes"], [{"language": "en-US", "text": "Test build"}])
        self.assertTrue(client.calls[3][1].endswith("/edits/E1:commit"))
        self.assertEqual(result["versionCode"], 13)

    def test_upload_refuses_a_bundle_whose_code_differs_from_pubspec(self):
        client = FakeClient()
        aab = Path(tempfile.mkdtemp()) / "app.aab"
        aab.write_bytes(b"bundle")
        with self.assertRaisesRegex(SystemExit, "version code"):
            play.upload(client, aab, pubspec("version: 2.0.0+14\n"), track="internal")
        self.assertFalse(any(u.endswith(":commit") for _, u, _, _ in client.calls))

    def test_tracks_never_commits_and_always_deletes_the_edit(self):
        client = FakeClient()
        rows = play.tracks(client)
        self.assertEqual(rows, [("internal", "completed", "2.0.0 (13)", ["13"])])
        self.assertEqual(client.calls[-1][0], "DELETE")
        failing = FakeClient(fail_on="/tracks")
        with self.assertRaises(RuntimeError):
            play.tracks(failing)
        self.assertEqual(failing.calls[-1][0], "DELETE")
        self.assertFalse(any(u.endswith(":commit") for _, u, _, _ in failing.calls))


class PlayDestructiveTests(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run([sys.executable, str(TOOLS / "play.py"), *args],
                              capture_output=True, text=True,
                              env={**os.environ, "PLAY_SERVICE_ACCOUNT": "/nonexistent"})

    def test_refund_and_consume_need_yes(self):
        for args in (["refund", "GPA.0000-0000-0000-00000"],
                     ["consume", "ekadashi_premium_lifetime", "TOKEN"]):
            done = self.run_cli(*args)
            self.assertNotEqual(done.returncode, 0, args)
            self.assertIn("--yes", done.stderr + done.stdout, args)
            self.assertNotIn("service account", (done.stderr + done.stdout).lower(), args)

    def test_refund_revokes_by_default(self):
        client = FakeClient()
        play.refund(client, "GPA.1", revoke=True)
        self.assertTrue(client.calls[0][1].endswith("/orders/GPA.1:refund?revoke=true"))

    def test_missing_service_account_names_the_path(self):
        done = self.run_cli("tracks")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("/nonexistent", done.stderr + done.stdout)


class AppStoreConnectConfigTests(unittest.TestCase):
    def test_missing_config_names_the_file(self):
        with self.assertRaisesRegex(SystemExit, "asc.json"):
            store_api.asc_config(Path("/nonexistent/asc.json"), env={})

    def test_environment_overrides_the_file(self):
        folder = Path(tempfile.mkdtemp())
        path = folder / "asc.json"
        path.write_text(json.dumps({"key_id": "K", "issuer": "I", "key_path": "/k.p8"}))
        self.assertEqual(store_api.asc_config(path, env={})["key_id"], "K")
        config = store_api.asc_config(path, env={"ASC_KEY_ID": "K2"})
        self.assertEqual(config["key_id"], "K2")
        self.assertEqual(config["issuer"], "I")


@unittest.skipUnless(HAS_CRYPTO, "cryptography is not installed")
class SigningTests(unittest.TestCase):
    def test_play_assertion_is_rs256_for_the_publisher_scope(self):
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                serialization.NoEncryption()).decode()
        jwt = store_api.play_assertion({"client_email": "sa@example.test", "private_key": pem}, now=1000)
        head, claim, sig = jwt.split(".")
        self.assertEqual(store_api.b64json(head)["alg"], "RS256")
        claims = store_api.b64json(claim)
        self.assertEqual(claims["scope"], "https://www.googleapis.com/auth/androidpublisher")
        self.assertEqual(claims["exp"] - claims["iat"], 600)
        self.assertTrue(sig)

    def test_asc_token_is_es256_with_a_64_byte_signature(self):
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        key = ec.generate_private_key(ec.SECP256R1())
        path = Path(tempfile.mkdtemp()) / "key.p8"
        path.write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                           serialization.NoEncryption()))
        jwt = store_api.asc_token({"key_id": "K", "issuer": "I", "key_path": str(path)}, now=1000)
        head, claim, sig = jwt.split(".")
        self.assertEqual(store_api.b64json(head), {"alg": "ES256", "kid": "K", "typ": "JWT"})
        self.assertEqual(store_api.b64json(claim)["aud"], "appstoreconnect-v1")
        self.assertEqual(len(store_api.b64decode(sig)), 64)


class AndroidUiTests(unittest.TestCase):
    def test_lists_labelled_nodes_with_bounds(self):
        xml = ('<hierarchy><node text="" content-desc="" bounds="[0,0][10,10]"/>'
               '<node text="Settings" content-desc="" bounds="[1,2][3,4]"/>'
               '<node text="" content-desc="Manage&#10;subscription" bounds="[5,6][7,8]" enabled="false"/></hierarchy>')
        self.assertEqual(android_ui.nodes(xml), [
            ("[1,2][3,4]", "Settings", True),
            ("[5,6][7,8]", "Manage / subscription", False),
        ])


class ScriptTests(unittest.TestCase):
    def test_shell_scripts_parse(self):
        scripts = sorted(TOOLS.glob("*.sh"))
        self.assertGreaterEqual(len(scripts), 3)
        for script in scripts:
            done = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, f"{script.name}: {done.stderr}")

    def test_android_device_needs_a_serial(self):
        done = subprocess.run(["bash", str(TOOLS / "android-device.sh"), "ui"], capture_output=True,
                              text=True, env={"PATH": "/usr/bin:/bin"})
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("ADB_SERIAL", done.stderr)

    def test_device_billing_harness_stays_outside_the_ui_test_target(self):
        self.assertTrue((TOOLS / "ios" / "DeviceBillingUITests.swift").exists())
        self.assertFalse((ROOT / "ios-native/EkadashiCalendarUITests/DeviceBillingUITests.swift").exists())

    def test_no_secrets_orders_or_personal_details(self):
        patterns = [r"GPA\.\d{4}-", r"BEGIN (RSA |EC )?PRIVATE KEY", r"[A-Za-z0-9._%+-]+@gmail\.com",
                    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
                    r"\b[0-9A-F]{8}-[0-9A-F]{16}\b", r"adb-[A-Z0-9]{8,}", r"\bArun\b|\bRiya\b"]
        files = [p for p in TOOLS.rglob("*") if p.is_file() and "__pycache__" not in p.parts]
        self.assertTrue(files)
        for path in files:
            text = path.read_text(errors="ignore")
            for pattern in patterns:
                self.assertIsNone(re.search(pattern, text), f"{path.name} matches {pattern}")


if __name__ == "__main__":
    unittest.main()
