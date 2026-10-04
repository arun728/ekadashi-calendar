"""Durable ledger schema. Production requires PostgreSQL; SQLite is test-only."""

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    MetaData,
    String,
    Table,
    UniqueConstraint,
)

metadata = MetaData()
accounts = Table(
    "accounts",
    metadata,
    Column("id", String(64), primary_key=True),
    Column("balance", Integer, nullable=False, default=0),
    Column("deleted_at", DateTime(timezone=True)),
)
observances = Table(
    "observances",
    metadata,
    Column("account_id", String(64), ForeignKey("accounts.id"), primary_key=True),
    Column("uid", String(64), primary_key=True),
    Column("observed", Boolean, nullable=False),
    Column("version", Integer, nullable=False),
    Column("award", Integer, nullable=False),
)
mutations = Table(
    "mutations",
    metadata,
    Column("account_id", String(64), ForeignKey("accounts.id"), primary_key=True),
    Column("key", String(128), primary_key=True),
    Column("fingerprint", String(64), nullable=False),
)
bonuses = Table(
    "bonuses",
    metadata,
    Column("account_id", String(64), ForeignKey("accounts.id"), primary_key=True),
    Column("year", Integer, primary_key=True),
    Column("award", Integer, nullable=False),
)
ledger = Table(
    "ledger",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("account_id", String(64), ForeignKey("accounts.id"), nullable=False),
    Column("reference", String(200), nullable=False),
    Column("kind", String(30), nullable=False),
    Column("delta", Integer, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False),
    UniqueConstraint("account_id", "reference"),
)
receipts = Table(
    "receipts",
    metadata,
    Column("token_hash", String(64), primary_key=True),
    Column("encrypted_token", String, nullable=False),
    Column("account_id", String(64), ForeignKey("accounts.id"), nullable=False),
    Column("product_id", String(100), nullable=False),
    Column("base_plan", String(100)),
    Column("state", String(50), nullable=False),
    Column("expiry", DateTime(timezone=True)),
    Column("lifetime", Boolean, nullable=False, default=False),
    Column("auto_renew", Boolean, nullable=False, default=False),
    Column("acknowledged", Boolean, nullable=False, default=False),
    Column("etag", String),
    Column("updated_at", DateTime(timezone=True), nullable=False),
)
redemptions = Table(
    "redemptions",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("account_id", String(64), ForeignKey("accounts.id"), nullable=False),
    Column("key", String(128), nullable=False),
    Column("cost", Integer, nullable=False),
    Column("state", String(40), nullable=False),
    Column("token_hash", String(64), ForeignKey("receipts.token_hash")),
    Column("etag", String),
    Column("duration_seconds", Integer),
    Column("original_expiry", DateTime(timezone=True)),
    Column("expected_expiry", DateTime(timezone=True)),
    Column("created_at", DateTime(timezone=True), nullable=False),
    UniqueConstraint("account_id", "key"),
)
promotions = Table(
    "promotions",
    metadata,
    Column("redemption_id", String(36), ForeignKey("redemptions.id"), primary_key=True),
    Column("account_id", String(64), ForeignKey("accounts.id"), nullable=False),
    Column("starts_at", DateTime(timezone=True), nullable=False),
    Column("expires_at", DateTime(timezone=True), nullable=False),
)
Index("ledger_account", ledger.c.account_id)
