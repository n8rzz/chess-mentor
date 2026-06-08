import os
import sys
from pathlib import Path

import psycopg
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "worker"))

# Dedicated Postgres database for Python tests (separate from chess_mentor_test).
os.environ.setdefault("DATABASE_HOST", "localhost")
os.environ.setdefault("DATABASE_PORT", "5432")
os.environ.setdefault("DATABASE_USERNAME", "chess_mentor")
os.environ.setdefault("DATABASE_PASSWORD", "chess_mentor")
os.environ.setdefault("DATABASE_NAME", "chess_mentor_python_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish")


def _database_url() -> str:
    return (
        f"postgresql://{os.environ['DATABASE_USERNAME']}:{os.environ['DATABASE_PASSWORD']}"
        f"@{os.environ['DATABASE_HOST']}:{os.environ['DATABASE_PORT']}/{os.environ['DATABASE_NAME']}"
    )


@pytest.fixture
def db_conn():
    """Yield a connection to the Python test database with import tables truncated."""
    try:
        conn = psycopg.connect(_database_url())
    except psycopg.OperationalError as exc:
        pytest.skip(f"Python test database unavailable: {exc}")

    with conn:
        with conn.transaction():
            conn.execute(
                """
                TRUNCATE TABLE
                  import_records,
                  games,
                  analysis_runs,
                  system_jobs,
                  import_batches,
                  provider_accounts,
                  users
                RESTART IDENTITY CASCADE
                """
            )
        try:
            yield conn
        finally:
            with conn.transaction():
                conn.execute(
                    """
                    TRUNCATE TABLE
                      import_records,
                      games,
                      analysis_runs,
                      system_jobs,
                      import_batches,
                      provider_accounts,
                      users
                    RESTART IDENTITY CASCADE
                    """
                )
