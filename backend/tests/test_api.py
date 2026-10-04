import base64
import json

import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient

from ekadashi_billing.api import create_app
from ekadashi_billing.fulfillment import BillingService
from ekadashi_billing.play import LIFETIME, VerifiedPurchase


class Publisher:
    package = "com.applausestudios.ekadashi_calendar"

    def resolve_account(self, token, product):
        return "account"

    def verify(self, token, product, account):
        return VerifiedPurchase(LIFETIME, "PURCHASED", True, lifetime=True)

    def acknowledge(self, *args):
        pass


@pytest.fixture
def client(engine, rewards, clock):
    billing = BillingService(engine, Publisher(), clock, Fernet.generate_key())

    def auth(token):
        if token != "signed-user-token":
            raise ValueError("bad token")
        return "account"

    return TestClient(
        create_app(billing, rewards, auth, lambda token: token == "signed-pubsub-token")
    )


HEADERS = {"Authorization": "Bearer signed-user-token"}


def test_unauthenticated_and_wrong_token_cannot_claim(client):
    assert client.get("/v1/wallet").status_code == 401
    assert client.get("/v1/wallet", headers={"Authorization": "Bearer forged"}).status_code == 401


def test_user_cannot_choose_account_and_api_never_accepts_paid_flag(client):
    response = client.post(
        "/v1/purchases/verify",
        headers=HEADERS,
        json={
            "productId": LIFETIME,
            "purchaseToken": "secret",
            "premium": True,
            "accountId": "someone-else",
        },
    )
    assert response.status_code == 422


def test_end_to_end_verify_and_wallet(client):
    assert client.post(
        "/v1/purchases/verify",
        headers=HEADERS,
        json={"productId": LIFETIME, "purchaseToken": "secret"},
    ).json()["premium"]
    result = client.post(
        "/v1/observances",
        headers=HEADERS,
        json={
            "uid": "ekadashi:2025:01",
            "status": "observed",
            "mutationKey": "stable-key",
            "expectedVersion": 0,
            "context": "IST",
        },
    )
    assert result.status_code == 200 and result.json()["coins"] == 10
    assert client.get("/v1/wallet", headers=HEADERS).json()["coins"] == 10


def test_other_account_queue_cannot_upload_after_identity_switch(client):
    result = client.post(
        "/v1/observances",
        headers={**HEADERS, "X-Expected-App-Account": "previous-account"},
        json={"uid": "ekadashi:2025:01", "status": "observed", "mutationKey": "private-previous"},
    )
    assert result.status_code == 409
    assert client.get("/v1/wallet", headers=HEADERS).json()["coins"] == 0


def test_rtdn_cannot_trust_notification_for_grant(client):
    assert client.post("/v1/play/rtdn", json={"message": {"data": "evil"}}).status_code == 401
    assert (
        client.post(
            "/v1/play/rtdn",
            headers={"Authorization": "Bearer signed-pubsub-token"},
            json={"message": {"data": "evil"}},
        ).status_code
        == 422
    )


def test_rtdn_discovers_verified_receipt_when_client_verification_was_interrupted(client):
    # Account exists from authenticated checkout preparation. Pub/Sub is signed;
    # entitlement must come from fresh Publisher verification, never this body.
    assert client.get("/v1/session", headers=HEADERS).status_code == 200
    payload = {
        "packageName": "com.applausestudios.ekadashi_calendar",
        "oneTimeProductNotification": {"sku": LIFETIME, "purchaseToken": "new-from-play"},
    }
    result = client.post(
        "/v1/play/rtdn",
        headers={"Authorization": "Bearer signed-pubsub-token"},
        json={"message": {"data": base64.b64encode(json.dumps(payload).encode()).decode()}},
    )
    assert result.status_code == 200
    assert client.get("/v1/session", headers=HEADERS).json()["premium"] is True


def test_delete_removes_cloud_history_but_does_not_recreate_rewards(client):
    client.post(
        "/v1/observances",
        headers=HEADERS,
        json={
            "uid": "ekadashi:2025:01",
            "status": "observed",
            "mutationKey": "claim",
            "context": "IST",
        },
    )
    assert client.delete("/v1/account", headers=HEADERS).status_code == 204
    assert client.get("/v1/wallet", headers=HEADERS).status_code == 409


def test_lifetime_restore_after_cloud_deletion_preserves_purchase_without_rewards_replay(client):
    client.post(
        "/v1/purchases/verify",
        headers=HEADERS,
        json={"productId": LIFETIME, "purchaseToken": "permanent-purchase"},
    )
    assert client.delete("/v1/account", headers=HEADERS).status_code == 204
    restored = client.post(
        "/v1/purchases/verify",
        headers=HEADERS,
        json={"productId": LIFETIME, "purchaseToken": "permanent-purchase"},
    )
    assert restored.status_code == 200 and restored.json()["premium"] is True
    assert client.get("/v1/wallet", headers=HEADERS).status_code == 409
