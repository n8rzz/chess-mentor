from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest

from worker.import_package.constants import PROVIDER
from worker.import_package.handler import run_import
from worker.import_package.lichess_client import LichessGame
from worker.import_package.repository import ImportContext, ImportRepository


def _sample_game() -> LichessGame:
    return LichessGame(
        raw={
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
    )


@pytest.fixture
def context() -> ImportContext:
    return ImportContext(
        import_batch_id="batch1",
        user_id="user1",
        provider_account_id="pa1",
        provider=PROVIDER["lichess"],
        provider_username="testuser",
        access_token="token",
        requested_since=datetime(2024, 1, 1, tzinfo=timezone.utc),
        requested_until=datetime(2024, 6, 1, tzinfo=timezone.utc),
        max_games=30,
        time_controls=["blitz"],
    )


def test_run_import_succeeds(context: ImportContext) -> None:
    conn = MagicMock()
    repo = MagicMock(spec=ImportRepository)
    repo.load_context.return_value = context
    repo.import_record_exists.return_value = False
    repo.game_exists.return_value = False

    with patch("worker.import_package.handler.ImportRepository", return_value=repo):
        with patch("worker.import_package.handler.LichessClient") as client_cls:
            client_cls.return_value.fetch_games.return_value = [_sample_game()]
            result = run_import(conn, "batch1")

    assert result["status"] == "succeeded"
    assert result["games_imported"] == 1
    repo.mark_batch_running.assert_called_once_with("batch1")
    repo.touch_last_imported_at.assert_called_once_with("pa1")


def test_run_import_fails_for_unsupported_provider(context: ImportContext) -> None:
    conn = MagicMock()
    repo = MagicMock(spec=ImportRepository)
    chess_context = ImportContext(
        import_batch_id=context.import_batch_id,
        user_id=context.user_id,
        provider_account_id=context.provider_account_id,
        provider=PROVIDER["chess_com"],
        provider_username=context.provider_username,
        access_token=context.access_token,
        requested_since=context.requested_since,
        requested_until=context.requested_until,
        max_games=context.max_games,
        time_controls=context.time_controls,
    )
    repo.load_context.return_value = chess_context

    with patch("worker.import_package.handler.ImportRepository", return_value=repo):
        with pytest.raises(ValueError, match="unsupported provider"):
            run_import(conn, "batch1")

    repo.mark_batch_finished.assert_called_once()
    assert repo.mark_batch_finished.call_args.kwargs["status"] == "failed"


def test_run_import_skips_duplicate_games(context: ImportContext) -> None:
    conn = MagicMock()
    repo = MagicMock(spec=ImportRepository)
    repo.load_context.return_value = context
    repo.import_record_exists.return_value = True

    with patch("worker.import_package.handler.ImportRepository", return_value=repo):
        with patch("worker.import_package.handler.LichessClient") as client_cls:
            client_cls.return_value.fetch_games.return_value = [_sample_game(), _sample_game()]
            result = run_import(conn, "batch1")

    assert result["games_found"] == 2
    assert result["games_skipped"] == 2
    assert result["games_imported"] == 0
    assert result["status"] == "succeeded"
    repo.insert_game.assert_not_called()


def test_run_import_partially_succeeded(context: ImportContext) -> None:
    conn = MagicMock()
    repo = MagicMock(spec=ImportRepository)
    repo.load_context.return_value = context
    repo.import_record_exists.return_value = False
    repo.game_exists.return_value = False

    bad_game = LichessGame(raw={"id": "bad-game"})

    with patch("worker.import_package.handler.ImportRepository", return_value=repo):
        with patch("worker.import_package.handler.LichessClient") as client_cls:
            client_cls.return_value.fetch_games.return_value = [_sample_game(), bad_game]
            result = run_import(conn, "batch1")

    assert result["games_imported"] == 1
    assert result["games_failed"] == 1
    assert result["status"] == "partially_succeeded"


def test_run_import_fails_without_access_token(context: ImportContext) -> None:
    conn = MagicMock()
    repo = MagicMock(spec=ImportRepository)
    no_token_context = ImportContext(
        import_batch_id=context.import_batch_id,
        user_id=context.user_id,
        provider_account_id=context.provider_account_id,
        provider=context.provider,
        provider_username=context.provider_username,
        access_token=None,
        requested_since=context.requested_since,
        requested_until=context.requested_until,
        max_games=context.max_games,
        time_controls=context.time_controls,
    )
    repo.load_context.return_value = no_token_context

    with patch("worker.import_package.handler.ImportRepository", return_value=repo):
        with pytest.raises(Exception, match="Missing Lichess access token"):
            run_import(conn, "batch1")

    assert repo.mark_batch_finished.call_args.kwargs["status"] == "failed"
