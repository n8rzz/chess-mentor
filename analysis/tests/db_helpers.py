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


DEMO_BLITZ_PGN = """[Event "Demo Blitz"]
[Site "lichess.org"]
[Date "2026.06.01"]
[White "starship_lichess"]
[Black "opponent_blitz"]
[Result "1-0"]
[TimeControl "180+0"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. d3 Be7 5. O-O O-O 6. Nc3 d6 7. Bg5 h6 8. Bxf6 Bxf6 9. Nd5 1-0"""


def seed_game_with_analysis_run(
    conn: psycopg.Connection,
    *,
    pgn: str = DEMO_BLITZ_PGN,
    user_color: int = 0,
    time_class: int = 1,
) -> dict[str, str]:
    seed = seed_import_batch(conn, batch_status=2)
    now = datetime.now(timezone.utc)
    game_id = new_id()
    analysis_run_id = new_id()

    conn.execute(
        """
        INSERT INTO games (
          id, user_id, provider_account_id, import_batch_id, provider,
          provider_game_id, pgn, played_at, user_color, result, time_control,
          time_class, metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            game_id,
            seed["user_id"],
            seed["provider_account_id"],
            seed["import_batch_id"],
            0,
            f"game-{game_id[-8:]}",
            pgn,
            now,
            user_color,
            0,
            "180+0",
            time_class,
            json.dumps({}),
            now,
            now,
        ),
    )
    conn.execute(
        """
        INSERT INTO analysis_runs (
          id, game_id, user_id, status, engine_name, engine_version,
          analysis_version, depth, metadata, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s)
        """,
        (
            analysis_run_id,
            game_id,
            seed["user_id"],
            0,
            "Stockfish",
            "16.1",
            "1.0.0",
            15,
            json.dumps({}),
            now,
            now,
        ),
    )

    return {
        **seed,
        "game_id": game_id,
        "analysis_run_id": analysis_run_id,
    }
