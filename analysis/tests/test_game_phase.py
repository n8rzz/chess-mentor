from worker.eval_package.game_phase import GAME_PHASE, classify_game_phases, classify_position_phase
from worker.eval_package.parser import ParsedMove
from worker.eval_package.positions import MovePosition


def _position(*, ply: int, move_number: int, fen_after: str) -> MovePosition:
    parsed = ParsedMove(
        ply=ply,
        move_number=move_number,
        color=0 if ply % 2 == 1 else 1,
        san="e4",
        uci="e2e4",
        played_by_user=True,
        clock_before=None,
        clock_after=None,
    )
    return MovePosition(
        parsed=parsed,
        fen_before="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        fen_after=fen_after,
    )


def test_opening_start_position_is_opening():
    fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    assert classify_position_phase(fen, 1) == GAME_PHASE["opening"]


def test_queenless_position_is_endgame():
    fen = "4k3/8/8/8/8/8/4P3/4K3 w - - 0 40"
    assert classify_position_phase(fen, 40) == GAME_PHASE["endgame"]


def test_low_piece_count_is_endgame_even_with_queens():
    # Two kings + two queens + a few pieces => still <= 10 pieces
    fen = "4k3/4q3/8/8/8/8/4Q3/4K3 w - - 0 50"
    assert classify_position_phase(fen, 50) == GAME_PHASE["endgame"]


def test_late_move_with_many_pieces_is_middlegame():
    fen = "r1bq1rk1/pppp1ppp/2n2n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 0 8"
    # move 20 with full-ish material -> middlegame
    assert classify_position_phase(fen, 20) == GAME_PHASE["middlegame"]


def test_early_reduced_material_is_middlegame_not_opening():
    # Within opening move limit, but piece count is in the middlegame band (queens still present).
    fen = "4k3/3qqppp/8/8/8/8/3QQPPP/4K3 w - - 0 8"
    assert classify_position_phase(fen, 8) == GAME_PHASE["middlegame"]


def test_monotonicity_never_returns_to_opening():
    opening_fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    middlegame_fen = "r1bq1rk1/pppp1ppp/2n2n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 0 8"
    # After middlegame, early move_number + high material still stays middlegame
    assert (
        classify_position_phase(opening_fen, 5, previous_phase=GAME_PHASE["middlegame"])
        == GAME_PHASE["middlegame"]
    )
    assert (
        classify_position_phase(middlegame_fen, 12, previous_phase=GAME_PHASE["endgame"])
        == GAME_PHASE["endgame"]
    )


def test_classify_game_phases_progresses_monotonically():
    positions = [
        _position(
            ply=1,
            move_number=1,
            fen_after="rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
        ),
        _position(
            ply=32,
            move_number=16,
            fen_after="r1bq1rk1/pppp1ppp/2n2n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 0 16",
        ),
        _position(
            ply=40,
            move_number=20,
            fen_after="4k3/8/8/8/8/8/4P3/4K3 w - - 0 20",
        ),
        _position(
            ply=41,
            move_number=21,
            # Would look like opening if classified alone, but must stay endgame
            fen_after="rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
        ),
    ]
    phases = classify_game_phases(positions)
    assert phases == [
        GAME_PHASE["opening"],
        GAME_PHASE["middlegame"],
        GAME_PHASE["endgame"],
        GAME_PHASE["endgame"],
    ]
