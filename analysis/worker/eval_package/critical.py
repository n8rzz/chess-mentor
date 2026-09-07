from __future__ import annotations

from dataclasses import dataclass

from worker.eval_package.constants import (
    CRITICAL_CANDIDATE_GAP_CP,
    CRITICAL_EQUAL_CP,
    CRITICAL_LOSING_CP,
    CRITICAL_ONLY_MOVE_GAP_CP,
    CRITICAL_SCORE_THRESHOLD,
    CRITICAL_WINNING_CP,
    CPL_THRESHOLDS,
    EVENT_TYPE,
    TIME_PRESSURE_THRESHOLDS_SECONDS,
)
from worker.eval_package.detectors.material import detect_material
from worker.eval_package.detectors.tactical import detect_tactical
from worker.eval_package.detectors.threat import detect_threat
from worker.eval_package.engine import CandidateLine, EngineEvaluation
from worker.eval_package.positions import MovePosition
from worker.eval_package.repository import AnalysisContext, StoredMove


@dataclass(frozen=True)
class CriticalAssessment:
    critical_position: bool
    criticality_score: float
    reasons: tuple[str, ...]
    candidate_gap_cp: int | None


def assess_criticality(
    *,
    context: AnalysisContext,
    move: StoredMove,
    position: MovePosition,
    evaluation: EngineEvaluation,
    cpl: int,
) -> CriticalAssessment:
    reasons: list[str] = []
    score = 0.0

    candidate_gap = candidate_gap_cp(evaluation.candidates)
    if candidate_gap is not None and candidate_gap >= CRITICAL_CANDIDATE_GAP_CP:
        reasons.append("candidate_dispersion")
        score += 0.35 if candidate_gap < CRITICAL_ONLY_MOVE_GAP_CP else 0.5
    if candidate_gap is not None and candidate_gap >= CRITICAL_ONLY_MOVE_GAP_CP:
        reasons.append("only_move")
        score += 0.15

    if cpl >= CPL_THRESHOLDS["blunder"]:
        reasons.append("blunder_cpl")
        score += 0.4
    elif cpl >= CPL_THRESHOLDS["mistake"]:
        reasons.append("mistake_cpl")
        score += 0.25
    elif cpl >= CPL_THRESHOLDS["inaccuracy"]:
        reasons.append("inaccuracy_cpl")
        score += 0.1

    if _missed_mate(evaluation):
        reasons.append("forced_mate_missed")
        score += 0.45

    transition = _winning_transition(evaluation.eval_before_cp, evaluation.eval_after_cp)
    if transition:
        reasons.append(transition)
        score += 0.3

    if _time_pressure(context=context, move=move):
        reasons.append("time_pressure")
        score += 0.15

    detector_boost = _detector_boost(
        context=context,
        position=position,
        evaluation=evaluation,
        cpl=cpl,
    )
    if detector_boost:
        reasons.extend(detector_boost)
        score += 0.1 * len(detector_boost)

    score = min(1.0, round(score, 2))
    critical = score >= CRITICAL_SCORE_THRESHOLD or bool(
        set(reasons) & {"candidate_dispersion", "only_move", "blunder_cpl", "forced_mate_missed"}
    )

    return CriticalAssessment(
        critical_position=critical,
        criticality_score=score if critical else score,
        reasons=tuple(dict.fromkeys(reasons)),
        candidate_gap_cp=candidate_gap,
    )


def candidate_gap_cp(candidates: tuple[CandidateLine, ...] | list[CandidateLine]) -> int | None:
    if len(candidates) < 2:
        return None
    return int(candidates[0].eval_cp - candidates[1].eval_cp)


def _missed_mate(evaluation: EngineEvaluation) -> bool:
    mate_before = evaluation.mate_before
    mate_after = evaluation.mate_after
    if mate_before is not None and mate_before > 0 and (mate_after is None or mate_after <= 0):
        return True
    if evaluation.eval_before_cp >= CRITICAL_WINNING_CP and mate_after is not None and mate_after < 0:
        return True
    return False


def _winning_transition(eval_before: int, eval_after: int) -> str | None:
    if eval_before >= CRITICAL_WINNING_CP and eval_after <= CRITICAL_EQUAL_CP:
        return "lost_winning_advantage"
    if abs(eval_before) <= CRITICAL_EQUAL_CP and eval_after <= CRITICAL_LOSING_CP:
        return "equal_to_losing"
    if eval_before <= CRITICAL_EQUAL_CP and eval_after >= CRITICAL_WINNING_CP:
        return "gained_winning_advantage"
    return None


def _time_pressure(*, context: AnalysisContext, move: StoredMove) -> bool:
    if move.clock_before is None:
        return False
    threshold = TIME_PRESSURE_THRESHOLDS_SECONDS.get(context.time_class)
    if threshold is None:
        return False
    return move.clock_before < threshold


def _detector_boost(
    *,
    context: AnalysisContext,
    position: MovePosition,
    evaluation: EngineEvaluation,
    cpl: int,
) -> list[str]:
    boosts: list[str] = []
    if detect_material(position=position):
        boosts.append("material_signal")
    if detect_tactical(position=position, evaluation=evaluation, cpl=cpl):
        boosts.append("tactical_signal")
    if detect_threat(position=position, evaluation=evaluation, cpl=cpl):
        boosts.append("threat_signal")
    # context unused today but kept for detector API symmetry / future clock-aware detectors
    _ = context
    return boosts


def critical_event_payload(assessment: CriticalAssessment) -> dict:
    return {
        "event_type": EVENT_TYPE["critical_position"],
        "severity": round(min(1.0, assessment.criticality_score), 2),
        "confidence": 0.9,
        "metadata": {
            "criticality_score": assessment.criticality_score,
            "reasons": list(assessment.reasons),
            "candidate_gap_cp": assessment.candidate_gap_cp,
        },
    }
