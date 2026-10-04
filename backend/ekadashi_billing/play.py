"""Google Publisher receipt verification. Credentials stay on the server."""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from urllib.parse import quote

import google.auth
from google.auth.transport.requests import AuthorizedSession
from requests import RequestException

SUBSCRIPTION = "ekadashi_premium"
LIFETIME = "ekadashi_premium_lifetime"
BASE_PLANS = {"monthly", "yearly"}
PACKAGE = "com.applausestudios.ekadashi_calendar"


class PurchaseRejected(ValueError):
    pass


class PublisherUnavailable(RuntimeError):
    pass


class ReceiptChanged(PurchaseRejected):
    pass


@dataclass(frozen=True)
class VerifiedPurchase:
    product_id: str
    state: str
    active: bool
    expiry: datetime | None = None
    lifetime: bool = False
    base_plan: str | None = None
    auto_renew: bool = False
    needs_acknowledgement: bool = False
    etag: str | None = None
    linked_token: str | None = field(default=None, repr=False)


def parse_time(value):
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if result.tzinfo is None:
            raise ValueError()
        return result.astimezone(timezone.utc)
    except (ValueError, AttributeError, TypeError) as exc:
        raise PurchaseRejected("invalid_expiry") from exc


def normalize_subscription(payload, account, now):
    if payload.get("externalAccountIdentifiers", {}).get("obfuscatedExternalAccountId") != account:
        raise PurchaseRejected("purchase_account_mismatch")
    state = payload.get("subscriptionState", "").removeprefix("SUBSCRIPTION_STATE_")
    known = {
        "ACTIVE",
        "IN_GRACE_PERIOD",
        "CANCELED",
        "ON_HOLD",
        "PAUSED",
        "EXPIRED",
        "PENDING",
        "PENDING_PURCHASE_CANCELED",
    }
    if state not in known:
        raise PurchaseRejected("unknown_purchase_state")
    items = [i for i in payload.get("lineItems", []) if i.get("productId") == SUBSCRIPTION]
    if not items:
        raise PurchaseRejected("purchase_product_mismatch")
    if any(i.get("offerDetails", {}).get("basePlanId") not in BASE_PLANS for i in items):
        raise PurchaseRejected("purchase_base_plan_mismatch")
    item = max(items, key=lambda i: parse_time(i.get("expiryTime")))
    expiry = parse_time(item.get("expiryTime"))
    active = state in {"ACTIVE", "IN_GRACE_PERIOD", "CANCELED"} and expiry > now
    ack = payload.get("acknowledgementState")
    if ack not in {
        "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
        "ACKNOWLEDGEMENT_STATE_PENDING",
    }:
        raise PurchaseRejected("unknown_acknowledgement_state")
    return VerifiedPurchase(
        product_id=SUBSCRIPTION,
        state=state,
        active=active,
        expiry=expiry,
        base_plan=item["offerDetails"]["basePlanId"],
        auto_renew=item.get("autoRenewingPlan", {}).get("autoRenewEnabled") is True,
        needs_acknowledgement=active and ack == "ACKNOWLEDGEMENT_STATE_PENDING",
        etag=payload.get("etag"),
        linked_token=payload.get("linkedPurchaseToken"),
    )


def normalize_lifetime(payload, account, now):
    if payload.get("obfuscatedExternalAccountId") != account:
        raise PurchaseRejected("purchase_account_mismatch")
    # Legacy products.get binds the product through its request path; reject an
    # explicit response product mismatch as well.
    if payload.get("productId", LIFETIME) != LIFETIME:
        raise PurchaseRejected("purchase_product_mismatch")
    state = payload.get("purchaseState")
    if type(state) is not int or state not in {0, 1, 2}:
        raise PurchaseRejected("unknown_purchase_state")
    if payload.get("consumptionState") != 0:
        raise PurchaseRejected("consumed_lifetime")
    ack = payload.get("acknowledgementState")
    if type(ack) is not int or ack not in {0, 1}:
        raise PurchaseRejected("unknown_acknowledgement_state")
    active = state == 0
    return VerifiedPurchase(
        product_id=LIFETIME,
        state={0: "PURCHASED", 1: "CANCELED", 2: "PENDING"}[state],
        active=active,
        lifetime=active,
        needs_acknowledgement=active and ack == 0,
    )


class GooglePublisher:
    def __init__(self, clock, package=PACKAGE, session=None):
        self.clock, self.package = clock, package
        if session is None:
            credentials, _ = google.auth.default(
                scopes=["https://www.googleapis.com/auth/androidpublisher"]
            )
            session = AuthorizedSession(credentials)
        self.session = session

    def _request(self, method, path, body=None):
        root = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + quote(
            self.package, safe=""
        )
        try:
            r = self.session.request(method, root + path, json=body, timeout=10)
        except RequestException as exc:
            raise PublisherUnavailable("publisher_unavailable") from exc
        if r.status_code >= 500 or r.status_code in {401, 403, 429}:
            raise PublisherUnavailable("publisher_unavailable")
        if r.status_code not in {200, 204}:
            if r.status_code in {409, 412}:
                raise ReceiptChanged("receipt_changed")
            raise PurchaseRejected("publisher_rejected_request")
        return r.json() if r.content else {}

    def verify(self, token, product, account):
        token_path = quote(token, safe="")
        if product == SUBSCRIPTION:
            payload = self._request("GET", "/purchases/subscriptionsv2/tokens/" + token_path)
            return normalize_subscription(payload, account, self.clock())
        if product == LIFETIME:
            payload = self._request(
                "GET", "/purchases/products/" + LIFETIME + "/tokens/" + token_path
            )
            return normalize_lifetime(payload, account, self.clock())
        raise PurchaseRejected("purchase_product_mismatch")

    def acknowledge(self, token, product):
        kind = "subscriptions" if product == SUBSCRIPTION else "products"
        self._request(
            "POST",
            "/purchases/"
            + kind
            + "/"
            + quote(product, safe="")
            + "/tokens/"
            + quote(token, safe="")
            + ":acknowledge",
            {},
        )

    def defer(self, token, etag, duration_seconds):
        if not etag or duration_seconds <= 0:
            raise PurchaseRejected("invalid_deferral")
        return self._request(
            "POST",
            "/purchases/subscriptionsv2/tokens/" + quote(token, safe="") + ":defer",
            {
                "deferralContext": {
                    "etag": etag,
                    "deferDuration": f"{duration_seconds}s",
                    "validateOnly": False,
                }
            },
        )
