from __future__ import annotations

from worker.eval_package.constants import EVENT_TYPE, TIME_PRESSURE_THRESHOLDS_SECONDS
from worker.eval_package.detectors.types import CandidateEventData
from worker.eval_package.positions import MovePosition
from worker.eval_package.repository import AnalysisContext


def detect_time_pressure(*, context: AnalysisContext, position: MovePosition) -> list[CandidateEventData]:
    if not position.parsed.played_by_user:
        return []

    clock = position.parsed.clock_before
    if clock is None:
        return []

    threshold = TIME_PRESSURE_THRESHOLDS_SECONDS.get(context.time_class)
    if threshold is None or clock >= threshold:
        return []

    severity = min(1.0, (threshold - clock) / max(threshold, 1))
    return [
        CandidateEventData(
            event_type=EVENT_TYPE["time_pressure"],
            severity=round(severity, 2),
            confidence=0.85,
            metadata={"clock_before_seconds": clock, "threshold_seconds": threshold},
        )
    ]
