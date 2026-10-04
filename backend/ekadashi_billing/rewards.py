"""Self-reported observance rewards; no cash, wagers, paid entry or coin sales."""

import hashlib
import json
import uuid
from datetime import date
from pathlib import Path
from zoneinfo import ZoneInfo

from sqlalchemy import func, insert, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from . import database as db

CONTEXTS = {
    "IST": "Asia/Kolkata",
    "EST": "America/New_York",
    "CST": "America/Chicago",
    "MST": "America/Denver",
    "PST": "America/Los_Angeles",
}


class RewardConflict(ValueError):
    pass


class Catalog:
    def __init__(self, dates):
        self.dates = {
            uid: (value if isinstance(value, dict) else {"IST": value})
            for uid, value in dates.items()
        }
        self.uids = tuple(self.dates)
        for uid, values in self.dates.items():
            parts = uid.split(":")
            if len(parts) != 3 or parts[0] != "ekadashi" or not parts[1].isdigit():
                raise ValueError("invalid_catalog_uid")
            if not values or any(not isinstance(day, date) for day in values.values()):
                raise ValueError("invalid_catalog_date")

    @classmethod
    def from_assets(cls, root):
        result = {}
        for pack in sorted(Path(root).glob("20??.json")):
            for event in json.loads(pack.read_text())["ekadashis"]:
                uid = event["occurrence_uid"]
                if uid in result:
                    raise ValueError("duplicate_catalog_uid")
                result[uid] = {
                    key: date.fromisoformat(value["date"])
                    for key, value in event["timing"].items()
                    if key in CONTEXTS
                }
        if not result:
            raise ValueError("empty_catalog")
        return cls(result)

    def year_uids(self, year):
        return tuple(uid for uid in self.uids if int(uid.split(":")[1]) == year)

    def eligible(self, uid, now, context):
        if uid not in self.dates or context not in self.dates[uid] or context not in CONTEXTS:
            raise ValueError("unknown_occurrence_or_context")
        return self.dates[uid][context] <= now.astimezone(ZoneInfo(CONTEXTS[context])).date()


def lock_account(conn, account):
    # Creation and every subsequent mutation serialize on one account row.
    dialect_insert = pg_insert if conn.dialect.name == "postgresql" else sqlite_insert
    conn.execute(
        dialect_insert(db.accounts)
        .values(id=account, balance=0)
        .on_conflict_do_nothing(index_elements=["id"])
    )
    row = (
        conn.execute(select(db.accounts).where(db.accounts.c.id == account).with_for_update())
        .mappings()
        .one()
    )
    if row["deleted_at"] is not None:
        raise RewardConflict("account_deleted")
    return row


def ledger_delta(conn, account, delta, kind, reference, now):
    if delta == 0:
        return
    conn.execute(
        insert(db.ledger).values(
            id=str(uuid.uuid4()),
            account_id=account,
            delta=delta,
            kind=kind,
            reference=reference,
            created_at=now,
        )
    )
    conn.execute(
        update(db.accounts)
        .where(db.accounts.c.id == account)
        .values(balance=db.accounts.c.balance + delta)
    )


def wallet_locked(conn, account):
    balance = conn.execute(
        select(db.accounts.c.balance).where(db.accounts.c.id == account)
    ).scalar_one()
    reserved = conn.execute(
        select(func.coalesce(func.sum(db.redemptions.c.cost), 0)).where(
            db.redemptions.c.account_id == account,
            db.redemptions.c.state.in_(["reserved", "pending", "needs_review"]),
        )
    ).scalar_one()
    versions = (
        conn.execute(
            select(
                db.observances.c.uid,
                db.observances.c.version,
                db.observances.c.observed,
            ).where(db.observances.c.account_id == account)
        )
        .mappings()
        .all()
    )
    return {
        "coins": max(0, balance - reserved),
        "reservedCoins": reserved,
        "observances": {
            r["uid"]: {"version": r["version"], "observed": r["observed"]} for r in versions
        },
        "redemptionCost": 300,
        "premiumMonths": 6,
    }


