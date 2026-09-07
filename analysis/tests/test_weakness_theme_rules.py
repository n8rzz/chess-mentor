from datetime import datetime, timezone

from worker.eval_package.constants import CLASSIFICATION, EVENT_TYPE
from worker.weakness_package.constants import GAME_PHASE, PATTERN
from worker.weakness_package.theme_rules import classify_move
from worker.weakness_package.types import AnalysisEventRow, MoveArtifact, MoveEvaluationRow


def _artifact(
    *,
    san: str = "Qh5",
    move_number: int = 10,
    events: list[AnalysisEventRow] | None = None,
    cpl: int = 120,
    classification: int = CLASSIFICATION["mistake"],
    phase: int | None = None,
    fen_after: str | None = None,
) -> MoveArtifact:
    return MoveArtifact(
        move_id="move-1",
        game_id="game-1",
        user_id="user-1",
        move_number=move_number,
        san=san,
        played_at=datetime.now(timezone.utc),
        time_class=1,
        phase=phase,
        fen_after=fen_after,
        analysis_events=tuple(events or []),
        evaluation=MoveEvaluationRow(
            centipawn_loss=cpl,
            classification=classification,
            metadata={},
        ),
    )


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
    result = classify_move(_artifact(events=events, san="Qh5"))
    assert result is not None
    assert result.primary_pattern == PATTERN["hanging_pieces"]


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
    result = classify_move(_artifact(events=events, san="Bxf6"))
    assert result is not None
    assert result.primary_pattern == PATTERN["bad_trades"]


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
    result = classify_move(_artifact(events=events, cpl=150))
    assert result is not None
    assert result.primary_pattern == PATTERN["missed_tactics"]


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
    result = classify_move(_artifact(events=events, san="h3", cpl=80))
    assert result is not None
    assert result.primary_pattern in {
        PATTERN["hanging_pieces"],
        PATTERN["ignored_threats"],
    }


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
    result = classify_move(_artifact(events=events, move_number=8, san="a4"))
    assert result is not None
    assert result.primary_pattern == PATTERN["opening_development"]


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
    result = classify_move(_artifact(events=events, move_number=20, san="h3"))
    assert result is not None
    assert result.primary_pattern == PATTERN["king_safety"]


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
    result = classify_move(_artifact(events=events, cpl=60))
    assert result is not None
    assert result.primary_pattern == PATTERN["pawn_structure"]


def test_endgame_technique_from_stored_endgame_phase():
    # Mid-endgame mistake: no transition event on this ply.
    result = classify_move(
        _artifact(
            move_number=42,
            phase=GAME_PHASE["endgame"],
            cpl=150,
            san="Ke2",
        )
    )
    assert result is not None
    assert result.primary_pattern == PATTERN["endgame_technique"]
    assert result.phase == GAME_PHASE["endgame"]


def test_endgame_technique_requires_mistake_cpl():
    result = classify_move(
        _artifact(
            move_number=42,
            phase=GAME_PHASE["endgame"],
            cpl=40,
            san="Ke2",
        )
    )
    assert result is None


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
    result = classify_move(
        _artifact(events=events, san="Qh5", phase=GAME_PHASE["middlegame"], move_number=22)
    )
    assert result is not None
    assert result.phase == GAME_PHASE["middlegame"]


def test_resolve_phase_falls_back_to_fen_when_phase_null():
    endgame_fen = "4k3/8/8/8/8/8/4P3/4K3 w - - 0 40"
    result = classify_move(
        _artifact(
            san="Ke2",
            move_number=40,
            phase=None,
            fen_after=endgame_fen,
            cpl=150,
        )
    )
    assert result is not None
    assert result.primary_pattern == PATTERN["endgame_technique"]
    assert result.phase == GAME_PHASE["endgame"]


def test_time_pressure_secondary_pattern():
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
    result = classify_move(_artifact(events=events))
    assert result is not None
    assert result.secondary_pattern == PATTERN["time_pressure"]
    assert result.occurred_under_time_pressure is True
