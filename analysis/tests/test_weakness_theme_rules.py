from datetime import datetime, timezone

from worker.eval_package.constants import CLASSIFICATION, EVENT_TYPE
from worker.weakness_package.constants import WEAKNESS_THEME
from worker.weakness_package.theme_rules import classify_move
from worker.weakness_package.types import CandidateEventRow, MoveArtifact, MoveEvaluationRow


def _artifact(
    *,
    san: str = "Qh5",
    move_number: int = 10,
    events: list[CandidateEventRow] | None = None,
    cpl: int = 120,
    classification: int = CLASSIFICATION["mistake"],
) -> MoveArtifact:
    return MoveArtifact(
        move_id="move-1",
        game_id="game-1",
        user_id="user-1",
        move_number=move_number,
        san=san,
        played_at=datetime.now(timezone.utc),
        time_class=1,
        candidate_events=tuple(events or []),
        evaluation=MoveEvaluationRow(
            centipawn_loss=cpl,
            classification=classification,
            metadata={},
        ),
    )


def test_hanging_pieces_from_material_loss():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.6,
            confidence=0.9,
            metadata={"material_lost": 3},
        )
    ]
    result = classify_move(_artifact(events=events, san="Qh5"))
    assert result is not None
    assert result.primary_theme == WEAKNESS_THEME["hanging_pieces"]


def test_bad_trades_requires_capture_and_material_loss():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.7,
            confidence=0.9,
            metadata={"material_lost": 3},
        )
    ]
    result = classify_move(_artifact(events=events, san="Bxf6"))
    assert result is not None
    assert result.primary_theme == WEAKNESS_THEME["bad_trades"]


def test_missed_tactics_requires_tactical_event_and_cpl():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["tactical"],
            severity=0.8,
            confidence=0.8,
            metadata={"missed_tactic": True, "centipawn_loss": 150},
        )
    ]
    result = classify_move(_artifact(events=events, cpl=150))
    assert result is not None
    assert result.primary_theme == WEAKNESS_THEME["missed_tactics"]


def test_ignored_threats_from_threat_event():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["threat"],
            severity=0.6,
            confidence=0.7,
            metadata={"ignored_hanging_pieces": ["e4"]},
        )
    ]
    result = classify_move(_artifact(events=events, san="h3", cpl=80))
    assert result is not None
    assert result.primary_theme in {
        WEAKNESS_THEME["hanging_pieces"],
        WEAKNESS_THEME["ignored_threats"],
    }


def test_opening_development_from_delayed_castling():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["king_safety"],
            severity=0.6,
            confidence=0.65,
            metadata={"signals": ["delayed_castling"]},
        )
    ]
    result = classify_move(_artifact(events=events, move_number=8, san="a4"))
    assert result is not None
    assert result.primary_theme == WEAKNESS_THEME["opening_development"]


def test_king_safety_outside_opening():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["king_safety"],
            severity=0.6,
            confidence=0.65,
            metadata={"signals": ["open_king_file"]},
        )
    ]
    result = classify_move(_artifact(events=events, move_number=20, san="h3"))
    assert result is not None
    assert result.primary_theme == WEAKNESS_THEME["king_safety"]


def test_pawn_structure_requires_eval_worsening():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["pawn_structure"],
            severity=0.5,
            confidence=0.7,
            metadata={"new_issues": ["doubled_pawn_file_4"]},
        )
    ]
    result = classify_move(_artifact(events=events, cpl=60))
    assert result is not None
    assert result.primary_theme == WEAKNESS_THEME["pawn_structure"]


def test_endgame_technique_from_endgame_phase_event():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["endgame_phase"],
            severity=0.5,
            confidence=0.8,
            metadata={"phase_before": "middlegame", "phase_after": "endgame"},
        )
    ]
    result = classify_move(_artifact(events=events, move_number=40))
    assert result is not None
    assert result.primary_theme == WEAKNESS_THEME["endgame_technique"]


def test_time_pressure_secondary_theme():
    events = [
        CandidateEventRow(
            id="e1",
            event_type=EVENT_TYPE["material"],
            severity=0.6,
            confidence=0.9,
            metadata={"material_lost": 3},
        ),
        CandidateEventRow(
            id="e2",
            event_type=EVENT_TYPE["time_pressure"],
            severity=0.7,
            confidence=0.85,
            metadata={"clock_before_seconds": 8},
        ),
    ]
    result = classify_move(_artifact(events=events))
    assert result is not None
    assert result.secondary_theme == WEAKNESS_THEME["time_pressure"]
    assert result.occurred_under_time_pressure is True
