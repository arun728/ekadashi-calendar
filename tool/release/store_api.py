"""Shared helpers for the Google Play Developer and App Store Connect APIs.

Credentials never live in the repository:
- Play: a service-account JSON file, `PLAY_SERVICE_ACCOUNT`
  (default ~/.config/ekadashi/play-service-account.json).
- App Store Connect: ~/.config/ekadashi/asc.json with key_id, issuer and
  key_path (the .p8 file); ASC_KEY_ID, ASC_ISSUER and ASC_KEY_PATH override it.
Never delete these keys: other agents and tools use them.

Signing needs the `cryptography` package (only imported when a token is made).
"""

import base64
import json
import os
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

PACKAGE = "com.applausestudios.ekadashi_calendar"
PLAY_APP = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
PLAY_UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"
ASC = "https://api.appstoreconnect.apple.com"
IOS_BUNDLE_ID = "com.apptinel.ekadashi-calendar"
ROOT = Path(__file__).resolve().parents[2]
PLAY_SERVICE_ACCOUNT = Path("~/.config/ekadashi/play-service-account.json").expanduser()
ASC_CONFIG = Path("~/.config/ekadashi/asc.json").expanduser()


def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def b64decode(text):
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def b64json(text):
    return json.loads(b64decode(text))


def pubspec_version(path=ROOT / "pubspec.yaml"):
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", Path(path).read_text(), re.M)
    if not match:
        raise SystemExit(f"No 'version: X.Y.Z+CODE' line in {path}")
    return match.group(1), int(match.group(2))


def release_name(path=ROOT / "pubspec.yaml"):
    name, code = pubspec_version(path)
    return f"{name} ({code})"


class Client:
    """Bearer-token JSON client; prints the API's error body before raising."""

    def __init__(self, token, opener=urllib.request.urlopen):
        self.token = token
        self.opener = opener

    def call(self, method, url, body=None, data=None, ctype="application/json"):
        payload = data if data is not None else (json.dumps(body).encode() if body is not None else None)
        request = urllib.request.Request(url, method=method, data=payload,
                                         headers={"Authorization": "Bearer " + self.token,
                                                  "Content-Type": ctype})
        try:
            with self.opener(request, timeout=900) as response:
                text = response.read()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as error:
            print("HTTP", error.code, error.read().decode()[:800])
            raise


def play_assertion(account, now=None):
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    now = int(now if now is not None else time.time())
    head = b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claim = b64(json.dumps({"iss": account["client_email"],
                            "scope": "https://www.googleapis.com/auth/androidpublisher",
                            "aud": "https://oauth2.googleapis.com/token",
                            "iat": now, "exp": now + 600}).encode())
    key = serialization.load_pem_private_key(account["private_key"].encode(), None)
    signature = key.sign(f"{head}.{claim}".encode(), padding.PKCS1v15(), hashes.SHA256())
    return f"{head}.{claim}.{b64(signature)}"


def play_client(path=None):
    path = Path(path or os.environ.get("PLAY_SERVICE_ACCOUNT") or PLAY_SERVICE_ACCOUNT).expanduser()
    if not path.exists():
        raise SystemExit(f"Play service account not found: {path} (set PLAY_SERVICE_ACCOUNT)")
    assertion = play_assertion(json.loads(path.read_text()))
    form = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                   "assertion": assertion}).encode()
    with urllib.request.urlopen("https://oauth2.googleapis.com/token", form) as response:
        return Client(json.load(response)["access_token"])


def asc_config(path=None, env=None):
    env = os.environ if env is None else env
    path = Path(path or env.get("ASC_CONFIG") or ASC_CONFIG).expanduser()
    config = json.loads(path.read_text()) if path.exists() else {}
    for key, name in (("key_id", "ASC_KEY_ID"), ("issuer", "ASC_ISSUER"), ("key_path", "ASC_KEY_PATH")):
        if env.get(name):
            config[key] = env[name]
    missing = [k for k in ("key_id", "issuer", "key_path") if not config.get(k)]
    if missing:
        raise SystemExit(f"App Store Connect config {path} is missing {', '.join(missing)} "
                         "(create asc.json or set ASC_KEY_ID, ASC_ISSUER, ASC_KEY_PATH)")
    return config


def asc_token(config, now=None):
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

    now = int(now if now is not None else time.time())
    key = serialization.load_pem_private_key(Path(config["key_path"]).expanduser().read_bytes(), None)
    head = b64(json.dumps({"alg": "ES256", "kid": config["key_id"], "typ": "JWT"}).encode())
    claim = b64(json.dumps({"iss": config["issuer"], "iat": now, "exp": now + 900,
                            "aud": "appstoreconnect-v1"}).encode())
    r, s = decode_dss_signature(key.sign(f"{head}.{claim}".encode(), ec.ECDSA(hashes.SHA256())))
    return f"{head}.{claim}.{b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def asc_client(config=None):
    return Client(asc_token(config or asc_config()))
