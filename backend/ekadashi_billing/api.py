"""Authenticated API. No client-controlled price, account or entitlement flags."""

import base64
import hashlib
import hmac
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, Response
from google.auth.transport.requests import Request
from google.oauth2 import id_token
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import create_engine, delete, select, update

from . import database as db
from .fulfillment import BillingService, token_hash
from .play import LIFETIME, SUBSCRIPTION, GooglePublisher, PublisherUnavailable, PurchaseRejected
from .rewards import Catalog, RewardConflict, RewardsService, lock_account


class StrictBody(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Purchase(StrictBody):
    productId: str = Field(max_length=100)
    purchaseToken: str = Field(min_length=1, max_length=4096)


class Observance(StrictBody):
    uid: str = Field(max_length=64)
    status: str = Field(max_length=20)
    mutationKey: str = Field(min_length=1, max_length=128)
    expectedVersion: int | None = Field(default=None, ge=0)
    context: str = Field(default="IST", max_length=10)


class Redeem(StrictBody):
    mutationKey: str = Field(min_length=1, max_length=128)


def create_app(billing, rewards, authenticate, authenticate_push):
    app = FastAPI(title="Ekadashi Premium", docs_url=None, redoc_url=None)

    def bearer(value):
        if not value or not value.startswith("Bearer "):
            raise HTTPException(401, "authentication_required")
        return value[7:]

    def identity(
        authorization: str | None = Header(default=None),
        expected_account: str | None = Header(
            default=None, alias="X-Expected-App-Account", max_length=128
        ),
    ):
        try:
            account = authenticate(bearer(authorization))
            if expected_account is not None and not hmac.compare_digest(expected_account, account):
                raise HTTPException(409, "identity_changed")
            return account
        except (ValueError, TypeError):
            raise HTTPException(401, "invalid_identity") from None

    def run(operation):
        try:
            return operation()
        except RewardConflict as exc:
            raise HTTPException(409, str(exc)) from None
        except PurchaseRejected as exc:
            raise HTTPException(422, str(exc)) from None
        except PublisherUnavailable:
            raise HTTPException(503, "purchase_verification_unavailable") from None
        except ValueError as exc:
            raise HTTPException(422, str(exc)) from None

    @app.get("/health")
    def health():
        return {"ok": True}

    @app.get("/v1/session")
    def session(account=Depends(identity)):
        return run(lambda: {"accountId": account, **billing.refresh(account)})

    @app.post("/v1/purchases/verify")
    def verify(body: Purchase, account=Depends(identity)):
        return run(lambda: billing.verify(account, body.purchaseToken, body.productId))

    @app.get("/v1/wallet")
    def wallet(account=Depends(identity)):
        return run(lambda: rewards.wallet(account))

    @app.post("/v1/observances")
    def record(
        body: Observance,
        account=Depends(identity),
        expected_account: str | None = Header(default=None, alias="X-Expected-App-Account"),
    ):
        if expected_account is not None and not hmac.compare_digest(expected_account, account):
            raise HTTPException(409, "identity_changed")
        return run(
            lambda: rewards.record(
                account,
                body.uid,
                body.status,
                body.mutationKey,
                expected_version=body.expectedVersion,
                context=body.context,
            )
        )

    @app.post("/v1/rewards/redeem")
    def redeem(body: Redeem, account=Depends(identity)):
        return run(
            lambda: {
                **billing.redeem(account, body.mutationKey),
                **billing.entitlement(account),
                **rewards.wallet(account),
            }
        )

    @app.delete("/v1/account", status_code=204)
    def remove(account=Depends(identity)):
        def perform():
            with billing.engine.begin() as c:
                lock_account(c, account)
                for table in [
                    db.promotions,
                    db.redemptions,
                    db.ledger,
                    db.mutations,
                    db.bonuses,
                    db.observances,
                ]:
                    c.execute(delete(table).where(table.c.account_id == account))
                c.execute(
                    update(db.accounts)
                    .where(db.accounts.c.id == account)
                    .values(balance=0, deleted_at=billing.clock())
                )
                # Pseudonymous receipt binding retained for fraud prevention;
                # erased after documented retention. Does not cancel Play billing.
                c.execute(
                    update(db.receipts)
                    .where(db.receipts.c.account_id == account)
                    .values(
                        state="ACCOUNT_DELETED",
                        encrypted_token="",
                        lifetime=False,
                        expiry=None,
                    )
                )
            return Response(status_code=204)

        return run(perform)

    @app.post("/v1/play/rtdn")
    def push(body: dict, authorization: str | None = Header(default=None)):
        try:
            if not authenticate_push(bearer(authorization)):
                raise ValueError()
        except (ValueError, TypeError):
            raise HTTPException(401, "invalid_push_identity") from None
        try:
            payload = json.loads(base64.b64decode(body["message"]["data"], validate=True))
            if payload["packageName"] != billing.publisher.package:
                raise ValueError()
            note = (
                payload.get("subscriptionNotification")
                or payload.get("oneTimeProductNotification")
                or payload.get("voidedPurchaseNotification")
            )
            if note:
                key = token_hash(note["purchaseToken"])
                with billing.engine.connect() as c:
                    account = c.execute(
                        select(db.receipts.c.account_id).where(db.receipts.c.token_hash == key)
                    ).scalar_one_or_none()
                if account:
                    run(lambda: billing.refresh(account))
                else:
                    product = (
                        SUBSCRIPTION
                        if "subscriptionNotification" in payload
                        else LIFETIME
                        if "oneTimeProductNotification" in payload
                        else None
                    )
                    if product:
                        run(lambda: billing.discover(note["purchaseToken"], product))
            elif "testNotification" not in payload:
                raise ValueError()
        except (KeyError, ValueError, TypeError):
            raise HTTPException(422, "invalid_notification") from None
        return {"ok": True}

    return app


def production_app():
    # Required settings, no credential defaults or test authentication fallback.
    url = os.environ["DATABASE_URL"]
    if not url.startswith("postgresql"):
        raise RuntimeError("PostgreSQL required")
    audience = os.environ["GOOGLE_WEB_CLIENT_ID"]
    push_audience = os.environ["PUBSUB_PUSH_AUDIENCE"]
    push_email = os.environ["PUBSUB_SERVICE_ACCOUNT_EMAIL"]
    secret = os.environ["ACCOUNT_HMAC_KEY"].encode()
    if len(secret) < 32:
        raise RuntimeError("HMAC secret must be at least 32 bytes")

    def authenticate(token):
        value = id_token.verify_oauth2_token(token, Request(), audience)
        if value["iss"] not in {"accounts.google.com", "https://accounts.google.com"}:
            raise ValueError()
        return hmac.new(secret, value["sub"].encode(), hashlib.sha256).hexdigest()

    def push_identity(token):
        value = id_token.verify_oauth2_token(token, Request(), push_audience)
        return value.get("email") == push_email and value.get("email_verified") is True

    engine = create_engine(url, pool_pre_ping=True)

    def clock():
        return datetime.now(timezone.utc)

    billing = BillingService(
        engine,
        GooglePublisher(clock),
        clock,
        os.environ["RECEIPT_ENCRYPTION_KEY"].encode(),
    )
    catalog = Catalog.from_assets(
        os.environ.get("CALENDAR_ASSET_PATH", str(Path(__file__).parents[2] / "assets/calendar"))
    )
    return create_app(billing, RewardsService(engine, catalog, clock), authenticate, push_identity)
