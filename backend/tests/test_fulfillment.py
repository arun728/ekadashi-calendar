from dataclasses import replace
from datetime import timedelta

import pytest
from cryptography.fernet import Fernet
from sqlalchemy import select

from ekadashi_billing import database as db
from ekadashi_billing.fulfillment import BillingService
from ekadashi_billing.play import (
    LIFETIME,
    SUBSCRIPTION,
    PublisherUnavailable,
    PurchaseRejected,
    VerifiedPurchase,
)


class Publisher:
    def __init__(self, clock):
        self.clock = clock
        self.calls = 0
        self.fail_ack = False
        self.fail_defer = False
        self.value = VerifiedPurchase(
            SUBSCRIPTION,
            "ACTIVE",
            True,
            clock() + timedelta(days=30),
            base_plan="yearly",
            auto_renew=True,
            needs_acknowledgement=True,
            etag="original",
        )

    def verify(self, token, product, account):
        return self.value

    def acknowledge(self, token, product):
        if self.fail_ack:
            raise PublisherUnavailable("temporary")
        self.value = replace(self.value, needs_acknowledgement=False)

    def defer(self, token, etag, duration_seconds):
        self.calls += 1
        assert etag == "original"
        self.value = replace(
            self.value,
            expiry=self.value.expiry + timedelta(seconds=duration_seconds),
            etag="extended",
        )
        if self.fail_defer:
            raise PublisherUnavailable("lost_response")


@pytest.fixture
def billing(engine, clock):
    return BillingService(engine, Publisher(clock), clock, Fernet.generate_key())


def earn(rewards):
    for i in range(1, 25):
        rewards.record("account", f"ekadashi:2025:{i:02}", "observed", f"claim{i}")


def test_receipts_encrypted_verified_and_bound(billing, engine):
    result = billing.verify("account", "secret-receipt", SUBSCRIPTION)
    assert result["premium"] and result["acknowledged"]
    with engine.connect() as c:
        row = c.execute(select(db.receipts)).mappings().one()
        assert "secret-receipt" not in row["encrypted_token"]
    with pytest.raises(PurchaseRejected):
        billing.verify("other-account", "secret-receipt", SUBSCRIPTION)


def test_pending_never_grants(billing):
    billing.publisher.value = replace(
        billing.publisher.value,
        state="PENDING",
        active=False,
        needs_acknowledgement=False,
    )
    result = billing.verify("account", "pending", SUBSCRIPTION)
    assert result["premium"] is False
    assert result["acknowledged"] is False


def test_ack_retry_durable(billing):
    billing.publisher.fail_ack = True
    assert billing.verify("account", "token", SUBSCRIPTION)["acknowledged"] is False
    billing.publisher.fail_ack = False
    billing.refresh("account")
    assert billing.entitlement("account")["premium"]
    with billing.engine.connect() as c:
        assert c.execute(select(db.receipts.c.acknowledged)).scalar_one()


def test_correction_and_redemption_once(billing, rewards):
    earn(rewards)
    result = billing.redeem("account", "redeem-one")
    assert result["state"] == "completed"
    assert billing.entitlement("account")["premium"]
    assert rewards.wallet("account")["coins"] == 0
    assert billing.redeem("account", "redeem-one") == result
    rewards.record("account", "ekadashi:2025:01", "missed", "edit", expected_version=1)
    assert rewards.wallet("account")["coins"] == 0


def test_low_balance_and_lifetime_no_spend(billing, rewards):
    with pytest.raises(ValueError):
        billing.redeem("account", "low")
    earn(rewards)
    billing.publisher.value = VerifiedPurchase(LIFETIME, "PURCHASED", True, lifetime=True)
    billing.verify("account", "life", LIFETIME)
    with pytest.raises(ValueError):
        billing.redeem("account", "no-need")
    assert rewards.wallet("account")["coins"] == 300


def test_deferral_lost_response_reconciles_without_double_extension(billing, rewards):
    earn(rewards)
    billing.verify("account", "token", SUBSCRIPTION)
    billing.publisher.fail_defer = True
    result = billing.redeem("account", "defer-one")
    assert result["state"] == "pending"
    assert rewards.wallet("account")["reservedCoins"] == 300
    result = billing.redeem("account", "defer-one")
    assert result["state"] == "completed"
    assert billing.publisher.calls == 1
    assert rewards.wallet("account")["coins"] == 0


def test_replaced_receipt_cannot_reactivate(billing):
    billing.verify("account", "old", SUBSCRIPTION)
    billing.publisher.value = replace(billing.publisher.value, linked_token="old")
    billing.verify("account", "new", SUBSCRIPTION)
    billing.publisher.value = replace(billing.publisher.value, linked_token=None)
    billing.verify("account", "old", SUBSCRIPTION)
    with billing.engine.connect() as c:
        assert "REPLACED" in list(c.execute(select(db.receipts.c.state)).scalars())


def test_unknown_product_rejected_before_verify(billing):
    with pytest.raises(PurchaseRejected):
        billing.verify("account", "token", "invented")
