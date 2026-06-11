from __future__ import annotations

from typing import Any

from worker.eval_package.constants import CLASSIFICATION, EVENT_TYPE
from worker.weakness_package.constants import (
    BAD_TRADE_MIN_MATERIAL_LOST,
    GAME_PHASE,
    INACCURACY_CPL,
    MISTAKE_CPL,
    OPENING_MOVE_LIMIT,
    TACTICAL_VALUE_MIN_CPL,
    WEAKNESS_THEME,
)
from worker.weakness_package.types import CandidateEventRow, ClassifiedWeakness, MoveArtifact


def classify_move(artifact: MoveArtifact) -> ClassifiedWeakness | None:
    events_by_type = _group_events_by_type(artifact.candidate_events)
    evaluation = artifact.evaluation
    cpl = evaluation.centipawn_loss if evaluation else 0
    under_pressure = EVENT_TYPE["time_pressure"] in events_by_type

    primary = _resolve_primary_theme(artifact, events_by_type, cpl)
    if primary is None:
        return None

    secondary = WEAKNESS_THEME["time_pressure"] if under_pressure and primary != WEAKNESS_THEME["time_pressure"] else None
    phase = _derive_phase(artifact.move_number, events_by_type)
    severity = _event_severity(primary, events_by_type, cpl)
    theme_key = _theme_key(primary)

    return ClassifiedWeakness(
        user_id=artifact.user_id,
        game_id=artifact.game_id,
        move_id=artifact.move_id,
        primary_theme=primary,
        secondary_theme=secondary,
        severity=round(min(1.0, max(0.0, severity)), 2),
        phase=phase,
        occurred_under_time_pressure=under_pressure,
        explanation_key=f"{theme_key}.v1",
        metadata=_build_metadata(events_by_type, evaluation),
        played_at=artifact.played_at,
    )


def classify_time_pressure_standalone(
    artifact: MoveArtifact,
    *,
    baseline_mistake_rate: float,
    pressure_mistake_rate: float,
) -> ClassifiedWeakness | None:
    if pressure_mistake_rate <= baseline_mistake_rate:
        return None

    events_by_type = _group_events_by_type(artifact.candidate_events)
    if EVENT_TYPE["time_pressure"] not in events_by_type:
        return None

    evaluation = artifact.evaluation
    if evaluation is None:
        return None

    if evaluation.classification < CLASSIFICATION["mistake"]:
        return None

    cpl = evaluation.centipawn_loss
    severity = min(1.0, 0.5 + (cpl / 600.0))

    return ClassifiedWeakness(
        user_id=artifact.user_id,
        game_id=artifact.game_id,
        move_id=artifact.move_id,
        primary_theme=WEAKNESS_THEME["time_pressure"],
        secondary_theme=None,
        severity=round(severity, 2),
        phase=_derive_phase(artifact.move_number, events_by_type),
        occurred_under_time_pressure=True,
        explanation_key="time_pressure.v1",
        metadata={
            "standalone": True,
            "baseline_mistake_rate": round(baseline_mistake_rate, 4),
            "pressure_mistake_rate": round(pressure_mistake_rate, 4),
            **_build_metadata(events_by_type, evaluation),
        },
        played_at=artifact.played_at,
    )


def _resolve_primary_theme(
    artifact: MoveArtifact,
    events_by_type: dict[int, list[CandidateEventRow]],
    cpl: int,
) -> int | None:
    if _matches_bad_trades(artifact, events_by_type, cpl):
        return WEAKNESS_THEME["bad_trades"]
    if _matches_hanging_pieces(events_by_type, cpl):
        return WEAKNESS_THEME["hanging_pieces"]
    if _matches_missed_tactics(events_by_type, cpl):
        return WEAKNESS_THEME["missed_tactics"]
    if _matches_ignored_threats(events_by_type, cpl):
        return WEAKNESS_THEME["ignored_threats"]
    if _matches_pawn_structure(events_by_type, cpl):
        return WEAKNESS_THEME["pawn_structure"]
    if EVENT_TYPE["endgame_phase"] in events_by_type:
        return WEAKNESS_THEME["endgame_technique"]
    if _matches_opening_development(artifact, events_by_type):
        return WEAKNESS_THEME["opening_development"]
    if _matches_king_safety(artifact, events_by_type):
        return WEAKNESS_THEME["king_safety"]
    return None


def _matches_bad_trades(
    artifact: MoveArtifact,
    events_by_type: dict[int, list[CandidateEventRow]],
    cpl: int,
) -> bool:
    material_events = events_by_type.get(EVENT_TYPE["material"], [])
    if not material_events:
        return False
    if "x" not in artifact.san:
        return False
    if cpl < INACCURACY_CPL:
        return False

    for event in material_events:
        material_lost = event.metadata.get("material_lost", 0)
        if material_lost >= BAD_TRADE_MIN_MATERIAL_LOST:
            return True
    return False


