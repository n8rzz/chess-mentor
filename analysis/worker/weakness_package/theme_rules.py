from __future__ import annotations

from typing import Any

from worker.eval_package.constants import CLASSIFICATION, EVENT_TYPE
from worker.eval_package.game_phase import classify_position_phase
from worker.metrics_package.calculators import parse_increment_seconds, think_time_seconds
from worker.metrics_package.constants import (
    CONVERSION_EQUAL_FLOOR_CP,
    FAST_MOVE_MIN_CLOCK_SECONDS,
    FAST_MOVE_THINK_SECONDS,
    WINNING_CONSECUTIVE_MOVES,
    WINNING_CP,
)
from worker.weakness_package.constants import (
    BAD_TRADE_MIN_MATERIAL_LOST,
    GAME_PHASE,
    INACCURACY_CPL,
    MISTAKE_CPL,
    MIN_CONFIDENCE_TO_PERSIST,
    MOVING_TOO_QUICKLY_MIN_CPL,
    OPENING_MOVE_LIMIT,
    PATTERN,
    TACTICAL_VALUE_MIN_CPL,
)
from worker.weakness_package.types import AnalysisEventRow, ClassifiedPattern, MoveArtifact


def classify_move(artifact: MoveArtifact) -> list[ClassifiedPattern]:
    """Return zero or more independent theme diagnoses for a single move."""
    events_by_type = _group_events_by_type(artifact.analysis_events)
    evaluation = artifact.evaluation
    cpl = evaluation.centipawn_loss if evaluation else 0
    under_pressure = EVENT_TYPE["time_pressure"] in events_by_type
    phase = _resolve_phase(artifact)

    matchers: list[tuple[int, bool, str, dict[str, Any]]] = []

    if _matches_bad_trades(artifact, events_by_type, cpl):
        matchers.append(
            (
                PATTERN["bad_trades"],
                True,
                "bad_trades.capture_material_loss",
                _material_evidence(events_by_type),
            )
        )
    if _matches_hanging_pieces(events_by_type, cpl):
        matchers.append(
            (
                PATTERN["hanging_pieces"],
                True,
                "hanging_pieces.material_or_ignored",
                _hanging_evidence(events_by_type),
            )
        )
    if _matches_missed_tactics(events_by_type, cpl):
        matchers.append(
            (
                PATTERN["missed_tactics"],
                True,
                "missed_tactics.tactical_candidate",
                _tactical_evidence(events_by_type),
            )
        )
    if _matches_ignored_threats(events_by_type, cpl):
        matchers.append(
            (
                PATTERN["ignored_threats"],
                True,
                "ignored_threats.threat_event",
                _threat_evidence(events_by_type),
            )
        )
    if _matches_pawn_structure(events_by_type, cpl):
        matchers.append(
            (
                PATTERN["pawn_structure"],
                True,
                "pawn_structure.new_issues",
                _pawn_evidence(events_by_type),
            )
        )
    if _matches_endgame_technique(artifact, cpl):
        matchers.append(
            (
                PATTERN["endgame_technique"],
                True,
                "endgame_technique.phase_mistake",
                {},
            )
        )
    if _matches_opening_development(artifact, events_by_type):
        matchers.append(
            (
                PATTERN["opening_development"],
                True,
                "opening_development.delayed_castling",
                _king_safety_evidence(events_by_type),
            )
        )
    if _matches_king_safety(artifact, events_by_type):
        matchers.append(
            (
                PATTERN["king_safety"],
                True,
                "king_safety.king_safety_event",
                _king_safety_evidence(events_by_type),
            )
        )
    if _matches_moving_too_quickly(artifact, cpl):
        matchers.append(
            (
                PATTERN["moving_too_quickly"],
                True,
                "moving_too_quickly.fast_mistake",
                _clock_evidence(artifact),
            )
        )

    results: list[ClassifiedPattern] = []
    for pattern, _matched, reason, theme_evidence in matchers:
        severity = _event_severity(pattern, events_by_type, cpl)
        confidence = _confidence_for_pattern(pattern, events_by_type, cpl, artifact)
        if confidence < MIN_CONFIDENCE_TO_PERSIST:
            continue
        results.append(
            _build_classified(
                artifact=artifact,
                pattern=pattern,
                severity=severity,
                confidence=confidence,
                phase=phase,
                under_pressure=under_pressure,
                detection_reason=reason,
                theme_evidence=theme_evidence,
                events_by_type=events_by_type,
            )
        )
    return results


