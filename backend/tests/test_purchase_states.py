from datetime import datetime, timezone

import pytest

from ekadashi_billing.play import (
    PurchaseRejected,
    normalize_lifetime,
    normalize_subscription,
)

NOW = datetime(2026, 10, 4, tzinfo=timezone.utc)


def subscription(state="ACTIVE", expiry="2027-10-04T00:00:00Z"):
    return {
        "subscriptionState": "SUBSCRIPTION_STATE_" + state,
        "externalAccountIdentifiers": {"obfuscatedExternalAccountId": "alice"},
        "lineItems": [
            {
                "productId": "ekadashi_premium",
                "expiryTime": expiry,
                "offerDetails": {"basePlanId": "yearly"},
                "autoRenewingPlan": {"autoRenewEnabled": True},
            }
        ],
        "acknowledgementState": "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
        "etag": "v1",
    }


@pytest.mark.parametrize(
    "state,active",
    [
        ("ACTIVE", True),
        ("IN_GRACE_PERIOD", True),
        ("CANCELED", True),
        ("ON_HOLD", False),
        ("PAUSED", False),
        ("EXPIRED", False),
        ("PENDING", False),
        ("PENDING_PURCHASE_CANCELED", False),
    ],
)
def test_authoritative_subscription_states(state, active):
    assert normalize_subscription(subscription(state), "alice", NOW).active is active


def test_expiry_is_checked_even_if_receipt_claims_active():
    assert not normalize_subscription(
        subscription(expiry="2026-10-03T00:00:00Z"), "alice", NOW
    ).active


@pytest.mark.parametrize("change", ["account", "product", "base_plan", "expiry", "unknown_state"])
def test_mismatched_or_invalid_receipts_are_rejected(change):
    receipt = subscription()
    if change == "account":
        receipt["externalAccountIdentifiers"]["obfuscatedExternalAccountId"] = "bob"
    if change == "product":
        receipt["lineItems"][0]["productId"] = "another_product"
    if change == "base_plan":
        receipt["lineItems"][0]["offerDetails"]["basePlanId"] = "unknown_plan"
    if change == "expiry":
        receipt["lineItems"][0]["expiryTime"] = "invalid"
    if change == "unknown_state":
        receipt["subscriptionState"] = "UNRECOGNIZED"
    with pytest.raises(PurchaseRejected):
        normalize_subscription(receipt, "alice", NOW)


def lifetime(state=0, consumed=0):
    return {
        "purchaseState": state,
        "consumptionState": consumed,
        "acknowledgementState": 1,
        "productId": "ekadashi_premium_lifetime",
        "obfuscatedExternalAccountId": "alice",
    }


@pytest.mark.parametrize("state,active", [(0, True), (1, False), (2, False)])
def test_lifetime_is_only_granted_for_purchased_state(state, active):
    result = normalize_lifetime(lifetime(state), "alice", NOW)
    assert result.active is active
    assert result.lifetime is active


def test_consumed_lifetime_and_wrong_account_are_rejected():
    with pytest.raises(PurchaseRejected):
        normalize_lifetime(lifetime(consumed=1), "alice", NOW)
    with pytest.raises(PurchaseRejected):
        normalize_lifetime(lifetime(), "bob", NOW)


def test_pending_ack_is_reported_for_durable_completion():
    payload = subscription()
    payload["acknowledgementState"] = "ACKNOWLEDGEMENT_STATE_PENDING"
    assert normalize_subscription(payload, "alice", NOW).needs_acknowledgement
    payload = lifetime()
    payload["acknowledgementState"] = 0
    assert normalize_lifetime(payload, "alice", NOW).needs_acknowledgement
