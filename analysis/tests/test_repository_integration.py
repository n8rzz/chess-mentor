import json

from worker.import_package.constants import IMPORT_BATCH_STATUS, IMPORT_RECORD_STATUS
from worker.import_package.repository import ImportRepository

from db_helpers import seed_import_batch


def test_load_context_reads_batch_and_account(db_conn) -> None:
    ids = seed_import_batch(db_conn, access_token="integration-token")
    repo = ImportRepository(db_conn)

    context = repo.load_context(ids["import_batch_id"])

    assert context.import_batch_id == ids["import_batch_id"]
    assert context.user_id == ids["user_id"]
    assert context.provider_username == "testuser"
    assert context.access_token == "integration-token"
    assert context.time_controls == ["blitz", "rapid"]


def test_mark_batch_running_updates_status(db_conn) -> None:
    ids = seed_import_batch(db_conn)
    repo = ImportRepository(db_conn)

    repo.mark_batch_running(ids["import_batch_id"])

    row = db_conn.execute(
        "SELECT status, started_at FROM import_batches WHERE id = %s",
        (ids["import_batch_id"],),
    ).fetchone()
    assert row[0] == IMPORT_BATCH_STATUS["running"]
    assert row[1] is not None


def test_insert_game_and_import_record(db_conn) -> None:
    ids = seed_import_batch(db_conn)
    repo = ImportRepository(db_conn)
    context = repo.load_context(ids["import_batch_id"])

    from datetime import datetime, timezone

    attrs = {
        "provider": 0,
        "provider_game_id": "integration-game-1",
        "pgn": "[Event \"Test\"]\n1. e4 e5 1-0",
        "played_at": datetime.now(timezone.utc),
        "user_color": 0,
        "result": 0,
        "time_class": 1,
        "time_control": "180+0",
        "opening_name": "Test Opening",
        "opening_eco": "A00",
        "user_rating": 1500,
        "opponent_rating": 1400,
        "opponent_username": "opponent",
        "metadata": {},
    }

    game_id = repo.insert_game(context=context, attrs=attrs)
    repo.insert_import_record(
        import_batch_id=ids["import_batch_id"],
        provider=0,
        provider_game_id="integration-game-1",
        status="imported",
        game_id=game_id,
    )

    game_row = db_conn.execute("SELECT pgn FROM games WHERE id = %s", (game_id,)).fetchone()
    record_row = db_conn.execute(
        "SELECT status, game_id FROM import_records WHERE provider_game_id = %s",
        ("integration-game-1",),
    ).fetchone()

    assert game_row[0].startswith("[Event")
    assert record_row[0] == IMPORT_RECORD_STATUS["imported"]
    assert record_row[1] == game_id
