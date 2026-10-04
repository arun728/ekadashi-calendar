from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

import pytest

from ekadashi_billing.rewards import Catalog, RewardConflict, RewardsService

UID = "ekadashi:2025:01"


def claim(service, uid=UID, key="first", status="observed", version=None, account="alice"):
    return service.record(account, uid, status, key, expected_version=version)


@pytest.mark.parametrize(
    "status,coins", [("observed", 10), ("partial", 0), ("missed", 0), ("unrecorded", 0)]
)
def test_only_completed_self_report_is_rewarded(rewards, status, coins):
    assert claim(rewards, status=status)["coins"] == coins


def test_retry_and_other_device_do_not_mint_duplicates(rewards):
    for key in ["first", "first", "device2", "device3"]:
        assert claim(rewards, key=key)["coins"] == 10
    assert len(rewards.ledger("alice")) == 1


def test_same_idempotency_key_cannot_change_payload(rewards):
    claim(rewards)
    with pytest.raises(RewardConflict):
        claim(rewards, status="missed")
    assert rewards.wallet("alice")["coins"] == 10


def test_stale_device_cannot_undo_a_correction(rewards):
    claim(rewards)
    claim(rewards, key="delete", status="unrecorded", version=1)
    with pytest.raises(RewardConflict):
        claim(rewards, key="stale", version=1)
    with pytest.raises(RewardConflict):
        claim(rewards, key="baseline-old-device")
    assert rewards.wallet("alice")["coins"] == 0
    assert claim(rewards, key="explicit-new-record", version=2)["coins"] == 10
    assert sum(row["delta"] for row in rewards.ledger("alice")) == 10


def test_unknown_and_future_dates_cannot_award_coins(engine, clock):
    service = RewardsService(engine, Catalog({"ekadashi:2027:01": date(2027, 1, 1)}), clock)
    with pytest.raises(ValueError):
        claim(service, uid="ekadashi:2027:01")
    with pytest.raises(ValueError):
        claim(service, uid="ekadashi:9999:01")
    assert service.wallet("alice")["coins"] == 0


@pytest.mark.parametrize("count,bonus", [(24, 60), (26, 40)])
def test_full_year_uses_catalog_count_and_reverses_bonus(engine, clock, count, bonus):
    catalog = Catalog({f"ekadashi:2025:{i:02}": date(2025, 1, i) for i in range(1, count + 1)})
    service = RewardsService(engine, catalog, clock)
    for uid in catalog.uids:
        claim(service, uid=uid, key=uid)
    assert service.wallet("alice")["coins"] == 300
    assert [r["delta"] for r in service.ledger("alice") if r["kind"] == "annual_bonus"] == [bonus]
    claim(service, key="correction", status="partial", version=1)
    assert service.wallet("alice")["coins"] == (count - 1) * 10
    claim(service, key="re-record", version=2)
    assert service.wallet("alice")["coins"] == 300
    assert sum(r["delta"] for r in service.ledger("alice")) == 300


def test_rewards_persist_and_carry_across_years(engine, clock):
    catalog = Catalog(
        {
            UID: date(2025, 1, 1),
            "ekadashi:2026:01": date(2026, 1, 1),
            "ekadashi:2025:02": date(2025, 2, 1),
            "ekadashi:2026:02": date(2026, 2, 1),
        }
    )
    service = RewardsService(engine, catalog, clock)
    claim(service)
    claim(service, uid="ekadashi:2026:01", key="new-year")
    assert RewardsService(engine, catalog, clock).wallet("alice")["coins"] == 20
    assert service.wallet("bob")["coins"] == 0


def test_concurrent_duplicate_claims_award_once(rewards, engine):
    if engine.dialect.name != "postgresql":
        pytest.skip("Real row-lock test requires PostgreSQL")
    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda i: claim(rewards, key=f"device-{i}"), range(16)))
    assert rewards.wallet("alice")["coins"] == 10
    assert len(rewards.ledger("alice")) == 1


def test_real_packs_have_stable_year_occurrences():
    catalog = Catalog.from_assets(Path(__file__).resolve().parents[2] / "assets/calendar")
    assert len(catalog.year_uids(2026)) == 24
    assert len(catalog.year_uids(2027)) == 24
    assert len(catalog.uids) == 48
