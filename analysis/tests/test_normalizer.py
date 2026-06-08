import json
from pathlib import Path

import pytest

from worker.import_package.lichess_client import LichessGame, normalize_lichess_game


FIXTURES = Path(__file__).resolve().parent / "fixtures" / "lichess"


@pytest.fixture
def sample_game() -> LichessGame:
    raw = json.loads((FIXTURES / "game.json").read_text())
    return LichessGame(raw=raw)


def test_normalize_lichess_game_maps_fields(sample_game: LichessGame) -> None:
    attrs = normalize_lichess_game(sample_game, account_username="testuser")

    assert attrs["provider_game_id"] == "abc123game"
    assert attrs["user_color"] == 0
    assert attrs["result"] == 0
    assert attrs["time_class"] == 1
    assert attrs["user_rating"] == 1520
    assert attrs["opponent_rating"] == 1480
    assert attrs["opening_name"] == "King's Pawn Game"
    assert attrs["opening_eco"] == "C20"
    assert "pgn" in attrs


def test_normalize_lichess_game_black_win() -> None:
    raw = json.loads((FIXTURES / "game.json").read_text())
    raw["winner"] = "black"
    game = LichessGame(raw=raw)

    attrs = normalize_lichess_game(game, account_username="testuser")

    assert attrs["result"] == 1


def test_normalize_lichess_game_draw() -> None:
    raw = json.loads((FIXTURES / "game.json").read_text())
    raw["winner"] = None
    game = LichessGame(raw=raw)

    attrs = normalize_lichess_game(game, account_username="testuser")

    assert attrs["result"] == 2


def test_normalize_lichess_game_black_color() -> None:
    raw = json.loads((FIXTURES / "game.json").read_text())
    raw["players"]["white"]["user"]["name"] = "opponent"
    raw["players"]["black"]["user"]["name"] = "testuser"
    game = LichessGame(raw=raw)

    attrs = normalize_lichess_game(game, account_username="testuser")

    assert attrs["user_color"] == 1


def test_normalize_lichess_game_unknown_perf() -> None:
    raw = json.loads((FIXTURES / "game.json").read_text())
    raw["perf"] = "correspondence"
    game = LichessGame(raw=raw)

    attrs = normalize_lichess_game(game, account_username="testuser")

    assert attrs["time_class"] == 4


def test_normalize_lichess_game_missing_pgn_raises(sample_game: LichessGame) -> None:
    sample_game.raw.pop("pgn")

    with pytest.raises(ValueError, match="missing pgn"):
        normalize_lichess_game(sample_game, account_username="testuser")
