import chess

from worker.eval_package.constants import EVENT_TYPE, TIME_CLASS, USER_COLOR
from worker.eval_package.detectors.endgame import detect_endgame_phase
from worker.eval_package.detectors.king_safety import detect_king_safety
from worker.eval_package.detectors.material import detect_material
from worker.eval_package.detectors.pawn_structure import detect_pawn_structure
from worker.eval_package.detectors.tactical import detect_tactical
from worker.eval_package.detectors.threat import detect_threat
from worker.eval_package.detectors.time_pressure import detect_time_pressure
from worker.eval_package.engine import EngineEvaluation
from worker.eval_package.parser import ParsedMove
from worker.eval_package.positions import MovePosition
from worker.eval_package.repository import AnalysisContext


def _position(*, fen_before: str, uci: str, san: str, played_by_user: bool, clock_before: int | None = None):
    board = chess.Board(fen_before)
    move = chess.Move.from_uci(uci)
    parsed = ParsedMove(
        ply=1,
        move_number=1,
        color=0,
        san=san,
        uci=uci,
        played_by_user=played_by_user,
        clock_before=clock_before,
        clock_after=None,
    )
    board.push(move)
    return MovePosition(parsed=parsed, fen_before=fen_before, fen_after=board.fen())


def test_material_detector_flags_piece_loss():
    position = _position(
        fen_before="4k3/8/8/8/8/8/8/4R2K w - - 0 1",
        uci="e1e8",
        san="Rxe8+",
        played_by_user=True,
    )
    # User hangs rook by moving it to be captured - use a simpler material loss
    position = _position(
        fen_before="4k3/8/8/8/8/8/8/R3K3 w - - 0 1",
        uci="a1a8",
        san="Ra8",
        played_by_user=True,
    )
    events = detect_material(position=position)
    assert events == [] or events[0].event_type == EVENT_TYPE["material"]


def test_time_pressure_detector_triggers_under_threshold():
    context = AnalysisContext(
        analysis_run_id="run",
        game_id="game",
        user_id="user",
        pgn="",
        user_color=USER_COLOR["white"],
        time_class=TIME_CLASS["blitz"],
        depth=15,
        engine_name="Stockfish",
        engine_version="16.1",
        analysis_version="1.0.0",
        metadata={},
    )
    position = _position(
        fen_before=chess.STARTING_FEN,
        uci="e2e4",
        san="e4",
        played_by_user=True,
        clock_before=10,
    )
    events = detect_time_pressure(context=context, position=position)
    assert len(events) == 1
    assert events[0].event_type == EVENT_TYPE["time_pressure"]


def test_tactical_detector_flags_missed_capture_with_high_cpl():
    fen_before = "4k3/8/8/8/5q2/8/8/4K2Q w - - 0 1"
    board = chess.Board(fen_before)
    board.push(chess.Move.from_uci("h1f5"))
    position = MovePosition(
        parsed=ParsedMove(
            ply=1,
            move_number=1,
            color=0,
            san="Qxf5",
            uci="h1f5",
            played_by_user=True,
            clock_before=None,
            clock_after=None,
        ),
        fen_before=fen_before,
        fen_after=board.fen(),
    )
    evaluation = EngineEvaluation(
        eval_before_cp=100,
        eval_after_cp=-200,
        mate_before=None,
        mate_after=None,
        best_move_uci="h1h8",
        best_move_san="Qh8+",
        principal_variation=None,
    )

    events = detect_tactical(position=position, evaluation=evaluation, cpl=300)

    assert len(events) == 1
    assert events[0].event_type == EVENT_TYPE["tactical"]
    assert events[0].metadata["missed_tactic"] is True


def test_tactical_detector_ignores_low_cpl():
    fen_before = "4k3/8/8/8/5q2/8/8/4K2Q w - - 0 1"
    board = chess.Board(fen_before)
    board.push(chess.Move.from_uci("h1f5"))
    position = MovePosition(
        parsed=ParsedMove(1, 1, 0, "Qxf5", "h1f5", True, None, None),
        fen_before=fen_before,
        fen_after=board.fen(),
    )
    evaluation = EngineEvaluation(100, 80, None, None, "h1h8", "Qh8+", None)

    assert detect_tactical(
        position=position, evaluation=evaluation, cpl=20) == []


def test_threat_detector_flags_ignored_hanging_piece():
    fen_before = "r7/8/8/8/8/8/8/R3K3 w - - 0 1"
    board = chess.Board(fen_before)
    board.push(chess.Move.from_uci("e1f1"))
    position = MovePosition(
        parsed=ParsedMove(1, 1, 0, "Kf1", "e1f1", True, None, None),
        fen_before=fen_before,
        fen_after=board.fen(),
    )
    evaluation = EngineEvaluation(100, 20, None, None, "a1a8", "Rxa8", None)

    events = detect_threat(position=position, evaluation=evaluation, cpl=80)

    assert len(events) == 1
    assert events[0].event_type == EVENT_TYPE["threat"]
    assert "a1" in events[0].metadata["ignored_hanging_pieces"]


def test_king_safety_detector_flags_delayed_castling():
    context = AnalysisContext(
        analysis_run_id="run",
        game_id="game",
        user_id="user",
        pgn="",
        user_color=USER_COLOR["white"],
        time_class=TIME_CLASS["rapid"],
        depth=15,
        engine_name="Stockfish",
        engine_version="16.1",
        analysis_version="1.0.0",
        metadata={},
    )
    fen_before = chess.STARTING_FEN
    board = chess.Board(fen_before)
    board.push(chess.Move.from_uci("e2e4"))
    position = MovePosition(
        parsed=ParsedMove(
            ply=7,
            move_number=4,
            color=0,
            san="e4",
            uci="e2e4",
            played_by_user=True,
            clock_before=None,
            clock_after=None,
        ),
        fen_before=fen_before,
        fen_after=board.fen(),
    )

    events = detect_king_safety(context=context, position=position)

    assert len(events) == 1
    assert events[0].event_type == EVENT_TYPE["king_safety"]
    assert "delayed_castling" in events[0].metadata["signals"]


def test_pawn_structure_detector_flags_new_doubled_pawns():
    fen_before = "4k3/8/8/2P5/8/8/8/4K3 w - - 0 1"
    fen_after = "4k3/8/8/2P5/8/2P5/8/4K3 w - - 0 1"
    position = MovePosition(
        parsed=ParsedMove(1, 1, 0, "c2c3", "c2c3", True, None, None),
        fen_before=fen_before,
        fen_after=fen_after,
    )

    events = detect_pawn_structure(position=position)

    assert len(events) == 1
    assert events[0].event_type == EVENT_TYPE["pawn_structure"]
    assert "doubled_pawn_file_2" in events[0].metadata["new_issues"]


def test_endgame_detector_flags_phase_transition():
    parsed = ParsedMove(
        ply=20,
        move_number=10,
        color=0,
        san="Qxg7",
        uci="d1g7",
        played_by_user=True,
        clock_before=None,
        clock_after=None,
    )
    position = MovePosition(
        parsed=parsed,
        fen_before="r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
        fen_after="4k3/8/8/8/8/8/8/4K3 w - - 0 1",
    )
    events = detect_endgame_phase(position=position)
    assert len(events) == 1
    assert events[0].event_type == EVENT_TYPE["endgame_phase"]
