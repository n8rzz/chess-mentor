from decimal import Decimal

from worker.eval_package.constants import CLASSIFICATION, TIME_CLASS
from worker.eval_package.game_phase import GAME_PHASE
from worker.metrics_package.calculators import (
    MoveMetricInput,
    aggregate_period_metrics,
    compute_conversion,
    compute_game_metrics,
    parse_increment_seconds,
    think_time_seconds,
)
from worker.metrics_package.constants import GAME_RESULT


def _move(**overrides) -> MoveMetricInput:
    base = dict(
        move_id="m1",
        ply=1,
        phase=GAME_PHASE["middlegame"],
        clock_before=60,
        clock_after=55,
        centipawn_loss=20,
        classification=CLASSIFICATION["good"],
        critical_position=False,
        eval_before_cp=50,
        eval_after_cp=40,
        has_time_pressure_event=False,
    )
    base.update(overrides)
    return MoveMetricInput(**base)


def test_parse_increment_seconds():
    assert parse_increment_seconds("180+2") == 2
    assert parse_increment_seconds("600") == 0
    assert parse_increment_seconds(None) == 0


def test_think_time_seconds_includes_increment():
    assert think_time_seconds(clock_before=60, clock_after=58, increment=2) == 4
    assert think_time_seconds(clock_before=None, clock_after=58, increment=2) is None


def test_compute_game_metrics_acpl_and_classifications():
    moves = [
        _move(move_id="a", ply=1, centipawn_loss=50, classification=CLASSIFICATION["inaccuracy"]),
        _move(move_id="b", ply=3, centipawn_loss=150, classification=CLASSIFICATION["mistake"]),
        _move(move_id="c", ply=5, centipawn_loss=300, classification=CLASSIFICATION["blunder"]),
    ]
    metrics = compute_game_metrics(
        moves=moves,
        game_result=GAME_RESULT["win"],
        time_class=TIME_CLASS["blitz"],
        time_control="180+0",
    )
    assert metrics["user_move_count"] == 3
    assert metrics["average_centipawn_loss"] == Decimal("166.67")
    assert metrics["inaccuracies_count"] == 1
    assert metrics["mistakes_count"] == 2
    assert metrics["blunders_count"] == 1


def test_phase_buckets():
    moves = [
        _move(move_id="o", ply=1, phase=GAME_PHASE["opening"], centipawn_loss=10),
        _move(move_id="m", ply=3, phase=GAME_PHASE["middlegame"], centipawn_loss=40),
        _move(
            move_id="e",
            ply=5,
            phase=GAME_PHASE["endgame"],
            centipawn_loss=100,
            classification=CLASSIFICATION["mistake"],
        ),
    ]
    metrics = compute_game_metrics(
        moves=moves,
        game_result=GAME_RESULT["draw"],
        time_class=TIME_CLASS["rapid"],
        time_control="600+0",
    )
    assert metrics["phase_metrics"]["opening"]["moves"] == 1
    assert metrics["phase_metrics"]["opening"]["acpl"] == 10.0
    assert metrics["phase_metrics"]["endgame"]["mistakes"] == 1


def test_conversion_converted_win():
    moves = [
        _move(move_id="a", ply=1, eval_before_cp=220, eval_after_cp=210),
        _move(move_id="b", ply=3, eval_before_cp=230, eval_after_cp=200),
        _move(move_id="c", ply=5, eval_before_cp=180, eval_after_cp=160),
    ]
    reached, converted = compute_conversion(moves=moves, game_result=GAME_RESULT["win"])
    assert reached == 1
    assert converted == 1


def test_conversion_lost_advantage():
    moves = [
        _move(move_id="a", ply=1, eval_before_cp=220, eval_after_cp=210),
        _move(move_id="b", ply=3, eval_before_cp=230, eval_after_cp=50),
        _move(move_id="c", ply=5, eval_before_cp=40, eval_after_cp=30),
    ]
    reached, converted = compute_conversion(moves=moves, game_result=GAME_RESULT["win"])
    assert reached == 1
    assert converted == 0


def test_fast_move_and_time_pressure_rates():
    moves = [
        _move(
            move_id="fast_err",
            ply=3,
            phase=GAME_PHASE["middlegame"],
            clock_before=90,
            clock_after=89,
            centipawn_loss=150,
            classification=CLASSIFICATION["mistake"],
        ),
        _move(
            move_id="pressure",
            ply=5,
            clock_before=10,
            clock_after=8,
            centipawn_loss=200,
            classification=CLASSIFICATION["mistake"],
            has_time_pressure_event=True,
        ),
        _move(
            move_id="opening_fast",
            ply=1,
            phase=GAME_PHASE["opening"],
            clock_before=90,
            clock_after=89,
            centipawn_loss=0,
        ),
    ]
    metrics = compute_game_metrics(
        moves=moves,
        game_result=GAME_RESULT["loss"],
        time_class=TIME_CLASS["blitz"],
        time_control="180+0",
    )
    assert metrics["fast_moves_count"] == 1
    assert metrics["fast_move_mistakes_count"] == 1
    assert metrics["fast_move_error_rate"] == Decimal("1.0000")
    assert metrics["time_pressure_moves_count"] == 1
    assert metrics["time_pressure_mistakes_count"] == 1