def classify_time_pressure_standalone(
    artifact: MoveArtifact,
    *,
    baseline_mistake_rate: float,
    pressure_mistake_rate: float,
) -> ClassifiedPattern | None:
    if pressure_mistake_rate <= baseline_mistake_rate:
        return None

    events_by_type = _group_events_by_type(artifact.analysis_events)
    if EVENT_TYPE["time_pressure"] not in events_by_type:
        return None

    evaluation = artifact.evaluation
    if evaluation is None:
        return None

    if evaluation.classification < CLASSIFICATION["mistake"]:
        return None

    cpl = evaluation.centipawn_loss
    severity = min(1.0, 0.5 + (cpl / 600.0))
    confidence = _clamp(
        0.75
        + (0.1 if cpl >= MISTAKE_CPL else 0.0)
        + (0.05 if pressure_mistake_rate >= baseline_mistake_rate * 2 else 0.0)
    )
    if confidence < MIN_CONFIDENCE_TO_PERSIST:
        return None

    return _build_classified(
        artifact=artifact,
        pattern=PATTERN["time_pressure"],
        severity=severity,
        confidence=confidence,
        phase=_resolve_phase(artifact),
        under_pressure=True,
        detection_reason="time_pressure.elevated_mistake_rate",
        theme_evidence={
            "standalone": True,
            "baseline_mistake_rate": round(baseline_mistake_rate, 4),
            "pressure_mistake_rate": round(pressure_mistake_rate, 4),
            **_clock_evidence(artifact),
        },
        events_by_type=events_by_type,
    )


def classify_lost_winning_positions(artifacts: list[MoveArtifact]) -> list[ClassifiedPattern]:
    """Emit one occurrence per collapsed winning episode on the worst drop move."""
    by_game: dict[str, list[MoveArtifact]] = {}
    for artifact in artifacts:
        by_game.setdefault(artifact.game_id, []).append(artifact)

    results: list[ClassifiedPattern] = []
    for game_artifacts in by_game.values():
        ordered = sorted(game_artifacts, key=lambda item: (item.ply, item.move_number))
        results.extend(_lost_winning_for_game(ordered))
    return results


def _lost_winning_for_game(ordered: list[MoveArtifact]) -> list[ClassifiedPattern]:
    consecutive_winning = 0
    in_episode = False
    episode_start_ply: int | None = None
    peak_eval: int | None = None
    episode_moves: list[MoveArtifact] = []
    episode_decision_count = 0
    results: list[ClassifiedPattern] = []

    def reset_episode() -> None:
        nonlocal in_episode, episode_start_ply, peak_eval, episode_moves, episode_decision_count
        in_episode = False
        episode_start_ply = None
        peak_eval = None
        episode_moves = []
        episode_decision_count = 0

    def close_lost_episode(final_artifact: MoveArtifact, final_eval: int) -> None:
        nonlocal in_episode, episode_start_ply, peak_eval, episode_moves, episode_decision_count
        if not in_episode or not episode_moves:
            reset_episode()
            return

        culpable = max(
            episode_moves,
            key=lambda item: (item.evaluation.centipawn_loss if item.evaluation else 0),
        )
        if culpable.evaluation is None:
            reset_episode()
            return

        drop = (peak_eval or 0) - final_eval
        if final_eval <= -100:
            severity = 0.9
            outcome = "winning_to_losing"
        else:
            severity = 0.75
            outcome = "winning_to_equal"

        confidence = _clamp(
            0.80
            + (0.1 if drop >= 300 else 0.0)
            + (0.05 if episode_decision_count >= WINNING_CONSECUTIVE_MOVES else 0.0)
        )
        if confidence >= MIN_CONFIDENCE_TO_PERSIST:
            under_pressure = any(
                event.event_type == EVENT_TYPE["time_pressure"] for event in culpable.analysis_events
            )
            results.append(
                _build_classified(
                    artifact=culpable,
                    pattern=PATTERN["lost_winning_positions"],
                    severity=severity,
                    confidence=confidence,
                    phase=_resolve_phase(culpable),
                    under_pressure=under_pressure,
                    detection_reason=f"lost_winning_positions.{outcome}",
                    theme_evidence={
                        "episode_start_ply": episode_start_ply,
                        "episode_end_ply": final_artifact.ply,
                        "peak_eval_cp": peak_eval,
                        "final_eval_cp": final_eval,
                        "eval_drop_cp": drop,
                        "outcome": outcome,
                    },
                    events_by_type=_group_events_by_type(culpable.analysis_events),
                )
            )

        reset_episode()

    for artifact in ordered:
        evaluation = artifact.evaluation
        if evaluation is None:
            consecutive_winning = 0
            continue

        before = evaluation.eval_before_cp
        after = evaluation.eval_after_cp

        if before is not None and before >= WINNING_CP:
            consecutive_winning += 1
        else:
            consecutive_winning = 0

        if not in_episode and consecutive_winning >= WINNING_CONSECUTIVE_MOVES:
            in_episode = True
            episode_start_ply = artifact.ply
            episode_moves = [artifact]
            episode_decision_count = consecutive_winning
            peak_eval = before if before is not None else after
            if after is not None and (peak_eval is None or after > peak_eval):
                peak_eval = after
        elif in_episode:
            episode_moves.append(artifact)
            episode_decision_count += 1
            if before is not None and (peak_eval is None or before > peak_eval):
                peak_eval = before
            if after is not None and (peak_eval is None or after > peak_eval):
                peak_eval = after

        if in_episode:
            dropped = False
            final_eval = after if after is not None else before
            if before is not None and before < CONVERSION_EQUAL_FLOOR_CP:
                dropped = True
                final_eval = before
            if after is not None and after < CONVERSION_EQUAL_FLOOR_CP:
                dropped = True
                final_eval = after
            if dropped and final_eval is not None:
                close_lost_episode(artifact, final_eval)
                consecutive_winning = 0

    return results