class RewardsService:
    def __init__(self, engine, catalog, clock):
        self.engine, self.catalog, self.clock = engine, catalog, clock

    def wallet(self, account):
        with self.engine.begin() as conn:
            lock_account(conn, account)
            return wallet_locked(conn, account)

    def ledger(self, account):
        with self.engine.begin() as conn:
            lock_account(conn, account)
            return [
                dict(r)
                for r in conn.execute(
                    select(db.ledger)
                    .where(db.ledger.c.account_id == account)
                    .order_by(db.ledger.c.created_at, db.ledger.c.id)
                ).mappings()
            ]

    def record(
        self,
        account,
        uid,
        status,
        mutation_key,
        *,
        expected_version=None,
        context="IST",
    ):
        if status not in ["observed", "partial", "missed", "unrecorded"]:
            raise ValueError("invalid_observance")
        if not mutation_key or len(mutation_key) > 128:
            raise ValueError("invalid_mutation_key")
        now = self.clock()
        eligible = self.catalog.eligible(uid, now, context)
        observed = status == "observed"
        if observed and not eligible:
            raise ValueError("future_occurrence")
        fingerprint = hashlib.sha256(
            json.dumps([uid, status, expected_version, context]).encode()
        ).hexdigest()
        with self.engine.begin() as conn:
            lock_account(conn, account)
            prior = (
                conn.execute(
                    select(db.mutations).where(
                        db.mutations.c.account_id == account,
                        db.mutations.c.key == mutation_key,
                    )
                )
                .mappings()
                .first()
            )
            if prior:
                if prior["fingerprint"] != fingerprint:
                    raise RewardConflict("mutation_key_reused")
                return wallet_locked(conn, account)
            old = (
                conn.execute(
                    select(db.observances).where(
                        db.observances.c.account_id == account,
                        db.observances.c.uid == uid,
                    )
                )
                .mappings()
                .first()
            )
            if old and old["observed"] != observed and expected_version != old["version"]:
                raise RewardConflict("stale_observance")
            if old is None and expected_version not in [None, 0]:
                raise RewardConflict("stale_observance")
            # Same-state baselines from other devices cannot multiply awards.
            # Corrections require an exact current server version.
            if old is None or old["observed"] != observed:
                version = 1 if old is None else old["version"] + 1
                award = 10 if observed else 0
                if old is None:
                    conn.execute(
                        insert(db.observances).values(
                            account_id=account,
                            uid=uid,
                            observed=observed,
                            version=version,
                            award=award,
                        )
                    )
                else:
                    conn.execute(
                        update(db.observances)
                        .where(
                            db.observances.c.account_id == account,
                            db.observances.c.uid == uid,
                        )
                        .values(observed=observed, version=version, award=award)
                    )
                ledger_delta(
                    conn,
                    account,
                    award - (old["award"] if old else 0),
                    "observance",
                    f"{uid}:version:{version}",
                    now,
                )
                self._annual_bonus(conn, account, int(uid.split(":")[1]), mutation_key, now)
            conn.execute(
                insert(db.mutations).values(
                    account_id=account, key=mutation_key, fingerprint=fingerprint
                )
            )
            return wallet_locked(conn, account)

    def _annual_bonus(self, conn, account, year, mutation_key, now):
        uids = self.catalog.year_uids(year)
        completed = conn.execute(
            select(func.count())
            .select_from(db.observances)
            .where(
                db.observances.c.account_id == account,
                db.observances.c.uid.in_(uids),
                db.observances.c.observed.is_(True),
            )
        ).scalar_one()
        desired = max(0, 300 - len(uids) * 10) if uids and completed == len(uids) else 0
        old = (
            conn.execute(
                select(db.bonuses).where(
                    db.bonuses.c.account_id == account, db.bonuses.c.year == year
                )
            )
            .mappings()
            .first()
        )
        previous = old["award"] if old else 0
        if desired == previous:
            return
        if old:
            conn.execute(
                update(db.bonuses)
                .where(db.bonuses.c.account_id == account, db.bonuses.c.year == year)
                .values(award=desired)
            )
        else:
            conn.execute(insert(db.bonuses).values(account_id=account, year=year, award=desired))
        ledger_delta(
            conn,
            account,
            desired - previous,
            "annual_bonus",
            f"year:{year}:mutation:{mutation_key}",
            now,
        )
