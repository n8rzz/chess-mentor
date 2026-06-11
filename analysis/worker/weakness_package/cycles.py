from __future__ import annotations

from worker.weakness_package.constants import (
    CYCLE_STATUS,
    DETECTION_WINDOW_DAYS,
    DETECTION_WINDOW_GAMES,
    IMPROVING_THRESHOLD,
    MANAGED_THRESHOLD,
    MIN_GAMES_FOR_ACTIVE,
    MIN_OCCURRENCES_FOR_ACTIVE,
)
from worker.weakness_package.types import CycleBuildResult, ThemeAggregation


def build_cycle(
    *,
    aggregation: ThemeAggregation,
    games_analyzed: int,
    frequency: float,
    severity: float,
    cycle_number: int,
) -> CycleBuildResult:
    occurrences = aggregation.occurrences
    status = resolve_status(
        occurrences=occurrences,
        games_with_occurrences=aggregation.games_with_occurrences,
        baseline_occurrences=occurrences,
        current_occurrences=occurrences,
    )

    improvement_percentage = None
    if status == CYCLE_STATUS["improving"]:
        improvement_percentage = round(IMPROVING_THRESHOLD * 100, 2)
    elif status == CYCLE_STATUS["managed"]:
        improvement_percentage = round(MANAGED_THRESHOLD * 100, 2)

    return CycleBuildResult(
        theme=aggregation.theme,
        cycle_number=cycle_number,
        status=status,
        baseline_occurrences=occurrences,
        current_occurrences=occurrences,
        baseline_severity=severity,
        current_severity=severity,
        improvement_percentage=improvement_percentage,
        frequency=round(frequency, 4),
        detection_window_games=games_analyzed if games_analyzed < DETECTION_WINDOW_GAMES else DETECTION_WINDOW_GAMES,
        detection_window_days=DETECTION_WINDOW_DAYS,
    )


def resolve_status(
    *,
    occurrences: int,
    games_with_occurrences: int,
    baseline_occurrences: int,
    current_occurrences: int,
) -> int:
    if _is_active(occurrences, games_with_occurrences):
        return CYCLE_STATUS["active"]

    if occurrences > 0:
        return CYCLE_STATUS["detected"]

    return CYCLE_STATUS["detected"]


def transition_status_for_improvement(
    current_status: int,
    *,
    baseline_occurrences: int,
    current_occurrences: int,
) -> int:
    if baseline_occurrences <= 0:
        return current_status

    reduction = 1.0 - (current_occurrences / baseline_occurrences)
    if reduction >= MANAGED_THRESHOLD:
        return CYCLE_STATUS["managed"]
    if reduction >= IMPROVING_THRESHOLD:
        return CYCLE_STATUS["improving"]
    return current_status


def _is_active(occurrences: int, games_with_occurrences: int) -> bool:
    return occurrences >= MIN_OCCURRENCES_FOR_ACTIVE and games_with_occurrences >= MIN_GAMES_FOR_ACTIVE
