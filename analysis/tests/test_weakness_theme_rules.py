from datetime import datetime, timezone

from worker.eval_package.constants import CLASSIFICATION, EVENT_TYPE, TIME_CLASS
from worker.weakness_package.constants import GAME_PHASE, PATTERN
from worker.weakness_package.theme_rules import (
    classify_lost_winning_positions,
    classify_move,
)
from worker.weakness_package.types import AnalysisEventRow, MoveArtifact, MoveEvaluationRow


def _artifact(
    *,
    san: str = "Qh5",
    move_number: int = 10,
    ply: int = 20,
    events: list[AnalysisEventRow] | None = None,
    cpl: int = 120,
    classification: int = CLASSIFICATION["mistake"],
    phase: int | None = None,
    fen_after: str | None = None,
    clock_before: int | None = None,
    clock_after: int | None = None,
    time_control: str | None = "180+0",
    time_class: int = TIME_CLASS["blitz"],
    eval_before_cp: int | None = 40,
    eval_after_cp: int | None = -80,
    best_move_san: str | None = "d4",
    critical_position: bool = False,
    move_id: str = "move-1",
    game_id: str = "game-1",
) -> MoveArtifact:
    return MoveArtifact(
        move_id=move_id,
        game_id=game_id,
        user_id="user-1",
        move_number=move_number,
        san=san,
        played_at=datetime.now(timezone.utc),
        time_class=time_class,
        ply=ply,
        phase=phase,
        fen_after=fen_after,
        clock_before=clock_before,
        clock_after=clock_after,
        time_control=time_control,
        analysis_events=tuple(events or []),
        evaluation=MoveEvaluationRow(
            centipawn_loss=cpl,
            classification=classification,
            metadata={},
            eval_before_cp=eval_before_cp,
            eval_after_cp=eval_after_cp,
            best_move_san=best_move_san,
            best_move_uci="d2d4",
            critical_position=critical_position,
        ),
    )


def _patterns(results: list) -> set[int]:
    return {item.primary_pattern for item in results}


def test_hanging_pieces_from_material_loss():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.6,
            confidence=0.9,
            metadata={"material_lost": 3},
        )
    ]
    results = classify_move(_artifact(events=events, san="Qh5"))
    assert PATTERN["hanging_pieces"] in _patterns(results)
    assert all(item.secondary_pattern is None for item in results)
    hanging = next(item for item in results if item.primary_pattern == PATTERN["hanging_pieces"])
    assert hanging.confidence >= 0.65
    assert hanging.metadata["evidence"]["detection_reason"]


def test_bad_trades_requires_capture_and_material_loss():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.7,
            confidence=0.9,
            metadata={"material_lost": 3},
        )
    ]
    results = classify_move(_artifact(events=events, san="Bxf6"))
    assert PATTERN["bad_trades"] in _patterns(results)
    assert PATTERN["hanging_pieces"] in _patterns(results)


def test_missed_tactics_requires_tactical_event_and_cpl():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["tactical"],
            severity=0.8,
            confidence=0.8,
            metadata={"missed_tactic": True, "centipawn_loss": 150},
        )
    ]
    results = classify_move(_artifact(events=events, cpl=150))
    assert PATTERN["missed_tactics"] in _patterns(results)


def test_ignored_threats_from_threat_event():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["threat"],
            severity=0.6,
            confidence=0.7,
            metadata={"ignored_hanging_pieces": ["e4"]},
        )
    ]
    results = classify_move(_artifact(events=events, san="h3", cpl=80))
    patterns = _patterns(results)
    assert PATTERN["hanging_pieces"] in patterns or PATTERN["ignored_threats"] in patterns
    assert PATTERN["ignored_threats"] in patterns


def test_opening_development_from_delayed_castling():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["king_safety"],
            severity=0.6,
            confidence=0.65,
            metadata={"signals": ["delayed_castling"]},
        )
    ]
    results = classify_move(_artifact(events=events, move_number=8, san="a4"))
    assert PATTERN["opening_development"] in _patterns(results)
    assert PATTERN["king_safety"] not in _patterns(results)


