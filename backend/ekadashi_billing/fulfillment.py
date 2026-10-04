"""Verified entitlements and transactional, non-cash premium credit redemption."""

import calendar
import hashlib
import uuid
from datetime import timezone

from cryptography.fernet import Fernet
from sqlalchemy import insert, select, update
from sqlalchemy.exc import IntegrityError

from . import database as db
from .play import (
    LIFETIME,
    SUBSCRIPTION,
    PublisherUnavailable,
    PurchaseRejected,
    ReceiptChanged,
)
from .rewards import ledger_delta, lock_account, wallet_locked


def utc(value):
    return value.replace(tzinfo=timezone.utc) if value and value.tzinfo is None else value


def six_months(value):
    month = value.month + 6
    year = value.year + (month - 1) // 12
    month = (month - 1) % 12 + 1
    return value.replace(
        year=year, month=month, day=min(value.day, calendar.monthrange(year, month)[1])
    )


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


class BillingService:
    def __init__(self, engine, publisher, clock, encryption_key):
        self.engine, self.publisher, self.clock = engine, publisher, clock
        self.cipher = Fernet(encryption_key)

    def verify(self, account, token, product):
        if product not in {SUBSCRIPTION, LIFETIME} or not token or len(token) > 4096:
            raise PurchaseRejected("invalid_purchase")
        value = self.publisher.verify(token, product, account)
        key = token_hash(token)
        try:
            with self.engine.begin() as c:
                lock_account(c, account, allow_deleted=True)
                old = (
                    c.execute(
                        select(db.receipts).where(db.receipts.c.token_hash == key).with_for_update()
                    )
                    .mappings()
                    .first()
                )
                if old and old["account_id"] != account:
                    raise PurchaseRejected("purchase_already_bound")
                state = "REPLACED" if old and old["state"] == "REPLACED" else value.state
                values = dict(
                    encrypted_token=self.cipher.encrypt(token.encode()).decode(),
                    account_id=account,
                    product_id=product,
                    base_plan=value.base_plan,
                    state=state,
                    expiry=value.expiry,
                    lifetime=value.lifetime,
                    auto_renew=value.auto_renew,
                    acknowledged=not value.needs_acknowledgement and value.active,
                    etag=value.etag,
                    updated_at=self.clock(),
                )
                if old:
                    c.execute(
                        update(db.receipts).where(db.receipts.c.token_hash == key).values(**values)
                    )
                else:
                    c.execute(insert(db.receipts).values(token_hash=key, **values))
                if value.linked_token:
                    c.execute(
                        update(db.receipts)
                        .where(
                            db.receipts.c.token_hash == token_hash(value.linked_token),
                            db.receipts.c.account_id == account,
                        )
                        .values(state="REPLACED")
                    )
        except IntegrityError as exc:
            raise PurchaseRejected("purchase_already_bound") from exc
        acknowledged = value.active and not value.needs_acknowledgement
        if value.needs_acknowledgement:
            try:
                self.publisher.acknowledge(token, product)
                with self.engine.begin() as c:
                    c.execute(
                        update(db.receipts)
                        .where(db.receipts.c.token_hash == key)
                        .values(acknowledged=True)
                    )
                acknowledged = True
            except PublisherUnavailable:
                # The receipt was durably saved first. Worker/resume retries.
                acknowledged = False
        return {**self.entitlement(account), "acknowledged": acknowledged}

    def discover(self, token, product):
        if not token or len(token) > 4096:
            raise PurchaseRejected("invalid_purchase")
        account = self.publisher.resolve_account(token, product)
        with self.engine.connect() as c:
            existing = (
                c.execute(
                    select(db.accounts).where(
                        db.accounts.c.id == account, db.accounts.c.deleted_at.is_(None)
                    )
                )
                .mappings()
                .first()
            )
        if existing:
            return self.verify(account, token, product)
        # A notification cannot create a new app account or bypass sign-in.
        return None

    def refresh(self, account):
        with self.engine.connect() as c:
            rows = (
                c.execute(
                    select(db.receipts).where(
                        db.receipts.c.account_id == account,
                        db.receipts.c.state.not_in(["REPLACED", "ACCOUNT_DELETED"]),
                    )
                )
                .mappings()
                .all()
            )
        for row in rows:
            try:
                self.verify(
                    account,
                    self.cipher.decrypt(row["encrypted_token"].encode()).decode(),
                    row["product_id"],
                )
            except PurchaseRejected:
                # Revoked/refunded/invalid purchases fail closed, not forever cached.
                with self.engine.begin() as c:
                    c.execute(
                        update(db.receipts)
                        .where(db.receipts.c.token_hash == row["token_hash"])
                        .values(state="REJECTED", lifetime=False, expiry=None)
                    )
        return self.entitlement(account)

    def entitlement(self, account):
        now = self.clock()
        with self.engine.begin() as c:
            lock_account(c, account, allow_deleted=True)
            receipts = (
                c.execute(select(db.receipts).where(db.receipts.c.account_id == account))
                .mappings()
                .all()
            )
            lifetime = any(r["lifetime"] and r["state"] == "PURCHASED" for r in receipts)
            active = [
                r
                for r in receipts
                if r["state"] in {"ACTIVE", "IN_GRACE_PERIOD", "CANCELED"}
                and r["expiry"]
                and utc(r["expiry"]) > now
            ]
            promos = (
                c.execute(select(db.promotions).where(db.promotions.c.account_id == account))
                .mappings()
                .all()
            )
            expiries = [utc(r["expiry"]) for r in active] + [
                utc(p["expires_at"])
                for p in promos
                if utc(p["starts_at"]) <= now < utc(p["expires_at"])
            ]
            return {
                "premium": lifetime or bool(expiries),
                "lifetime": lifetime,
                "validUntil": max(expiries).isoformat() if expiries else None,
                "serverTime": now.isoformat(),
                "autoRenew": any(r["auto_renew"] for r in active),
            }

    def redeem(self, account, key):
        if not key or len(key) > 128:
            raise ValueError("invalid_redemption_key")
        # Refresh paid state first; provider outage prevents unsafe promotional
        # grants over a renewing subscription. No coins spent on failed refresh.
        self.refresh(account)
        now = self.clock()
        with self.engine.begin() as c:
            lock_account(c, account)
            prior = (
                c.execute(
                    select(db.redemptions).where(
                        db.redemptions.c.account_id == account,
                        db.redemptions.c.key == key,
                    )
                )
                .mappings()
                .first()
            )
            if prior:
                operation = dict(prior)
                if operation["state"] in {"completed", "needs_review"}:
                    return {"id": operation["id"], "state": operation["state"]}
            else:
                rows = (
                    c.execute(
                        select(db.receipts).where(
                            db.receipts.c.account_id == account,
                            db.receipts.c.state.not_in(["REPLACED", "ACCOUNT_DELETED"]),
                        )
                    )
                    .mappings()
                    .all()
                )
                if any(r["lifetime"] and r["state"] == "PURCHASED" for r in rows):
                    raise ValueError("already_lifetime")
                if wallet_locked(c, account)["coins"] < 300:
                    raise ValueError("insufficient_coins")
                if any(r["state"] in {"ON_HOLD", "PAUSED", "PENDING"} for r in rows):
                    raise ValueError("manage_subscription_first")
                renewing = [
                    r
                    for r in rows
                    if r["auto_renew"]
                    and r["expiry"]
                    and utc(r["expiry"]) > now
                    and r["state"] in {"ACTIVE", "IN_GRACE_PERIOD"}
                ]
                if len(renewing) > 1:
                    raise ValueError("manage_subscription_first")
                operation = dict(
                    id=str(uuid.uuid4()),
                    account_id=account,
                    key=key,
                    cost=300,
                    state="reserved",
                    created_at=now,
                )
                if renewing:
                    receipt = renewing[0]
                    start = utc(receipt["expiry"])
                    end = six_months(start)
                    if not receipt["etag"]:
                        raise ValueError("receipt_etag_required")
                    operation.update(
                        token_hash=receipt["token_hash"],
                        etag=receipt["etag"],
                        original_expiry=start,
                        expected_expiry=end,
                        duration_seconds=int((end - start).total_seconds()),
                    )
                    c.execute(insert(db.redemptions).values(**operation))
                else:
                    expiries = [
                        utc(r["expiry"])
                        for r in rows
                        if r["expiry"] and utc(r["expiry"]) > now and r["state"] == "CANCELED"
                    ]
                    expiries += list(
                        map(
                            utc,
                            c.execute(
                                select(db.promotions.c.expires_at).where(
                                    db.promotions.c.account_id == account
                                )
                            ).scalars(),
                        )
                    )
                    start = max([now] + expiries)
                    end = six_months(start)
                    operation["state"] = "completed"
                    c.execute(insert(db.redemptions).values(**operation))
                    c.execute(
                        insert(db.promotions).values(
                            redemption_id=operation["id"],
                            account_id=account,
                            starts_at=start,
                            expires_at=end,
                        )
                    )
                    ledger_delta(c, account, -300, "redemption", operation["id"], now)
                    return {"id": operation["id"], "state": "completed"}
        return self._defer(account, operation)

    def _defer(self, account, operation):
        with self.engine.connect() as c:
            row = (
                c.execute(
                    select(db.receipts).where(db.receipts.c.token_hash == operation["token_hash"])
                )
                .mappings()
                .one()
            )
        token = self.cipher.decrypt(row["encrypted_token"].encode()).decode()
        value = self.publisher.verify(token, SUBSCRIPTION, account)
        expected = utc(operation["expected_expiry"])
        original = utc(operation["original_expiry"])
        if value.expiry == expected:
            state = "completed"
        elif value.expiry != original or value.etag != operation["etag"]:
            # A renewal/plan change made attribution ambiguous. Keep credit
            # reserved for support instead of extending twice or charging twice.
            state = "needs_review"
        else:
            try:
                self.publisher.defer(token, operation["etag"], operation["duration_seconds"])
                value = self.publisher.verify(token, SUBSCRIPTION, account)
                state = "completed" if value.expiry == expected else "pending"
            except (PublisherUnavailable, ReceiptChanged):
                state = "pending"
        with self.engine.begin() as c:
            lock_account(c, account)
            existing = (
                c.execute(
                    select(db.redemptions)
                    .where(db.redemptions.c.id == operation["id"])
                    .with_for_update()
                )
                .mappings()
                .one()
            )
            if existing["state"] == "completed":
                return {"id": operation["id"], "state": "completed"}
            c.execute(
                update(db.redemptions)
                .where(db.redemptions.c.id == operation["id"])
                .values(state=state)
            )
            if state == "completed":
                ledger_delta(c, account, -300, "redemption", operation["id"], self.clock())
                c.execute(
                    update(db.receipts)
                    .where(db.receipts.c.token_hash == operation["token_hash"])
                    .values(expiry=expected, etag=value.etag)
                )
        return {"id": operation["id"], "state": state}