def _matches_hanging_pieces(
    events_by_type: dict[int, list[CandidateEventRow]],
    cpl: int,
) -> bool:
    material_events = events_by_type.get(EVENT_TYPE["material"], [])
    if material_events and cpl >= INACCURACY_CPL:
        return True

    threat_events = events_by_type.get(EVENT_TYPE["threat"], [])
    for event in threat_events:
        if event.metadata.get("ignored_hanging_pieces") and cpl >= INACCURACY_CPL:
            return True
    return False


def _matches_missed_tactics(
    events_by_type: dict[int, list[CandidateEventRow]],
    cpl: int,
) -> bool:
    tactical_events = events_by_type.get(EVENT_TYPE["tactical"], [])
    if not tactical_events:
        return False
    if cpl < TACTICAL_VALUE_MIN_CPL:
        return False
    return any(event.metadata.get("missed_tactic") or cpl >= MISTAKE_CPL for event in tactical_events)


def _matches_ignored_threats(
    events_by_type: dict[int, list[CandidateEventRow]],
    cpl: int,
) -> bool:
    threat_events = events_by_type.get(EVENT_TYPE["threat"], [])
    return bool(threat_events) and cpl >= INACCURACY_CPL


def _matches_pawn_structure(
    events_by_type: dict[int, list[CandidateEventRow]],
    cpl: int,
) -> bool:
    pawn_events = events_by_type.get(EVENT_TYPE["pawn_structure"], [])
    if not pawn_events:
        return False
    return cpl >= INACCURACY_CPL and any(event.metadata.get("new_issues") for event in pawn_events)


def _matches_opening_development(
    artifact: MoveArtifact,
    events_by_type: dict[int, list[CandidateEventRow]],
) -> bool:
    if artifact.move_number > OPENING_MOVE_LIMIT:
        return False

    king_events = events_by_type.get(EVENT_TYPE["king_safety"], [])
    for event in king_events:
        signals = event.metadata.get("signals", [])
        if "delayed_castling" in signals:
            return True
    return False


def _matches_king_safety(
    artifact: MoveArtifact,
    events_by_type: dict[int, list[CandidateEventRow]],
) -> bool:
    if _matches_opening_development(artifact, events_by_type):
        return False

    king_events = events_by_type.get(EVENT_TYPE["king_safety"], [])
    return bool(king_events)


def _derive_phase(move_number: int, events_by_type: dict[int, list[CandidateEventRow]]) -> int:
    if EVENT_TYPE["endgame_phase"] in events_by_type:
        return GAME_PHASE["endgame"]
    if move_number <= OPENING_MOVE_LIMIT:
        return GAME_PHASE["opening"]
    if move_number >= 35:
        return GAME_PHASE["endgame"]
    return GAME_PHASE["middlegame"]


def _event_severity(
    primary: int,
    events_by_type: dict[int, list[CandidateEventRow]],
    cpl: int,
) -> float:
    event_type = _primary_to_event_type(primary)
    detector_severity = 0.0
    if event_type is not None and event_type in events_by_type:
        detector_severity = max(event.severity for event in events_by_type[event_type])

    cpl_component = min(1.0, cpl / 500.0)
    return max(detector_severity, cpl_component, 0.25)


def _primary_to_event_type(primary: int) -> int | None:
    mapping = {
        WEAKNESS_THEME["hanging_pieces"]: EVENT_TYPE["material"],
        WEAKNESS_THEME["missed_tactics"]: EVENT_TYPE["tactical"],
        WEAKNESS_THEME["ignored_threats"]: EVENT_TYPE["threat"],
        WEAKNESS_THEME["opening_development"]: EVENT_TYPE["king_safety"],
        WEAKNESS_THEME["king_safety"]: EVENT_TYPE["king_safety"],
        WEAKNESS_THEME["bad_trades"]: EVENT_TYPE["material"],
        WEAKNESS_THEME["pawn_structure"]: EVENT_TYPE["pawn_structure"],
        WEAKNESS_THEME["endgame_technique"]: EVENT_TYPE["endgame_phase"],
        WEAKNESS_THEME["time_pressure"]: EVENT_TYPE["time_pressure"],
    }
    return mapping.get(primary)


def _theme_key(theme: int) -> str:
    for key, value in WEAKNESS_THEME.items():
        if value == theme:
            return key
    return "unknown"


def _group_events_by_type(events: tuple[CandidateEventRow, ...]) -> dict[int, list[CandidateEventRow]]:
    grouped: dict[int, list[CandidateEventRow]] = {}
    for event in events:
        grouped.setdefault(event.event_type, []).append(event)
    return grouped


def _build_metadata(
    events_by_type: dict[int, list[CandidateEventRow]],
    evaluation: Any,
) -> dict[str, Any]:
    metadata: dict[str, Any] = {}
    for event_type, rows in events_by_type.items():
        metadata[f"event_type_{event_type}"] = [
            {
                "severity": row.severity,
                "confidence": row.confidence,
                "metadata": row.metadata,
            }
            for row in rows
        ]
    if evaluation is not None:
        metadata["centipawn_loss"] = evaluation.centipawn_loss
        metadata["classification"] = evaluation.classification
    return metadata