def _matches_bad_trades(
    artifact: MoveArtifact,
    events_by_type: dict[int, list[AnalysisEventRow]],
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
    events_by_type: dict[int, list[AnalysisEventRow]],
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
    events_by_type: dict[int, list[AnalysisEventRow]],
    cpl: int,
) -> bool:
    tactical_events = events_by_type.get(EVENT_TYPE["tactical"], [])
    if not tactical_events:
        return False
    if cpl < TACTICAL_VALUE_MIN_CPL:
        return False
    return any(event.metadata.get("missed_tactic") or cpl >= MISTAKE_CPL for event in tactical_events)


def _matches_ignored_threats(
    events_by_type: dict[int, list[AnalysisEventRow]],
    cpl: int,
) -> bool:
    threat_events = events_by_type.get(EVENT_TYPE["threat"], [])
    return bool(threat_events) and cpl >= INACCURACY_CPL


def _matches_pawn_structure(
    events_by_type: dict[int, list[AnalysisEventRow]],
    cpl: int,
) -> bool:
    pawn_events = events_by_type.get(EVENT_TYPE["pawn_structure"], [])
    if not pawn_events:
        return False
    return cpl >= INACCURACY_CPL and any(event.metadata.get("new_issues") for event in pawn_events)


def _matches_endgame_technique(artifact: MoveArtifact, cpl: int) -> bool:
    if _resolve_phase(artifact) != GAME_PHASE["endgame"]:
        return False
    return cpl >= MISTAKE_CPL


def _matches_opening_development(
    artifact: MoveArtifact,
    events_by_type: dict[int, list[AnalysisEventRow]],
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
    events_by_type: dict[int, list[AnalysisEventRow]],
) -> bool:
    if _matches_opening_development(artifact, events_by_type):
        return False

    king_events = events_by_type.get(EVENT_TYPE["king_safety"], [])
    return bool(king_events)


def _matches_moving_too_quickly(artifact: MoveArtifact, cpl: int) -> bool:
    evaluation = artifact.evaluation
    if evaluation is None:
        return False
    if _resolve_phase(artifact) == GAME_PHASE["opening"]:
        return False
    if artifact.clock_before is None or artifact.clock_after is None:
        return False
    if artifact.clock_before < FAST_MOVE_MIN_CLOCK_SECONDS:
        return False

    increment = parse_increment_seconds(artifact.time_control)
    think = think_time_seconds(
        clock_before=artifact.clock_before,
        clock_after=artifact.clock_after,
        increment=increment,
    )
    if think is None:
        return False

    fast_limit = FAST_MOVE_THINK_SECONDS.get(artifact.time_class, 3)
    if think > fast_limit:
        return False

    if evaluation.classification >= CLASSIFICATION["mistake"]:
        return True
    return cpl >= MOVING_TOO_QUICKLY_MIN_CPL


