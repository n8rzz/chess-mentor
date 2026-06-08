from __future__ import annotations

import json
from datetime import datetime, timezone

import psycopg
from ulid import ULID


def new_id() -> str:
    return str(ULID())


def sample_lichess_game_raw() -> dict:
    return {
        "id": "game123",
        "createdAt": 1717200000000,
        "perf": "blitz",
        "winner": "white",
        "pgn": '[Event "Test"]\n1. e4 e5 1-0',
        "clock": {"initial": 180, "increment": 0},
        "opening": {"name": "King's Pawn Game", "eco": "C20"},
        "players": {
            "white": {"user": {"name": "testuser"}, "rating": 1500},
            "black": {"user": {"name": "opponent"}, "rating": 1400},
        },
    }


def seed_import_batch(
    conn: psycopg.Connection,
    *,
    access_token: str | None = "test-token",
    batch_status: int = 0,
) -> dict[str, str]:
    now = datetime.now(timezone.utc)
    user_id = new_id()
    provider_account_id = new_id()
    import_batch_id = new_id()

    conn.execute(
        """
        INSERT INTO users (
          id, email, username, encrypted_password, role, created_at, updated_at, confirmed_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            user_id,
            f"{user_id}@python-test.local",
            f"user_{user_id[-8:].lower()}",
            "",
            0,
            now,
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO provider_accounts (
          id, user_id, provider, provider_username, provider_user_id,
          access_token, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            provider_account_id,
            user_id,
            0,
            "testuser",
            f"lichess-{provider_account_id}",
            access_token,
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO import_batches (
          id, user_id, provider_account_id, provider, status,
          requested_since, requested_until, max_games, time_controls,
          metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s::jsonb, %s, %s)
        """,
        (
            import_batch_id,
            user_id,
            provider_account_id,
            0,
            batch_status,
            now,
            now,
            30,
            json.dumps(["blitz", "rapid"]),
            json.dumps({}),
            now,
            now,
        ),
    )

    return {
        "user_id": user_id,
        "provider_account_id": provider_account_id,
        "import_batch_id": import_batch_id,
    }
