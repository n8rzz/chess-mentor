from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from worker.import_package.constants import IMPORT_BATCH_STATUS
from worker.import_package.handler import run_import
from worker.import_package.lichess_client import LichessGame

from db_helpers import sample_lichess_game_raw, seed_import_batch


def test_run_import_persists_game_against_python_test_db(db_conn) -> None:
    ids = seed_import_batch(db_conn, access_token="live-token")

    with patch("worker.import_package.handler.LichessClient") as client_cls:
        client_cls.return_value.fetch_games.return_value = [LichessGame(raw=sample_lichess_game_raw())]
        result = run_import(db_conn, ids["import_batch_id"])

    assert result["status"] == "succeeded"
    assert result["games_imported"] == 1

    batch_row = db_conn.execute(
        "SELECT status, games_imported_count FROM import_batches WHERE id = %s",
        (ids["import_batch_id"],),
    ).fetchone()
    game_count = db_conn.execute(
        "SELECT count(*) FROM games WHERE user_id = %s",
        (ids["user_id"],),
    ).fetchone()[0]

    assert batch_row[1] == 1
    assert game_count == 1


def test_run_import_is_idempotent_for_terminal_batch(db_conn) -> None:
    ids = seed_import_batch(db_conn, access_token="live-token", batch_status=2)

    with patch("worker.import_package.handler.LichessClient") as client_cls:
        client_cls.return_value.fetch_games.return_value = [LichessGame(raw=sample_lichess_game_raw())]
        result = run_import(db_conn, ids["import_batch_id"])

    assert result["status"] == "succeeded"

    game_count = db_conn.execute(
        "SELECT count(*) FROM games WHERE user_id = %s",
        (ids["user_id"],),
    ).fetchone()[0]
    assert game_count == 0


def test_run_import_marks_batch_failed_without_access_token(db_conn) -> None:
    ids = seed_import_batch(db_conn, access_token=None)

    result = run_import(db_conn, ids["import_batch_id"])
    db_conn.commit()

    assert result["status"] == "failed"

    batch_row = db_conn.execute(
        "SELECT status, error_message FROM import_batches WHERE id = %s",
        (ids["import_batch_id"],),
    ).fetchone()

    assert batch_row[0] == 4  # failed
    assert "Missing Lichess access token" in batch_row[1]


def test_run_import_resumes_stuck_running_batch(db_conn) -> None:
    stale_started_at = datetime.now(timezone.utc) - timedelta(minutes=45)
    ids = seed_import_batch(
        db_conn,
        access_token="live-token",
        batch_status=IMPORT_BATCH_STATUS["running"],
        started_at=stale_started_at,
    )

    with patch("worker.import_package.handler.LichessClient") as client_cls:
        client_cls.return_value.fetch_games.return_value = [LichessGame(raw=sample_lichess_game_raw())]
        result = run_import(db_conn, ids["import_batch_id"])

    assert result["status"] == "succeeded"
    assert result["games_imported"] == 1

    batch_row = db_conn.execute(
        "SELECT status, games_imported_count FROM import_batches WHERE id = %s",
        (ids["import_batch_id"],),
    ).fetchone()
    game_count = db_conn.execute(
        "SELECT count(*) FROM games WHERE user_id = %s",
        (ids["user_id"],),
    ).fetchone()[0]

    assert batch_row[0] == IMPORT_BATCH_STATUS["succeeded"]
    assert batch_row[1] == 1
    assert game_count == 1