def test_king_safety_outside_opening():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["king_safety"],
            severity=0.6,
            confidence=0.65,
            metadata={"signals": ["open_king_file"]},
        )
    ]
    results = classify_move(_artifact(events=events, move_number=20, san="h3"))
    assert PATTERN["king_safety"] in _patterns(results)


def test_pawn_structure_requires_eval_worsening():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["pawn_structure"],
            severity=0.5,
            confidence=0.7,
            metadata={"new_issues": ["doubled_pawn_file_4"]},
        )
    ]
    results = classify_move(_artifact(events=events, cpl=60))
    assert PATTERN["pawn_structure"] in _patterns(results)


def test_endgame_technique_from_stored_endgame_phase():
    results = classify_move(
        _artifact(
            move_number=42,
            phase=GAME_PHASE["endgame"],
            cpl=150,
            san="Ke2",
        )
    )
    assert PATTERN["endgame_technique"] in _patterns(results)
    endgame = next(item for item in results if item.primary_pattern == PATTERN["endgame_technique"])
    assert endgame.phase == GAME_PHASE["endgame"]


def test_endgame_technique_requires_mistake_cpl():
    results = classify_move(
        _artifact(
            move_number=42,
            phase=GAME_PHASE["endgame"],
            cpl=40,
            san="Ke2",
        )
    )
    assert results == []


def test_pattern_phase_matches_stored_move_phase():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.6,
            confidence=0.9,
            metadata={"material_lost": 3},
        )
    ]
    results = classify_move(
        _artifact(events=events, san="Qh5", phase=GAME_PHASE["middlegame"], move_number=22)
    )
    hanging = next(item for item in results if item.primary_pattern == PATTERN["hanging_pieces"])
    assert hanging.phase == GAME_PHASE["middlegame"]


def test_resolve_phase_falls_back_to_fen_when_phase_null():
    endgame_fen = "4k3/8/8/8/8/8/4P3/4K3 w - - 0 40"
    results = classify_move(
        _artifact(
            san="Ke2",
            move_number=40,
            phase=None,
            fen_after=endgame_fen,
            cpl=150,
        )
    )
    assert PATTERN["endgame_technique"] in _patterns(results)
    endgame = next(item for item in results if item.primary_pattern == PATTERN["endgame_technique"])
    assert endgame.phase == GAME_PHASE["endgame"]


def test_time_pressure_marks_occurred_under_pressure_without_secondary():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.6,
            confidence=0.9,
            metadata={"material_lost": 3},
        ),
        AnalysisEventRow(
            id="e2",
            event_type=EVENT_TYPE["time_pressure"],
            severity=0.7,
            confidence=0.85,
            metadata={"clock_before_seconds": 8},
        ),
    ]
    results = classify_move(_artifact(events=events))
    assert PATTERN["hanging_pieces"] in _patterns(results)
    hanging = next(item for item in results if item.primary_pattern == PATTERN["hanging_pieces"])
    assert hanging.secondary_pattern is None
    assert hanging.occurred_under_time_pressure is True


def test_moving_too_quickly_on_fast_mistake():
    results = classify_move(
        _artifact(
            phase=GAME_PHASE["middlegame"],
            clock_before=90,
            clock_after=89,
            time_control="180+0",
            cpl=200,
            classification=CLASSIFICATION["mistake"],
        )
    )
    assert PATTERN["moving_too_quickly"] in _patterns(results)
    fast = next(item for item in results if item.primary_pattern == PATTERN["moving_too_quickly"])
    assert fast.confidence >= 0.65
    assert fast.metadata["evidence"]["think_time_seconds"] == 1


def test_moving_too_quickly_excluded_in_opening():
    results = classify_move(
        _artifact(
            phase=GAME_PHASE["opening"],
            move_number=5,
            clock_before=90,
            clock_after=89,
            cpl=200,
            classification=CLASSIFICATION["mistake"],
        )
    )
    assert PATTERN["moving_too_quickly"] not in _patterns(results)


