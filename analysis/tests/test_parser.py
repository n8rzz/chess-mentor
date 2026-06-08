import pytest

from worker.eval_package.constants import USER_COLOR
from worker.eval_package.errors import InvalidPgnError
from worker.eval_package.parser import parse_pgn


def test_parse_pgn_extracts_moves_for_white_user():
    pgn = '[Event "Test"]\n1. e4 e5 2. Nf3 *'
    moves = parse_pgn(pgn, user_color=USER_COLOR["white"])

    assert len(moves) == 3
    assert moves[0].san == "e4"
    assert moves[0].played_by_user is True
    assert moves[1].played_by_user is False
    assert moves[2].played_by_user is True


def test_parse_pgn_marks_black_user_moves():
    pgn = '[Event "Test"]\n1. e4 e5 2. Nf3 *'
    moves = parse_pgn(pgn, user_color=USER_COLOR["black"])

    assert moves[0].played_by_user is False
    assert moves[1].played_by_user is True


def test_parse_pgn_rejects_empty_game():
    with pytest.raises(InvalidPgnError):
        parse_pgn("", user_color=USER_COLOR["white"])


def test_parse_pgn_parses_clock_annotation():
    pgn = '[Event "Test"]\n1. e4 { [%clk 0:02:30] } e5 { [%clk 0:02:28] } *'
    moves = parse_pgn(pgn, user_color=USER_COLOR["white"])

    assert moves[0].clock_after == 150
    assert moves[1].clock_after == 148
