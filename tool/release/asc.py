#!/usr/bin/env python3
"""App Store Connect API for Ekadashi Calendar (read only unless you say so).

  asc.py products        subscription groups, subscriptions, in-app purchases and their texts
  asc.py get PATH        any GET, for example /v1/apps?filter[bundleId]=com.apptinel.ekadashi-calendar

Credentials: see store_api.py (~/.config/ekadashi/asc.json).
"""

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import store_api  # noqa: E402


def get(client, path):
    return client.call("GET", store_api.ASC + path)


def products(client):
    apps = get(client, f"/v1/apps?filter[bundleId]={store_api.IOS_BUNDLE_ID}")["data"]
    app = apps[0]["id"]
    print("app", app, apps[0]["attributes"]["name"])
    for group in get(client, f"/v1/apps/{app}/subscriptionGroups")["data"]:
        print("GROUP", group["attributes"]["referenceName"])
        for sub in get(client, f"/v1/subscriptionGroups/{group['id']}/subscriptions")["data"]:
            print(" SUB", sub["attributes"]["productId"], sub["attributes"]["state"], sub["id"])
            for loc in get(client, f"/v1/subscriptions/{sub['id']}/subscriptionLocalizations")["data"]:
                a = loc["attributes"]
                print("    ", a["locale"], "|", a.get("name"), "|", a.get("description"))
    for iap in get(client, f"/v1/apps/{app}/inAppPurchasesV2")["data"]:
        print(" IAP", iap["attributes"]["productId"], iap["attributes"]["state"], iap["id"])
        for loc in get(client, f"/v2/inAppPurchases/{iap['id']}/inAppPurchaseLocalizations")["data"]:
            a = loc["attributes"]
            print("    ", a["locale"], "|", a.get("name"), "|", a.get("description"))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("products")
    raw = commands.add_parser("get")
    raw.add_argument("path")
    args = parser.parse_args(argv)
    client = store_api.asc_client()
    if args.command == "products":
        products(client)
    else:
        print(json.dumps(get(client, args.path), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