def test_lost_winning_positions_on_collapsed_episode():
    artifacts = [
        _artifact(
            move_id="m1",
            ply=10,
            move_number=10,
            eval_before_cp=250,
            eval_after_cp=240,
            cpl=10,
            classification=CLASSIFICATION["good"],
        ),
        _artifact(
            move_id="m2",
            ply=12,
            move_number=11,
            eval_before_cp=240,
            eval_after_cp=220,
            cpl=20,
            classification=CLASSIFICATION["good"],
        ),
        _artifact(
            move_id="m3",
            ply=14,
            move_number=12,
            eval_before_cp=220,
            eval_after_cp=20,
            cpl=200,
            classification=CLASSIFICATION["mistake"],
        ),
    ]
    results = classify_lost_winning_positions(artifacts)
    assert len(results) == 1
    assert results[0].primary_pattern == PATTERN["lost_winning_positions"]
    assert results[0].move_id == "m3"
    assert results[0].metadata["evidence"]["outcome"] == "winning_to_equal"
    assert results[0].confidence >= 0.65


def test_lost_winning_positions_winning_to_losing_is_severe():
    artifacts = [
        _artifact(
            move_id="m1",
            ply=10,
            move_number=10,
            eval_before_cp=300,
            eval_after_cp=280,
            cpl=20,
            classification=CLASSIFICATION["good"],
        ),
        _artifact(
            move_id="m2",
            ply=12,
            move_number=11,
            eval_before_cp=280,
            eval_after_cp=250,
            cpl=30,
            classification=CLASSIFICATION["good"],
        ),
        _artifact(
            move_id="m3",
            ply=14,
            move_number=12,
            eval_before_cp=250,
            eval_after_cp=-150,
            cpl=400,
            classification=CLASSIFICATION["blunder"],
        ),
    ]
    results = classify_lost_winning_positions(artifacts)
    assert len(results) == 1
    assert results[0].metadata["evidence"]["outcome"] == "winning_to_losing"
    assert results[0].severity >= 0.9
    assert results[0].move_id == "m3"


def test_lost_winning_positions_no_emit_when_episode_holds():
    artifacts = [
        _artifact(
            move_id="m1",
            ply=10,
            move_number=10,
            eval_before_cp=250,
            eval_after_cp=240,
            cpl=10,
            classification=CLASSIFICATION["good"],
        ),
        _artifact(
            move_id="m2",
            ply=12,
            move_number=11,
            eval_before_cp=240,
            eval_after_cp=230,
            cpl=10,
            classification=CLASSIFICATION["good"],
        ),
        _artifact(
            move_id="m3",
            ply=14,
            move_number=12,
            eval_before_cp=230,
            eval_after_cp=210,
            cpl=20,
            classification=CLASSIFICATION["good"],
        ),
    ]
    assert classify_lost_winning_positions(artifacts) == []


def test_lost_winning_positions_picks_highest_cpl_move_in_episode():
    artifacts = [
        _artifact(
            move_id="m1",
            ply=10,
            move_number=10,
            eval_before_cp=250,
            eval_after_cp=240,
            cpl=10,
            classification=CLASSIFICATION["good"],
        ),
        _artifact(
            move_id="m2",
            ply=12,
            move_number=11,
            eval_before_cp=240,
            eval_after_cp=100,
            cpl=140,
            classification=CLASSIFICATION["mistake"],
        ),
        _artifact(
            move_id="m3",
            ply=14,
            move_number=12,
            eval_before_cp=100,
            eval_after_cp=20,
            cpl=80,
            classification=CLASSIFICATION["inaccuracy"],
        ),
    ]
    results = classify_lost_winning_positions(artifacts)
    assert len(results) == 1
    assert results[0].move_id == "m2"


def test_multi_label_hanging_and_moving_too_quickly():
    events = [
        AnalysisEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.6,
            confidence=0.9,
            metadata={"material_lost": 3},
        )
    ]
    results = classify_move(
        _artifact(
            events=events,
            phase=GAME_PHASE["middlegame"],
            clock_before=120,
            clock_after=119,
            cpl=250,
            classification=CLASSIFICATION["blunder"],
        )
    )
    patterns = _patterns(results)
    assert PATTERN["hanging_pieces"] in patterns
    assert PATTERN["moving_too_quickly"] in patterns