def _resolve_phase(artifact: MoveArtifact) -> int:
    if artifact.phase is not None:
        return int(artifact.phase)
    if artifact.fen_after:
        return classify_position_phase(artifact.fen_after, artifact.move_number)
    if artifact.move_number <= OPENING_MOVE_LIMIT:
        return GAME_PHASE["opening"]
    return GAME_PHASE["middlegame"]


def _event_severity(
    primary: int,
    events_by_type: dict[int, list[AnalysisEventRow]],
    cpl: int,
) -> float:
    event_type = _primary_to_event_type(primary)
    detector_severity = 0.0
    if event_type is not None and event_type in events_by_type:
        detector_severity = max(event.severity for event in events_by_type[event_type])

    cpl_component = min(1.0, cpl / 500.0)
    return max(detector_severity, cpl_component, 0.25)


def _confidence_for_pattern(
    pattern: int,
    events_by_type: dict[int, list[AnalysisEventRow]],
    cpl: int,
    artifact: MoveArtifact,
) -> float:
    event_type = _primary_to_event_type(pattern)
    event_confidence = 0.0
    if event_type is not None and event_type in events_by_type:
        event_confidence = max(event.confidence for event in events_by_type[event_type])

    cpl_boost = 0.1 if cpl >= MISTAKE_CPL else (0.05 if cpl >= INACCURACY_CPL else 0.0)

    if pattern == PATTERN["moving_too_quickly"]:
        base = 0.70
        think = None
        if artifact.clock_before is not None and artifact.clock_after is not None:
            think = think_time_seconds(
                clock_before=artifact.clock_before,
                clock_after=artifact.clock_after,
                increment=parse_increment_seconds(artifact.time_control),
            )
        if think is not None and think < 1:
            base += 0.10
        if cpl > 300:
            base += 0.10
        evaluation = artifact.evaluation
        if evaluation is not None and evaluation.critical_position:
            base += 0.10
        return _clamp(base)

    if pattern == PATTERN["endgame_technique"]:
        return _clamp(max(0.70, event_confidence, 0.65 + cpl_boost))

    if event_confidence > 0:
        return _clamp(max(event_confidence, 0.65) + cpl_boost * 0.5)

    return _clamp(0.70 + cpl_boost)


def _primary_to_event_type(primary: int) -> int | None:
    mapping = {
        PATTERN["hanging_pieces"]: EVENT_TYPE["material"],
        PATTERN["missed_tactics"]: EVENT_TYPE["tactical"],
        PATTERN["ignored_threats"]: EVENT_TYPE["threat"],
        PATTERN["opening_development"]: EVENT_TYPE["king_safety"],
        PATTERN["king_safety"]: EVENT_TYPE["king_safety"],
        PATTERN["bad_trades"]: EVENT_TYPE["material"],
        PATTERN["pawn_structure"]: EVENT_TYPE["pawn_structure"],
        PATTERN["endgame_technique"]: EVENT_TYPE["endgame_phase"],
        PATTERN["time_pressure"]: EVENT_TYPE["time_pressure"],
    }
    return mapping.get(primary)


def _theme_key(theme: int) -> str:
    for key, value in PATTERN.items():
        if value == theme:
            return key
    return "unknown"


def _group_events_by_type(events: tuple[AnalysisEventRow, ...]) -> dict[int, list[AnalysisEventRow]]:
    grouped: dict[int, list[AnalysisEventRow]] = {}
    for event in events:
        grouped.setdefault(event.event_type, []).append(event)
    return grouped


