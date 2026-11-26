# Release tools

Tools used to ship v2: store APIs, test-order cleanup and real-device checks.
Their offline tests are in `test/tool/test_release_tools.py`
(`python3 -m unittest discover -s test/tool`).

## Credentials (never in the repo, never delete them)

| Store | File | Override |
|---|---|---|
| Google Play | `~/.config/ekadashi/play-service-account.json` | `PLAY_SERVICE_ACCOUNT` |
| App Store Connect | `~/.config/ekadashi/asc.json`: `{"key_id": …, "issuer": …, "key_path": "…/AuthKey_….p8"}` | `ASC_KEY_ID`, `ASC_ISSUER`, `ASC_KEY_PATH` |

Other agents and tools use these keys, so never delete or rotate them.
Signing needs Python's `cryptography` package, for example in a venv:
`python3 -m venv build/venv && build/venv/bin/pip install cryptography pillow`.

## Google Play (`play.py`)

```bash
build/venv/bin/python tool/release/play.py tracks
build/venv/bin/python tool/release/play.py products
flutter build appbundle --release
build/venv/bin/python tool/release/play.py upload --track internal --notes "What testers should check"
build/venv/bin/python tool/release/play.py purchase ekadashi_premium_lifetime PURCHASE_TOKEN
build/venv/bin/python tool/release/play.py refund ORDER_ID --yes
build/venv/bin/python tool/release/play.py consume ekadashi_premium_lifetime PURCHASE_TOKEN --yes
```

- `upload` reads the version from `pubspec.yaml`, refuses a bundle with another
  version code, names the release "2.0.0 (13)" and rolls it out to the track.
  Bump the version code test-first (`test/unit/release_version_test.dart`):
  Play never accepts a code twice.
- `refund` revokes access by default (`--keep` refunds only). To let a tester
  buy Lifetime again, refund it with revoke, then `consume` its purchase token
  (from the app's debug log or the order in Play Console).
- `tracks` and `products` only read; `tracks` deletes its edit without committing.

## App Store Connect (`asc.py`)

```bash
build/venv/bin/python tool/release/asc.py products
build/venv/bin/python tool/release/asc.py get "/v1/apps?filter[bundleId]=com.apptinel.ekadashi-calendar"
```

## Devices

- `android-device.sh`: screenshot, labelled UI nodes with bounds, taps, or any
  adb command on the phone named by `ADB_SERIAL` (from `adb devices`).
- `ios-device-install.sh`: builds the Debug app (App Store sandbox) and installs
  it on the first paired iPhone, or `IOS_DEVICE`.
- `ios-device-step.sh ACTION`: runs one step of `ios/DeviceBillingUITests.swift`
  on the iPhone and saves its screenshots. The harness joins the UI test target
  only for that run. It never types a password: confirm Apple's sheet and Face
  ID on the phone yourself.

Devices are the source of truth for billing; simulator StoreKit is not.
