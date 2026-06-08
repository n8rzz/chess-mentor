import chess

from worker.eval_package.constants import USER_COLOR
from worker.eval_package.positions import generate_positions
from db_helpers import DEMO_BLITZ_PGN


def test_generate_positions_produces_fen_snapshots():
    positions = generate_positions(DEMO_BLITZ_PGN, user_color=USER_COLOR["white"])

    assert len(positions) == 17
    first = positions[0]
    assert first.parsed.san == "e4"
    assert first.fen_before == chess.STARTING_FEN
    board = chess.Board(first.fen_before)
    board.push_uci(first.parsed.uci)
    assert board.fen() == first.fen_after
