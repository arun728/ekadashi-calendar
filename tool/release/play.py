#!/usr/bin/env python3
"""Google Play Developer API for Ekadashi Calendar.

  play.py tracks                         every track's releases (read only)
  play.py products                       subscriptions, base plans, India prices, listings
  play.py upload [--track internal] [--notes TEXT] [--aab PATH]
                                         upload the release AAB and roll it out on the track
  play.py purchase PRODUCT TOKEN         state of a one-time purchase (read only)
  play.py refund ORDER_ID --yes [--keep] refund an order; revokes access unless --keep
  play.py consume PRODUCT TOKEN --yes    consume a one-time purchase so it can be bought again

Build first: `flutter build appbundle --release`. The version comes from
pubspec.yaml; Play refuses a version code it has seen before.
"""

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import store_api  # noqa: E402

EDITS = store_api.PLAY_APP + "/edits"
DEFAULT_AAB = store_api.ROOT / "build/app/outputs/bundle/release/app-release.aab"


def tracks(client):
    edit = client.call("POST", EDITS, {})["id"]
    try:
        rows = []
        for track in client.call("GET", f"{EDITS}/{edit}/tracks").get("tracks", []):
            for release in track.get("releases", []):
                rows.append((track["track"], release.get("status"), release.get("name"),
                             release.get("versionCodes")))
        return rows
    finally:
        client.call("DELETE", f"{EDITS}/{edit}")


def upload(client, aab, pubspec=store_api.ROOT / "pubspec.yaml", track="internal", notes=None):
    _, code = store_api.pubspec_version(pubspec)
    edit = client.call("POST", EDITS, {})["id"]
    uploaded = client.call("POST", f"{store_api.PLAY_UPLOAD}/edits/{edit}/bundles?uploadType=media",
                           data=Path(aab).read_bytes(), ctype="application/octet-stream")
    if uploaded.get("versionCode") != code:
        client.call("DELETE", f"{EDITS}/{edit}")
        raise SystemExit(f"The bundle has version code {uploaded.get('versionCode')} but pubspec.yaml "
                         f"says {code}; rebuild with `flutter build appbundle --release`.")
    release = {"name": store_api.release_name(pubspec), "versionCodes": [str(code)], "status": "completed"}
    if notes:
        release["releaseNotes"] = [{"language": "en-US", "text": notes}]
    result = client.call("PUT", f"{EDITS}/{edit}/tracks/{track}", {"track": track, "releases": [release]})
    client.call("POST", f"{EDITS}/{edit}:commit")
    return {"versionCode": code, "track": result.get("track"), "release": release}


def products(client):
    for sub in client.call("GET", f"{store_api.PLAY_APP}/subscriptions").get("subscriptions", []):
        print("SUB", sub["productId"], "(archived)" if sub.get("archived") else "")
        for plan in sub.get("basePlans", []):
            renewing = plan.get("autoRenewingBasePlanType", {})
            india = next((c for c in plan.get("regionalConfigs", []) if c.get("regionCode") == "IN"), {})
            price = india.get("price", {})
            print("   base plan", plan["basePlanId"], plan.get("state"), renewing.get("billingPeriodDuration"),
                  "IN", price.get("units"), price.get("currencyCode"))
        for listing in sub.get("listings", []):
            print("   listing", listing["languageCode"], "|", listing.get("title"), "|", listing.get("benefits"))
    for item in client.call("GET", f"{store_api.PLAY_APP}/oneTimeProducts").get("oneTimeProducts", []):
        print("ONE-TIME", item["productId"], [o.get("state") for o in item.get("purchaseOptions", [])])


def purchase(client, product, token):
    data = client.call("GET", f"{store_api.PLAY_APP}/purchases/products/{product}/tokens/{token}")
    return {k: data.get(k) for k in ("orderId", "purchaseState", "consumptionState",
                                     "acknowledgementState", "purchaseType", "refundableQuantity")}


def refund(client, order, revoke=True):
    suffix = "?revoke=true" if revoke else ""
    return client.call("POST", f"{store_api.PLAY_APP}/orders/{order}:refund{suffix}", {})


def consume(client, product, token):
    return client.call("POST", f"{store_api.PLAY_APP}/purchases/products/{product}/tokens/{token}:consume", {})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("tracks")
    commands.add_parser("products")
    up = commands.add_parser("upload")
    up.add_argument("--track", default="internal")
    up.add_argument("--notes")
    up.add_argument("--aab", default=str(DEFAULT_AAB))
    read = commands.add_parser("purchase")
    read.add_argument("product")
    read.add_argument("token")
    back = commands.add_parser("refund")
    back.add_argument("order")
    back.add_argument("--keep", action="store_true", help="refund without revoking access")
    back.add_argument("--yes", action="store_true")
    use = commands.add_parser("consume")
    use.add_argument("product")
    use.add_argument("token")
    use.add_argument("--yes", action="store_true")
    args = parser.parse_args(argv)

    if args.command in ("refund", "consume") and not args.yes:
        parser.exit(2, f"{args.command} changes a real order: run it again with --yes\n")
    client = store_api.play_client()
    if args.command == "tracks":
        for row in tracks(client):
            print(*row)
    elif args.command == "products":
        products(client)
    elif args.command == "upload":
        print(upload(client, args.aab, track=args.track, notes=args.notes))
    elif args.command == "purchase":
        print(purchase(client, args.product, args.token))
    elif args.command == "refund":
        print(refund(client, args.order, revoke=not args.keep) or "refunded")
    elif args.command == "consume":
        print(consume(client, args.product, args.token) or "consumed")


if __name__ == "__main__":
    main()