def test_missing_clocks_null_rates():
    moves = [
        _move(
            move_id="a",
            clock_before=None,
            clock_after=None,
            has_time_pressure_event=False,
        )
    ]
    metrics = compute_game_metrics(
        moves=moves,
        game_result=GAME_RESULT["draw"],
        time_class=TIME_CLASS["blitz"],
        time_control="180+0",
    )
    assert metrics["fast_move_error_rate"] is None
    assert metrics["time_pressure_error_rate"] is None
    assert metrics["metadata"]["clock_coverage"] is False


def test_critical_accuracy():
    moves = [
        _move(move_id="a", critical_position=True, classification=CLASSIFICATION["good"]),
        _move(
            move_id="b",
            ply=3,
            critical_position=True,
            classification=CLASSIFICATION["mistake"],
            centipawn_loss=120,
        ),
    ]
    metrics = compute_game_metrics(
        moves=moves,
        game_result=GAME_RESULT["win"],
        time_class=TIME_CLASS["classical"],
        time_control="1800+0",
    )
    assert metrics["critical_moves_count"] == 2
    assert metrics["critical_accurate_count"] == 1
    assert metrics["critical_position_accuracy"] == Decimal("0.5000")


def test_conversion_multiple_episodes():
    moves = [
        _move(move_id="a", ply=1, eval_before_cp=220, eval_after_cp=210),
        _move(move_id="b", ply=3, eval_before_cp=230, eval_after_cp=40),
        _move(move_id="c", ply=5, eval_before_cp=30, eval_after_cp=20),
        _move(move_id="d", ply=7, eval_before_cp=210, eval_after_cp=205),
        _move(move_id="e", ply=9, eval_before_cp=220, eval_after_cp=200),
    ]
    reached, converted = compute_conversion(moves=moves, game_result=GAME_RESULT["win"])
    assert reached == 2
    assert converted == 1


def test_aggregate_period_unknown_only_results_null_rates():
    metrics = aggregate_period_metrics(
        game_rows=[],
        member_results=[GAME_RESULT["unknown"], GAME_RESULT["unknown"]],
    )
    assert metrics["games_count"] == 2
    assert metrics["analyzed_games_count"] == 0
    assert metrics["win_rate"] is None
    assert metrics["draw_rate"] is None
    assert metrics["loss_rate"] is None
    assert metrics["average_centipawn_loss"] is None


def test_aggregate_period_metrics():
    game_rows = [
        {
            "average_centipawn_loss": Decimal("20.00"),
            "user_move_count": 10,
            "mistakes_count": 1,
            "blunders_count": 0,
            "phase_metrics": {
                "opening": {"moves": 4, "acpl": 10.0, "mistakes": 0, "blunders": 0},
                "middlegame": {"moves": 6, "acpl": 26.67, "mistakes": 1, "blunders": 0},
                "endgame": {"moves": 0, "acpl": None, "mistakes": 0, "blunders": 0},
            },
            "winning_positions_reached": 1,
            "winning_positions_converted": 1,
            "time_pressure_moves_count": 2,
            "time_pressure_mistakes_count": 1,
            "fast_moves_count": 2,
            "fast_move_mistakes_count": 0,
            "critical_moves_count": 2,
            "critical_accurate_count": 2,
        },
        {
            "average_centipawn_loss": Decimal("40.00"),
            "user_move_count": 10,
            "mistakes_count": 3,
            "blunders_count": 2,
            "phase_metrics": {
                "opening": {"moves": 4, "acpl": 20.0, "mistakes": 0, "blunders": 0},
                "middlegame": {"moves": 6, "acpl": 53.33, "mistakes": 3, "blunders": 2},
                "endgame": {"moves": 0, "acpl": None, "mistakes": 0, "blunders": 0},
            },
            "winning_positions_reached": 1,
            "winning_positions_converted": 0,
            "time_pressure_moves_count": 2,
            "time_pressure_mistakes_count": 1,
            "fast_moves_count": 2,
            "fast_move_mistakes_count": 2,
            "critical_moves_count": 2,
            "critical_accurate_count": 0,
        },
    ]
    metrics = aggregate_period_metrics(
        game_rows=game_rows,
        member_results=[GAME_RESULT["win"], GAME_RESULT["loss"], GAME_RESULT["unknown"]],
    )
    assert metrics["games_count"] == 3
    assert metrics["analyzed_games_count"] == 2
    assert metrics["win_rate"] == Decimal("0.5000")
    assert metrics["loss_rate"] == Decimal("0.5000")
    assert metrics["average_centipawn_loss"] == Decimal("30.00")
    assert metrics["mistakes_per_game"] == Decimal("2.0000")
    assert metrics["blunders_per_game"] == Decimal("1.0000")
    assert metrics["conversion_rate"] == Decimal("0.5000")
    assert metrics["phase_metrics"]["opening"]["moves"] == 8
