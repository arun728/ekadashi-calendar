"""Run every few minutes: durable acknowledgement and deferral recovery."""

import os
from datetime import datetime, timedelta, timezone

from sqlalchemy import create_engine, delete, func, select, update

from . import database as db
from .fulfillment import BillingService
from .play import GooglePublisher, PublisherUnavailable, PurchaseRejected


def run_once(billing):
    with billing.engine.connect() as c:
        accounts = list(
            c.execute(
                select(db.receipts.c.account_id)
                .where(db.receipts.c.state.not_in(["REPLACED", "ACCOUNT_DELETED"]))
                .distinct()
            ).scalars()
        )
        pending = list(
            c.execute(
                select(db.redemptions.c.account_id, db.redemptions.c.key).where(
                    db.redemptions.c.state.in_(["reserved", "pending"])
                )
            )
        )
    with billing.engine.begin() as c:
        cutoff = billing.clock() - timedelta(days=180)
        deleted = list(
            c.execute(select(db.accounts.c.id).where(db.accounts.c.deleted_at < cutoff)).scalars()
        )
        for account in deleted:
            c.execute(
                delete(db.receipts).where(
                    db.receipts.c.account_id == account, db.receipts.c.state == "ACCOUNT_DELETED"
                )
            )
            restored = c.execute(
                select(func.count())
                .select_from(db.receipts)
                .where(db.receipts.c.account_id == account)
            ).scalar_one()
            if restored:
                # A fresh authenticated restore is new, necessary billing data;
                # erase the old deletion marker, never the valid purchase.
                c.execute(
                    update(db.accounts).where(db.accounts.c.id == account).values(deleted_at=None)
                )
            else:
                c.execute(delete(db.accounts).where(db.accounts.c.id == account))
    failed = 0
    for account in accounts:
        try:
            billing.refresh(account)
        except (PublisherUnavailable, PurchaseRejected):
            failed += 1
    for account, key in pending:
        try:
            billing.redeem(account, key)
        except (PublisherUnavailable, PurchaseRejected, ValueError):
            failed += 1
    return failed


if __name__ == "__main__":

    def clock():
        return datetime.now(timezone.utc)

    engine = create_engine(os.environ["DATABASE_URL"], pool_pre_ping=True)
    raise SystemExit(
        bool(
            run_once(
                BillingService(
                    engine,
                    GooglePublisher(clock),
                    clock,
                    os.environ["RECEIPT_ENCRYPTION_KEY"].encode(),
                )
            )
        )
    )