def _build_classified(
    *,
    artifact: MoveArtifact,
    pattern: int,
    severity: float,
    confidence: float,
    phase: int,
    under_pressure: bool,
    detection_reason: str,
    theme_evidence: dict[str, Any],
    events_by_type: dict[int, list[AnalysisEventRow]],
) -> ClassifiedPattern:
    evaluation = artifact.evaluation
    pattern_key = _theme_key(pattern)
    evidence = {
        "detection_reason": detection_reason,
        "played_move": artifact.san,
        "best_move": evaluation.best_move_san if evaluation else None,
        "best_move_uci": evaluation.best_move_uci if evaluation else None,
        "eval_before_cp": evaluation.eval_before_cp if evaluation else None,
        "eval_after_cp": evaluation.eval_after_cp if evaluation else None,
        "centipawn_loss": evaluation.centipawn_loss if evaluation else None,
        "classification": evaluation.classification if evaluation else None,
        "clock_before": artifact.clock_before,
        "clock_after": artifact.clock_after,
        "opening_eco": artifact.opening_eco,
        "opening_name": artifact.opening_name,
        **theme_evidence,
    }
    metadata = {
        "evidence": evidence,
        **_build_event_metadata(events_by_type, evaluation),
    }
    return ClassifiedPattern(
        user_id=artifact.user_id,
        game_id=artifact.game_id,
        move_id=artifact.move_id,
        primary_pattern=pattern,
        secondary_pattern=None,
        severity=round(min(1.0, max(0.0, severity)), 2),
        confidence=round(min(1.0, max(0.0, confidence)), 2),
        phase=phase,
        occurred_under_time_pressure=under_pressure,
        explanation_key=f"{pattern_key}.v1",
        metadata=metadata,
        played_at=artifact.played_at,
    )


def _build_event_metadata(
    events_by_type: dict[int, list[AnalysisEventRow]],
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


def _material_evidence(events_by_type: dict[int, list[AnalysisEventRow]]) -> dict[str, Any]:
    rows = events_by_type.get(EVENT_TYPE["material"], [])
    if not rows:
        return {}
    best = max(rows, key=lambda row: row.severity)
    return {"material_lost": best.metadata.get("material_lost"), "material_delta": best.metadata.get("material_delta")}


def _hanging_evidence(events_by_type: dict[int, list[AnalysisEventRow]]) -> dict[str, Any]:
    evidence = _material_evidence(events_by_type)
    for event in events_by_type.get(EVENT_TYPE["threat"], []):
        hanging = event.metadata.get("ignored_hanging_pieces")
        if hanging:
            evidence["ignored_hanging_pieces"] = hanging
            break
    return evidence


def _tactical_evidence(events_by_type: dict[int, list[AnalysisEventRow]]) -> dict[str, Any]:
    rows = events_by_type.get(EVENT_TYPE["tactical"], [])
    if not rows:
        return {}
    best = max(rows, key=lambda row: row.severity)
    return {
        "missed_tactic": best.metadata.get("missed_tactic"),
        "best_move_uci": best.metadata.get("best_move_uci"),
    }


def _threat_evidence(events_by_type: dict[int, list[AnalysisEventRow]]) -> dict[str, Any]:
    rows = events_by_type.get(EVENT_TYPE["threat"], [])
    if not rows:
        return {}
    best = max(rows, key=lambda row: row.severity)
    return {"ignored_hanging_pieces": best.metadata.get("ignored_hanging_pieces")}


def _pawn_evidence(events_by_type: dict[int, list[AnalysisEventRow]]) -> dict[str, Any]:
    rows = events_by_type.get(EVENT_TYPE["pawn_structure"], [])
    if not rows:
        return {}
    best = max(rows, key=lambda row: row.severity)
    return {"new_issues": best.metadata.get("new_issues")}


def _king_safety_evidence(events_by_type: dict[int, list[AnalysisEventRow]]) -> dict[str, Any]:
    rows = events_by_type.get(EVENT_TYPE["king_safety"], [])
    if not rows:
        return {}
    best = max(rows, key=lambda row: row.severity)
    return {"signals": best.metadata.get("signals")}


def _clock_evidence(artifact: MoveArtifact) -> dict[str, Any]:
    increment = parse_increment_seconds(artifact.time_control)
    think = think_time_seconds(
        clock_before=artifact.clock_before,
        clock_after=artifact.clock_after,
        increment=increment,
    )
    return {
        "think_time_seconds": think,
        "increment_seconds": increment,
        "fast_think_limit_seconds": FAST_MOVE_THINK_SECONDS.get(artifact.time_class, 3),
    }


def _clamp(value: float) -> float:
    return min(1.0, max(0.0, value))
