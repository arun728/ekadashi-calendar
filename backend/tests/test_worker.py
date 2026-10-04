from datetime import timedelta

from cryptography.fernet import Fernet
from sqlalchemy import select, update
from test_fulfillment import Publisher

from ekadashi_billing import database as db
from ekadashi_billing.fulfillment import BillingService
from ekadashi_billing.play import SUBSCRIPTION
from ekadashi_billing.worker import run_once


def test_worker_acknowledges_durable_purchase_after_outage(engine, clock):
    publisher = Publisher(clock)
    billing = BillingService(engine, publisher, clock, Fernet.generate_key())
    publisher.fail_ack = True
    billing.verify("account", "token", SUBSCRIPTION)
    publisher.fail_ack = False
    assert run_once(billing) == 0
    with engine.connect() as c:
        assert c.execute(select(db.receipts.c.acknowledged)).scalar_one()


def test_deleted_receipt_retention_is_bounded_and_skips_refresh(engine, clock):
    billing = BillingService(engine, Publisher(clock), clock, Fernet.generate_key())
    billing.verify("old", "token-old", SUBSCRIPTION)
    billing.verify("recent", "token-recent", SUBSCRIPTION)
    with engine.begin() as c:
        for account, days in [("old", 181), ("recent", 179)]:
            c.execute(
                update(db.accounts)
                .where(db.accounts.c.id == account)
                .values(deleted_at=clock() - timedelta(days=days))
            )
            c.execute(
                update(db.receipts)
                .where(db.receipts.c.account_id == account)
                .values(state="ACCOUNT_DELETED", encrypted_token="")
            )
    assert run_once(billing) == 0
    with engine.connect() as c:
        assert list(c.execute(select(db.accounts.c.id)).scalars()) == ["recent"]
        assert list(c.execute(select(db.receipts.c.account_id)).scalars()) == ["recent"]
