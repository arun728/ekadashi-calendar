"""Explicit initial schema creation; never run migrations implicitly on requests."""

import os

from sqlalchemy import create_engine

from .database import metadata

if __name__ == "__main__":
    url = os.environ["DATABASE_URL"]
    if not url.startswith("postgresql"):
        raise RuntimeError("PostgreSQL required")
    metadata.create_all(create_engine(url))
