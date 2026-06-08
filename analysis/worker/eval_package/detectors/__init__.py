from __future__ import annotations

from worker.eval_package.detectors.endgame import detect_endgame_phase
from worker.eval_package.detectors.king_safety import detect_king_safety
from worker.eval_package.detectors.material import detect_material
from worker.eval_package.detectors.pawn_structure import detect_pawn_structure
from worker.eval_package.detectors.tactical import detect_tactical
from worker.eval_package.detectors.threat import detect_threat
from worker.eval_package.detectors.time_pressure import detect_time_pressure
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.engine import EngineEvaluation
from worker.eval_package.positions import MovePosition
from worker.eval_package.repository import AnalysisContext, StoredMove


def run_detectors(
    *,
    context: AnalysisContext,
    move: StoredMove,
    position: MovePosition,
    evaluation: EngineEvaluation | None,
    cpl: int | None,
) -> list[CandidateEventData]:
    events: list[CandidateEventData] = []
    events.extend(detect_material(position=position))
    events.extend(detect_time_pressure(context=context, position=position))
    if evaluation is not None and cpl is not None:
        events.extend(detect_tactical(position=position, evaluation=evaluation, cpl=cpl))
        events.extend(detect_threat(position=position, evaluation=evaluation, cpl=cpl))
    events.extend(detect_king_safety(context=context, position=position))
    events.extend(detect_pawn_structure(position=position))
    events.extend(detect_endgame_phase(position=position))
    return events
