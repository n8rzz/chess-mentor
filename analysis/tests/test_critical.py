from worker.eval_package.critical import assess_criticality, candidate_gap_cp
from worker.eval_package.constants import TIME_CLASS, USER_COLOR
from worker.eval_package.engine import CandidateLine, EngineEvaluation
from worker.eval_package.parser import ParsedMove
from worker.eval_package.positions import MovePosition
from worker.eval_package.repository import AnalysisContext, StoredMove


def _context(**overrides):
    base = dict(
        analysis_run_id="run",
        game_id="game",
        user_id="user",
        pgn="",
        user_color=USER_COLOR["white"],
        time_class=TIME_CLASS["blitz"],
        depth=14,
        depth_critical=20,
        multipv=3,
        engine_name="Stockfish",
        engine_version="16.1",
        analysis_version="1.1.0",
        metadata={},
    )
    base.update(overrides)
    return AnalysisContext(**base)


def _move(**overrides):
    base = dict(
        id="move1",
        game_id="game",
        ply=10,
        move_number=5,
        color=0,
        san="e4",
        uci="e2e4",
        fen_before="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        fen_after="rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
        played_by_user=True,
        clock_before=120,
        clock_after=115,
    )
    base.update(overrides)
    return StoredMove(**base)


def _position():
    parsed = ParsedMove(
        ply=10,
        move_number=5,
        color=0,
        san="e4",
        uci="e2e4",
        played_by_user=True,
        clock_before=120,
        clock_after=115,
    )
    return MovePosition(
        parsed=parsed,
        fen_before="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        fen_after="rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
    )


def test_candidate_gap_cp():
    candidates = (
        CandidateLine(1, "e2e4", "e4", 40, None, "e4 e5"),
        CandidateLine(2, "d2d4", "d4", -120, None, "d4 d5"),
    )
    assert candidate_gap_cp(candidates) == 160


def test_assess_criticality_flags_candidate_dispersion():
    evaluation = EngineEvaluation(
        eval_before_cp=40,
        eval_after_cp=30,
        mate_before=None,
        mate_after=None,
        best_move_uci="e2e4",
        best_move_san="e4",
        principal_variation="e4 e5",
        candidates=(
            CandidateLine(1, "e2e4", "e4", 40, None, "e4 e5"),
            CandidateLine(2, "d2d4", "d4", -130, None, "d4 d5"),
            CandidateLine(3, "c2c4", "c4", -150, None, "c4 e5"),
        ),
        played_is_best=True,
    )
    assessment = assess_criticality(
        context=_context(),
        move=_move(),
        position=_position(),
        evaluation=evaluation,
        cpl=10,
    )
    assert assessment.critical_position is True
    assert "candidate_dispersion" in assessment.reasons
    assert assessment.candidate_gap_cp == 170


def test_assess_criticality_flags_blunder_and_lost_winning():
    evaluation = EngineEvaluation(
        eval_before_cp=250,
        eval_after_cp=-50,
        mate_before=None,
        mate_after=None,
        best_move_uci="e2e4",
        best_move_san="e4",
        principal_variation="e4",
        candidates=(CandidateLine(1, "e2e4", "e4", 250, None, "e4"),),
        played_is_best=False,
    )
    assessment = assess_criticality(
        context=_context(),
        move=_move(),
        position=_position(),
        evaluation=evaluation,
        cpl=300,
    )
    assert assessment.critical_position is True
    assert "blunder_cpl" in assessment.reasons
    assert "lost_winning_advantage" in assessment.reasons


def test_assess_criticality_time_pressure_boost():
    evaluation = EngineEvaluation(
        eval_before_cp=20,
        eval_after_cp=-90,
        mate_before=None,
        mate_after=None,
        best_move_uci="e2e4",
        best_move_san="e4",
        principal_variation="e4",
        candidates=(
            CandidateLine(1, "e2e4", "e4", 20, None, "e4"),
            CandidateLine(2, "d2d4", "d4", 10, None, "d4"),
        ),
        played_is_best=False,
    )
    assessment = assess_criticality(
        context=_context(),
        move=_move(clock_before=8),
        position=_position(),
        evaluation=evaluation,
        cpl=110,
    )
    assert assessment.critical_position is True
    assert "time_pressure" in assessment.reasons
    assert "mistake_cpl" in assessment.reasons


def test_assess_criticality_flags_forced_mate_missed():
    evaluation = EngineEvaluation(
        eval_before_cp=9900,
        eval_after_cp=50,
        mate_before=2,
        mate_after=None,
        best_move_uci="e2e4",
        best_move_san="e4",
        principal_variation="e4 e5",
        candidates=(CandidateLine(1, "e2e4", "e4", 9900, 2, "e4"),),
        played_is_best=False,
    )
    assessment = assess_criticality(
        context=_context(),
        move=_move(),
        position=_position(),
        evaluation=evaluation,
        cpl=50,
    )
    assert assessment.critical_position is True
    assert "forced_mate_missed" in assessment.reasons


def test_assess_criticality_flags_only_move():
    evaluation = EngineEvaluation(
        eval_before_cp=40,
        eval_after_cp=35,
        mate_before=None,
        mate_after=None,
        best_move_uci="e2e4",
        best_move_san="e4",
        principal_variation="e4",
        candidates=(
            CandidateLine(1, "e2e4", "e4", 40, None, "e4"),
            CandidateLine(2, "d2d4", "d4", -280, None, "d4"),
        ),
        played_is_best=True,
    )
    assessment = assess_criticality(
        context=_context(),
        move=_move(),
        position=_position(),
        evaluation=evaluation,
        cpl=5,
    )
    assert assessment.critical_position is True
    assert "only_move" in assessment.reasons
    assert "candidate_dispersion" in assessment.reasons
    assert assessment.candidate_gap_cp == 320
