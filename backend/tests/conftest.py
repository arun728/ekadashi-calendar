import os
import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine, text

from ekadashi_billing.database import metadata
from ekadashi_billing.rewards import Catalog, RewardsService


@pytest.fixture
def engine(tmp_path):
    url = os.getenv("EKADASHI_TEST_DATABASE_URL", f"sqlite:///{tmp_path}/rewards.sqlite")
    base = create_engine(url)
    schema = None
    if base.dialect.name == "postgresql":
        schema = "test_" + uuid.uuid4().hex
        with base.begin() as conn:
            conn.execute(text(f"CREATE SCHEMA {schema}"))
        db = base.execution_options(schema_translate_map={None: schema})
    else:
        db = base
    metadata.create_all(db)
    yield db
    if schema:
        with base.begin() as conn:
            conn.execute(text(f"DROP SCHEMA {schema} CASCADE"))
    base.dispose()


@pytest.fixture
def clock():
    return lambda: datetime(2026, 10, 4, 12, tzinfo=timezone.utc)


@pytest.fixture
def catalog():
    from datetime import date

    return Catalog({f"ekadashi:2025:{i:02}": date(2025, 1, i) for i in range(1, 25)})


@pytest.fixture
def rewards(engine, catalog, clock):
    return RewardsService(engine, catalog, clock)
